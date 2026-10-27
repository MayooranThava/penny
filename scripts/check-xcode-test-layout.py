#!/usr/bin/env python3
"""CI layout checks that do not need a Mac.

- Every unit-test target, and every UI-test target except PennyUITests, is on the
  Penny scheme and not skipped.
- PennyUITests is only on the PennyScreenshots scheme (Screenshots configuration).
  ci-gate does not run it. The screenshot workflow is push-to-main,
  workflow_dispatch, and a path-filtered pull_request. The demo seed compiles
  only with SCREENSHOT_SEED.
- --list-products prints only test bundles the Penny scheme builds and does
  not skip. The macOS job requires those products after build-for-testing.
  PennyUITests.xctest is omitted because that job never compiles it.
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
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "Penny.xcodeproj" / "project.pbxproj"
SCHEME = ROOT / "Penny.xcodeproj" / "xcshareddata" / "xcschemes" / "Penny.xcscheme"
SCREENSHOT_SCHEME = ROOT / "Penny.xcodeproj" / "xcshareddata" / "xcschemes" / "PennyScreenshots.xcscheme"
CI_MACOS = ROOT / "scripts" / "ci-macos.sh"
CI_SCREENSHOTS = ROOT / "scripts" / "ci-screenshots.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
SCREENSHOT_WORKFLOW = ROOT / ".github" / "workflows" / "screenshots.yml"
SCREENSHOT_UI_TEST = "PennyUITests"
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
    if project.count("INFOPLIST_FILE = Penny/Info.plist;") < 3:
        failures.append(
            "App target is missing INFOPLIST_FILE = Penny/Info.plist for Debug, Release, and Screenshots"
        )
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


def screenshot_isolation_failures(project: str, penny_scheme: str) -> list[str]:
    """The screenshot UI tests stay off ci-gate and only run from their own scheme."""
    failures: list[str] = []
    if SCREENSHOT_UI_TEST in penny_scheme:
        failures.append("Penny scheme must not reference PennyUITests")
    if not SCREENSHOT_SCHEME.is_file():
        return failures + ["PennyScreenshots.xcscheme is missing"]
    screen = SCREENSHOT_SCHEME.read_text()
    testables = scheme_testables(screen)
    names = {name: skipped for skipped, name in testables}
    if names.get(SCREENSHOT_UI_TEST) != "NO":
        failures.append("PennyScreenshots scheme must include PennyUITests and not skip it")
    if "PennyTests" in names:
        failures.append("PennyScreenshots scheme must not run PennyTests")
    test_action = screen.split("<TestAction", 1)[-1].split("</TestAction>", 1)[0]
    launch_action = screen.split("<LaunchAction", 1)[-1].split("</LaunchAction>", 1)[0]
    archive_action = screen.split("<ArchiveAction", 1)[-1].split("</ArchiveAction>", 1)[0]
    if 'buildConfiguration = "Screenshots"' not in test_action:
        failures.append("PennyScreenshots test action must use the Screenshots configuration")
    if 'buildConfiguration = "Screenshots"' not in launch_action:
        failures.append("PennyScreenshots launch action must use the Screenshots configuration")
    if 'buildConfiguration = "Release"' not in archive_action:
        failures.append("PennyScreenshots archive action must stay on Release")
    if f'productType = "com.apple.product-type.bundle.ui-testing"' not in project:
        failures.append("PennyUITests product type is missing")
    failures.extend(ui_test_shared_source_failures(project))
    return failures


def ui_test_shared_source_failures(project: str) -> list[str]:
    """PrivateModeLogic formats money, so the UI test target must compile both files."""
    ui = next((target for target in native_targets(project) if target["name"] == SCREENSHOT_UI_TEST), None)
    if ui is None:
        return ["PennyUITests target is missing"]
    phase_ids = re.findall(r"([A-F0-9]{24}) /\*", ui["phases"])
    sources_body = ""
    for phase_id in phase_ids:
        match = re.search(
            rf"{phase_id} /\* Sources \*/ = \{{\s*isa = PBXSourcesBuildPhase;(.*?)\n\t\t\}};",
            project,
            re.S,
        )
        if match:
            sources_body = match.group(1)
            break
    failures: list[str] = []
    for filename in ("PrivateModeLogic.swift", "MoneyFormatters.swift"):
        if f"{filename} in Sources" not in sources_body:
            failures.append(
                f"PennyUITests must compile {filename}; PrivateModeLogic calls MoneyFormatters"
            )
    return failures


def strip_code_comments(source: str) -> str:
    return "\n".join(line.split("//", 1)[0] for line in source.splitlines())


def outside_screenshot_seed(source: str) -> str:
    """Source with `//` comments and `#if SCREENSHOT_SEED` regions removed."""
    code = strip_code_comments(source)
    kept: list[str] = []
    index = 0
    token = "#if SCREENSHOT_SEED"
    while True:
        start = code.find(token, index)
        if start < 0:
            kept.append(code[index:])
            break
        kept.append(code[index:start])
        end = code.find("#endif", start)
        if end < 0:
            raise ValueError("unclosed #if SCREENSHOT_SEED")
        index = end + len("#endif")
    return "".join(kept)


def launch_contract_failures() -> list[str]:
    app_path = ROOT / "Penny" / "App" / "UITestSeedLaunch.swift"
    test_path = ROOT / "PennyUITests" / "ScreenshotLaunch.swift"
    penny_path = ROOT / "Penny" / "App" / "PennyApp.swift"
    demo_path = ROOT / "Penny" / "Services" / "DemoDataService.swift"
    if not app_path.is_file() or not test_path.is_file():
        return ["UITestSeedLaunch.swift and PennyUITests/ScreenshotLaunch.swift are required"]
    app = app_path.read_text()
    test = test_path.read_text()
    penny = penny_path.read_text()
    demo = demo_path.read_text()
    failures: list[str] = []
    for label, source in (
        ("UITestSeedLaunch.swift", app),
        ("ScreenshotLaunch.swift", test),
        ("PennyApp.swift", penny),
    ):
        lowered = strip_code_comments(source).lower()
        if "xctestconfiguration" in lowered or "penny_xcui_configuration" in lowered:
            failures.append(f"{label} still string-matches the XCUITest configuration path")
    try:
        app_outside = outside_screenshot_seed(app)
        penny_outside = outside_screenshot_seed(penny)
        demo_outside = outside_screenshot_seed(demo)
    except ValueError as error:
        return failures + [str(error)]
    if "#if SCREENSHOT_SEED" not in strip_code_comments(app):
        failures.append("UITestSeedLaunch must be wrapped in #if SCREENSHOT_SEED")
    if "enum UITestSeedLaunch" in app_outside or "replaceExisting" in app_outside:
        failures.append("UITestSeedLaunch seed code must stay inside #if SCREENSHOT_SEED")
    if "UITestSeedLaunch" in penny_outside:
        failures.append("PennyApp must call UITestSeedLaunch only inside #if SCREENSHOT_SEED")
    if "UITestSeedLaunch.isEnabled" not in penny or "openSeededContainer" not in penny:
        failures.append("PennyApp does not consult UITestSeedLaunch.isEnabled")
    if "func seedDemo" not in demo_outside or "func seedFresh" not in demo_outside:
        failures.append("User-facing seedDemo and seedFresh must stay compiled in Release")
    if "func seedVolumeTransactions" not in demo or "func seedVolumeTransactions" in demo_outside:
        failures.append("seedVolumeTransactions must be compiled only for SCREENSHOT_SEED")
    for literal in (
        "-PennyUITestSeed",
        "-PennyAppearance",
        "-PennyPrivateMode",
        "-PennyUITestTransactionCount",
    ):
        if literal not in app or literal not in test:
            failures.append(f"{literal} must be used by both the app and PennyUITests")
    allowed = {
        "Penny/Services/DemoDataService.swift",
        "Penny/App/UITestSeedLaunch.swift",
    }
    hits = {
        str(path.relative_to(ROOT))
        for path in ROOT.rglob("*.swift")
        if "seedVolumeTransactions" in path.read_text()
    }
    if hits != allowed:
        failures.append(f"seedVolumeTransactions references must be {sorted(allowed)}, found {sorted(hits)}")
    return failures


def _normalized_settings(body: str) -> str:
    lines: list[str] = []
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("SWIFT_ACTIVE_COMPILATION_CONDITIONS"):
            continue
        lines.append(stripped)
    return "\n".join(lines)


def screenshot_configuration_failures(project: str) -> list[str]:
    """Screenshots copies Release. Only the app target adds SCREENSHOT_SEED."""
    failures: list[str] = []
    blocks = re.findall(
        r"\t\t([A-F0-9]{24}) /\* (?P<comment>[^*]+) \*/ = \{\n"
        r"\t\t\tisa = XCBuildConfiguration;\n"
        r"\t\t\tbuildSettings = \{(?P<body>.*?)\n\t\t\t\};\n"
        r"\t\t\tname = (?P<name>[^;]+);\n"
        r"\t\t\};",
        project,
        re.S,
    )
    by_id = {item[0]: (item[1], item[2], item[3]) for item in blocks}
    if len(by_id) != 15:
        failures.append(f"expected 15 build configurations (Debug, Release, Screenshots), found {len(by_id)}")
    for cfg_id, (comment, _body, name) in by_id.items():
        if comment != name:
            failures.append(f"build configuration {cfg_id} comment {comment!r} does not match name {name!r}")

    lists = re.findall(
        r"/\* Build configuration list for (?P<owner>[^*]+) \*/ = \{\n"
        r"\t\t\tisa = XCConfigurationList;\n"
        r"\t\t\tbuildConfigurations = \((?P<body>.*?)\n\t\t\t\);\n"
        r"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        r"\t\t\tdefaultConfigurationName = (?P<default>[^;]+);",
        project,
        re.S,
    )
    required = {
        'PBXProject "Penny"',
        'PBXNativeTarget "Penny"',
        'PBXNativeTarget "PennyWidgets"',
        'PBXNativeTarget "PennyTests"',
        'PBXNativeTarget "PennyUITests"',
    }
    found_owners = {owner for owner, _body, _default in lists}
    if found_owners != required:
        failures.append(f"configuration lists must be {sorted(required)}, found {sorted(found_owners)}")

    app_screenshots = ""
    for owner, body, default_name in lists:
        if default_name != "Release":
            failures.append(f"{owner} default configuration must stay Release")
        names: list[str] = []
        release_body = ""
        screenshots_body = ""
        for cfg_id, comment in re.findall(r"([A-F0-9]{24}) /\* ([^*]+) \*/", body):
            parsed = by_id.get(cfg_id)
            if parsed is None:
                failures.append(f"{owner} lists unknown configuration {cfg_id}")
                continue
            _comment, settings, name = parsed
            if name != comment:
                failures.append(f"{owner} lists {comment} but the block is named {name}")
            names.append(name)
            if name == "Release":
                release_body = settings
            elif name == "Screenshots":
                screenshots_body = settings
        if names != ["Debug", "Release", "Screenshots"]:
            failures.append(f"{owner} configurations must be Debug, Release, Screenshots (found {names})")
            continue
        if _normalized_settings(release_body) != _normalized_settings(screenshots_body):
            failures.append(f"{owner} Screenshots configuration must copy Release")
        if owner == 'PBXNativeTarget "Penny"':
            app_screenshots = screenshots_body
        elif "SCREENSHOT_SEED" in screenshots_body:
            failures.append(f"{owner} must not set SCREENSHOT_SEED")
    expected = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "SCREENSHOT_SEED $(inherited)";'
    if expected not in app_screenshots:
        failures.append("Penny app Screenshots configuration must set SCREENSHOT_SEED")
    if app_screenshots.count("SCREENSHOT_SEED") != 1:
        failures.append("SCREENSHOT_SEED must appear once on the Penny app Screenshots configuration")
    return failures


def demo_seed_failures() -> list[str]:
    path = ROOT / "Penny" / "Services" / "DemoDataService.swift"
    text = path.read_text()
    banned = (
        "Starbucks",
        "Netflix",
        "Loblaws",
        "Tim Hortons",
        "Uber",
        "Cineplex",
        "Spotify",
        "Disney",
        "Amazon",
        "Walmart",
        "Costco",
        "Indigo",
        "Shoppers",
        "No Frills",
        "Winners",
        "Raptors",
        "TTC",
        "McDonald",
        "Airbnb",
        "Nike",
        "YouTube",
        "Alex",
    )
    return [f"DemoDataService contains real brand or personal name {name!r}" for name in banned if name in text]


def workflow_event_body(workflow: str, event: str) -> str | None:
    """Return the indented body of one top-level `on:` event, or None."""
    lines = workflow.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line == f"  {event}:":
            start = index + 1
            break
    if start is None:
        return None
    body: list[str] = []
    for line in lines[start:]:
        if line.startswith("  ") and not line.startswith("   ") and line.strip():
            break
        if line and not line.startswith((" ", "#")):
            break
        body.append(line)
    return "\n".join(body)


def screenshot_workflow_failures() -> list[str]:
    failures: list[str] = []
    if not SCREENSHOT_WORKFLOW.is_file():
        return ["screenshots workflow is missing"]
    workflow = SCREENSHOT_WORKFLOW.read_text()
    ci = WORKFLOW.read_text()
    push = workflow_event_body(workflow, "push")
    pull_request = workflow_event_body(workflow, "pull_request")
    if workflow_event_body(workflow, "workflow_dispatch") is None:
        failures.append("screenshots workflow must allow workflow_dispatch")
    if push is None or "branches: [main]" not in push:
        failures.append("screenshots workflow must run on push to main")
    elif "paths:" in push:
        failures.append("screenshots push to main must stay unfiltered")
    if pull_request is None:
        failures.append("screenshots workflow must run on pull_request")
    else:
        for path in (
            "Penny/**",
            "PennyUITests/**",
            "Penny.xcodeproj/**",
            ".github/workflows/**",
        ):
            if path not in pull_request:
                failures.append(f"screenshots pull_request paths must include {path}")
        if "paths:" not in pull_request:
            failures.append("screenshots pull_request must be path-filtered")
    if "select-stable-xcode.sh" not in workflow:
        failures.append("screenshots workflow must select the same stable Xcode as the Mac job")
    if "ci-screenshots.sh" not in workflow:
        failures.append("screenshots workflow must run scripts/ci-screenshots.sh")
    if "name: app-screenshots" not in workflow:
        failures.append("screenshots artifact must be named app-screenshots")
    if "screenshots.yml" in ci or "ci-screenshots" in ci or "PennyUITests" in ci:
        failures.append("ci.yml must not run the screenshot job or PennyUITests")
    if "needs: [sanity, macos]" not in ci:
        failures.append("ci-gate must keep depending only on sanity and macos")
    if not CI_SCREENSHOTS.is_file():
        return failures + ["scripts/ci-screenshots.sh is missing"]
    script = CI_SCREENSHOTS.read_text()
    if "-scheme PennyScreenshots" not in script or "-configuration Screenshots" not in script:
        failures.append("ci-screenshots.sh must test the PennyScreenshots scheme in the Screenshots configuration")
    if "-configuration Release" in script:
        failures.append("ci-screenshots.sh must not build the screenshot tests as Release")
    if "check-release-omits-uitest-seed.sh" not in ci:
        failures.append("ci.yml must build Release and reject a UITestSeedLaunch symbol")
    if "-only-testing" in script or "-skip-testing" in script:
        failures.append("ci-screenshots.sh must not filter tests")
    if "export-screenshot-artifacts.py" not in script:
        failures.append("ci-screenshots.sh must export screenshots and metrics")
    return failures


def release_seed_symbol_script_failures() -> list[str]:
    """Release must omit UITestSeedLaunch, and Screenshots must still contain it."""
    script = ROOT / "scripts" / "check-release-omits-uitest-seed.sh"
    if not script.is_file():
        return ["scripts/check-release-omits-uitest-seed.sh is missing"]
    text = script.read_text()
    failures: list[str] = []
    if "-scheme Penny" not in text or 'build_penny Release' not in text:
        failures.append("Release seed check must build the Penny scheme in Release")
    if 'build_penny Screenshots' not in text or "-configuration" not in text:
        failures.append(
            "Release seed check must build the Screenshots configuration as a positive control"
        )
    if "UITestSeedLaunch" not in text:
        failures.append("Release seed check must look for UITestSeedLaunch")
    if "nm -a" not in text or "strings -a" not in text:
        failures.append("Release seed check must use nm and strings on the built executable")
    if "${configuration}-iphonesimulator" not in text:
        failures.append("Release seed check must inspect each configuration's simulator product")
    if "missing UITestSeedLaunch" not in text:
        failures.append(
            "Screenshots positive control must fail when UITestSeedLaunch is absent"
        )
    if '[[ -z "$NM_HITS" && -z "$STRING_HITS" ]]' not in text:
        failures.append(
            "Screenshots positive control must fail when both nm and strings miss UITestSeedLaunch"
        )
    completed = subprocess.run(
        ["bash", str(script), "--self-test"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stdout + completed.stderr).strip() or "self-test failed"
        failures.append(f"Release seed-symbol filter self-test failed: {detail}")
    return failures


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
        if target["name"] == SCREENSHOT_UI_TEST:
            skipped = by_name.get(target["name"])
            if skipped is not None:
                failures.append(
                    "PennyUITests must stay off the Penny scheme so ci-gate does not run screenshots"
                )
            if target["product_type"] != "com.apple.product-type.bundle.ui-testing":
                failures.append("PennyUITests must be a UI-test bundle")
            continue
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
    failures.extend(screenshot_isolation_failures(project, scheme))
    failures.extend(screenshot_configuration_failures(project))
    failures.extend(launch_contract_failures())
    failures.extend(demo_seed_failures())
    failures.extend(screenshot_workflow_failures())
    failures.extend(release_seed_symbol_script_failures())

    if failures:
        print("Xcode test layout check failed:", file=sys.stderr)
        for message in failures:
            fail(message)
        return 1

    print(
        f"[pass] {len(test_targets)} test target(s); PennyUITests is only on PennyScreenshots",
        file=sys.stderr,
    )
    print("[pass] PennyTests bundles Migration/Fixtures", file=sys.stderr)
    print("[pass] every suite isolates SwiftData and UserDefaults", file=sys.stderr)
    print("[pass] Settings footnote renders PennyAppInfo.settingsFootnote", file=sys.stderr)
    print("[pass] widget snapshot suites are .serialized", file=sys.stderr)
    print("[pass] macOS CI does not filter PennyTests", file=sys.stderr)
    print("[pass] every .xcassets reference is folder.assetcatalog", file=sys.stderr)
    print("[pass] ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon", file=sys.stderr)
    print("[pass] Penny/Info.plist sets CFBundleIconName to AppIcon", file=sys.stderr)
    print("[pass] Screenshots configuration copies Release and seeds only the app", file=sys.stderr)
    print("[pass] UITestSeedLaunch is compiled only for SCREENSHOT_SEED", file=sys.stderr)
    print(
        "[pass] Release omits UITestSeedLaunch and Screenshots must still contain it",
        file=sys.stderr,
    )
    print(
        "[pass] screenshot workflow is push, workflow_dispatch, and path-filtered pull_request",
        file=sys.stderr,
    )
    if list_products:
        # ci-macos.sh requires each printed product after the Penny scheme
        # build. PennyUITests is a test target, but only PennyScreenshots
        # builds it, so it must not appear here.
        for target in test_targets:
            if by_name.get(target["name"]) == "NO":
                print(target["product"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
