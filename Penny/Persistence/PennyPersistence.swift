import Foundation
import os
import SwiftData

enum PennyLog {
    static let persistence = Logger(subsystem: "com.mayooran.penny", category: "persistence")
}

/// Local SwiftData store for Penny.
///
/// **Update safety:** The store lives in the app’s Application Support directory under a
/// stable configuration name (`Penny`). TestFlight / App Store updates keep that
/// directory. Data is only removed if the user deletes the app, uses Settings →
/// Reset/Delete, or chooses an onboarding path that explicitly replaces content.
enum PennyPersistence {
    /// Stable store name — do not rename; renaming would create a new empty database.
    static let storeName = "Penny"

    /// Shown when a migration fails and the pre-migration copy is put back.
    static let dataIsSafeMessage = "Your data is safe"

    /// Set only by PennyTests. Nil in the app, so production and previews keep
    /// the in-memory or on-disk store named `Penny`.
    @TaskLocal static var isolatedStoreName: String?

    /// Directory name for the test-only store override, when one is set.
    static var activeIsolatedStoreName: String? { isolatedStoreName }

    /// Test-only. After the pre-migration copy is taken, this runs and the open fails.
    /// The store is restored from that copy and the error includes `dataIsSafeMessage`.
    @TaskLocal static var migrationFailureInjection: (@Sendable (URL) throws -> Void)?

    private static let isolatedStoreLock = NSLock()

    /// On-disk schema. This is the current version (`PennySchemaV1`, version 1.0.4).
    /// Breaking model changes add a new `VersionedSchema` and a stage on `PennyMigrationPlan`.
    static let schema = Schema(versionedSchema: PennySchemaV1.self)

