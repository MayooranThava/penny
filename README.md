# Penny

Beautiful personal finance without an expensive subscription.

Penny is a native iOS personal finance planner focused on clarity: safe-to-spend, budgets, bills, savings goals, debt payoff, and lightweight forecasts. It is intentionally **not** an accounting app.

## Current features

- **Onboarding** (3 intro screens + quick setup): name, currency, income, sample data or start fresh
- **Home**: “Welcome back {name}”, Safe to Spend hero with bills **and debt targets** deducted, spending progress, upcoming bills/debt, savings goals, insights
- **Activity**: month selector, search, income/expense/category filters, grouped transactions, add/delete
- **Budget**: planned vs spent ring, category progress with health states, category detail + edit + trend chart
- **Plan**: Goals, Bills (weekly / biweekly / monthly / yearly + start date, **paid-this-cycle checkmarks**), Debt payoff estimates, Forecast chart
- **Settings**: display name, currency (CAD/USD/GBP/EUR/AUD), income, planned savings, appearance + Pro accent themes, bill reminders, **optional Wallet tap capture instructions (Shortcuts)**, CSV + PDF export (Pro), reset/delete data, Privacy / Terms links, Penny Pro paywall, replay quick tour
- **Walkthrough**: short skippable spotlight tour after first setup
- **Widgets**: Safe to Spend (Home + Lock Screen), Upcoming reminder, Upcoming bills, Monthly budget, Savings goal (App Group `group.com.mayooran.penny`)
- **Design system**: mint/emerald warm identity, light + dark mode, reusable cards/rows/buttons
- **Local insights**: deterministic rules (no AI APIs)
- **Demo data**: sample household with display name **Alex** and a generic credit-card debt (not a real person)

## Architecture

Feature-oriented SwiftUI composition with a thin service layer for calculations:

```
Penny/
  App/                 # PennyApp, RootView, MainTabView
  Models/              # SwiftData models
  Features/            # Home, Activity, Budget, Plan, Settings, Onboarding
  Components/          # Shared UI building blocks
  Services/            # FinanceCalculator, InsightEngine, DemoData, Notifications
  Persistence/         # ModelContainer helpers
  DesignSystem/        # Colors, typography, spacing, button styles
  Utilities/           # Money + date formatting, haptics
  Resources/           # Asset catalog
PennyTests/            # Swift Testing suites for business logic
```

Separation of concerns:

| Layer | Responsibility |
| --- | --- |
| Views | Presentation, navigation, user input |
| Services | Pure calculations, insights, demo seeding |
| Models / SwiftData | Persistence |
| Design system | Visual tokens |

No VIPER / TCA / Redux. No third-party packages.

## Technology stack

- Swift 5 / SwiftUI
- SwiftData (on-device persistence)
- Swift Charts
- Swift Concurrency + Observation (`@Observable` session)
- UserNotifications (bill reminders)
- Swift Testing (`PennyTests`)

## Minimum iOS version

**iOS 17.0**

Chosen because it is the baseline for SwiftData + Observation while remaining a modern, maintainable floor. Charts, TabView, and the rest of the UI APIs used here are stable on iOS 17+. Newer SDKs (Xcode 16+) are supported; beta-only APIs were avoided.

## Data & privacy

- All user data stays **on-device** via SwiftData
- No bank connectivity, Plaid, analytics, ads, or remote databases
- Optional **Wallet tap capture** is documented in Settings only (never required). Users who want it build a Shortcuts personal automation once; amounts never leave the device.
- Reset demo data / delete all data available in Settings
- Notification permission is only used for optional bill reminders

## Monetization

Free app with optional **Penny Pro Lifetime** (one-time Non-Consumable via StoreKit 2):

- Unlimited savings goals (free tier: 3)
- Longer-range forecasts (6 & 12 months)
- CSV export of transactions
- Custom accent themes (mint / ocean / slate / amber)

No subscription in the current release. iCloud sync is **not** included yet and is not marketed as a Pro benefit.

## Tests

Business-logic coverage in `PennyTests/` plus a mirrored Linux package:

- **Release Sanity** (`ReleaseSanityTests`) — pre-ship smoke for safe-to-spend, budgets, goals, debt, money formatting, bill schedule, Apple Pay drafts, demo seed, soft-delete, product IDs
- Safe to spend, budget health, goals, debt amortization, forecasts
- Currency formatting helpers (always two decimals on Home)
- Date helpers and insight rules
- Apple Pay capture logic + SwiftData insert/dedupe

**Before every release:**

```bash
./scripts/pre-release-sanity.sh          # product IDs + Linux core suite
./scripts/pre-release-sanity.sh --xcode  # Mac: also runs PennyTests
```

The same Linux gate runs automatically in GitHub Actions (**Actions → Pre-release Sanity**) on every push and pull request.

See **[docs/pre-release-sanity.md](./docs/pre-release-sanity.md)** for the full automated + manual checklist.

In Xcode: **⌘U**, or:

```bash
xcodebuild test -scheme Penny -destination 'platform=iOS Simulator,name=iPhone 16'
```

(Adjust simulator name to one installed on your Mac.)

Core calculation logic also validates on Linux via `Tools/PennyCoreLogic`.

## How to open and run

1. On a Mac with **Xcode 15.4+** (Xcode 16 recommended), clone this repository.
2. Open `Penny.xcodeproj`.
3. Select an iPhone simulator (or a device).
4. Press **Run (⌘R)**.
5. Choose **Explore with sample data** on first launch to see a populated household.

If signing is required for a physical device, select your Development Team on the Penny target (**Signing & Capabilities**). The project defaults to team `2YJ478267N`.

## TestFlight (internal + external)

Use **Xcode Cloud** for My Penny in App Store Connect (same system as Void Runner). After a one-time GitHub link + workflow on `main`, every push archives to TestFlight.

See **[docs/app-store-connect.md](docs/app-store-connect.md)** for the click path and the export-compliance answer.

Manual Mac upload (rare): `./scripts/archive-for-testflight.sh`

API helper: `python3 scripts/asc_setup_penny.py status`

Regenerating the Xcode project after adding files:

```bash
python3 scripts/generate_xcode_project.py
```

## Known limitations

- This Cloud Agent environment is Linux and cannot compile or launch the iOS Simulator; validate builds on macOS Xcode.
- App Icon is a placeholder slot (no final artwork yet).
- No live bank feeds or iCloud sync yet (intentionally omitted from Pro marketing until shipped).
- Home-screen widgets require the App Group `group.com.mayooran.penny` enabled for your Apple Developer team.
- Forecasts are deterministic estimates from income/bills/average spending — not predictions or financial advice.
- Debt payoff uses monthly compounding amortization with rounded interest.
- Alternate App Store icons are not offered yet (accent themes only).

## Future roadmap (highest value next)

1. Polish launch branding extras
2. CSV import (export already ships with Pro)
3. iCloud sync via SwiftData CloudKit (add to Pro only after it ships)
4. Optional alternate app icons

## Brand

Warm modern finance: fresh mint/emerald primary, cream surfaces, charcoal text, soft blue for savings, amber for caution — **not** a purple-heavy competitor lookalike.
