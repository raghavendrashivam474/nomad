# Engineering Completion & Architecture Review Report — Sprint AL-2
**Project:** Nomad — Mobile-First Development Lab  
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Baseline Commit:** `bacb5cb932412bf94ef6f9490337eabe9ff5e667` (`tag: v-AL-1`, branch: `main`)  
**To:** Senior Developer / Principal Architect  
**Status:** Submitted for Architecture & Milestone Review  

---

## 1. Verification State Matrix (Mandatory Section 12 Distinction)

Per Section 12 of the AL-2 Engineering Brief, the exact verification state of each workstream is explicitly distinguished below. No workstation execution is misrepresented as physical Android hardware execution:

| Workstream / Deliverable | Research Completed | Prototype Implemented | Implementation Verified (Host/Loopback) | Physical Device Verified | Production Integration Completed |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **A1. Existing AL-1 System Audit** | ✅ | N/A | ✅ | N/A | N/A |
| **A2. Track 3: On-Device Toolchain & Termux Research** | ✅ | N/A | N/A | N/A | N/A |
| **A3/A4. Track A (Workstation) & Track B (Remote) Research** | ✅ | N/A | N/A | N/A | N/A |
| **A5. Hybrid Build Provider Architecture (`BuildProvider`)** | ✅ | ✅ | ✅ (Unit + Integration) | ⏳ Pending ADB Target | ⏸️ Held per Sec. 6 Guardrail |
| **Versioned Mobile Template Engine (`AndroidTemplateConfig`)** | ✅ | ✅ | ✅ (Unit Tested) | ⏳ Pending ADB Target | ⏸️ Held per Sec. 6 Guardrail |
| **POC-01: Native Process Execution** | ✅ | ✅ | ✅ (`116ms`, exit `0`) | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-02: OpenJDK Execution & Heap Allocation** | ✅ | ✅ | ✅ (`-Xmx512m`, exit `0`) | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-03: Gradle Task Execution** | ✅ | ✅ | ✅ | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-04: Direct SDK Pipeline (`aapt2` → `javac` → `d8` → `apk`)** | ✅ | ✅ | ✅ (`5.56s`, `1.7 KB` APK) | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-05: Full Kotlin 2.0.21 + Jetpack Compose APK Build** | ✅ | ✅ | ✅ (`109.4s`, `9.01 MB` APK) | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-06: Companion Agent Daemon & REST Loopback Protocol** | ✅ | ✅ | ✅ (`127.0.0.1:8099`) | ⏳ Pending ADB Target | N/A (Isolated POC) |
| **POC-07: 5-Run Cold/Warm/Incremental Reliability Benchmark** | ✅ | ✅ | ✅ (`62.4s` cold / `2.99s` warm) | ⏳ Pending ADB Target | N/A (Isolated POC) |

> **Transparency Note on Physical Device Verification:** During this execution session, `adb devices -l` was queried against `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe` and returned an empty device list (no physical Android phone or running AVD was attached to the host machine). In strict compliance with Section 11 (*"Do not conceal a failed feasibility result or substitute workstation execution for on-device verification"*), all POC harnesses were executed and verified against the local toolchain and loopback companion daemon, while physical ARM64/Bionic hardware verification is flagged as the immediate validation gate upon attaching an Android target.

---

## 2. Existing Implementation Inspected & Files Examined

Before writing any code or documentation, a read-only audit of the AL-1 baseline (`bacb5cb`) was conducted across `packages/nomad_core`, `apps/nomad_mobile`, and `docs/`.

### 2.1 Files Inspected
*   **Core Domain (`packages/nomad_core/lib/`):**
    *   `nomad_core.dart`, `src/identifiers/unique_id.dart` (`EntityId`)
    *   `src/domain/project.dart`, `src/domain/project_type.dart` (`ProjectType.web`, `ProjectType.android`)
    *   `src/domain/file_node.dart`, `src/domain/file_node_type.dart`
    *   `src/domain/project_repository.dart`, `src/domain/workspace_repository.dart`, `src/domain/file_content_repository.dart`
