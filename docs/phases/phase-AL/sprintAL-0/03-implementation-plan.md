# AL-0: Implementation Plan

> Micro-sprint A deliverable. Gate document for Micro-sprint B.
> Baseline: `772c22a` (main). Depends on: 01-architecture-map.md, 02-build-strategy-decision.md.

## 1. Scope Summary

Prove that Nomad can create a minimal Kotlin/Compose Android project,
materialize it from SQLite to disk, compile it into a debug APK via
`gradlew assembleDebug`, and make the APK artifact available.

**No changes to WebLab, ProjectFileServer, ProjectFileResolver, database
schema, or existing Runner/Activity contracts.**

## 2. Implementation Sequence

### Step 1 — Android Template (no build dependency)

**New file:** `apps/nomad_mobile/lib/data/templates/android_template.dart`

Follow the `WebTemplate` pattern (static const strings). Contains the
complete minimal project as a map of relative-path → content.

Files in the template:
- `build.gradle.kts` (root)
- `settings.gradle.kts` (root)
- `gradle.properties` (root)
- `gradle/wrapper/gradle-wrapper.properties`
- `app/build.gradle.kts`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/java/com/nomad/lab/MainActivity.kt`

The `gradlew` and `gradlew.bat` scripts and `gradle-wrapper.jar`
cannot be stored as const strings (binary content). Strategy:
- The materializer will generate `gradlew`/`gradlew.bat` from known
  templates and download `gradle-wrapper.jar` on first build, OR
- Use the host machine's existing Gradle installation to generate the
  wrapper into the materialized directory before building.
- Decision: use `gradle wrapper --gradle-version 8.11.1` from the host
  if available, otherwise bundle the wrapper scripts as const strings
  and download the jar. AL-0 will test with the host approach first.

**Pinned versions** (from 02-build-strategy-decision.md §4):
AGP 8.7.3, Kotlin 2.0.21, Compose BOM 2024.12.01, compileSdk 35,
minSdk 24, Gradle 8.11.1.

**Test:** Template map contains all required paths. No empty values.

### Step 2 — Project Creation for Android

**Modified file:** `apps/nomad_mobile/lib/ui/projects_view.dart`

In `_createProject()`, add a branch for `ProjectType.android`:
```dart
if (type == ProjectType.android && workspace != null && contents != null) {
  final starters = AndroidTemplate.files; // Map<String, String>
  for (final entry in starters.entries) {
    // Create folder nodes for directory structure
    // Create file nodes for each file
    // Write content via FileContentRepository
  }
}

```

Key detail: Android projects have nested directories
(`app/src/main/java/com/nomad/lab/`). The existing FileNode model
supports this via parentId. The creation code must build the folder
tree first, then create files under the correct parent folders.

Rollback: Already handled by the existing try/catch in
`_createProject()` which deletes project + nodes + content on failure.

Test: Creating an Android project produces the correct FileNode tree
in the repository. Creating a web project still works (regression).

### Step 3 — Project Materializer

**New file:** `apps/nomad_mobile/lib/android_build/project_materializer.dart`

Class: `ProjectMaterializer`

Responsibility: Read a project's FileNode tree and file contents from
SQLite, write them to a temporary directory on the host filesystem.

```dart
class ProjectMaterializer {
  final WorkspaceRepository workspace;
  final FileContentRepository content;

  /// Materializes project [projectId] into a new temp directory.
  /// Returns the path to the created directory.
  Future<String> materialize(EntityId projectId) async { ... }

  /// Removes a previously materialized directory.
  Future<void> cleanup(String directoryPath) async { ... }
}

```

Implementation:

* `Directory.systemTemp.createTemp('nomad_android_')`
* Fetch all nodes via `workspace.getNodesForProject(projectId)`
* Build a map of nodeId → FileNode and parentId → children
* Walk the tree: create directories for folders, write files for file nodes
* Use `content.readFile(projectId, nodeId)` for text content
* Return the temp directory path

Security: The temp directory is under the OS temp path. No user input
influences the directory name. FileNode names are validated by the domain
model (no path separators).

Test: Materialize a known project, verify directory structure matches
FileNode tree, verify file contents match. Cleanup removes the directory.

### Step 4 — Build Result Model

**New file:** `apps/nomad_mobile/lib/android_build/build_result.dart`

```dart
enum BuildStatus { success, failure, timeout, cancelled }

