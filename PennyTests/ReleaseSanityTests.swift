import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Penny

/// Mac / Xcode pre-release sanity for persistence, soft-delete, catalog, and demo seed.
/// Run with ⌘U or `./scripts/pre-release-sanity.sh --xcode` on a Mac.
@Suite("Release Sanity", .serialized, .isolatedTestResources)
struct ReleaseSanityTests {

    // MARK: - Product catalog ↔ StoreKit config

    @Test("Penny Pro product IDs match Penny.storekit (lifetime-only)")
    func productCatalogMatchesStoreKit() throws {
        #expect(PennyProductCatalog.lifetimeProductID == "com.penny.app.pro.lifetime")
        #expect(PennyProductCatalog.allProductIDs == [PennyProductCatalog.lifetimeProductID])
        #expect(!PennyProductCatalog.allProductIDs.contains(PennyProductCatalog.retiredMonthlyConsumableProductID))
        #expect(PennyProductCatalog.freeTierGoalLimit == 3)
        #expect(PennyProductCatalog.freeTierAccountLimit == 3)
        #expect(PennyProductCatalog.forecastHorizons(isPro: false) == [0, 1, 3])
        #expect(PennyProductCatalog.forecastHorizons(isPro: true) == [0, 1, 3, 6, 12])
        #expect(AccentTheme.effective(storedRaw: "ocean", isPro: false) == .mint)
        #expect(AccentTheme.effective(storedRaw: "ocean", isPro: true) == .ocean)

        let storeKitURL = try locateStoreKitConfig()
        let data = try Data(contentsOf: storeKitURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)

        var ids = Set<String>()
        if let products = json?["products"] as? [[String: Any]] {
            for product in products {
                if let id = product["productID"] as? String { ids.insert(id) }
            }
        }
        if let groups = json?["subscriptionGroups"] as? [[String: Any]] {
            for group in groups {
                guard let subscriptions = group["subscriptions"] as? [[String: Any]] else { continue }
                for subscription in subscriptions {
                    if let id = subscription["productID"] as? String { ids.insert(id) }
                }
            }
        }

        #expect(ids == PennyProductCatalog.allProductIDs)
    }

    // MARK: - Persistence identity

    @Test("SwiftData store name and schema version stay stable across releases")
    func persistenceIdentityVital() {
        #expect(PennyPersistence.storeName == "Penny")
        #expect(PennyPersistence.dataIsSafeMessage == "Your data is safe")
        #expect(PennySchemaV103.versionIdentifier == Schema.Version(1, 0, 3))
        #expect(PennySchemaV103.models.count == 8)
        #expect(PennySchemaV1.versionIdentifier == Schema.Version(1, 0, 4))
        #expect(PennySchemaV1.models.count == 9)
        #expect(PennyMigrationPlan.schemas.count == 2)
        #expect(PennyMigrationPlan.stages.count == 1)
        #expect(String(describing: PennyMigrationPlan.schemas[0]) == "PennySchemaV103")
        #expect(String(describing: PennyMigrationPlan.schemas[1]) == "PennySchemaV1")
    }

    // MARK: - Demo seed

