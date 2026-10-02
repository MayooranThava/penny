# App Store Connect & TestFlight — My Penny

**Pipeline: Xcode Cloud only** (same as Void Runner). No GitHub Actions upload path.

## Identifiers

| Item | Value |
|---|---|
| App Store name | **My Penny** |
| Home-screen name | Penny |
| App ID | `6811749191` |
| Bundle ID | `com.mayooran.penny` |
| Widget Bundle ID | `com.mayooran.penny.widgets` |
| SKU | `penny-ios` |
| Team ID | `2YJ478267N` |
| Primary locale | English (Canada) |
| Internal TestFlight group | **Internal Testers** (`e2003e1f-f82e-4bd0-85f9-a5dfc4f4cec5`) |

## Xcode Cloud (required for auto TestFlight)

Void Runner (`ApolloX_IOS`) already has Xcode Cloud. Penny needs a one-time enable, then every push to `main` archives to TestFlight.

### One-time setup (App Store Connect or Xcode)

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **My Penny** → **Xcode Cloud**  
   *(or Xcode: Product → Xcode Cloud → Create Workflow…)*
2. Get Started / create the product for **My Penny**.
3. Connect GitHub repo **MayooranThava/penny** (approve the Xcode Cloud GitHub app if asked).
4. Create a workflow:
   - **Name:** `TestFlight`
   - **Start condition:** Branch changes → `main`
   - **Action:** Archive – iOS, scheme `Penny`  
     Deployment: **TestFlight and App Store** (or Internal Testing Only)
   - **Post-action:** TestFlight Internal Testing → **Internal Testers**
5. Save → start a first build (or push to `main`).

### Build numbers

App Store Connect already has builds **1** and **2** from Mac uploads. The project starts at build **3**, and `ci_scripts/ci_post_clone.sh` bumps `CURRENT_PROJECT_VERSION` on each Xcode Cloud run so uploads never collide.

### External testing

1. Create an External group under TestFlight.
2. Add an External Testing post-action (or a separate release workflow).
3. First external build of a version still needs **Beta App Review**.

## Export compliance (encryption question)

Penny does **not** implement its own crypto (no CryptoKit / custom AES). It only uses encryption already in Apple’s OS (e.g. HTTPS if networking is used).

**In the App Store Connect dialog, choose:**

> **None of the algorithms mentioned above**

The project sets `ITSAppUsesNonExemptEncryption = NO` so future uploads can skip this prompt.

## Manual Mac upload (rare)

```bash
./scripts/archive-for-testflight.sh
```

## Signing checklist

- Team: `2YJ478267N`
- App Bundle ID: `com.mayooran.penny`
- Widget Bundle ID: `com.mayooran.penny.widgets`
- App Group: `group.com.mayooran.penny` on both targets
- Automatically manage signing: **on**
- Widget `Info.plist`: `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`

## API helper

```bash
export ASC_ISSUER_ID="…"
export ASC_KEY_ID="…"
export ASC_PRIVATE_KEY="$(cat ~/AuthKey_XXXX.p8)"
python3 scripts/asc_setup_penny.py status
```

## Security

- Do not commit `.p8` keys
- Rotate any Admin key that was pasted into chat

## Local data across builds

See [data-persistence.md](./data-persistence.md). Short version: updating TestFlight/App Store builds **keeps** on-device SwiftData. Deleting the app or using Settings → Reset/Delete is what clears it.

---

# App Store submission prep

> **Version note (2026-10-02):** App Store Connect closed the `1.0.3` train (`ITMS-90186` / `ITMS-90062` — `CFBundleShortVersionString` must be higher than the previously approved `1.0.3`). The project marketing version is now **`1.0.4`**. Create an **iOS App Version 1.0.4** in ASC and attach the new build there — do not keep uploading to 1.0.3.

Everything below is ready to paste into App Store Connect. Prices are suggestions — you choose the final tiers. Nothing here is a substitute for the manual steps in the checklist at the end.

## 1. App information (App Store Connect → General → App Information)

| Field | Value |
|---|---|
| Name (≤30) | `My Penny` (or, for keywords: `My Penny: Budget Planner`) |
| Subtitle (≤30) | `Budget, bills & savings goals` |
| Primary category | Finance |
| Secondary category (optional) | Productivity |
| Content rights | Does **not** contain, show, or access third-party content |
| Age rating | 4+ (answer every questionnaire item **None/No**) |

## 2. Version metadata — English (Canada) (Version → 1.0.4)

**Promotional text (≤170):**
```
See a clear Safe to Spend estimate from your income, bills, and goals — private, on-device, and free to use with optional Penny Pro.
```

