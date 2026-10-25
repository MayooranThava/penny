# Migration tests

This suite is the **no data lost on upgrade** check. CI runs the entire `PennyTests` target. Do not add `-only-testing`, `-skip-testing`, or a scheme skip. `ci-gate` fails if `v103StoreOpensOnCurrentSchemaWithoutLosingACent` or `fiveThousandTransactionUpgradeFinishesWithinAFewSeconds` did not run.

## How the stores are produced

This repo’s cloud agent cannot install the App Store binaries for v1.0.3 or v1.0.4, so the tests do not ship a prebuilt `.store` file. They write a real SwiftData store, then open it the way an update does.

- **v1.0.3** uses `PennySchemaV103` in `Penny/Persistence/PennySchemaV103.swift`. Those stored properties are the model from commit `dca913c` (the v1.0.3 marketing bump). The test inserts a household (including a `$0.01` row and a long note), closes the container, and calls `PennyPersistence.makeContainer(at:)`.
- **v1.0.4** uses an unversioned `Schema` of the current model types. That shape has not changed since commit `92c6746`. The shipping v1.0.4 app opened its store the same way, without `PennyMigrationPlan`. The test then opens the file through the plan.
- **Skip-version** is the v1.0.3 file opened on the current schema. Users do not have to install v1.0.4 in between. The plan’s one lightweight stage adds `paidCycleKey`, `hasCompletedWalkthrough`, and `GoalFundingAllocation`.
- **5,000 transactions** are written with the v1.0.3 schema. The assertion times only `makeContainer(at:)`, and the sum of the amounts must stay exact.

`makeContainer(at:)` copies the store before opening. `failedMigrationRestoresBackupAndSaysDataIsSafe` corrupts the file after that copy and expects the original rows back, plus the words “Your data is safe”.

## When the model changes

Add a new `VersionedSchema`. Do not edit `PennySchemaV103` or the stored properties of an older version. Add a stage, point the app at the new types, and add a fixture case here. Checklist: `docs/data-persistence.md`.
