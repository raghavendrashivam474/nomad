# AL-2: Existing System Audit & Architecture Baseline
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Baseline Commit:** `bacb5cb` (tag: `v-AL-1`)  
**Status:** COMPLETE — Technical Audit  
**Date:** 2026-10-24  

---

## 1. Executive Summary

Nomad AL-1 established the initial Android development capability inside `apps/nomad_mobile`. The subsystem allows creating a Jetpack Compose project from an embedded template, editing Kotlin and Gradle files within the Nomad virtual filesystem (backed by SQLite and disk storage), materializing the workspace files into a temporary directory, executing a local host-side Gradle build (`assembleDebug`), capturing logs and errors, and deploying the generated APK to connected devices via ADB.

However, the AL-1 implementation is fundamentally a **workstation-hosted build pipeline**. In `AndroidBuildService.build()` (line 67):

```dart
if (Platform.isAndroid || Platform.isIOS) {
  return BuildResult(
    status: BuildStatus.failure,
    log: 'Mobile host environment detected...\n'
         'Local Gradle daemon and JDK 17/21 toolchain are not available on mobile OS.\n'
         'Please run Nomad on your workstation...',
    errorMessage: 'Workstation build host required...',
  );
}
```

AL-2 investigates and breaks through this restriction to enable native on-device compilation and a hybrid execution architecture.

---

## 2. Component Inventory & Existing Responsibilities

| File Path | Component | Responsibility | Architectural Boundary |
| :--- | :--- | :--- | :--- |
| `apps/nomad_mobile/lib/data/templates/android_template.dart` | `AndroidTemplate` | Provides pinned Kotlin + Compose project files (AGP 8.7.3, Kotlin 2.0.21, Compose BOM 2024.12.01, compileSdk 35, Gradle 8.11.1). | Data / Template layer |
| `apps/nomad_mobile/lib/android_build/project_materializer.dart` | `ProjectMaterializer` | Flattens virtual SQLite `FileNode` tree and `FileContentRepository` files into a real directory in `Directory.systemTemp`. Read-only projection. | Build Infrastructure |
| `apps/nomad_mobile/lib/android_build/android_build_service.dart` | `AndroidBuildService` | Host-side build orchestrator. Injects Gradle wrapper from host or asset bundle, runs `gradlew assembleDebug` via `Process.start`, tracks timeout (5 min) and cancellation. | Build Infrastructure |
| `apps/nomad_mobile/lib/android_build/android_build_controller.dart` | `AndroidBuildController` | `ChangeNotifier` managing build phases (`idle`, `preparing`, `building`, `cancelling`, `success`, `failure`, `timeout`), concurrency lock (`isBusy`), and status messages. | Presentation State |
| `apps/nomad_mobile/lib/android_build/build_result.dart` | `BuildResult`, `BuildStatus` | Immutable value objects representing build outcome (`apkPath`, `log`, `duration`, `errorMessage`). | Domain / Build Value Types |
| `apps/nomad_mobile/lib/android_build/artifact_manager.dart` | `ArtifactManager`, `ApkArtifact` | Indexes, copies, and prunes APKs in `{temp}/nomad_builds/{projectId}/`. Retains up to 3 artifacts per project. | Storage / Artifacts |
| `apps/nomad_mobile/lib/android_build/build_error_classifier.dart` | `BuildErrorClassifier`, `ClassifiedError` | Pattern matches console logs for JDK missing, Android SDK missing, wrapper missing, syntax/type errors, timeouts. | Diagnostics |
| `apps/nomad_mobile/lib/android_build/adb_service.dart` | `AdbService`, `AdbDevice` | Wraps system ADB CLI (`adb devices -l`, `adb install -r`, `adb shell am start`). Safe process execution abstraction. | Tooling / Hardware Bridge |
| `apps/nomad_mobile/lib/ui/android/build_diagnostics_sheet.dart` | `BuildDiagnosticsSheet` | Modal bottom sheet displaying build outcome, duration, artifact details, error suggestions, scrollable console log, and ADB installation triggers. | Presentation |
| `apps/nomad_mobile/lib/ui/workspace_view.dart` | `WorkspaceView` | Hosts Android build trigger (`build_apk_button`), diagnostics launch button, and instantiates default build stack when `project.type == ProjectType.android`. | Presentation |
| `apps/nomad_mobile/lib/ui/projects_view.dart` | `ProjectsView` | Allows selecting `ProjectType.android` upon project creation and generates initial `AndroidTemplate.files` into workspace. | Presentation |

