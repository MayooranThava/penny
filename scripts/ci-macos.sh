#!/usr/bin/env bash
# macOS CI: drift check, build Penny + PennyWidgets + every test target for the
# simulator, then run the entire PennyTests bundle (no -only-testing / -skip-testing).
#
#   ./scripts/ci-macos.sh
#
# On GitHub Actions the workflow selects the newest stable Xcode first.
# Locally this uses the active `xcode-select` unless PENNY_SELECT_XCODE=1.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 "$ROOT/scripts/check-core-logic-drift.py"
python3 "$ROOT/scripts/check-xcode-test-layout.py"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Drift and test-layout checks passed."
  echo "Build and PennyTests need a Mac with Xcode. See docs/ci.md."
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    exit 1
  fi
  exit 0
fi

if [[ "${PENNY_SELECT_XCODE:-}" == "1" ]]; then
  "$ROOT/scripts/select-stable-xcode.sh"
fi

mkdir -p "$ROOT/artifacts"
DD="${PENNY_DERIVED_DATA:-$ROOT/.derivedData}"
mkdir -p "$DD"

DESTINATION="${PENNY_TEST_DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  picked="$(
    python3 - <<'PY'
import json, re, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(raw)
best = None
for runtime, devices in data.get("devices", {}).items():
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    if not match:
        continue
    version = tuple(int(part) for part in match.groups() if part)
    for device in devices:
        if device.get("isAvailable") is False:
            continue
        name = device.get("name") or ""
        if not name.startswith("iPhone") or "SE" in name:
            continue
        exact = 1 if re.fullmatch(r"iPhone \d+", name) else 0
        rank = (version, exact, -len(name), name)
        if best is None or rank > best[0]:
            best = (rank, device["udid"], name, ".".join(str(part) for part in version))
if best is None:
    sys.exit("No available iPhone simulator for the selected Xcode")
_, udid, name, version = best
print(f"{udid}\t{name}\t{version}")
PY
  )"
  UDID="${picked%%$'\t'*}"
  rest="${picked#*$'\t'}"
  SIM_NAME="${rest%%$'\t'*}"
  SIM_OS="${rest#*$'\t'}"
  DESTINATION="platform=iOS Simulator,id=${UDID}"
else
  UDID=""
  SIM_NAME="$DESTINATION"
  SIM_OS=""
fi

echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Destination: $DESTINATION (${SIM_NAME} ${SIM_OS})"

SUMMARY="$ROOT/artifacts/ci-macos-summary.md"
{
  echo "## macOS build and PennyTests"
  echo
  echo "- Xcode: \`$(xcodebuild -version | head -n 1)\`"
  echo "- Destination: \`$DESTINATION\`"
  if [[ -n "$SIM_OS" ]]; then
    echo "- Simulator: $SIM_NAME (iOS $SIM_OS)"
  fi
} > "$SUMMARY"

SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)

echo "Building Penny, PennyWidgets, and every scheme test target (build-for-testing)..."
xcodebuild build-for-testing \
  -project "$ROOT/Penny.xcodeproj" \
  -scheme Penny \
  -destination "$DESTINATION" \
  -derivedDataPath "$DD" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "${SIGNING[@]}" \
  | tee "$ROOT/artifacts/xcodebuild-build.log"

verify_compiled_app_icon() {
  local app=""
  local line
  local icon_name
  while IFS= read -r line; do
    app="$line"
    break
  done < <(find "$DD/Build/Products" -type d -name "Penny.app" -print)
  if [[ -z "$app" || ! -f "$app/Info.plist" ]]; then
    echo "Built Penny.app Info.plist not found under $DD/Build/Products" >&2
    exit 1
  fi
  if ! icon_name="$(plutil -extract CFBundleIconName raw -o - "$app/Info.plist")"; then
    echo "Penny.app Info.plist is missing CFBundleIconName ($app/Info.plist)" >&2
    exit 1
  fi
  icon_name="${icon_name//$'\n'/}"
  icon_name="${icon_name//\"/}"
  if [[ "$icon_name" != "AppIcon" ]]; then
    echo "Penny.app Info.plist CFBundleIconName is '$icon_name', expected AppIcon" >&2
    exit 1
  fi
  if [[ ! -f "$app/Assets.car" ]]; then
    echo "Penny.app is missing Assets.car ($app/Assets.car). The asset catalog was not compiled." >&2
    exit 1
  fi
  echo "Verified $app has CFBundleIconName=AppIcon and Assets.car"
}

