# AL-1 Architecture & Integration Plan

**Date**: 2026-10-25
**Document**: 06-al1-architecture-and-integration-plan.md
**Milestone**: AL-1

## 1. Overview
The goal of AL-1 is to make Android Lab usable for real-world iterative development without rewriting existing systems or destabilizing WebLab.

## 2. Component Design & Integration

### 2.1 Build State Management (\BuildController\ / \BuildNotifier\)
- Introduce a lightweight ChangeNotifier: \AndroidBuildController\
- Maintains current state:
  \enum BuildPhase { idle, preparing, compiling, cancelling, success, failure, timeout }\
- Holds \ctiveProjectId\, \currentProgressMessage\, \lastResult\, and \isBusy\.
- Prevents concurrent executions: rejects any new build invocation while another is in progress.
- Supports build cancellation by killing the active build process cleanly.

### 2.2 UI Integration in \WorkspaceView\
- When \widget.project.type == ProjectType.android\:
  - Show a "Build APK" icon button in the AppBar actions (tooltip: 'Build APK', key: 'build_apk_button').
  - Show animated/loading icon or disabled button while busy.
  - Show a status badge / banner or snackbar when build completes or fails, offering an "Inspect" action to open the Diagnostics panel.

### 2.3 Build Diagnostics & Log Sheet (\BuildDiagnosticsSheet\)
- Accessible via button or build completion banner.
- Features:
  - Header: Status icon (Check / Cross / Clock), build duration, artifact file size (if successful).
  - High-level actionable guidance: Missing JDK, missing SDK, timeout, syntax error, or general Gradle failure.
  - Tabbed or expandable view: Actionable Summary vs Raw Console Log (up to 100 KB, monospace, scrollable).
  - Quick actions: "Install on Device" (if ADB device available and build succeeded), "Share / Copy Path", "Dismiss".

### 2.4 Artifact Management (\ArtifactManager\)
- Retains generated APKs under <systemTemp>/nomad_builds/<projectId>/.
- Provides metadata: file size (formatted in MB), creation timestamp, sha256/md5 check.
- Retains up to 3 recent APK builds per project, automatically pruning older artifacts to prevent unbounded disk growth.

### 2.5 ADB Device Integration (\AdbService\)
- Safe, restricted ADB helper:
  - \getConnectedDevices()\: parses \db devices -l\ for connected and authorized Android devices/emulators.
  - \installApk(String serial, String apkPath)\: executes \db -s <serial> install -r <apkPath>\.
  - \launchApp(String serial, String packageName, String activityName)\: executes \db -s <serial> shell am start -n ...\.
- No arbitrary shell commands allowed. Device interaction strictly requires an explicit user tap.

## 3. Preservation of Contracts
- **nomad_core**: No modifications to core repository interfaces or Project models.
- **WebLab**: Untouched. \WebPreviewView\ and live activity controller remain isolated.
- **SQLite Storage**: Read-only projection to disk is preserved. No generated build artifacts written to database.
