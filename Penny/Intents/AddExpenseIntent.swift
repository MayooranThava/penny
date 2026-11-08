import AppIntents
import Foundation

/// Spoken shortcut for adding an expense. Amount is required. Merchant, note, and
/// category are optional. Currency comes from Penny settings, then the phone locale.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription(
        "Adds an expense from the amount you say, with an optional merchant, note, and category."
    )
    static var openAppWhenRun = false
    static var isDiscoverable = true

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Merchant", default: "")
    var merchant: String

    @Parameter(title: "Note", default: "")
    var note: String

    @Parameter(title: "Category", default: "")
    var category: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount)") {
            \.$merchant
            \.$note
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try QuickAddExpenseService.addUsingSharedStore(
            amount: amount,
            merchant: merchant,
            note: note,
            category: category
        )
        let reply = Self.reply(for: outcome, hidesAmount: Self.hidesTransactionAmounts)
        QuickAddWidgetRefresh.reloadAffected()
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: reply)))
    }

    /// One read of the in-memory Private mode choice. It does not open UserDefaults.
    @MainActor
    static var hidesTransactionAmounts: Bool {
        PrivateModeController.shared.masks(.transactions)
    }

    @MainActor
    static func reply(
        for outcome: QuickAddExpenseOutcome,
        hidesAmount: Bool,
        locale: Locale = .current
    ) -> String {
        let amountText = MoneyFormatters.string(
            from: outcome.amount,
            currencyCode: outcome.currencyCode,
            locale: locale
        )
        return QuickAddExpenseDialog.added(
            merchant: outcome.title,
            amountText: amountText,
            hidesAmount: hidesAmount
        )
    }
}
