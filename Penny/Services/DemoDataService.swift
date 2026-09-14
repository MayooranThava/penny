import Foundation
import SwiftData

/// Default budget category definitions shared by demo seeding and fresh setup.
enum CategoryCatalog {
    struct Definition {
        let name: String
        let icon: String
        let colourIdentifier: String
        let defaultBudget: Decimal
        let sortOrder: Int
    }

    static let defaults: [Definition] = [
        .init(name: "Housing", icon: "house.fill", colourIdentifier: "housing", defaultBudget: 1_900, sortOrder: 0),
        .init(name: "Food", icon: "fork.knife", colourIdentifier: "food", defaultBudget: 550, sortOrder: 1),
        .init(name: "Transportation", icon: "car.fill", colourIdentifier: "transportation", defaultBudget: 450, sortOrder: 2),
        .init(name: "Shopping", icon: "bag.fill", colourIdentifier: "shopping", defaultBudget: 300, sortOrder: 3),
        .init(name: "Entertainment", icon: "ticket.fill", colourIdentifier: "entertainment", defaultBudget: 250, sortOrder: 4),
        .init(name: "Health", icon: "heart.fill", colourIdentifier: "health", defaultBudget: 120, sortOrder: 5),
        .init(name: "Subscriptions", icon: "rectangle.stack.fill", colourIdentifier: "subscriptions", defaultBudget: 95, sortOrder: 6),
        .init(name: "Travel", icon: "airplane", colourIdentifier: "travel", defaultBudget: 150, sortOrder: 7),
        .init(name: "Savings", icon: "leaf.fill", colourIdentifier: "savings", defaultBudget: 1_000, sortOrder: 8),
        .init(name: "Other", icon: "ellipsis.circle.fill", colourIdentifier: "other", defaultBudget: 100, sortOrder: 9)
    ]

    static func icon(for categoryName: String) -> String {
        defaults.first { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }?.icon
            ?? "tag.fill"
    }
}

@MainActor
enum DemoDataService {
    static let demoMonthlyIncome: Decimal = 6_200
    static let demoPlannedSavings: Decimal = 1_000

    static func resetAll(in context: ModelContext) throws {
        try deleteAll(in: context)
        try seedDemo(in: context, markOnboardingComplete: true, replaceExisting: true)
    }

    static func deleteAll(in context: ModelContext) throws {
        try context.delete(model: Transaction.self)
        try context.delete(model: BudgetCategory.self)
        try context.delete(model: Budget.self)
        try context.delete(model: RecurringBill.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: Debt.self)
        try context.delete(model: FinancialAccount.self)
        try context.delete(model: UserSettings.self)
        try context.save()
    }

    /// True when the store already has user-facing records (excluding a lone empty settings row).
    static func hasPersistedUserContent(in context: ModelContext) throws -> Bool {
        if try fetchExists(Transaction.self, in: context) { return true }
        if try fetchExists(RecurringBill.self, in: context) { return true }
        if try fetchExists(Debt.self, in: context) { return true }
        if try fetchExists(SavingsGoal.self, in: context) { return true }
        if try fetchExists(FinancialAccount.self, in: context) { return true }
        if try fetchExists(BudgetCategory.self, in: context) { return true }
        return try fetchExists(Budget.self, in: context)
    }

    private static func fetchExists<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    static func seedFresh(
        in context: ModelContext,
        currencyCode: String,
        monthlyIncome: Decimal,
        appearance: AppAppearance = .system,
        displayName: String = "",
        replaceExisting: Bool = false
    ) throws {
        if try hasPersistedUserContent(in: context), !replaceExisting {
            // Protect existing installs: never wipe just because a seed was requested without opt-in.
            try restoreSettingsIfMissing(in: context, currencyCode: currencyCode, monthlyIncome: monthlyIncome, appearance: appearance, displayName: displayName)
            return
        }

        try deleteAll(in: context)

        for def in CategoryCatalog.defaults {
            let amount: Decimal = def.name == "Savings" ? 0 : 0
            context.insert(
                BudgetCategory(
                    name: def.name,
                    icon: def.icon,
                    budgetedAmount: amount,
                    colourIdentifier: def.colourIdentifier,
                    sortOrder: def.sortOrder
                )
            )
        }

        let monthStart = DateHelpers.startOfMonth()
        context.insert(Budget(monthStart: monthStart, plannedSpending: 0))

        context.insert(
            FinancialAccount(name: "Everyday Chequing", accountType: .chequing, balance: 0, sortOrder: 0)
        )
        context.insert(
            FinancialAccount(name: "Savings", accountType: .savings, balance: 0, sortOrder: 1)
        )

        let settings = UserSettings(
            currencyCode: currencyCode,
            monthlyIncome: monthlyIncome,
            plannedMonthlySavings: 0,
            hasCompletedOnboarding: true,
            billRemindersEnabled: true,
            appearance: appearance,
            usingDemoData: false,
            displayName: displayName
        )
        context.insert(settings)
        try context.save()
    }

