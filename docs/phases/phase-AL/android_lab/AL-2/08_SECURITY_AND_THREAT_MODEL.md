# AL-2: Security & Threat Model

**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Threat Analysis  
**Date:** 2026-10-24  

---

## 1. Threat Identification & Mitigation Matrix

| Threat ID | Threat Vector | Risk Level | Description | Architectural Mitigation |
| :--- | :--- | :--- | :--- | :--- |
| **T-01** | Arbitrary Shell Code Execution | Critical | Malicious build scripts (`build.gradle.kts` executing `Runtime.getRuntime().exec()`). | Constrained Template System (L0–L2). Nomad controls build scripts; arbitrary plugins or shell tasks are disallowed in mobile mode. |
| **T-02** | Localhost Port Hijacking | High | Rogue apps on Android probing or injecting commands into companion agent port `8089`. | **Authentication Token:** Agent generates random 256-bit UUID token on startup written to private app storage, required as `X-Nomad-Token` header for all requests. |
| **T-03** | Malicious APK Injection / Supply Chain | High | Tampered APK returned to Nomad during build retrieval. | Nomad verifies cryptographic checksum (`SHA-256`) of generated APK and runs `apksigner verify` before installation. |
| **T-04** | Denial of Service / Storage Exhaustion | Medium | Runaway build loops filling flash storage with Gradle caches. | `ArtifactManager` retains strictly at most 3 builds per project with automatic oldest-first pruning. Temp directories have strict `finally { cleanup() }` guarantees. |
| **T-05** | Battery / Thermal Drain | Medium | Gradle daemon running indefinitely in background draining mobile battery. | Companion agent enforces `--no-daemon` or idle daemon timeout of 3 minutes; kills orphaned worker processes upon disconnect or cancellation. |
| **T-06** | Cross-Project Leakage | Low | Build artifacts or sources from Project A persisting into Project B. | Each build operates in an isolated temporary directory with guaranteed deletion; artifacts are isolated under `{baseDir}/{projectId}/`. |