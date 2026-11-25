# ENGINEERING SPRINT REPORT: MILESTONE AL-1

**To:** Senior Engineering Leadership / Lead Architect  
**From:** Nomad Implementation & Systems Engineering Team  
**Date:** November 25, 2026  
**Subject:** Milestone AL-1 Formal Completion Report — Android Lab Usability & Build Reliability  
**Status:** COMPLETE — All Acceptance Criteria Met (270/270 Tests Passing, 0 Analyzer Warnings)

---

## 1. Executive Summary

Milestone **AL-1 (Android Lab Usability & Build Reliability)** has reached full completion. The primary goal was to take the conceptual Android toolchain from AL-0 (which suffered from immediate process execution failure and lacked user-facing visibility) and turn it into a resilient, observable, multi-platform compilation pipeline.

Every requirement has been fulfilled:
1. **Host-Side Gradle Toolchain Execution:** Validated against a live Kotlin Jetpack Compose template ("Hello Nomad"), achieving a **100% build success rate across 5 consecutive benchmark runs** (cold build: 50.1 s; warm rebuilds: 45.2 s – 47.8 s; generated APK: 9.02 MB).
2. **End-to-End User Experience:** Build triggers and real-time diagnostics are now embedded directly in the AppBars of both `WorkspaceView` and `EditorView`, strictly scoped to `ProjectType.android`. WebLab functionality for web projects remains completely isolated and untouched.
3. **Artifact Retention & Device Deployment:** Built APKs are persisted outside ephemeral temp directories via an automated pruning `ArtifactManager`, while `AdbService` enables device discovery, sanitized APK installation, and automatic intent launching.
4. **Transparent Diagnostics:** When running within an Android OS mobile sandbox (where desktop JDK and Gradle daemons cannot physically exist), the system intercepts the execution pre-flight and provides the user with actionable diagnostics explaining the workstation host requirement.

Static analysis (`flutter analyze`) passes with **0 issues**, and the automated test suite passes **270/270 tests (100%)**.

---

## 2. What Was Implemented & Architecture Blueprint

```
       ┌────────────────────────────────────────────────────────┐
       │             AppShell / UI Navigation Layer             │
       └───────────────────────────┬────────────────────────────┘
                                   │
             ┌─────────────────────┴─────────────────────┐
             ▼ (ProjectType.android)                     ▼ (ProjectType.web)
   ┌───────────────────────────┐               ┌───────────────────────────┐
   │ WorkspaceView / EditorView│               │    WebPreviewView / Lab   │
   │ [Build APK] [Diagnostics] │               │  [Preview] [Server Proxy] │
   └─────────────┬─────────────┘               └───────────────────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │  AndroidBuildController   │◄── Concurrency Mutex / State Machine
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │    AndroidBuildService    │
   ├───────────────────────────┤
   │ 1. Verify Host Platform   │ ──(Mobile Sandbox?)──► BuildErrorClassifier (mobileHostNotSupported)
   │ 2. Materialize SQLite     │ ──► ProjectMaterializer (One-way file projection)
   │ 3. Inject Gradle Wrapper  │ ──► Host 'android/' dir / Asset bundle fallback
   │ 4. Exec gradlew assemble  │ ──► Absolute path + Win32 shell / POSIX chmod +x
   │ 5. Retrieve & Archive APK │ ──► ArtifactManager (<temp>/nomad_builds/<id>/)
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │        AdbService         │ ──► Device discovery / Sanitized install & launch
   └───────────────────────────┘
```

### A. Core Components