**Keywords (≤100, comma-separated, no spaces):**
```
budget,budgeting,money,finance,spending,savings,bills,expense,tracker,planner,debt,goals,safe
```

**Description:**
```
Penny is a calm, private way to estimate what you can safely spend — without spreadsheets, bank logins, or requiring a paid plan.

Most budgeting apps overwhelm you with charts or ask you to hand over your bank passwords. Penny does the opposite: you tell it your income, bills, and goals, and it turns everything into one clear number — your Safe to Spend estimate for the rest of the month.

Everything stays on your device. No bank connections. No ads. No tracking.

SAFE TO SPEND
- One clear estimate for what's left to spend this month (based on your entries — not a bank balance)
- Accounts for income, bills, spending, and savings you enter

BUDGETS THAT MAKE SENSE
- Simple category budgets with healthy / near-limit / over states
- See planned vs. spent at a glance

BILLS & REMINDERS
- Track recurring bills and due dates
- Optional reminders before a bill is due

SAVINGS GOALS
- Set goals and see estimated monthly savings toward them

DEBT & FORECASTS
- Estimate debt payoff timelines from the balance, rate, and payment you enter
- Lightweight forecasts labeled as estimates (longer ranges with Penny Pro)

WIDGETS
- Safe to Spend and next-bill widgets for your Home and Lock Screen

PRIVATE BY DESIGN
- All data is stored on your device
- No bank logins, no analytics, no ads, no accounts

PENNY PRO (optional)
Unlock unlimited savings goals, extra accounts with goal funding (TFSA / FHSA / more), 6- and 12-month forecasts, CSV + PDF export, and custom accent themes with a one-time lifetime purchase. Penny is fully usable for free. (Cloud sync and bank connections are not included. No subscription required.)

IMPORTANT
Penny is a planning tool, not financial, tax, or investment advice. Figures are estimates from numbers you enter and are not guarantees. Intended for adults managing personal finances; not directed to children under 13.

Penny supports CAD, USD, GBP, EUR, and AUD.

---
Penny Pro Lifetime is a one-time In-App Purchase. Payment is charged to your Apple Account at purchase confirmation. Restore purchases anytime from Settings if you reinstall. Refunds are handled by Apple (reportaproblem.apple.com).
Privacy Policy: https://mayooranthava.github.io/penny/privacy-policy.html
Terms of Use: https://mayooranthava.github.io/penny/terms-of-use.html
```

**What's New (1.0.4):** `Penny Pro: add extra accounts (TFSA, FHSA, RRSP, non-registered) and earmark balances toward savings goals. Free tier still includes three accounts.`

**What's New (1.0.3):** `Lifetime Penny Pro unlock, stronger Terms (refunds, lifetime scope, governing law), onboarding consent, CSV export and accent themes, longer-range Pro forecasts, and clearer Safe-to-Spend estimates.`

**Support URL (required):** `https://mayooranthava.github.io/penny/support.html`

**Marketing URL (optional):** `https://mayooranthava.github.io/penny/`

## 3. Privacy Policy (GitHub Pages)

Hosted like Void Runner. After Pages is enabled (see checklist), paste:

| App Store Connect field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/penny/privacy-policy.html` |
| Terms of Use | `https://mayooranthava.github.io/penny/terms-of-use.html` |
| Support URL | `https://mayooranthava.github.io/penny/support.html` |
| Marketing URL (optional) | `https://mayooranthava.github.io/penny/` |

Source files: `docs/index.html`, `docs/privacy-policy.html`, `docs/terms-of-use.html`, `docs/support.html`. Workflow: `.github/workflows/pages.yml`.

## 4. App Privacy (App Store Connect → App Privacy)

Answer: **"Data is not collected."** This is accurate today — the app has no analytics, tracking, ads, accounts, or network data collection. (If you ever add analytics/crash reporting, you must update this.)

## 5. In-App Purchases (Monetization → In-App Purchases)

> Product IDs must match the app exactly (`PennyProductCatalog` in `Penny/Services/AppSession.swift`). Your bundle ID is `com.mayooran.penny`. **Product IDs are permanent once created.**
>
> **Current monetization: lifetime only.** Do **not** sell `com.penny.app.pro.month` — that ID was created as a **Consumable** by mistake and the app ignores it. Cancel the Create Subscription flow if you started one.

**Non-consumable — Penny Pro (Lifetime)** *(required)*
| Field | Value |
|---|---|
| Type | **Non-Consumable** (not Consumable, not Subscription) |
| Reference Name | `Penny Pro Lifetime` |
| Product ID | `com.penny.app.pro.lifetime` |
| Price | your choice (suggest CAD $24.99–$39.99 one-time) |
| Display Name | `Penny Pro (Lifetime)` |
| Description | `Unlimited goals, extra accounts + goal funding, longer forecasts, CSV export, and accent themes — forever.` |
| Review screenshot | screenshot of the in-app paywall (required) |

