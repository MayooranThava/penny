import Foundation
import SwiftData

/// Frozen SwiftData model for the v1.0.3 App Store schema.
///
/// Copied from `Penny/Models/Models.swift` at commit `dca913c` (marketing version 1.0.4's
/// predecessor, the v1.0.3 bump). Stored properties match that build so a store written
/// with these types has the same entity hash the shipping v1.0.3 app produced.
///
/// This environment cannot launch that binary. Upgrade tests write a store with this
/// schema, then open it through `PennyMigrationPlan` the way an update would.
/// Do not add properties here. A new shipped shape gets its own version.
enum PennySchemaV103: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 3)

    static var models: [any PersistentModel.Type] {
        [
            Transaction.self,
            BudgetCategory.self,
            Budget.self,
            RecurringBill.self,
            SavingsGoal.self,
            Debt.self,
            FinancialAccount.self,
            UserSettings.self
        ]
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
        var importSourceRaw: String = TransactionImportSource.manual.rawValue
        var externalIdentifier: String = ""
        var merchantName: String = ""
        var cardName: String = ""

        init(
            id: UUID,
            title: String,
            amount: Decimal,
            date: Date,
            transactionTypeRaw: String,
            categoryName: String,
            note: String,
            createdAt: Date
        ) {
            self.id = id
            self.title = title
            self.amount = amount
            self.date = date
            self.transactionTypeRaw = transactionTypeRaw
            self.categoryName = categoryName
            self.note = note
            self.createdAt = createdAt
        }
    }

    @Model
    final class BudgetCategory {
        @Attribute(.unique) var id: UUID
        var name: String
        var icon: String
        var budgetedAmount: Decimal
        var colourIdentifier: String
        var sortOrder: Int

        init(id: UUID, name: String, icon: String, budgetedAmount: Decimal, colourIdentifier: String, sortOrder: Int) {
            self.id = id
            self.name = name
            self.icon = icon
            self.budgetedAmount = budgetedAmount
            self.colourIdentifier = colourIdentifier
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class Budget {
        @Attribute(.unique) var id: UUID
        var monthStart: Date
        var plannedSpending: Decimal
        var notes: String

        init(id: UUID, monthStart: Date, plannedSpending: Decimal, notes: String) {
            self.id = id
            self.monthStart = monthStart
            self.plannedSpending = plannedSpending
            self.notes = notes
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
        var startDate: Date
        var reminderEnabled: Bool
        var reminderDaysBefore: Int
        var isActive: Bool
        var icon: String

        init(
            id: UUID,
            name: String,
            amount: Decimal,
            dueDay: Int,
            categoryName: String,
            recurrenceRaw: String,
            nextDueDate: Date,
            startDate: Date,
            reminderEnabled: Bool,
            reminderDaysBefore: Int,
            isActive: Bool,
            icon: String
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.dueDay = dueDay
            self.categoryName = categoryName
            self.recurrenceRaw = recurrenceRaw
            self.nextDueDate = nextDueDate
            self.startDate = startDate
            self.reminderEnabled = reminderEnabled
            self.reminderDaysBefore = reminderDaysBefore
            self.isActive = isActive
            self.icon = icon
        }
    }

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
            id: UUID,
            name: String,
            targetAmount: Decimal,
            currentAmount: Decimal,
            targetDate: Date?,
            icon: String,
            createdAt: Date,
            colourIdentifier: String
        ) {
            self.id = id
            self.name = name
            self.targetAmount = targetAmount
            self.currentAmount = currentAmount
            self.targetDate = targetDate
            self.icon = icon
            self.createdAt = createdAt
            self.colourIdentifier = colourIdentifier
        }
    }

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
            id: UUID,
            name: String,
            originalBalance: Decimal,
            currentBalance: Decimal,
            interestRate: Decimal,
            minimumPayment: Decimal,
            plannedMonthlyPayment: Decimal,
            dueDay: Int,
            icon: String
        ) {
            self.id = id
            self.name = name
            self.originalBalance = originalBalance
            self.currentBalance = currentBalance
            self.interestRate = interestRate
            self.minimumPayment = minimumPayment
            self.plannedMonthlyPayment = plannedMonthlyPayment
            self.dueDay = dueDay
            self.icon = icon
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

        init(id: UUID, name: String, typeRaw: String, balance: Decimal, isIncludedInNetWorth: Bool, sortOrder: Int) {
            self.id = id
            self.name = name
            self.typeRaw = typeRaw
            self.balance = balance
            self.isIncludedInNetWorth = isIncludedInNetWorth
            self.sortOrder = sortOrder
        }
    }

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
        var applePayCaptureConfigured: Bool = false
        var accentThemeRaw: String = AccentTheme.mint.rawValue

        init(
            id: UUID,
            currencyCode: String,
            monthlyIncome: Decimal,
            plannedMonthlySavings: Decimal,
            hasCompletedOnboarding: Bool,
            billRemindersEnabled: Bool,
            appearanceRaw: String,
            usingDemoData: Bool,
            displayName: String,
            applePayCaptureConfigured: Bool,
            accentThemeRaw: String
        ) {
            self.id = id
            self.currencyCode = currencyCode
            self.monthlyIncome = monthlyIncome
            self.plannedMonthlySavings = plannedMonthlySavings
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.billRemindersEnabled = billRemindersEnabled
            self.appearanceRaw = appearanceRaw
            self.usingDemoData = usingDemoData
            self.displayName = displayName
            self.applePayCaptureConfigured = applePayCaptureConfigured
            self.accentThemeRaw = accentThemeRaw
        }
    }
}