*   **Android Build Subsystem (`apps/nomad_mobile/lib/android_build/`):**
    *   `build_result.dart` (891 bytes) — `BuildResult` and `BuildStatus` (`success`, `failure`, `timeout`, `cancelled`)
    *   `project_materializer.dart` (2,976 bytes) — Projects virtual SQLite `FileNode` tree + `FileContentRepository` strings to `Directory.systemTemp.createTemp('nomad_android_')`
    *   `android_build_service.dart` (11,293 bytes) — Host-side Gradle wrapper injector and process runner
    *   `android_build_controller.dart` (4,516 bytes) — `ChangeNotifier` state machine (`BuildPhase`)
    *   `artifact_manager.dart` (4,237 bytes) — APK retention & pruning (max 3 per project in `{systemTemp}/nomad_builds/{projectId}`)
    *   `build_error_classifier.dart` (3,742 bytes) — Log regex/substring diagnostic classifier
    *   `adb_service.dart` (5,093 bytes) — `ProcessExecutor` wrapper for `adb devices -l`, `adb install -r`, `adb shell am start`
*   **Templates & UI (`apps/nomad_mobile/lib/`):**
    *   `data/templates/android_template.dart` (6,015 bytes) — Pinned AGP `8.7.3`, Kotlin `2.0.21`, Compose BOM `2024.12.01`, `compileSdk 35`, `minSdk 24`
    *   `ui/android/build_diagnostics_sheet.dart` (14,010 bytes)
    *   `ui/workspace_view.dart` (24,145 bytes)
    *   `ui/projects_view.dart` (13,792 bytes)
*   **Gradle Wrapper Configs:**
    *   `apps/nomad_mobile/android/gradle/wrapper/gradle-wrapper.properties`
    *   `apps/nomad_mobile/assets/gradle_wrapper/gradle/wrapper/gradle-wrapper.properties`

### 2.2 Technical Audit Findings (Bottlenecks in AL-1)
1.  **Hard Platform Rejection (`android_build_service.dart` lines 67–77):**
    `AndroidBuildService.build()` explicitly checks `if (Platform.isAndroid || Platform.isIOS)` and immediately aborts with `BuildStatus.failure` and `errorMessage: 'Workstation build host required...'`.
2.  **Wrapper Version Drift Discrepancy:**
    `AndroidTemplate._wrapperProperties` specifies `gradle-8.11.1-bin.zip`, whereas `apps/nomad_mobile/android/gradle/wrapper/gradle-wrapper.properties` and `assets/gradle_wrapper/.../gradle-wrapper.properties` specify `gradle-9.1.0-all.zip`. Because `AndroidBuildService._injectGradleWrapper()` overwrites `gradle/wrapper/gradle-wrapper.properties` from the host/asset bundle *after* `ProjectMaterializer` writes the template files, materialized builds actually get upgraded to Gradle 9.1.0 unless `gradle-wrapper.properties` is preserved.
3.  **Desktop-Only `JAVA_HOME` Resolution (`android_build_service.dart` lines 39–60):**
    `resolveCompatibleJavaHome()` only checks `Platform.environment['JAVA_HOME']` and hardcoded Windows paths (`C:\Program Files\Java\jdk-21`, `.tools\jdk-21`, etc.).
4.  **Direct Controller-to-Service Coupling (`android_build_controller.dart` line 18):**
    `AndroidBuildController` requires a concrete `AndroidBuildService` instance, preventing injection of remote, workstation-LAN, or on-device companion providers without either subclassing `AndroidBuildService` or abstracting a `BuildProvider` interface.
5.  **Asset Declaration Gap in `pubspec.yaml`:**
    `AndroidBuildService._injectGradleWrapper()` attempts to fall back to `rootBundle.load('assets/gradle_wrapper/...')`, but `apps/nomad_mobile/pubspec.yaml` only declares `- assets/branding/` under `flutter: assets:`. On a packaged mobile build, `rootBundle.load` for the wrapper will fail unless those asset paths are registered or the companion runtime supplies its own Gradle distribution.

---

## 3. Core Technical Findings — On-Device Execution Feasibility (Track 3)

