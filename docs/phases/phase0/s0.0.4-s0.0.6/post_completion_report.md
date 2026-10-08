# Post-Completion Report — Sprint Cluster S0.0.4 → S0.0.6
### Nomad — V0.0 Seed Milestone
**Author:** Junior Developer
**Reviewer:** Senior Developer
**Release Tag:** `v0.0.6`
**Date:** Sprint Cluster Completion
**Status:** ✅ Complete — All Definition of Done criteria satisfied

---

## 1. Executive Summary

Sprints S0.0.4, S0.0.5, and S0.0.6 collectively transformed Nomad from an application shell with persistent project metadata (the state at `v0.0.3`) into a **fully functional mobile-first development workspace**.

At the end of this cluster, Nomad can carry a real development project from creation to persistent editable source code, entirely from a lightweight phone or tablet surface. This completes the **V0.0 Seed milestone** as defined in the implementation brief.

The final deliverable supports this verified end-user flow:

```text
Launch Nomad
    → Create Project
    → Open Project
    → Create Folders & Files
    → Open a File
    → Edit Source Code
    → Save
    → Close Nomad
    → Reopen Nomad
    → Project + Workspace + File Contents Remain Intact
```

**Test coverage summary at `v0.0.6`:**

| Package | Tests | Status |
|---|---|---|
| `nomad_core` | 20 | ✅ All passing |
| `nomad_mobile` | 16 | ✅ All passing |
| **Total** | **36** | ✅ **100% green** |

Static analysis (`dart analyze` and `flutter analyze`) reports **zero issues** across both packages.

---

## 2. Scope Delivered

### 2.1 Sprint S0.0.4 — File Explorer & Virtual Workspace

**Objective:** Give every Project a workspace containing files and folders.

**Delivered capabilities:**
- Introduced `FileNode` and `FileNodeType` domain entities in `nomad_core`.
- Introduced `WorkspaceRepository` contract — a pure Dart boundary with six operations: `getNodesForProject`, `getNodeById`, `createNode`, `renameNode`, `deleteNode`, `deleteAllNodesForProject`.
- Extended `AppDatabase` schema to version `2` with a new `file_nodes` table and a backward-compatible `onUpgrade` migration path.
- Implemented `LocalWorkspaceRepository` with full CRUD semantics, folder-first alphabetical sort order, and recursive BFS folder deletion.
- Implemented `FileNodeMapper` following the existing `ProjectMapper` convention.
- Delivered `WorkspaceView` — a mobile-first file explorer with:
  - Breadcrumb path display
  - Folder drill-down and "go-up" navigation
  - Create file / create folder dialogs
  - Rename / delete actions via a per-row popup menu
- Wired `WorkspaceView` into `AppShell` and extended `ProjectsView` with project-open navigation and cascade cleanup of workspace metadata on project deletion.
- Captured the architectural decision in **ADR-0003 — Workspace and File Hierarchy Domain Model**.

### 2.2 Sprint S0.0.5 — Basic Editor

**Objective:** Make the files created in S0.0.4 editable.

**Delivered capabilities:**
- Introduced `FileContentRepository` contract in `nomad_core` with four operations: `readFile`, `writeFile`, `deleteContent`, `deleteAllContentForProject`.
- Implemented `LocalFileContentRepository` in `nomad_mobile` using `dart:io` and `path_provider`, storing content at:
  ```
  <app docs>/nomad_workspaces/<projectId>/<fileNodeId>.txt
  ```
- Delivered `EditorView` — a monospaced multi-line editor with:
  - Explicit load state and retry on failure
  - Dirty tracking indicator (`*` suffix on the title)
  - Save button that is only enabled when content differs from last-saved state
  - Keyboard shortcut support for `Ctrl + S` and `Cmd + S`
  - Distinct error handling for load failures (with retry) and save failures (via SnackBar)
- Wired `EditorView` into `AppShell` with proper selection flow from `WorkspaceView`.
- Captured the architectural decision in **ADR-0004 — File Content Persistence & Basic Editor Architecture**.

### 2.3 Sprint S0.0.6 — Responsive Foundation

**Objective:** Compose the capabilities of S0.0.4 and S0.0.5 into one coherent workspace that works across phone and tablet.

