#!/usr/bin/env bash
# Release UI tests: demo screenshots plus 5,000-transaction launch and scroll metrics.
# Not part of ci-gate. GitHub Actions runs this on push to main and workflow_dispatch.
#
#   ./scripts/ci-screenshots.sh
#
# Uses the active Xcode unless PENNY_SELECT_XCODE=1 (Actions selects a stable Xcode first).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Screenshot capture needs a Mac with Xcode. See docs/ci.md."
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    exit 1
  fi
  exit 0
fi

if [[ "${PENNY_SELECT_XCODE:-}" == "1" ]]; then
  "$ROOT/scripts/select-stable-xcode.sh"
fi

mkdir -p "$ROOT/artifacts/app-screenshots"
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
  SIM_NAME="$DESTINATION"
  SIM_OS=""
fi

echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Destination: $DESTINATION (${SIM_NAME} ${SIM_OS})"

# Release matches the shipped app. Signing and product validation are skipped
# so the simulator can install the build; Swift optimization and the missing
# DEBUG flag stay on the Release configuration.
SIGNING=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=-
  VALIDATE_PRODUCT=NO
)

RESULT="$ROOT/artifacts/PennyScreenshots.xcresult"
LOG="$ROOT/artifacts/xcodebuild-screenshots.log"
rm -rf "$RESULT"

echo "Running PennyUITests in Release (screenshots and performance)..."
set +e
xcodebuild test \
  -project "$ROOT/Penny.xcodeproj" \
  -scheme PennyScreenshots \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DD" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RESULT" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "${SIGNING[@]}" \
  | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

set +e
python3 "$ROOT/scripts/export-screenshot-artifacts.py" \
  --xcresult "$RESULT" \
  --log "$LOG" \
  --output "$ROOT/artifacts/app-screenshots" \
  --require-complete "$([[ "$status" -eq 0 ]] && echo yes || echo no)"
export_status=$?
set -e

if [[ "$status" -ne 0 ]]; then
  echo "PennyUITests failed (exit $status). See $LOG" >&2
  exit "$status"
fi
if [[ "$export_status" -ne 0 ]]; then
  echo "Screenshot export failed (exit $export_status)." >&2
  exit "$export_status"
fi

echo "Screenshots and performance metrics are in artifacts/app-screenshots."
