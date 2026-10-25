# CI

GitHub Actions workflow **CI** (`.github/workflows/ci.yml`) runs on every pull request and on every push to `main`.

| Job | What it does |
| --- | --- |
| Product IDs + core logic | Ubuntu. Product IDs, `PennyCoreLogic` tests, and the shared-logic drift check. |
| macOS build and PennyTests | Newest **stable** Xcode on `macos-latest`. `build-for-testing` for the iOS Simulator (Penny, PennyWidgets, and every test target on the Penny scheme), then the **entire** PennyTests bundle. |
| `ci-gate` | Depends on both jobs. Fails unless each one **succeeded**. A failed, skipped, or cancelled job fails `ci-gate`. |

Require **`ci-gate`** (shown as `CI / ci-gate`) as the single required status check on `main`.

The macOS job does not pass `-only-testing` or `-skip-testing`. `PennyTests/Migration` always runs, including the upgrade tests PR 2 will add. `build-for-testing` compiles every unit-test and UI-test target listed on the Penny scheme.

## Run the same checks locally

Linux, or a Mac without the simulator:

```bash
./scripts/pre-release-sanity.sh
```

That runs the drift check, the test-layout check, product IDs, and `swift test` in `Tools/PennyCoreLogic`.

Mac, full simulator build and every PennyTests case (same script Actions runs):

```bash
./scripts/ci-macos.sh
```

`./scripts/pre-release-sanity.sh --xcode` does the Linux checks and then `ci-macos.sh`.

Use the Xcode you already have selected. To match Actions and pick the newest stable Xcode under `/Applications` (skipping beta, preview, and release candidates):

```bash
PENNY_SELECT_XCODE=1 ./scripts/ci-macos.sh
```

Override the simulator if you need a specific device:

```bash
PENNY_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16' ./scripts/ci-macos.sh
```

SPM caches and DerivedData are cached in Actions under `.derivedData` plus `~/Library/Caches/org.swift.swiftpm` and `~/Library/org.swift.swiftpm`. Locally, DerivedData for this script defaults to `.derivedData/` in the repo (gitignored).

## Drift check

`Tools/PennyCoreLogic` is a Foundation-only copy of the calculation layer so Linux can run it. The app does not compile those files.

Symlinks or a shared Xcode source list would not work: the package has to be `public`, it cannot import SwiftData, and `BillRecurrence` lives on the app model with UI helpers. The package keeps a case-only stand-in, plus explicit public initializers.

`scripts/check-core-logic-drift.py` diffs the logic after ignoring `public`, `Sendable`, memberwise initializers, comments, and that recurrence shim. The shim's cases still have to match `Penny/Models`. It covers:

- `Penny/Services/FinanceCalculator.swift`
- `Penny/Services/InsightEngine.swift`
- `Penny/Services/ApplePayCaptureLogic.swift`
- `Penny/Services/CSVExportLogic.swift`
- `Penny/Services/BillPaymentCycle.swift`
- `Penny/Utilities/DateHelpers.swift`
- `Penny/Utilities/MoneyFormatters.swift`

`DateHelpers` and `MoneyFormatters` live in `Penny/Utilities`, not `Services`, and are part of the same mirror.

## Parallel tests and isolation

`-parallel-testing-enabled YES` is on. Calculation suites run in parallel. Suites that open SwiftData (`Release Sanity`, `ApplePayCaptureService`, `Migration`, `Test isolation`) are `.serialized`.

Every suite uses `.isolatedTestResources`. That gives the test its own temp SwiftData directory and its own UserDefaults suite. The app store name stays `Penny`, and widgets still use the App Group, unless that test override is set. It is not set in the app.

## No data lost on upgrade

`PennyTests/Migration` is the reserved upgrade suite. The placeholder test `reservedUpgradeCheckRunsInCI` passes today and checks that `Fixtures` is inside the test bundle. PR 2 replaces the assertion with the real upgrade.

Any pull request that changes the SwiftData model must pass that upgrade test:

- Models in `Penny/Models`
- The schema in `Penny/Persistence/PennyPersistence.swift`
- `PennySchemaV1` or `PennyMigrationPlan`

The test has to:

1. Open a store written by the shipping app (v1.0.4), bundled from `PennyTests/Migration/Fixtures/Penny-v1.0.4.store`.
2. Prove no records were lost.
3. Include a **timing check on about 5,000 transactions**. Time the open/migrate call. This suite is serialized so its own cases do not overlap.

PennyTests has a Resources build phase. `Migration/Fixtures` is a folder reference, so adding `Penny-v1.0.4.store` there bundles it on the next build. Details are in `PennyTests/Migration/README.md`.

`ci-gate` fails if the macOS job fails or does not run, so the upgrade test cannot be dropped from the required check by skipping that job.