### 3.1 Why Normal Android Apps Cannot Run Gradle Directly
1.  **SELinux & `W^X` Enforcement (Android 10 / API 29+):**
    Untrusted app contexts (`u:r:untrusted_app:s0`) are forbidden from calling `execve()` on files residing in writable app data directories (`/data/data/<pkg>/files` or `/cache`) or `/sdcard`. Attempting to extract `java`, `aapt2`, or `gradlew` into app storage and run `Process.start()` throws `Permission denied (errno = 13 / EACCES)` at the kernel level. Only binaries packaged inside the APK's read-only `/data/app/.../lib/arm64/` directory (named `lib*.so`) have `exec_type` SELinux labels.
2.  **Bionic libc vs. GNU C Library (`glibc`):**
    Even when Kotlin (`kotlinc`), D8, R8, and `apksigner` run on pure JVM bytecode, **AGP 8.7.3 automatically downloads `aapt2-<version>-linux.jar` from Google Maven**, which contains an `aarch64` or `x86_64` ELF binary linked against `/lib/ld-linux-aarch64.so.1` (`glibc`). Android uses `/system/bin/linker64` (Bionic libc). Gradle builds on Android fail during `:app:processDebugResources` unless explicitly passed `-Pandroid.aapt2FromMavenOverride=/path/to/bionic/aapt2`.
3.  **Android 12+ Phantom Process Killer & LMK:**
    Android 12+ caps child processes (`phantom processes`) at 32 per system-wide or per-UID threshold and kills background processes exceeding CPU/PSS limits. A cold Kotlin + Compose Gradle build spawns a Gradle client, a Gradle daemon (`-Xmx2048m`), a Kotlin compiler daemon, and multiple `aapt2` worker daemons. On Android, we must pass `--no-daemon`, `-Dkotlin.compiler.execution.strategy=in-process`, and cap heap to `-Xmx1536m` (or `-Xmx2048m` on 8GB+ devices) while keeping a foreground service active.

### 3.2 Selected Architecture: Companion Build Agent + Hybrid Provider Contract
Rather than bloating the Nomad Flutter APK by 250+ MB with disguised `libopenjdk.so` binaries or fragile `ptrace`-based PRoot containers, we designed a **Provider-Independent Hybrid Architecture**:
*   **On-Device Companion Runtime (Termux / Local Daemon):** Runs ARM64 Bionic-native OpenJDK 17/21, Gradle, and Bionic `aapt2`, listening on `127.0.0.1:8089`.
*   **Workstation Agent (Track A):** Runs the exact same HTTP/REST protocol over LAN (`192.168.x.x:8089`), wrapping the host toolchain.
*   **Remote Cloud Runner (Track B):** Runs the exact same HTTP/REST protocol over HTTPS inside isolated containers/microVMs.
*   **Local Host Provider:** Wraps the existing AL-1 `AndroidBuildService` when Nomad runs on Windows/macOS/Linux.

---

## 4. What We Implemented & How

In strict compliance with **Section 6** (*"All experimental code must initially live in an isolated proof-of-concept area... Do not integrate an experimental runtime into Nomad's production application until its architecture has been approved"*) and **Section 8.1** (*"No unnecessary rewrites"*):

### 4.1 Isolated Proof-of-Concept Suite (`experiments/android_lab_on_device/`)
We built 7 standalone executable Dart verification harnesses:
1.  **`poc01_native/poc01_test.dart`:** Validates native child process spawning, stdout capture, exit code handling, and wall-clock timing.
2.  **`poc02_jvm/poc02_test.dart`:** Dynamically writes `TestJvm.java`, compiles it via `javac`, and executes it on the JVM with `-Xmx512m` to verify heap allocation and runtime properties.
3.  **`poc03_gradle/poc03_test.dart`:** Creates an isolated Gradle project and executes a custom task with `--no-daemon`.
4.  **`poc04_pipeline/poc04_test.dart`:** Bypasses Gradle completely to prove low-level SDK toolchain viability. Runs:
    *   `aapt2 link -I android.jar --manifest AndroidManifest.xml --java src -o bin/unaligned.apk`
    *   `javac --release 17 -cp android.jar -d bin/classes MainActivity.java R.java`
    *   `d8 --release --output bin --lib android.jar *.class`
    *   `jar uf bin/unaligned.apk -C bin classes.dex`
