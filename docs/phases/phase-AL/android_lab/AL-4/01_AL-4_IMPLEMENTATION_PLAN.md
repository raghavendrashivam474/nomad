# Nomad Android Lab — Sprint AL-4 Implementation Plan
**Document ID:** AL-4-PLAN-01  
**Sprint Classification:** Reliability Engineering, Root Cause Analysis, Lifecycle Hardening  
**Target Baseline:** AL-3 (tag: `v-AL-3`, commit `1872ae3`)  
**Status:** In Progress  

---

## 1. Executive Summary & Goals
Sprint AL-4 addresses the critical reliability defect in Nomad Android Lab where initiating an Android build from the Kotlin editor causes a persistent indefinite loading spinner. This sprint establishes a deterministic, observable, bounded, and recoverable build lifecycle across Flutter and the Termux Companion Agent.

---

## 2. Work Packages Breakdown

### AL-4.1 — Baseline Audit & Reproduction
- [x] Record Git baseline, working tree, and branch safety checkpoints (`feature/android-lab-al4-lifecycle-reliability`).
- [x] Audit all 10 mandatory files and component interactions across `nomad_mobile` and `companion_agent`.
- [x] Map the complete build lifecycle sequence, identifying every awaited stage.
- [x] Document the reproduction mechanisms and initial failure register.
- **Deliverable:** `02_AL-4_ARCHITECTURE_AUDIT.md`

### AL-4.2 — Structured Diagnostics & Lifecycle Tracing
- [ ] Implement correlation ID (`buildId` / `nomad-YYYYMMDD-UUID`) propagated across Flutter and Companion Agent.
- [ ] Implement lightweight structured diagnostic event logging for all lifecycle transitions (`BUILD_REQUESTED`, `CONTROLLER_STARTED`, `PROVIDER_SELECTED`, `CAPABILITY_CHECKED`, `REQUEST_SENT`, `REQUEST_RECEIVED`, `JOB_REGISTERED`, `GRADLE_STARTED`, `GRADLE_COMPLETED`, `STATUS_UPDATED`, `STATUS_RECEIVED`, `APK_DISCOVERED`, `ARTIFACT_TRANSFERRED`, `ARTIFACT_VERIFIED`, `ARTIFACT_STORED`, `BUILD_TERMINAL`).
- [ ] Ensure non-leaking, sanitized diagnostics (no credentials, tokens, or source code leak).
- **Deliverable:** Structured logging layer and trace logs.

### AL-4.3 — Root Cause Analysis (RCA)
- [ ] Formally document primary root causes:
  1. Unbounded HTTP operations (`req.close()`, `utf8.decodeStream()`, artifact stream).
  2. Companion Agent SHA-256 stub (`apkSha256 = '_'`) causing checksum verification failure and silent APK discard.
  3. Lack of progress feedback in poll loop leaving `AndroidBuildController` in static `building` phase.
  4. Unbounded process execution and inefficient string concatenation in companion log streaming.
  5. Missing cancellation affordance in UI during active builds.
- **Deliverable:** `03_AL-4_RCA.md`

### AL-4.4 — Controller & Provider Lifecycle Hardening
- [ ] Add explicit timeout guards on every HTTP lifecycle stage in `CompanionBuildProvider`.
- [ ] Implement active build progress updates in `AndroidBuildController` (e.g. streaming log snippets and durations).
- [ ] Ensure `AndroidBuildController.isBusy` and state transitions strictly terminate on every error/timeout/cancellation branch.
- [ ] Ensure cancellation immediately aborts polling, signals agent, and transitions controller to `cancelled`.
- [ ] Prevent duplicate concurrent builds with proper state gating.
- **Deliverable:** Hardened `android_build_controller.dart`, `companion_build_provider.dart`, `build_orchestrator.dart`.

### AL-4.5 — Companion Agent Reliability
- [ ] Implement true SHA-256 checksum calculation for APKs in `agent.dart` (using self-contained standard Dart crypto / standalone package).
- [ ] Create standalone `pubspec.yaml` for companion agent with `crypto` dependency for clean Termux execution.
- [ ] Optimize stdout/stderr stream consumption to prevent buffer lock or event-loop starvation.
- [ ] Robust process termination using `SIGTERM` / `SIGKILL` on cancellation/timeout.
- [ ] Improve job lifecycle tracking, status reporting, and workspace cleanup.
- **Deliverable:** Hardened `agent.dart`, `pubspec.yaml`, `setup_termux.sh`.

### AL-4.6 — Artifact Transfer & Integrity
- [ ] Bounded streaming transfer of APK with `Content-Length` and `X-APK-SHA256` headers.
- [ ] Strict SHA-256 verification before invoking `ArtifactManager.storeArtifact`.
- [ ] Atomic copy and proper cleanup of temp download files.
- [ ] Accurate error propagation when artifact transfer or verification fails.
- **Deliverable:** Verified artifact pipeline.

### AL-4.7 — Regression & End-to-End Verification
- [ ] Comprehensive unit tests for controller, providers, orchestrator, and artifact manager.
- [ ] Integration tests covering capability probing, build submission, polling, cancellation, timeout, and artifact transfer.
- [ ] Real device / Termux companion validation matrix.
- **Deliverable:** `05_AL-4_TEST_REPORT.md`, `06_AL-4_DEVICE_VALIDATION.md`, `07_AL-4_COMPLETION_REPORT.md`.