---

## 3. Data Flow & Execution Pipeline (AL-1 Baseline)

```text
[Nomad SQLite / Virtual Filesystem]
                │
                ▼ (Project ID)
[ProjectMaterializer.materialize(projectId)]
                │
                ▼
[Temp Directory: nomad_android_xxxx]
  ├── build.gradle.kts
  ├── settings.gradle.kts
  ├── app/
  └── (gradlew injected from Flutter host/assets)
                │
                ▼
[AndroidBuildService.build(projectId)]
  ├── Explicit Platform Check: Rejects Android/iOS
  ├── Resolves JAVA_HOME (JDK 17/21)
  ├── Process.start(gradlew assembleDebug --no-daemon)
  └── Timeout (5 min) / Cancellation Token
                │
         ┌──────┴──────┐
      Success       Failure / Timeout / Cancel
         │                     │
         ▼                     ▼
[ArtifactManager]    [BuildErrorClassifier]
  Copy APK to           Categorize failure
  nomad_builds/         (Missing JDK/SDK/Syntax)
         │                     │
         └──────┬──────────────┘
                │
                ▼
   [AndroidBuildController]
                │
                ▼
  [BuildDiagnosticsSheet & WorkspaceView]
                │
                ▼
   [AdbService.installApk()] -> Physical Device / Emulator
```

---

## 4. Tightly Coupled Desktop Assumptions

The audit reveals six specific desktop-centric assumptions in the existing AL-1 implementation:

1. **Host OS Execution Check:**
   `AndroidBuildService` explicitly blocks execution on `Platform.isAndroid` or `Platform.isIOS`, assuming that native compilation can only ever happen on Windows, macOS, or Linux desktop.
2. **Gradle Daemon & Standard Process Spawning:**
   Execution is performed via Dart `Process.start()` calling `gradlew.bat` or `gradlew` directly. Inside Android's sandbox (SELinux + Bionic libc + W^X security policies), normal apps cannot spawn child processes directly from arbitrary paths or launch desktop shell scripts.
3. **Desktop `JAVA_HOME` Discovery:**
   `AndroidBuildService.resolveCompatibleJavaHome()` checks Windows paths (`C:\Program Files\Java\...`, `.tools\jdk-21`, Android Studio JBR). It has no concept of an on-device embedded JDK (e.g., OpenJDK ARM64) or Termux/PRoot rootfs paths.
4. **Desktop Android SDK & AAPT2:**
   Standard Gradle AGP 8.7.3 downloads `x86_64` or `aarch64` Linux binaries for AAPT2. On Android devices, AAPT2 must be compiled specifically against Android Bionic libc or executed in a glibc-compatible user environment.
5. **Coupled Build Controller to Build Service:**
   `AndroidBuildController` directly depends on the concrete `AndroidBuildService` class rather than an abstract `BuildProvider` interface.
6. **Local ADB Assumption:**
   `AdbService` assumes `adb.exe` or `adb` is in `PATH` or `$ANDROID_HOME/platform-tools`. On a mobile device, ADB is either accessed via Android Wireless Debugging (pairing code + TLS over `localhost`) or via Termux `android-tools`, or bypassed entirely since Nomad is running directly on the target device.

---

## 5. Reusable Components & Preservation Plan

In accordance with Section 8.1 and 8.2 of the Engineering Brief, the following components will be preserved without regression:

* **`WorkspaceRepository` & `FileContentRepository`:** Untouched. Virtual file persistence remains the single source of truth.
* **`ProjectMaterializer`:** Reused directly. Any build provider (on-device, workstation, remote) requires projecting SQLite virtual files into a filesystem directory or an archive payload.
* **`ArtifactManager` & `ApkArtifact`:** Reused directly. APK artifact retention, sizing, and indexing operate uniformly regardless of build provider.
* **`BuildResult` & `BuildStatus`:** Reused directly. Universal immutable build outcome contract.
* **`BuildErrorClassifier`:** Reused and extended to recognize on-device specific errors (e.g., out of memory, SELinux execution denied, missing ARM64 tools).
* **`BuildDiagnosticsSheet`:** Reused. Retains UI presentation, scrollable logs, and deployment hooks.