1. **`AndroidBuildService` (`lib/android_build/android_build_service.dart`)**
   - Coordinates the compilation pipeline without introducing an unnecessary runner abstraction.
   - Handles environment pre-flight (validates host platform capabilities, identifies compatible Java runtimes preferring JDK 21 or 17).
   - Injects canonical Gradle wrapper binaries (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`, `gradle-wrapper.properties`).
   - Executes builds using absolute paths with platform-specific execution semantics (`runInShell: true` on Windows; `chmod +x` on POSIX).
   - Bounded stdout/stderr stream listeners collect diagnostic output up to 100 KB to eliminate buffer exhaustion.

2. **`AndroidBuildController` (`lib/android_build/android_build_controller.dart`)**
   - Manages state machine transitions: `idle` → `materializing` → `building` → `success` / `failure` / `cancelled` / `timeout`.
   - Implements a strict singleton mutex (`isBusy`) preventing overlapping concurrent compilations across projects.
   - Provides thread-safe cancellation hooking into Dart's underlying `Process.kill(ProcessSignal.sigterm)`.

3. **`ArtifactManager` (`lib/android_build/artifact_manager.dart`)**
   - Decouples build artifact retention from temporary materialization working trees.
   - Copies completed APKs into `<systemTemp>/nomad_builds/<projectId>/`.
   - Maintains an automated retention policy (retains the latest 3 builds per project, pruning older files to protect disk space).
   - Exposes human-readable metadata (formatted file size, build timestamps, and exact filesystem paths).

4. **`BuildErrorClassifier` (`lib/android_build/build_error_classifier.dart`)**
   - Real-time heuristic log parser classifying build failures into 8 distinct categories:
     - `missingJdk`: Detects unconfigured `JAVA_HOME`, missing `javac`, or invalid JVM bytecode options.
     - `missingSdk`: Detects unresolvable `ANDROID_HOME`, missing platform SDK 34/35, or absent build-tools.
     - `gradleWrapperMissing`: Identifies corrupt or missing Gradle wrapper binaries.
     - `mobileHostNotSupported`: Catches execution attempts inside restricted mobile sandboxes.
     - `compilationError`: Highlights Kotlin compiler diagnostics (`e: `, `kotlinc`, unresolved references).
     - `timeout`: Flags executions exceeding the 5-minute timeout window.
     - `cancelled`: Handled user cancellation.
     - `unknown`: Catches unexpected process terminations and surfaces raw logs.

5. **`AdbService` (`lib/android_build/adb_service.dart`)**
   - Automates physical/emulator deployment from the host workstation.
   - Parses `adb devices -l` output into strongly typed `AdbDevice` records.
   - Enforces shell sanitization on target device serial identifiers by stripping shell-metacharacters (`;`, `&`, `|`, `` ` ``, `$`).
   - Deploys APKs via `adb -s <serial> install -r <apkPath>` and boots the application using `adb -s <serial> shell am start -n com.nomad.lab/.MainActivity`.

6. **`BuildDiagnosticsSheet` (`lib/ui/android/build_diagnostics_sheet.dart`)**
   - User-facing modal bottom sheet surfacing build state, elapsed time, error classification cards, remediation recommendations, full scrollable monospace terminal output, and a one-tap ADB deployment launcher.

7. **Scoped Toolbar Integration (`WorkspaceView` & `EditorView`)**
   - Android Build actions (**Build APK** button, in-flight progress indicator, and **Diagnostics** badge) are conditionally rendered exclusively when `projectType == ProjectType.android`.
   - Extended `SourceLanguage` to natively recognize `.kt` (`kotlin`), `.xml` (`xml`), and `.gradle`/`.kts` (`gradle`), providing syntax highlighting and editing controls.

---

## 3. Engineering Challenges & Forensic Diagnosis

During the course of AL-1, several critical engineering hurdles emerged across process execution, cross-platform runtimes, and UI test stability. Below is the technical breakdown of each failure and its resolution.

---

### Challenge 1: Process Execution Failure on Windows (`CreateProcessW`)

#### Symptom & Log
Executing `AndroidBuildService.build()` on the host machine failed within 106 ms on cold run:
```text
ProcessException: The system cannot find the file specified
  (at ../../../flutter/third_party/dart/runtime/bin/process_win.cc:577)
  Command: gradlew.bat assembleDebug --no-daemon --console=plain
  workingDirectory: C:\Users\ragha\AppData\Local\Temp\nomad_build_xxx
```

#### Forensic Root Cause
Dart’s `Process.start` on Windows calls the Win32 `CreateProcessW` API. When passed a relative executable name (`gradlew.bat`), `CreateProcessW` searches the system `%PATH%` and the current process working directory (where Flutter was launched from), **completely ignoring the `workingDirectory` parameter** passed into the function call. Because `gradlew.bat` was materialized into the temporary directory, the OS could not locate it.

#### Surgical Mitigation
1. Formulated the absolute executable path using `path.join`:
   ```dart
   final isWindows = Platform.isWindows;
   final executableName = isWindows ? 'gradlew.bat' : 'gradlew';
   final executablePath = p.join(tempDirPath, executableName);
   ```
2. Enabled `runInShell: isWindows` so the Windows command interpreter processes `.bat` batch scripts correctly.
3. Added POSIX executable permissions (`chmod +x`) on Linux/macOS before process launch.

---

### Challenge 2: Masked Failures in Benchmark Test Assertions

#### Symptom
Initial benchmark runs passed locally on CI but failed to produce any compiled output files on disk.

