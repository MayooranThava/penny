# App Store Connect & TestFlight — My Penny

**Preferred path: Xcode Cloud** (same as Void Runner).  
GitHub Actions archive upload is optional fallback only.

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

## Recommended: Xcode Cloud (like Void Runner)

Void Runner (`ApolloX_IOS`) already has an Xcode Cloud product with a **TestFlight** workflow that archives on branch pushes and sends builds to TestFlight.

Penny does **not** have Xcode Cloud enabled yet (no `ciProduct` in App Store Connect). After a one-time enable, every push to `main` can archive and land in TestFlight with **no GitHub Actions secrets and no Mac uploads**.

### One-time setup (App Store Connect or Xcode)

Do this once on your Mac (browser Apple ID login / GitHub OAuth cannot be finished from this Linux agent):

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **My Penny** → **Xcode Cloud**  
   *(or in Xcode: Product → Xcode Cloud → Create Workflow…)*
2. **Get Started** / create product for **My Penny**.
3. Connect the GitHub repo **MayooranThava/penny** (approve the Xcode Cloud GitHub app if asked).
4. Create a workflow (mirror Void Runner’s **TestFlight** workflow):
   - **Name:** `TestFlight`
   - **Start condition:** Branch changes → `main` (Void Runner uses `development`; for Penny use `main`)
   - **Action:** Archive – iOS  
     - Scheme: `Penny`  
     - Deployment: **TestFlight and App Store** (or Internal Testing Only if you prefer)
   - **Post-actions:** TestFlight Internal Testing → group **Internal Testers**  
     - Optional: add an External Testing post-action later
5. Save → start a first build (or push to `main`).

After that, every commit to `main` produces a new TestFlight build. Internal Testers already have **access to all builds**.

### External testing

1. Create an External group under TestFlight.
2. Add an External Testing post-action on the same Xcode Cloud workflow (or a separate release workflow).
3. First external build of a version still needs **Beta App Review** once.

## Optional fallback: GitHub Actions

Only if you do not want Xcode Cloud. Workflow: [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml)

GitHub secrets: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY`  
Optional: `TESTFLIGHT_EXTERNAL_GROUP_ID`

Prefer Xcode Cloud when possible — it matches Void Runner and uses Apple’s signing/hosting.

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
