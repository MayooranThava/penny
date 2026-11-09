import AppIntents
import Foundation

/// Spoken shortcut for adding an expense. Amount is required. Merchant, note, and
/// category are optional. Currency comes from Penny settings, then the phone locale.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription(
        "Adds an expense from the amount you say, with an optional merchant, note, and category."
    )
    static let openAppWhenRun = false
    static var isDiscoverable = true

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Merchant", default: "")
    var merchant: String

    @Parameter(title: "Note", default: "")
    var note: String

    @Parameter(title: "Category", default: "")
    var category: String

    /// Tests pass a throwaway suite. Nil uses the active suite, which is the App Group in the app.
    var privateModeDefaults: UserDefaults?

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
        let reply = Self.reply(for: outcome, hidesAmount: Self.hidesTransactionAmounts(in: privateModeDefaults))
        QuickAddWidgetRefresh.reloadAffected()
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: reply)))
    }

    /// One read of the saved Private mode choice for this run.
    @MainActor
    static func hidesTransactionAmounts(in defaults: UserDefaults?) -> Bool {
        let store = defaults ?? UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite)
        guard let store else { return false }
        return PrivateModeStorage.load(from: store).masks(.transactions)
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
