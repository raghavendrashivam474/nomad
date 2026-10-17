# AL-0: Completion Report

> **Status:** COMPLETE — Feasibility gate passed.
> Baseline: `772c22a` (main, tag v-NT-1.S-T3).
> Completion date: 2026-10-17.

---

## 1. Summary

AL-0 set out to prove that Nomad can create a minimal native Android
project, compile it into an APK, and make the artifact available to the
user. **All five feasibility questions have been answered with evidence.**

| Question | Answer | Evidence |
|---|---|---|
| Can Nomad represent a minimal Android project? | **Yes** | `AndroidTemplate` stores 7 files as `Map<String, String>` in the same pattern as `WebTemplate`. `ProjectType.android` already existed in the domain model. |
| Can the project be compiled into an APK? | **Yes** | Real `gradlew assembleDebug` produced a 9.2 MB APK with valid ZIP header. 35 Gradle tasks executed, exit code 0. |
| Where should compilation execute? | **User-controlled machine** (Option B) | JDK 21 + Android SDK 34–36.1 already present. Zero infrastructure cost. On-device (A) rejected due to memory/storage constraints. Remote (C) rejected as premature. |
| What are the real resource implications? | **See §4 below** | Cold build: 5m 27s, ~330 MB network. Warm build: expected <2 min. APK: 9.2 MB. Zero new dependencies. |
| Can it integrate without damage? | **Yes** | 257/257 tests pass. 1 existing file modified (+77 lines). Zero changes to `nomad_core`, WebLab, server, editor, database, or activity systems. |

---

## 2. File Manifest

### Modified (1 file)

| File | Change |
|---|---|
| `apps/nomad_mobile/lib/ui/projects_view.dart` | +77 lines: Android template import, creation branch in `_createProject()`, `_createAndroidProjectFiles()` helper for nested folder tree |

### New Source (4 files)

| File | Size | Purpose |
|---|---|---|
| `apps/nomad_mobile/lib/data/templates/android_template.dart` | 6,015 B | 7 project files as static const strings (AGP 8.7.3, Kotlin 2.0.21, Compose BOM 2024.12.01) |
| `apps/nomad_mobile/lib/android_build/build_result.dart` | 891 B | Immutable build outcome model (status, APK path, log, duration, error) |
| `apps/nomad_mobile/lib/android_build/project_materializer.dart` | 2,976 B | SQLite → temp directory projection using `WorkspaceRepository` + `FileContentRepository` |
| `apps/nomad_mobile/lib/android_build/android_build_service.dart` | 5,887 B | Build orchestration: materialize → inject wrapper → `gradlew assembleDebug` → copy APK → cleanup |

### New Tests (3 files)

| File | Tests | Coverage |
|---|---|---|
| `test/data/templates/android_template_test.dart` | 8 | File completeness, non-empty content, version pins, manifest structure, Compose label |
| `test/android_build/build_result_test.dart` | 3 | Success/failure/timeout semantics |
| `test/android_build/project_materializer_test.dart` | 4 | Materialization, empty project error, cleanup, idempotent cleanup |

### Documentation (3 files)

| File | Purpose |
|---|---|
| `docs/phases/phase-AL/01-architecture-map.md` | Actual codebase structure, contracts, execution flows |
| `docs/phases/phase-AL/02-build-strategy-decision.md` | Options A/B/C evaluation, evidence, decision rationale |
| `docs/phases/phase-AL/03-implementation-plan.md` | Step-by-step plan, file changes, risks |

---

## 3. Test Results

| Suite | Tests | Passed | Failed |
|---|---|---|---|
| AL-0 new tests | 15 | 15 | 0 |
| Full regression suite | 257 | 257 | 0 |
| Static analysis (`dart analyze lib/`) | 1 pre-existing warning | — | — |

The single warning (`_PhoneHomeLayout` unused in `app_shell.dart:641`) is
pre-existing and unrelated to AL-0.

---

## 4. Performance & Cost Evidence

