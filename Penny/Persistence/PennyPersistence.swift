import Foundation
import os
import SQLite3
import SwiftData
import WidgetKit

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

    /// On-disk store for this container, or nil when the container is memory-only.
    static func onDiskStoreURL(in container: ModelContainer) -> URL? {
        container.configurations.first { !$0.isStoredInMemoryOnly }?.url
    }

    /// Shared Settings → Reset / Delete all data cleanup.
    ///
    /// Deletes every model through the open context and saves before touching
    /// files. A second SQLite connection then runs `PRAGMA wal_checkpoint(TRUNCATE)`
    /// and `VACUUM` so deleted rows are removed from the file. That step is
    /// best-effort: a failure is logged and Reset still finishes. The live
    /// `.store` / `-wal` / `-shm` files are never removed, so the open
    /// `ModelContainer` stays valid. Only the pre-migration backup snapshot,
    /// its marker, and the widget snapshot are removed.
    @MainActor
    static func reset(in context: ModelContext) throws {
        try DemoDataService.deleteAll(in: context)
        if let storeURL = onDiskStoreURL(in: context.container) {
            compactOpenStore(at: storeURL)
            PennyStoreBackup.discard(storeAt: storeURL)
        }
        WidgetSnapshotStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Checkpoint and vacuum an on-disk store while SwiftData still has it open.
    ///
    /// Opens a separate connection, runs `PRAGMA wal_checkpoint(TRUNCATE)` then
    /// `VACUUM`, and closes it. Does not unlink the live `.store`, `-wal`, or
    /// `-shm` files. SQLite errors are logged and do not fail Reset.
    private static func compactOpenStore(at storeURL: URL) {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let opened = sqlite3_open_v2(storeURL.path, &db, flags, nil)
        guard opened == SQLITE_OK, let db else {
            let detail = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unable to open the store"
            if let db {
                sqlite3_close(db)
            }
            PennyLog.persistence.error("Store compact skipped: \(detail, privacy: .public)")
            return
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 500)
        if let checkpointError = truncateWal(db) {
            PennyLog.persistence.error("WAL checkpoint failed: \(checkpointError, privacy: .public)")
        }
        if let vacuumError = executeSQL(db, "VACUUM;") {
            PennyLog.persistence.error("VACUUM failed: \(vacuumError, privacy: .public)")
        }
    }

    /// `PRAGMA wal_checkpoint(TRUNCATE)` returns one row: busy, log, checkpointed.
    /// A non-zero busy count means readers stopped the WAL from being fully truncated.
    private static func truncateWal(_ db: OpaquePointer) -> String? {
        let sql = "PRAGMA wal_checkpoint(TRUNCATE);"
        var lastFailure = "wal_checkpoint(TRUNCATE) did not finish"
        for attempt in 0..<4 {
            var statement: OpaquePointer?
            let prepared = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepared == SQLITE_OK, let statement else {
                return String(cString: sqlite3_errmsg(db))
            }
            let stepped = sqlite3_step(statement)
            let failure: String?
            if stepped == SQLITE_ROW {
                let busy = sqlite3_column_int(statement, 0)
                failure = busy == 0 ? nil : "wal_checkpoint(TRUNCATE) busy (\(busy))"
            } else {
                failure = String(cString: sqlite3_errmsg(db))
            }
            sqlite3_finalize(statement)
            if failure == nil {
                return nil
            }
            lastFailure = failure ?? lastFailure
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        return lastFailure
    }

    private static func executeSQL(_ db: OpaquePointer, _ sql: String) -> String? {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        defer { sqlite3_free(errorPointer) }
        guard result == SQLITE_OK else {
            if let errorPointer {
                return String(cString: errorPointer)
            }
            return "SQLite error \(result)"
        }
        return nil
    }

    /// Settings → Reset demo data. Erases local data, then loads the sample household.
    @MainActor
    static func resetDemoData(in context: ModelContext) throws {
        try reset(in: context)
        try DemoDataService.resetAll(in: context)
    }

    /// Settings → Delete all data. Same erase as Reset, then an empty first-run store.
    @MainActor
    static func deleteAllData(in context: ModelContext) throws {
        try reset(in: context)
        try DemoDataService.seedFresh(
            in: context,
            currencyCode: "CAD",
            monthlyIncome: 0,
            replaceExisting: true
        )
        if let settings = try context.fetch(FetchDescriptor<UserSettings>()).first {
            settings.hasCompletedOnboarding = false
            try context.save()
        }
    }

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
