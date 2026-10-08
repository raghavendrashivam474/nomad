# ADR-0003: Workspace and File Hierarchy Domain Model

## Status
Accepted

## Context
In S0.0.1–S0.0.3, Nomad established the `Project` entity and local SQLite persistence. In S0.0.4, Nomad requires a development workspace where projects contain files and folders with full isolation between projects.

## Decision
1. **Core Domain (`nomad_core`)**:
   - Introduce `FileNodeType` (`file`, `folder`).
   - Introduce `FileNode` entity representing logical workspace items.
   - Enforce project isolation by associating each `FileNode` with a required `projectId` (`EntityId`).
   - Enforce path-safe name validation in domain constructor.
   - Introduce `WorkspaceRepository` contract for CRUD and traversal.

2. **Persistence (`nomad_mobile`)**:
   - Extend `AppDatabase` schema to version 2 by introducing `file_nodes` table.
   - Implement recursive cascading deletion for folder nodes and project cleanup.
   - Provide `LocalWorkspaceRepository` following existing `ProjectRepository` patterns.

3. **Separation of Concerns**:
   - `FileNode` models logical metadata, hierarchy (`parentId`), and type.
   - Actual file content persistence is decoupled from metadata and handled in S0.0.5 via dedicated file storage abstraction.

## Consequences
- Pure Dart domain invariants are preserved.
- Workspaces are strictly project-isolated.
- Folder hierarchies support arbitrary depth with clean recursive operations.
