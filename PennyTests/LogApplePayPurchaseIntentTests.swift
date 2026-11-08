import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("LogApplePayPurchaseIntent", .serialized, .isolatedTestResources)
@MainActor
struct LogApplePayPurchaseIntentTests {

    @Test("perform() inserts a Wallet expense through the shared store")
    func performInsertsExpense() async throws {
        let intent = LogApplePayPurchaseIntent()
        intent.amount = "12.34"
        intent.merchant = "Intent Cafe"
        intent.currencyCode = "CAD"
        intent.cardName = "Test Card"

        _ = try await intent.perform()

        let rows = try fetchWalletExpenses()
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Intent Cafe")
        #expect(rows.first?.amount == Decimal(string: "12.34"))
        #expect(rows.first?.importSource == .applePayShortcut)
        #expect(rows.first?.categoryName == "Food")
    }

    @Test("perform() dedupes the same Wallet tap")
    func performDedupesSameTap() async throws {
        let intent = LogApplePayPurchaseIntent()
        intent.amount = "7.50"
        intent.merchant = "Duplicate Cafe"
        intent.currencyCode = "CAD"
        intent.cardName = "Visa"

        _ = try await intent.perform()
        _ = try await intent.perform()

        let rows = try fetchWalletExpenses()
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Duplicate Cafe")
        #expect(rows.first?.amount == Decimal(string: "7.5") || rows.first?.amount == Decimal(string: "7.50"))
    }

    @Test("An empty Merchant falls back to Name, then Apple Pay")
    func merchantFallsBack() async throws {
        let named = LogApplePayPurchaseIntent()
        named.amount = "4.25"
        named.merchant = " "
        named.transactionName = "Name Cafe"
        named.currencyCode = "CAD"
        _ = try await named.perform()

        let plain = LogApplePayPurchaseIntent()
        plain.amount = "4.25"
        plain.merchant = ""
        plain.transactionName = ""
        plain.currencyCode = "CAD"
        _ = try await plain.perform()

        let rows = try fetchWalletExpenses()
        #expect(rows.contains { $0.title == "Name Cafe" })
        #expect(rows.contains { $0.title == "Apple Pay" })
    }

    @Test("Private mode on hides amounts in the dialog and still stores the amount")
    func privateModeOnHidesDialogAmount() async throws {
        let logged = WalletPurchaseDialog.logged(
            merchant: "Private Cafe",
            amountText: "$15.75",
            categoryName: "Food",
            isPrivate: true
        )
        let duplicate = WalletPurchaseDialog.duplicate(
            merchant: "Private Cafe",
            amountText: "$15.75",
            isPrivate: true
        )
        #expect(logged == "Logged a purchase at Private Cafe.")
        #expect(duplicate == "Already logged a purchase at Private Cafe.")
        #expect(!logged.contains("15"))
        #expect(!logged.contains("$"))
        #expect(!duplicate.contains("15"))
        #expect(!duplicate.contains("$"))

        let defaults = try #require(UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite))
        PrivateModeDefaults.setEnabled(true, in: defaults)
        let intent = LogApplePayPurchaseIntent()
        intent.amount = "15.75"
        intent.merchant = "Private Cafe"
        intent.currencyCode = "CAD"
        _ = try await intent.perform()

        let rows = try fetchWalletExpenses()
        #expect(rows.count == 1)
        #expect(rows.first?.amount == Decimal(string: "15.75"))
        #expect(rows.first?.title == "Private Cafe")
    }

    @Test("Private mode off includes the amount in the dialog")
    func privateModeOffShowsAmount() {
        let logged = WalletPurchaseDialog.logged(
            merchant: "Cafe",
            amountText: "$12.34",
            categoryName: "Food",
            isPrivate: false
        )
        let duplicate = WalletPurchaseDialog.duplicate(
            merchant: "Cafe",
            amountText: "$12.34",
            isPrivate: false
        )
        #expect(logged == "Logged $12.34 at Cafe under Food.")
        #expect(duplicate == "Already logged $12.34 at Cafe.")
        #expect(logged.contains("$12.34"))
        #expect(duplicate.contains("$12.34"))
    }

    @Test("USD and decimal-comma amounts are what the intent parses")
    func parsesUSDAndDecimalCommaAmounts() {
        let enUS = Locale(identifier: "en_US")
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "US$9.99", currencyCode: "USD", locale: enUS) == Decimal(string: "9.99"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "12,50", locale: Locale(identifier: "de_DE")) == Decimal(string: "12.50"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "1.234,56", currencyCode: "EUR") == Decimal(string: "1234.56"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "1,234.56", currencyCode: "USD", locale: enUS) == Decimal(string: "1234.56"))
    }

    @Test("A failed save is reported to Shortcuts")
    func saveErrorReachesShortcuts() async {
        let intent = LogApplePayPurchaseIntent()
        intent.amount = "2.00"
        intent.merchant = "Save Fail"
        intent.currencyCode = "CAD"
        await PennySaveTesting.$forcedError.withValue(PennyForcedSaveFailure()) {
            do {
                _ = try await intent.perform()
                Issue.record("Expected perform() to throw when the save fails")
            } catch let error as ApplePayCaptureSaveError {
                #expect(error.localizedDescription.localizedCaseInsensitiveContains("save"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("perform() rejects a zero amount")
    func performRejectsZero() async {
        let intent = LogApplePayPurchaseIntent()
        intent.amount = "0"
        intent.merchant = "Cafe"
        intent.currencyCode = "CAD"
        do {
            _ = try await intent.perform()
            Issue.record("Expected perform() to throw for a zero amount")
        } catch {
            // App Intent surfaces this as a parameter needs-value error.
        }
    }

    private func fetchWalletExpenses() throws -> [Transaction] {
        let container = try PennyPersistence.makeContainer()
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Transaction>())
            .filter { $0.importSource == .applePayShortcut }
    }

    @Test("Intent title avoids the banned Apple brand word")
    func titleAvoidsAppleBrandWord() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Penny/Intents/LogApplePayPurchaseIntent.swift"),
            encoding: .utf8
        )
        #expect(source.contains("Log Wallet Purchase"))
        #expect(!source.contains("title: LocalizedStringResource = \"Log Apple"))
        #expect(source.contains("captureUsingSharedStore"))
        #expect(source.contains("WidgetCenter.shared.reloadTimelines(ofKind: kind)"))
        #expect(!source.contains("reloadAllTimelines"))
        #expect(source.contains("struct TogglePrivateModeIntent"))
    }
}
