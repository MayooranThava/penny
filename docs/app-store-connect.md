# App Store Connect & TestFlight — My Penny

Same Apple team / API-key pattern as **Void Runner** (`ApolloX_IOS`), plus **automatic TestFlight uploads on every `main` push**.

> Note: Void Runner’s GitHub Actions only ran unit tests. Archives were still uploaded from a Mac. Penny goes further: `main` → macOS CI → Archive → TestFlight.

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

## Automatic builds (every commit to `main`)

Workflow: [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml)

### One-time GitHub secrets

Repo → **Settings → Secrets and variables → Actions** → add:

| Secret | Value |
|---|---|
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID (Users and Access → Integrations) |
| `ASC_KEY_ID` | Key ID (e.g. `AJ6G86WBA2`) |
| `ASC_PRIVATE_KEY` | Full `.p8` PEM contents (`-----BEGIN PRIVATE KEY-----` …) |
| `TESTFLIGHT_EXTERNAL_GROUP_ID` | *(optional)* External testing group UUID |

Use an **App Manager** or **Admin** API key (same key type as Void Runner).

### What happens on each `main` push

1. GitHub Actions starts on `macos-15`
2. Picks the next `CURRENT_PROJECT_VERSION` (latest ASC build + 1)
3. Archives **Penny** + widgets with ASC API-key signing
4. Uploads to App Store Connect (`ExportOptions.plist` → `destination=upload`)
5. Best-effort assign to Internal Testers (and external group if secret is set)

### Internal vs external

| Track | Behavior |
|---|---|
| **Internal** | App Store Connect users in **Internal Testers**. Enable **automatic distribution** on that group so every processed build appears without manual clicks. |
| **External** | Create an External Testing group in ASC. First build of a version needs **Beta App Review**. After approval, later builds can distribute automatically if the group is set that way. Set `TESTFLIGHT_EXTERNAL_GROUP_ID` so CI can attach builds. |

Manual re-run: Actions → **TestFlight** → **Run workflow**.

## Manual upload (Mac, same as Void Runner)

```bash
cd /path/to/penny
git pull
./scripts/archive-for-testflight.sh
```

Or with the CI script + API key (no Xcode GUI account session required):

```bash
export ASC_ISSUER_ID="…"
export ASC_KEY_ID="…"
export ASC_KEY_PATH="$HOME/AuthKey_${ASC_KEY_ID}.p8"
export PENNY_BUILD_NUMBER="$(python3 scripts/next_build_number.py --fallback 2)"
./scripts/ci_testflight.sh
```

Or in Xcode: **Any iOS Device** → **Product → Archive** → **Distribute App → App Store Connect → Upload**.  
Bump **Current Project Version** before each manual upload if CI is not doing it.

## Signing checklist

- Team: `2YJ478267N`
- App Bundle ID: `com.mayooran.penny`
- Widget Bundle ID: `com.mayooran.penny.widgets`
- App Group: `group.com.mayooran.penny` on both targets
- Automatically manage signing: **on**
- Widget `Info.plist` must include `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`

## API helper

```bash
export ASC_ISSUER_ID="…"
export ASC_KEY_ID="…"
export ASC_PRIVATE_KEY="$(cat ~/AuthKey_XXXX.p8)"
python3 scripts/asc_setup_penny.py status
python3 scripts/next_build_number.py
```

## Security

- Do not commit `.p8` keys
- Store them only in GitHub Actions secrets / your password manager
- Rotate any Admin key that was pasted into chat
