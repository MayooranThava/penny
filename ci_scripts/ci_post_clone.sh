#!/bin/sh
# Xcode Cloud: assign a unique CFBundleVersion higher than App Store Connect.
# ASC already has builds 1 and 2 from Mac uploads; CI_BUILD_NUMBER alone can collide.
set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

BASE_OFFSET=2
CI_NUM="${CI_BUILD_NUMBER:-1}"
NEXT=$((CI_NUM + BASE_OFFSET))
if [ "$NEXT" -lt 3 ]; then
  NEXT=3
fi

echo "Setting CURRENT_PROJECT_VERSION to $NEXT (CI_BUILD_NUMBER=$CI_NUM, offset=$BASE_OFFSET)"

# Keep app, widgets, and tests on the same build number.
python3 - <<PY
from pathlib import Path
path = Path("Penny.xcodeproj/project.pbxproj")
text = path.read_text()
import re
updated, n = re.subn(
    r"CURRENT_PROJECT_VERSION = \d+;",
    f"CURRENT_PROJECT_VERSION = {int('$NEXT')};",
    text,
)
if n == 0:
    raise SystemExit("No CURRENT_PROJECT_VERSION entries found")
path.write_text(updated)
print(f"Updated {n} CURRENT_PROJECT_VERSION entries to {int('$NEXT')}")
PY
