#!/usr/bin/env python3
"""Generate Penny.xcodeproj/project.pbxproj for the Penny iOS app."""

from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Penny.xcodeproj"
SOURCE_ROOT = ROOT / "Penny"
TESTS_ROOT = ROOT / "PennyTests"
WIDGETS_ROOT = ROOT / "PennyWidgets"

def uid() -> str:
    return uuid.uuid4().hex[:24].upper()

# Stable-ish IDs for core objects
PROJECT_ID = "A10000000000000000000001"
MAIN_GROUP = "A10000000000000000000002"
PRODUCTS_GROUP = "A10000000000000000000003"
PENNY_GROUP = "A10000000000000000000004"
TESTS_GROUP = "A10000000000000000000005"
APP_TARGET = "A10000000000000000000006"
TEST_TARGET = "A10000000000000000000007"
APP_PRODUCT = "A10000000000000000000008"
TEST_PRODUCT = "A10000000000000000000009"
SOURCES_APP = "A1000000000000000000000A"
SOURCES_TEST = "A1000000000000000000000B"
RESOURCES_APP = "A1000000000000000000000C"
FRAMEWORKS_APP = "A1000000000000000000000D"
FRAMEWORKS_TEST = "A1000000000000000000000E"
TARGET_DEP = "A1000000000000000000000F"
CONTAINER_PROXY = "A10000000000000000000010"
PROJECT_CONFIGS = "A10000000000000000000011"
APP_CONFIGS = "A10000000000000000000012"
TEST_CONFIGS = "A10000000000000000000013"
PROJ_DEBUG = "A10000000000000000000014"
PROJ_RELEASE = "A10000000000000000000015"
APP_DEBUG = "A10000000000000000000016"
APP_RELEASE = "A10000000000000000000017"
TEST_DEBUG = "A10000000000000000000018"
TEST_RELEASE = "A10000000000000000000019"

# Widget extension IDs
WIDGETS_GROUP = "A1000000000000000000001A"
WIDGET_TARGET = "A1000000000000000000001B"
WIDGET_PRODUCT = "A1000000000000000000001C"
SOURCES_WIDGET = "A1000000000000000000001D"
FRAMEWORKS_WIDGET = "A1000000000000000000001E"
RESOURCES_WIDGET = "A1000000000000000000001F"
WIDGET_CONFIGS = "A10000000000000000000020"
WIDGET_DEBUG = "A10000000000000000000021"
WIDGET_RELEASE = "A10000000000000000000022"
EMBED_EXTENSIONS = "A10000000000000000000023"
WIDGET_TARGET_DEP = "A10000000000000000000024"
WIDGET_CONTAINER_PROXY = "A10000000000000000000025"
WIDGET_EMBED_BF = "A10000000000000000000026"
APP_ENTITLEMENTS_REF = "A10000000000000000000027"
WIDGET_ENTITLEMENTS_REF = "A10000000000000000000028"
WIDGET_INFOPLIST_REF = "A10000000000000000000029"

swift_files: list[Path] = sorted(SOURCE_ROOT.rglob("*.swift"))
test_files: list[Path] = sorted(TESTS_ROOT.rglob("*.swift"))
widget_files: list[Path] = sorted(WIDGETS_ROOT.rglob("*.swift"))
asset_catalogs: list[Path] = sorted(SOURCE_ROOT.rglob("*.xcassets"))

app_entitlements = SOURCE_ROOT / "Penny.entitlements"
widget_entitlements = WIDGETS_ROOT / "PennyWidgets.entitlements"
widget_info_plist = WIDGETS_ROOT / "Info.plist"

file_refs: dict[Path, str] = {}
build_files: dict[Path, str] = {}

for path in swift_files + test_files + widget_files + asset_catalogs:
    file_refs[path] = uid()
    build_files[path] = uid()

file_refs[app_entitlements] = APP_ENTITLEMENTS_REF
file_refs[widget_entitlements] = WIDGET_ENTITLEMENTS_REF
file_refs[widget_info_plist] = WIDGET_INFOPLIST_REF

# Build group tree
# Map directory -> group id
group_ids: dict[Path, str] = {
    SOURCE_ROOT: PENNY_GROUP,
    TESTS_ROOT: TESTS_GROUP,
    WIDGETS_ROOT: WIDGETS_GROUP,
}

def ensure_group(path: Path) -> str:
    if path in group_ids:
        return group_ids[path]
    group_ids[path] = uid()
    parent = path.parent
    roots = (SOURCE_ROOT, TESTS_ROOT, WIDGETS_ROOT)
    if parent != ROOT and parent not in group_ids and any(
        r in parent.parents or parent == r for r in roots
    ):
        ensure_group(parent)
    return group_ids[path]

for path in list(swift_files) + list(asset_catalogs):
    ensure_group(path.parent)
