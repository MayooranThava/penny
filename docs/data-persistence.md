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

The database uses a **stable store name** (`Penny`) and a **versioned schema** (`PennySchemaV1` + `PennyMigrationPlan`). Future model changes should add a new schema version and a migration stage — never rename the store or change the bundle ID.

Additive fields (for example Apple Pay import metadata on `Transaction`, or `applePayCaptureConfigured` on `UserSettings`) rely on SwiftData lightweight migration and keep existing rows.

## Protections in code

1. **No empty in-memory fallback** if the on-disk store fails to open (that looked like a wipe).
2. **`repairIfNeeded`** — if transactions/bills/etc. exist but settings were missing, settings are recreated with onboarding complete so you are not forced through a destructive setup.
3. **Seed helpers default to non-destructive** unless `replaceExisting: true` (used only for onboarding choices and Settings reset/delete).

## Widget snapshots

Widget “Safe to Spend” snapshots use App Group `group.com.mayooran.penny`. That is separate from the SwiftData database and is rewritten whenever Home refreshes; it does not delete transactions or budgets.
