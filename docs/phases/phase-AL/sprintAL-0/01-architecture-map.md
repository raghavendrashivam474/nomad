# AL-0: Current Architecture Map

> Generated during Micro-sprint A inspection.
> Baseline commit: `772c22a` (main, tag v-NT-1.S-T3).
> All paths relative to repository root.

## 1. Repository Layout

```text
nomad/
apps/nomad_mobile/ # Flutter application (host)
lib/
activity/ # Live Activity state (ADR-0009)
app/ # App entry point
branding/ # NomadBrand constants
data/
database/ # SQLite schema (app_database.dart)
mappers/ # ProjectMapper
repositories/ # LocalProjectRepository
templates/ # WebTemplate
editor/ # Code editor, input actions, snippets
server/ # ProjectFileServer, ProjectFileResolver
terminal/ # Terminal commands
ui/ # ProjectsView (creation + selection)
android/ # Flutter host Android project (Kotlin DSL)
packages/nomad_core/ # Domain primitives (zero dependencies)
lib/src/
domain/ # Project, FileNode, repositories (abstract)
errors/ # NomadException, ContractViolationException
identifiers/ # EntityId
docs/
adr/ # ADR-0001 through ADR-0010
phases/ # Phase reports
```

## 2. Core Domain Model (packages/nomad_core)

### Project
- **File:** `packages/nomad_core/lib/src/domain/project.dart`
- **Fields:** `EntityId id`, `String name`, `ProjectType type`, `DateTime createdAt/updatedAt`
- **Validation:** name cannot be empty

### ProjectType
- **File:** `packages/nomad_core/lib/src/domain/project_type.dart`
- **Values:** `web`, `android`
- **Note:** `android` already exists in the enum. The UI dropdown already renders it.

### FileNode
- **File:** `packages/nomad_core/lib/src/domain/file_node.dart`
- **Fields:** `EntityId id`, `EntityId projectId`, `EntityId? parentId`, `String name`, `FileNodeType type`
- **Validation:** name cannot be empty, cannot contain `/` or `\`
- **Helpers:** `isFile`, `isFolder`, `isRoot`

### FileNodeType
- **File:** `packages/nomad_core/lib/src/domain/file_node_type.dart`
- **Values:** `file`, `folder`

## 3. Repository Contracts (packages/nomad_core, all abstract)

| Contract | File | Key Methods |
|---|---|---|
| `ProjectRepository` | `src/domain/project_repository.dart` | `getAllProjects`, `getProjectById`, `saveProject`, `deleteProject` |
| `WorkspaceRepository` | `src/domain/workspace_repository.dart` | `getNodesForProject`, `getNodeById`, `createNode`, `renameNode`, `moveNode`, `deleteNode`, `deleteAllNodesForProject` |
| `FileContentRepository` | `src/domain/file_content_repository.dart` | `readFile`, `writeFile`, `readFileBytes`, `writeFileBytes`, `deleteContent`, `deleteAllContentForProject` |

## 4. Infrastructure (apps/nomad_mobile)

### Persistence
- **Database:** `data/database/app_database.dart` — SQLite, version 2
- **Tables:** `projects` (id, name, type, created_at, updated_at), `file_nodes` (id, project_id, parent_id, name, type, created_at, updated_at)
- **Mapper:** `data/mappers/project_mapper.dart` — `ProjectMapper.toMap/fromMap`
- **Implementation:** `data/repositories/local_project_repository.dart` — `LocalProjectRepository`

### Templates
- **File:** `data/templates/web_template.dart`
- **Pattern:** Static const strings (`indexHtml`, `styleCss`, `scriptJs`)
- **Usage:** Hardcoded in `ProjectsView._createProject()` for `ProjectType.web`

### Execution (Web only)
- **Server:** `server/project_file_server.dart` — `ProjectFileServer` binds `127.0.0.1:18080`
- **Resolver:** `server/project_file_resolver.dart` — `ProjectFileResolver` walks FileNode tree, enforces path safety
- **Flow:** HTTP GET → resolve logical path → read bytes from `FileContentRepository` → serve to WebView
- **Virtual route:** `/_nomad/transport.js` (ADR-0010)

### Activity (ADR-0009)
- **Controller:** `activity/activity_controller.dart` — `ActivityController` (ChangeNotifier, bounded event list)
- **Event:** `activity/activity_event.dart` — `ActivityEvent` with `ActivityCategory` (lifecycle, resource, runtime) and `ActivitySeverity`

## 5. Execution Flows

### CREATE (all types)

ProjectsView._createProjectDialog()
→ _createProject(name, type)
→ ProjectRepository.saveProject()
→ IF type == web:
    FOR each starter file:
        WorkspaceRepository.createNode(FileNode)
        FileContentRepository.writeFile(content)
→ IF type == android:
    *** NO FILE CREATION — gap to fill ***
→ ON partial failure: rollback (delete project + nodes + content)


### EDIT
Editor (code_editing_controller.dart)
→ modifies files via WorkspaceRepository + FileContentRepository


### RUN (Web only)
ProjectFileServer.start() on 127.0.0.1:18080
→ WebView loads http://127.0.0.1:18080/<projectId>/index.html
→ ProjectFileResolver resolves path against FileNode tree
→ FileContentRepository.readFileBytes() returns content
→ HTTP response served to WebView


### RUN (Android)
*** DOES NOT EXIST — AL-0 must prove this path ***


## 6. Key Constraints for AL-0

1. **Files live in SQLite, not on disk** (ADR-0007). Gradle requires real filesystem paths. A materialization step is required.
2. **No Runner abstraction exists.** The brief references it as intended direction. AL-0 should not invent one prematurely.
3. **ProjectType.android is already modeled.** The enum, UI dropdown, and project creation flow acknowledge it. Only the file-creation and build-execution logic are missing.
4. **Web execution is HTTP-serving, not compilation.** Android builds are a fundamentally different operation. Do not force them into the ProjectFileServer model.
5. **Activity system exists** for live diagnostics. Build status events could integrate here, but AL-0 should not over-couple.