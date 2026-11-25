# AL-2: On-Device Execution Research & OS Constraints
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Technical Investigation  
**Date:** 2026-10-24  

---

## 1. The Core Android Sandbox Challenge

Compiling an Android application requires executing multiple distinct native binaries and a Java Virtual Machine:
1. `aapt2` (ELF binary for resource compilation and linking)
2. `java` / `javac` / `kotlinc` (JVM host running Kotlin compiler & plugins)
3. `d8` / `r8` (Java/DEX bytecode compiler and shrinker)
4. `zipalign` (ELF binary for 4-byte page alignment)
5. `apksigner` (Java/JVM tool for v2/v3 APK signing)

### 1.1 SELinux and Executable Permissions (Android 10+ / API 29+)
On modern Android (API 29+), Android enforces `W^X` (Write XOR Execute) security policies via SELinux:
- Executables located in `/data/data/<package_name>/cache` or external storage (`/sdcard`) **cannot be executed** (`execve()` returns `EACCES` - Permission Denied).
- Only binaries located in the read-only application native library directory (`/data/app/.../lib/arm64`) can be executed by standard apps, and they must be named with the `lib*.so` naming convention.
- Direct invocation of arbitrary dynamic ELF binaries compiled against Glibc fails immediately because Android uses **Bionic libc**, which has a different dynamic linker (`/system/bin/linker64`), different symbols, and no `libpthread.so` or `libc.so.6`.

### 1.2 Bionic vs. Glibc Compatibility
Standard Gradle distributions and Google Android SDK build-tools distributed via Maven/Google repository contain Linux x86_64 binaries (and experimental Linux aarch64 binaries) built against GNU C Library (`glibc`). When attempting to run standard Linux aarch64 `aapt2` on Android Bionic:
- It looks for `/lib/ld-linux-aarch64.so.1`, which does not exist on Android.
- The ELF header interpreter (`PT_INTERP`) fails to load.
- Solutions:
  1. **Bionic-compiled toolchain:** Native binaries compiled specifically with Android NDK targeting Bionic.
  2. **PRoot environment:** Userspace `chroot`/`ptrace` emulation that maps Glibc paths and intercepts system calls.
  3. **Termux execution environment:** Native packages built specifically for Bionic ARM64 with Termux patches.

### 1.3 Process Lifecycle & Background Execution
Android OS aggressively kills background processes consuming significant CPU or RAM through the Low Memory Killer (LMK) and Phantom Process Killer (Android 12+):
- Android 12 introduced a limit of at most 32 child phantom processes per app uid.
- Any background process using more than 2 GB RAM without a foreground service notification is subject to immediate SIGKILL.
- Requirement for Nomad on-device builds: Any build operation running longer than 10 seconds must be tied to an explicit Android Foreground Service with an ongoing notification (`FOREGROUND_SERVICE_TYPE_SPECIAL_USE` or `DATA_SYNC`).

---

## 2. Technical Evaluation of Execution Paths

| Execution Path | Technical Mechanism | Viability | Architectural Assessment |
|---|---|---|---|
| **A. Pure In-App Process (`Process.start` inside Nomad)** | Pack `aapt2`, `d8`, `javac` as `.so` libraries in Nomad APK. Invoke via Dart `Process.start` or JNI/FFI. | **High (for lightweight pipeline)** | Excellent for L0–L2 template builds. Bypasses external app requirements, but requires custom ARM64 toolchain packaging. |
| **B. Termux Companion Service** | Nomad communicates with Termux or Termux-based companion app via IPC (Localhost HTTP/WebSocket or Unix Domain Socket). | **High (for full Gradle/Compose)** | Capable of running complete standard Gradle 8.11.1 + AGP 8.7.3 + OpenJDK 17/21. Standard development workflow. |
| **C. In-App PRoot Rootfs** | Bundle minimal Ubuntu/Debian ARM64 rootfs inside Nomad assets, execute via PRoot binary disguised as `libproot.so`. | **Medium** | High overhead (~30-50% CPU penalty from ptrace syscall interception), large initial asset download (200MB+), fragile on Samsung/Xiaomi devices. |
| **D. In-App Java via Embedded JVM (e.g. dynamic DEX/Dalvik)** | Run D8 and ECJ/Kotlinc directly on the host Android ART runtime via DEX classloading. | **Medium-High (for Java/D8)** | Bypasses OpenJDK heap entirely by running in Android's ART, but Kotlin Compose compiler plugin requires full JVM/AGP infrastructure. |

---

## 3. Conclusions & Decision

For AL-2, a two-tier on-device execution strategy is selected:
1. **Full-fidelity native builds (Kotlin + Jetpack Compose):** Supported via a **Companion Runtime Environment** (Termux-based or dedicated Nomad Build Agent on device) capable of hosting OpenJDK 17/21 and full Gradle.
2. **Nomad Core Hybrid Bridge:** Nomad core must remain agnostic to where the build occurs, submitting standard `BuildRequest` payloads and receiving structured `BuildEvent` logs and artifacts.
