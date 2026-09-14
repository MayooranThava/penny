# App Store Connect & TestFlight — My Penny

Same workflow pattern as **Void Runner** (`ApolloX_IOS`).

## Identifiers

| Item | Value |
|---|---|
| App Store name | **My Penny** |
| Home-screen name | Penny |
| App ID | `6811749191` |
| Bundle ID | `com.mayooran.penny` |
| SKU | `penny-ios` |
| Team ID | `2YJ478267N` |
| Primary locale | English (Canada) |
| Internal TestFlight group | **Internal Testers** (`e2003e1f-f82e-4bd0-85f9-a5dfc4f4cec5`) |

## Current status (API-checked)

- App record: **exists**
- App Store version 1.0: **Prepare for Submission**
- Builds uploaded: **0**
- Internal group: **created** (access to all builds)
- Internal tester added: **mayooranthava@outlook.com** (invite/state updates after the first build finishes processing)

## What this agent cannot do

Uploading a TestFlight **build** requires archiving a signed `.ipa` with **Xcode on a Mac**. This Linux environment cannot produce iOS binaries. After you upload once from your Mac, **Internal Testers** will see the build automatically.

## Upload build #1 (on your Mac)

```bash
cd /path/to/penny
git pull
./scripts/archive-for-testflight.sh
```

Or in Xcode: select **Any iOS Device** → **Product → Archive** → **Distribute App → App Store Connect → Upload**.

Then:

1. Wait for processing (often 5–20 minutes)
2. App Store Connect → **My Penny** → **TestFlight**
3. Confirm the build is **Ready to Test**
4. On iPhone: open **TestFlight** → install **My Penny**

## Signing checklist in Xcode

- Team: `2YJ478267N`
- Bundle Identifier: `com.mayooran.penny`
- Automatically manage signing: **on**
- Increment **Current Project Version** before each upload

## API helper

```bash
export ASC_ISSUER_ID="…"
export ASC_KEY_ID="…"
export ASC_PRIVATE_KEY="$(cat ~/AuthKey_XXXX.p8)"
python3 scripts/asc_setup_penny.py status
```

## Security

- Do not commit `.p8` keys
- Rotate the Admin key that was shared in chat when convenient