**Do not use**
| Product ID | Why |
|---|---|
| `com.penny.app.pro.month` | Wrong type (Consumable). Leave unused. |
| `com.penny.app.pro.monthly` | Draft / wrong. Leave unused or delete if still draft. |

> First-time IAPs must be **submitted together with a new app version**, and **Agreements, Tax, and Banking → Paid Applications** must be active or products won't load.
>
> **“Purchases are unavailable right now” in the app** means StoreKit returned no products. Checklist:
> 1. Paid Applications agreement is **Active**.
> 2. Lifetime is a **Non-Consumable** with Product ID exactly `com.penny.app.pro.lifetime`.
> 3. Price + localization complete (not Missing Metadata).
> 4. Attach the IAP to the app version you submit / test.
> 5. Test via **TestFlight** with a Sandbox Apple Account (Settings → Developer).
> 6. After creating/editing products, wait a few minutes and tap Try again.

## 6. Pricing and Availability

- Price: **Free** (with In-App Purchases)
- Availability: all territories (or your selection)

## 7. Age rating → 4+ (no objectionable content)

## 8. Export compliance

Already handled: `ITSAppUsesNonExemptEncryption = NO`. If prompted, choose **"None of the algorithms mentioned above."**

## 9. App Review Information

- Sign-in required? **No.**
- Demo account: not needed. Notes:
```
No account or login is required. On first launch, choose "Explore with sample data" to see a fully populated example (generic sample data — not a real person).

To review Penny Pro: Settings → Penny Pro → Unlock Penny Pro opens the paywall (one-time lifetime Non-Consumable `com.penny.app.pro.lifetime`). Purchases can be validated in the sandbox. The gentle gate also triggers when adding a 4th savings goal or a 4th account on the free tier.

Penny is 100% on-device: no bank connections, no analytics, no ads, no accounts.
```
- Contact info: your name, phone, email.

## 10. Screenshots (required — capture on your Mac via Simulator)

The app is **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`), so App Store Connect does **not** require iPad screenshots.
- iPhone **6.5"** / **6.9"** (e.g., iPhone 16 Pro Max) — required

Capture ~5: **Home (Safe to Spend)**, **Budget**, **Activity**, **Plan (Goals/Forecast)**, and **Paywall or Settings**. Use "Explore with sample data" so screens look populated. In Simulator: `Device → Trigger Screenshot` (⌘S).

> After merging this change, upload a **new build** (Xcode Cloud / archive). The old universal build still declares iPad support, so ASC will keep asking for 13" iPad screenshots until you attach an iPhone-only build.

---

# Remaining manual checklist (only you can do these)

1. **Revoke the App Store Connect API key `R3H7Z9G9R8`** that was pasted in chat, and generate a new one. (Users and Access → Integrations.)
2. **Agreements, Tax, and Banking** → accept the **Paid Applications** agreement and complete banking + tax (required for IAP).
3. **Enable GitHub Pages** (one-time — Actions cannot do this for you; see `docs/legal-pages.md`):  
   - If the repo is private on a free plan → **Settings → General → Change visibility → Public** (or use GitHub Pro).  
   - **Settings → Pages → Build and deployment → Source: GitHub Actions**  
   - **Actions → GitHub Pages → Run workflow** on `main`  
   - Paste the Privacy / Support URLs from section 3 into ASC.
4. **Create/finish Penny Pro Lifetime** (section 5) as a **Non-Consumable** with ID `com.penny.app.pro.lifetime`. Do not use the mistaken Consumable monthly ID.
5. **Paste** App Information, keywords, promo text, description, What's New (sections 1–2).
6. **Upload screenshots** (section 10).
7. **Answer App Privacy** = Data not collected (section 4) and **Age rating** = 4+ (section 7).
8. **Set pricing** = Free + availability (section 6).
9. **Run pre-release sanity** (`./scripts/pre-release-sanity.sh --xcode` on a Mac, plus the manual steps in [pre-release-sanity.md](./pre-release-sanity.md)).
10. **Upload a build** via Xcode Cloud (push to `main`) and **attach it** to version **1.0.4** (not 1.0.3 — that train is closed).
11. **Fill App Review Information** (section 9), **attach the IAPs to the version**, then **Submit for Review**.

> Prerequisite: the app must compile. Ensure PR #19 (StoreKit `Transaction` fix) is merged before triggering the Archive/upload build.
