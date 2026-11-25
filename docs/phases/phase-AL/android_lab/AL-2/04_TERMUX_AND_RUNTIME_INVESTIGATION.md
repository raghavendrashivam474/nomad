# AL-2: Termux & Native Runtime Investigation
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Runtime Architecture Analysis  
**Date:** 2026-10-24  

---

## 1. Overview of Termux Environment

Termux provides an Android terminal emulator and Linux userspace environment that runs directly on Android without root permissions. Unlike traditional chroot/containers, Termux compiles all its packages directly against Android's **Bionic libc**, placing binaries in `/data/data/com.termux/files/usr/bin` and linking against Bionic dynamic libraries.

### 1.1 Available Toolchain in Termux Repositories
Termux actively maintains all components needed for native Android builds:
1. `openjdk-17` and `openjdk-21`: Official ARM64 headless OpenJDK compiled for Android Bionic.
2. `android-tools`: Includes `aapt`, `aapt2`, `adb`, `fastboot`, `zipalign`.
3. `gradle`: Pre-packaged Gradle distribution with environment wrappers.
4. `ecj`, `dx`, `apksigner`: Java byte-code and packaging utilities.

---

## 2. Integration Models between Nomad and On-Device Runtime

We evaluated three architectural integration patterns for Nomad:

### Model 1: Intent / Content Provider to Installed Termux (Termux:Tasker Plugin)
- **Concept:** Nomad sends an Android `Intent` to the Termux app via `com.termux.RUN_COMMAND`.
- **Drawbacks:**
  - Requires user to separately install Termux from F-Droid (Termux on Play Store is deprecated/broken).
  - Termux enforces strict signature-level permissions (`com.termux.permission.RUN_COMMAND`) that require explicit configuration by the user in `~/.termux/termux.properties`.
  - Fragile IPC with limited real-time log streaming.

### Model 2: Localhost Daemon / Companion Agent (Recommended Architecture)
- **Concept:** A lightweight companion agent runs on the device (either inside Termux or as a dedicated companion service), exposing a secure loopback REST / WebSocket server on `127.0.0.1:<port>`.
- **Strengths:**
  - Identical architectural contract as the Workstation Agent and Remote Build Runner!
  - Real-time chunked log streaming via WebSocket or Server-Sent Events.
  - Interactive cancellation (`POST /api/v1/builds/{id}/cancel`).
  - Standard HTTP multipart or binary tarball project upload.
  - Nomad application code remains 100% identical whether building locally on-device, over LAN on a workstation, or in the cloud.

### Model 3: Embedded In-App Runtime (Nomad Companion Bundle)
- **Concept:** Nomad packages a minimal ARM64 Bionic toolchain directly in its application assets and extracts it to its app-private storage.
- **Strengths:** Zero external setup for the user. Single APK install.
- **Challenges:** APK size grows by ~150-200 MB; on Android 10+, executing extracted binaries requires specific `.so` renaming tricks or NDK execution wrappers.
- **Roadmap:** Suitable for Sprint AL-3 after hybrid protocol validation in AL-2.

---

## 3. Communication Protocol Specification (Companion Agent)

To maintain absolute backend neutrality (Section 1.2 and 4.5 of Engineering Brief), the companion runtime exposes the unified **Nomad Build Protocol**:

```text
HTTP / WebSocket on 127.0.0.1:8089 (Local Companion) or 192.168.x.x:8089 (Workstation Agent)
  ├── GET  /api/v1/capabilities  -> Returns JDK, SDK, AGP, Gradle versions & provider type
  ├── POST /api/v1/builds        -> Submits BuildRequest (multipart/form-data or tar.gz snapshot)
  ├── GET  /api/v1/builds/{id}/events -> SSE / WebSocket live log stream
  ├── POST /api/v1/builds/{id}/cancel -> Immediately cancels active process
  └── GET  /api/v1/builds/{id}/artifact -> Downloads generated APK
```

>This protocol guarantees that Nomad's Dart frontend has zero coupled dependencies on Termux, local shell commands, or operating system paths.
