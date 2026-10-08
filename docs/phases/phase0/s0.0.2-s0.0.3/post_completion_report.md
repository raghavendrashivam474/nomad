Here is the formal post-sprint report. You can save this directly to `docs/phases/phase0/S0.0.2-S0.0.3-sprint-report.md`.

---

# Nomad Sprint Report â€” S0.0.2 + S0.0.3

**Date:** 2025-07-10
**Sprints:** S0.0.2 (Project Model) â†’ S0.0.3 (Local Storage)
**Baseline:** `v0.0.1` (commit `51fde2a`)
**Branch:** `main`
**Status:** âœ… Complete

---

## 1. Executive Summary

Over two consecutive sprints, Nomad gained its first real domain entity (`Project`) and a fully functional local persistence layer backed by SQLite. At the end of S0.0.3, the application can create a project, close, reopen, and find the project still present â€” the exact acceptance criterion defined in the implementation brief.

All existing S0.0.1 architecture, tests, and boundaries remain intact. No Flutter dependencies were introduced into `nomad_core`. No destructive refactoring was performed on any existing code.

---

## 2. S0.0.2 â€” Project Domain Model

### 2.1 What Was Implemented

| Artifact | Location | Purpose |
|---|---|---|
| `Project` entity | `packages/nomad_core/lib/src/domain/project.dart` | Immutable domain model with `id`, `name`, `type`, `createdAt`, `updatedAt` |
| `ProjectType` enum | `packages/nomad_core/lib/src/domain/project_type.dart` | `web` and `android` project type distinction |
| `ProjectRepository` contract | `packages/nomad_core/lib/src/domain/project_repository.dart` | Abstract persistence boundary (`getAllProjects`, `getProjectById`, `saveProject`, `deleteProject`) |
| Project unit tests | `packages/nomad_core/test/project_test.dart` | Creation, invariants, empty-name rejection, `copyWith` immutability |
| Updated barrel export | `packages/nomad_core/lib/nomad_core.dart` | Exports new domain types |

### 2.2 Design Decisions

- **`EntityId` reuse:** The `Project` entity uses the existing `EntityId` value object from S0.0.1 rather than introducing a raw `String id`. This was a hard requirement of the brief and ensures identifier consistency across all future entities.

- **Immutability via `copyWith`:** The `Project` class exposes no public setters. Mutation is performed through `copyWith()`, which returns a new `Project` instance with the specified fields replaced. The `id` and `createdAt` fields are deliberately excluded from `copyWith` to prevent identity and provenance corruption.

- **Invariant enforcement in constructor:** An empty or whitespace-only project name throws `ContractViolationException` at construction time. This keeps invalid state out of the domain entirely rather than deferring validation to the persistence or UI layer.

- **`ProjectRepository` as abstract class:** Defined in pure Dart inside `nomad_core` with four methods (`getAllProjects`, `getProjectById`, `saveProject`, `deleteProject`). This establishes the dependency inversion boundary that S0.0.3 implements against.

### 2.3 Problems Encountered

| # | Problem | Severity | Resolution |
|---|---|---|---|
| 1 | `prefer_const_constructors` lint on `EntityId('project-1')` in test file | Low | Added `const` keyword to the constructor invocation. Single-line fix. |

### 2.4 Verification

```
dart analyze  â†’ 0 issues
dart test     â†’ 7/7 passed (4 existing + 3 new)
```

---

## 3. S0.0.3 â€” Local Storage

### 3.1 What Was Implemented

