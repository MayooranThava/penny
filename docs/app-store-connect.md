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
