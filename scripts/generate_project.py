"""Generate a checked-in Xcode project without requiring XcodeGen or a Mac."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, body):
    key = ident(name)
    objects[key] = body
    return key
def quote(value): return json.dumps(str(value), ensure_ascii=False)
def refs(items): return "(" + ", ".join(items) + ")"

sources, test_sources, resources = [], [], []
app_refs, test_refs, resource_refs = [], [], []
for folder, suffix, bucket, files in [("App", "*.swift", sources, app_refs), ("Tests", "*.swift", test_sources, test_refs), ("ThirdParty", "*-LICENSE.txt", resources, resource_refs)]:
    for path in sorted((ROOT / folder).glob(suffix)):
        relative = path.relative_to(ROOT).as_posix()
        file_type = "sourcecode.swift" if suffix == "*.swift" else "text"
        file_id = add(relative, f"isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quote(relative)}; sourceTree = SOURCE_ROOT;")
        files.append(file_id)
        bucket.append(add("build:" + relative, f"isa = PBXBuildFile; fileRef = {file_id};"))

packages, products, framework_builds = [], [], []
for name, url, rev in [
    ("HorizonCalendar", "https://github.com/airbnb/HorizonCalendar", "257927434aecbc4a70163570b5ef40976f0428a2")
]:
    package = add("package:" + name, f"isa = XCRemoteSwiftPackageReference; repositoryURL = {quote(url)}; requirement = {{kind = revision; revision = {quote(rev)};}};")
    product = add("product:" + name, f"isa = XCSwiftPackageProductDependency; package = {package}; productName = {name};")
    packages.append(package); products.append(product)
    framework_builds.append(add("link:" + name, f"isa = PBXBuildFile; productRef = {product};"))

app_product = add("AfterClass.app", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = AfterClass.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = add("AfterClassTests.xctest", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = AfterClassTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
groups = [add("group:" + name, f"isa = PBXGroup; children = {refs(items)}; name = {name}; sourceTree = \"<group>\";") for name, items in [("App", app_refs), ("Tests", test_refs), ("Licenses", resource_refs), ("Products", [app_product, test_product])]]
root_group = add("rootGroup", f'isa = PBXGroup; children = {refs(groups)}; sourceTree = "<group>";')

def phase(name, kind, files):
    return add(name, f"isa = {kind}; buildActionMask = 2147483647; files = {refs(files)}; runOnlyForDeploymentPostprocessing = 0;")
app_phases = [phase("sources", "PBXSourcesBuildPhase", sources), phase("frameworks", "PBXFrameworksBuildPhase", framework_builds), phase("resources", "PBXResourcesBuildPhase", resources)]
test_phases = [phase("testSources", "PBXSourcesBuildPhase", test_sources), phase("testFrameworks", "PBXFrameworksBuildPhase", [])]

def configurations(name, extra):
    configs = []
    for mode in ["Debug", "Release"]:
        settings = dict(extra)
        if name == "project":
            settings.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if mode == "Debug" else "-O", DEBUG_INFORMATION_FORMAT="dwarf" if mode == "Debug" else "dwarf-with-dsym")
            if mode == "Debug": settings.update(ENABLE_TESTABILITY="YES", SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG $(inherited)")
        body = " ".join(f"{k} = {quote(v)};" for k, v in settings.items())
        configs.append(add(name + mode, f"isa = XCBuildConfiguration; buildSettings = {{{body}}}; name = {mode};"))
    return add(name + "ConfigList", f"isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")

project_configs = configurations("project", dict(SDKROOT="iphoneos", IPHONEOS_DEPLOYMENT_TARGET="18.0", SWIFT_VERSION="5.0", CLANG_ENABLE_MODULES="YES", CLANG_ENABLE_OBJC_ARC="YES", SWIFT_EMIT_LOC_STRINGS="YES"))
app_configs = configurations("app", dict(PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="app.afterclass.personal", CODE_SIGN_STYLE="Automatic", GENERATE_INFOPLIST_FILE="YES", INFOPLIST_KEY_CFBundleDisplayName="下课见", INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES", INFOPLIST_KEY_UISupportedInterfaceOrientations="UIInterfaceOrientationPortrait", TARGETED_DEVICE_FAMILY="1", MARKETING_VERSION="0.1.0", CURRENT_PROJECT_VERSION="1", LD_RUNPATH_SEARCH_PATHS="$(inherited) @executable_path/Frameworks"))
test_configs = configurations("tests", dict(PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="app.afterclass.personal.tests", GENERATE_INFOPLIST_FILE="YES", CODE_SIGN_STYLE="Automatic", TARGETED_DEVICE_FAMILY="1", TEST_HOST="$(BUILT_PRODUCTS_DIR)/AfterClass.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AfterClass", BUNDLE_LOADER="$(TEST_HOST)"))
app_id = ident("appTarget")
proxy = add("proxy", f"isa = PBXContainerItemProxy; containerPortal = {ident('project')}; proxyType = 1; remoteGlobalIDString = {app_id}; remoteInfo = AfterClass;")
dep = add("testDependency", f"isa = PBXTargetDependency; target = {app_id}; targetProxy = {proxy};")
add("appTarget", f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = {refs(app_phases)}; buildRules = (); dependencies = (); name = AfterClass; packageProductDependencies = {refs(products)}; productName = AfterClass; productReference = {app_product}; productType = "com.apple.product-type.application";')
test_id = add("testTarget", f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = {refs(test_phases)}; buildRules = (); dependencies = ({dep}); name = AfterClassTests; productName = AfterClassTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
add("project", f'isa = PBXProject; attributes = {{LastUpgradeCheck = 1600; BuildIndependentTargetsInParallel = YES; TargetAttributes = {{{test_id} = {{TestTargetID = {app_id};}};}};}}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base); mainGroup = {root_group}; productRefGroup = {groups[-1]}; projectDirPath = ""; projectRoot = ""; packageReferences = {refs(packages)}; targets = ({app_id}, {test_id});')
project = ROOT / "AfterClass.xcodeproj"
project.mkdir(exist_ok=True)
text = '// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n'
text += "\n".join(f"  {key} = {{{body}}};" for key, body in objects.items())
text += f"\n }};\n rootObject = {ident('project')};\n}}\n"
(project / "project.pbxproj").write_text(text, encoding="utf-8")
schemes = project / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
def buildable(identifier, name, filename):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{filename}" BlueprintName="{name}" ReferencedContainer="container:AfterClass.xcodeproj"/>'
app_ref = buildable(app_id, "AfterClass", "AfterClass.app")
test_ref = buildable(test_id, "AfterClassTests", "AfterClassTests.xctest")
(schemes / "AfterClass.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''', encoding="utf-8")
print(f"Generated project with {len(app_refs)} Swift files, {len(test_refs)} test files, one pinned Swift package.")
