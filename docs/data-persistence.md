# Local data across builds

Penny stores everything on-device with **SwiftData**. TestFlight and App Store **updates keep your data**.

## What preserves data

| Situation | Data kept? |
|---|---|
| Install newer TestFlight / App Store build (same bundle ID `com.mayooran.penny`) | **Yes** |
| Xcode Cloud / Mac archive upload as an update | **Yes** |
| Change app version or build number only | **Yes** |
| Delete the app from the Home Screen, then reinstall | **No** (iOS removes the sandbox) |
| Settings → **Reset demo data** or **Delete all data** | **No** (explicit wipe) |

The database uses a **stable store name** (`Penny`). `PennyMigrationPlan` is passed into every `ModelContainer` the app opens. `PennySchemaV103` is the v1.0.3 shape. `PennySchemaV1` is the current shape (version identifier 1.0.4: goal funding, the walkthrough flag, and `paidCycleKey`). The plan’s lightweight stage carries a v1.0.3 store forward, including when the user skipped v1.0.4.

## Adding a schema version

1. Leave `PennySchemaV103` and `PennySchemaV1` unchanged. Add `PennySchemaV2` (or the next number) with the new stored properties. Do not edit an older version’s stored properties.
2. Append that schema to `PennyMigrationPlan.schemas` and add a `MigrationStage` from the previous version. Use `lightweight` for additive fields and new entities. Use `custom` when values have to be rewritten.
3. Point `PennyPersistence`’s model list at the new types (the app reads the latest models).
4. Add an upgrade test in `PennyTests/Migration` that writes a store with the previous schema, opens it with `makeContainer(at:)`, and checks every record and every amount to the cent. Include a skip from v1.0.3 if the new stage sits after it.
5. Run `./scripts/ci-macos.sh`. `ci-gate` fails if the v1.0.3 upgrade or the 5,000-transaction timing check did not run.

## Protections in code

1. **No empty in-memory fallback** if the on-disk store fails to open (that looked like a wipe).
2. **Backup before open.** If a store file already exists, Penny copies it (and the SQLite `-wal` / `-shm` sidecars) to `PennyBackups/<store name>/pre-migration` and writes a `migration-in-progress` marker. `PennyStoreBackup` is the copy/restore helper a later export feature can reuse.
3. **Restore on failure.** If the open throws, or the process died after the copy and before the open finished, Penny puts that copy back and tells the user **“Your data is safe”**.
4. **`repairIfNeeded`** — if transactions/bills/etc. exist but settings were missing, settings are recreated with onboarding complete so you are not forced through a destructive setup. A repair failure is shown, not ignored.
5. **Saves are visible.** `modelContext.saveOrSurfaceError()` reports a failure on a banner (`PennySaveReporter`). Do not add `try? save()`.
6. **Seed helpers default to non-destructive** unless `replaceExisting: true` (used only for onboarding choices and Settings reset/delete).

## Widget snapshots

Widget “Safe to Spend” snapshots use App Group `group.com.mayooran.penny`. That is separate from the SwiftData database and is rewritten whenever Home refreshes; it does not delete transactions or budgets.
