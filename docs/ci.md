# CI

GitHub Actions workflow **CI** (`.github/workflows/ci.yml`) runs on every pull request and on every push to `main`.

| Job | What it does |
| --- | --- |
| Product IDs + core logic | Ubuntu. Product IDs, `PennyCoreLogic` tests, and the shared-logic drift check. |
| macOS build and PennyTests | Newest **stable** Xcode on `macos-latest`. `build-for-testing` for the iOS Simulator (Penny, PennyWidgets, and every test target on the Penny scheme), then the **entire** PennyTests bundle. It then builds **Release** and fails if the Penny executable contains a `UITestSeedLaunch` symbol, and builds **Screenshots** and fails if that symbol is missing. |
| `ci-gate` | Depends on both jobs. Fails unless each one **succeeded**. A failed, skipped, or cancelled job fails `ci-gate`. |

Require **`ci-gate`** (shown as `CI / ci-gate`) as the single required status check on `main`.

The macOS job does not pass `-only-testing` or `-skip-testing`. `PennyTests/Migration` always runs, including the v1.0.3 / v1.0.4 upgrade tests and the 5,000-transaction timing check. `build-for-testing` compiles every unit-test and UI-test target listed on the Penny scheme.

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

`./scripts/pre-release-sanity.sh --xcode` does the Linux checks and then `ci-macos.sh`. On a Mac, `./scripts/check-release-omits-uitest-seed.sh` builds Release and rejects a `UITestSeedLaunch` symbol, then builds Screenshots and requires that same scan to find the symbol. Actions runs it in the macOS job.

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

`scripts/check-core-logic-drift.py` diffs the logic after ignoring `public`, `Sendable`, memberwise initializers, comments, and that recurrence shim. The shim's cases still have to match `Penny/Models`. Any new difference fails the check.

`Decimal.from` and Apple Pay cent rounding match in both copies. `Decimal.from` rejects broken input such as `1.2.3`, `12-3`, and `--5`. Apple Pay amounts are rounded to cents with integer math, not `Decimal(Double)` and not a locale-sensitive `String(format:)`. `FinanceCalculator` builds one cent with `Decimal(sign:exponent:significand:)` so `Decimal(0.01)` never comes from a Double.

Deleting a bill sets `RecurringBill.isActive` to false. `BillPaymentCycle.includesInCommittedSpend(isActive:)` is that rule in both copies. Safe to Spend totals bills through `FinanceCalculator.totalMonthlyCommitted`, which calls the helper, so a deleted or inactive bill does not reduce the number in the app or the widget snapshot. The app UI still assigns `isActive` directly. The old `paidCycleKey == key` checklist is not how a bill is marked paid.

It covers:

- `Penny/Services/FinanceCalculator.swift`
- `Penny/Services/InsightEngine.swift`
- `Penny/Services/ApplePayCaptureLogic.swift`
- `Penny/Services/CSVExportLogic.swift`
- `Penny/Services/BillPaymentCycle.swift`
- `Penny/Utilities/DateHelpers.swift`
- `Penny/Utilities/MoneyFormatters.swift`

`DateHelpers` and `MoneyFormatters` live in `Penny/Utilities`, not `Services`, and are part of the same mirror.

## Parallel tests and isolation

`-parallel-testing-enabled YES` is on. Calculation suites run in parallel. Suites that open SwiftData (`Release Sanity`, `ApplePayCaptureService`, `Migration`, `Save errors`, `Test isolation`) are `.serialized`.

Every suite uses `.isolatedTestResources`. That gives the test its own temp SwiftData directory and its own UserDefaults suite. The app store name stays `Penny`, and widgets still use the App Group, unless that test override is set. It is not set in the app.

## No data lost on upgrade

