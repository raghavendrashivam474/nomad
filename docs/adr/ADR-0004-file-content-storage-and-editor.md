# ADR-0004: File Content Persistence & Basic Editor Architecture

## Status
Accepted

## Context
In S0.0.4, Nomad introduced `FileNode` for workspace hierarchy and metadata stored in SQLite. S0.0.5 requires reading, editing, and persisting actual file content while keeping metadata and source content cleanly decoupled and project-isolated.

## Decision
1. **Domain Contract (`nomad_core`)**:
   - Introduce `FileContentRepository` with `readFile`, `writeFile`, `deleteContent`, and `deleteAllContentForProject`.
   - Pure Dart contract scoped to `projectId` and `fileNodeId`.

2. **Storage Implementation (`nomad_mobile`)**:
   - Provide `LocalFileContentRepository` writing files to local disk under `nomad_workspaces/<projectId>/<fileNodeId>.txt`.
   - Metadata remains in SQLite (`file_nodes`), while content lives in the filesystem.

3. **Editor Component (`nomad_mobile`)**:
   - `EditorView` is a pure UI widget consuming `FileContentRepository`.
   - Does not touch the SQLite database directly.
   - Provides dirty tracking, keyboard shortcut save (`Ctrl+S` / `Cmd+S`), and explicit failure handling.

## Consequences
- File content size does not inflate the SQLite database.
- Editor UI remains completely independent of metadata queries and database transactions.
- Project isolation is preserved on disk by physical directory scoping.