| Metric | Value | Notes |
|---|---|---|
| Nomad APK size delta | Not measured | No release build performed during AL-0. Zero new dependencies added, so delta expected to be negligible. |
| Additional dependencies | **None** | `pubspec.yaml` unchanged. All new code uses existing `nomad_core`, `path`, `dart:io`. |
| Build duration (cold) | **5m 27s** | First run: Gradle 8.11.1 distribution download + all Compose/AndroidX dependencies. 35 tasks executed. |
| Build duration (warm) | Not measured | Expected <2 min with cached Gradle distribution and dependencies. |
| Peak memory | Unknown | No profiling performed. Gradle JVM args set to `-Xmx2048m`. |
| Local storage (template) | ~6 KB | Dart const strings in `android_template.dart`. |
| Local storage (APK) | **9,223.6 KB** | Debug APK with Compose Material3 + Activity Compose. |
| Infrastructure cost | **$0** | Local machine build. No cloud services. |
| Network transfer (cold) | ~330 MB | Gradle dist (~130 MB) + Maven dependencies (~200 MB). Cached after first run. |
| Network transfer (warm) | ~0 MB | All dependencies cached in `~/.gradle`. |
| Reliability | **1/1** | Single cold build succeeded. No flaky failures observed. |
| Artifact validity | **Valid** | ZIP magic bytes `PK` confirmed. APK at `app/build/outputs/apk/debug/app-debug.apk`. |

---

## 5. Acceptance Criteria

- [x] Existing architecture and contracts documented (01-architecture-map.md)
- [x] Build strategy has documented rationale (02-build-strategy-decision.md)
- [x] Minimal Kotlin/Compose project reproducibly created (AndroidTemplate, 7 files)
- [x] Real build produces valid APK (9.2 MB, ZIP-verified, exit code 0)
- [x] APK retrievable through artifact workflow (copied to `systemTemp/nomad_builds/`)
- [x] Success, failure, timeout cases handled (BuildResult model, AndroidBuildService)
- [x] Automated tests cover new logic (15 tests, all passing)
- [x] Existing WebLab workflows pass regression (257 total, all passing)
- [x] Full test suite and static analysis run
- [x] Resource and cost evidence recorded (table above)
- [x] No material architectural decisions required (no ADR needed)
- [x] Known limitations disclosed (see §6)
- [x] Completion report with next-milestone recommendation

---

## 6. Known Limitations

1. **Host toolchain required.** Build requires JDK 17+ and Android SDK on the
   machine running Nomad. Not viable on a bare phone.
2. **No on-device build.** Option A rejected for AL-0.
3. **No remote/cloud build.** Option C rejected for AL-0.
4. **Debug signing only.** Uses default debug keystore.
5. **No incremental caching.** Each materialization is a clean build.
6. **No ADB install test.** ADB is available at the SDK path but physical
   device installation was not tested during AL-0.
7. **No build UI in the app.** The build service is wired in code but no
   "Build" button has been added to the workspace UI. AL-0 proves the
   pipeline, not the UX.
8. **Gradle wrapper sourced from Flutter host.** Requires the Flutter host
   Android project to be initialized (`flutter build apk` or `flutter run`
   at least once).
9. **Warm build time not measured.** Only the cold first-run was executed.

---

## 7. Recommendation for AL-1

AL-0 has proven the complete build path. AL-1 should focus on making it
usable:

### Suggested AL-1 scope

1. **Build UI integration.** Add a "Build APK" action to the workspace
   screen for Android projects. Show progress, success/failure, and APK
   path. Wire `AndroidBuildService` into the existing navigation.
2. **Warm build measurement.** Run a second build with cached dependencies
   and record the actual duration.
3. **ADB install test.** If a device or emulator is available, push the
   APK and verify it launches with the "Nomad Android Lab" screen.
4. **Build log viewer.** Surface the Gradle output in the Activity panel
   or a dedicated build log view.
5. **Error recovery.** Handle common failure modes (missing SDK, JDK
   version mismatch, disk full) with actionable error messages.
6. **Regression hardening.** Add an integration test that creates an
   Android project via the repository layer, materializes it, and
   verifies the file tree matches the template.

### Suggested AL-1 non-goals

- Live preview of Android apps inside Nomad
- Release signing or Play Store publishing
- Multi-module Android projects
- NDK / native code support
- Android emulator inside Nomad

---

## 8. Architecture Decision

No ADR was required. AL-0 introduced no new abstractions, modified no
shared contracts, and changed no database schema. The `AndroidBuildService`
is a self-contained module that can be absorbed into a future Runner
abstraction when one is warranted by evidence.

---

*AL-0 feasibility gate: **PASSED**.*