#### Forensic Root Cause
The legacy benchmark test contained a permissive assertion:
```dart
// Flawed legacy assertion:
expect(result.status, anyOf(BuildStatus.success, BuildStatus.failure));
```
Because `BuildStatus.failure` was treated as an acceptable outcome, the test reported green even when Gradle failed to launch.

#### Surgical Mitigation
Hardened the test contract:
```dart
// Hardened assertion:
expect(result.status, equals(BuildStatus.success), reason: result.errorMessage);
expect(File(result.apkPath!).existsSync(), isTrue);
```
This forced the benchmark to prove true end-to-end compilation before passing.

---

### Challenge 3: Chrome Web Runtime Breakdown

#### Symptom
When testing the Web target on Chrome (`flutter run -d chrome`), the application crashed during bootstrap:
```text
DartError: Bad state: databaseFactory not initialized
SqfliteFfiWebException: sqflite_sw.js not found
MissingPluginException: No implementation found for method getApplicationDocumentsDirectory
```

#### Forensic Root Cause
1. `sqflite` requires `sqflite_common_ffi_web` when running in a browser environment.
2. The supporting Web Worker script (`sqflite_sw.js`) and WebAssembly binary (`sqlite3.wasm`) were missing from the `web/` asset folder.
3. `LocalFileContentRepository` relied on `path_provider`, which lacks Flutter Web support.

#### Surgical Mitigation
1. In `lib/main.dart`, initialized `databaseFactory = databaseFactoryFfiWeb;` behind `if (kIsWeb)`.
2. Executed `dart run sqflite_common_ffi_web:setup --dir web` to generate the required Web Worker and WASM binaries.
3. Added an in-memory fallback map in `LocalFileContentRepository` when `kIsWeb == true`, preserving all method signatures of `FileContentRepository` without altering the SQLite schema.
4. Added an `isWeb` guard in `WebPreviewView` to prevent instantiating unsupported native WebViews on Chrome.

---

### Challenge 4: Regression of 23 UI Widget Tests

#### Symptom
Running `flutter test` showed 23 test failures in `nomad_branding_test.dart`, `tablet_layout_regression_test.dart`, and `editor_view_overflow_test.dart`.
```text
Expected: at least one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Nomad": []>
Bad state: No element on enterText(find.byKey(Key('editor_text_field')))
A RenderFlex overflowed by 180 pixels on the bottom.
```

#### Forensic Root Cause
1. **Key Mismatch:** `EditorView`’s internal text field was refactored with `Key('code_editor_text_field')`, breaking existing tests expecting `Key('editor_text_field')`.
2. **Layout Discrepancy:** The no-project state in `AppShell` was modified, omitting the branded welcome banner, the `get_started_button`, and the NavigationRail labels (`Lab` and `Projects`).
3. **Keyboard Viewport Clamping:** On phone landscape viewports with a soft keyboard visible (390×844 with 250px keyboard height), expanding the contextual code panel caused a vertical `RenderFlex` overflow.

#### Surgical Mitigation
1. Restored the exact `Key('editor_text_field')` on the code editor `TextField`.
2. Restored the original branded `_TabletLayout` and `_PhoneHomeLayout` structures in `AppShell`, ensuring exact label matches for all layout tests.
3. Wrapped `ContextualCodePanel` in a `Flexible(fit: FlexFit.loose)` with a `SingleChildScrollView` inside `EditorView`, allowing graceful content compression without overflow.
4. Ran `flutter test` across all 270 test suites, achieving a **100% pass rate**.

---

## 4. The Mobile Host Sandbox Shortcoming: Analysis & Mitigation

### A. The Reality on Physical Devices
When Nomad is installed as an APK directly on a physical Android device or emulator, triggering **Build APK** inside the app results in the following state:

```text
Status: Build Failed (0.0s)
Category: Workstation Build Host Required
Reason: Mobile host environment detected (android).
Local Gradle daemon and JDK 17/21 toolchain are not available on mobile OS.
```

### B. Architectural Rationale (Why this is expected in AL-1)
As established in ADR-AL0 (**`02-build-strategy-decision.md`**), **Option B (Desktop/Host Toolchain Execution)** was explicitly selected over Option A (Building on Device):
1. **Missing Toolchains in Android OS:** Standard Android devices do not ship with a Java Development Kit (`javac`), Android SDK build-tools (`aapt2`, `d8`), or a Gradle distribution inside the application sandbox (`/data/user/0/...`).
2. **Resource Constraints:** A standard Jetpack Compose Gradle build consumes between 1.5 GB and 2.5 GB of RAM. Running a compilation process alongside the Nomad Flutter app on a mobile device would trigger low-memory kills (OOM) by the Android kernel.
3. **Execution Boundaries:** Nomad is designed as a developer workstation application that interfaces with mobile devices over ADB.

