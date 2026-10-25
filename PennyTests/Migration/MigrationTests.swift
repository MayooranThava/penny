import Foundation
import SwiftData
import Testing
@testable import Penny

/// Anchor so tests can find the PennyTests bundle (the host app bundle is not the test bundle).
final class MigrationFixtureAnchor {}

/// Upgrade gate. Stores are written from the frozen v1.0.3 schema (`PennySchemaV103`,
/// copied from commit `dca913c`) and from the unversioned v1.0.4 model list (commit `92c6746`,
/// which is still the shipping model). This environment cannot boot those App Store binaries.
/// Each test then opens the file with `PennyPersistence.makeContainer(at:)`, the same path
/// an update uses: backup, then `PennyMigrationPlan`.
@Suite("Migration", .serialized, .isolatedTestResources)
struct MigrationTests {
    private static let coffeeID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private static let pennyID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private static let paycheckID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    private static let groceriesID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private static let rentCategoryID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private static let budgetID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private static let rentBillID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    private static let transitBillID = UUID(uuidString: "40000000-0000-0000-0000-000000000002")!
    private static let goalID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    private static let debtID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    private static let chequingID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
    private static let savingsID = UUID(uuidString: "70000000-0000-0000-0000-000000000002")!
    private static let settingsID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
    private static let allocationID = UUID(uuidString: "90000000-0000-0000-0000-000000000001")!

    private static let longNote = String(repeating: "Rent is paid from the joint account. ", count: 12)

    @Test("v103StoreOpensOnCurrentSchemaWithoutLosingACent")
    @MainActor
    func v103StoreOpensOnCurrentSchemaWithoutLosingACent() throws {
        let url = try storeURL("Penny-v1.0.3.store")
        try writeV103RichStore(at: url)
        let container = try PennyPersistence.makeContainer(at: url)
        try assertRichHousehold(
            in: container,
            paidCycleKey: "",
            walkthroughComplete: false,
            allocationAmount: nil,
            secondAccountType: "savings"
        )
        try assertSafeToSpendAndWidget(in: container)
    }

    @Test("v104StoreOpensThroughMigrationPlanWithoutLosingACent")
    @MainActor
    func v104StoreOpensThroughMigrationPlanWithoutLosingACent() throws {
        let url = try storeURL("Penny-v1.0.4.store")
        try writeV104RichStore(at: url)
        let container = try PennyPersistence.makeContainer(at: url)
        try assertRichHousehold(
            in: container,
            paidCycleKey: "2026-10",
            walkthroughComplete: true,
            allocationAmount: money("125.50"),
            secondAccountType: "tfsa"
        )
        try assertSafeToSpendAndWidget(in: container)
    }