| Artifact | Location | Purpose |
|---|---|---|
| `AppDatabase` | `apps/nomad_mobile/lib/data/database/app_database.dart` | SQLite database initialization, schema creation, singleton access |
| `ProjectMapper` | `apps/nomad_mobile/lib/data/mappers/project_mapper.dart` | Bidirectional mapping between `Project` domain entity and SQLite row `Map<String, dynamic>` |
| `LocalProjectRepository` | `apps/nomad_mobile/lib/data/repositories/local_project_repository.dart` | Concrete implementation of `ProjectRepository` using `sqflite` |
| Repository integration tests | `apps/nomad_mobile/test/data/local_project_repository_test.dart` | Full CRUD lifecycle against in-memory SQLite via `sqflite_common_ffi` |
| `ProjectsView` widget | `apps/nomad_mobile/lib/ui/projects_view.dart` | Minimal project list + creation dialog (scoped to brief Section 21) |
| Updated `AppShell` | `apps/nomad_mobile/lib/app/app_shell.dart` | Integrated `ProjectsView` into phone/tablet navigation with `ProjectRepository` injection |
| Updated `NomadApp` | `apps/nomad_mobile/lib/app/nomad_app.dart` | Accepts optional `ProjectRepository` for test injection; defaults to `LocalProjectRepository` |
| Updated widget tests | `apps/nomad_mobile/test/widget_test.dart` | Phone layout, tablet layout, and end-to-end persistence restart test |
| ADR-0002 | `docs/adr/ADR-0002-project-persistence.md` | Documents persistence architecture decisions |
| Updated `ARCHITECTURE.md` | `docs/ARCHITECTURE.md` | Updated Section 2.5 diagram and Section 5 roadmap |
| Updated `pubspec.yaml` | `apps/nomad_mobile/pubspec.yaml` | Added `sqflite`, `path`, `path_provider`, `uuid`, `sqflite_common_ffi` |

### 3.2 Database Schema

```sql
CREATE TABLE projects (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    type       TEXT NOT NULL,
    created_at TEXT NOT NULL,   -- ISO-8601
    updated_at TEXT NOT NULL    -- ISO-8601
);
```

No additional columns were added. This matches the brief's explicit instruction to keep the schema minimal.

### 3.3 Architecture Compliance

```
nomad_core (pure Dart)
  â””â”€â”€ ProjectRepository (abstract contract)
        â–²
        â”‚ implements
        â”‚
nomad_mobile (Flutter + sqflite)
  â””â”€â”€ LocalProjectRepository
        â””â”€â”€ ProjectMapper
              â””â”€â”€ AppDatabase (SQLite)
```

- `nomad_core` has **zero** knowledge of SQLite, Drift, or Flutter.
- `LocalProjectRepository` accepts a `dbProvider` function, enabling in-memory database injection during tests without any code changes to the repository itself.
- `ProjectMapper` is a pure transformation layer. The `Project` domain entity contains no serialization logic.

### 3.4 Problems Encountered

| # | Problem | Severity | Root Cause | Resolution |
|---|---|---|---|---|
| 1 | **SQL CREATE TABLE with empty column names** â€” `CREATE TABLE ( TEXT PRIMARY KEY, TEXT NOT NULL, ... )` | **Critical** | PowerShell double-quoted here-strings (`@" ... "@`) interpolated Dart's `$tableProjects`, `$columnId`, etc. as PowerShell variables (which were `$null`), stripping them from the generated Dart source. | Switched all Dart code generation to single-quoted here-strings (`@' ... '@`) which prevent PowerShell variable interpolation. |
| 2 | **`pumpAndSettle()` timeout** in widget tests | **High** | `ProjectsView` shows a `CircularProgressIndicator` during async DB loading. `pumpAndSettle()` waits for all animations to stop, but `CircularProgressIndicator` is an infinite animation that never settles. | Replaced `pumpAndSettle()` with a custom `settleDb()` helper that performs multiple `pump(duration)` + `tester.runAsync()` cycles to let background isolate DB operations complete without waiting on infinite animations. |
| 3 | **Background isolate timing** â€” DB queries returning empty results in tests | **High** | `sqflite_common_ffi` executes queries on a background isolate. Flutter's `WidgetTester.pump()` only advances the widget frame clock; it does not yield to the real Dart event loop where isolate messages are processed. | Added `tester.runAsync(() async { await Future.delayed(...) })` inside the `settleDb()` loop. This yields to the real event loop, allowing the FFI isolate to return query results before the next frame is pumped. |
| 4 | **Widget state preserved across simulated restart** | **Medium** | Re-pumping `NomadApp(repository: repository)` in a widget test does not destroy existing widget state because Flutter's reconciliation algorithm preserves stateful widgets of the same type and key. The `_selectedIndex` remained at `1` (Projects), so the "Get Started" button was not in the tree. | Added `key: UniqueKey()` to the restarted `NomadApp` instance, forcing Flutter to treat it as an entirely new widget tree â€” simulating a true cold restart where all state is rebuilt from the persistent database. |
| 5 | **RenderFlex overflow in dialog** â€” `DropdownButtonFormField` overflowed by 8.3px | **Medium** | The `DropdownButtonFormField` inside `AlertDialog` exceeded the available horizontal width on the 390px test viewport. | Added `isExpanded: true` to `DropdownButtonFormField` and wrapped the dialog content in `SizedBox(width: 320)`. |
| 6 | **Flutter deprecation lint** â€” `value` parameter on `DropdownButtonFormField` | **Low** | Flutter 3.33+ deprecated `value` in favor of `initialValue` on form fields. | Added `// ignore: deprecated_member_use` comment. This maintains compatibility across Flutter versions without forcing a minimum SDK bump. |
| 7 | **Dart syntax typo** â€” `.toList>` instead of `.toList()` | **Low** | Manual transcription error during code generation. | Caught immediately by `flutter analyze`. Fixed to `.toList()`. |

