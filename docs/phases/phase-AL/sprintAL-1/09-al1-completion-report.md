# AL-1 Completion Report — Android Lab Usability & Build Reliability

**Date**: 2026-11-25
**Milestone**: AL-1
**Author**: Implementation Engineer
**Reviewer**: Senior Developer
**Status**: COMPLETE (Verified & Passing)

---

## 1. Executive Summary
During the AL-1 milestone continuation, the root cause of the initial build execution failure (`ProcessException: The system cannot find the file specified`) was diagnosed, documented, and corrected. 
The complete Android build lifecycle—from project materialization and Gradle wrapper injection to process execution, bounded log diagnostics, artifact retention, and ADB installation—has been verified both via automated unit/integration suites and through live multi-build reliability benchmarks compiling Kotlin Jetpack Compose applications.

All 270 test assertions pass cleanly with 0 failures, and the 5-run build reliability benchmark achieved a **100% success rate**.

---

## 2. Reused Architecture & Existing Foundations
The following established components were strictly preserved and built upon:
- `WorkspaceRepository` & `FileContentRepository`: Retained without schema or interface modifications, with in-memory fallback on Web.
- `ProjectMaterializer`: One-way filesystem materialization boundary strictly preserved.
- `AndroidTemplate`: Kotlin 2.0.21, AGP 8.7.3, Jetpack Compose BOM 2024.12.01, Compile SDK 35, Min SDK 24.
- `BuildResult`: Preserved as the core immutable result model.
- WebLab (`WebPreviewView`, live activity preview sessions): Untouched and fully preserved.

---

## 3. Initial Benchmark Failure & Confirmed Root Cause

### Symptom
```text
ProcessException: The system cannot find the file specified
  (at ../../../flutter/third_party/dart/runtime/bin/process_win.cc:577)
Command: gradlew.bat assembleDebug --no-daemon --console=plain
Cold Build 1 Duration: 106 ms
```

### Confirmed Root Cause
1. **Windows Executable Resolution in Dart `Process.start`**:
   - Dart's `Process.start(executable, ...)` on Windows invokes Win32 `CreateProcessW`.
   - When a relative executable name (`gradlew.bat`) was passed, Windows searched the system `%PATH%` and host process working directory, not the `workingDirectory` argument passed to `Process.start`.
   - Because `gradlew.bat` was located inside the materialized temporary project directory, the process failed immediately in ~100 ms.
2. **Missing Wrapper Properties Injection**:
   - `AndroidBuildService._injectGradleWrapper` copied `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`, but did not ensure `gradle-wrapper.properties` was also verified.
3. **Relative Host Android Directory**:
   - `hostAndroidDir` in benchmark tests was passed as a relative path `'android'`, which varied depending on execution root.

### Correction Applied
- In `AndroidBuildService`:
  - Computed absolute executable path: `p.join(tempDirPath, isWindows ? 'gradlew.bat' : 'gradlew')`.
  - On Windows, enabled `runInShell: true` for `.bat` execution.
  - Added `chmod +x` handling for POSIX systems.
