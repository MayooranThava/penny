# Pre-release sanity checklist

Use this before every App Store / TestFlight release. Automated checks catch calculation, formatting, catalog, and persistence regressions. Manual steps catch UI/device issues the unit suite cannot see.

## One-command automated check

```bash
# Linux CI / Cloud Agent / any Mac with Swift
./scripts/pre-release-sanity.sh

# Mac with Xcode — also runs PennyTests (SwiftData, soft-delete, StoreKit ID lock)
./scripts/pre-release-sanity.sh --xcode
```

### GitHub Actions

Every push and pull request runs **Pre-release Sanity** on Ubuntu (product IDs + `PennyCoreLogic` Release Sanity + full core suite).

- Open the repo → **Actions** → **Pre-release Sanity**
- PR checks show the same job status on the pull request
- Re-run anytime via **Actions** → **Pre-release Sanity** → **Run workflow**

Mac-only checks (SwiftData soft-delete, demo seed, `PennyTests`) are **not** in Actions (no iOS Simulator on `ubuntu-latest`). Run those with `--xcode` or **⌘U** before App Store submission.

Override the simulator if needed:

```bash
PENNY_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro' ./scripts/pre-release-sanity.sh --xcode
```

Or in Xcode: open `Penny.xcodeproj` → select the **Penny** scheme → **Product → Test (⌘U)**. The suite named **Release Sanity** is the smoke gate.

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
3. After adding a `PennyTests` file, regenerate the Xcode project:

```bash
python3 scripts/generate_xcode_project.py
```