### 3.5 Verification

```
dart analyze (nomad_core)     â†’ 0 issues
dart test (nomad_core)        â†’ 7/7 passed

flutter analyze (nomad_mobile) â†’ 0 issues
flutter test (nomad_mobile)    â†’ 5/5 passed
  â”œâ”€â”€ Phone layout rendering
  â”œâ”€â”€ Tablet layout rendering
  â”œâ”€â”€ Repository CRUD lifecycle (in-memory SQLite)
  â”œâ”€â”€ Repository null-return for missing ID
  â””â”€â”€ End-to-End: Create â†’ Restart â†’ Persist âœ…
```

---

## 4. What Was Explicitly NOT Done (Per Brief)

The following were deliberately excluded per the sprint contract:

- âŒ Editor, file explorer, WebView, runner
- âŒ Cloud backend, authentication, sync
- âŒ Android build system or development environment
- âŒ Project description, owner, cloud ID, repository URL, sync status fields
- âŒ Drift ORM (raw `sqflite` used per current roadmap)
- âŒ Dedicated infrastructure package (not yet justified; documented in ADR-0002)
- âŒ Refactoring of any S0.0.1 code

---

## 5. Key Lessons for Future Sprints

1. **PowerShell code generation requires single-quoted here-strings (`@' ... '@`)** when the target language uses `$` for its own interpolation (Dart, Kotlin, Swift, etc.). Double-quoted here-strings silently corrupt source code.

2. **`pumpAndSettle()` is incompatible with infinite animations** (`CircularProgressIndicator`, `LinearProgressIndicator`). Widget tests involving loading states should use explicit `pump(duration)` sequences.

3. **`sqflite_common_ffi` requires `tester.runAsync()`** in Flutter widget tests. The FFI isolate operates outside Flutter's fake async zone, so `pump()` alone cannot advance its operations.

4. **`UniqueKey()` is essential for simulating cold restarts** in widget tests. Without it, Flutter's reconciliation preserves stateful widget state across `pumpWidget()` calls, masking persistence bugs.

5. **Repository injection via constructor** (`dbProvider` function) made the entire persistence layer testable without mocking frameworks. This pattern should be replicated for all future infrastructure dependencies.

---

## 6. Next Steps (S0.0.4)

The foundation is now in place for **File Explorer & Virtual Workspace**. The `Project` entity and `ProjectRepository` provide the anchor point that the file explorer will attach to. Recommended starting point:

- Define `Workspace` and `FileNode` domain entities in `nomad_core`
- Establish `WorkspaceContract` per the architecture's contract-driven design principle
- Implement virtual filesystem scoped to individual projects

---

**Report prepared by:** Junior Developer (Sprint Execution)
**Reviewed against:** Nomad Implementation Brief V0.0 Seed â€” S0.0.2 + S0.0.3
**Architecture compliance:** ADR-0001 âœ… | ADR-0002 âœ…