**Delivered capabilities:**
- **Phone layout (< 600 dp):** Sequential stack navigation — Projects → Workspace → Fullscreen Editor. The bottom navigation bar is hidden while a project is open, maximizing usable code space.
- **Tablet layout (≥ 600 dp):** Side-by-side IDE layout — 300 dp workspace sidebar on the left, multi-file tab bar + editor on the right.
- **Multi-file tab bar (tablet):** Opening a file opens a tab. Tabs can be switched without losing editor state. Closing a tab transfers focus to the nearest remaining tab or returns to the placeholder state.
- **Active file highlighting:** `WorkspaceView` highlights the currently open file node in the tree to maintain visual context across split layouts.
- Clean cleanup of open tabs when leaving a project.
- Captured the architectural decision in **ADR-0005 — Responsive Foundation & Multi-File Workspace Layout**.

---

## 3. Architectural Discipline Observed

The implementation strictly honored the non-negotiable rules in the brief:

| Rule | Enforcement |
|---|---|
| `nomad_core` remains pure Dart | ✅ Zero Flutter / SQLite / platform imports in any new core file |
| Existing contracts not replaced | ✅ `Project`, `ProjectType`, `EntityId`, `ProjectRepository`, and `NomadException` extended only |
| Metadata and content kept separate | ✅ SQLite holds metadata; filesystem holds source content |
| Project isolation enforced | ✅ Every workspace and content operation is scoped to `projectId` |
| ADR required for boundary changes | ✅ ADR-0003, ADR-0004, and ADR-0005 produced |
| Backward compatibility for persistence | ✅ `AppDatabase` version bumped to `2` with `onUpgrade` migration |

The repository history shows **13 atomic commits** across the three sprints, grouped by concern (`feat(core)`, `feat(storage)`, `feat(ui)`, `feat(editor)`, `test(...)`, `docs(...)`), rather than monolithic sprint-wide commits.

---

## 4. Problems Encountered & Mitigations

Several non-trivial problems surfaced during implementation. Each is documented below along with the mitigation applied.

### 4.1 PowerShell `$` Interpolation Corrupted SQL in `AppDatabase`

**Problem:** When writing `app_database.dart` using a PowerShell double-quoted here-string (`@" ... "@`), PowerShell interpolated `$tableProjects`, `$columnId`, etc., as empty strings. This produced catastrophically malformed SQL at runtime:

```
CREATE TABLE  (
   TEXT PRIMARY KEY,
   TEXT NOT NULL,
   ...
)
```

Every mobile test immediately failed with `SqliteException: near "(": syntax error`.

**Mitigation:** All PowerShell file emission that embeds Dart `$`-prefixed variables now uses **single-quoted here-strings** (`@' ... '@`), which treat the content as a literal with no interpolation. This instantly restored test pass rate and prevented a whole class of future paste-driven errors.

**Lesson learned:** When scripting file emission on Windows, single-quoted here-strings are the safe default for any file that contains `$` meaningful to Dart or SQL.

### 4.2 Unused Variable Warnings Produced by Premature Scaffolding

**Problem:** Two scaffolding variables (`placeholders`, `deletePlaceholders` in `LocalWorkspaceRepository`, and `fileId2` in a test) were introduced during initial drafting but never actually consumed. `flutter analyze` correctly flagged these as `unused_local_variable`.

**Mitigation:** The unused scaffolding was removed in a dedicated clean-up pass. Static analysis was then rerun and confirmed `No issues found!` before any commit was made.

**Lesson learned:** The "clean analyzer" bar is non-negotiable at commit time, even if tests pass. Static warnings are treated as blockers.

### 4.3 Recursive Folder Deletion Required a Non-Trivial Query Strategy

**Problem:** SQLite does not natively support recursive `DELETE ... CASCADE` across self-referential tables in sqflite without foreign key triggers and recursive CTEs. A naive "delete node by ID" would have left orphaned child rows pointing to a parent that no longer existed.

**Mitigation:** Implemented an **iterative breadth-first traversal** in `LocalWorkspaceRepository.deleteNode`:
1. Start with the target node ID as the frontier.
2. For each frontier generation, query all nodes whose `parent_id IN (frontier)`.
3. Add discovered child IDs to the deletion set and to the next frontier.
4. Repeat until frontier is empty.
5. Execute a single parameterized `DELETE ... WHERE id IN (...)` with the accumulated set.

This is covered explicitly by `test('recursive folder deletion cleans up all children nodes', ...)` in `local_workspace_repository_test.dart`.

**Lesson learned:** Even "simple" domain operations can hide non-trivial infrastructure concerns. The domain stayed clean because the recursion is implemented inside the infrastructure adapter, not inside `FileNode`.

### 4.4 Project Isolation Had to Be Defended at Every Layer

**Problem:** The brief explicitly requires that "a file from one project must never accidentally appear inside another project's workspace." Isolation can leak at the domain layer, the SQL layer, or the filesystem layer.

