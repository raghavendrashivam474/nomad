# AL-2: Workstation Agent Architecture & Feasibility
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Workstation Feasibility Analysis  
**Date:** 2026-10-24  

---

## 1. Executive Summary

Track A evaluates a local workstation agent running on the developer's PC/Mac (Windows/macOS/Linux) that Nomad on mobile discovers over the local Wi-Fi network. The mobile device offloads the computationally heavy compilation steps (Gradle, Kotlinc, Compose) to the workstation, while retaining full UI editing and build control on mobile.

---

## 2. Workstation Agent Architecture

```text
[Nomad Mobile Application]
        │
        │ 1. mDNS Discovery (_nomad-build._tcp.local) or Manual IP Entry
        │ 2. Mutual Pairing (HMAC-SHA256 Shared Secret / PIN)
        ▼
[Workstation Build Agent (Dart / Go / Node CLI)]
  ├── Local HTTP / WebSocket Server (Port 8089)
  ├── Project Unpacker (Expands project workspace snapshot)
  ├── Host Gradle Executor (Invokes local gradlew / Gradle daemon)
  └── Artifact Cache (Stores app-debug.apk for retrieval)
```

### 2.1 Network Discovery & Security Model

* **Discovery:** Zero-configuration local network discovery via mDNS / DNS-SD using service type `_nomad-build._tcp.local`. Fallback to manual `IP:port` input.
* **Authentication:** Pairing code displayed on workstation terminal screen. Mobile enters 6-digit PIN; agent exchanges it for a cryptographically secure JWT or bearer token.
* **Transport Security:** HTTP/2 over TLS (self-signed cert pinned during initial pairing) or local authenticated REST over private subnets.

### 2.2 Job Submission & Log Streaming

* **Submission:** Mobile issues `POST /api/v1/builds` with project files compressed as a `.tar.gz` archive or multipart JSON payload containing file tree and content hashes.
* **Streaming:** Mobile connects to `GET /api/v1/builds/{id}/events` via Server-Sent Events (SSE) or WebSocket to receive real-time `stdout`/`stderr` lines with task progress (`:app:compileDebugKotlin 45%`).
* **Artifact Retrieval:** Once status reaches `SUCCESS`, mobile downloads `GET /api/v1/builds/{id}/artifact` directly into mobile app storage.
* **Direct Install:** The workstation agent can also optionally deploy the APK directly to physical devices connected to the workstation via workstation-side ADB.

### 2.3 Resource & Performance Comparison

* **Build Times:**
  * **Cold build:** ~25–35 seconds
  * **Warm build:** ~4–8 seconds (leveraging workstation's multi-core CPU and persistent Gradle daemon)
* **Mobile Battery/Thermals:** Zero mobile thermal load; minimal battery drain.
* **Migration Path from AL-1:** The existing AL-1 `AndroidBuildService` code becomes the core engine inside the standalone Workstation Agent CLI (`packages/nomad_build_agent`).