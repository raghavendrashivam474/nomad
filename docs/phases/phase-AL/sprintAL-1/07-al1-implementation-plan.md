# AL-1 Implementation Plan (Micro-Sprint A)

**Date**: 2026-10-25
**Document**: 07-al1-implementation-plan.md
**Milestone**: AL-1

## 1. Targeted File Manifest

### New Files to Create:
1. \pps/nomad_mobile/lib/android_build/android_build_controller.dart\
   - State notifier orchestrating builds, cancellation, error classification, and progress status.
2. \pps/nomad_mobile/lib/android_build/adb_service.dart\
   - Restricted device detection and installation interface.
3. \pps/nomad_mobile/lib/android_build/artifact_manager.dart\
   - APK metadata calculation, storage retention (keep last 3 builds), and cleanup.
4. \pps/nomad_mobile/lib/ui/android/build_diagnostics_sheet.dart\
   - Bottom sheet / dialog displaying build status, duration, artifact details, error summaries, and log viewer.
5. \pps/nomad_mobile/test/android_build/android_build_controller_test.dart\
   - Unit tests covering build phases, concurrency rejection, timeout handling, and cancellation.
6. \pps/nomad_mobile/test/android_build/adb_service_test.dart\
   - Unit tests parsing adb output and verifying restricted command generation.
7. \pps/nomad_mobile/test/android_build/artifact_manager_test.dart\
   - Unit tests verifying APK retention policy and metadata extraction.
8. \pps/nomad_mobile/test/ui/android/build_diagnostics_sheet_test.dart\
   - Widget tests validating diagnostic rendering and user interactions.

### Existing Files to Update:
1. \pps/nomad_mobile/lib/android_build/android_build_service.dart\
   - Add cancellation token / kill method support.
   - Refactor to work in tandem with \ArtifactManager\.
2. \pps/nomad_mobile/lib/ui/workspace_view.dart\
   - Add \uild_apk_button\ in AppBar for \ProjectType.android\.
   - Wire \AndroidBuildController\ with in-progress spinner and post-build notification trigger.

## 2. Capability Implementation Sequence

### Sprint B Steps:
- **B1. Core Build Controller & Concurrency Guard**:
  - Implement \AndroidBuildController\ with mutex/busy check.
  - Unit tests for concurrent build prevention.
- **B2. Artifact Management & Error Classifier**:
  - Implement \ArtifactManager\ and classified error diagnostics (JDK, SDK, syntax, timeout).
  - Unit tests for classification and artifact retention.
- **B3. Restricted ADB Service**:
  - Implement device listing and APK installation commands with safety guarantees.
- **B4. UI Integration**:
  - Add build action in \WorkspaceView\.
  - Add \BuildDiagnosticsSheet\ with log viewer and device install trigger.
- **B5. Practical Hello Nomad Development Loop & Benchmark**:
  - Create "Hello Nomad" project.
  - Edit Kotlin Compose file with interactive state counter.
  - Run repeated builds (cold + warm benchmark runs).
  - Verify ADB detection and installation where device permits.