5.  **`poc05_compose/poc05_test.dart`:** Materializes the full Nomad Kotlin 2.0.21 + Jetpack Compose (BOM `2024.12.01`, AGP `8.7.3`, `compileSdk 35`) project into a temp directory, injects the Gradle wrapper, executes `gradlew assembleDebug --no-daemon --console=plain`, and verifies the generated `app-debug.apk`.
6.  **`companion_agent/agent.dart` & `companion_provider_test.dart`:** Implements the standalone HTTP loopback daemon (`GET /api/v1/capabilities`, `POST /api/v1/builds`, `POST /api/v1/builds/{id}/cancel`) and verifies client-server serialization and job dispatch.
7.  **`poc07_benchmarks/poc07_benchmark_test.dart`:** Executes a 5-build sequential stress test measuring Cold Build, Warm Cached Build, Incremental Kotlin Modification #1, Incremental Kotlin Modification #2, and No-Op Up-To-Date verification.

### 4.2 Production-Grade Hybrid Provider Contracts (`apps/nomad_mobile/lib/android_build/providers/`)
Without touching or modifying a single line of existing AL-1 files, we added:
*   **`build_provider.dart`:** Defines `BuildProviderType` (`hostLocal`, `onDeviceCompanion`, `workstationAgent`, `remoteRunner`), `BuildCapabilities`, `BuildRequest`, `BuildEvent`, `BuildEventType`, and the abstract `BuildProvider` interface.
*   **`local_host_build_provider.dart`:** Adapts the existing AL-1 `AndroidBuildService` to `BuildProvider`.
*   **`companion_build_provider.dart`:** Implements `BuildProvider` over HTTP/JSON to communicate with the on-device companion daemon (`127.0.0.1:8089`) or LAN workstation agent.
*   **`build_orchestrator.dart`:** Implements `BuildProvider` as a composite orchestrator that probes registered providers in priority order (`selectOptimalProvider()`), dispatches builds to the first available provider, and manages synchronous/asynchronous cancellation.

### 4.3 Versioned Mobile Template Customization (`apps/nomad_mobile/lib/data/templates/android_template_config.dart`)
Per Section 7 of the Brief, we implemented `AndroidTemplateConfig` supporting L0–L2 controlled mobile customization:
*   Supports custom `appName`, `packageName`, `greetingText`, `primaryColorHex`, and `includeCounterComponent` (L1/L2 stateful Compose counter with `remember { mutableIntStateOf(0) }`).
*   Dynamically rewrites `settings.gradle.kts`, `app/build.gradle.kts` (`namespace` and `applicationId`), `AndroidManifest.xml` (`android:label`), and places `MainActivity.kt` under the custom package directory tree (`app/src/main/java/<package_path>/MainActivity.kt`).
*   Preserves 100% compatibility with standard desktop Android Studio / Gradle projects.

---

## 5. Actual Commands Executed, Raw Outputs & Performance Benchmarks

### 5.1 POC-01 & POC-02 Raw Output
```text
PS> dart run experiments/android_lab_on_device/poc01_native/poc01_test.dart
=== POC-01: Native Execution Verification ===
OS: windows ("Windows 11 Home Single Language" 10.0 (Build 26300))
Architecture: 3.12.2 (stable) on "windows_x64"
Command exit code: 0
Command stdout: Nomad Native Execution OK
Execution time: 116ms
>>> POC-01 RESULT: SUCCESS

PS> dart run experiments/android_lab_on_device/poc02_jvm/poc02_test.dart
=== POC-02: OpenJDK & Heap Allocation Verification ===
Compiling TestJvm.java...
Executing TestJvm with -Xmx512m...
Exit Code: 0
Stdout:
JVM Initialized Successfully.
JVM Vendor: Oracle Corporation
JVM Version: 25.0.5.0.3
JVM Max Heap: 512 MB
JVM Total Heap: 250 MB
>>> POC-02 RESULT: SUCCESS
```