for path in test_files:
    ensure_group(path.parent)
for path in widget_files:
    ensure_group(path.parent)

# Children for each group
group_children: dict[Path, list[tuple[str, str]]] = {p: [] for p in group_ids}

# Add subgroups to parents
for path, gid in sorted(group_ids.items(), key=lambda x: len(str(x[0]))):
    if path in (SOURCE_ROOT, TESTS_ROOT, WIDGETS_ROOT):
        continue
    parent = path.parent
    if parent in group_ids:
        group_children[parent].append((gid, path.name))

# Add files to groups
for path, fid in file_refs.items():
    parent = path.parent
    if parent not in group_children:
        group_children[parent] = []
    name = path.name
    group_children[parent].append((fid, name))

def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()

lines: list[str] = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")

# PBXBuildFile
lines.append("/* Begin PBXBuildFile section */")
for path, bid in build_files.items():
    fid = file_refs[path]
    phase = "Resources" if path.suffix == ".xcassets" else "Sources"
    lines.append(f"\t\t{bid} /* {path.name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};")
# Link Penny.app into tests
TEST_HOST_BF = uid()
lines.append(f"\t\t{TEST_HOST_BF} /* Penny.app in Frameworks */ = {{isa = PBXBuildFile; fileRef = {APP_PRODUCT} /* Penny.app */; }};")
# Embed widget extension in app
lines.append(f"\t\t{WIDGET_EMBED_BF} /* PennyWidgets.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {WIDGET_PRODUCT} /* PennyWidgets.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
lines.append("/* End PBXBuildFile section */")
lines.append("")

# PBXContainerItemProxy
lines.append("/* Begin PBXContainerItemProxy section */")
lines.append(f"\t\t{CONTAINER_PROXY} /* PBXContainerItemProxy */ = {{")
lines.append("\t\t\tisa = PBXContainerItemProxy;")
lines.append(f"\t\t\tcontainerPortal = {PROJECT_ID} /* Project object */;")
lines.append("\t\t\tproxyType = 1;")
lines.append(f"\t\t\tremoteGlobalIDString = {APP_TARGET};")
lines.append("\t\t\tremoteInfo = Penny;")
lines.append("\t\t};")
lines.append(f"\t\t{WIDGET_CONTAINER_PROXY} /* PBXContainerItemProxy */ = {{")
lines.append("\t\t\tisa = PBXContainerItemProxy;")
lines.append(f"\t\t\tcontainerPortal = {PROJECT_ID} /* Project object */;")
lines.append("\t\t\tproxyType = 1;")
lines.append(f"\t\t\tremoteGlobalIDString = {WIDGET_TARGET};")
lines.append("\t\t\tremoteInfo = PennyWidgets;")
lines.append("\t\t};")
lines.append("/* End PBXContainerItemProxy section */")
lines.append("")

# PBXCopyFilesBuildPhase — Embed Foundation Extensions
lines.append("/* Begin PBXCopyFilesBuildPhase section */")
lines.append(f"\t\t{EMBED_EXTENSIONS} /* Embed Foundation Extensions */ = {{")
lines.append("\t\t\tisa = PBXCopyFilesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tdstPath = \"\";")
lines.append("\t\t\tdstSubfolderSpec = 13;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{WIDGET_EMBED_BF} /* PennyWidgets.appex in Embed Foundation Extensions */,")
lines.append("\t\t\t);")
lines.append('\t\t\tname = "Embed Foundation Extensions";')
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXCopyFilesBuildPhase section */")
lines.append("")

# PBXFileReference
lines.append("/* Begin PBXFileReference section */")
lines.append(f'\t\t{APP_PRODUCT} /* Penny.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Penny.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
lines.append(f'\t\t{WIDGET_PRODUCT} /* PennyWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = PennyWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
lines.append(f'\t\t{TEST_PRODUCT} /* PennyTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PennyTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
lines.append(f'\t\t{APP_ENTITLEMENTS_REF} /* Penny.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Penny.entitlements; sourceTree = "<group>"; }};')
lines.append(f'\t\t{WIDGET_ENTITLEMENTS_REF} /* PennyWidgets.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = PennyWidgets.entitlements; sourceTree = "<group>"; }};')
lines.append(f'\t\t{WIDGET_INFOPLIST_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
for path, fid in file_refs.items():
    if path in (app_entitlements, widget_entitlements, widget_info_plist):
        continue
    if path.suffix == ".xcassets":
        lines.append(f'\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {path.name}; sourceTree = "<group>"; }};')
    else:
        lines.append(f'\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path.name}; sourceTree = "<group>"; }};')
lines.append("/* End PBXFileReference section */")
lines.append("")

# PBXFrameworksBuildPhase
lines.append("/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{FRAMEWORKS_APP} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{FRAMEWORKS_WIDGET} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{FRAMEWORKS_TEST} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{TEST_HOST_BF} /* Penny.app in Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

# PBXGroup
lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{MAIN_GROUP} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{PENNY_GROUP} /* Penny */,")
lines.append(f"\t\t\t\t{WIDGETS_GROUP} /* PennyWidgets */,")
lines.append(f"\t\t\t\t{TESTS_GROUP} /* PennyTests */,")
lines.append(f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")
lines.append("\t\t\t);")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")
lines.append(f"\t\t{PRODUCTS_GROUP} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{APP_PRODUCT} /* Penny.app */,")
lines.append(f"\t\t\t\t{WIDGET_PRODUCT} /* PennyWidgets.appex */,")
lines.append(f"\t\t\t\t{TEST_PRODUCT} /* PennyTests.xctest */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")

for path, gid in sorted(group_ids.items(), key=lambda x: str(x[0])):
    name = path.name
    lines.append(f"\t\t{gid} /* {name} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    # Sort children: groups first then files, by name
    children = group_children.get(path, [])
    # Deduplicate while preserving
    seen = set()
    unique = []
    for cid, cname in children:
        if cid in seen:
            continue
        seen.add(cid)
        unique.append((cid, cname))
    unique.sort(key=lambda x: x[1].lower())
    for cid, cname in unique:
        lines.append(f"\t\t\t\t{cid} /* {cname} */,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tpath = {name};")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")

lines.append("/* End PBXGroup section */")
lines.append("")

# PBXNativeTarget
lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{APP_TARGET} /* Penny */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = " + APP_CONFIGS + " /* Build configuration list for PBXNativeTarget \"Penny\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{SOURCES_APP} /* Sources */,")
lines.append(f"\t\t\t\t{FRAMEWORKS_APP} /* Frameworks */,")
lines.append(f"\t\t\t\t{RESOURCES_APP} /* Resources */,")
lines.append(f"\t\t\t\t{EMBED_EXTENSIONS} /* Embed Foundation Extensions */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append(f"\t\t\t\t{WIDGET_TARGET_DEP} /* PBXTargetDependency */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Penny;")
lines.append("\t\t\tproductName = Penny;")
lines.append(f"\t\t\tproductReference = {APP_PRODUCT} /* Penny.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append(f"\t\t{WIDGET_TARGET} /* PennyWidgets */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = " + WIDGET_CONFIGS + " /* Build configuration list for PBXNativeTarget \"PennyWidgets\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{SOURCES_WIDGET} /* Sources */,")
lines.append(f"\t\t\t\t{FRAMEWORKS_WIDGET} /* Frameworks */,")
lines.append(f"\t\t\t\t{RESOURCES_WIDGET} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = PennyWidgets;")
lines.append("\t\t\tproductName = PennyWidgets;")
lines.append(f"\t\t\tproductReference = {WIDGET_PRODUCT} /* PennyWidgets.appex */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
lines.append("\t\t};")
lines.append(f"\t\t{TEST_TARGET} /* PennyTests */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = " + TEST_CONFIGS + " /* Build configuration list for PBXNativeTarget \"PennyTests\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{SOURCES_TEST} /* Sources */,")
lines.append(f"\t\t\t\t{FRAMEWORKS_TEST} /* Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append(f"\t\t\t\t{TARGET_DEP} /* PBXTargetDependency */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = PennyTests;")
lines.append("\t\t\tproductName = PennyTests;")
lines.append(f"\t\t\tproductReference = {TEST_PRODUCT} /* PennyTests.xctest */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

# PBXProject
lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
lines.append("\t\t\t\tTargetAttributes = {")
lines.append(f"\t\t\t\t\t{APP_TARGET} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t};")
lines.append(f"\t\t\t\t\t{WIDGET_TARGET} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t};")
lines.append(f"\t\t\t\t\t{TEST_TARGET} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t\tTestTargetID = " + APP_TARGET + ";")
lines.append("\t\t\t\t\t};")
lines.append("\t\t\t\t};")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {PROJECT_CONFIGS} /* Build configuration list for PBXProject \"Penny\" */;")
lines.append('\t\t\tcompatibilityVersion = "Xcode 15.0";')
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {MAIN_GROUP};")
lines.append(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;")
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{APP_TARGET} /* Penny */,")
lines.append(f"\t\t\t\t{WIDGET_TARGET} /* PennyWidgets */,")
lines.append(f"\t\t\t\t{TEST_TARGET} /* PennyTests */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

# Resources
lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{RESOURCES_APP} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in asset_catalogs:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{RESOURCES_WIDGET} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

# Sources
lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{SOURCES_APP} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in swift_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{SOURCES_WIDGET} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in widget_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{SOURCES_TEST} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in test_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

# Target dependency
lines.append("/* Begin PBXTargetDependency section */")
lines.append(f"\t\t{TARGET_DEP} /* PBXTargetDependency */ = {{")
lines.append("\t\t\tisa = PBXTargetDependency;")
lines.append(f"\t\t\ttarget = {APP_TARGET} /* Penny */;")
lines.append(f"\t\t\ttargetProxy = {CONTAINER_PROXY} /* PBXContainerItemProxy */;")
lines.append("\t\t};")
lines.append(f"\t\t{WIDGET_TARGET_DEP} /* PBXTargetDependency */ = {{")
lines.append("\t\t\tisa = PBXTargetDependency;")
lines.append(f"\t\t\ttarget = {WIDGET_TARGET} /* PennyWidgets */;")
lines.append(f"\t\t\ttargetProxy = {WIDGET_CONTAINER_PROXY} /* PBXContainerItemProxy */;")
lines.append("\t\t};")
lines.append("/* End PBXTargetDependency section */")
lines.append("")

# Build configurations
common_project = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
"""

common_project_release = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
"""

app_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Penny/Penny.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 2YJ478267N;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Penny;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.finance";
				INFOPLIST_KEY_NSUserNotificationsUsageDescription = "Penny can remind you before bills are due.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mayooran.penny;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

widget_settings = """
				CODE_SIGN_ENTITLEMENTS = PennyWidgets/PennyWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 2YJ478267N;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = PennyWidgets/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Penny;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mayooran.penny.widgets;
				PRODUCT_NAME = PennyWidgets;
				SKIP_INSTALL = NO;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

# Deployment target iOS 17
iphoneos_deploy = "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;\n"

lines.append("/* Begin XCBuildConfiguration section */")
lines.append(f"\t\t{PROJ_DEBUG} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project)
lines.append(iphoneos_deploy)
lines.append("\t\t\t};")
lines.append('\t\t\tname = Debug;')
lines.append("\t\t};")
lines.append(f"\t\t{PROJ_RELEASE} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project_release)
lines.append(iphoneos_deploy)
lines.append("\t\t\t};")
lines.append('\t\t\tname = Release;')
lines.append("\t\t};")

for cfg_id, name in [(APP_DEBUG, "Debug"), (APP_RELEASE, "Release")]:
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append(app_settings)
    lines.append(iphoneos_deploy)
    lines.append("\t\t\t};")
    lines.append(f'\t\t\tname = {name};')
    lines.append("\t\t};")

for cfg_id, name in [(WIDGET_DEBUG, "Debug"), (WIDGET_RELEASE, "Release")]:
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append(widget_settings)
    lines.append(iphoneos_deploy)
    lines.append("\t\t\t};")
    lines.append(f'\t\t\tname = {name};')
    lines.append("\t\t};")

for cfg_id, name in [(TEST_DEBUG, "Debug"), (TEST_RELEASE, "Release")]:
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("""
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mayooran.penny.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Penny.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Penny";
""")
    lines.append(iphoneos_deploy)
    lines.append("\t\t\t};")
    lines.append(f'\t\t\tname = {name};')
    lines.append("\t\t};")

lines.append("/* End XCBuildConfiguration section */")
lines.append("")

# Config lists
lines.append("/* Begin XCConfigurationList section */")
lines.append(f'\t\t{PROJECT_CONFIGS} /* Build configuration list for PBXProject "Penny" */ = {{')
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{PROJ_DEBUG} /* Debug */,")
lines.append(f"\t\t\t\t{PROJ_RELEASE} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f'\t\t{APP_CONFIGS} /* Build configuration list for PBXNativeTarget "Penny" */ = {{')
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{APP_DEBUG} /* Debug */,")
lines.append(f"\t\t\t\t{APP_RELEASE} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f'\t\t{WIDGET_CONFIGS} /* Build configuration list for PBXNativeTarget "PennyWidgets" */ = {{')
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{WIDGET_DEBUG} /* Debug */,")
lines.append(f"\t\t\t\t{WIDGET_RELEASE} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f'\t\t{TEST_CONFIGS} /* Build configuration list for PBXNativeTarget "PennyTests" */ = {{')
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{TEST_DEBUG} /* Debug */,")
lines.append(f"\t\t\t\t{TEST_RELEASE} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("\t};")
lines.append(f"\trootObject = {PROJECT_ID} /* Project object */;")
lines.append("}")

PROJECT.mkdir(parents=True, exist_ok=True)
out = PROJECT / "project.pbxproj"
out.write_text("\n".join(lines) + "\n")
print(f"Wrote {out}")
print(f"App sources: {len(swift_files)}")
print(f"Widget sources: {len(widget_files)}")
print(f"Test sources: {len(test_files)}")
print(f"Assets: {len(asset_catalogs)}")
