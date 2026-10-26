#!/usr/bin/env python3
"""CI layout checks that do not need a Mac.

- Every unit-test and UI-test target is on the Penny scheme and not skipped.
- PennyTests has a Copy Bundle Resources phase that bundles Migration/Fixtures
  (so a v1.0.4 store can land there without another project edit).
- Every @Suite opts into isolated SwiftData / UserDefaults.
- Settings → Legal & privacy renders PennyAppInfo.settingsFootnote and does not
  inline those sentences.
- Suites that touch WidgetSnapshotStore are .serialized so they do not share
  the test widget UserDefaults slot in parallel.
- The macOS test script does not filter PennyTests (MigrationTests must run).
- Every .xcassets PBXFileReference (app and widgets) is folder.assetcatalog,
  ASSETCATALOG_COMPILER_APPICON_NAME stays AppIcon, and Penny/Info.plist
  supplies CFBundleIconName. Xcode ignores a user-defined
  INFOPLIST_KEY_CFBundleIconName.
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


def settings_footnote_sentences(app_info: str) -> list[str]:
    """Sentences named by `settingsFootnote`, in order. The array must not inline them."""
    array = re.search(r"static let settingsFootnote = \[(.*?)\]", app_info, re.S)
    if array is None:
        raise ValueError("PennyAppInfo.settingsFootnote is missing")
    body = array.group(1)
    if '"' in body:
        raise ValueError("settingsFootnote inlines wording instead of naming constants")
    names = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\b", body)
    if not names:
        raise ValueError("settingsFootnote has no lines")
    sentences: list[str] = []
    for name in names:
        match = re.search(rf'static let {name}\s*=\s*"([^"]*)"', app_info)
        if match is None:
            raise ValueError(f"settingsFootnote names {name}, which has no string literal")
        sentences.append(match.group(1))
    return sentences


def settings_footnote_failures() -> list[str]:
    """Settings legal footnote must render the locked constants, not a second copy."""
    app_info_path = ROOT / "Penny" / "Utilities" / "PennyAppInfo.swift"
    settings_path = ROOT / "Penny" / "Features" / "Settings" / "SettingsView.swift"
    try:
        sentences = settings_footnote_sentences(app_info_path.read_text())
    except ValueError as error:
        return [str(error)]
    settings = settings_path.read_text()
    failures: list[str] = []
    if "PennyAppInfo.settingsFootnote" not in settings:
        failures.append("SettingsView does not render PennyAppInfo.settingsFootnote")
    for sentence in sentences:
        if sentence in settings:
            failures.append(f"SettingsView inlines footnote copy: {sentence}")
    return failures


def phase_is_resources(project: str, phase_id: str) -> bool:
    return (
        re.search(
            rf"{re.escape(phase_id)} /\* [^*]+ \*/ = \{{\s*isa = PBXResourcesBuildPhase;",
            project,
        )
        is not None
    )


def asset_catalog_failures(project: str) -> list[str]:
    """Fail when an .xcassets file reference would be copied instead of compiled.

    A PBXFileReference with lastKnownFileType = folder copies the catalog raw.
    App Store Connect then rejects the build (ITMS-90022, ITMS-90713) because
    actool never emits Assets.car or CFBundleIconName.
    """
    failures: list[str] = []
    catalogs = 0
    for match in re.finditer(
        r"isa = PBXFileReference;(?P<body>.*?)\};",
        project,
        re.S,
    ):
        body = match.group("body")
        path_match = re.search(r"\bpath = ([^;]+);", body)
        if not path_match:
            continue
        path = path_match.group(1).strip().strip('"')
        if not path.endswith(".xcassets"):
            continue
        catalogs += 1
        type_match = re.search(
            r"\b(?:lastKnownFileType|explicitFileType) = ([^;]+);",
            body,
        )
        file_type = type_match.group(1).strip().strip('"') if type_match else ""
        if file_type != "folder.assetcatalog":
            shown = file_type or "missing"
            failures.append(
                f"{path} PBXFileReference type is {shown}; expected folder.assetcatalog"
            )
    if catalogs == 0:
        failures.append("project.pbxproj has no .xcassets PBXFileReference")

    icon_names = re.findall(r"ASSETCATALOG_COMPILER_APPICON_NAME = ([^;]+);", project)
    if not icon_names:
        failures.append("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon is missing")
    for value in icon_names:
        cleaned = value.strip().strip('"')
        if cleaned != "AppIcon":
            failures.append(
                f"ASSETCATALOG_COMPILER_APPICON_NAME is {cleaned}; expected AppIcon"
            )

    # Xcode does not copy a user-defined INFOPLIST_KEY_CFBundleIconName into
    # the generated Info.plist. The app target merges Penny/Info.plist instead.
    if project.count("INFOPLIST_FILE = Penny/Info.plist;") < 2:
        failures.append("App target is missing INFOPLIST_FILE = Penny/Info.plist for Debug and Release")
    icon_plist = ROOT / "Penny" / "Info.plist"
    if not icon_plist.is_file():
        failures.append("Penny/Info.plist is missing")
    else:
        plist_text = icon_plist.read_text()
        if "<key>CFBundleIconName</key>" not in plist_text or "<string>AppIcon</string>" not in plist_text:
            failures.append("Penny/Info.plist must set CFBundleIconName to AppIcon")
    return failures


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

    swallow = re.compile(
        r"try\?\s+(modelContext|context)\.save\(\)|try\?\s+PennyPersistence\.repairIfNeeded"
    )
    for path in sorted((ROOT / "Penny").rglob("*.swift")):
        for index, line in enumerate(path.read_text().splitlines(), start=1):
            stripped = line.split("//", 1)[0]
            if swallow.search(stripped):
                failures.append(
                    f"{path.relative_to(ROOT)}:{index} swallows a save or repair error"
                )

    for path in sorted((ROOT / "PennyTests").rglob("*.swift")):
        text = path.read_text()
        for block in suite_blocks(text):
            if "isolatedTestResources" not in block:
                failures.append(f"{path.relative_to(ROOT)} suite is missing .isolatedTestResources: {block}")
            if "WidgetSnapshotStore" in text and ".serialized" not in block:
                failures.append(
                    f"{path.relative_to(ROOT)} suite shares the widget snapshot slot and is not .serialized: {block}"
                )

    failures.extend(settings_footnote_failures())

    for path in (CI_MACOS, WORKFLOW):
        for line in filtered_lines(path):
            failures.append(f"test filter would skip MigrationTests: {line}")

    failures.extend(asset_catalog_failures(project))

    if failures:
        print("Xcode test layout check failed:", file=sys.stderr)
        for message in failures:
            fail(message)
        return 1

    print(f"[pass] {len(test_targets)} test target(s) on the Penny scheme, unskipped", file=sys.stderr)
    print("[pass] PennyTests bundles Migration/Fixtures", file=sys.stderr)
    print("[pass] every suite isolates SwiftData and UserDefaults", file=sys.stderr)
    print("[pass] Settings footnote renders PennyAppInfo.settingsFootnote", file=sys.stderr)
    print("[pass] widget snapshot suites are .serialized", file=sys.stderr)
    print("[pass] macOS CI does not filter PennyTests", file=sys.stderr)
    print("[pass] every .xcassets reference is folder.assetcatalog", file=sys.stderr)
    print("[pass] ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon", file=sys.stderr)
    print("[pass] Penny/Info.plist sets CFBundleIconName to AppIcon", file=sys.stderr)
    if list_products:
        for target in test_targets:
            print(target["product"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