    @Test("Demo seed creates the household needed for Home / Plan")
    @MainActor
    func demoSeedVital() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try DemoDataService.seedDemo(
            in: context,
            markOnboardingComplete: true,
            replaceExisting: true
        )

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1)
        #expect(settings.first?.hasCompletedOnboarding == true)
        #expect(settings.first?.monthlyIncome ?? 0 > 0)

        let bills = try context.fetch(FetchDescriptor<RecurringBill>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let debts = try context.fetch(FetchDescriptor<Debt>())
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let accounts = try context.fetch(FetchDescriptor<FinancialAccount>())
        let allocations = try context.fetch(FetchDescriptor<GoalFundingAllocation>())

        #expect(!bills.isEmpty)
        #expect(!goals.isEmpty)
        #expect(!debts.isEmpty)
        #expect(categories.count >= CategoryCatalog.defaults.count)
        #expect(!transactions.isEmpty)
        // Direct property access: Xcode 26 treats SwiftData key paths as throwing,
        // so `\.isActive` cannot be passed to `allSatisfy` inside `#expect`.
        #expect(bills.allSatisfy { $0.isActive })
        #expect(accounts.count == PennyProductCatalog.freeTierAccountLimit)
        #expect(accounts.contains { $0.accountType == .tfsa })
        #expect(!allocations.isEmpty)
        #expect(
            FinanceCalculator.allocationsFitBalances(
                accountBalances: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.balance) }),
                links: allocations.map {
                    .init(accountID: $0.accountID, goalID: $0.goalID, amount: $0.amount)
                }
            )
        )
    }

    @Test("Demo expense titles match bill names so Safe to Spend does not double-count")
    @MainActor
    func demoSeedBillExpenseTitlesAlign() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try DemoDataService.seedDemo(
            in: context,
            markOnboardingComplete: true,
            replaceExisting: true
        )

        let bills = try context.fetch(FetchDescriptor<RecurringBill>())
        let billNames = Set(bills.map { $0.name.lowercased() })
        let expenses = try context.fetch(FetchDescriptor<Transaction>())
            .filter { $0.transactionType == .expense }

        // Transit used to be "TTC Presto" while the bill was "TTC Pass".
        #expect(expenses.contains { $0.title == "TTC Pass" })
        #expect(!expenses.contains { $0.title == "TTC Presto" })

        let overlapping = expenses.filter { billNames.contains($0.title.lowercased()) }
        #expect(overlapping.contains { $0.title == "TTC Pass" })
        #expect(overlapping.contains { $0.title == "Streaming" })
    }

    @Test("Rolling bill schedules advances past nextDueDate")
    @MainActor
    func billScheduleRollsForward() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let past = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let bill = RecurringBill(
            name: "Rent",
            amount: 1_750,
            dueDay: 1,
            categoryName: "Housing",
            recurrence: .monthly,
            nextDueDate: past,
            startDate: past,
            icon: "house.fill"
        )
        context.insert(bill)
        try context.save()

        let asOf = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let changed = BillScheduleService.rollForwardDueDates(bills: [bill], in: context, asOf: asOf)
        #expect(changed)
        #expect(bill.nextDueDate >= calendar.startOfDay(for: asOf))
        #expect(calendar.component(.month, from: bill.nextDueDate) == 10)
        #expect(calendar.component(.day, from: bill.nextDueDate) == 1)
    }

    @Test("Seeding without replaceExisting preserves existing content")
    @MainActor
    func demoSeedPreservesExisting() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try DemoDataService.seedDemo(
            in: context,
            markOnboardingComplete: true,
            replaceExisting: true
        )
        let billCount = try context.fetch(FetchDescriptor<RecurringBill>()).count

        try DemoDataService.seedDemo(
            in: context,
            markOnboardingComplete: true,
            replaceExisting: false
        )
        #expect(try context.fetch(FetchDescriptor<RecurringBill>()).count == billCount)
    }

    // MARK: - Bill soft-delete

    @Test("Deleting a bill deactivates it and excludes it from active committed spend")
    @MainActor
    func billSoftDeleteVital() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let rent = RecurringBill(
            name: "Rent",
            amount: 2_000,
            dueDay: 1,
            categoryName: "Housing",
            recurrence: .monthly,
            nextDueDate: .now,
            startDate: .now,
            isActive: true,
            icon: "house.fill"
        )
        let gym = RecurringBill(
            name: "Gym",
            amount: 45,
            dueDay: 15,
            categoryName: "Health",
            recurrence: .monthly,
            nextDueDate: .now,
            startDate: .now,
            isActive: true,
            icon: "figure.run"
        )
        context.insert(rent)
        context.insert(gym)
        try context.save()

        // Soft-delete like Plan → Delete Bill.
        rent.isActive = false
        try context.save()

        let active = try context.fetch(
            FetchDescriptor<RecurringBill>(
                predicate: #Predicate { $0.isActive }
            )
        )
        #expect(active.count == 1)
        #expect(active.first?.name == "Gym")

        let all = try context.fetch(FetchDescriptor<RecurringBill>())
        #expect(all.count == 2)
        #expect(all.contains { !$0.isActive && $0.name == "Rent" })

        let committed = FinanceCalculator.totalMonthlyCommitted(
            billAmountsAndRecurrence: active.map { ($0.amount, $0.recurrence) },
            debtPayments: []
        )
        #expect(committed == 45)
    }

    // MARK: - Repair missing settings

    @Test("repairIfNeeded recreates settings when content exists without wiping data")
    @MainActor
    func repairSettingsVital() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)

        context.insert(
            RecurringBill(
                name: "Internet",
                amount: 80,
                dueDay: 10,
                categoryName: "Subscriptions",
                recurrence: .monthly,
                nextDueDate: .now,
                startDate: .now,
                isActive: true,
                icon: "wifi"
            )
        )
        try context.save()
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)

        try PennyPersistence.repairIfNeeded(in: context)

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1)
        #expect(settings.first?.hasCompletedOnboarding == true)
        #expect(try context.fetch(FetchDescriptor<RecurringBill>()).count == 1)
    }

    // MARK: - Money display contract (Home)

    @Test("Home money string always shows two decimals")
    func homeMoneyDecimalsVital() {
        let locale = Locale(identifier: "en_US")
        let hero = MoneyFormatters.string(from: Decimal(string: "235.4")!, currencyCode: "USD", locale: locale)
        #expect(hero.contains("235.40"))
        let budget = MoneyFormatters.string(from: 3_450, currencyCode: "USD", locale: locale)
        #expect(budget.contains("3,450.00") || budget.contains("3450.00"))
    }

    // MARK: - CSV export

    @Test("CSV export escapes fields and includes header")
    func csvExportVital() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let csv = CSVExportLogic.makeCSV(
            rows: [
                .init(
                    date: date,
                    title: "Rent, apt",
                    amount: 2000,
                    type: "Expense",
                    category: "Housing",
                    note: "note",
                    merchant: "",
                    source: "Manual"
                )
            ],
            calendar: calendar
        )
        #expect(csv.contains(CSVExportLogic.header))
        #expect(csv.contains("\"Rent, apt\""))
        #expect(csv.contains("2026-09-01"))
    }

    // MARK: - Settings copy

    @Test("Settings privacy line names on-device storage and Apple crash reports")
    func settingsPrivacyLine() {
        #expect(PennyAppInfo.settingsFootnote == [
            "Penny keeps your financial info on your iPhone and never sends it to us. Purchases are handled by Apple, and Apple may share crash reports with us only if you've turned that on in your iPhone settings.",
            "Penny is a budgeting tool, not financial, tax or investment advice. Amounts are estimates based on what you enter and may not match your bank.",
            "Penny doesn't connect to your bank. Wallet tap capture and widgets keep their data on this iPhone.",
            "Deleting Penny or using Reset permanently erases your data from this iPhone.",
            "Intended for adults; not directed to children under 13. Full details are in the Terms of Use."
        ])
        #expect(PennyAppInfo.privacySummary == PennyAppInfo.settingsFootnote[0])
        let lowered = PennyAppInfo.privacySummary.lowercased()
        #expect(!lowered.contains("to anyone"))
        #expect(!lowered.contains("send analytics"))
        #expect(!PennyAppInfo.settingsFootnote.joined(separator: "\n").contains("App updates keep your data"))
    }

    @Test("Reset clears the open store, backup, marker, and widget snapshot")
    @MainActor
    func resetErasesOnDeviceFiles() async throws {
        #expect(WidgetSnapshotStore.activeDefaultsSuite != WidgetSnapshotStore.appGroupID)
        #expect(WidgetSnapshotStore.activeDefaultsSuite.hasPrefix("PennyTests."))

        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")
        let fileManager = FileManager.default

        do {
            let container = try PennyPersistence.makeContainer(at: storeURL)
            let context = ModelContext(container)
            context.insert(sampleExpense(title: "Coffee"))
            context.insert(sampleExpense(title: "Groceries"))
            context.insert(
                RecurringBill(
                    name: "Internet",
                    amount: 80,
                    dueDay: 10,
                    categoryName: "Subscriptions",
                    recurrence: .monthly,
                    nextDueDate: .now,
                    startDate: .now,
                    isActive: true,
                    icon: "wifi"
                )
            )
            context.insert(UserSettings(currencyCode: "CAD", monthlyIncome: 100, hasCompletedOnboarding: true))
            try context.save()
            #expect(try context.fetch(FetchDescriptor<Transaction>()).count == 2)

            try PennyStoreBackup.copyStore(
                at: storeURL,
                to: PennyStoreBackup.snapshotDirectory(for: storeURL)
            )
            try Data("1".utf8).write(to: PennyStoreBackup.markerURL(for: storeURL), options: .atomic)
            WidgetSnapshotStore.save(resetSnapshot(displayName: "Reset"))
            let wal = URL(fileURLWithPath: storeURL.path + "-wal")
            let shm = URL(fileURLWithPath: storeURL.path + "-shm")
            let walBefore = fileManager.fileExists(atPath: wal.path)
            let shmBefore = fileManager.fileExists(atPath: shm.path)

            _ = try await PennyPersistence.reset(in: context)

            #expect(fileManager.fileExists(atPath: storeURL.path))
            #expect(fileManager.fileExists(atPath: wal.path) == walBefore)
            #expect(fileManager.fileExists(atPath: shm.path) == shmBefore)
            try expectNoBackupOrWidget(at: storeURL)
            try expectNoUserModels(in: context)
        }

        let reopened = try PennyPersistence.makeContainer(at: storeURL)
        try expectNoUserModels(in: ModelContext(reopened))
        try expectNoBackupOrWidget(at: storeURL)
    }

    @Test("Reset removes a deleted transaction title from the .store, -wal, and -shm bytes")
    @MainActor
    func resetErasesCanaryFromStoreFiles() async throws {
        let canary = "PENNY-ERASE-CANARY-\(UUID().uuidString)"
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyErase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")
        let needle = Data(canary.utf8)

        do {
            let container = try PennyPersistence.makeContainer(at: storeURL)
            let context = ModelContext(container)
            context.insert(sampleExpense(title: canary))
            try context.save()
            _ = try await PennyPersistence.reset(in: context)

            for url in PennyStoreBackup.relatedURLs(for: storeURL) {
                if url.path != storeURL.path, !FileManager.default.fileExists(atPath: url.path) {
                    continue
                }
                let bytes = try Data(contentsOf: url)
                #expect(bytes.range(of: needle) == nil)
            }
        }

        let reopened = try PennyPersistence.makeContainer(at: storeURL)
        let transactions = try ModelContext(reopened).fetch(FetchDescriptor<Transaction>())
        #expect(transactions.isEmpty)
    }

    @Test("Reset finishes when compaction cannot lock the store")
    @MainActor
    func resetCompletesWhenCompactionCannotLock() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyEraseLock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")
        let container = try PennyPersistence.makeContainer(at: storeURL)
        let context = ModelContext(container)
        context.insert(sampleExpense(title: "Coffee"))
        try context.save()

        let lock = ExclusiveStoreLock()
        defer { lock.release() }
        let result = try await PennyPersistence.$beforeStoreCompaction.withValue({ url in
            lock.acquire(url)
        }) {
            try await PennyPersistence.reset(in: context)
        }
        #expect(lock.didAcquire)
        #expect(!result.succeeded)
        #expect(result.ranOffMainThread)
        lock.release()
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
    }

    @Test("Compaction of 5,000 transactions is measured off the main thread")
    @MainActor
    func compactionOfFiveThousandTransactions() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyEraseBulk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")
        let container = try PennyPersistence.makeContainer(at: storeURL)
        let context = ModelContext(container)
        if #available(iOS 18, *) {
            context.autosaveEnabled = false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))!
        let longNote = String(repeating: "Rent is paid from the joint account. ", count: 12)
        for index in 1...5_000 {
            context.insert(Transaction(
                title: "Bulk \(index)",
                amount: Decimal(sign: .plus, exponent: -2, significand: Decimal(index)),
                date: date,
                transactionType: .expense,
                categoryName: "Groceries",
                note: index == 1 ? longNote : ""
            ))
        }
        context.insert(UserSettings(
            currencyCode: "CAD",
            monthlyIncome: Decimal(sign: .plus, exponent: -2, significand: 500055),
            hasCompletedOnboarding: true
        ))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Transaction>()).count == 5_000)

        let result = try await PennyPersistence.reset(in: context)
        let seconds = result.duration.secondsValue
        let timingLine = String(
            format: "COMPACTION_5000_SECONDS=%.3f\n",
            locale: Locale(identifier: "en_US_POSIX"),
            seconds
        )
        // xcodebuild does not forward print/stderr from the simulator. The
        // macOS job reads the attachment (Xcode 26) and this temp marker.
        print(timingLine, terminator: "")
        FileHandle.standardError.write(Data(timingLine.utf8))
        NSLog("%@", timingLine.trimmingCharacters(in: .newlines))
        let timingURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("COMPACTION_5000_SECONDS.txt")
        try? timingLine.write(to: timingURL, atomically: true, encoding: .utf8)
        #if compiler(>=6.2)
        Attachment.record(timingLine, named: "COMPACTION_5000_SECONDS.txt")
        #endif
        #expect(result.ranOffMainThread)
        #expect(result.succeeded)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
    }

    @Test("Delete all data uses the same cleanup and leaves no transactions")
    @MainActor
    func deleteAllDataUsesReset() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")

        do {
            let container = try PennyPersistence.makeContainer(at: storeURL)
            let context = ModelContext(container)
            context.insert(sampleExpense(title: "Coffee"))
            context.insert(sampleExpense(title: "Groceries"))
            try context.save()
            try PennyStoreBackup.copyStore(
                at: storeURL,
                to: PennyStoreBackup.snapshotDirectory(for: storeURL)
            )
            try Data("1".utf8).write(to: PennyStoreBackup.markerURL(for: storeURL), options: .atomic)
            WidgetSnapshotStore.save(resetSnapshot(displayName: "Delete"))

            try await PennyPersistence.deleteAllData(in: context)

            #expect(FileManager.default.fileExists(atPath: storeURL.path))
            #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
            try expectNoBackupOrWidget(at: storeURL)
        }

        let reopened = try PennyPersistence.makeContainer(at: storeURL)
        let context = ModelContext(reopened)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecurringBill>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Debt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavingsGoal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FinancialAccount>()).isEmpty)
        try expectNoBackupOrWidget(at: storeURL)
    }

    @Test("Reset demo data keeps the store file and drops the pre-upgrade backup")
    @MainActor
    func resetDemoDataUsesReset() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PennyResetDemo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Penny.store")

        let container = try PennyPersistence.makeContainer(at: storeURL)
        let context = ModelContext(container)
        context.insert(sampleExpense(title: "Coffee"))
        try context.save()
        try PennyStoreBackup.copyStore(
            at: storeURL,
            to: PennyStoreBackup.snapshotDirectory(for: storeURL)
        )
        try Data("1".utf8).write(to: PennyStoreBackup.markerURL(for: storeURL), options: .atomic)
        WidgetSnapshotStore.save(resetSnapshot(displayName: "Demo"))

        try await PennyPersistence.resetDemoData(in: context)

        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        try expectNoBackupOrWidget(at: storeURL)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.usingDemoData == true)
    }

    // MARK: - Helpers

    private func sampleExpense(title: String) -> Transaction {
        Transaction(
            title: title,
            amount: 12,
            transactionType: .expense,
            categoryName: "Food"
        )
    }

    private func resetSnapshot(displayName: String) -> WidgetSnapshotStore.Snapshot {
        WidgetSnapshotStore.Snapshot(
            safeToSpend: 12,
            currencyCode: "CAD",
            monthLabel: "Oct",
            nextReminderTitle: "Rent due",
            nextReminderDetail: "$10",
            displayName: displayName,
            updatedAt: .now,
            upcomingItems: nil,
            spentThisMonth: nil,
            plannedSpending: nil,
            budgetHealth: nil,
            topGoalName: nil,
            topGoalProgress: nil,
            topGoalDetail: nil
        )
    }

    @MainActor
    private func expectNoUserModels(in context: ModelContext) throws {
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<BudgetCategory>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Budget>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecurringBill>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavingsGoal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Debt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FinancialAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GoalFundingAllocation>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }

    private func expectNoBackupOrWidget(at storeURL: URL) throws {
        let fileManager = FileManager.default
        #expect(!fileManager.fileExists(atPath: PennyStoreBackup.snapshotDirectory(for: storeURL).path))
        #expect(!fileManager.fileExists(atPath: PennyStoreBackup.markerURL(for: storeURL).path))
        #expect(!fileManager.fileExists(atPath: PennyStoreBackup.backupRoot(for: storeURL).path))
        #expect(WidgetSnapshotStore.load() == nil)
        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        #expect(defaults.object(forKey: WidgetSnapshotStore.snapshotKey) == nil)
    }

    private func locateStoreKitConfig() throws -> URL {
        let fm = FileManager.default
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("Penny.storekit")
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        Issue.record("Could not find Penny.storekit relative to \(#filePath)")
        throw CocoaError(.fileNoSuchFile)
    }
}

