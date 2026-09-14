#!/usr/bin/env bash
# CI / Mac helper: archive Penny (Release) and upload to App Store Connect.
# Uses App Store Connect API key auth (Xcode 15+) so no local certs are needed.
#
# Required env:
#   ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH  (path to AuthKey_*.p8)
# Optional:
#   PENNY_BUILD_NUMBER  (defaults to CURRENT_PROJECT_VERSION in the project)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Penny"
PROJECT="$ROOT/Penny.xcodeproj"
ARCHIVE_PATH="$ROOT/build/Penny.xcarchive"
EXPORT_PATH="$ROOT/build/export"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"
TEAM_ID="2YJ478267N"

cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Run on macOS with Xcode installed." >&2
  exit 1
fi

: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required}"
: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH is required (path to .p8)}"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "ASC API key file not found: $ASC_KEY_PATH" >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Missing $EXPORT_OPTIONS" >&2
  exit 1
fi

BUILD_ARGS=()
if [[ -n "${PENNY_BUILD_NUMBER:-}" ]]; then
  BUILD_ARGS+=(CURRENT_PROJECT_VERSION="$PENNY_BUILD_NUMBER")
  echo "==> Build number override: $PENNY_BUILD_NUMBER"
fi

AUTH_ARGS=(
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

echo "==> Clean archive (Release)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$ROOT/build"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  "${BUILD_ARGS[@]}"

echo "==> Export and upload to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]}"

echo "Done. Check App Store Connect → My Penny → TestFlight for processing."
