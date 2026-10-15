# S-T0 — Lightweight Terminal Feasibility & Architecture Audit

**Project:** Nomad — Mobile-First Development Lab
**Phase:** NT-1 — Nomad Terminal: Project Shell
**Sprint:** S-T0
**Repository:** https://github.com/raghavendrashivam474/nomad.git
**Branch:** main @ 85c3e78 (tag: v-LC-3)
**Date:** 2026-10-15
**Status:** COMPLETE — Ready for review

---

## 1. Executive Recommendation

### ✅ PROCEED — with restrictions

The Nomad codebase already provides every capability required for a V1 project-aware terminal. The virtual filesystem (SQLite tree + on-disk content), path-safety resolver, and workspace CRUD operations can be reused directly. No new dependencies, no schema changes, and no modifications to existing contracts are required.

**Restrictions:**
- V1 must operate exclusively through existing WorkspaceRepository, FileContentRepository, and ProjectFileResolver contracts.
- No real OS shell execution, no process spawning, no network access.
- Command output must be bounded (max 10,000 characters per command).
- Recursive operations (`tree`, `find`, `rm`) must enforce depth/count limits.
- The terminal must not modify the preview server, editor, activity panel, or connectivity subsystems.

---

## 2. Repository State & Inspection Scope

| Property | Value |
|----------|-------|
| Branch | main |
| HEAD | 85c3e78 |
| Tag | v-LC-3 |
| Working tree | Clean |
| Last commit | feat(lc3): implement background/foreground WebRTC connection recovery |

**Inspected locations:**
- `docs/adr/` — 10 ADRs (ADR-0001 through ADR-0010)
- `apps/nomad_mobile/lib/` — 29 Dart source files
- `apps/nomad_mobile/test/` — 24 test files (4,000+ lines)
- `packages/nomad_core/lib/` — 7 domain contracts + 2 utility classes
- `packages/nomad_core/test/` — 3 test files (306 lines)
- `apps/nomad_mobile/pubspec.yaml` and `packages/nomad_core/pubspec.yaml`

---

## 3. Capability Reuse Map

### Storage Architecture (Critical Finding)

Nomad uses a **virtual filesystem** — the file tree is stored in SQLite, not on the real filesystem:

| Layer | Storage | Location |
|-------|---------|----------|
| Tree structure | SQLite `file_nodes` table | `AppDatabase` (L47-72) |
| File content | Real files at `{appDocs}/nomad_workspaces/{projectId}/{nodeId}.txt` | `LocalFileContentRepository._getFile()` (L13-21) |
| Path resolution | In-memory tree walk against DB nodes | `ProjectFileResolver.resolve()` (L46-150) |

### Reuse Matrix