    static func seedDemo(
        in context: ModelContext,
        currencyCode: String = "CAD",
        markOnboardingComplete: Bool = true,
        replaceExisting: Bool = false
    ) throws {
        if try hasPersistedUserContent(in: context), !replaceExisting {
            try restoreSettingsIfMissing(
                in: context,
                currencyCode: currencyCode,
                monthlyIncome: nil,
                appearance: nil,
                displayName: nil,
                markOnboardingComplete: markOnboardingComplete
            )
            return
        }

        try deleteAll(in: context)

        let calendar = Calendar.current
        let now = Date.now
        let monthStart = DateHelpers.startOfMonth(for: now)

        // Categories with budgets matching product brief
        let budgets: [(String, Decimal)] = [
            ("Housing", 1_900),
            ("Food", 550),
            ("Transportation", 450),
            ("Shopping", 300),
            ("Entertainment", 250),
            ("Health", 120),
            ("Subscriptions", 95),
            ("Travel", 150),
            ("Savings", 1_000),
            ("Other", 100)
        ]

        for def in CategoryCatalog.defaults {
            let budgeted = budgets.first { $0.0 == def.name }?.1 ?? def.defaultBudget
            context.insert(
                BudgetCategory(
                    name: def.name,
                    icon: def.icon,
                    budgetedAmount: budgeted,
                    colourIdentifier: def.colourIdentifier,
                    sortOrder: def.sortOrder
                )
            )
        }

        let planned = budgets.map(\.1).filter { $0 != 1_000 }.reduce(Decimal(0), +) // exclude savings envelope from "planned spending" hero optionally
        // Product brief: planned spending $3,400
        context.insert(Budget(monthStart: monthStart, plannedSpending: 3_400))
        _ = planned

        // Accounts
        context.insert(FinancialAccount(name: "Everyday Chequing", accountType: .chequing, balance: 4_280, sortOrder: 0))
        context.insert(FinancialAccount(name: "High-Interest Savings", accountType: .savings, balance: 12_450, sortOrder: 1))
        context.insert(FinancialAccount(name: "Investment Account", accountType: .investment, balance: 8_200, sortOrder: 2))
        context.insert(FinancialAccount(name: "Visa", accountType: .creditCard, balance: -2_850, sortOrder: 3))

        // Goals
        let houseTarget = calendar.date(byAdding: .month, value: 20, to: now)
        context.insert(
            SavingsGoal(
                name: "House",
                targetAmount: 30_000,
                currentAmount: 18_400,
                targetDate: houseTarget,
                icon: "house.fill",
                colourIdentifier: "housing"
            )
        )
        context.insert(
            SavingsGoal(
                name: "Emergency Fund",
                targetAmount: 10_000,
                currentAmount: 8_100,
                targetDate: calendar.date(byAdding: .month, value: 4, to: now),
                icon: "shield.fill",
                colourIdentifier: "savings"
            )
        )
        context.insert(
            SavingsGoal(
                name: "Vacation",
                targetAmount: 4_000,
                currentAmount: 2_100,
                targetDate: calendar.date(byAdding: .month, value: 8, to: now),
                icon: "airplane",
                colourIdentifier: "travel"
            )
        )

        // Debt — monthly targets reduce Safe to Spend on Home
        context.insert(
            Debt(
                name: "BMO VIP Porter",
                originalBalance: 6_500,
                currentBalance: 5_800,
                interestRate: 21.99,
                minimumPayment: 150,
                plannedMonthlyPayment: 800,
                dueDay: 18,
                icon: "creditcard.fill"
            )
        )

        // Bills
        let bills: [(String, Decimal, Int, BillRecurrence, String, String)] = [
            ("Rent", 1_500, 20, .monthly, "Housing", "house.fill"),
            ("Internet", 79.99, 15, .monthly, "Subscriptions", "wifi"),
            ("Phone", 65, 20, .monthly, "Subscriptions", "iphone"),
            ("Car Payment", 350, 11, .monthly, "Transportation", "car.fill"),
            ("Streaming", 22.99, 8, .monthly, "Subscriptions", "play.tv.fill"),
            ("Gym", 45, 5, .biweekly, "Health", "figure.run")
        ]

        for bill in bills {
            let start = DateHelpers.nextDueDate(dueDay: bill.2, from: now)
            context.insert(
                RecurringBill(
                    name: bill.0,
                    amount: bill.1,
                    dueDay: bill.2,
                    categoryName: bill.4,
                    recurrence: bill.3,
                    nextDueDate: DateHelpers.nextDueDate(
                        startDate: start,
                        recurrence: bill.3,
                        dueDay: bill.2,
                        from: now
                    ),
                    startDate: start,
                    reminderEnabled: true,
                    reminderDaysBefore: 2,
                    isActive: true,
                    icon: bill.5
                )
            )
        }

        // Income this month
        let payday1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monthStart.addingTimeInterval(86400 * 1)) ?? monthStart
        let payday2 = calendar.date(byAdding: .day, value: 14, to: payday1) ?? now
        context.insert(Transaction(title: "Salary", amount: 3_100, date: payday1, transactionType: .income, categoryName: "Income", note: "Bi-weekly pay"))
        context.insert(Transaction(title: "Salary", amount: 3_100, date: min(payday2, now), transactionType: .income, categoryName: "Income", note: "Bi-weekly pay"))

