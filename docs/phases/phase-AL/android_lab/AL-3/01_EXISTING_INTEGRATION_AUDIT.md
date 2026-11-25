# Nomad AL-3: Initial System Integration Audit

**Sprint:** AL-3 (Physical Device Validation & On-Device Build Integration)  
**Baseline Commit:** `5ea3c02` (Tagged `v-AL-2`)  
**Date:** March 2026  
**Status:** Completed & Verified  

---

## 1. Executive Summary & Baseline Verification

A clean audit of repository state was conducted at baseline commit `5ea3c02` (`v-AL-2`).  
All pre-existing test suites pass (`nomad_core`: 20/20, `nomad_mobile/test/android_build`: 22/22).

The core finding of this audit confirms the problem statement of the AL-3 Brief:

**The user's actual Android device still displays:**
> *"Workstation build host required: Gradle APK builds cannot execute directly inside mobile OS sandbox."*

This occurs because `AndroidBuildController` remains hard-coupled directly to `AndroidBuildService`. Although AL-2 created `BuildProvider`, `LocalHostBuildProvider`, `CompanionBuildProvider`, and `BuildOrchestrator`, these abstractions were never connected to `AndroidBuildController` or wired into `AppShell` and `WorkspaceView`.

---

## 2. Existing Architecture & Coupling Map

### Current Production Wiring

```text
[ AppShell / WorkspaceView ]
         │ (instantiates directly)
         ▼
[ AndroidBuildController ]
         │ (hard-coupled: final AndroidBuildService buildService)
         ▼
[ AndroidBuildService ]
         │ (checks Platform.isAndroid || Platform.isIOS)
         ▼
[ Hard Rejection on Mobile OS ]
```

### Registered Providers vs Production Wiring

| Component | Existing Responsibility | Production Ingestion Status |
| :--- | :--- | :--- |
| `BuildProvider` | Universal build backend contract (`getCapabilities`, `build`, `cancel`) | Not consumed by `AndroidBuildController` |
| `LocalHostBuildProvider` | Adapts `AndroidBuildService` to `BuildProvider` for desktop OS | Instantiated only in provider unit tests |
| `CompanionBuildProvider` | HTTP client querying `/api/v1/capabilities` and posting `/api/v1/builds` | Instantiated only in provider unit tests |
| `BuildOrchestrator` | Probes providers in priority order, exposes `buildProject(projectId)` | Instantiated only in provider unit tests |
| `AndroidBuildController` | UI-facing state notifier managing `BuildPhase`, `BuildResult`, `ClassifiedError` | **Directly coupled** to `AndroidBuildService` |

---

## 3. Detailed Component Audits

### 3.1 `AndroidBuildController` (`apps/nomad_mobile/lib/android_build/android_build_controller.dart`)

* **Constructor:**
  ```dart
  AndroidBuildController({
    required this.buildService, // Concrete AndroidBuildService!
    ArtifactManager? artifactManager,
  })
  ```
* **Execution Call:**
  Calls `await buildService.build(projectId);` directly in `startBuild()`.
* **Cancellation Call:**
  Calls `buildService.cancel();` directly in `cancelBuild()`.
* **Artifact Retrieval:**
  On `BuildStatus.success`, calls `await artifactManager.getLatestArtifact(projectId);` assuming local filesystem artifact storage.
* **Integration Opportunity:**
  `BuildOrchestrator` already implements `Future<BuildResult> buildProject(EntityId projectId)` and `void cancel()`. By allowing `AndroidBuildController` to accept a `BuildOrchestrator` (or by having `BuildOrchestrator` implement or adapt the interface needed by the controller), the controller can remain backward-compatible with existing UI listeners while routing execution through provider negotiation.

### 3.2 `AndroidBuildService` (`apps/nomad_mobile/lib/android_build/android_build_service.dart`)

* Contains step 0:
  ```dart
  if (Platform.isAndroid || Platform.isIOS) {
    return BuildResult(
      status: BuildStatus.failure,
      errorMessage: 'Workstation build host required: Gradle APK builds cannot execute directly inside mobile OS sandbox.',
    );
  }
  ```
* **Architectural Decision:** This guard is legitimate and correct for host-local in-sandbox execution. It must not be bypassed or removed. Instead, on mobile platforms, `BuildOrchestrator` must select `CompanionBuildProvider` rather than `LocalHostBuildProvider`.

### 3.3 `CompanionBuildProvider` & Protocol Gap Analysis

* **Canonical Endpoint Discrepancy:**
  * `CompanionBuildProvider` default: `http://127.0.0.1:8089`
  * `agent.dart` default: `http://127.0.0.1:8089`
  * `companion_provider_test.dart`: `http://127.0.0.1:8099`
  * **Resolution:** `8089` is adopted as the canonical companion agent port across all files.
* **Project Snapshot Transfer Gap:**
  * `CompanionBuildProvider.build()` currently sends only `{ 'projectId': request.projectId.value, 'buildType': request.buildType }`.
  * It does not serialize the workspace files from SQLite.
  * `agent.dart` expects a `'files': { 'relativePath': 'content' }` map in the POST body.
* **Artifact Retrieval Gap:**
  * `CompanionBuildProvider` currently assumes `apkPath` in the JSON response points to a local file. On Android, if the companion runs in Termux/isolated runtime, Nomad's app sandbox cannot read files directly from Termux's private directory without an artifact download endpoint (e.g., `GET /api/v1/builds/{jobId}/artifact`).
  * The companion must expose byte streaming or Base64/chunked transfer of the generated APK.

---

## 4. Construction Site Ingestion Map

`AndroidBuildController` is instantiated in exactly two production UI call sites:

1. **`apps/nomad_mobile/lib/app/app_shell.dart` (lines 163–170):**
   ```dart
   final buildService = AndroidBuildService(
     materializer: materializer,
     hostAndroidDir: p.join(Directory.current.path, 'android'),
     artifactManager: artifactManager,
   );
   _buildController = AndroidBuildController(
     buildService: buildService,
     artifactManager: artifactManager,
   );
   ```

2. **`apps/nomad_mobile/lib/ui/workspace_view.dart` (lines 58–65):**
   ```dart
   final buildService = AndroidBuildService(
     materializer: materializer,
     hostAndroidDir: p.join(Directory.current.path, 'android'),
     artifactManager: artifactManager,
   );
   _internalBuildController = AndroidBuildController(
     buildService: buildService,
     artifactManager: artifactManager,
   );
   ```

Both sites must be upgraded to construct a `BuildOrchestrator` populated with `LocalHostBuildProvider` and `CompanionBuildProvider`.

---

## 5. Summary of Gaps to Close in AL-3

1. **Physical Device Validation (Micro-Sprint A):**
   Verify OpenJDK, Gradle, Bionic AAPT2, and Jetpack Compose compilation on physical ARM64 hardware.
2. **Companion Protocol Alignment:**
   Harmonize port `8089`, file snapshot upload, job execution, polling/event streaming, and APK byte retrieval.
3. **Controller/Orchestrator Integration (Micro-Sprint B):**
   Adapt `AndroidBuildController` to execute builds via `BuildOrchestrator`, with fallback handling that properly displays companion diagnostics on mobile.
4. **Artifact Retrieval & Verification:**
   Stream APK bytes from companion, verify SHA-256, and store in Nomad's local `ArtifactManager`.