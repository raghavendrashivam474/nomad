# ADR-0008: Workspace Move Operations and Touch-Resizable Layout

## Status
Accepted

## Context
Sprint WX-2 requires two core capabilities to expand Nomad's workspace:
1. Safe reorganization of files and folders (moves) within projects.
2. Touch-resizable split panels for tablet/wide viewports allowing users to adjust the explorer and editor proportions without sacrificing mobile usability.

## Decision

### 1. Workspace Node Move Operations
- **Contract Extension**: Added `moveNode(EntityId id, EntityId? newParentId)` to `WorkspaceRepository`.
- **Identity Preservation**: Because Nomad's `FileContentRepository` keys content by `(projectId, fileNodeId)`, moving a node only requires updating the SQLite `parent_id` column. File content is unaffected and preserved byte-for-byte.
- **Safety Invariants**:
  - Rejects moving non-existent nodes or to non-existent parent folders.
  - Rejects cross-project moves to preserve project isolation.
  - Rejects self-moves (`id == newParentId`).
  - Rejects cyclic moves (preventing moving a folder into any of its own descendants via ancestor traversal).
  - Enforces sibling name uniqueness at the destination folder (throws `DomainException` to avoid silent overwrites).
  - Safe no-op when destination is the current parent.

### 2. Touch-Resizable Panels
- **Layout Model**: Integrated a responsive divider `_ResizableDivider` into `AppShell` for viewports >= 600px width.
- **Constraints & Clamping**:
  - Explorer minimum width: 180.0 logical pixels.
  - Editor minimum width: 240.0 logical pixels.
  - Explorer maximum fraction: 50% of available viewport width.
- **Gesture Handling**: Continuous horizontal drag updates using Flutter's `GestureDetector` with opaque hit-testing and a 16px touch target.
- **Mobile Preservation**: Single-panel mobile flow (phone portrait/landscape) is preserved with full-screen editor and preview views.

## Consequences
- **Positive**: Complete workspace reorganization capability without file content relocation or risk of data corruption.
- **Positive**: Smooth, touch-friendly tablet workflow with zero third-party dependencies added.
- **Neutral**: `WorkspaceRepository` fakes in tests must implement `moveNode`.