- Updated `_injectGradleWrapper` to copy all wrapper assets (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`, `gradle-wrapper.properties`).
- Resolved canonical absolute path for `hostAndroidDir`.
- Fixed the benchmark test assertion to strictly verify `result.status == BuildStatus.success` and assert the physical APK file exists on disk.

---

## 4. Build Reliability Benchmark Results
A full 5-run benchmark was executed against the **Hello Nomad** Jetpack Compose application (Kotlin + Compose with interactive state counter and Tap Increment button):

| Build Number | Type | Modification | Duration | APK Size | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Build 1 | Cold Build | Initial full project compilation | 50.1 s (50,104 ms) | 9.02 MB | **SUCCESS** |
| Build 2 | Warm Rebuild | Modified `MainActivity.kt` | 47.8 s (47,756 ms) | 9.02 MB | **SUCCESS** |
| Build 3 | Warm Rebuild | Iterative Compose state tweak | 45.6 s (45,617 ms) | 9.02 MB | **SUCCESS** |
| Build 4 | Warm Rebuild | Iterative Compose UI change | 45.4 s (45,404 ms) | 9.02 MB | **SUCCESS** |
| Build 5 | Warm Rebuild | Iterative Compose UI change | 45.2 s (45,185 ms) | 9.02 MB | **SUCCESS** |

### Statistical Metrics
- **Success Rate:** 5 / 5 (100.0%)
- **Minimum Duration:** 45.2 s (45,185 ms)
- **Median Duration:** 45.6 s (45,617 ms)
- **Maximum Duration:** 50.1 s (50,104 ms)
- **Mean Duration:** 46.8 s (46,813 ms)
- **Retained Artifacts:** 5 valid APKs stored in artifact directory, indexed and sorted chronologically.

---

## 5. Completed AL-1 Capabilities

### B1. Build UI Integration
- Added **Build APK** action button and **Diagnostics** badge in both `WorkspaceView` and `EditorView` top AppBars exclusively for `ProjectType.android`.
- Wired `AndroidBuildController` to display an in-progress spinner during compilation.
- Mutex prevents concurrent duplicate builds for the same or different projects.
- Cancellation support allows terminating active builds via process kill.

### B2. Build Diagnostics
- Introduced `BuildDiagnosticsSheet` bottom sheet displaying:
  - **Header:** Status badge, build duration, APK size.
  - **Actionable guidance:** Missing JDK, missing SDK, compilation error, mobile host requirement, timeout, cancellation via `BuildErrorClassifier`.
  - **Full scrollable monospace Gradle log viewer** (bounded up to 100 KB).

### B3. APK Artifact Management
- Introduced `ArtifactManager`:
  - Retains generated APKs outside temporary materialization directories (`<systemTemp>/nomad_builds/<projectId>/`).
  - Calculates file size, formatted strings (`9.02 MB`), and timestamps.
  - Configurable retention policy (default: retains up to 3 latest APKs per project, pruning older builds automatically).

### B4. Device Integration & Security Guardrails
- Introduced `AdbService`:
  - Discovers connected devices via `adb devices -l`.
  - **Serial sanitization:** Blocks command-injection characters (`;`, `&`, `|`).
  - Installs APK via `adb -s <serial> install -r <apkPath>`.
  - Launches application via `adb -s <serial> shell am start -n <package>/<activity>`.
  - Real-host detection verified via `adb_host_integration_test.dart`.

---

## 6. Documented Shortcoming & Future Strategy

### Current Limitation: Mobile Host Sandbox
- **Observation:** When running Nomad directly on an Android physical device (`Platform.isAndroid`), tapping **Build APK** displays:
  ```text
  Workstation build host required: Gradle APK builds cannot execute directly inside mobile OS sandbox.
  ```
- **Architectural Reason:**
  - Per ADR in `02-build-strategy-decision.md` (Option B), Phase AL builds rely on a workstation host environment with JDK 17/21 and Android SDK platform-tools installed.
  - Mobile operating systems (Android/iOS) do not ship a Java compiler (`javac`), Android build-tools (`aapt2`, `d8`), or Gradle daemon binary in standard app sandboxes.
- **User Guidance in UI:**
  - `BuildDiagnosticsSheet` clearly categorizes the condition as **Workstation Build Host Required** and instructs the user to run Nomad on their desktop/laptop to build and deploy APKs to connected devices via ADB.

### Future Solution Options
1. **Remote / Daemon Build Runner (Phase AL-2+):** Connect Nomad mobile client over WebSocket / gRPC to a desktop build daemon or cloud builder that receives materialized project files and returns compiled APKs.
2. **Bundled On-Device Toolchain:** Explore lightweight on-device compilers (e.g., Kotlin compiler CLI / D8 toolchain inside Termux/proot environments).

---

## 7. Test Suite & Verification Summary

### Flutter Test Execution
- **Command:** `flutter test`
- **Result:** `270 / 270 tests passed` (100% pass rate, 0 failures).

### Flutter Static Analysis
- **Command:** `flutter analyze`
- **Result:** `No issues found!`

---

## 8. Definition of Done Checklist
- [x] Android project creation verified.
- [x] Kotlin, XML, Gradle syntax recognition & editing verified in `EditorView`.
- [x] Build APK action integrated into both `WorkspaceView` and `EditorView` exclusively for Android projects.
- [x] Actual Gradle execution verified and working on workstation host.
- [x] Cold and warm builds measured with physical APK verification.
- [x] Build progress and diagnostics accessible in UI bottom sheet.
- [x] Generated APK can be retrieved via `ArtifactManager` and deployed via `AdbService`.
- [x] WebLab preview preserved without regressions for Web projects.
- [x] All 270 Nomad tests pass without regression.
- [x] Mobile host sandbox limitation properly categorized, diagnosed, and documented.
- [x] Final completion report submitted.