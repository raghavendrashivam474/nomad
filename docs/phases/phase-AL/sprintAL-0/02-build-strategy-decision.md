# AL-0: Build Strategy Decision

> Micro-sprint A deliverable.
> Baseline: `772c22a` (main). Inspection date: 2026-10-17.

## 1. Options Evaluated

### Option A — Build on the Android Device

**Concept:** Run Gradle/JDK directly on the target phone inside Nomad's process or a sandboxed shell.

**Evidence:**
- Nomad files are stored in SQLite (ADR-0007), not on the real filesystem.
  Gradle requires a materialized directory tree with `build.gradle.kts`,
  `gradlew`, source files, and writable build output directories.
- Android devices do not ship a JDK or Gradle distribution.
- Termux can install OpenJDK on some devices, but this is not a controlled
  or reproducible environment for a production build pipeline.
- Peak memory for a minimal Compose build typically exceeds 1.5 GB.
  Many target devices have 4–6 GB total RAM shared with the OS and Nomad itself.
- Thermal throttling on sustained CPU loads would make builds unreliable.
- No evidence exists that a full AGP 8.x build can complete on a phone
  in acceptable time. Marking as **unverified — high risk**.

**Verdict:** Rejected for AL-0. May be revisited if a future milestone
introduces a constrained on-device compiler (e.g., for single-file Kotlin
scripts), but not for full APK production.

### Option B — Build on a User-Controlled Machine

**Concept:** Nomad materializes the project from SQLite to a temporary directory
on the host machine, invokes `gradlew assembleDebug`, and retrieves the APK.

**Evidence from inspection environment:**
| Resource | Status |
|---|---|
| JDK | OpenJDK 21.0.12 LTS |
| Android SDK | `C:\Users\ragha\AppData\Local\Android\Sdk` |
| SDK Platforms | 34, 35, 36, 36.1 |
| Build Tools | 34.0.0, 36.0.0, 36.1.0, 37.0.0 |
| ADB | v1.0.41 (at SDK platform-tools) |
| Gradle | Not in PATH, but `gradlew` wrapper will be bundled in template |
| Flutter | 3.44.2 stable |
| OS | Windows 11, PowerShell 5.1 |

**Advantages:**
- Zero infrastructure cost. No cloud accounts, no per-build billing.
- Full toolchain already present on the development machine.
- Build output is local — no network transfer of source code or artifacts.
- ADB available for optional install testing.
- Reproducible: same JDK, SDK, and Gradle wrapper every time.

**Risks:**
- Only works when Nomad runs on a machine with Android SDK installed.
  This is acceptable for AL-0 (feasibility proof) but must be documented
  as a limitation for future milestones.
- Materialization step adds complexity (SQLite → disk → build → cleanup).

**Verdict:** **Selected for AL-0.**

### Option C — Build Using Remote Infrastructure

**Concept:** Upload project source to a hosted CI/build service, compile remotely,
download the APK.

**Evidence:**
- Per-build cost varies by provider. GitHub Actions free tier: 2,000 min/month
  for private repos. Not zero-cost at scale.
- Build latency: cold-start Gradle builds typically 2–5 minutes on shared runners.
- Source code leaves the device — security and privacy implications.
- Network dependency: builds fail offline.
- Operational burden: CI pipeline maintenance, secret management, quota tracking.
- A remote service must not be described as free merely because a free tier exists.

**Verdict:** Rejected for AL-0. Viable for a future milestone if Nomad targets
devices without local toolchains, but premature for a feasibility proof.

## 2. Decision

**AL-0 will build on the user-controlled host machine (Option B).**

The build pipeline for AL-0 is:

1. User creates Android project in Nomad (ProjectType.android)
2. Starter files are stored in SQLite via WorkspaceRepository + FileContentRepository
3. On "Build" trigger:
   a. Materialize: read all FileNodes + content from SQLite
   b. Write to a temporary directory on the host filesystem
   c. Invoke: gradlew assembleDebug (bounded timeout)
   d. On success: locate APK at app/build/outputs/apk/debug/
   e. Copy APK to a defined artifact location
   f. Clean up temporary build directory
4. Report success/failure with diagnostics

## 3. Architectural Implications

### 3.1 No Runner abstraction introduced
Per the inspection findings, no Runner interface exists in the codebase.
AL-0 will **not** create one. The build will be invoked through a focused
`AndroidBuildService` class in `apps/nomad_mobile/lib/android_build/`.
If a future milestone needs a unified Runner, it can absorb this service.

### 3.2 Materialization is a new concern
Files live in SQLite (ADR-0007). Gradle needs real files. The materialization
step is a one-way projection: SQLite → temp directory. It does not modify
the SQLite store. Build outputs (APK, logs) are stored separately from
project source files.

### 3.3 No changes to existing web workflow
The `ProjectFileServer`, `ProjectFileResolver`, and `WebTemplate`
remain untouched. Android builds do not use the HTTP server or WebView.

### 3.4 Activity integration (optional, bounded)
Build status events may be posted to `ActivityController` using a new
`ActivityCategory.build` value, but only if it can be done without
modifying the existing event contract in a breaking way. If the enum
cannot be extended without a migration, AL-0 will use a separate
notification mechanism.

## 4. Pinned Toolchain Versions (AL-0 Template)

| Component | Version | Rationale |
|---|---|---|
| AGP | 8.7.3 | Stable, compatible with JDK 21 |
| Kotlin | 2.0.21 | Stable, Compose compiler integrated |
| Compose BOM | 2024.12.01 | Recent stable |
| compileSdk | 35 | Available in local SDK |
| minSdk | 24 | Broad device support |
| targetSdk | 35 | Matches compileSdk |
| Gradle wrapper | 8.11.1 | Compatible with AGP 8.7.x |

These will be pinned in the template's `build.gradle.kts` and
`gradle/wrapper/gradle-wrapper.properties`.

## 5. Known Limitations

- Build requires Android SDK + JDK on the host machine.
- AL-0 does not support building on the phone itself.
- AL-0 does not support remote/cloud builds.
- Signing uses the default debug keystore only.
- No incremental build caching across materializations (clean build each time).
- ADB install testing is best-effort and depends on device connectivity.
