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
            // Never fall back to an empty in-memory store in production — that
            // looks like a data wipe after an app update when the on-disk open fails.
            // Previews and unit tests pass `inMemory: true` explicitly.
            #if DEBUG
            if inMemory == false {
                // Development-only last resort so UI work can continue on a broken store.
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
                    return container
                }
            }
            #endif
            throw ContainerError.unavailable(underlying: error)
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
