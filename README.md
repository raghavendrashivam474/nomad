# Nomad — Mobile-First Development Lab

Nomad is a **mobile-first development lab** enabling developers to build real applications directly from phones and tablets, delegating heavy compilation and packaging to personal or cloud runners on demand.

## Release: V0.0 Seed (Sprints S0.0.1 — S0.0.6)

Nomad V0.0 provides a complete local-first development workspace:

```text
CREATE PROJECT
      ↓
PERSIST PROJECT (SQLite)
      ↓
OPEN PROJECT WORKSPACE
      ↓
CREATE FOLDERS & FILES
      ↓
OPEN FILE IN EDITOR
      ↓
EDIT & SAVE (Filesystem)
      ↓
REOPEN NOMAD
      ↓
PROJECT + WORKSPACE + CODE PERSIST
```

## What Exists in V0.0 Seed

- **Architecture**: Monorepo with strict `apps/` and `packages/` boundaries.
- **packages/nomad_core**: Pure Dart domain primitives (`Project`, `ProjectType`, `FileNode`,
   `FileNodeType`, `EntityId`, `NomadException`) and domain contracts (`ProjectRepository`, `WorkspaceRepository`, `FileContentRepository`).
- **apps/nomad_mobile**: Responsive Flutter studio with SQLite metadata persistence (`AppDatabase`,
  `LocalProjectRepository`, `LocalWorkspaceRepository`) and file content storage (`LocalFileContentRepository`).

- **Responsive Adaptive Workspace**:
      * **Phone (< 600dp)**: Sequential stack navigation (Projects → File Tree → Fullscreen Code Editor).
      * **Tablet (>= 600dp)**: Integrated IDE layout with collapsible workspace explorer sidebar and multi-file editor tabs.
- **Editor**: Monospaced multi-line editing, dirty tracking (`*`), error handling, and `Ctrl+S` / `Cmd+S` keyboard shortcuts.
- **Strict Project Isolation**: Workspace hierarchies and file contents are strictly scoped by `projectId`.

## Repository Layout

```text
nomad/
├── apps/
│   └── nomad_mobile/       # Flutter client studio (Phone + Tablet)
├── packages/
│   └── nomad_core/         # Pure Dart domain models & contracts
├── docs/
│   ├── ARCHITECTURE.md     # Engineering principles & architecture
│   ├── adr/                # Architecture Decision Records (ADR-0001 to ADR-0005)
│   └── phases/             # Sprint milestone completion reports
└── .github/
    └── workflows/          # CI workflows (analyze + test)
```

## Verification & Testing

### 1. Nomad Core (Dart)

```Bash
cd packages/nomad_core
dart pub get
dart analyze
dart test
```

### 2. Nomad Mobile (Flutter)

```Bash
cd apps/nomad_mobile
flutter pub get
flutter analyze
flutter test
```

### 3. Debug APK Build Verification

```Bash
cd apps/nomad_mobile
flutter build apk --debug
```