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

# App Store submission prep (v1.0.0)

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

## 2. Version metadata — English (Canada) (Version → 1.0.0)

**Promotional text (≤170):**
```
Know exactly what's safe to spend today. Penny turns your income, bills, and goals into one calm number — private, on-device, and free of expensive subscriptions.
```

**Keywords (≤100, comma-separated, no spaces):**
```
budget,budgeting,money,finance,spending,savings,bills,expense,tracker,planner,debt,goals,safe
```

**Description:**
```
Penny is a calm, private way to see exactly what you can safely spend — without spreadsheets, bank logins, or an expensive subscription.

Most budgeting apps overwhelm you with charts or ask you to hand over your bank passwords. Penny does the opposite: you tell it your income, bills, and goals, and it turns everything into one clear number — your Safe to Spend for the rest of the month.

Everything stays on your device. No bank connections. No ads. No tracking.

SAFE TO SPEND
- One clear number for what's left to spend this month
- Automatically accounts for income, bills, spending, and savings

BUDGETS THAT MAKE SENSE
- Simple category budgets with healthy / near-limit / over states
- See planned vs. spent at a glance

BILLS & REMINDERS
- Track recurring bills and due dates
- Optional reminders before a bill is due

SAVINGS GOALS
- Set goals and see how much to save each month to reach them

DEBT & FORECASTS
- Estimate debt payoff timelines
- Peek a few months ahead with lightweight forecasts (always labeled as estimates)

WIDGETS
- Safe to Spend and next-bill widgets for your Home and Lock Screen

PRIVATE BY DESIGN
- All data is stored on your device
- No bank logins, no analytics, no ads, no accounts

PENNY PRO (optional)
Unlock unlimited savings goals, advanced forecasts, CSV export, iCloud sync, and custom themes. Available as an annual subscription with a free trial, or a one-time lifetime purchase. Penny is fully usable for free.

Penny supports CAD, USD, GBP, EUR, and AUD.

---
Penny Pro (Annual) is an auto-renewing subscription. Payment is charged to your Apple Account at purchase confirmation. It renews automatically unless canceled at least 24 hours before the end of the period. Manage or cancel anytime in your Apple Account settings.
Privacy Policy: https://mayooranthava.github.io/penny/privacy-policy.html
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**What's New (1.0.0):** `First release of Penny — safe-to-spend budgeting, bills, savings goals, forecasts, and widgets. All on-device.`

**Support URL (required):** `https://mayooranthava.github.io/penny/support.html`

**Marketing URL (optional):** `https://mayooranthava.github.io/penny/`

## 3. Privacy Policy (GitHub Pages)

Hosted like Void Runner. After Pages is enabled (see checklist), paste:

| App Store Connect field | URL |
|---|---|
| Privacy Policy | `https://mayooranthava.github.io/penny/privacy-policy.html` |
| Support URL | `https://mayooranthava.github.io/penny/support.html` |
| Marketing URL (optional) | `https://mayooranthava.github.io/penny/` |

Source files: `docs/index.html`, `docs/privacy-policy.html`, `docs/support.html`. Workflow: `.github/workflows/pages.yml`.

## 4. App Privacy (App Store Connect → App Privacy)

Answer: **"Data is not collected."** This is accurate today — the app has no analytics, tracking, ads, accounts, or network data collection. (If you ever add analytics/crash reporting, you must update this.)

## 5. In-App Purchases (Monetization → In-App Purchases & Subscriptions)

> ⚠️ Decide product-ID convention first. The app currently uses `com.penny.app.pro.annual` and `com.penny.app.pro.lifetime` (see `PennyProductCatalog` in `Penny/Services/AppSession.swift`). Your bundle ID is `com.mayooran.penny`. **Product IDs are permanent once created.** Either:
> - **(A) Keep** the existing IDs — no code change. Create the IAPs with exactly those IDs, or
> - **(B) Rename** to `com.mayooran.penny.pro.annual` / `.lifetime` for consistency — requires a one-line-each code change in `PennyProductCatalog` and `Penny.storekit`. Ask and I'll make it.

