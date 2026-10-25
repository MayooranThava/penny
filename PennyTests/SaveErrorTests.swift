import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("Save errors", .serialized, .isolatedTestResources)
struct SaveErrorTests {
    @Test("a failed save is shown instead of swallowed")
    @MainActor
    func failedSaveIsShown() throws {
        PennySaveReporter.shared.dismiss()
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Transaction(
            title: "Coffee",
            amount: Decimal(string: "4.75")!,
            transactionType: .expense,
            categoryName: "Food"
        ))

        // A second insert with the same id does not throw on this SDK (the row is updated).
        // Force the failure path the banner is built for.
        try PennySaveTesting.$forcedError.withValue(PennyForcedSaveFailure()) {
            let saved = context.saveOrSurfaceError()
            #expect(saved == false)
        }

        let message = try #require(PennySaveReporter.shared.message)
        #expect(message.contains("Couldn’t save"))
        #expect(context.saveOrSurfaceError() == true)
        let rows = try context.fetch(FetchDescriptor<Transaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.amount == Decimal(string: "4.75"))
    }
}
