import AppIntents
import Foundation
import SwiftData

/// Shortcuts action used by a Wallet / Transaction personal automation.
///
/// Apple does not allow apps to create that automation for the user. Penny exposes
/// this intent; Settings walks the user through approving it in Shortcuts.
struct LogApplePayPurchaseIntent: AppIntent {
    // App Store rejects App Intent title/description/phrases that include the brand name.
    static var title: LocalizedStringResource = "Log Wallet Purchase"
    static var description = IntentDescription(
        "Saves a Wallet tap as an expense in Penny. Use this from a Shortcuts automation with the Wallet / Transaction trigger."
    )
    static var openAppWhenRun = false
    /// Keep out of Siri Suggestions — setup stays opt-in via Settings → instructions.
    static var isDiscoverable = false

    @Parameter(
        title: "Amount",
        description: "Map this to Currency Amount from Shortcut Input."
    )
    var amount: Double

    @Parameter(
        title: "Merchant",
        description: "Map this to Name from Shortcut Input.",
        default: ""
    )
    var merchant: String

    @Parameter(
        title: "Currency Code",
        description: "Map this to Currency Code from Shortcut Input.",
        default: ""
    )
    var currencyCode: String

    @Parameter(
        title: "Card Name",
        description: "Optional. Map this to Card or Pass from Shortcut Input.",
        default: ""
    )
    var cardName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)") {
            \.$currencyCode
            \.$cardName
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try ApplePayCaptureService.captureUsingSharedStore(
            amount: amount,
            merchant: merchant,
            currencyCode: currencyCode,
            cardName: cardName
        )

        switch result {
        case .inserted(let title, let amountValue, let categoryName):
            let money = MoneyFormatters.compact(from: amountValue, currencyCode: preferredCurrencyCode())
            return .result(
                dialog: IntentDialog("Logged \(money) at \(title) under \(categoryName).")
            )
        case .duplicate(let title, let amountValue):
            let money = MoneyFormatters.compact(from: amountValue, currencyCode: preferredCurrencyCode())
            return .result(
                dialog: IntentDialog("Already logged \(money) at \(title) today.")
            )
        case .invalidAmount:
            throw $amount.needsValueError("Amount must be greater than zero.")
        }
    }

    @MainActor
    private func preferredCurrencyCode() -> String {
        if !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currencyCode.uppercased()
        }
        do {
            let container = try PennyPersistence.makeContainer()
            let context = ModelContext(container)
            let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
            return settings?.currencyCode ?? "CAD"
        } catch {
            return "CAD"
        }
    }
}

// App Shortcuts / Siri suggestion phrases are intentionally omitted.
// Wallet capture stays opt-in: users find "Log Wallet Purchase" from Settings
// instructions when building a Shortcuts automation — not via proactive Siri prompts.
