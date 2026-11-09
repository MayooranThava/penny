import Foundation
import SwiftData
import WidgetKit

enum QuickAddExpenseError: LocalizedError, Equatable {
    case invalidAmount

    var errorDescription: String? {
        "Enter an amount greater than zero."
    }
}

struct QuickAddExpenseOutcome: Equatable {
    var title: String
    var amount: Decimal
    var currencyCode: String
    var categoryName: String
    var note: String
}

enum QuickAddExpenseLogic {
    static func amount(from value: Double) -> Decimal? {
        let decimal = ApplePayCaptureLogic.money(fromApplePayAmount: value)
        guard decimal > 0 else { return nil }
        return decimal
    }

    static func currencyCode(settingsCode: String?, locale: Locale) -> String {
        let trimmed = settingsCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed.uppercased()
        }
        if let code = locale.currency?.identifier, !code.isEmpty {
            return code.uppercased()
        }
        return "CAD"
    }

    static func title(merchant: String?) -> String {
        let trimmed = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Expense" : trimmed
    }

    struct CategoryChoice: Equatable {
        var name: String
        var createNew: Bool
    }

    /// Match a category the user already has, ignoring case. Create one only when
    /// nothing stored matches. An empty name means Other.
    static func categoryChoice(spoken: String?, existingNames: [String]) -> CategoryChoice {
        let trimmed = spoken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let requested = trimmed.isEmpty ? "Other" : trimmed
        if let match = existingNames.first(where: { $0.caseInsensitiveCompare(requested) == .orderedSame }) {
            return CategoryChoice(name: match, createNew: false)
        }
        if let catalog = CategoryCatalog.defaults.first(where: { $0.name.caseInsensitiveCompare(requested) == .orderedSame }) {
            return CategoryChoice(name: catalog.name, createNew: true)
        }
        return CategoryChoice(name: requested, createNew: true)
    }
}

enum QuickAddExpenseDialog {
    static func added(merchant: String, amountText: String, hidesAmount: Bool) -> String {
        let place = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if hidesAmount {
            if place.isEmpty || place == "Expense" {
                return "Added an expense."
            }
            return "Added an expense at \(place)."
        }
        if place.isEmpty || place == "Expense" {
            return "Added \(amountText)."
        }
        return "Added \(amountText) at \(place)."
    }
}

enum QuickAddWidgetRefresh {
    /// A new expense changes spending totals. Upcoming bills and the savings goal do not.
    static let affectedKinds = [
        PrivateWidgetKinds.safeToSpend,
        PrivateWidgetKinds.monthlyBudget,
        PrivateWidgetKinds.upcomingReminder
    ]

    static var reload: ([String]) -> Void = defaultReload

    static func reloadAffected() {
        reload(affectedKinds)
    }

    static func defaultReload(_ kinds: [String]) {
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

@MainActor
enum QuickAddExpenseService {
    static func addUsingSharedStore(
        amount: Double,
        merchant: String?,
        note: String?,
        category: String?,
        locale: Locale = .current
    ) throws -> QuickAddExpenseOutcome {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try add(
            amount: amount,
            merchant: merchant,
            note: note,
            category: category,
            in: context,
            locale: locale
        )
    }

    static func add(
        amount: Double,
        merchant: String?,
        note: String?,
        category: String?,
        in context: ModelContext,
        locale: Locale = .current
    ) throws -> QuickAddExpenseOutcome {
        guard let decimal = QuickAddExpenseLogic.amount(from: amount) else {
            throw QuickAddExpenseError.invalidAmount
        }
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
        let currency = QuickAddExpenseLogic.currencyCode(settingsCode: settings?.currencyCode, locale: locale)
        let title = QuickAddExpenseLogic.title(merchant: merchant)
        let existing = try context.fetch(FetchDescriptor<BudgetCategory>())
        let choice = QuickAddExpenseLogic.categoryChoice(spoken: category, existingNames: existing.map(\.name))
        let newCategory = choice.createNew ? makeCategory(named: choice.name, existing: existing) : nil
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transaction = Transaction(
            title: title,
            amount: decimal,
            transactionType: .expense,
            categoryName: choice.name,
            note: trimmedNote
        )
        try TransactionInsert.saveNew(transaction, also: newCategory, in: context)
        return QuickAddExpenseOutcome(
            title: title,
            amount: decimal,
            currencyCode: currency,
            categoryName: choice.name,
            note: trimmedNote
        )
    }

    private static func makeCategory(named name: String, existing: [BudgetCategory]) -> BudgetCategory {
        let catalog = CategoryCatalog.defaults.first { $0.name == name }
        let sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        return BudgetCategory(
            name: name,
            icon: catalog?.icon ?? CategoryCatalog.icon(for: name),
            budgetedAmount: 0,
            colourIdentifier: catalog?.colourIdentifier ?? "other",
            sortOrder: sortOrder
        )
    }
}
