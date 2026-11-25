# AL-2: Hybrid Execution Architecture Blueprint
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Architecture Proposal  
**Date:** 2026-10-24  

---

## 1. High-Level Architecture

The Nomad Hybrid Execution Architecture completely separates **what** the user builds (the project templates and workspace files) from **where and how** the build executes.

```text
[Nomad Android Lab Presentation]
  (WorkspaceView / BuildDiagnosticsSheet)
                │
                ▼
     [AndroidBuildController]
                │
                ▼
     [BuildOrchestrator]
                │
                ├── Discovers / Auto-selects active provider
                │
                ▼
  ┌────────────────────────────────────────────────────────┐
  │              «abstract» BuildProvider                  │
  │────────────────────────────────────────────────────────│
  │ + getCapabilities(): Future<BuildCapabilities>         │
  │ + startBuild(request: BuildRequest): Future<BuildJob>  │
  │ + streamEvents(jobId: String): Stream<BuildEvent>      │
  │ + cancel(jobId: String): Future<void>                  │
  │ + getResult(jobId: String): Future<BuildResult>        │
  │ + fetchArtifact(jobId: String): Future<String>         │
  └─────────────────────────┬──────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
[LocalHostBuildProvider] [CompanionBuildProvider] [RemoteBuildProvider]
(AL-1 Desktop Host:     (On-Device Termux/    (Cloud microVM:
 Win/macOS/Linux)        Loopback Daemon)      REST/HTTPS)
```

---

## 2. Core Architectural Contracts

These contracts extend and generalize the existing AL-1 models without breaking them:

### 2.1 `BuildCapabilities`

```dart
enum BuildProviderType {
  hostLocal,    // Workstation local process (Windows/macOS/Linux)
  onDevice,     // On-device companion / Termux / embedded runtime
  workstation,  // LAN-connected workstation agent
  remote,       // Cloud build runner
}

class BuildCapabilities {
  final BuildProviderType providerType;
  final String providerName;
  final bool isAvailable;
  final bool supportsCompose;
  final bool supportsOffline;
  final List<String> supportedJdkVersions;
  final String? unavailableReason;
  // ...
}
```

### 2.2 `BuildRequest`

```dart
class BuildRequest {
  final EntityId projectId;
  final String projectPath;
  final String buildType; // 'debug' | 'release'
  final Map<String, String> environmentOverrides;
  final Duration timeout;
  // ...
}
```

### 2.3 `BuildEvent`

```dart
enum BuildEventType {
  log,
  phaseChange,
  progress,
  error,
}

class BuildEvent {
  final String jobId;
  final BuildEventType type;
  final String message;
  final double? progressPercent;
  final DateTime timestamp;
  // ...
}
```

---

## 3. Seamless Migration & Backward Compatibility

* **Workstation Desktop:** When Nomad runs on Windows, macOS, or Linux, `LocalHostBuildProvider` (wrapping the existing AL-1 `AndroidBuildService`) is selected automatically. Zero breaking change or degradation for desktop developers.
* **Mobile Android:** When Nomad runs on Android, `BuildOrchestrator` probes for:
  1. `OnDeviceCompanionBuildProvider` (loopback on `127.0.0.1:8089`)
  2. `WorkstationAgentBuildProvider` (saved LAN workstation IP)
  3. `RemoteBuildProvider` (configured cloud endpoint)
  
  If none is connected, it presents a helpful setup dialog in `BuildDiagnosticsSheet` explaining how to enable on-device or workstation building.