private extension Duration {
    var secondsValue: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// Holds `BEGIN EXCLUSIVE` on a store so a second connection cannot checkpoint or vacuum.
/// If that transaction cannot be granted, write permission is removed so the open fails instead.
private final class ExclusiveStoreLock: @unchecked Sendable {
    private let gate = NSLock()
    private var db: OpaquePointer?
    private var storePath: String?
    private var originalPermissions: NSNumber?
    private var acquired = false

    var didAcquire: Bool {
        gate.lock()
        defer { gate.unlock() }
        return acquired
    }

    func acquire(_ url: URL) {
        gate.lock()
        defer { gate.unlock() }
        storePath = url.path
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle {
            db = handle
            sqlite3_busy_timeout(handle, 1_000)
            var error: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(handle, "BEGIN EXCLUSIVE;", nil, nil, &error)
            sqlite3_free(error)
            if result == SQLITE_OK {
                acquired = true
            }
        } else if let handle {
            sqlite3_close(handle)
        }

        // BEGIN EXCLUSIVE blocks other writers. Write permission is removed as well
        // so the compaction connection cannot open the file for update.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            let permissions = (attributes[.posixPermissions] as? NSNumber)
                ?? (attributes[.posixPermissions] as? Int).map { NSNumber(value: $0) }
            if let permissions {
                originalPermissions = permissions
                if (try? FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o444)],
                    ofItemAtPath: url.path
                )) != nil {
                    acquired = true
                }
            }
        }
    }

    func release() {
        gate.lock()
        defer { gate.unlock() }
        if let db {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            sqlite3_close(db)
            self.db = nil
        }
        if let storePath, let originalPermissions {
            try? FileManager.default.setAttributes(
                [.posixPermissions: originalPermissions.uint16Value],
                ofItemAtPath: storePath
            )
            self.originalPermissions = nil
        }
    }
}
