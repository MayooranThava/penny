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
        intent.amount = 12.34
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
        intent.amount = 7.50
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

    @Test("perform() rejects a zero amount")
    func performRejectsZero() async {
        let intent = LogApplePayPurchaseIntent()
        intent.amount = 0
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
    }
}