### 5.2 POC-04 Direct SDK Toolchain (`aapt2` → `javac` → `d8` → `apk`) Raw Output
```text
PS> dart run experiments/android_lab_on_device/poc04_pipeline/poc04_test.dart
=== POC-04: Direct Toolchain APK Compilation Verification ===
Android SDK: C:\Users\ragha\AppData\Local\Android\Sdk
Platform android.jar: C:\Users\ragha\AppData\Local\Android\Sdk/platforms/android-34/android.jar
Build Tools: C:\Users\ragha\AppData\Local\Android\Sdk/build-tools/34.0.0
[Step 1/4] Running AAPT2 link to create initial APK shell...
AAPT2 Link OK -> C:\Users\ragha\AppData\Local\Temp\poc04_apk_5fb44f3a/bin/unaligned.apk
[Step 2/4] Compiling Java classes with javac...
Javac OK -> Classes compiled
[Step 3/4] Running D8 to create classes.dex...
D8 OK -> C:\Users\ragha\AppData\Local\Temp\poc04_apk_5fb44f3a/bin/classes.dex
[Step 4/4] Injecting classes.dex and signing debug APK...
========================================
Direct Pipeline Execution: SUCCESS
Generated APK: C:\Users\ragha\AppData\Local\Temp\poc04_apk_5fb44f3a/app-debug.apk
APK Byte Size: 1722 bytes (1.7 KB)
Total Pipeline Duration: 5564ms
========================================
>>> POC-04 RESULT: SUCCESS
```

### 5.3 POC-05 Full Kotlin 2.0.21 + Jetpack Compose APK Build Raw Output
```text
PS> dart run experiments/android_lab_on_device/poc05_compose/poc05_test.dart
=== POC-05: Full Kotlin + Jetpack Compose Build Verification ===
Materializing Nomad Jetpack Compose project into: C:\Users\ragha\AppData\Local\Temp\poc05_compose_ba49d0e6
Injecting Gradle wrapper...
Invoking gradlew assembleDebug --no-daemon --console=plain...
> Task :app:preBuild
> Task :app:generateDebugResValues
> Task :app:mergeDebugResources
> Task :app:processDebugMainManifest
> Task :app:processDebugResources
> Task :app:compileDebugKotlin
> Task :app:dexBuilderDebug
> Task :app:mergeDexDebug
> Task :app:packageDebug
> Task :app:assembleDebug
BUILD SUCCESSFUL
========================================
Gradle assembleDebug Exit Code: 0
Build Duration: 109.4s
Generated APK: C:\Users\ragha\AppData\Local\Temp\poc05_compose_ba49d0e6/app/build/outputs/apk/debug/app-debug.apk
APK Byte Size: 9444980 bytes (9.01 MB)
========================================
>>> POC-05 RESULT: SUCCESS
```

### 5.4 POC-07 Multi-Build Reliability & Incremental Benchmark Measurements
```text
PS> dart run experiments/android_lab_on_device/poc07_benchmarks/poc07_benchmark_test.dart
```

| Build Run | Scenario | Daemon / Cache State | Duration (s) | APK Size | Exit Code |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **Run 1** | Initial Cold Build (Full Materialization) | Cold / Fresh Project | **62.44s** | 8.30 MB | `0` |
| **Run 2** | Immediate Rebuild (No Source Change) | Warm Daemon + Task Cache | **3.27s** | 8.30 MB | `0` |
| **Run 3** | Incremental Edit #1 (`MainActivity.kt` String Change) | Warm Daemon + Incremental Kotlin/DEX | **5.86s** | 8.31 MB | `0` |
| **Run 4** | Incremental Edit #2 (`MainActivity.kt` String Change) | Warm Daemon + Incremental Kotlin/DEX | **5.10s** | 8.31 MB | `0` |
| **Run 5** | No-Op Up-To-Date Verification | Warm Daemon + Up-To-Date | **2.99s** | 8.31 MB | `0` |

**Key Performance Takeaway:** Retaining a warm project directory and build cache reduces subsequent Kotlin + Compose iteration times by **91.8%** (from `62.44s` down to `5.10s` for code changes, and `2.99s` for no-op builds). Currently, AL-1's `AndroidBuildService` deletes the materialized temp directory in its `finally` block on every single build (`materializer.cleanup(tempDirPath)`), forcing every build to re-materialize from scratch. Moving to incremental workspace synchronization in AL-3 will yield a ~10x speedup.

---

## 6. Problems Encountered & Engineering Mitigations

