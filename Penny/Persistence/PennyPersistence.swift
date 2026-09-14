import Foundation
import SwiftData
import SwiftUI

enum PennyPersistence {
    static let schema = Schema([
        Transaction.self,
        BudgetCategory.self,
        Budget.self,
        RecurringBill.self,
        SavingsGoal.self,
        Debt.self,
        FinancialAccount.self,
        UserSettings.self
    ])

    enum ContainerError: Error, LocalizedError {
        case unavailable(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .unavailable(let underlying):
                return "Penny couldn’t open local storage: \(underlying.localizedDescription)"
            }
        }
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Penny",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Retry once with an in-memory store so development can continue if the
            // on-disk store is corrupted.
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                throw ContainerError.unavailable(underlying: error)
            }
        }
    }

    /// Preview helper with demo data already loaded.
    @MainActor
    static func previewContainer() -> ModelContainer {
        let emptyConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? makeContainer(inMemory: true) else {
            // In-memory container creation is effectively guaranteed for previews.
            return try! ModelContainer(for: schema, configurations: [emptyConfig])
        }
        try? DemoDataService.seedDemo(in: container.mainContext, markOnboardingComplete: true)
        return container
    }
}