        // Expenses — tuned so totals feel realistic (~$2,615 discretionary+housing mix for demo)
        let expenseSamples: [(String, Decimal, String, Int)] = [
            ("Rent", 1_500, "Housing", 1),
            ("FreshCo", 63.42, "Food", 0),
            ("Gas", 72.10, "Transportation", 0),
            ("Metro Groceries", 88.25, "Food", 2),
            ("Coffee Bar", 6.75, "Food", 0),
            ("Uber", 18.40, "Transportation", 1),
            ("Indie Cinema", 32.00, "Entertainment", 3),
            ("Spotify", 12.99, "Subscriptions", 5),
            ("Netflix", 22.99, "Subscriptions", 8),
            ("Uniqlo", 84.50, "Shopping", 4),
            ("Pharmacy", 28.60, "Health", 6),
            ("Dinner Out", 64.20, "Food", 7),
            ("Transit Pass", 120.00, "Transportation", 2),
            ("Bookstore", 27.80, "Shopping", 9),
            ("Farmers Market", 41.15, "Food", 10),
            ("Concert Tickets", 95.00, "Entertainment", 11),
            ("Internet", 79.99, "Subscriptions", 15),
            ("Climbing Gym", 48.00, "Health", 12),
            ("HomeSense", 62.40, "Shopping", 13),
            ("Lunch", 14.80, "Food", 14)
        ]

        for sample in expenseSamples {
            let dayOffset = sample.3
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) ?? now
            // Only include transactions up to "today" for a natural feel; allow a few future-dated for calendar realism
            let clamped = min(date, now.addingTimeInterval(86400 * 2))
            context.insert(
                Transaction(
                    title: sample.0,
                    amount: sample.1,
                    date: clamped,
                    transactionType: .expense,
                    categoryName: sample.2
                )
            )
        }

        // Prior month sample for insight comparisons
        guard let priorMonth = calendar.date(byAdding: .month, value: -1, to: monthStart) else {
            throw DemoDataError.calendarFailure
        }
        let priorExpenses: [(String, Decimal, String, Int)] = [
            ("Rent", 1_500, "Housing", 1),
            ("Groceries", 520, "Food", 5),
            ("Gas", 95, "Transportation", 8),
            ("Dining", 140, "Food", 12),
            ("Shopping Haul", 210, "Shopping", 15),
            ("Movies", 55, "Entertainment", 18),
            ("Subscriptions Bundle", 90, "Subscriptions", 4)
        ]
        for sample in priorExpenses {
            let date = calendar.date(byAdding: .day, value: sample.3, to: priorMonth) ?? priorMonth
            context.insert(
                Transaction(
                    title: sample.0,
                    amount: sample.1,
                    date: date,
                    transactionType: .expense,
                    categoryName: sample.2
                )
            )
        }

        let settings = UserSettings(
            currencyCode: currencyCode,
            monthlyIncome: demoMonthlyIncome,
            plannedMonthlySavings: demoPlannedSavings,
            hasCompletedOnboarding: markOnboardingComplete,
            billRemindersEnabled: true,
            appearance: .system,
            usingDemoData: true,
            displayName: "Mayooran"
        )
        context.insert(settings)
        try context.save()
    }

    /// Recreate or refresh settings without deleting transactions/bills/goals.
    private static func restoreSettingsIfMissing(
        in context: ModelContext,
        currencyCode: String,
        monthlyIncome: Decimal?,
        appearance: AppAppearance?,
        displayName: String?,
        markOnboardingComplete: Bool = true
    ) throws {
        if let settings = try context.fetch(FetchDescriptor<UserSettings>()).first {
            settings.currencyCode = currencyCode
            if let monthlyIncome { settings.monthlyIncome = monthlyIncome }
            if let appearance { settings.appearance = appearance }
            if let displayName { settings.displayName = displayName }
            settings.hasCompletedOnboarding = markOnboardingComplete
            try context.save()
            return
        }

        context.insert(
            UserSettings(
                currencyCode: currencyCode,
                monthlyIncome: monthlyIncome ?? 0,
                plannedMonthlySavings: 0,
                hasCompletedOnboarding: markOnboardingComplete,
                billRemindersEnabled: true,
                appearance: appearance ?? .system,
                usingDemoData: false,
                displayName: displayName ?? ""
            )
        )
        try context.save()
    }

    enum DemoDataError: Error {
        case calendarFailure
    }
}

private extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try fetch(descriptor)
        for item in items {
            delete(item)
        }
    }
}