### Problem 1: Asynchronous Race Condition in `BuildOrchestrator.cancel()`
*   **What happened:** During unit testing of `BuildOrchestrator` (`test/android_build/providers/build_orchestrator_test.dart`), calling `orchestrator.build(request)` followed immediately by `orchestrator.cancel()` failed with `Expected: <true>, Actual: <false>` on `availableProvider.wasCancelled`.
*   **Root cause:** `BuildOrchestrator.build()` is an `async` method that first awaits `selectOptimalProvider()` (which asynchronously queries `provider.getCapabilities()`). Because `await selectOptimalProvider()` yields execution to the Dart microtask loop, a synchronous call to `orchestrator.cancel()` on the next line executed *before* `_activeProvider = provider` was assigned. Thus, `_activeProvider?.cancel()` was a no-op (`null`).
*   **Mitigation:** Added a boolean state latch `bool _isCancelled = false;` to `BuildOrchestrator`. When `build()` starts, `_isCancelled` is reset to `false`. If `cancel()` is invoked while `selectOptimalProvider()` is still in flight, `_isCancelled` is set to `true`. As soon as `selectOptimalProvider()` resolves and assigns `_activeProvider = provider`, `build()` checks `if (_isCancelled) { provider.cancel(); }`. Re-tested and verified 100% deterministic cancellation.

### Problem 2: Dart Analyzer `prefer_const_constructors` vs. `unnecessary_const`
*   **What happened:** Running `flutter analyze` flagged `prefer_const_constructors` on `BuildRequest(...)` at line 41 of `build_orchestrator_test.dart`. When `final req = BuildRequest(...)` was changed to `const req = BuildRequest(...)`, the inner `const EntityId('p1')` and `const Duration(minutes: 2)` triggered two new `unnecessary_const` lint warnings because they were now inside a constant expression context.
*   **Mitigation:** Removed the redundant inner `const` keywords inside the outer `const BuildRequest(...)` invocation and re-ran `flutter analyze`, achieving **0 issues found**.

### Problem 3: PowerShell `NativeCommandError` on `java -version`
*   **What happened:** In Block 11, invoking `& java -version 2>&1` in PowerShell threw a `RemoteException / NativeCommandError` even though Java executed properly.
*   **Root cause:** OpenJDK writes `-version` output to `stderr` by default, and PowerShell's error stream redirection wraps `stderr` records as `ErrorRecord` objects when piped.
*   **Mitigation:** Handled `stdout`/`stderr` streams directly via Dart's `Process.run` / `Process.start` inside the POC harnesses rather than relying on PowerShell stderr piping.

---

## 7. Complete Inventory of Files Added (Zero Existing Files Modified)

In compliance with Section 8.1 and 8.5, **zero tracked files were modified or overwritten**. All deliverables were added cleanly:

### Documentation (`docs/android_lab/AL-2/`)
1.  `docs/android_lab/AL-2/01_EXISTING_SYSTEM_AUDIT.md` (8,497 bytes)
2.  `docs/android_lab/AL-2/02_ON_DEVICE_EXECUTION_RESEARCH.md` (4,898 bytes)
3.  `docs/android_lab/AL-2/03_TOOLCHAIN_COMPATIBILITY_MATRIX.md` (3,694 bytes)
4.  `docs/android_lab/AL-2/04_TERMUX_AND_RUNTIME_INVESTIGATION.md` (3,874 bytes)
5.  `docs/android_lab/AL-2/05_WORKSTATION_AGENT_FEASIBILITY.md` (2,887 bytes)
6.  `docs/android_lab/AL-2/06_REMOTE_RUNNER_FEASIBILITY.md` (2,243 bytes)
7.  `docs/android_lab/AL-2/07_HYBRID_ARCHITECTURE_PROPOSAL.md` (4,117 bytes)
8.  `docs/android_lab/AL-2/08_SECURITY_AND_THREAT_MODEL.md` (2,021 bytes)
9.  `docs/android_lab/AL-2/09_RESOURCE_BENCHMARK_PLAN.md` (2,102 bytes)
10. `docs/android_lab/AL-2/10_ARCHITECTURE_DECISIONS.md` (2,821 bytes)
11. `docs/android_lab/AL-2/11_MICRO_SPRINT_B_IMPLEMENTATION_PLAN.md` (1,834 bytes)
12. `docs/android_lab/AL-2/12_AL2_COMPLETION_REPORT.md` (5,840 bytes)

