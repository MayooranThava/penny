import Foundation
import SwiftData
import SwiftUI

/// Local SwiftData store for Penny.
///
/// **Update safety:** The store lives in the app’s Application Support directory under a
/// stable configuration name (`Penny`). TestFlight / App Store updates keep that
/// directory. Data is only removed if the user deletes the app, uses Settings →
/// Reset/Delete, or chooses an onboarding path that explicitly replaces content.
enum PennyPersistence {
    /// Stable store name — do not rename; renaming would create a new empty database.
    static let storeName = "Penny"

    /// On-disk schema. Keep model types stable across builds; additive fields are OK.
    /// When a breaking model change is needed, introduce `PennySchemaV2` + a migration stage
    /// in `PennyMigrationPlan` and pass that plan into `ModelContainer`.
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
            storeName,
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            // Use the Schema overload (not VersionedSchema.Type) for Xcode Cloud compatibility.
            // Lightweight migration still preserves data across additive updates.
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never fall back to an empty in-memory store. That would look like a
            // data wipe after an app update if the on-disk open failed.
            throw ContainerError.unavailable(underlying: error)
        }
    }

    /// If transactions/bills/etc. exist but `UserSettings` is missing, recreate
    /// settings with onboarding marked complete so the user isn’t sent through a
    /// destructive “Start fresh” flow that would wipe their data.
    @MainActor
    static func repairIfNeeded(in context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        guard settings.isEmpty else { return }
        guard try DemoDataService.hasPersistedUserContent(in: context) else { return }

        context.insert(
            UserSettings(
                currencyCode: "CAD",
                monthlyIncome: 0,
                plannedMonthlySavings: 0,
                hasCompletedOnboarding: true,
                billRemindersEnabled: true,
                appearance: .system,
                usingDemoData: false,
                displayName: ""
            )
        )

        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        if categories.isEmpty {
            for def in CategoryCatalog.defaults {
                context.insert(
                    BudgetCategory(
                        name: def.name,
                        icon: def.icon,
                        budgetedAmount: 0,
                        colourIdentifier: def.colourIdentifier,
                        sortOrder: def.sortOrder
                    )
                )
            }
        }

        try context.save()
    }

    /// Preview helper with demo data already loaded.
    @MainActor
    static func previewContainer() -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            try DemoDataService.seedDemo(
                in: container.mainContext,
                markOnboardingComplete: true,
                replaceExisting: true
            )
            return container
        } catch {
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}

// MARK: - Versioned schema baseline (ready for future V2 migrations)

/// Declares the current model set for future `SchemaMigrationPlan` stages.
/// Not passed directly into `ModelContainer(for:)` — that API expects `Schema`.
enum PennySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Transaction.self,
            BudgetCategory.self,
            Budget.self,
            RecurringBill.self,
            SavingsGoal.self,
            Debt.self,
            FinancialAccount.self,
            UserSettings.self
        ]
    }
}

enum PennyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PennySchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