class BuildResult {
  final BuildStatus status;
  final String? apkPath;      // Non-null only on success
  final String log;           // Bounded build output
  final Duration duration;
  final String? errorMessage; // Non-null on failure
}

```

Pure data class. No dependencies.

### Step 5 — Android Build Service

**New file:** `apps/nomad_mobile/lib/android_build/android_build_service.dart`

Class: `AndroidBuildService`

```dart
class AndroidBuildService {
  final ProjectMaterializer materializer;

  /// Builds the project and returns a BuildResult.
  /// The command, working directory, and timeout are fixed.
  Future<BuildResult> build(EntityId projectId) async { ... }
}

```

Implementation:

* Call `materializer.materialize(projectId)` → temp dir
* Generate Gradle wrapper in temp dir (if not already in template)
* Execute: `Process.run('gradlew.bat', ['assembleDebug'], workingDirectory: tempDir, timeout: 5 minutes)`
* On Windows: `gradlew.bat`
* On Linux/Mac: `./gradlew`
* Command is hardcoded. No user-supplied shell input.


* Capture stdout + stderr (bounded to 100 KB)
* On exit code 0: locate APK at `<tempDir>/app/build/outputs/apk/debug/app-debug.apk`
* Copy APK to a persistent artifact location (e.g., `<appDocsDir>/nomad/builds/<projectId>-<timestamp>.apk`)
* Call `materializer.cleanup(tempDir)`
* Return `BuildResult`

Timeout: 5 minutes. `Process.run` supports a timeout parameter.
On timeout, kill the process and return `BuildStatus.timeout`.

Test (unit): Use a fake materializer that creates a known directory.
Mock `Process.run` to return success/failure. Verify `BuildResult`.

Test (e2e): One real build of the minimal template. Verify APK exists
and is a valid ZIP (APK is a ZIP file — check magic bytes PK).

### Step 6 — Integration Wiring

**Modified file:** `apps/nomad_mobile/lib/ui/projects_view.dart`
(or a new workspace screen, depending on existing navigation)

Add a "Build" action for Android projects that:

* Creates an `AndroidBuildService` with real repositories
* Calls `build(projectId)`
* Shows progress (simple loading indicator — no live log streaming in AL-0)
* On success: shows APK path and file size
* On failure: shows error message and truncated log

No changes to the web project workflow.

## 3. Files Changed Summary

| Action | File | Scope |
| --- | --- | --- |
| **NEW** | `lib/data/templates/android_template.dart` | Template strings |
| **NEW** | `lib/android_build/build_result.dart` | Data class |
| **NEW** | `lib/android_build/project_materializer.dart` | SQLite → disk |
| **NEW** | `lib/android_build/android_build_service.dart` | Build orchestration |
| **MODIFY** | `lib/ui/projects_view.dart` | Add android branch in `_createProject` |
| **NEW** | `test/data/templates/android_template_test.dart` | Template validation |
| **NEW** | `test/android_build/project_materializer_test.dart` | Materialization |
| **NEW** | `test/android_build/android_build_service_test.dart` | Build lifecycle |

## 4. What Is NOT Changed

* `packages/nomad_core/` — zero modifications
* `lib/server/` — zero modifications
* `lib/editor/` — zero modifications
* `lib/activity/` — zero modifications (deferred to future milestone)
* `lib/data/database/` — zero modifications
* `lib/data/repositories/` — zero modifications
* `lib/data/mappers/` — zero modifications
* `pubspec.yaml` — zero new dependencies

## 5. Acceptance Criteria (from brief §9)

* [ ] Minimal Kotlin/Compose project is reproducibly created
* [ ] Real build produces a valid APK (verified: ZIP magic bytes)
* [ ] APK is retrievable through the artifact workflow
* [ ] Success, failure, and timeout cases are handled
* [ ] Automated tests cover new logic and failure cases
* [ ] Existing WebLab workflows pass regression tests
* [ ] Resource and cost evidence is recorded
* [ ] Known limitations are disclosed

## 6. Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Gradle wrapper generation fails on host | Low | Fallback: bundle wrapper scripts as const strings |
| First build downloads dependencies (slow) | High | Document cold-build time; subsequent builds faster if Gradle cache exists |
| APK path differs across AGP versions | Low | Pin AGP 8.7.3; verify path in e2e test |
| SQLite materialization loses binary fidelity | Low | Minimal template is all text; ADR-0007 binary support exists if needed |
| Windows path length limits | Low | Temp dir names are short; project structure is minimal |

```