require_product() {
  local name="$1"
  local found=""
  local line
  while IFS= read -r line; do
    found="$line"
    break
  done < <(find "$DD/Build/Products" -name "$name" -print)
  if [[ -z "$found" ]]; then
    echo "Missing built product $name" >&2
    find "$DD/Build/Products" \( -name '*.app' -o -name '*.appex' -o -name '*.xctest' \) -print >&2 || true
    exit 1
  fi
  echo "Built $found"
}

require_product "Penny.app"
verify_compiled_app_icon
require_product "PennyWidgets.appex"
while IFS= read -r product; do
  [[ -n "$product" ]] || continue
  require_product "$product"
done < <(python3 "$ROOT/scripts/check-xcode-test-layout.py" --list-products)

# Refuse filters. MigrationTests (and any later upgrade test in PennyTests) must run.
# The case arms are the only mention of those flags; check-xcode-test-layout.py allows them.
forbidden_test_filter() {
  case "$1" in
    -only-testing*|-skip-testing*) return 0 ;;
    *) return 1 ;;
  esac
}

TEST_ARGS=(
  test-without-building
  -project "$ROOT/Penny.xcodeproj"
  -scheme Penny
  -destination "$DESTINATION"
  -derivedDataPath "$DD"
  -parallel-testing-enabled YES
  -resultBundlePath "$ROOT/artifacts/PennyTests.xcresult"
  COMPILER_INDEX_STORE_ENABLE=NO
  "${SIGNING[@]}"
)
for arg in "${TEST_ARGS[@]}"; do
  if forbidden_test_filter "$arg"; then
    echo "Refusing to filter PennyTests ($arg). MigrationTests must run." >&2
    exit 1
  fi
done

rm -rf "$ROOT/artifacts/PennyTests.xcresult"
echo "Running every test on the Penny scheme (parallel where the suite allows it)..."
set +e
xcodebuild "${TEST_ARGS[@]}" | tee "$ROOT/artifacts/xcodebuild-test.log"
status=${PIPESTATUS[0]}
set -e

require_test_token() {
  local token="$1"
  if grep -q "$token" "$ROOT/artifacts/xcodebuild-test.log"; then
    return 0
  fi
  if [[ -d "$ROOT/artifacts/PennyTests.xcresult" ]]; then
    if xcrun xcresulttool get test-results tests --path "$ROOT/artifacts/PennyTests.xcresult" 2>/dev/null | grep -q "$token"; then
      return 0
    fi
    if xcrun xcresulttool get --legacy --format json --path "$ROOT/artifacts/PennyTests.xcresult" 2>/dev/null | grep -q "$token"; then
      return 0
    fi
  fi
  return 1
}

migration_seen=0
timing_seen=0
if require_test_token "v103StoreOpensOnCurrentSchemaWithoutLosingACent"; then
  migration_seen=1
fi
if require_test_token "fiveThousandTransactionUpgradeFinishesWithinAFewSeconds"; then
  timing_seen=1
fi

{
  echo "- build-for-testing: Penny.app, PennyWidgets.appex, and scheme test bundles"
  echo "- PennyTests filter: none (Migration suite is required)"
  echo "- parallel-testing-enabled: YES"
  echo "- xcodebuild exit: $status"
  echo "- v103 upgrade test seen: $migration_seen"
  echo "- 5,000-transaction timing test seen: $timing_seen"
} >> "$SUMMARY"

if [[ "$status" -ne 0 ]]; then
  echo "PennyTests failed (exit $status). See artifacts/xcodebuild-test.log" >&2
  exit "$status"
fi
if [[ "$migration_seen" -ne 1 || "$timing_seen" -ne 1 ]]; then
  echo "PennyTests exited 0 but the upgrade tests did not run." >&2
  echo "Required: v103StoreOpensOnCurrentSchemaWithoutLosingACent and fiveThousandTransactionUpgradeFinishesWithinAFewSeconds." >&2
  echo "Do not filter the PennyTests target." >&2
  exit 1
fi

echo "macOS CI passed."
