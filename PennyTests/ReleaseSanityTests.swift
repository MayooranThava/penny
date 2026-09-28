import Foundation
import SwiftData
import Testing
@testable import Penny

/// Mac / Xcode pre-release sanity for persistence, soft-delete, catalog, and demo seed.
/// Run with ⌘U or `./scripts/pre-release-sanity.sh --xcode` on a Mac.
@Suite("Release Sanity")
struct ReleaseSanityTests {

    // MARK: - Product catalog ↔ StoreKit config

    @Test("Penny Pro product IDs match Penny.storekit (lifetime-only)")
    func productCatalogMatchesStoreKit() throws {
        #expect(PennyProductCatalog.lifetimeProductID == "com.penny.app.pro.lifetime")
        #expect(PennyProductCatalog.allProductIDs == [PennyProductCatalog.lifetimeProductID])
        #expect(!PennyProductCatalog.allProductIDs.contains(PennyProductCatalog.retiredMonthlyConsumableProductID))
        #expect(PennyProductCatalog.freeTierGoalLimit == 3)
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
        #expect(PennySchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(PennySchemaV1.models.count == 8)
        #expect(PennyMigrationPlan.schemas.count == 1)
        #expect(PennyMigrationPlan.stages.isEmpty)
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

        #expect(!bills.isEmpty)
        #expect(!goals.isEmpty)
        #expect(!debts.isEmpty)
        #expect(categories.count >= CategoryCatalog.defaults.count)
        #expect(!transactions.isEmpty)
        #expect(bills.allSatisfy(\.isActive))
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
            icon: "house.fill",
            isActive: true
        )
        let gym = RecurringBill(
            name: "Gym",
            amount: 45,
            dueDay: 15,
            categoryName: "Health",
            recurrence: .monthly,
            nextDueDate: .now,
            startDate: .now,
            icon: "figure.run",
            isActive: true
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
                icon: "wifi",
                isActive: true
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

    // MARK: - Helpers

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