**Mitigation:** Isolation was enforced defensively at **three layers**:
1. **Domain:** `FileNode` requires `projectId` as a mandatory constructor argument.
2. **SQL:** Every `WorkspaceRepository` query that touches multiple nodes is filtered by `project_id = ?`.
3. **Filesystem:** `LocalFileContentRepository` physically scopes content under `nomad_workspaces/<projectId>/` so two files with the same `fileNodeId` across different projects can never collide.

A dedicated test, `test('enforces strict project isolation for file contents', ...)`, verifies that deleting all content for Project A leaves Project B's content completely intact.

**Lesson learned:** Isolation is a cross-cutting invariant and deserves tests that span layers, not just unit tests in one layer.

### 4.5 Widget Test Flakiness with Chained Async Database Calls

**Problem:** `flutter test` widget tests that chain multiple async SQLite operations (through `sqflite_common_ffi`) sometimes did not settle before `expect` ran, producing flaky "widget not found" failures.

**Mitigation:** The existing `settleDb(tester)` helper from S0.0.3 was retained and extended to cover the new workspace and editor flows. It alternates `tester.pump(...)` with `tester.runAsync(...)` across five iterations to allow the FFI isolate round-trips to fully resolve before the test proceeds.

**Lesson learned:** Mobile widget tests that cross the SQLite isolate boundary need explicit multi-cycle settling. The `settleDb` helper is now the standard tool for all such flows and should remain in place for future sprints.

### 4.6 Save Must Never Silently Succeed on Failure

**Problem:** A common bug in editor implementations is that the UI reports "Saved" purely because the save method didn't throw at the UI layer, even when the underlying `write` operation failed.

**Mitigation:**
- `LocalFileContentRepository.writeFile` wraps failures in `DomainException` with the original cause attached.
- `EditorView._saveContent` catches that exception explicitly and surfaces it via a red error-colored `SnackBar`, and critically **does not update `_initialContent`** on failure — so the dirty indicator (`*`) remains visible, truthfully reflecting that the user's edits are not persisted.
- Load failures are handled with equal explicitness: a clear error panel with a `Retry` button, not a silent empty editor.

**Lesson learned:** The brief's requirement that *"The UI should not falsely report 'Saved' when persistence failed"* was enforced in both directions — success state is only committed after persistence returns successfully.

### 4.7 Tab Closure Must Not Orphan the Active File

**Problem:** When a user closes the currently active tab, naively setting `_activeFileNode = null` leaves the editor pane blank even when other tabs are open — an unexpected and frustrating UX.

**Mitigation:** `_closeTab` was implemented to:
1. Remove the tab from `_openTabs`.
2. If the closed tab was active, promote the last remaining tab as the new active file.
3. Only when the list is empty does the editor revert to its placeholder state.

Covered by the S0.0.6 tablet E2E test which closes one of two open tabs and verifies the other becomes active.

**Lesson learned:** Multi-file UIs need deliberate focus-transfer logic. Section 33 of the brief explicitly called this out: *"Switching between files should be predictable and should not accidentally destroy user edits."*

### 4.8 PowerShell Script Execution Fragility