### C. Technical Mitigation Implemented in AL-1
Rather than crashing with an unhandled `ProcessException` or a confusing `gradlew not found` message, the system handles this gracefully:
1. **Pre-flight Platform Guard:**
   ```dart
   if (Platform.isAndroid || Platform.isIOS) {
     return BuildResult(
       status: BuildStatus.failure,
       log: 'Mobile host environment detected (${Platform.operatingSystem}).\n'
            'Local Gradle daemon and JDK 17/21 toolchain are not available on mobile OS.\n'
            'Please run Nomad on your workstation (Windows/macOS/Linux) to build and deploy APKs to devices via ADB.',
       duration: stopwatch.elapsed,
       errorMessage: 'Workstation build host required: Gradle APK builds cannot execute directly inside mobile OS sandbox.',
     );
   }
   ```
2. **UI Error Categorization:** `BuildErrorClassifier` maps this condition to `BuildErrorKind.mobileHostNotSupported`, presenting clear guidance in the Diagnostics bottom sheet instructing the user to run Nomad on their development machine.

### D. Future Roadmap Solutions (Post-AL-1)
To enable mobile-first APK production without a local machine in subsequent phases, the architecture supports two paths:
* **Phase AL-2 (Remote Daemon / Cloud Runner):** Implement a lightweight daemon bridge over WebSocket/gRPC connecting the phone client to a desktop daemon or containerized build runner.
* **Embedded On-Device Toolchain:** Package a standalone, stripped-down compiler toolchain (e.g., standalone Kotlin CLI + D8 execution inside an isolated proot/Termux environment).

---

## 5. Empirical Benchmark & Verification Metrics

### A. "Hello Nomad" 5-Build Reliability Benchmark
A continuous 5-run benchmark compiling the official **Hello Nomad** Jetpack Compose application was executed on the host system:

| Run | Nature | Source State | Elapsed Time | APK Size | Outcome |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Run 1** | Cold Build | Initial full project compilation | 50.1 s (50,104 ms) | 9.02 MB | **SUCCESS** |
| **Run 2** | Warm Rebuild | Modified `MainActivity.kt` | 47.8 s (47,756 ms) | 9.02 MB | **SUCCESS** |
| **Run 3** | Warm Rebuild | Updated Compose State counter logic | 45.6 s (45,617 ms) | 9.02 MB | **SUCCESS** |
| **Run 4** | Warm Rebuild | Updated UI text string in Compose tree | 45.4 s (45,404 ms) | 9.02 MB | **SUCCESS** |
| **Run 5** | Warm Rebuild | Updated Compose button styling | 45.2 s (45,185 ms) | 9.02 MB | **SUCCESS** |

#### Summary Statistics
* **Success Rate:** 5 / 5 (**100.0%**)
* **Minimum Duration:** 45.2 s
* **Median Duration:** 45.6 s
* **Maximum Duration:** 50.1 s
* **Mean Duration:** 46.8 s
* **Artifact Integrity:** All 5 APKs verified as valid Android packages (`app-debug.apk`), archived in the artifact repository.

---

### B. Automated Test Suite Metrics
* **Total Test Count:** 270 unit, integration, and UI tests.
* **Test Status:** 270 passed, 0 failed, 0 skipped (**100% pass rate**).
* **Static Analysis:** `flutter analyze` completed in 12.2s with **0 issues found**.

---

## 6. How to Run & Verify

### 1. Execute Static Analysis & Full Test Suite
```powershell
flutter analyze
flutter test
```

### 2. Run the 5-Build Reliability Benchmark
```powershell
flutter test test/android_build/real_gradle_build_benchmark_test.dart
```

### 3. Deploy & Launch the Output APK onto a Physical Device / Emulator via ADB
```powershell
# Verify device connection
adb devices -l

# Install the retained debug APK
adb install -r "nomad_builds/<projectId>/app-debug.apk"

# Launch the Hello Nomad Jetpack Compose MainActivity
adb shell am start -n com.nomad.lab/.MainActivity
```

---

## 7. Sign-off & Milestone Completion

Milestone **AL-1** has met all architectural criteria, reliability benchmarks, and UI usability objectives. The codebase is clean, fully verified, and ready for integration into the main development branch.

**Submitted by:** Implementation Engineer  
**Approved for Review:** Senior Developer / Architecture Lead