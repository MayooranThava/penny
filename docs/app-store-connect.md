# App Store Connect & TestFlight — My Penny

Same workflow pattern as **Void Runner** (`ApolloX_IOS`).

## Identifiers

| Item | Value |
|---|---|
| App Store name | **My Penny** |
| Home-screen name | Penny |
| App ID | `6811749191` |
| Bundle ID | `com.mayooran.penny` (`SNH525T7U8`) |
| SKU | `penny-ios` |
| Team ID | `2YJ478267N` |
| Primary locale | English (Canada) |
| Internal TestFlight group | **Internal Testers** (`e2003e1f-f82e-4bd0-85f9-a5dfc4f4cec5`) |

## Current status (API-checked)

- App record: **exists**
- App Store version 1.0: **Prepare for Submission**
- Builds uploaded: **0** (none yet)
- Internal group: **created** (`hasAccessToAllBuilds = true`)

## What this environment cannot do

Uploading a TestFlight **build** requires archiving a signed `.ipa` with **Xcode on a Mac**. This Linux agent cannot produce or upload iOS binaries. After you upload once from your Mac, the Internal Testers group will automatically see builds.

## Upload build #1 (on your Mac)

```bash
cd /path/to/penny
git pull
# Confirm signing: Team 2YJ478267N, Bundle ID com.mayooran.penny
open Penny.xcodeproj
# Product → Archive  (or):
./scripts/archive-for-testflight.sh
```

Then:

1. Wait for email / ASC: **Processing complete** (often 5–20 min)
2. App Store Connect → **My Penny** → **TestFlight**
3. Confirm build appears under iOS builds
4. **Internal Testers** group already has access to all builds
5. On iPhone: install **TestFlight** → accept invite if prompted → install **My Penny**

Internal testers must be App Store Connect users on the team (Account Holder/Admin/etc.). Your admin Apple ID `mayooranthava@outlook.com` is eligible.

## Bump build number each upload

In Xcode, increment **Current Project Version** (`CURRENT_PROJECT_VERSION`) before every new archive. Marketing version can stay `1.0.0` for now.

## API helper

```bash
export ASC_ISSUER_ID="62c11ca7-f94e-4d56-8ecd-52c8c725cc18"
export ASC_KEY_ID="AJ6G86WBA2"
export ASC_PRIVATE_KEY="$(cat ~/AuthKey_AJ6G86WBA2.p8)"
python3 scripts/asc_setup_penny.py status
```

## Security

- Do not commit `.p8` keys
- Rotate the Admin key that was shared in chat when convenient
