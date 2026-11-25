# AL-2: Toolchain Compatibility Matrix
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Compatibility Matrix  
**Date:** 2026-10-24  

---

## 1. Pinned Baseline Versions (from AL-1)
- **Target OS:** Android 10 (API 29) to Android 15 (API 35)
- **Architecture:** ARM64-v8a (`aarch64`)
- **Gradle:** 8.11.1
- **Android Gradle Plugin (AGP):** 8.7.3
- **Kotlin:** 2.0.21
- **Compose Compiler:** Bundled with Kotlin 2.0.21
- **Compose BOM:** 2024.12.01
- **JDK Target:** Java 17 or Java 21

---

## 2. On-Device Component Compatibility Matrix

| Component | Standard Workstation | Android ARM64 Native (Bionic) | Android ARM64 via Termux/PRoot | Compatibility Status | Notes |
|---|---|---|---|---|---|
| **OpenJDK 17 / 21** | Native (x86_64/ARM64) | ❌ Standard Oracle/Adoptium not Bionic compatible | ✅ OpenJDK 17/21 available in Termux repo (`pkg install openjdk-17` / `openjdk-21`) | **Compatible via Termux/companion** | Verified running on ARM64 Android with `-Xmx2048m`. |
| **Gradle 8.11.1** | Native Shell / Wrapper | ❌ Wrapper bash script requires `/bin/sh` and POSIX environment | ✅ Runs directly via `termux-chroot` or Termux POSIX shell | **Compatible** | Pure Java/Groovy/Kotlin bytecode. No native code in Gradle core. |
| **Android SDK (Platform 34/35)** | Standard Google zip | ✅ Platform `android.jar` is pure Java bytecode | ✅ Platform `android.jar` is pure Java bytecode | **100% Compatible** | `android.jar` requires zero native compilation. |
| **AAPT2** | Linux/Mac/Win ELF | ❌ Prebuilt Google AGP AAPT2 binary is Glibc ELF | ✅ Bionic ARM64 AAPT2 available in Termux `android-tools` package | **Requires Architecture Adapter** | AGP's default downloaded AAPT2 must be overridden via `android.aapt2FromMaven=false` or PATH redirect. |
| **D8 / R8** | Java JAR (SDK) | ✅ Pure Java JAR (`d8.jar` / `r8.jar`) | ✅ Pure Java JAR | **100% Compatible** | Runs on any standard JVM 17+. |
| **Kotlinc 2.0.21** | Pure Java + native launcher | ✅ Kotlin compiler is JVM-based JAR | ✅ Runs seamlessly under OpenJDK 17/21 | **100% Compatible** | Kotlin compiler plugin for Jetpack Compose is JVM bytecode. |
| **Jetpack Compose BOM** | Standard Maven | ✅ Pure AAR/JAR dependencies from Maven Central / Google | ✅ Resolvable over HTTP/HTTPS from Maven Central / Google | **100% Compatible** | Dependencies resolve and cache identically. |
| **Zipalign** | Native ELF | ❌ Glibc ELF | ✅ Termux `android-tools` contains Bionic ARM64 `zipalign` | **Compatible via Bionic build** | Required for APK alignment before signing. |
| **Apksigner** | Java JAR + wrapper | ✅ Pure Java bytecode (`apksigner.jar`) | ✅ Runs directly on OpenJDK | **100% Compatible** | Debug key generation and v2/v3 signing verified. |

---

## 3. Toolchain Footprint Analysis

| Toolchain Element | Cold Storage Footprint | Runtime Peak RAM (Cold) | Runtime Peak RAM (Warm Daemon) |
|---|---|---|---|
| OpenJDK 17 Headless (ARM64) | ~140 MB | ~250 MB | ~180 MB |
| Android Platform 35 (`android.jar`) | ~65 MB | N/A (Read by AAPT2/Kotlinc) | N/A |
| Android Build-Tools (AAPT2, D8, zipalign) | ~45 MB | ~150 MB | ~80 MB |
| Gradle 8.11.1 Runtime | ~130 MB | ~350 MB | ~200 MB |
| Maven Cache (AGP, Compose BOM, AndroidX) | ~250 MB | N/A (On-disk cache) | N/A |
| **Total Practical Toolchain** | **~630 MB** | **~750 MB – 1.2 GB** | **~600 MB – 900 MB** |

**Hardware Suitability Threshold:**
- Devices with **4 GB RAM**: Marginally viable (system LMK may terminate background builds).
- Devices with **6 GB – 8+ GB RAM**: Fully viable with stable execution and active foreground service.
