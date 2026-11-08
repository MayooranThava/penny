import AppIntents
import Foundation
import SwiftData
import WidgetKit

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
    /// Must be true or Shortcuts will not list Penny actions at all.
    /// In-app setup stays optional (Settings only) — this only makes the action findable
    /// when the user is already building an automation.
    static var isDiscoverable = true

    @Parameter(
        title: "Amount",
        description: "Map this to Currency Amount from Shortcut Input."
    )
    var amount: Double

    @Parameter(
        title: "Amount (text)",
        description: "Optional. Used when Amount is written with a comma, such as 12,50.",
        default: ""
    )
    var amountText: String

    @Parameter(
        title: "Merchant",
        description: "Map this to Merchant from Shortcut Input.",
        default: ""
    )
    var merchant: String

    @Parameter(
        title: "Name",
        description: "Used when Merchant is empty. Map this to Name from Shortcut Input.",
        default: ""
    )
    var transactionName: String

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
            \.$amountText
            \.$transactionName
            \.$currencyCode
            \.$cardName
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try ApplePayCaptureService.captureUsingSharedStore(
            amount: try resolvedAmount(),
            merchant: merchant,
            name: transactionName,
            currencyCode: currencyCode,
            cardName: cardName
        )

        let isPrivate = Self.privateModeIsOn
        switch result {
        case .inserted(let title, let amountValue, let categoryName):
            reloadTransactionAndTotalWidgets()
            let money = MoneyFormatters.compact(from: amountValue, currencyCode: preferredCurrencyCode())
            return .result(
                dialog: IntentDialog(LocalizedStringResource(stringLiteral: WalletPurchaseDialog.logged(
                    merchant: title,
                    amountText: money,
                    categoryName: categoryName,
                    isPrivate: isPrivate
                )))
            )
        case .duplicate(let title, let amountValue):
            let money = MoneyFormatters.compact(from: amountValue, currencyCode: preferredCurrencyCode())
            return .result(
                dialog: IntentDialog(LocalizedStringResource(stringLiteral: WalletPurchaseDialog.duplicate(
                    merchant: title,
                    amountText: money,
                    isPrivate: isPrivate
                )))
            )
        case .invalidAmount:
            throw $amount.needsValueError("Amount must be greater than zero.")
        }
    }

    /// `amountText` wins when it parses. Otherwise the 1.3 numeric `amount` is used.
    @MainActor
    private func resolvedAmount() throws -> Double {
        let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty,
           let parsed = ApplePayCaptureLogic.money(fromShortcutAmount: text, currencyCode: currencyCode) {
            return NSDecimalNumber(decimal: parsed).doubleValue
        }
        guard amount > 0 else {
            throw $amount.needsValueError("Amount must be greater than zero.")
        }
        return amount
    }

    @MainActor
    private static var privateModeIsOn: Bool {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite) else {
            return false
        }
        return PrivateModeDefaults.isEnabled(in: defaults)
    }

    /// Safe to Spend, monthly budget, the savings goal, upcoming bills, and the
    /// reminder each show a total or a list of transactions. Other timelines stay put.
    @MainActor
    private func reloadTransactionAndTotalWidgets() {
        let kinds = [
            PrivateWidgetKinds.safeToSpend,
            PrivateWidgetKinds.monthlyBudget,
            PrivateWidgetKinds.savingsGoal,
            PrivateWidgetKinds.upcomingBills,
            PrivateWidgetKinds.upcomingReminder
        ]
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
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

enum WalletPurchaseDialog {
    static func logged(merchant: String, amountText: String, categoryName: String, isPrivate: Bool) -> String {
        if isPrivate {
            return "Logged a purchase at \(merchant)."
        }
        return "Logged \(amountText) at \(merchant) under \(categoryName)."
    }

    static func duplicate(merchant: String, amountText: String, isPrivate: Bool) -> String {
        if isPrivate {
            return "Already logged a purchase at \(merchant)."
        }
        return "Already logged \(amountText) at \(merchant)."
    }
}

/// Registers Penny under Shortcuts → Apps so “Log Wallet Purchase” can be found.
/// Phrases avoid the banned brand word. This does not force setup inside Penny —
/// it only makes the action discoverable when the user is already in Shortcuts.
struct TogglePrivateModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Private Mode"
    static var description = IntentDescription("Hides or shows totals. Does not reload your transactions.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        PrivateModeController.shared.toggle()
        return .result()
    }
}

struct PennyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogApplePayPurchaseIntent(),
            phrases: [
                "Log Wallet purchase in \(.applicationName)",
                "Add Wallet purchase to \(.applicationName)"
            ],
            shortTitle: "Log Wallet Tap",
            systemImageName: "wallet.pass.fill"
        )
        AppShortcut(
            intent: TogglePrivateModeIntent(),
            phrases: [
                "Toggle \(.applicationName) private mode"
            ],
            shortTitle: "Toggle Penny private mode",
            systemImageName: "eye.slash"
        )
    }
}