    @Test("fiveThousandTransactionUpgradeFinishesWithinAFewSeconds")
    @MainActor
    func fiveThousandTransactionUpgradeFinishesWithinAFewSeconds() throws {
        let url = try storeURL("Penny-v1.0.3-large.store")
        try writeV103BulkStore(at: url, count: 5_000)
        let clock = ContinuousClock()
        let started = clock.now
        let container = try PennyPersistence.makeContainer(at: url)
        let elapsed = started.duration(to: clock.now)
        if elapsed >= .seconds(5) {
            Issue.record("Opening the 5,000-transaction store took too long: \(elapsed)")
        }
        #expect(elapsed < .seconds(5))

        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 5_000)
        let sum = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(sum == Decimal(125_025))
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1)
        #expect(settings.first?.hasCompletedOnboarding == true)
        #expect(settings.first?.monthlyIncome == money("5000.55"))
        #expect(settings.first?.currencyCode == "CAD")
    }

    @Test("failedMigrationRestoresBackupAndSaysDataIsSafe")
    @MainActor
    func failedMigrationRestoresBackupAndSaysDataIsSafe() throws {
        let url = try storeURL("Penny-restore.store")
        try writeCurrentStore(at: url, amount: money("12.34"), title: "Kept")

        try PennyPersistence.$migrationFailureInjection.withValue({ storeURL in
            let snapshot = PennyStoreBackup.snapshotDirectory(for: storeURL)
            guard FileManager.default.fileExists(atPath: snapshot.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let copied = try FileManager.default.contentsOfDirectory(at: snapshot, includingPropertiesForKeys: nil)
            guard !copied.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
            try Data("corrupt".utf8).write(to: storeURL, options: .atomic)
        }) {
            do {
                _ = try PennyPersistence.makeContainer(at: url)
                Issue.record("Expected the forced migration failure to throw")
            } catch {
                #expect(error.localizedDescription.contains(PennyPersistence.dataIsSafeMessage))
            }
        }

        let container = try PennyPersistence.makeContainer(at: url)
        let rows = try ModelContext(container).fetch(FetchDescriptor<Transaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Kept")
        #expect(rows.first?.amount == money("12.34"))
        let header = try Data(contentsOf: url).prefix(15)
        #expect(header == Data("SQLite format 3".utf8))
    }

    @Test("interruptedMigrationRestoresThePreviousCopy")
    @MainActor
    func interruptedMigrationRestoresThePreviousCopy() throws {
        let url = try storeURL("Penny-interrupted.store")
        try writeCurrentStore(at: url, amount: money("0.01"), title: "Cent")
        try PennyStoreBackup.copyStore(at: url, to: PennyStoreBackup.snapshotDirectory(for: url))
        try Data("1".utf8).write(to: PennyStoreBackup.markerURL(for: url), options: .atomic)
        try Data("torn-write".utf8).write(to: url, options: .atomic)

        let container = try PennyPersistence.makeContainer(at: url)
        let rows = try ModelContext(container).fetch(FetchDescriptor<Transaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.amount == money("0.01"))
        #expect(rows.first?.title == "Cent")
    }

    // MARK: - Writers

    private func storeURL(_ name: String) throws -> URL {
        let directoryName = try #require(
            PennyPersistence.activeIsolatedStoreName,
            "Migration tests need an isolated store directory"
        )
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    private func sampleDate() -> Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))!
    }

    private func money(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    @MainActor
    private func writeV103RichStore(at url: URL) throws {
        let schema = Schema(versionedSchema: PennySchemaV103.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(container)
        let date = sampleDate()
        context.insert(PennySchemaV103.Transaction(
            id: Self.coffeeID,
            title: "Coffee",
            amount: money("4.75"),
            date: date,
            transactionTypeRaw: "expense",
            categoryName: "Groceries",
            note: "",
            createdAt: date
        ))
        context.insert(PennySchemaV103.Transaction(
            id: Self.pennyID,
            title: "Café tip",
            amount: money("0.01"),
            date: date,
            transactionTypeRaw: "expense",
            categoryName: "Groceries",
            note: Self.longNote,
            createdAt: date
        ))
        context.insert(PennySchemaV103.Transaction(
            id: Self.paycheckID,
            title: "Paycheck",
            amount: money("2500.00"),
            date: date,
            transactionTypeRaw: "income",
            categoryName: "Income",
            note: "",
            createdAt: date
        ))
        context.insert(PennySchemaV103.BudgetCategory(
            id: Self.groceriesID,
            name: "Groceries",
            icon: "cart.fill",
            budgetedAmount: money("400.00"),
            colourIdentifier: "food",
            sortOrder: 1
        ))
        context.insert(PennySchemaV103.BudgetCategory(
            id: Self.rentCategoryID,
            name: "Rent",
            icon: "house.fill",
            budgetedAmount: money("1500.10"),
            colourIdentifier: "housing",
            sortOrder: 0
        ))
        context.insert(PennySchemaV103.Budget(
            id: Self.budgetID,
            monthStart: DateHelpers.startOfMonth(for: date),
            plannedSpending: money("1900.10"),
            notes: "October envelope"
        ))
        context.insert(PennySchemaV103.RecurringBill(
            id: Self.rentBillID,
            name: "Rent",
            amount: money("1500.10"),
            dueDay: 1,
            categoryName: "Rent",
            recurrenceRaw: "monthly",
            nextDueDate: date,
            startDate: date,
            reminderEnabled: true,
            reminderDaysBefore: 2,
            isActive: true,
            icon: "house.fill"
        ))
        context.insert(PennySchemaV103.RecurringBill(
            id: Self.transitBillID,
            name: "Transit",
            amount: money("12.50"),
            dueDay: 15,
            categoryName: "Transportation",
            recurrenceRaw: "weekly",
            nextDueDate: date,
            startDate: date,
            reminderEnabled: false,
            reminderDaysBefore: 1,
            isActive: true,
            icon: "tram.fill"
        ))
        context.insert(PennySchemaV103.SavingsGoal(
            id: Self.goalID,
            name: "Vacation",
            targetAmount: money("10000.00"),
            currentAmount: money("250.25"),
            targetDate: nil,
            icon: "airplane",
            createdAt: date,
            colourIdentifier: "savings"
        ))
        context.insert(PennySchemaV103.Debt(
            id: Self.debtID,
            name: "Visa",
            originalBalance: money("3000.00"),
            currentBalance: money("1234.56"),
            interestRate: money("19.99"),
            minimumPayment: money("35.00"),
            plannedMonthlyPayment: money("50.00"),
            dueDay: 15,
            icon: "creditcard.fill"
        ))
        context.insert(PennySchemaV103.FinancialAccount(
            id: Self.chequingID,
            name: "Everyday Chequing",
            typeRaw: "chequing",
            balance: money("4321.09"),
            isIncludedInNetWorth: true,
            sortOrder: 0
        ))
        context.insert(PennySchemaV103.FinancialAccount(
            id: Self.savingsID,
            name: "Rainy day",
            typeRaw: "savings",
            balance: money("100.01"),
            isIncludedInNetWorth: true,
            sortOrder: 1
        ))
        context.insert(PennySchemaV103.UserSettings(
            id: Self.settingsID,
            currencyCode: "CAD",
            monthlyIncome: money("5000.55"),
            plannedMonthlySavings: money("200.00"),
            hasCompletedOnboarding: true,
            billRemindersEnabled: true,
            appearanceRaw: "dark",
            usingDemoData: false,
            displayName: "Avery",
            applePayCaptureConfigured: true,
            accentThemeRaw: "ocean"
        ))
        try context.save()
    }

    @MainActor
    private func writeV104RichStore(at url: URL) throws {
        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Budget.self,
            RecurringBill.self,
            SavingsGoal.self,
            Debt.self,
            FinancialAccount.self,
            GoalFundingAllocation.self,
            UserSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(container)
        let date = sampleDate()
        context.insert(Transaction(
            id: Self.coffeeID, title: "Coffee", amount: money("4.75"), date: date,
            transactionType: .expense, categoryName: "Groceries", note: "", createdAt: date
        ))
        context.insert(Transaction(
            id: Self.pennyID, title: "Café tip", amount: money("0.01"), date: date,
            transactionType: .expense, categoryName: "Groceries", note: Self.longNote, createdAt: date
        ))
        context.insert(Transaction(
            id: Self.paycheckID, title: "Paycheck", amount: money("2500.00"), date: date,
            transactionType: .income, categoryName: "Income", note: "", createdAt: date
        ))
        context.insert(BudgetCategory(
            id: Self.groceriesID, name: "Groceries", icon: "cart.fill",
            budgetedAmount: money("400.00"), colourIdentifier: "food", sortOrder: 1
        ))
        context.insert(BudgetCategory(
            id: Self.rentCategoryID, name: "Rent", icon: "house.fill",
            budgetedAmount: money("1500.10"), colourIdentifier: "housing", sortOrder: 0
        ))
        context.insert(Budget(
            id: Self.budgetID, monthStart: DateHelpers.startOfMonth(for: date),
            plannedSpending: money("1900.10"), notes: "October envelope"
        ))
        context.insert(RecurringBill(
            id: Self.rentBillID, name: "Rent", amount: money("1500.10"), dueDay: 1,
            categoryName: "Rent", recurrence: .monthly, nextDueDate: date, startDate: date,
            reminderEnabled: true, reminderDaysBefore: 2, isActive: true, icon: "house.fill",
            paidCycleKey: "2026-10"
        ))
        context.insert(RecurringBill(
            id: Self.transitBillID, name: "Transit", amount: money("12.50"), dueDay: 15,
            categoryName: "Transportation", recurrence: .weekly, nextDueDate: date, startDate: date,
            reminderEnabled: false, reminderDaysBefore: 1, isActive: true, icon: "tram.fill",
            paidCycleKey: ""
        ))
        context.insert(SavingsGoal(
            id: Self.goalID, name: "Vacation", targetAmount: money("10000.00"),
            currentAmount: money("250.25"), targetDate: nil, icon: "airplane",
            createdAt: date, colourIdentifier: "savings"
        ))
        context.insert(Debt(
            id: Self.debtID, name: "Visa", originalBalance: money("3000.00"),
            currentBalance: money("1234.56"), interestRate: money("19.99"),
            minimumPayment: money("35.00"), plannedMonthlyPayment: money("50.00"),
            dueDay: 15, icon: "creditcard.fill"
        ))
        context.insert(FinancialAccount(
            id: Self.chequingID, name: "Everyday Chequing", accountType: .chequing,
            balance: money("4321.09"), isIncludedInNetWorth: true, sortOrder: 0
        ))
        context.insert(FinancialAccount(
            id: Self.savingsID, name: "TFSA", accountType: .tfsa,
            balance: money("100.01"), isIncludedInNetWorth: true, sortOrder: 1
        ))
        context.insert(GoalFundingAllocation(
            id: Self.allocationID, accountID: Self.savingsID, goalID: Self.goalID,
            amount: money("125.50"), createdAt: date
        ))
        context.insert(UserSettings(
            id: Self.settingsID, currencyCode: "CAD", monthlyIncome: money("5000.55"),
            plannedMonthlySavings: money("200.00"), hasCompletedOnboarding: true,
            billRemindersEnabled: true, appearance: .dark, usingDemoData: false,
            displayName: "Avery", applePayCaptureConfigured: true, accentTheme: .ocean,
            hasCompletedWalkthrough: true
        ))
        try context.save()
    }

    @MainActor
    private func writeV103BulkStore(at url: URL, count: Int) throws {
        let schema = Schema(versionedSchema: PennySchemaV103.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(container)
        if #available(iOS 18, *) {
            context.autosaveEnabled = false
        }
        let date = sampleDate()
        for index in 1...count {
            context.insert(PennySchemaV103.Transaction(
                id: UUID(),
                title: "Bulk \(index)",
                amount: Decimal(sign: .plus, exponent: -2, significand: Decimal(index)),
                date: date,
                transactionTypeRaw: "expense",
                categoryName: "Groceries",
                note: index == 1 ? Self.longNote : "",
                createdAt: date
            ))
        }
        context.insert(PennySchemaV103.UserSettings(
            id: Self.settingsID,
            currencyCode: "CAD",
            monthlyIncome: money("5000.55"),
            plannedMonthlySavings: money("200.00"),
            hasCompletedOnboarding: true,
            billRemindersEnabled: true,
            appearanceRaw: "system",
            usingDemoData: false,
            displayName: "Avery",
            applePayCaptureConfigured: false,
            accentThemeRaw: "mint"
        ))
        try context.save()
    }

    @MainActor
    private func writeCurrentStore(at url: URL, amount: Decimal, title: String) throws {
        let container = try PennyPersistence.makeContainer(at: url)
        let context = ModelContext(container)
        context.insert(Transaction(
            title: title,
            amount: amount,
            transactionType: .expense,
            categoryName: "Food"
        ))
        try context.save()
    }

    // MARK: - Assertions

    @MainActor
    private func assertRichHousehold(
        in container: ModelContainer,
        paidCycleKey: String,
        walkthroughComplete: Bool,
        allocationAmount: Decimal?,
        secondAccountType: String
    ) throws {
        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let bills = try context.fetch(FetchDescriptor<RecurringBill>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let debts = try context.fetch(FetchDescriptor<Debt>())
        let accounts = try context.fetch(FetchDescriptor<FinancialAccount>())
        let allocations = try context.fetch(FetchDescriptor<GoalFundingAllocation>())
        let settings = try context.fetch(FetchDescriptor<UserSettings>())

        #expect(transactions.count == 3)
        #expect(categories.count == 2)
        #expect(budgets.count == 1)
        #expect(bills.count == 2)
        #expect(goals.count == 1)
        #expect(debts.count == 1)
        #expect(accounts.count == 2)
        #expect(settings.count == 1)
        #expect(allocations.count == (allocationAmount == nil ? 0 : 1))

        let coffee = try #require(transactions.first { $0.id == Self.coffeeID })
        let penny = try #require(transactions.first { $0.id == Self.pennyID })
        let paycheck = try #require(transactions.first { $0.id == Self.paycheckID })
        let date = sampleDate()
        #expect(coffee.title == "Coffee")
        #expect(coffee.amount == money("4.75"))
        #expect(coffee.date == date)
        #expect(penny.createdAt == date)
        #expect(coffee.transactionType == .expense)
        #expect(coffee.categoryName == "Groceries")
        #expect(penny.title == "Café tip")
        #expect(penny.amount == money("0.01"))
        #expect(penny.note == Self.longNote)
        #expect(paycheck.amount == money("2500.00"))
        #expect(paycheck.transactionType == .income)
        let amountTotal = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(amountTotal == money("2504.76"))

        let groceries = try #require(categories.first { $0.id == Self.groceriesID })
        let rentCategory = try #require(categories.first { $0.id == Self.rentCategoryID })
        #expect(groceries.budgetedAmount == money("400.00"))
        #expect(groceries.sortOrder == 1)
        #expect(rentCategory.budgetedAmount == money("1500.10"))
        #expect(BudgetPlanning.plannedSpending(from: categories) == money("1900.10"))

        let budget = try #require(budgets.first)
        #expect(budget.id == Self.budgetID)
        #expect(budget.plannedSpending == money("1900.10"))
        #expect(budget.notes == "October envelope")
        #expect(budget.monthStart == DateHelpers.startOfMonth(for: date))

        let rent = try #require(bills.first { $0.id == Self.rentBillID })
        let transit = try #require(bills.first { $0.id == Self.transitBillID })
        #expect(rent.amount == money("1500.10"))
        #expect(rent.recurrence == .monthly)
        #expect(rent.dueDay == 1)
        #expect(rent.isActive == true)
        #expect(rent.paidCycleKey == paidCycleKey)
        #expect(rent.nextDueDate == date)
        #expect(rent.startDate == date)
        #expect(transit.amount == money("12.50"))
        #expect(transit.recurrence == .weekly)
        #expect(transit.reminderEnabled == false)

        let goal = try #require(goals.first)
        #expect(goal.name == "Vacation")
        #expect(goal.targetAmount == money("10000.00"))
        #expect(goal.currentAmount == money("250.25"))
        #expect(goal.targetDate == nil)
        #expect(goal.createdAt == date)

        let debt = try #require(debts.first)
        #expect(debt.name == "Visa")
        #expect(debt.originalBalance == money("3000.00"))
        #expect(debt.currentBalance == money("1234.56"))
        #expect(debt.interestRate == money("19.99"))
        #expect(debt.minimumPayment == money("35.00"))
        #expect(debt.plannedMonthlyPayment == money("50.00"))

        let chequing = try #require(accounts.first { $0.id == Self.chequingID })
        let second = try #require(accounts.first { $0.id == Self.savingsID })
        #expect(chequing.balance == money("4321.09"))
        #expect(chequing.typeRaw == "chequing")
        #expect(second.balance == money("100.01"))
        #expect(second.typeRaw == secondAccountType)

        if let allocationAmount {
            let allocation = try #require(allocations.first)
            #expect(allocation.amount == allocationAmount)
            #expect(allocation.accountID == Self.savingsID)
            #expect(allocation.goalID == Self.goalID)
        }

        let saved = try #require(settings.first)
        #expect(saved.currencyCode == "CAD")
        #expect(saved.monthlyIncome == money("5000.55"))
        #expect(saved.plannedMonthlySavings == money("200.00"))
        #expect(saved.hasCompletedOnboarding == true)
        #expect(saved.billRemindersEnabled == true)
        #expect(saved.appearance == .dark)
        #expect(saved.usingDemoData == false)
        #expect(saved.displayName == "Avery")
        #expect(saved.applePayCaptureConfigured == true)
        #expect(saved.accentThemeRaw == "ocean")
        #expect(saved.hasCompletedWalkthrough == walkthroughComplete)
    }

    @MainActor
    private func assertSafeToSpendAndWidget(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        let bills = try context.fetch(FetchDescriptor<RecurringBill>())
        let debts = try context.fetch(FetchDescriptor<Debt>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let allocations = try context.fetch(FetchDescriptor<GoalFundingAllocation>())
        let settings = try #require(context.fetch(FetchDescriptor<UserSettings>()).first)
        let month = sampleDate()

        // Weekly bills use 52 weeks / 12 months (54.17), not the biweekly 26/12 figure.
        let weekly = FinanceCalculator.monthlyEquivalent(amount: money("12.50"), recurrence: .weekly)
        let committed = money("1500.10") + weekly + money("50.00")
        let expected = money("5000.55") - committed - money("4.76") - money("200.00")
        #expect(weekly == money("54.17"))
        #expect(committed == money("1604.27"))
        #expect(expected == money("3191.52"))

        WidgetSnapshotPublisher.publish(
            transactions: transactions,
            categories: categories,
            bills: bills,
            debts: debts,
            goals: goals,
            allocations: allocations,
            settings: settings,
            month: month
        )
        let snapshot = try #require(WidgetSnapshotStore.load())
        #expect(snapshot.currencyCode == "CAD")
        #expect(snapshot.displayName == "Avery")
        #expect(snapshot.safeToSpend == expected)
        let planned = try #require(snapshot.plannedSpending)
        #expect(planned == money("1900.10"))
    }
}
