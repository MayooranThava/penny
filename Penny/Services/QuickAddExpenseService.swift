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

    static func categoryName(_ category: String?) -> String {
        let trimmed = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Other" : trimmed
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
        let categoryName = QuickAddExpenseLogic.categoryName(category)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transaction = Transaction(
            title: title,
            amount: decimal,
            transactionType: .expense,
            categoryName: categoryName,
            note: trimmedNote
        )
        try TransactionInsert.saveNew(transaction, in: context)
        return QuickAddExpenseOutcome(
            title: title,
            amount: decimal,
            currencyCode: currency,
            categoryName: categoryName,
            note: trimmedNote
        )
    }
}
