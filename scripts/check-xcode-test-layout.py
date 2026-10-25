#!/usr/bin/env python3
"""CI layout checks that do not need a Mac.

- Every unit-test and UI-test target is on the Penny scheme and not skipped.
- PennyTests has a Copy Bundle Resources phase that bundles Migration/Fixtures
  (so a v1.0.4 store can land there without another project edit).
- Every @Suite opts into isolated SwiftData / UserDefaults.
- The macOS test script does not filter PennyTests (MigrationTests must run).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "Penny.xcodeproj" / "project.pbxproj"
SCHEME = ROOT / "Penny.xcodeproj" / "xcshareddata" / "xcschemes" / "Penny.xcscheme"
CI_MACOS = ROOT / "scripts" / "ci-macos.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
TEST_TYPES = {
    "com.apple.product-type.bundle.unit-test",
    "com.apple.product-type.bundle.ui-testing",
}


def fail(message: str) -> None:
    print(f"[fail] {message}", file=sys.stderr)


def native_targets(text: str) -> list[dict[str, str]]:
    targets: list[dict[str, str]] = []
    pattern = re.compile(
        r"/\* (?P<comment>[^*]+) \*/ = \{\s*isa = PBXNativeTarget;(?P<body>.*?)\n\t\t\};",
        re.S,
    )
    for match in pattern.finditer(text):
        body = match.group("body")
        name = re.search(r"\bname = ([^;]+);", body)
        product_type = re.search(r'productType = "([^"]+)"', body)
        product = re.search(r"productReference = [A-F0-9]+ /\* ([^*]+) \*/", body)
        phases = re.search(r"buildPhases = \((.*?)\);", body, re.S)
        if not (name and product_type and product and phases):
            continue
        targets.append(
            {
                "name": name.group(1).strip(),
                "product_type": product_type.group(1),
                "product": product.group(1).strip(),
                "phases": phases.group(1),
            }
        )
    return targets


def scheme_testables(text: str) -> list[tuple[str, str]]:
    return re.findall(
        r'<TestableReference\s+skipped = "(YES|NO)".*?BlueprintName = "([^"]+)"',
        text,
        re.S,
    )


def suite_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        stripped = lines[index].split("//", 1)[0].strip()
        if stripped.startswith("@Suite"):
            block = stripped
            if "(" in block:
                while block.count("(") > block.count(")") and index + 1 < len(lines):
                    index += 1
                    block += lines[index].split("//", 1)[0]
            blocks.append(block)
        index += 1
    return blocks


def phase_is_resources(project: str, phase_id: str) -> bool:
    return (
        re.search(
            rf"{re.escape(phase_id)} /\* [^*]+ \*/ = \{{\s*isa = PBXResourcesBuildPhase;",
            project,
        )
        is not None
    )


def filtered_lines(path: Path) -> list[str]:
    bad: list[str] = []
    if not path.is_file():
        return [f"missing {path}"]
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("//"):
            continue
        if "-only-testing" in stripped or "-skip-testing" in stripped:
            if stripped.startswith("case ") or "*) return 0" in stripped or "forbidden" in stripped:
                continue
            bad.append(f"{path.name}: {stripped}")
    return bad


def main() -> int:
    list_products = "--list-products" in sys.argv
    failures: list[str] = []
    project = PBXPROJ.read_text()
    scheme = SCHEME.read_text()
    targets = native_targets(project)
    if not targets:
        failures.append("No PBXNativeTarget entries parsed from project.pbxproj")

    test_targets = [target for target in targets if target["product_type"] in TEST_TYPES]
    testables = scheme_testables(scheme)
    by_name = {name: skipped for skipped, name in testables}

    if not test_targets:
        failures.append("No unit-test or UI-test targets found")

    for target in test_targets:
        skipped = by_name.get(target["name"])
        if skipped is None:
            failures.append(
                f"Test target {target['name']} is not on the Penny scheme, so build-for-testing will not compile it"
            )
        elif skipped == "YES":
            failures.append(f"Test target {target['name']} is skipped on the Penny scheme")

    penny = next((target for target in test_targets if target["name"] == "PennyTests"), None)
    if penny is None:
        failures.append("PennyTests target is missing")
    else:
        phase_ids = re.findall(r"([A-F0-9]{24}) /\*", penny["phases"])
        if not any(phase_is_resources(project, phase_id) for phase_id in phase_ids):
            failures.append("PennyTests has no Resources build phase, so fixture stores will not be bundled")
        resources_blocks = re.findall(
            r"([A-F0-9]{24}) /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;(.*?)\n\t\t\};",
            project,
            re.S,
        )
        bundled = False
        for phase_id, body in resources_blocks:
            if phase_id in phase_ids and "Fixtures in Resources" in body:
                bundled = True
        if not bundled:
            failures.append("PennyTests Resources phase does not copy Migration/Fixtures")

    for path in sorted((ROOT / "PennyTests").rglob("*.swift")):
        for block in suite_blocks(path.read_text()):
            if "isolatedTestResources" not in block:
                failures.append(f"{path.relative_to(ROOT)} suite is missing .isolatedTestResources: {block}")

    for path in (CI_MACOS, WORKFLOW):
        for line in filtered_lines(path):
            failures.append(f"test filter would skip MigrationTests: {line}")

    if failures:
        print("Xcode test layout check failed:", file=sys.stderr)
        for message in failures:
            fail(message)
        return 1

    print(f"[pass] {len(test_targets)} test target(s) on the Penny scheme, unskipped")
    print("[pass] PennyTests bundles Migration/Fixtures")
    print("[pass] every suite isolates SwiftData and UserDefaults")
    print("[pass] macOS CI does not filter PennyTests")
    if list_products:
        for target in test_targets:
            print(target["product"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