    enum ContainerError: Error, LocalizedError {
        case unavailable(underlying: Error)
        case migrationFailedDataRestored(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .unavailable(let underlying):
                return "Penny couldn’t open local storage: \(underlying.localizedDescription)"
            case .migrationFailedDataRestored:
                return "\(PennyPersistence.dataIsSafeMessage). Penny put your previous records back because the update didn’t finish."
            }
        }
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        // PennyTests sets `isolatedStoreName` so parallel cases do not share a store.
        // The app never sets it: on-disk and preview containers stay named `Penny`.
        if inMemory, let override = isolatedStoreName, !override.isEmpty {
            return try makeIsolatedTestContainer(directoryName: override)
        }
        // Leave schema off the configuration. Passing a Schema here makes SwiftData
        // ignore `migrationPlan` (the container then won't run PennyMigrationPlan).
        let configuration = ModelConfiguration(
            storeName,
            isStoredInMemoryOnly: inMemory
        )
        return try openFileStore(configuration, backupExistingStore: !inMemory)
    }

    /// Opens a store file the way a real upgrade does: migration plan, and a backup first.
    static func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        return try openFileStore(configuration, backupExistingStore: true)
    }

    /// Temp-file store used by tests. Unique directories isolate SwiftData even
    /// when in-memory configurations would otherwise alias inside one process.
    private static func makeIsolatedTestContainer(directoryName: String) throws -> ModelContainer {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("Penny.store"))
        isolatedStoreLock.lock()
        defer { isolatedStoreLock.unlock() }
        return try openFileStore(configuration, backupExistingStore: true)
    }

    private static func openFileStore(
        _ configuration: ModelConfiguration,
        backupExistingStore: Bool
    ) throws -> ModelContainer {
        let storeURL = configuration.url
        guard backupExistingStore else {
            return try makeModelContainer(configuration)
        }

        if FileManager.default.fileExists(atPath: PennyStoreBackup.markerURL(for: storeURL).path),
           FileManager.default.fileExists(atPath: PennyStoreBackup.snapshotDirectory(for: storeURL).path) {
            // The last launch copied the store, then died before the open finished.
            try PennyStoreBackup.restore(
                from: PennyStoreBackup.snapshotDirectory(for: storeURL),
                over: storeURL
            )
            try? FileManager.default.removeItem(at: PennyStoreBackup.markerURL(for: storeURL))
            PennyLog.persistence.error("Restored a pre-migration store after an interrupted update.")
        }

        let hadStore = PennyStoreBackup.storeExists(at: storeURL)
        if hadStore {
            try PennyStoreBackup.copyStore(
                at: storeURL,
                to: PennyStoreBackup.snapshotDirectory(for: storeURL)
            )
            try Data("1".utf8).write(to: PennyStoreBackup.markerURL(for: storeURL), options: .atomic)
        }

        if let injection = migrationFailureInjection {
            let failure = runInjection(injection, storeURL: storeURL)
            try restoreAfterFailedMigration(hadStore: hadStore, storeURL: storeURL, underlying: failure)
        }

        do {
            let container = try makeModelContainer(configuration)
            if hadStore {
                try? FileManager.default.removeItem(at: PennyStoreBackup.markerURL(for: storeURL))
                PennyStoreBackup.discard(storeAt: storeURL)
            }
            return container
        } catch {
            try restoreAfterFailedMigration(hadStore: hadStore, storeURL: storeURL, underlying: error)
        }
    }

    private static func runInjection(
        _ injection: @Sendable (URL) throws -> Void,
        storeURL: URL
    ) -> Error {
        do {
            try injection(storeURL)
            return ForcedMigrationFailure()
        } catch {
            return error
        }
    }

    private static func restoreAfterFailedMigration(hadStore: Bool, storeURL: URL, underlying: Error) throws -> Never {
        guard hadStore else {
            throw ContainerError.unavailable(underlying: underlying)
        }
        do {
            try PennyStoreBackup.restore(
                from: PennyStoreBackup.snapshotDirectory(for: storeURL),
                over: storeURL
            )
            try? FileManager.default.removeItem(at: PennyStoreBackup.markerURL(for: storeURL))
        } catch {
            PennyLog.persistence.error("Migration failed and the backup could not be restored: \(error.localizedDescription, privacy: .public)")
            throw ContainerError.unavailable(underlying: error)
        }
        PennyLog.persistence.error("Migration failed; restored the previous store. \(underlying.localizedDescription, privacy: .public)")
        throw ContainerError.migrationFailedDataRestored(underlying: underlying)
    }

    /// Model types plus `migrationPlan`. A `VersionedSchema` container initializer
    /// has been unreliable on Xcode Cloud, and passing `Schema` into the container
    /// or the configuration can make SwiftData skip the plan.
    private static func makeModelContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: Transaction.self,
                BudgetCategory.self,
                Budget.self,
                RecurringBill.self,
                SavingsGoal.self,
                Debt.self,
                FinancialAccount.self,
                GoalFundingAllocation.self,
                UserSettings.self,
                migrationPlan: PennyMigrationPlan.self,
                configurations: configuration
            )
        } catch {
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
            return try! ModelContainer(
                for: Transaction.self,
                BudgetCategory.self,
                Budget.self,
                RecurringBill.self,
                SavingsGoal.self,
                Debt.self,
                FinancialAccount.self,
                GoalFundingAllocation.self,
                UserSettings.self,
                migrationPlan: PennyMigrationPlan.self,
                configurations: fallback
            )
        }
    }
}

private struct ForcedMigrationFailure: Error {}

// MARK: - Versioned schema

/// Current shipping model set (the v1.0.4 shape: goal funding, walkthrough flag, bill paid-cycle key).
/// Version 1.0.0 was declared but never passed to `ModelContainer`, so no user store is stamped with it.
enum PennySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 4)

    static var models: [any PersistentModel.Type] {
        [
            Transaction.self,
            BudgetCategory.self,
            Budget.self,
            RecurringBill.self,
            SavingsGoal.self,
            Debt.self,
            FinancialAccount.self,
            GoalFundingAllocation.self,
            UserSettings.self
        ]
    }
}

enum PennyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PennySchemaV103.self, PennySchemaV1.self]
    }

    /// v1.0.3 → current. Additive columns and the goal-funding entity. Skip-version
    /// upgrades use this single stage (there is no required stop at v1.0.4).
    static let migrateV103ToCurrent = MigrationStage.lightweight(
        fromVersion: PennySchemaV103.self,
        toVersion: PennySchemaV1.self
    )

    static var stages: [MigrationStage] {
        [migrateV103ToCurrent]
    }
}
