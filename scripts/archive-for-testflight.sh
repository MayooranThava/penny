#!/usr/bin/env bash
# Archive Penny and upload to App Store Connect (TestFlight) from a Mac.
# Prefer Xcode Cloud on main (same as Void Runner). This script is a rare manual fallback.
# Same signing team as Void Runner (ApolloX_IOS).
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
  echo "xcodebuild not found. Run this script on macOS with Xcode installed." >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Missing $EXPORT_OPTIONS" >&2
  exit 1
fi

echo "==> Clean archive (Release)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$ROOT/build"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID"

echo "==> Export and upload to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "Done. Check App Store Connect → TestFlight for processing."
echo "Bump CURRENT_PROJECT_VERSION in Xcode before the next upload."
