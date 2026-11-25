# Nomad AL-3: Project Snapshot Transfer Architecture

## 1. Principles
- **Authoritative Source:** Nomad's SQLite database (WorkspaceRepository and FileContentRepository) remains the sole authoritative source of project files.
- **Stateless Offloading:** The companion runtime is treated as an ephemeral compiler workspace.
- **Path Sanitization:** File keys are sanitized against directory traversal (..) before writing to disk.

## 2. Transfer Sequence

```text
[Nomad SQLite Workspace]
│
▼
[In-Memory FileNode Tree Map] ──(POST /api/v1/builds)──► [Companion Temp Workspace]
│
▼
[gradlew assembleDebug]
```
