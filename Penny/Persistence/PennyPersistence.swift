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

    /// Shared schema used for the on-disk store and previews.
    /// Built from the versioned V1 models so the migration plan stays aligned.
    static let schema = Schema(versionedSchema: PennySchemaV1.self)

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
            return try ModelContainer(
                for: schema,
                migrationPlan: PennyMigrationPlan.self,
                configurations: [configuration]
            )
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

// MARK: - Versioned schema (baseline for future migrations)

/// Version 1 — current shipping models. Additive changes should become V2 + a migration stage.
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

    /// No stages yet — V1 is the baseline. Future model changes get a lightweight or custom stage here.
    static var stages: [MigrationStage] { [] }
}
