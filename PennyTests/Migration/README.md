# Migration tests

This folder is the reserved home for the **no data lost on upgrade** check. PR 2 lands the real fixture and assertions. Until then, `MigrationTests` passes and only checks that this folder’s `Fixtures` directory is copied into the PennyTests bundle.

CI runs the **entire** `PennyTests` target. Do not add `-only-testing`, `-skip-testing`, or a scheme skip for this suite. `ci-gate` fails if the macOS test job fails or is skipped.

## What PR 2 adds

1. A store written by the shipping app at marketing version **1.0.4**, placed at `PennyTests/Migration/Fixtures/Penny-v1.0.4.store`. The `Fixtures` directory is a folder reference on the PennyTests target, so files added here are bundled without a new Copy Bundle Resources entry.
2. A test that copies that store to a temp directory, opens it with the current `PennyPersistence` schema / migration plan, and asserts no records were dropped.
3. A timing check that migrates **about 5,000 transactions** inside the budget the test sets. Time the open/migrate call itself so other parallel suites do not dominate the number. This suite is `.serialized`.

Any pull request that changes the SwiftData model (`Penny/Models`, the schema in `PennyPersistence`, or `PennySchemaV1` / `PennyMigrationPlan`) has to pass that upgrade test once it exists. Open the fixture the way a real upgrade would (file URL copied out of the bundle). Do not call `makeContainer()` without `inMemory` for the fixture: the on-disk name `Penny` is the user’s store. CI gives each test its own temp store only when `makeContainer(inMemory: true)` runs under the test trait.
