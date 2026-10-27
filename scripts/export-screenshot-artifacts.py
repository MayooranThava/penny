#!/usr/bin/env python3
"""Copy screenshot PNGs and performance metrics out of an xcresult bundle."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True)


def export_attachments(xcresult: Path, destination: Path) -> str:
    destination.mkdir(parents=True, exist_ok=True)
    commands = [
        ["xcrun", "xcresulttool", "export", "attachments", "--path", str(xcresult), "--output-path", str(destination)],
        ["xcrun", "xcresulttool", "export", "--type", "directory", "--path", str(xcresult), "--output-path", str(destination)],
    ]
    notes: list[str] = []
    for command in commands:
        completed = run(command)
        notes.append("$ " + " ".join(command))
        notes.append(completed.stdout)
        notes.append(completed.stderr)
        if completed.returncode == 0:
            return "\n".join(notes)
    return "\n".join(notes)


def load_json_documents(root: Path) -> list[object]:
    documents: list[object] = []
    if not root.exists():
        return documents
    for path in root.rglob("*"):
        if path.suffix.lower() not in {".json", ".plist"} or not path.is_file():
            continue
        try:
            documents.append(json.loads(path.read_text()))
        except (OSError, json.JSONDecodeError):
            continue
    return documents


def attachment_names(documents: list[object]) -> dict[str, str]:
    """Map an exported filename to the XCTAttachment name when a manifest has one."""
    found: dict[str, str] = {}

    def visit(node: object) -> None:
        if isinstance(node, dict):
            name = ""
            for key in ("suggestedHumanReadableName", "suggestedFilename", "name", "filename"):
                value = node.get(key)
                if isinstance(value, str) and value.endswith(".png"):
                    name = Path(value).name
                    break
            exported = ""
            for key in ("exportedFileName", "exportedFilename", "path", "fileName"):
                value = node.get(key)
                if isinstance(value, str):
                    exported = Path(value).name
                    break
            if name and exported:
                found[exported] = name
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)

    for document in documents:
        visit(document)
    return found


# Xcode 26 writes "<attachment>_<index>_<UUID>.png" even when the test named it
# "home-light.png". The UUID is not part of the screenshot name.
_XCRESULT_PNG_SUFFIX = re.compile(
    r"^(?P<stem>.+)_\d+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)


def canonical_png_name(name: str) -> str:
    path = Path(name)
    stem = path.stem
    if stem.lower().endswith(".png"):
        stem = stem[:-4]
    match = _XCRESULT_PNG_SUFFIX.fullmatch(stem)
    if match:
        stem = match.group("stem")
        if stem.lower().endswith(".png"):
            stem = stem[:-4]
    return stem + ".png"


def copy_pngs(source: Path, output: Path, names: dict[str, str]) -> list[str]:
    written: list[str] = []
    if not source.exists():
        return written
    for path in sorted(source.rglob("*.png")):
        target_name = canonical_png_name(names.get(path.name, path.name))
        destination = output / target_name
        suffix = 2
        while destination.exists():
            destination = output / f"{Path(target_name).stem}-{suffix}.png"
            suffix += 1
        shutil.copy2(path, destination)
        written.append(destination.name)
    return written


def metrics_from_log(log_text: str) -> list[str]:
    return [line.strip() for line in log_text.splitlines() if "measured [" in line]


def xcresult_tests_json(xcresult: Path) -> str:
    commands = [
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(xcresult)],
        ["xcrun", "xcresulttool", "get", "--legacy", "--format", "json", "--path", str(xcresult)],
    ]
    for command in commands:
        completed = run(command)
        if completed.returncode == 0 and completed.stdout.strip():
            return completed.stdout
    return ""


def xcresult_metrics_text(xcresult: Path) -> str:
    """Signpost submetrics such as hitch time live here, not in the tests summary."""
    commands = [
        ["xcrun", "xcresulttool", "get", "test-results", "metrics", "--path", str(xcresult)],
        ["xcrun", "xcresulttool", "get", "test-results", "test-details", "--path", str(xcresult), "--test-id", "ActivityPerformanceTests/testFiveThousandTransactionActivityScroll()"],
    ]
    chunks: list[str] = []
    for command in commands:
        completed = run(command)
        if completed.stdout.strip():
            chunks.append(completed.stdout)
        elif completed.stderr.strip():
            chunks.append(completed.stderr)
    return "\n".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xcresult", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--require-complete", choices=("yes", "no"), default="yes")
    args = parser.parse_args()

    xcresult = Path(args.xcresult)
    log_path = Path(args.log)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    for stale in output.glob("*"):
        if stale.is_file():
            stale.unlink()

    export_root = output / "_attachments"
    if export_root.exists():
        shutil.rmtree(export_root)
    notes = ""
    if xcresult.exists():
        notes = export_attachments(xcresult, export_root)
    documents = load_json_documents(export_root)
    pngs = copy_pngs(export_root, output, attachment_names(documents))
    if export_root.exists():
        shutil.rmtree(export_root)

    log_text = log_path.read_text(errors="replace") if log_path.is_file() else ""
    measured = metrics_from_log(log_text)
    raw_json = xcresult_tests_json(xcresult) if xcresult.exists() else ""
    metrics_text = xcresult_metrics_text(xcresult) if xcresult.exists() else ""
    blob = "\n".join(measured) + "\n" + raw_json + "\n" + metrics_text

    metric_lines = list(measured)
    if metrics_text.strip():
        metric_lines.append(metrics_text.rstrip())
    (output / "performance-metrics.txt").write_text(
        "\n".join(metric_lines) + ("\n" if metric_lines else "")
    )
    if raw_json:
        (output / "performance-metrics.json").write_text(raw_json)
    else:
        (output / "performance-metrics.json").write_text(json.dumps({"measured": measured}, indent=2) + "\n")
    (output / "export-notes.txt").write_text(notes)

    print(f"Exported {len(pngs)} screenshot(s) and {len(measured)} metric line(s) to {output}")
    if args.require_complete != "yes":
        return 0

    failures: list[str] = []
    if len(pngs) < 20:
        failures.append(f"expected 20 screenshots, found {len(pngs)}: {pngs}")
    expected = [
        "home-light.png",
        "home-light-private.png",
        "home-dark.png",
        "home-dark-private.png",
        "budget-light.png",
        "activity-dark-private.png",
        "settings-dark-private.png",
    ]
    for name in expected:
        if name not in pngs:
            failures.append(f"missing {name}")
    if "testFiveThousandTransactionLaunch" not in blob and "App Launch" not in blob and "AppLaunch" not in blob:
        failures.append("launch metric was not found in the log or xcresult")
    if not re.search(r"hitch", blob, re.I):
        failures.append("scroll hitch metric was not found in the log or xcresult")
    if "scroll" not in blob.lower() and "Scroll" not in blob:
        failures.append("scroll deceleration metric was not found in the log or xcresult")
    if failures:
        for message in failures:
            print(f"[fail] {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
