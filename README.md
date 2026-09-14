# Penny

Beautiful personal finance without an expensive subscription.

Penny is a native iOS personal finance planner focused on clarity: safe-to-spend, budgets, bills, savings goals, debt payoff, and lightweight forecasts. It is intentionally **not** an accounting app.

## Current features

- **Onboarding** (3 intro screens + quick setup): currency, income, sample data or start fresh
- **Home**: greeting, Safe to Spend hero, monthly spending progress, upcoming bills, savings goals, insights
- **Activity**: month selector, search, income/expense/category filters, grouped transactions, add/delete
- **Budget**: planned vs spent ring, category progress with health states, category detail + edit + trend chart
- **Plan**: Goals, Bills, Debt payoff estimates, multi-horizon Forecast chart (labeled as estimates)
- **Settings**: currency (CAD/USD/GBP/EUR/AUD), income, planned savings, appearance, bill reminders, reset/delete data, privacy copy, Penny Pro roadmap stub
- **Design system**: mint/emerald warm identity, light + dark mode, reusable cards/rows/buttons
- **Local insights**: deterministic rules (no AI APIs)
- **Demo data**: realistic Canadian-style household seeded for previews and first-run exploration

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

- All prototype data stays **on-device** via SwiftData
- No bank connectivity, Plaid, analytics, ads, or remote databases
- Reset demo data / delete all data available in Settings
- Notification permission is only used for optional bill reminders

## Monetization (architecture only)

`PennyProductCatalog` reserves a lifetime Pro product id. There is **no paywall** in this prototype. Likely model: free app + one-time lifetime unlock (not a high-priced subscription).

## Tests

Business-logic coverage in `PennyTests/FinanceCalculatorTests.swift`:

- Safe to spend
- Budget remaining / progress / health
- Goal progress & required monthly savings
- Debt amortization / payment-too-low
- Balance projections
- Currency formatting helpers
- Date helpers
- Insight rules

Run in Xcode with **⌘U**, or:

```bash
xcodebuild test -scheme Penny -destination 'platform=iOS Simulator,name=iPhone 16'
```

(Adjust simulator name to one installed on your Mac.)

## How to open and run

1. On a Mac with **Xcode 15.4+** (Xcode 16 recommended), clone this repository.
2. Open `Penny.xcodeproj`.
3. Select an iPhone simulator (or a device).
4. Press **Run (⌘R)**.
5. Choose **Explore with sample data** on first launch to see a populated household.

If signing is required for a physical device, set your Development Team in the Penny target signing settings.

Regenerating the Xcode project after adding files:

```bash
python3 scripts/generate_xcode_project.py
```

## Known limitations

- This Cloud Agent environment is Linux and cannot compile or launch the iOS Simulator; validate builds on macOS Xcode.
- App Icon is a placeholder slot (no final artwork yet).
- No live bank feeds, iCloud sync, widgets, CSV export, or StoreKit purchase flow yet.
- Forecasts are deterministic estimates from income/bills/average spending — not predictions.
- Debt payoff uses monthly compounding amortization with rounded interest.

## Future roadmap (highest value next)

1. Polish App Icon + launch branding
2. Widgets (Safe to Spend / next bill)
3. CSV import/export
4. iCloud sync via SwiftData CloudKit
5. StoreKit 2 lifetime Penny Pro unlock

## Brand

Warm modern finance: fresh mint/emerald primary, cream surfaces, charcoal text, soft blue for savings, amber for caution — **not** a purple-heavy competitor lookalike.
