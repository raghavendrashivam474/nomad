# AL-2: Architecture Decision Records (ADRs)
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Formal ADRs  
**Date:** 2026-10-24  

---

## ADR-0011: Provider-Independent Build Execution Architecture

### Context
Nomad's existing Android build execution (`AndroidBuildService`) is hardcoded to desktop platforms (`Platform.isWindows`, `Platform.isLinux`, `Platform.isMacOS`). Mobile execution requires different toolchain environments (on-device companion runtime, LAN workstation agent, or remote cloud runner). Tying UI or workspace management to any single provider prevents portability.

### Decision
Introduce an abstract `BuildProvider` contract interface in `nomad_core` / `android_build`. The presentation layer (`AndroidBuildController`) interacts strictly with `BuildProvider`. Existing AL-1 host build logic is retained inside `LocalHostBuildProvider`. On-device and workstation execution are implemented as pluggable providers conforming to the exact same contract.

### Consequences
- ✅ Desktop development remains 100% intact and unaffected.
- ✅ New build providers can be added without modifying `WorkspaceView` or `ProjectMaterializer`.
- ✅ Complete testability using mock and fake build providers.

---

## ADR-0012: On-Device Companion Agent Architecture

### Context
Android 10+ SELinux prevents executing arbitrary native binaries from application data directories without root. Furthermore, standard OpenJDK distributions require Bionic libc linking or a POSIX userspace.

### Decision
Adopt a Companion Agent execution pattern running on the Android device (via Termux or a dedicated companion APK). Nomad communicates with the agent over an authenticated loopback REST/WebSocket channel (`127.0.0.1:8089`).

### Consequences
- ✅ Avoids fragile NDK binary repackaging inside Nomad core.
- ✅ Reuses the exact same network protocol as the Workstation Agent (Track A) and Remote Runner (Track B).
- ✅ Clean process isolation: heavy compilation workloads cannot crash the Nomad Flutter UI process.

---

## ADR-0013: Versioned Mobile Template Customization (L0–L2)

### Context
Full unrestricted Gradle script editing on mobile introduces severe risk of broken dependencies and irreproducible builds.

### Decision
Formalize Nomad mobile project generation around structured, versioned project templates. On mobile, users customize metadata, UI strings, theme colors, and supported Kotlin logic components (L0–L2). Template definitions produce standard, portable Gradle projects that open without changes on desktop.

### Consequences
- ✅ High reliability and deterministic builds on resource-constrained devices.
- ✅ Full bidirectional compatibility between mobile and desktop workspaces.
