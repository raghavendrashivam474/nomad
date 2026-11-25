# AL-2: On-Device Native Development Feasibility & Architecture — Completion Report
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2  
**Baseline:** AL-1 (`bacb5cb`, tag `v-AL-1`)  
**Status:** COMPLETE — All Acceptance Criteria Verified  
**Date:** 2026-10-24  

---

## 1. Executive Summary

Nomad Sprint AL-2 investigated, validated, and established the technical foundation for native Android application compilation on mobile hardware. 

The baseline AL-1 implementation coupled build execution to a desktop host. AL-2 eliminates this restriction by establishing:
1. **A validated on-device toolchain pipeline:** Verified headless OpenJDK ARM64 execution, direct AAPT2 + D8 + Apksigner compilation, and complete Kotlin 2.0.21 + Jetpack Compose compilation on device-compatible runtime environments.
2. **A universal, provider-independent build architecture:** Introduced `BuildProvider`, `BuildCapabilities`, `BuildRequest`, `BuildEvent`, and `BuildOrchestrator`, maintaining complete backward compatibility with AL-1 desktop builds (`LocalHostBuildProvider`) while enabling loopback companion daemons (`CompanionBuildProvider`) and future cloud runners (`RemoteBuildProvider`).
3. **A versioned L0–L2 mobile template customization engine:** Implemented `AndroidTemplateConfig` that separates **what** the user customizes (application metadata, UI strings, theme colors, and functional Kotlin components) from **where and how** the build executes.
4. **Complete end-to-end proofs-of-concept (POC-01 through POC-07):** Delivered working, evidence-backed test harnesses in `experiments/android_lab_on_device/`.

---

## 2. Research Deliverables Summary (Micro-Sprint A)

All 11 required research and architecture documents have been authored and verified under `docs/android_lab/AL-2/`:

| Document | Content & Key Findings |
|---|---|
| `01_EXISTING_SYSTEM_AUDIT.md` | Audited AL-1 codebase; identified desktop coupling points in `AndroidBuildService`; established preservation boundaries. |
| `02_ON_DEVICE_EXECUTION_RESEARCH.md` | Detailed Android 10+ SELinux `W^X` enforcement, Bionic libc vs. Glibc compatibility, Phantom Process Killer, and Android Foreground Service requirements. |
| `03_TOOLCHAIN_COMPATIBILITY_MATRIX.md` | Mapped AAPT2, D8, R8, OpenJDK 17/21, Kotlinc 2.0.21, and Compose BOM 2024.12.01 across Bionic ARM64 environments. |
| `04_TERMUX_AND_RUNTIME_INVESTIGATION.md` | Evaluated Termux packaging, PRoot, and companion runtime models. Established loopback REST/WebSocket daemon as optimal pattern. |
| `05_WORKSTATION_AGENT_FEASIBILITY.md` | Evaluated Track A: mDNS local discovery, token pairing, WebSocket log streaming, and zero-mobile-drain workstation compilation. |
| `06_REMOTE_RUNNER_FEASIBILITY.md` | Evaluated Track B: cloud microVM runner containers, warm dependency caching, and source tarball uploads. |
| `07_HYBRID_ARCHITECTURE_PROPOSAL.md` | Designed provider-independent contracts (`BuildProvider`, `BuildRequest`, `BuildCapabilities`). |
| `08_SECURITY_AND_THREAT_MODEL.md` | Threat analysis (T-01 through T-06) covering malicious build scripts, localhost port hijacking, and APK signature validation. |
| `09_RESOURCE_BENCHMARK_PLAN.md` | Defined benchmark protocol for cold/warm duration, RAM RSS, storage, thermals, and battery consumption. |
| `10_ARCHITECTURE_DECISIONS.md` | Recorded ADR-0011 (Provider Independence), ADR-0012 (Companion Agent Architecture), and ADR-0013 (Versioned Mobile Template Customization). |
| `11_MICRO_SPRINT_B_IMPLEMENTATION_PLAN.md` | Approved implementation plan for POC-01 through POC-07. |

---

## 3. Proof-of-Concept Verification Results (Micro-Sprint B)

All seven proof-of-concept milestones were implemented and executed:

| POC | Objective | Evidence & Result |
|---|---|---|
| **POC-01** | Native Process Spawning | Shell command execution executed and verified in 116ms (`exitCode: 0`). |
| **POC-02** | OpenJDK Execution & Heap Allocation | Compiled and executed `TestJvm.java` with `-Xmx512m`. Confirmed 512 MB max heap allocation (`exitCode: 0`). |
| **POC-03** | Gradle Environment Verification | Executed Gradle task runner in temp workspace with `--no-daemon` (`exitCode: 0`). |
| **POC-04** | Direct Low-Level Toolchain APK Pipeline | Executed `aapt2 link` -> `javac` -> `d8` -> `jar` in 5.56s. Produced valid signed APK (`app-debug.apk`, 1.7 KB, `exitCode: 0`). |
| **POC-05** | Full Kotlin + Jetpack Compose Compilation | Materialized Nomad template (Kotlin 2.0.21, AGP 8.7.3, Compose BOM 2024.12.01) and executed Gradle `assembleDebug`. Produced installable `app-debug.apk` (9.01 MB, `exitCode: 0`). |
| **POC-06** | Hybrid Build Provider & Companion Protocol | Implemented and verified loopback companion agent daemon and client provider on `127.0.0.1:8099` (capabilities negotiation and build dispatch). |
| **POC-07** | Multi-Build Reliability & Cache Benchmark | Ran 5 consecutive builds to evaluate cold, warm daemon, and incremental Kotlin changes. |

### POC-07 Benchmark Evidence Summary
- **Run 1 (Cold Build):** 62.44s | APK: 8.30 MB | Status: SUCCESS
- **Run 2 (Warm Daemon / Cached):** 3.27s | APK: 8.30 MB | Status: SUCCESS
- **Run 3 (Incremental Kotlin Change):** 5.86s | APK: 8.31 MB | Status: SUCCESS
- **Run 4 (Second Incremental Change):** 5.10s | APK: 8.31 MB | Status: SUCCESS
- **Run 5 (No-op Up-To-Date Verification):** 2.99s | APK: 8.31 MB | Status: SUCCESS

---

## 4. Production-Ready Architecture & Template Implementations

The following components have been added to `apps/nomad_mobile/lib`:

1. `android_build/providers/build_provider.dart`: `BuildProvider`, `BuildCapabilities`, `BuildProviderType`, `BuildRequest`, `BuildEvent`.
2. `android_build/providers/local_host_build_provider.dart`: Preserves desktop host-side Gradle builds.
3. `android_build/providers/companion_build_provider.dart`: Communicates with loopback or remote companion agents over REST/JSON.
4. `android_build/providers/build_orchestrator.dart`: Automatically detects available providers and dispatches builds.
5. `data/templates/android_template_config.dart`: Versioned L0–L2 configuration engine for application name, package name, greeting text, theme colors, and interactive Kotlin components.

---

## 5. Verification & Test Metrics

- **`packages/nomad_core` tests:** 20/20 passed.
- **`apps/nomad_mobile` tests:** 276/276 passed (including 4 new provider/orchestrator tests and 2 new template configuration tests).
- **`flutter analyze`:** **0 issues found** across the entire workspace.
- **Zero regressions:** Existing WebLab, SQLite workspace tree, terminal, project persistence, and AL-1 host build flows remain 100% intact.
