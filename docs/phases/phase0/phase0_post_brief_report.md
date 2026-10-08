---

# Nomad â€” Phase 0 Completion Report
## V0.0 Seed: S0.0.1 â†’ S0.0.6

**Phase:** 0 â€” Foundation & Seed Workspace
**Duration:** 6 Sprints (S0.0.1 through S0.0.6)
**Release Tag:** `v0.0`
**Status:** âœ… Complete

---

## 1. Phase 0 Objective

Phase 0 had a single, non-negotiable goal:

> **Prove that Nomad can carry a real development project from creation to persistent editable source code, entirely from a lightweight mobile/tablet workspace.**

It was not required to execute code, preview output, highlight syntax, or connect to any external service. It was required to establish the architectural foundation, domain model, persistence layer, workspace hierarchy, basic editor, and responsive layout â€” all with strict project isolation and zero data loss across application restarts.

---

## 2. Sprint-by-Sprint Summary

### S0.0.1 â€” Repository & Application Shell (`v0.0.1`)

**Delivered:**
- Monorepo structure with `apps/nomad_mobile` (Flutter) and `packages/nomad_core` (pure Dart).
- Responsive `AppShell` with adaptive phone (< 600 dp) and tablet (â‰¥ 600 dp) layouts.
- Phone layout: bottom `NavigationBar` with Lab and Projects destinations.
- Tablet layout: `NavigationRail` with side-by-side content area.
- CI pipeline (`.github/workflows/ci.yml`) running `dart analyze`, `dart test`, `flutter analyze`, `flutter test`.
- **ADR-0001:** Application Boundaries & Monorepo Foundation.

**Key constraint established:** `nomad_core` must never depend on Flutter, SQLite, or any platform API.

---

### S0.0.2 â€” Project Domain Model (`v0.0.2`)

**Delivered:**
- `EntityId` â€” lightweight immutable String wrapper with value equality.
- `ProjectType` enum â€” `web`, `android`.
- `Project` entity â€” immutable with `id`, `name`, `type`, `createdAt`, `updatedAt`, and `copyWith`.
- `ProjectRepository` â€” pure Dart abstract contract with `getAllProjects`, `getProjectById`, `saveProject`, `deleteProject`.
- `NomadException` hierarchy â€” `DomainException` and `ContractViolationException`.
- Domain invariants enforced in constructors (e.g., empty name rejection).
- **ADR-0002:** Project Domain Persistence & SQLite Strategy (prepared for S0.0.3).

**Key constraint established:** No raw strings for IDs. No duplicate Project models. `EntityId` is the single source of identity.

---

### S0.0.3 â€” Local Project Persistence (`v0.0.3`)

**Delivered:**
- `AppDatabase` â€” SQLite database via `sqflite` with `projects` table (schema version 1).
- `ProjectMapper` â€” bidirectional domain â†” database row transformation.
- `LocalProjectRepository` â€” full `ProjectRepository` implementation with injectable `dbProvider` for testability.
- `ProjectsView` â€” project list UI with create dialog (name + type dropdown) and delete action.
- Wired repository through `NomadApp` â†’ `AppShell` â†’ `ProjectsView`.
- End-to-end widget test proving project creation survives cold app restart.

**Key constraint established:** Repository implementations live in `nomad_mobile`, never in `nomad_core`. Dependency injection via constructor parameters enables in-memory SQLite testing with `sqflite_common_ffi`.

---

### S0.0.4 â€” File Explorer & Virtual Workspace (`v0.0.4`)

**Delivered:**
- `FileNodeType` enum â€” `file`, `folder`.
- `FileNode` entity â€” immutable with `id`, `projectId`, `parentId`, `name`, `type`, timestamps. Name validation rejects empty names and path separators.
- `WorkspaceRepository` contract â€” 6 operations: list, get, create, rename, delete, deleteAllForProject.
- `AppDatabase` schema bumped to version 2 with `file_nodes` table and `onUpgrade` migration.
- `FileNodeMapper` and `LocalWorkspaceRepository` with recursive BFS folder deletion.
- `WorkspaceView` â€” file explorer with breadcrumb navigation, folder drill-down, create/rename/delete dialogs.
- Project isolation enforced at domain, SQL, and filesystem layers.
- **ADR-0003:** Workspace and File Hierarchy Domain Model.

**Key constraint established:** `FileNode` carries metadata only. File content storage is a separate concern deferred to S0.0.5.

---

### S0.0.5 â€” Basic Editor (`v0.0.5`)

**Delivered:**
- `FileContentRepository` contract â€” `readFile`, `writeFile`, `deleteContent`, `deleteAllContentForProject`.
- `LocalFileContentRepository` â€” filesystem-based storage at `<app docs>/nomad_workspaces/<projectId>/<fileNodeId>.txt`.
- `EditorView` â€” monospaced multi-line editor with dirty tracking (`*`), save button, `Ctrl+S` / `Cmd+S` shortcut, load-failure retry, and save-failure SnackBar.
- Wired through `AppShell` with file selection flow from `WorkspaceView`.
- End-to-end widget test proving typed code survives cold app restart.
- **ADR-0004:** File Content Persistence & Basic Editor Architecture.

**Key constraint established:** Editor never touches SQLite. Content and metadata are physically separated (filesystem vs. database). Save UI only reports success after persistence actually completes.

---

### S0.0.6 â€” Responsive Foundation (`v0.0.6`)

