# AL-2: Remote Build Runner Architecture & Feasibility

**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Remote Runner Analysis  
**Date:** 2026-10-24  

---

## 1. Executive Summary

Track B evaluates offloading builds to a remote, cloud-hosted build runner. This enables developers on any mobile device to compile Jetpack Compose APKs without requiring a local workstation on the same Wi-Fi network and without needing high-end on-device RAM/CPU.

---

## 2. Remote Runner Architecture

```text
[Nomad Mobile App]
        │
        │ HTTPS POST /api/v1/builds (Bearer API Key)
        ▼
[Nomad Build Gateway / Orchestrator]
        │
        ├── Build Job Queue (Redis / BullMQ / NATS)
        │
        ▼
[Ephemeral Runner Container (Docker / Firecracker microVM)]
  ├── Base Image: ubuntu:24.04 + OpenJDK 21 + Android SDK 35 + Gradle 8.11.1
  ├── Warm Gradle Cache Volume (Read-only dependency cache)
  ├── Task: gradlew assembleDebug
  └── Artifact Uploader (Pre-signed S3 / Object Store URL)
```

### 2.1 Key Design Considerations

* **Build Isolation & Security:**
  * User projects are compiled inside disposable, unprivileged Docker containers or Firecracker microVMs.
  * Network egress from the compilation container is locked down: strictly allowed only to Maven Central and Google Maven, or fully offline with a pre-warmed Gradle dependency cache.
* **Dependency Caching:**
  * Pre-warming container base images with Compose BOM `2024.12.01`, AGP `8.7.3`, and standard Kotlin `2.0.21` dependencies cuts build times from ~90 seconds down to ~12 seconds.
* **Bandwidth Efficiency:**
  * Template-driven projects (L0–L2) have source code footprints of less than 50 KB. Uploading source files takes <100ms.
  * Downloading the resulting APK (~8–10 MB) takes ~1–3 seconds over 4G/5G/Wi-Fi.

### 2.2 Operational Cost & Complexity

* Dedicated on-demand cloud builders (e.g., AWS `c6i.xlarge`, Hetzner Cloud, or GCP `e2-standard-4`) cost approximately $0.03 – $0.05 per build hour.
* Free-tier or self-hosted options (GitHub Actions runner, user's private VPS) can also implement this exact API.