`PennyTests/Migration` is the upgrade suite. It opens a v1.0.3 store and a v1.0.4 store with `PennyPersistence.makeContainer(at:)`, checks every record and every amount to the cent, opens v1.0.3 straight on the current schema (skip-version), and times a 5,000-transaction upgrade. The macOS job fails if `v103StoreOpensOnCurrentSchemaWithoutLosingACent` or `fiveThousandTransactionUpgradeFinishesWithinAFewSeconds` did not run.

Any pull request that changes the SwiftData model must pass that upgrade test:

- Models in `Penny/Models`
- The schema in `Penny/Persistence/PennyPersistence.swift`
- `PennySchemaV103`, `PennySchemaV1`, or `PennyMigrationPlan`

The stores are written in the test from the frozen v1.0.3 types and the unversioned v1.0.4 model list, then opened the way an update opens them. See `PennyTests/Migration/README.md`. A new shipped schema needs its own `VersionedSchema`, a lightweight or custom stage, and another case in this suite.

`ci-gate` fails if the macOS job fails or does not run, so the upgrade test cannot be dropped from the required check by skipping that job.

## App screenshots

Workflow **App screenshots** (`.github/workflows/screenshots.yml`) is separate from **CI**. It runs on a push to `main`, from **workflow_dispatch**, and on a pull request that changes the app (`Penny/**`), the UI tests (`PennyUITests/**`), the Xcode project (`Penny.xcodeproj/**`), or a workflow file (`.github/workflows/**`). `ci-gate` does not wait for it.

The job uses `scripts/select-stable-xcode.sh`, then `scripts/ci-screenshots.sh`. That script runs the `PennyScreenshots` scheme in the **Screenshots** configuration. Screenshots copies Release and adds the `SCREENSHOT_SEED` Swift compilation condition on the app target, so optimization matches a shipped build and the demo seed is compiled in. `VALIDATE_PRODUCT` and code signing are turned off for the simulator install only. Swift does not set the `DEBUG` flag.

`PennyUITests` is not on the Penny scheme. `build-for-testing` in the macOS CI job does not compile or run it. The screenshot target compiles `PrivateModeLogic.swift` together with `MoneyFormatters.swift`, because the amount regex lives in the former and that file formats currency through the latter. The product check after that build uses `check-xcode-test-layout.py --list-products`, which lists only unskipped Penny-scheme test bundles, so it does not require `PennyUITests.xctest`.

`UITestSeedLaunch`, the launch path in `PennyApp`, and `DemoDataService.seedVolumeTransactions` are wrapped in `#if SCREENSHOT_SEED`. Debug and Release do not compile them. The UI tests pass `-PennyUITestSeed` plus appearance, Private mode, and an optional transaction count. The seed loads the fictional demo household, marks onboarding and the walkthrough complete, and sets Light or Dark plus Private mode. A 5,000-transaction count is only added when the performance tests pass `-PennyUITestTransactionCount`. Onboarding and Settings still call `seedDemo` / `seedFresh` in every configuration; those paths are unchanged.

The macOS CI job runs `scripts/check-release-omits-uitest-seed.sh` after PennyTests. That builds the Penny scheme in **Release** and fails if `nm` or `strings` finds `UITestSeedLaunch` in `Penny.app/Penny`. It then builds the same scheme in **Screenshots** and fails if both `nm` and `strings` miss `UITestSeedLaunch` there. That positive control stops a tool miss from making a seeded Release binary look clean. `ci-gate` depends on that job, so a seeded Release binary fails the required check.

The tests attach a PNG for Home, Budget, Plan, Activity, and Settings, each with Private mode off and on, in Light and Dark (`home-dark-private.png`). On every Private-mode shot, a total amount label fails the test if it contains a digit. Sentences that also include a percent use `PrivateAmountLogic.containsCurrencyAmount`, the same currency regex as Private mode. The performance tests record `XCTApplicationLaunchMetric` for the 5,000-transaction launch, `XCTOSSignpostMetric` scroll-deceleration duration, and `XCTHitchMetric` hitch time. `scripts/export-screenshot-artifacts.py` copies the PNGs and the metric report into the `app-screenshots` artifact.
