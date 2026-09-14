# App Store Connect & TestFlight — Penny

Same workflow pattern as **Void Runner** (`ApolloX_IOS`).

## Identifiers

| Item | Value |
|---|---|
| App name | Penny |
| Bundle ID | `com.mayooran.penny` (registered in ASC: `SNH525T7U8`) |
| Team ID | `2YJ478267N` |
| SKU (suggested) | `penny-ios` |
| Primary language | English (U.S.) |

## What the API can and cannot do

| Action | Public ASC API |
|---|---|
| Register Bundle ID | Yes (`scripts/asc_setup_penny.py ensure-bundle-id`) |
| Create App Store Connect app record | **No** — do once in the website |
| Upload build to TestFlight | Via `xcodebuild -exportArchive` on a Mac |
| Fill listing metadata | Partially (after the app exists) |

Apple returns `403` for `POST /v1/apps` regardless of Admin role.

## One-time setup

### 1. API credentials (local env — do not commit the `.p8`)

```bash
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # Users and Access → Integrations
export ASC_KEY_ID="AJ6G86WBA2"   # Admin key named "cursor"
export ASC_PRIVATE_KEY="$(cat ~/AuthKey_AJ6G86WBA2.p8)"
```

### 2. Register the Bundle ID

```bash
python3 -m pip install PyJWT cryptography
python3 scripts/asc_setup_penny.py status
python3 scripts/asc_setup_penny.py ensure-bundle-id
```

### 3. Create the app record (website, once)

1. [App Store Connect → My Apps → +](https://appstoreconnect.apple.com/apps)
2. **New App**
3. Platforms: **iOS**
4. Name: **Penny**
5. Primary Language: **English (U.S.)**
6. Bundle ID: **com.mayooran.penny**
7. SKU: **penny-ios**
8. User Access: **Full Access**
9. Create

### 4. Xcode signing

- Team: **Mayooran Thavajogarasa** / `2YJ478267N`
- Bundle Identifier: `com.mayooran.penny`
- Automatically manage signing: on

`DEVELOPMENT_TEAM` is set in the Xcode project / archive script.

## Upload a TestFlight build (on your Mac)

```bash
# From the repo root, with Xcode installed and team signed in:
chmod +x scripts/archive-for-testflight.sh
./scripts/archive-for-testflight.sh
```

Then open **App Store Connect → Penny → TestFlight**. Wait for processing, add internal testers to a group, and install via the TestFlight app.

Bump **Current Project Version** (`CURRENT_PROJECT_VERSION`) before each new upload.

## Internal testing checklist

1. App record exists in ASC
2. At least one processed build in TestFlight
3. Internal group has your Apple ID
4. Build is assigned to that group
5. On device: TestFlight → Penny → Install

## Security

- Never commit `AuthKey_*.p8` or paste keys into the repo
- Prefer macOS Keychain / local env exports
- Rotate the Admin key if it was shared in chat