| Capability | Source | Contract | Reuse Decision | Risk |
|-----------|--------|----------|---------------|------|
| List files in folder | `LocalWorkspaceRepository.getNodesForProject()` | `WorkspaceRepository` | **REUSE** | None — read-only query |
| Get node by ID | `LocalWorkspaceRepository.getNodeById()` | `WorkspaceRepository` | **REUSE** | None |
| Create file/folder | `LocalWorkspaceRepository.createNode()` | `WorkspaceRepository` | **REUSE** | None — name validation in `FileNode` constructor |
| Rename | `LocalWorkspaceRepository.renameNode()` | `WorkspaceRepository` | **REUSE** | None — blocks `/` and `\` in names |
| Move | `LocalWorkspaceRepository.moveNode()` | `WorkspaceRepository` | **REUSE** | None — has cycle detection + collision checks |
| Delete (recursive) | `LocalWorkspaceRepository.deleteNode()` | `WorkspaceRepository` | **REUSE** | Low — already cascades to children |
| Read file content | `LocalFileContentRepository.readFile()` | `FileContentRepository` | **REUSE** | None |
| Read file bytes | `LocalFileContentRepository.readFileBytes()` | `FileContentRepository` | **REUSE** | None — binary-safe per ADR-0007 |
| Write file content | `LocalFileContentRepository.writeFile()` | `FileContentRepository` | **REUSE** | None |
| Delete file content | `LocalFileContentRepository.deleteContent()` | `FileContentRepository` | **REUSE** | None |
| Path resolution + safety | `ProjectFileResolver.resolve()` | Own class | **REUSE** | None — blocks `..`, `.`, absolute paths, backslashes |
| Project lookup | `LocalProjectRepository.getProjectById()` | `ProjectRepository` | **REUSE** | None |
| Activity events | `ActivityController.createEvent()` | `ChangeNotifier` | **OPTIONAL** | None — could log terminal errors to activity panel |
| Nav slot | `AppShell` L429-433 (phone), L569-572 (tablet) | Widget tree | **REUSE** | None — "Lab" tab with terminal icon already exists |

### What Does NOT Need to Be Built

- ❌ No new filesystem abstraction
- ❌ No new database tables or schema migration
- ❌ No new path-safety layer
- ❌ No new project isolation mechanism
- ❌ No new dependencies in either pubspec

---

## 4. Proposed Minimum Terminal Architecture

### Logical Flow

```text
TerminalView (UI)
└── TerminalController (state: CWD, history, output buffer)
└── CommandDispatcher (parse + route)
└── Command implementations (one per command)
└── Existing Nomad contracts (WorkspaceRepository, FileContentRepository, ProjectFileResolver)
```

### Minimum New Components

| Component | Responsibility | Location (proposed) |
|-----------|---------------|-------------------|
| `TerminalView` | Text input/output widget, scrollback | `lib/ui/terminal_view.dart` (NEW) |
| `TerminalController` | CWD tracking, output buffer, history | `lib/terminal/terminal_controller.dart` (NEW) |
| `CommandDispatcher` | Tokenize input, match command name, dispatch | `lib/terminal/command_dispatcher.dart` (NEW) |
| Command implementations | One class/function per command | `lib/terminal/commands/*.dart` (NEW) |
| `AppShell` integration | Wire terminal into existing "Lab" nav tab | `lib/app/app_shell.dart` (MODIFY — minimal) |

### What This Is NOT

- Not a plugin system
- Not a process supervisor
- Not a shell compatibility layer
- Not an execution framework for future runtimes
- Not a new package — all code lives in `nomad_mobile`

---

## 5. Initial Command Feasibility Matrix

| Command | Feasible? | Implementation Strategy | Dependencies | S-T1? |
|---------|-----------|----------------------|-------------|-------|
| `help` | ✅ Yes | Static text output | None | **Yes** |
| `clear` | ✅ Yes | Clear output buffer | None | **Yes** |
| `pwd` | ✅ Yes | Return tracked CWD path | TerminalController state | **Yes** |
| `ls` | ✅ Yes | `getNodesForProject()` → filter by `parentId` | WorkspaceRepository | **Yes** |
| `cd <dir>` | ✅ Yes | Resolve target via tree walk, validate is folder | WorkspaceRepository | **Yes** |
| `tree` | ✅ Yes | `getNodesForProject()` → recursive display | WorkspaceRepository | **Yes** |
| `mkdir <name>` | ✅ Yes | `createNode(FileNode(type: folder))` | WorkspaceRepository | **Yes** |
| `touch <name>` | ✅ Yes | `createNode(FileNode(type: file))` + `writeFile('')` | WorkspaceRepository + FileContentRepository | **Yes** |
| `cat <file>` | ✅ Yes | `ProjectFileResolver.resolve()` or `readFile()` | FileContentRepository | **Yes** |
| `cp <src> <dst>` | ⚠️ Compose | Read source → create dest node → write content | WorkspaceRepository + FileContentRepository | **Defer to S-T2** |
| `mv <src> <dst>` | ✅ Yes | `moveNode()` + `renameNode()` | WorkspaceRepository | **Defer to S-T2** |
| `rm <target>` | ✅ Yes | `deleteNode()` + `deleteContent()` | WorkspaceRepository + FileContentRepository | **Defer to S-T2** |
| `find <pattern>` | ⚠️ Compose | `getNodesForProject()` → filter by name glob | WorkspaceRepository | **Defer to S-T3** |
| `grep <pattern> <file>` | ⚠️ Compose | `readFile()` → line-by-line regex | FileContentRepository | **Defer to S-T3** |
| `wc <file>` | ⚠️ Compose | `readFile()` → count lines/words/chars | FileContentRepository | **Defer to S-T3** |

### Recommended S-T1 Command Set (9 commands)

`help`, `clear`, `pwd`, `ls`, `cd`, `tree`, `mkdir`, `touch`, `cat`

### V1 Syntax (Deliberately Limited)

- Single space-separated tokens: `command [arg1] [arg2]`
- No pipes, no redirection, no globbing, no quoting, no environment variables
- No `&&`, `||`, `;` chaining
- Paths use forward slashes only: `cd assets/images`
- Paths are relative to the current virtual working directory
- No absolute paths (no leading `/`)
- No `..` or `.` traversal (enforced by `ProjectFileResolver`)

---

## 6. Filesystem Safety & Error Handling

### Existing Protections (Reuse)

| Protection | Source | Status |
|-----------|--------|--------|
| Path traversal blocked (`..`, `.`) | `ProjectFileResolver` L74-78 | ✅ Active |
| Absolute paths rejected | `ProjectFileResolver` L58-64 | ✅ Active |
| Backslash paths rejected | `ProjectFileResolver` L58-64 | ✅ Active |
| Cross-project access blocked | `ProjectFileResolver` L87-93 | ✅ Active |
| Name validation (no `/`, `\`, empty) | `FileNode` constructor + `renameNode()` L50-53 | ✅ Active |
| Move cycle prevention | `LocalWorkspaceRepository.moveNode()` L102-113 | ✅ Active |
| Move collision detection | `LocalWorkspaceRepository.moveNode()` L117-131 | ✅ Active |
| Recursive delete | `LocalWorkspaceRepository.deleteNode()` L148-176 | ✅ Active |

### New Safeguards Required for Terminal

| Safeguard | Implementation | Priority |
|-----------|---------------|----------|
| Output size limit | Cap command output at 10,000 chars; truncate with `... [truncated]` | **Must** |
| Tree depth limit | `tree` command: max 5 levels deep | **Must** |
| `cat` size limit | Refuse to display files > 100 KB; show byte count instead | **Must** |
| No-project guard | All commands except `help`/`clear` require an active project | **Must** |
| Error messages | Catch `DomainException`/`ContractViolationException`, display `message` field | **Must** |
| Async execution | All command execution on `compute()` or `Future.microtask()` to avoid UI jank | **Should** |
| Destructive confirmation | `rm` (when implemented in S-T2) must require `--force` flag | **Should** |

---

## 7. Performance & Footprint Baseline

| Metric | Value | Source |
|--------|-------|--------|
| nomad_core dependencies | **Zero** (pure Dart) | `packages/nomad_core/pubspec.yaml` |
| nomad_mobile dependencies | flutter, sqflite, path, path_provider, uuid, webview_flutter | `apps/nomad_mobile/pubspec.yaml` |
| New dependencies for terminal | **Zero** | Analysis |
| New database tables | **Zero** | Analysis |
| Source files in lib/ | 29 | Block 2 scan |
| Estimated new files for S-T1 | 4–6 | Architecture proposal |
| APK size baseline | **NOT MEASURED** — requires `flutter build apk --debug` | Gap |
| Memory baseline | **NOT MEASURED** — requires device profiling | Gap |
| Command latency target | < 50ms for `ls`, `pwd`; < 200ms for `tree`, `cat` | Estimate |

### Measurement Gaps

- APK size and memory footprint should be measured before and after S-T1 on a physical Android device.
- Command latency should be measured after implementation using `Stopwatch` in the dispatcher.
- These gaps do not block S-T1 but should be addressed in S-T2.

---

## 8. Regression Risks & Existing Tests

### Tests That Must Remain Green

| Test File | Lines | Protects |
|-----------|-------|----------|
| `test/data/local_workspace_repository_test.dart` | 428 | File tree CRUD — terminal's primary data source |
| `test/server/project_file_resolver_test.dart` | 277 | Path safety — terminal must not weaken this |
| `test/data/local_file_content_repository_test.dart` | 122 | File I/O — terminal reads/writes through this |
| `test/server/project_file_server_test.dart` | 347 | Preview server — terminal must not interfere |
| `test/activity/activity_controller_test.dart` | 220 | Activity events — terminal may integrate here |
| `test/widget_test.dart` | 302 | App shell integration — nav changes must not break |
| `packages/nomad_core/test/file_node_test.dart` | 212 | Domain invariants — name validation, equality |

### New Tests Required for S-T1

- `test/terminal/command_dispatcher_test.dart` — parsing, routing, unknown commands
- `test/terminal/commands/ls_test.dart` — listing with various tree structures
- `test/terminal/commands/cd_test.dart` — navigation, invalid targets, path traversal
- `test/terminal/commands/cat_test.dart` — content display, size limits, binary files
- All testable without UI (pure Dart command logic against mock repositories)

---

## 9. Exact Files Expected to Change in S-T1

### New Files (4–6)

| File | Purpose |
|------|---------|
| `lib/ui/terminal_view.dart` | Terminal UI widget (input field + scrollable output) |
| `lib/terminal/terminal_controller.dart` | CWD state, output buffer, command history |
| `lib/terminal/command_dispatcher.dart` | Tokenizer + command router |
| `lib/terminal/commands/builtin_commands.dart` | help, clear, pwd, ls, cd, tree, mkdir, touch, cat |
| `test/terminal/command_dispatcher_test.dart` | Dispatcher unit tests |
| `test/terminal/commands/builtin_commands_test.dart` | Command unit tests |

### Modified Files (1)

| File | Change | Risk |
|------|--------|------|
| `lib/app/app_shell.dart` | Replace placeholder "Lab" tab body with `TerminalView` when selected | **Low** — the nav slot and icon already exist (L429-433, L569-572); only the body widget changes |

### Files That Will NOT Change

- `packages/nomad_core/` — zero modifications
- `lib/data/` — zero modifications
- `lib/server/` — zero modifications
- `lib/activity/` — zero modifications
- `lib/editor/` — zero modifications
- `lib/ui/workspace_view.dart` — zero modifications
- `lib/ui/web_preview_view.dart` — zero modifications
- `pubspec.yaml` (both) — zero modifications

---

## 10. Proposed Terminal Command Contract

### Input

<command> [arg1] [arg2] ...

- Lowercase command names only
- Arguments separated by single spaces
- No quoting, no escaping, no pipes, no redirection
- Empty input is a no-op (returns new prompt)

### Output

- Plain text, monospace font
- Each command produces zero or more lines of output
- Output is appended to a scrollable buffer (max 500 lines retained)
- Errors are prefixed with `Error: ` and displayed in the same buffer

### Error Handling

| Error Type | Display |
|-----------|---------|
| Unknown command | `Error: Unknown command '<name>'. Type 'help' for available commands.` |
| Missing argument | `Error: Usage: <command> <args>` |
| File not found | `Error: No such file or directory: '<path>'` |
| Not a directory | `Error: Not a directory: '<name>'` |
| Not a file | `Error: Not a file: '<name>'` |
| Permission/safety | `Error: Operation not permitted: <reason>` |
| No active project | `Error: No project selected. Open a project first.` |
| Output too large | `[Output truncated: <N> characters omitted]` |

### Explicitly Unsupported in V1

- Shell pipes (`|`), redirection (`>`, `<`)
- Command chaining (`&&`, `||`, `;`)
- Environment variables (``)
- Globbing (`*.html`)
- Quoting (`"file name.txt"`)
- Background execution (`&`)
- Any real OS process execution
- Network access
- Cross-project file access
- Absolute filesystem paths

---

## 11. Architecture Decisions Requiring Review

### No New ADR Required

The terminal reuses existing architecture without introducing new structural decisions. The existing ADRs (0002, 0003, 0004, 0007) already cover the storage, isolation, and content models that the terminal operates within.

### Proposed ADR (Optional, for S-T2+)

If the terminal evolves to support destructive operations (`rm`, `mv`) or execution backends, a new ADR should be drafted covering:
- Command safety classification (read-only vs. mutating vs. destructive)
- Undo/redo capability for destructive commands
- Execution isolation boundaries for future runtime integration

This is **not required for S-T1**.

---

## 12. S-T1 Implementation Plan & Acceptance Criteria

### Implementation Order

| Step | Task | Estimated Time |
|------|------|---------------|
| 1 | Create `TerminalController` with CWD state and output buffer | 30 min |
| 2 | Create `CommandDispatcher` with tokenizer and routing | 30 min |
| 3 | Implement `help`, `clear`, `pwd` (zero-dependency commands) | 20 min |
| 4 | Implement `ls`, `cd` (tree navigation commands) | 40 min |
| 5 | Implement `tree` (recursive display with depth limit) | 20 min |
| 6 | Implement `mkdir`, `touch` (creation commands) | 20 min |
| 7 | Implement `cat` (content display with size limit) | 20 min |
| 8 | Create `TerminalView` widget (input + output) | 40 min |
| 9 | Wire into `AppShell` "Lab" tab | 15 min |
| 10 | Write unit tests for dispatcher and commands | 45 min |
| **Total** | | **~5 hours** |

### Acceptance Criteria

- [ ] `help` displays all 9 commands with one-line descriptions
- [ ] `pwd` shows `/project/<name>` when a project is active, `/` otherwise
- [ ] `ls` lists files and folders in the current virtual directory, folders first
- [ ] `cd <folder>` navigates into a child folder; `cd` alone returns to project root
- [ ] `cd <invalid>` shows an error without crashing
- [ ] `tree` displays the full project hierarchy up to 5 levels deep
- [ ] `mkdir <name>` creates a new folder node in the current directory
- [ ] `touch <name>` creates a new empty file node in the current directory
- [ ] `cat <file>` displays file content (text only, max 100 KB)
- [ ] Path traversal attempts (`cd ../../`) are rejected with an error
- [ ] Commands without an active project show `Error: No project selected`
- [ ] All existing tests remain green
- [ ] No new dependencies added
- [ ] No modifications to `nomad_core`, `server/`, `data/`, `editor/`, or `activity/`

---

## 13. Open Questions, Assumptions & Deferred Work

### Open Questions

1. Should the terminal output integrate with the `ActivityController` for diagnostic visibility? (Recommended: defer to S-T2)
2. Should `cat` support binary files with a hex dump, or refuse them? (Recommended: refuse with message in V1)
3. What is the maximum scrollback buffer size? (Recommended: 500 lines)

### Assumptions

- The "Lab" nav tab (index 0) is the intended home for the terminal. This is based on the existing terminal icon and label.
- The terminal operates on the currently selected project (`_selectedProject` in `AppShell`).
- File content is UTF-8 text for `cat` purposes. Binary files exist (ADR-0007) but `cat` will display a warning for non-text content.

### Deferred to S-T2+

- `cp`, `mv`, `rm` commands (destructive operations need safety UX)
- `find`, `grep`, `wc` commands (search/text-processing)
- Command history (up/down arrow navigation)
- Tab completion
- Output formatting (colors, tables)
- Activity panel integration
- APK size and memory baseline measurements

---

## Final Handoff

| Question | Answer |
|----------|--------|
| What was verified? | All 29 source files, 10 ADRs, 27 test files, both pubspecs, nav structure, storage model |
| What remains uncertain? | APK size impact, memory footprint, exact command latency |
| What should be reused? | WorkspaceRepository, FileContentRepository, ProjectFileResolver, AppShell nav slot |
| What should NOT be built? | New filesystem abstraction, new DB schema, shell compatibility layer, process executor |
| Which files should S-T1 modify? | `app_shell.dart` only (1 file) |
| Which files should S-T1 create? | 4–6 new files under `lib/terminal/` and `lib/ui/` |
| What must be approved? | The 9-command S-T1 scope and the deliberate V1 syntax limitations |
| Recommended first slice | `help` + `clear` + `pwd` + `ls` + `cd` + `TerminalView` wired into "Lab" tab |
| Evidence that slice works | Unit tests for dispatcher + manual verification on Android emulator |

**S-T0 is complete. Awaiting explicit approval to begin S-T1.**
