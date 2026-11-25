# Nomad AL-3: Physical Device Validation & Execution Matrix

**Sprint:** AL-3  
**Target Environment:** Android ARM64  
**Primary Execution Route:** Termux Companion Daemon (127.0.0.1:8089)  

---

## 1. Physical Device & Toolchain Profile

| Component | Target Spec / Physical Runtime |
| :--- | :--- |
| **Architecture** | ARM64 (arch64 / Bionic C library) |
| **Android Version** | Android 12–15 (API 31–35) |
| **Java Runtime** | OpenJDK 17 (pkg install openjdk-17) |
| **Build Tool** | Gradle 8.11.1 (pkg install gradle) |
| **Target SDK** | Android 35 (compileSdk = 35, minSdk = 24) |
| **Kotlin / Compose** | Kotlin 2.0.21, Compose BOM 2024.12.01 |
| **Companion Agent** | Dart 3.x Daemon on http://127.0.0.1:8089 |

---

## 2. On-Device Compilation Pipeline

1. **Nomad Mobile UI**: User customizes template (L0–L2: App Name, Theme, Greeting, Counter) and taps **Build**.
2. **Snapshot Creation**: Nomad reads project nodes from SQLite and builds in-memory relative file map.
3. **Upload**: Nomad HTTP POSTs snapshot payload to http://127.0.0.1:8089/api/v1/builds.
4. **Daemon Materialization**: Daemon creates isolated temp directory and writes out project files with traversal guards.
5. **Gradle Invocation**: Daemon launches gradle assembleDebug --no-daemon --console=plain.
6. **Artifact Ingestion**: Nomad polls status, streams binary APK over GET /api/v1/builds/{jobId}/artifact, validates SHA-256 checksum, and stores in ArtifactManager.
