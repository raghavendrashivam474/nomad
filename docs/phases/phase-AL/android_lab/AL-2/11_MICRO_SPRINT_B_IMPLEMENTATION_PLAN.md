# AL-2: Micro-Sprint B Implementation Plan
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** APPROVED FOR IMPLEMENTATION  
**Date:** 2026-10-24  

---

## 1. Implementation Principles & Guardrails
- In accordance with Section 6, all experimental code must reside in an isolated location: `experiments/android_lab_on_device/`.
- No modification of mature AL-1 desktop build code until proof-of-concept validation is complete.
- All Flutter test suites must remain green with zero analyzer errors throughout the sprint.

---

## 2. Micro-Sprint B Milestone Breakdown

| Milestone | Objective | Validation Target |
|---|---|---|
| **POC-01** | Native Process Spawning & Verification | Validate execution of native binaries (`uname`, `aapt2`, `sh`) within the target Android runtime environment. |
| **POC-02** | OpenJDK ARM64 Execution | Verify headless OpenJDK 17/21 execution, memory allocation (`-Xmx2048m`), and javac compilation on Android hardware. |
| **POC-03** | Gradle 8.11.1 Execution | Execute Gradle wrapper with `--version` and simple task execution within the on-device environment. |
| **POC-04** | Minimal Native APK Compilation | Run end-to-end `aapt2 link` -> `d8` -> `zipalign` -> `apksigner` generating a valid, signed Android APK. |
| **POC-05** | Kotlin + Jetpack Compose APK Compilation | Compile the full Hello Nomad Kotlin + Jetpack Compose project using AGP 8.7.3 and Kotlin 2.0.21 on device. |
| **POC-06** | Nomad Hybrid Build Provider Prototype | Implement `BuildProvider`, `BuildRequest`, `BuildEvent`, and `CompanionBuildProvider` in `lib/android_build/providers/`. |
| **POC-07** | Reliability & Performance Benchmarking | Execute 5-build consecutive stress test; record cold vs. warm durations, RAM RSS, and APK validity. |
