import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("ApplePayCaptureService")
@MainActor
struct ApplePayCaptureServiceTests {

    @Test("Inserts an expense and dedupes the same external id")
    func insertAndDedupe() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let first = try ApplePayCaptureService.capture(
            amount: 18.50,
            merchant: "Starbucks",
            currencyCode: "CAD",
            cardName: "Apple Card",
            in: context
        )
        guard case .inserted(let title, let amount, let category) = first else {
            Issue.record("Expected inserted, got \(first)")
            return
        }
        #expect(title == "Starbucks")
        #expect(amount == Decimal(string: "18.5") || amount == Decimal(string: "18.50"))
        #expect(category == "Food")

        let second = try ApplePayCaptureService.capture(
            amount: 18.50,
            merchant: "Starbucks",
            currencyCode: "CAD",
            cardName: "Apple Card",
            in: context
        )
        guard case .duplicate = second else {
            Issue.record("Expected duplicate, got \(second)")
            return
        }

        let rows = try context.fetch(FetchDescriptor<Transaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.importSource == .applePayShortcut)
    }

    @Test("Returns invalidAmount for zero")
    func invalidAmount() throws {
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let result = try ApplePayCaptureService.capture(
            amount: 0,
            merchant: "Cafe",
            currencyCode: "CAD",
            cardName: nil,
            in: context
        )
        #expect(result == .invalidAmount)
    }
}