### Isolated Proof-of-Concept Harnesses (`experiments/android_lab_on_device/`)
13. `experiments/android_lab_on_device/poc01_native/poc01_test.dart`
14. `experiments/android_lab_on_device/poc02_jvm/poc02_test.dart`
15. `experiments/android_lab_on_device/poc03_gradle/poc03_test.dart`
16. `experiments/android_lab_on_device/poc04_pipeline/poc04_test.dart`
17. `experiments/android_lab_on_device/poc05_compose/poc05_test.dart`
18. `experiments/android_lab_on_device/companion_agent/agent.dart`
19. `experiments/android_lab_on_device/companion_agent/companion_provider_test.dart`
20. `experiments/android_lab_on_device/poc07_benchmarks/poc07_benchmark_test.dart`

### Hybrid Architecture & Template Modules (`apps/nomad_mobile/`)
21. `apps/nomad_mobile/lib/android_build/providers/build_provider.dart` (2,388 bytes)
22. `apps/nomad_mobile/lib/android_build/providers/local_host_build_provider.dart` (1,201 bytes)
23. `apps/nomad_mobile/lib/android_build/providers/companion_build_provider.dart` (3,540 bytes)
24. `apps/nomad_mobile/lib/android_build/providers/build_orchestrator.dart` (1,582 bytes)
25. `apps/nomad_mobile/lib/data/templates/android_template_config.dart` (4,512 bytes)

### Unit Tests (`apps/nomad_mobile/test/`)
26. `apps/nomad_mobile/test/android_build/providers/build_orchestrator_test.dart` (3,945 bytes)
27. `apps/nomad_mobile/test/data/templates/android_template_config_test.dart` (2,289 bytes)

---

## 8. Regression & Static Analysis Results

| Suite / Tool | Command | Result | Duration |
| :--- | :--- | :--- | :---: |
| **Core Domain Unit Tests** | `flutter test` (`packages/nomad_core`) | **20 / 20 passed** | `2.0s` |
| **Mobile App Unit & Widget Tests** | `flutter test` (`apps/nomad_mobile`) | **276 / 276 passed** (+6 new AL-2 tests) | `77.0s` |
| **Flutter Static Analyzer** | `flutter analyze` (`apps/nomad_mobile`) | **No issues found! (0 warnings, 0 errors)** | `9.3s` |

---

## 9. Remaining Risks & Recommended Next Actions (Sprint AL-3)

### Remaining Technical Risks
1.  **Physical Device Memory Pressure on 4GB/6GB Devices:** While warm builds take ~3–5 seconds, cold Kotlin + Compose builds require a ~1.5 GB – 2.0 GB JVM heap spike. On 4GB Android devices, Android's Low Memory Killer (LMK) may terminate the companion daemon mid-compilation.
2.  **AGP AAPT2 Override Enforcement:** When running inside Termux on an ARM64 Android phone, Gradle will still download the x86_64/glibc `aapt2` from Maven unless `gradle.properties` explicitly injects `android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2`.
3.  **Ephemeral Materialization Overhead:** `AndroidBuildService` currently deletes the materialized directory after every build, forfeiting incremental compilation speedups (62s vs 5s).

### Recommended Next Actions (Upon Senior Approval of ADR-0011, ADR-0012, ADR-0013)
1.  **Attach Physical ARM64 Android Target (`adb devices`) & Execute Termux Companion Run:** Run `agent.dart` inside Termux on a physical ARM64 device with `openjdk-17` and `android-tools` (`aapt2`) installed, and record physical device thermal/PSS metrics.
2.  **Wire `AndroidBuildController` to `BuildProvider` (Sprint AL-3):** Update `AndroidBuildController` to accept `BuildProvider` (defaulting to `BuildOrchestrator([LocalHostBuildProvider(...), CompanionBuildProvider(...)])`) so `WorkspaceView` transparently supports both desktop and on-device companion builds.
3.  **Persistent Incremental Build Cache:** Update `ProjectMaterializer` to support delta-syncing modified `FileNode` contents into a persistent per-project build cache directory rather than wiping the temp directory after every build.