**Subscription group:** `Penny Pro`

**Auto-renewable subscription — Penny Pro (Annual)**
| Field | Value |
|---|---|
| Reference Name | `Penny Pro Annual` |
| Product ID | `com.penny.app.pro.annual` |
| Duration | 1 Year |
| Price | your choice (suggest CAD $39.99/yr) |
| Introductory Offer | Free trial, 1 week |
| Display Name | `Penny Pro (Annual)` |
| Description | `Unlock every Penny Pro feature. 7-day free trial, then billed yearly. Cancel anytime.` |
| Review screenshot | screenshot of the in-app paywall (required) |

**Non-consumable — Penny Pro (Lifetime)**
| Field | Value |
|---|---|
| Reference Name | `Penny Pro Lifetime` |
| Product ID | `com.penny.app.pro.lifetime` |
| Price | your choice (suggest CAD $79.99 one-time) |
| Display Name | `Penny Pro (Lifetime)` |
| Description | `Unlock every Penny Pro feature forever with a single purchase.` |
| Review screenshot | screenshot of the in-app paywall (required) |

> First-time IAPs must be **submitted together with the app version** (attach them to the 1.0.0 submission), and **Agreements, Tax, and Banking → Paid Applications** must be active or products won't load.

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

To review Penny Pro: Settings → Penny Pro → Unlock Penny Pro opens the paywall. Purchases can be validated in the sandbox. The gentle gate also triggers when adding a 4th savings goal on the free tier.

Penny is 100% on-device: no bank connections, no analytics, no ads, no accounts.
```
- Contact info: your name, phone, email.

## 10. Screenshots (required — capture on your Mac via Simulator)

The app is **universal (iPhone + iPad)**, so App Store Connect requires **both** sets:
- iPhone **6.9"** (e.g., iPhone 16 Pro Max) — required
- iPad **13"** — required (or set the target to iPhone-only to skip iPad)

Capture ~5 each: **Home (Safe to Spend)**, **Budget**, **Activity**, **Plan (Goals/Forecast)**, and **Paywall or Settings**. Use "Explore with sample data" so screens look populated. In Simulator: `Device → Trigger Screenshot` (⌘S).

---

# Remaining manual checklist (only you can do these)

1. **Revoke the App Store Connect API key `R3H7Z9G9R8`** that was pasted in chat, and generate a new one. (Users and Access → Integrations.)
2. **Agreements, Tax, and Banking** → accept the **Paid Applications** agreement and complete banking + tax (required for IAP).
3. **Enable GitHub Pages** (one-time — Actions cannot do this for you; see `docs/legal-pages.md`):  
   - If the repo is private on a free plan → **Settings → General → Change visibility → Public** (or use GitHub Pro).  
   - **Settings → Pages → Build and deployment → Source: GitHub Actions**  
   - **Actions → GitHub Pages → Run workflow** on `main`  
   - Paste the Privacy / Support URLs from section 3 into ASC.
4. **Create the two IAPs** (section 5) — decide the product-ID convention first.
5. **Paste** App Information, keywords, promo text, description, What's New (sections 1–2).
6. **Upload screenshots** (section 10).
7. **Answer App Privacy** = Data not collected (section 4) and **Age rating** = 4+ (section 7).
8. **Set pricing** = Free + availability (section 6).
9. **Upload a build (≥ build 3)** via Xcode Cloud (push to `main`) and **attach it** to version 1.0.0. Make sure the StoreKit fix (PR #19) is merged so the Archive build succeeds.
10. **Fill App Review Information** (section 9), **attach the IAPs to the version**, then **Submit for Review**.

> Prerequisite: the app must compile. Ensure PR #19 (StoreKit `Transaction` fix) is merged before triggering the Archive/upload build.
