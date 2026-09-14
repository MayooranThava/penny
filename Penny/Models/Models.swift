import Foundation
import SwiftData
import SwiftUI

// MARK: - Transaction

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Decimal
    var date: Date
    var transactionTypeRaw: String
    var categoryName: String
    var note: String
    var createdAt: Date

    var transactionType: TransactionType {
        get { TransactionType(rawValue: transactionTypeRaw) ?? .expense }
        set { transactionTypeRaw = newValue.rawValue }
    }

    /// Signed amount: income positive, expense negative for net calculations.
    var signedAmount: Decimal {
        transactionType == .income ? amount : -amount
    }

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        date: Date = .now,
        transactionType: TransactionType,
        categoryName: String,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.amount = abs(amount)
        self.date = date
        self.transactionTypeRaw = transactionType.rawValue
        self.categoryName = categoryName
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Budget Category

@Model
final class BudgetCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var budgetedAmount: Decimal
    var colourIdentifier: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        budgetedAmount: Decimal,
        colourIdentifier: String,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.budgetedAmount = budgetedAmount
        self.colourIdentifier = colourIdentifier
        self.sortOrder = sortOrder
    }
}

// MARK: - Budget (monthly envelope)

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var monthStart: Date
    var plannedSpending: Decimal
    var notes: String

    init(
        id: UUID = UUID(),
        monthStart: Date,
        plannedSpending: Decimal,
        notes: String = ""
    ) {
        self.id = id
        self.monthStart = monthStart
        self.plannedSpending = plannedSpending
        self.notes = notes
    }
}

// MARK: - Recurring Bill

enum BillRecurrence: String, Codable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

@Model
final class RecurringBill {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var dueDay: Int
    var categoryName: String
    var recurrenceRaw: String
    var nextDueDate: Date
    /// Anchor date for weekly / biweekly schedules (and preferred first due for monthly).
    var startDate: Date
    var reminderEnabled: Bool
    var reminderDaysBefore: Int
    var isActive: Bool
    var icon: String

    var recurrence: BillRecurrence {
        get { BillRecurrence(rawValue: recurrenceRaw) ?? .monthly }
        set { recurrenceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        dueDay: Int,
        categoryName: String,
        recurrence: BillRecurrence = .monthly,
        nextDueDate: Date,
        startDate: Date? = nil,
        reminderEnabled: Bool = true,
        reminderDaysBefore: Int = 2,
        isActive: Bool = true,
        icon: String = "doc.text.fill"
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDay = max(1, min(28, dueDay))
        self.categoryName = categoryName
        self.recurrenceRaw = recurrence.rawValue
        self.nextDueDate = nextDueDate
        self.startDate = startDate ?? nextDueDate
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.isActive = isActive
        self.icon = icon
    }
}

// MARK: - Savings Goal

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var icon: String
    var createdAt: Date
    var colourIdentifier: String

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        icon: String = "target",
        createdAt: Date = .now,
        colourIdentifier: String = "savings"
    ) {
        self.id = id
        self.name = name
        self.targetAmount = max(targetAmount, 0)
        self.currentAmount = max(currentAmount, 0)
        self.targetDate = targetDate
        self.icon = icon
        self.createdAt = createdAt
        self.colourIdentifier = colourIdentifier
    }
}

// MARK: - Debt

@Model
final class Debt {
    @Attribute(.unique) var id: UUID
    var name: String
    var originalBalance: Decimal
    var currentBalance: Decimal
    var interestRate: Decimal
    var minimumPayment: Decimal
    var plannedMonthlyPayment: Decimal
    var dueDay: Int
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        originalBalance: Decimal,
        currentBalance: Decimal,
        interestRate: Decimal,
        minimumPayment: Decimal,
        plannedMonthlyPayment: Decimal,
        dueDay: Int = 15,
        icon: String = "creditcard.fill"
    ) {
        self.id = id
        self.name = name
        self.originalBalance = originalBalance
        self.currentBalance = currentBalance
        self.interestRate = interestRate
        self.minimumPayment = minimumPayment
        self.plannedMonthlyPayment = plannedMonthlyPayment
        self.dueDay = max(1, min(28, dueDay))
        self.icon = icon
    }
}

// MARK: - Financial Account

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case chequing
    case savings
    case investment
    case creditCard
    case loan
    case cash
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chequing: return "Chequing"
        case .savings: return "Savings"
        case .investment: return "Investment"
        case .creditCard: return "Credit Card"
        case .loan: return "Loan"
        case .cash: return "Cash"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .chequing: return "building.columns.fill"
        case .savings: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .creditCard: return "creditcard.fill"
        case .loan: return "doc.text.fill"
        case .cash: return "dollarsign.circle.fill"
        case .other: return "wallet.pass.fill"
        }
    }
}

@Model
final class FinancialAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var balance: Decimal
    var isIncludedInNetWorth: Bool
    var sortOrder: Int

    var accountType: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        accountType: AccountType,
        balance: Decimal,
        isIncludedInNetWorth: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.typeRaw = accountType.rawValue
        self.balance = balance
        self.isIncludedInNetWorth = isIncludedInNetWorth
        self.sortOrder = sortOrder
    }
}

// MARK: - User Settings (SwiftData)

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var currencyCode: String
    var monthlyIncome: Decimal
    var plannedMonthlySavings: Decimal
    var hasCompletedOnboarding: Bool
    var billRemindersEnabled: Bool
    var appearanceRaw: String
    var usingDemoData: Bool
    var displayName: String

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        currencyCode: String = "CAD",
        monthlyIncome: Decimal = 0,
        plannedMonthlySavings: Decimal = 0,
        hasCompletedOnboarding: Bool = false,
        billRemindersEnabled: Bool = true,
        appearance: AppAppearance = .system,
        usingDemoData: Bool = false,
        displayName: String = ""
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.monthlyIncome = monthlyIncome
        self.plannedMonthlySavings = plannedMonthlySavings
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.billRemindersEnabled = billRemindersEnabled
        self.appearanceRaw = appearance.rawValue
        self.usingDemoData = usingDemoData
        self.displayName = displayName
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
