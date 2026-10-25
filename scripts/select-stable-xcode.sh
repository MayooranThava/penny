#!/usr/bin/env bash
# Point DEVELOPER_DIR and xcode-select at the newest stable Xcode on this Mac.
# Beta, preview, and release-candidate app bundles are ignored.
set -euo pipefail

if [[ ! -d /Applications ]]; then
  echo "select-stable-xcode.sh needs a Mac with Xcode installed under /Applications." >&2
  exit 1
fi

eval "$(
  python3 - <<'PY'
import os
import pathlib
import re
import shlex
import subprocess
import sys

skip = re.compile(r"beta|preview|release[ _-]?candidate|(^|[^A-Za-z])rc([^A-Za-z]|$)", re.I)
candidates = []
for app in sorted(pathlib.Path("/Applications").glob("Xcode*.app")):
    if skip.search(app.name):
        print(f"skip {app.name}", file=sys.stderr)
        continue
    developer = app / "Contents" / "Developer"
    if not developer.is_dir():
        continue
    env = os.environ.copy()
    env["DEVELOPER_DIR"] = str(developer)
    try:
        output = subprocess.check_output(
            ["xcodebuild", "-version"],
            env=env,
            text=True,
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as exc:
        print(f"skip {app.name}: {exc.output}", file=sys.stderr)
        continue
    first = output.splitlines()[0] if output.splitlines() else ""
    if skip.search(output):
        print(f"skip {app.name}: {first}", file=sys.stderr)
        continue
    match = re.search(r"Xcode\s+(\d+(?:\.\d+)*)", first)
    if not match:
        print(f"skip {app.name}: unrecognized {first!r}", file=sys.stderr)
        continue
    version = match.group(1)
    parts = tuple(int(part) for part in version.split("."))
    candidates.append((parts, version, str(app), str(developer), first))

if not candidates:
    sys.exit("No stable Xcode found under /Applications")

candidates.sort()
_, version, app, developer, first = candidates[-1]
print(f"Selected {first}", file=sys.stderr)
print(f"SELECTED_VERSION={shlex.quote(version)}")
print(f"SELECTED_APP={shlex.quote(app)}")
print(f"SELECTED_DEV={shlex.quote(developer)}")
PY
)"

export DEVELOPER_DIR="$SELECTED_DEV"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DEVELOPER_DIR=$SELECTED_DEV" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$SELECTED_VERSION"
    echo "path=$SELECTED_APP"
    echo "developer_dir=$SELECTED_DEV"
  } >> "$GITHUB_OUTPUT"
fi

if [[ "$(id -u)" -eq 0 ]]; then
  xcode-select -s "$SELECTED_DEV"
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo xcode-select -s "$SELECTED_DEV"
else
  xcode-select -s "$SELECTED_DEV"
fi

xcodebuild -version
echo "Using $SELECTED_APP ($SELECTED_VERSION)"
