#!/usr/bin/env bash
# Pre-release sanity checks for Penny.
#
# Usage:
#   ./scripts/pre-release-sanity.sh           # Linux/core logic + product IDs + drift
#   ./scripts/pre-release-sanity.sh --xcode   # Also build and run every PennyTests case (Mac)
#   ./scripts/pre-release-sanity.sh --help
#
# Exit 0 = automated gate green. Still complete docs/pre-release-sanity.md manual steps.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RUN_XCODE=0
for arg in "$@"; do
  case "$arg" in
    --xcode) RUN_XCODE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

pass() { printf '[pass] %s\n' "$1"; }
fail() { printf '[fail] %s\n' "$1" >&2; exit 1; }
header() { printf '\n== %s ==\n' "$1"; }

header "1. Core logic drift (PennyCoreLogic vs Penny/Services)"
python3 "$ROOT/scripts/check-core-logic-drift.py"
pass "Shared logic matches"

header "2. Xcode test layout (scheme, fixtures, isolation, no PennyTests filter)"
python3 "$ROOT/scripts/check-xcode-test-layout.py"
pass "Test layout matches CI"

header "3. Product IDs (catalog <-> Penny.storekit)"
"$ROOT/scripts/check-product-ids.sh"
pass "Product IDs match"

header "4. Core logic release sanity (Linux / Mac)"
if ! command -v swift >/dev/null 2>&1; then
  fail "swift toolchain not found - install Swift or run on a machine with Xcode/Swift"
fi

SANITY_LOG="$(mktemp)"
(cd "$ROOT/Tools/PennyCoreLogic" && swift test --filter ReleaseSanity) | tee "$SANITY_LOG"
if grep -q "No matching test cases were run" "$SANITY_LOG"; then
  rm -f "$SANITY_LOG"
  fail "No tests matched filter ReleaseSanity"
fi
if ! grep -q "Test run with .* tests passed" "$SANITY_LOG"; then
  rm -f "$SANITY_LOG"
  fail "Release Sanity suite did not report a passing test run"
fi
rm -f "$SANITY_LOG"
pass "PennyCoreLogic Release Sanity passed"

header "5. Full PennyCoreLogic suite"
(cd "$ROOT/Tools/PennyCoreLogic" && swift test)
pass "PennyCoreLogic full suite passed"

if [[ "$RUN_XCODE" -eq 1 ]]; then
  header "6. Xcode build-for-testing and the full PennyTests target"
  if ! command -v xcodebuild >/dev/null 2>&1; then
    fail "xcodebuild not found - run without --xcode on Linux, or use a Mac with Xcode"
  fi
  "$ROOT/scripts/ci-macos.sh"
  pass "Xcode PennyTests passed"
else
  header "6. Xcode PennyTests (skipped)"
  echo "On a Mac, re-run with --xcode (or ./scripts/ci-macos.sh). GitHub Actions runs that job on every PR."
fi

header "Done"
cat <<'EOF'

Automated checks passed.

Before releasing, also complete the short manual checklist:
  docs/pre-release-sanity.md

Suggested flow:
  1. ./scripts/pre-release-sanity.sh --xcode   # on Mac
  2. Manual smoke on Simulator / TestFlight
  3. Archive / Xcode Cloud -> attach build to ASC version
EOF