**Delivered:**
- Phone layout refined: sequential stack (Projects â†’ Workspace â†’ Fullscreen Editor), bottom nav hidden during project editing.
- Tablet layout refined: 300 dp workspace sidebar + multi-file tab bar + editor pane.
- Multi-file tab system: open, switch, close tabs without losing editor state.
- Active file highlighting in workspace tree.
- Clean tab cleanup on project exit.
- End-to-end tablet widget test covering multi-file editing, tab switching, and tab closure.
- **ADR-0005:** Responsive Foundation & Multi-File Workspace Layout.

**Key constraint established:** Tab closure transfers focus to the nearest remaining tab, never orphans the active editor.

---

## 3. Architecture at Phase 0 Completion

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                        nomad_mobile                         â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”‚
â”‚  â”‚              Flutter UI / Presentation                â”‚  â”‚
â”‚  â”‚  AppShell Â· ProjectsView Â· WorkspaceView Â· EditorView â”‚  â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â”‚
â”‚                         â”‚                                    â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”‚
â”‚  â”‚              Infrastructure & Storage                 â”‚  â”‚
â”‚  â”‚  LocalProjectRepository â”€â”€â–º SQLite (projects)         â”‚  â”‚
â”‚  â”‚  LocalWorkspaceRepository â”€â”€â–º SQLite (file_nodes)     â”‚  â”‚
â”‚  â”‚  LocalFileContentRepository â”€â”€â–º Filesystem            â”‚  â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                          â”‚
                          â–¼  (Pure Dart Contracts)
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                        nomad_core                           â”‚
â”‚  Entities:     Project Â· FileNode Â· ProjectType Â· FileNodeTypeâ”‚
â”‚  Contracts:    ProjectRepository Â· WorkspaceRepository       â”‚
â”‚                FileContentRepository                         â”‚
â”‚  Identity:     EntityId                                      â”‚
â”‚  Errors:       NomadException Â· DomainException              â”‚
â”‚                ContractViolationException                    â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

## 4. Final Metrics

| Metric | Value |
|---|---|
| Total sprints | 6 |
| Release tags | `v0.0.1` through `v0.0.6`, plus `v0.0` |
| ADRs published | 5 (ADR-0001 through ADR-0005) |
| Core domain tests | 20 |
| Mobile integration tests | 16 |
| Total tests | **36 â€” all passing** |
| Static analysis issues | **0** |
| New domain entities | 3 (`FileNode`, `FileNodeType`, `FileContentRepository`) |
| New repository contracts | 2 (`WorkspaceRepository`, `FileContentRepository`) |
| New infrastructure implementations | 3 (`LocalWorkspaceRepository`, `LocalFileContentRepository`, `FileNodeMapper`) |
| New UI screens | 2 (`WorkspaceView`, `EditorView`) |
| Database schema versions | 2 |

---

## 5. Key Problems & Mitigations (Phase-Wide)

| # | Problem | Mitigation |
|---|---|---|
| 1 | PowerShell `$` interpolation corrupted SQL during scripted file emission | Migrated all file emission to single-quoted here-strings (`@' ... '@`) |
| 2 | Recursive folder deletion has no native SQLite CASCADE in sqflite | Implemented iterative BFS traversal in `LocalWorkspaceRepository.deleteNode` |
| 3 | Project isolation could leak across domain, SQL, or filesystem layers | Enforced `projectId` scoping at all three layers with dedicated cross-layer tests |
| 4 | Widget tests flaky due to async SQLite FFI isolate round-trips | Standardized `settleDb(tester)` multi-cycle pump helper across all E2E tests |
| 5 | Save UI could falsely report success on persistence failure | `EditorView` only updates clean state after `writeFile` returns successfully; failures show red SnackBar and preserve dirty indicator |
| 6 | Tab closure could orphan the active editor | `_closeTab` promotes the last remaining tab before falling back to placeholder |
| 7 | Large documentation patches failed due to PowerShell backtick and token parsing | Migrated to incremental line-by-line replacements and single-quoted strings |

---

## 6. What V0.0 Deliberately Does NOT Include

The following capabilities were explicitly deferred and remain absent from the codebase:

- Code execution (HTML/CSS/JS, Python, Android)
- WebView preview or live reload
- Syntax highlighting or autocomplete
- Terminal or package manager
- Git integration
- Cloud synchronization or collaboration
- AI assistance
- Runner infrastructure (local PC or cloud)

No premature abstractions were created for these future capabilities. The architecture provides clean attachment points (contracts, repository boundaries, UI composition slots) without speculative scaffolding.

---

## 7. Readiness for Phase 2 (V0.1 â€” Web Lab)

Phase 0 established the exact seams Phase 2 will build on:

| Phase 2 Need | Phase 0 Foundation |
|---|---|
| Read file content for WebView | `FileContentRepository.readFile` already provides this |
| Syntax highlighting | `FileNode.name` carries extension; `EditorView` can swap its `TextField` for a highlighted surface |
| Live preview | Tablet split-pane layout already has a right-side slot that can host a WebView alongside the editor |
| Templates | `WorkspaceRepository.createNode` + `FileContentRepository.writeFile` can seed template files on project creation |
| File watching / live reload | `FileContentRepository` is the single write boundary; a watcher can be attached without touching the editor |

---

## 8. Conclusion

Phase 0 delivered exactly what the V0.0 Seed definition required: a mobile-first workspace that can create a project, build a file hierarchy, edit source code, save it, and survive application restarts with all data intact â€” on both phones and tablets.

The architecture is clean, the contracts are stable, the tests are green, and the repository history is atomic and reviewable.

**Phase 0 is complete. Nomad V0.0 is ready for Phase 2.**

---

*End of Phase 0 Completion Report*
