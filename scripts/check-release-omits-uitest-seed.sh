#!/usr/bin/env bash
# Build Penny in the Release configuration and fail if the executable contains
# UITestSeedLaunch. The screenshot seed is compiled only for Screenshots.
#
#   ./scripts/check-release-omits-uitest-seed.sh
#   ./scripts/check-release-omits-uitest-seed.sh --self-test
#
# `--self-test` checks the symbol filter without Xcode. The real build runs on
# the macOS CI job, which ci-gate requires.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Drop compiler filenames. Keep a Swift type name or mangled symbol.
filter_seed_hits() {
  grep -F "UITestSeedLaunch" \
    | grep -E -v 'UITestSeedLaunch\.(swift|o|swiftdeps|swiftmodule|dSYM)($|[^A-Za-z0-9])' \
    || true
}

self_test() {
  local hits
  hits="$(printf '%s\n' 'Penny/App/UITestSeedLaunch.swift' 'UITestSeedLaunch.o' | filter_seed_hits)"
  if [[ -n "$hits" ]]; then
    echo "self-test: source filename should be ignored" >&2
    exit 1
  fi
  hits="$(printf '%s\n' '_$s5Penny17UITestSeedLaunchOMf' | filter_seed_hits)"
  if [[ -z "$hits" ]]; then
    echo "self-test: mangled UITestSeedLaunch symbol should fail the check" >&2
    exit 1
  fi
  hits="$(printf '%s\n' 'UITestSeedLaunch' | filter_seed_hits)"
  if [[ -z "$hits" ]]; then
    echo "self-test: UITestSeedLaunch type name should fail the check" >&2
    exit 1
  fi
  hits="$(printf '%s\n' 'no seed here' | filter_seed_hits)"
  if [[ -n "$hits" ]]; then
    echo "self-test: unrelated text should be ignored" >&2
    exit 1
  fi
  echo "seed-symbol filter self-test passed"
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. The Release seed-symbol check needs a Mac with Xcode."
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    exit 1
  fi
  exit 0
fi

if ! command -v nm >/dev/null 2>&1 || ! command -v strings >/dev/null 2>&1; then
  echo "nm and strings are required to inspect the Release executable." >&2
  exit 1
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
  SIM_NAME="$DESTINATION"
  SIM_OS=""
fi

echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Release seed check destination: $DESTINATION (${SIM_NAME} ${SIM_OS})"

# Release compilation conditions stay in the project. Signing and product
# validation are skipped so the simulator build can finish.
SIGNING=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=-
  VALIDATE_PRODUCT=NO
)

LOG="$ROOT/artifacts/xcodebuild-release-seed-guard.log"
echo "Building Penny in Release..."
set +e
xcodebuild build \
  -project "$ROOT/Penny.xcodeproj" \
  -scheme Penny \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DD" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "${SIGNING[@]}" \
  | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
if [[ "$status" -ne 0 ]]; then
  echo "Release build failed (exit $status). See $LOG" >&2
  exit "$status"
fi

binary=""
while IFS= read -r line; do
  binary="$line"
  break
done < <(find "$DD/Build/Products/Release-iphonesimulator" -type f -path '*/Penny.app/Penny' -print)
if [[ -z "$binary" || ! -s "$binary" ]]; then
  echo "Release Penny executable not found under $DD/Build/Products/Release-iphonesimulator" >&2
  find "$DD/Build/Products" -name 'Penny.app' -print >&2 || true
  exit 1
fi

echo "Checking $binary for UITestSeedLaunch"
nm_hits="$(nm -a "$binary" | filter_seed_hits)"
string_hits="$(strings -a "$binary" | filter_seed_hits)"
if [[ -n "$nm_hits" || -n "$string_hits" ]]; then
  echo "Release Penny executable contains UITestSeedLaunch. The screenshot seed must be compiled only for the Screenshots configuration." >&2
  if [[ -n "$nm_hits" ]]; then
    echo "nm:" >&2
    printf '%s\n' "$nm_hits" >&2
  fi
  if [[ -n "$string_hits" ]]; then
    echo "strings:" >&2
    printf '%s\n' "$string_hits" >&2
  fi
  exit 1
fi

echo "Release Penny executable has no UITestSeedLaunch symbol."