**Problem:** Several PowerShell blocks used for emitting large multi-line here-strings for documentation (`ARCHITECTURE.md`, ADRs) hit parser errors due to backtick (`` ` ``) interpretation inside double-quoted strings, numbered-list tokens being parsed as statements, and other shell idiosyncrasies.

**Mitigation:** All large documentation and code emissions were migrated to **single-quoted here-strings** or **line-by-line token-safe replacements**. For complex multi-section edits, the file was patched incrementally rather than regenerated in a single block. This made the pipeline resilient to Windows terminal quoting rules.

**Lesson learned:** When executing many file-writes via PowerShell, prefer small targeted edits over large regenerations. Each targeted edit is reviewable via `git diff` before commit.

---

## 5. Verification Evidence

### 5.1 Static Analysis

```
packages/nomad_core   → dart analyze    → No issues found!
apps/nomad_mobile     → flutter analyze → No issues found!
```

### 5.2 Test Suites

```
packages/nomad_core   → dart test       → 20/20 passed
apps/nomad_mobile     → flutter test    → 16/16 passed
```

### 5.3 Regression Guarantee

All tests introduced in S0.0.1, S0.0.2, and S0.0.3 continue to pass unchanged. The following previously-tagged capabilities are explicitly re-verified by the current widget test suite:

- Phone layout rendering at 390×844
- Tablet layout rendering at 1024×768
- End-to-end project creation and cold-restart persistence (originally shipped in `v0.0.3`)

### 5.4 Showcase Flow Verified

The end-to-end widget test `End-to-End S0.0.5: Phone flow - Open File -> Edit Code -> Save -> Restart App -> Code Persists` executes exactly the showcase flow described in Section 46 of the brief:

1. Create project `Web Lab Project`
2. Open project
3. Create `index.html`
4. Open `index.html`
5. Type a complete HTML snippet
6. Save
7. Close editor
8. Close workspace
9. **Cold restart `NomadApp`**
10. Reopen project
11. Reopen `index.html`
12. Assert the exact HTML snippet is still present

The equivalent tablet flow (`End-to-End S0.0.6: Tablet flow - Split-Pane Workspace with Multi-File Tabs & Editing`) covers multi-file editing across `index.html` and `style.css` with tab switching, independent saves, and tab closure.

---

## 6. Repository State at `v0.0.6`

### 6.1 Tags Published

```
v0.0.1  → S0.0.1  Foundation
v0.0.2  → S0.0.2  Project Domain
v0.0.3  → S0.0.3  Local Persistence
v0.0.4  → S0.0.4  Workspace & File Explorer
v0.0.5  → S0.0.5  Basic Editor
v0.0.6  → S0.0.6  Responsive Multi-File Workspace     ← V0.0 Seed complete
```

### 6.2 ADRs Published

```
ADR-0001  Application Boundaries & Monorepo Foundation
ADR-0002  Project Domain Persistence & SQLite Strategy
ADR-0003  Workspace and File Hierarchy Domain Model
ADR-0004  File Content Persistence & Basic Editor Architecture
ADR-0005  Responsive Foundation & Multi-File Workspace Layout
```

### 6.3 Key Modules Added

**`packages/nomad_core`:**
- `src/domain/file_node_type.dart`
- `src/domain/file_node.dart`
- `src/domain/workspace_repository.dart`
- `src/domain/file_content_repository.dart`

**`apps/nomad_mobile`:**
- `lib/data/mappers/file_node_mapper.dart`
- `lib/data/repositories/local_workspace_repository.dart`
- `lib/data/repositories/local_file_content_repository.dart`
- `lib/ui/workspace_view.dart`
- `lib/ui/editor_view.dart`
- Updated `lib/data/database/app_database.dart` (schema v2, migration)
- Updated `lib/app/app_shell.dart` (phone-stack + tablet-split-pane with tabs)
- Updated `lib/app/nomad_app.dart` (dependency injection for all three repositories)

---

## 7. What V0.0 Deliberately Does NOT Do

Per the brief, the following remain explicitly out of scope and are deferred to V0.1 (Web Lab) and beyond:

- Execution of HTML / CSS / JavaScript
- WebView preview or live reload
- Syntax highlighting, autocomplete, language servers
- Terminal, package manager, build system
- Git integration
- Cloud synchronization or multi-device collaboration
- AI assistance

This boundary was respected without exception. No preview WebView, no highlighter, no execution engine, no premature "universal" abstractions were introduced.

---

## 8. Readiness for V0.1 — Web Lab

The architecture positions V0.1 for a clean start:

- `FileContentRepository` already provides the exact read/write boundary a WebView preview will need to compose a running `index.html`.
- `FileNode` already carries enough metadata (`name`, `type`) for a file-extension-driven syntax highlighter to be introduced without domain changes.
- `EditorView` is isolated enough that adding a syntax-highlighted editor surface in S0.1.4 can be done as a drop-in replacement of its `TextField`, with no changes required at the shell or repository layers.
- The responsive shell already handles the tablet IDE-style side-by-side layout that will host both the editor and the WebView preview in S0.1.5.

In short: **V0.0 did not just ship a workspace. It shipped the correct seams for V0.1 to attach to.**

---

## 9. Request for Review

I am requesting formal review and acceptance of:

- Tag `v0.0.6` as the official **V0.0 Seed** release.
- ADR-0003, ADR-0004, and ADR-0005 as accepted architectural decisions of record.
- The sprint cluster S0.0.4 → S0.0.6 as complete per the Definition of Done items in Sections 43, 44, and 45 of the implementation brief.

All non-negotiable rules in Section 2 (Protect Existing Work), Section 36 (Architectural Change Protocol), Section 38 (Dependency Rules), and Section 50 (Golden Rule for the Developer) were honored throughout.

The repository is clean, pushed to `origin/main`, and ready for inspection.

— *End of Report —*