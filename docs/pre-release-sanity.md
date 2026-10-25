# Pre-release sanity checklist

Use this before every App Store / TestFlight release. Automated checks catch calculation, formatting, catalog, and persistence regressions. Manual steps catch UI/device issues the unit suite cannot see.

## One-command automated check

```bash
# Linux CI / Cloud Agent / any Mac with Swift
./scripts/pre-release-sanity.sh

# Mac with Xcode — build-for-testing and every PennyTests case, including Migration
./scripts/ci-macos.sh
# or
./scripts/pre-release-sanity.sh --xcode
```

### GitHub Actions

Every pull request and every push to `main` runs workflow **CI**:

- **Product IDs + core logic** on Ubuntu (product IDs, drift check, `PennyCoreLogic`)
- **macOS build and PennyTests** on the newest stable Xcode (`build-for-testing`, then the full PennyTests target with no filter)
- **`ci-gate`**, which fails unless both jobs succeeded (a skipped macOS job fails the gate)

Require `ci-gate` on `main`. Local commands and the SwiftData upgrade rule (no data lost, timing on about 5,000 transactions) are in **[docs/ci.md](./ci.md)**.

Override the simulator if needed:

```bash
PENNY_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro' ./scripts/ci-macos.sh
```

Or in Xcode: open `Penny.xcodeproj` → select the **Penny** scheme → **Product → Test (⌘U)**. That runs every PennyTests suite, including **Migration**. **Release Sanity** is the smoke gate.

## What the automated suite covers

| Area | Linux (`PennyCoreLogic`) | Mac (`PennyTests`) |
| --- | --- | --- |
| Safe to spend + monthly committed | ✓ | via mirrored logic |
| Budget health thresholds | ✓ | ✓ |
| Goals / debt payoff / forecast | ✓ | ✓ |
| Money two-decimal display | ✓ | ✓ |
| Bill next-due schedule | ✓ | — |
| Apple Pay capture draft / IDs | ✓ | service insert/dedupe |
| Product IDs ↔ `Penny.storekit` | script | ✓ |
| Demo seed + non-destructive re-seed | — | ✓ |
| Bill soft-delete (`isActive`) | — | ✓ |
| Persistence store name / schema V1 | — | ✓ |
| Settings repair when content exists | — | ✓ |
| Upgrade / no data lost, including ~5,000 transaction timing | — | reserved in `PennyTests/Migration` (fixture in PR 2). Required for SwiftData model changes. See `docs/ci.md`. |

## Manual smoke (≈5 minutes on Simulator or TestFlight)

Do these after automated green:

1. **Fresh launch / demo** — Delete the app (or Reset in Settings), choose sample data. Home shows Safe to Spend with **two decimal places** (e.g. `$235.40`, not `$235.4`).
2. **Spending card** — “of” budget amount also shows `.00` when whole dollars.
3. **Activity** — Add a transaction, swipe to delete, confirm it disappears.
4. **Plan → Bills** — Open a bill → **Delete Bill** (or swipe Delete). Bill leaves the list and Home committed spend drops. Re-open the app; it stays gone.
5. **Plan → Goals / Debt** — Delete one of each via swipe or edit sheet; lists update.
6. **Budget** — Category remaining / progress looks sane for demo spend.
7. **Settings → Penny Pro** — Paywall opens; products load when StoreKit / ASC agreements are active (Simulator with `Penny.storekit` is enough for local).
8. **Widgets (device)** — After visiting Home, Safe to Spend widget refreshes (App Group required).

## Release gate

Ship only when:

- [ ] `./scripts/pre-release-sanity.sh --xcode` exits 0
- [ ] Manual smoke above is done on the build you will submit
- [ ] App Store Connect version train matches `MARKETING_VERSION` (see `docs/app-store-connect.md`)
- [ ] Export compliance / privacy / IAP attachments still current

## Adding new sanity checks

1. Prefer pure logic in `Tools/PennyCoreLogic/Tests/.../ReleaseSanityTests.swift` so Linux CI can run it.
2. Persistence / SwiftData / StoreKit file checks go in `PennyTests/ReleaseSanityTests.swift`.
3. Upgrade fixtures belong in `PennyTests/Migration/Fixtures/` (a folder reference on PennyTests, so a `Penny-v1.0.4.store` is bundled without a new Copy Bundle Resources row). Model changes must pass that upgrade test, including the timing check on about 5,000 transactions (`docs/ci.md`).
4. After adding a `PennyTests` Swift file, regenerate the Xcode project:

```bash
python3 scripts/generate_xcode_project.py
```
