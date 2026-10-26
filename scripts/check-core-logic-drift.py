#!/usr/bin/env python3
"""Fail when Tools/PennyCoreLogic drifts from Penny's shared calculation sources.

Symlinks (or a shared Xcode source list) are a poor fit. The Linux package must
stay Foundation-only and `public`, and it cannot import Penny's SwiftData
models. `BillRecurrence` lives on the app model, with UI helpers; the package
keeps a case-only stand-in. CSV / goal types also need explicit public
initializers that the app gets for free as internal types.

This script compares logic after stripping those packaging-only differences:
`public`, `Sendable`, memberwise initializers, comments, and the recurrence
shim. A real calculation change in only one copy fails the check.

Mapped files:
  Penny/Services/FinanceCalculator.swift
  Penny/Services/InsightEngine.swift
  Penny/Services/ApplePayCaptureLogic.swift
  Penny/Services/CSVExportLogic.swift
  Penny/Services/BillPaymentCycle.swift
  Penny/Utilities/DateHelpers.swift        (mirrored; not under Services/)
  Penny/Utilities/MoneyFormatters.swift    (mirrored; not under Services/)
  Penny/Services/PrivateModeLogic.swift
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Tools" / "PennyCoreLogic" / "Sources" / "PennyCoreLogic"

# package file -> app file
PAIRS: list[tuple[str, str]] = [
    ("FinanceCalculator.swift", "Penny/Services/FinanceCalculator.swift"),
    ("InsightEngine.swift", "Penny/Services/InsightEngine.swift"),
    ("ApplePayCaptureLogic.swift", "Penny/Services/ApplePayCaptureLogic.swift"),
    ("CSVExportLogic.swift", "Penny/Services/CSVExportLogic.swift"),
    ("BillPaymentCycle.swift", "Penny/Services/BillPaymentCycle.swift"),
    ("DateHelpers.swift", "Penny/Utilities/DateHelpers.swift"),
    ("MoneyFormatters.swift", "Penny/Utilities/MoneyFormatters.swift"),
    ("PrivateModeLogic.swift", "Penny/Services/PrivateModeLogic.swift"),
]

# Intentionally empty. Decimal.from and Apple Pay cent rounding now match the app.
# A new difference still fails. Do not reintroduce a deferred entry to hide one.
DEFERRED_DIFFS: dict[str, str] = {}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*?$", "", text, flags=re.M)
    return text


def strip_public_and_sendable(text: str) -> str:
    text = re.sub(r"\bpublic\s+", "", text)
    text = re.sub(r",\s*Sendable\b", "", text)
    text = re.sub(r":\s*Sendable\b", "", text)
    text = re.sub(r"\bSendable\b", "", text)
    return text


def find_matching(text: str, open_index: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    for index in range(open_index, len(text)):
        char = text[index]
        if char == open_ch:
            depth += 1
        elif char == close_ch:
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unbalanced {open_ch}{close_ch} starting at {open_index}")


def is_memberwise_body(body: str) -> bool:
    statements: list[str] = []
    for line in strip_comments(body).splitlines():
        stripped = line.strip()
        if stripped:
            statements.append(stripped)
    if not statements:
        return False
    assignment = re.compile(r"^self\.[A-Za-z_][A-Za-z0-9_]*\s*=\s*[A-Za-z_][A-Za-z0-9_]*$")
    return all(assignment.match(statement) for statement in statements)


def strip_memberwise_inits(text: str) -> str:
    """Drop initializers whose body is only `self.field = field`."""
    pattern = re.compile(r"\binit\s*\(")
    pieces: list[str] = []
    cursor = 0
    for match in pattern.finditer(text):
        if match.start() < cursor:
            continue
        paren = text.find("(", match.start())
        try:
            paren_end = find_matching(text, paren, "(", ")")
        except ValueError:
            continue
        brace = paren_end + 1
        while brace < len(text) and text[brace] in " \t\r\n":
            brace += 1
        if brace >= len(text) or text[brace] != "{":
            continue
        try:
            brace_end = find_matching(text, brace, "{", "}")
        except ValueError:
            continue
        if not is_memberwise_body(text[brace + 1 : brace_end]):
            continue
        pieces.append(text[cursor:match.start()])
        cursor = brace_end + 1
    pieces.append(text[cursor:])
    return "".join(pieces)


def extract_enum_cases(text: str, enum_name: str) -> list[str]:
    match = re.search(rf"\benum\s+{re.escape(enum_name)}\b[^{{]*\{{", text)
    if not match:
        raise ValueError(f"enum {enum_name} not found")
    open_brace = match.end() - 1
    close_brace = find_matching(text, open_brace, "{", "}")
    body = text[open_brace + 1 : close_brace]
    cases: list[str] = []
    for raw in re.findall(r"\bcase\s+([^:\n]+)", body):
        # Stop before an associated-value or raw-value payload on the same line.
        raw = raw.split("//", 1)[0]
        for part in raw.split(","):
            name = part.strip()
            if not name or name.startswith("case"):
                continue
            name = re.match(r"[A-Za-z_][A-Za-z0-9_]*", name)
            if name:
                cases.append(name.group(0))
    return cases


def remove_top_level_enum(text: str, enum_name: str) -> str:
    match = re.search(rf"\benum\s+{re.escape(enum_name)}\b[^{{]*\{{", text)
    if not match:
        return text
    open_brace = match.end() - 1
    close_brace = find_matching(text, open_brace, "{", "}")
    return text[: match.start()] + text[close_brace + 1 :]


def normalize_lines(text: str) -> list[str]:
    text = strip_comments(text)
    text = strip_public_and_sendable(text)
    text = strip_memberwise_inits(text)
    lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped:
            lines.append(stripped)
    return lines


def prepare_package(filename: str, text: str) -> str:
    if filename == "FinanceCalculator.swift":
        text = remove_top_level_enum(text, "BillRecurrence")
    if filename == "BillPaymentCycle.swift":
        text = remove_top_level_enum(text, "Recurrence")
        # The nested shim is gone; remaining mentions are the app's type name.
        text = re.sub(r"\bRecurrence\b", "BillRecurrence", text)
    return text


def unified_diff(app_lines: list[str], package_lines: list[str], app_path: str, package_path: str) -> str:
    import difflib

    diff = difflib.unified_diff(
        app_lines,
        package_lines,
        fromfile=app_path,
        tofile=package_path,
        lineterm="",
    )
    return "\n".join(diff)


def main() -> int:
    package_sources = sorted(path.name for path in PACKAGE.glob("*.swift"))
    mapped = [name for name, _ in PAIRS]
    unknown = sorted(set(package_sources) - set(mapped))
    missing = sorted(set(mapped) - set(package_sources))
    failures: list[str] = []

    if unknown or missing:
        failures.append(
            "PennyCoreLogic source list does not match the drift manifest.\n"
            f"  unmapped package files: {unknown or '[]'}\n"
            f"  missing package files: {missing or '[]'}"
        )

    models = (ROOT / "Penny" / "Models" / "Models.swift").read_text()
    try:
        app_cases = extract_enum_cases(models, "BillRecurrence")
    except ValueError as exc:
        failures.append(str(exc))
        app_cases = []

    print("Core logic drift check")
    print("Compared PennyCoreLogic sources to Penny/Services and Penny/Utilities")
    print("after ignoring public, Sendable, memberwise inits, comments, and the")
    print("BillRecurrence shim (cases still have to match Penny/Models).")
    print()

    for filename, app_rel in PAIRS:
        package_path = PACKAGE / filename
        app_path = ROOT / app_rel
        if not package_path.is_file() or not app_path.is_file():
            failures.append(f"missing pair: {package_path} or {app_path}")
            continue
        package_text = package_path.read_text()
        app_text = app_path.read_text()
        if filename == "FinanceCalculator.swift":
            package_cases = extract_enum_cases(package_text, "BillRecurrence")
            if package_cases != app_cases:
                failures.append(
                    "BillRecurrence cases differ:\n"
                    f"  Penny/Models: {app_cases}\n"
                    f"  PennyCoreLogic: {package_cases}"
                )
        if filename == "BillPaymentCycle.swift":
            package_cases = extract_enum_cases(package_text, "Recurrence")
            if package_cases != app_cases:
                failures.append(
                    "BillPaymentCycle.Recurrence cases differ from BillRecurrence:\n"
                    f"  Penny/Models: {app_cases}\n"
                    f"  PennyCoreLogic: {package_cases}"
                )
        app_lines = normalize_lines(app_text)
        package_lines = normalize_lines(prepare_package(filename, package_text))
        if app_lines == package_lines:
            if filename in DEFERRED_DIFFS:
                failures.append(
                    f"{filename} now matches, but this PR still lists it as deferred drift.\n"
                    "Remove it from DEFERRED_DIFFS when the data-safety PR copies the app behaviour."
                )
            else:
                print(f"  match  {app_rel}")
            continue
        diff = unified_diff(
            app_lines,
            package_lines,
            app_rel,
            f"Tools/PennyCoreLogic/Sources/PennyCoreLogic/{filename}",
        )
        if filename in DEFERRED_DIFFS:
            if diff != DEFERRED_DIFFS[filename]:
                failures.append(
                    f"deferred drift in {filename} changed. This CI PR does not take that behaviour change.\n"
                    f"Expected:\n{DEFERRED_DIFFS[filename]}\n\nActual:\n{diff}"
                )
            else:
                print(f"  deferred  {app_rel}")
                print("    left for the data-safety PR (app behaviour stays; package was not updated)")
            continue
        failures.append(f"logic drift in {filename}\n{diff}")

    if failures:
        print("\nDRIFT DETECTED\n", file=sys.stderr)
        print("\n\n".join(failures), file=sys.stderr)
        return 1

    print()
    deferred = sum(1 for name, _ in PAIRS if name in DEFERRED_DIFFS)
    print(
        f"No logic drift across {len(PAIRS)} shared files "
        f"({deferred} deferred diff(s))."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
