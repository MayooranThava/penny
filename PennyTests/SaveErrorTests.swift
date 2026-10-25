import Foundation
import SwiftData
import Testing
@testable import Penny

@Suite("Save errors", .serialized, .isolatedTestResources)
struct SaveErrorTests {
    @Test("duplicate save failure is shown instead of swallowed")
    @MainActor
    func duplicateSaveFailureIsShown() throws {
        PennySaveReporter.shared.dismiss()
        let container = try PennyPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let id = UUID()
        context.insert(Transaction(
            id: id,
            title: "First",
            amount: Decimal(string: "1.25")!,
            transactionType: .expense,
            categoryName: "Food"
        ))
        try context.save()
        context.insert(Transaction(
            id: id,
            title: "Duplicate",
            amount: Decimal(string: "2.50")!,
            transactionType: .expense,
            categoryName: "Food"
        ))
        let saved = context.saveOrSurfaceError()
        #expect(saved == false)
        let message = try #require(PennySaveReporter.shared.message)
        #expect(message.contains("Couldn’t save"))
    }
}
