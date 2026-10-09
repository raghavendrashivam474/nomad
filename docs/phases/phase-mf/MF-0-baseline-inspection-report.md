# MF-0: Multi-File Support — Baseline Inspection & Architecture Decision Report

**Phase:** MF — Multi-File Support
**Sprint:** MF-0 (Inspection & Architecture Validation)
**Date:** 2025-07-11
**Branch:** `main`
**Commit:** `5bf75e04c74c53d687a9715441837584aaef3e38`
**Working tree:** Clean (no uncommitted changes)
**Status:** Ready for senior review

---

## A. Executive Summary

### What currently exists
Nomad has a functioning single-file web preview. The `WebPreviewView` widget loads
`index.html` from the workspace, inlines exactly one CSS file (`style.css`) and one
JavaScript file (`script.js`) into the HTML document, and renders the result via
`WebViewController.loadHtmlString()` with `baseUrl: 'https://localhost/'`.

The workspace already supports nested folders and arbitrary file hierarchies through
the `FileNode` tree model (ADR-0003). The `WorkspaceView` provides full folder
navigation, file creation, renaming, and deletion. The `EditorView` can open and
edit any file node.

### What already works
- ✅ Projects with multiple files and nested folders (workspace layer)
- ✅ Browsing nested directories in the file explorer
- ✅ Opening and editing any file in the editor
- ✅ Saving file content to disk (filesystem-backed, ADR-0004)
- ✅ Preview of a single HTML file with one inlined CSS and one inlined JS
- ✅ `localStorage` and web APIs via the `https://localhost/` origin
- ✅ Preview refresh on save (via `previewVersion` + `onSaveCompleted` callback)
- ✅ 20/20 `nomad_core` tests passing
- ✅ `flutter analyze` clean — no issues

### What does not work or remains unverified
- ❌ CSS files other than `style.css` are ignored by preview
- ❌ JavaScript files other than `script.js` are ignored by preview
- ❌ Nested file references (`css/responsive.css`, `js/app.js`) cannot resolve
- ❌ ES module imports (`import { x } from "./utils.js"`) have no serving mechanism
- ❌ Image and font assets cannot be loaded by the preview
- ❌ CSS `url()` references to external files fail silently
- ❌ The `https://localhost/` baseUrl serves no actual resources — it is an
  origin placeholder only
- ⚠️ No `INTERNET` permission in AndroidManifest (needed for localhost HTTP)
- ⚠️ No network security config for cleartext localhost traffic
- ⚠️ File-size limits: none defined in code; practical limits unmeasured

### Principal technical constraint
The `webview_flutter` 4.x Dart API provides **no sub-resource interception**.
`NavigationDelegate` handles page-level navigation events only. There is no
`shouldInterceptRequest` or `onLoadResource` equivalent exposed in Dart. This
eliminates pure-Dart WebView interception as a viable approach and makes an
embedded HTTP server the only single-mechanism solution that can serve arbitrary
project resources to the WebView.

---

## B. Existing Architecture Map

```text
┌─────────────────────────────────────────────────────────────────────┐
│ nomad_mobile (Flutter) │
│ │
│ WorkspaceView ──► FileNode tree browsing, CRUD │
│ │ │
│ ▼ onFileSelected │
│ EditorView ──► CodeEditingController ──► dirty tracking │
│ │ │ │
│ │ onSave │ readFile / writeFile │
│ ▼ ▼ │
│ FileContentRepository (contract) │
│ │ │
│ ▼ LocalFileContentRepository │
│ Filesystem: <appDocs>/nomad_workspaces/<projectId>/<nodeId>.txt │
│ │
│ EditorView.onSaveCompleted ──► previewVersion++ ──► │
│ │ │
│ ▼ │
│ WebPreviewView │
│ │ │
│ ├─ getNodesForProject(projectId) ──► flat List<FileNode> │
│ ├─ _findFile(nodes, "index.html") ──► single node match │
│ ├─ _assembleDocument() │
│ │ ├─ readFile(index.html) │
│ │ ├─ readFile(style.css) ──► inline into <style> │
│ │ └─ readFile(script.js) ──► inline into <script> │
│ └─ loadHtmlString(assembled, baseUrl: "https://localhost/") │
│ │ │
│ ▼ │
│ Android WebView (no resource server, no interception) │
│ Sub-resource requests to https://localhost/ → FAIL (404) │
└─────────────────────────────────────────────────────────────────────┘
│
▼ (Domain Contracts)
┌─────────────────────────────────────────────────────────────────────┐
│ nomad_core (Pure Dart) │
│ │
│ Entities: Project, FileNode, FileNodeType, EntityId │
│ Contracts: ProjectRepository, WorkspaceRepository, │
│ FileContentRepository │
│ Errors: NomadException, DomainException, ContractViolationEx │
└─────────────────────────────────────────────────────────────────────┘
```
### Key data flow observations

1. **File identity is UUID-based, not path-based.** Content is stored at
   `<nodeId>.txt`, not at the file's logical project path. Any resource-serving
   mechanism must resolve URL paths to node IDs via tree walk.

2. **`getNodesForProject()` returns a flat list.** Path resolution requires
   building a parent→children map and walking from root to the target file.

3. **Preview re-renders from saved content.** The `previewVersion` integer
   increments on save, triggering `didUpdateWidget` → `_renderPreview()`.
   Unsaved editor changes are NOT reflected in preview.

---

## C. Capability Matrix

| # | Required Capability | Current Status | Evidence | Missing Work |
|---|---|---|---|---|
| 1 | Multiple CSS files | ❌ Unsupported | `_assembleDocument()` inlines only `style.css` | Resource serving for arbitrary `.css` paths |
| 2 | Multiple JS files | ❌ Unsupported | `_assembleDocument()` inlines only `script.js` | Resource serving for arbitrary `.js` paths |
| 3 | Nested directories | ✅ Workspace only | `FileNode.parentId` tree, `WorkspaceView` folder nav | Preview cannot resolve nested paths |
| 4 | Open/save nested file | ✅ Supported | `EditorView` takes any `FileNode`; content repo is ID-based | None |
| 5 | Preview arbitrary file by path | ❌ Unsupported | No path→node resolution; no resource server | Path resolver + serving mechanism |
| 6 | CSS relative URL to image | ❌ Unsupported | No resource serving; `url()` references fail | MIME-aware resource serving |
| 7 | ES module import | ❌ Unsupported | No server; `import` requires real HTTP URLs with correct MIME | HTTP server with `application/javascript` MIME |
| 8 | Distinguish files from folders | ✅ Supported | `FileNodeType.file` / `FileNodeType.folder` enum | None |
| 9 | Path normalization | ⚠️ Partial | `FileNode` rejects `/` and `\` in names; no full-path builder | Path resolution utility needed |
| 10 | Missing resource handling | ⚠️ Partial | `_findFile` returns null → skipped; no 404 for sub-resources | HTTP 404 responses for missing files |
| 11 | File size limits | ℹ️ None defined | No limit in `LocalFileContentRepository`; `readAsStringSync()` loads fully | Measure practical limits on device |

---

## D. Architecture Comparison

### Candidate A — WebView Resource Interception (Dart API)

| Aspect | Assessment |
|---|---|
| **Mechanism** | Intercept sub-resource requests in the WebView and return workspace content |
| **API availability** | ❌ `webview_flutter` 4.10.0 Dart API exposes `NavigationDelegate` for page navigation only. No `shouldInterceptRequest`, `onLoadResource`, or custom scheme handler in the Dart API |
| **Native fallback** | Android's `WebViewClient.shouldInterceptRequest()` exists but is not exposed through `webview_flutter_android`'s public API. Would require a custom platform implementation or method channel |
| **MIME types** | N/A — cannot intercept |
| **ES modules** | N/A |
| **Origin/storage** | Would preserve `https://localhost/` origin if it worked |
| **Dependencies** | None (if Dart API existed); native code otherwise |
| **Complexity** | High if native bridge required; trivial if Dart API existed |
| **Verdict** | **NOT VIABLE** in pure Dart. Requires native Android code that contradicts the lightweight-first principle |

### Candidate B — Embedded Local HTTP Server

| Aspect | Assessment |
|---|---|
| **Mechanism** | `dart:io` `HttpServer` bound to `127.0.0.1`, serving workspace files by resolved path |
| **API availability** | ✅ `dart:io` is in the Dart SDK. No additional dependency needed |
| **Path resolution** | Requires a new `ProjectFileResolver` utility: URL path → tree walk → `fileNodeId` → `FileContentRepository.readFile()` |
| **MIME types** | Must implement extension→MIME mapping (`.html`, `.css`, `.js`, `.json`, `.png`, `.svg`, `.woff2`, etc.) |
| **ES modules** | ✅ Works natively — browser resolves `import` URLs as HTTP requests to the server |
| **Origin/storage** | `http://127.0.0.1:<port>`. Dynamic port changes origin across restarts, breaking `localStorage` persistence. Mitigation: use a fixed preferred port with fallback range |
| **Android config** | Requires `INTERNET` permission and `network_security_config.xml` allowing cleartext to `127.0.0.1` |
| **Security** | Bind to loopback only. Scope all paths to current `projectId`. Reject `..` traversal. No external exposure |
| **Lifecycle** | Start on first preview, stop on app pause or preview close. Idle when not serving |
| **Dependencies** | **Zero** — `dart:io` is SDK-builtin |
| **Complexity** | Moderate: ~150–250 lines for server + resolver + MIME map |
| **Verdict** | **VIABLE** — the only single-mechanism approach that satisfies all requirements |

### Candidate C — Android WebViewAssetLoader

| Aspect | Assessment |
|---|---|
| **Mechanism** | AndroidX `WebViewAssetLoader` with a custom `PathHandler` bridging to workspace files |
| **API availability** | Available in AndroidX WebKit, but not exposed through `webview_flutter` |
| **Integration** | Requires native Android code (custom `FlutterActivity` or method channel) and a custom platform view or plugin modification |
| **Dynamic files** | `WebViewAssetLoader` is designed for static bundled assets. Serving dynamic workspace files requires a custom `PathHandler` that reads from the filesystem at request time |
| **Origin/storage** | Uses `https://appassets.androidplatform.net/` — stable origin, good for storage |
| **Dependencies** | AndroidX WebKit (likely already transitive); native integration code |
| **Complexity** | High: native Android code + Flutter bridge + custom path handler |
| **Verdict** | **NOT RECOMMENDED** — significantly more complex than Candidate B for marginal origin-stability benefit |

### Hybrid A+B Evaluation

| Question | Finding |
|---|---|
| Can A and B coexist? | A is not viable in Dart, so the hybrid collapses to B alone |
| Would `loadHtmlString` + server work? | Loading initial HTML via `loadHtmlString(baseUrl: 'https://localhost/')` while sub-resources come from `http://127.0.0.1:<port>/` creates a **cross-origin mismatch**. ES modules, `fetch()`, and `localStorage` would break |
| Is routing complexity justified? | No — there is no interception to route. All resources must come from one origin |
| Single mechanism sufficient? | Yes — loading the initial page via `loadRequest(Uri.parse('http://127.0.0.1:<port>/<projectId>/index.html'))` gives a consistent origin for all resources |
| **Verdict** | **Hybrid NOT justified.** Use Candidate B consistently for all resources including the initial page load |

---

## E. Recommended Architecture

### Candidate B — Embedded Dart HTTP Server (sole mechanism)

**Principle:** Replace the current `_assembleDocument()` concatenation with a
lightweight `HttpServer` that serves all project resources from the existing
workspace, resolving URL paths through the `FileNode` tree.

### Components unchanged
| Component | Change |
|---|---|
| `nomad_core` (all entities, contracts, enums) | **No changes** |
| `LocalWorkspaceRepository` | **No changes** |
| `LocalFileContentRepository` | **No changes** |
| `FileNode` / `FileNodeType` | **No changes** |
| `WorkspaceView` (file explorer) | **No changes** |
| `EditorView` | **No changes** |
| `AppDatabase` schema | **No changes** |
| Existing ADRs (0001–0005) | **No changes** |

### Components to modify
| Component | Change | Scope |
|---|---|---|
| `WebPreviewView` | Replace `_assembleDocument()` + `loadHtmlString()` with `loadRequest()` to the local server URL. Start/stop server in lifecycle. | ~80 lines changed |
| `AndroidManifest.xml` | Add `<uses-permission android:name="android.permission.INTERNET"/>` | 1 line |
| `android/app/src/main/res/xml/network_security_config.xml` | New file: allow cleartext to `127.0.0.1` only | ~10 lines |
| `build.gradle.kts` or `AndroidManifest.xml` | Reference network security config | 1–2 lines |

### New components to add (all in `nomad_mobile`)
| Component | Purpose | Est. Size |
|---|---|---|
| `ProjectFileServer` | `HttpServer` wrapper: bind, serve, stop. Handles request routing, MIME types, 404s, path traversal rejection | ~120 lines |
| `ProjectFileResolver` | Walks `List<FileNode>` tree to resolve a URL path (e.g., `css/responsive.css`) to a `FileNode` and its content | ~60 lines |
| `MimeTypeResolver` | Maps file extensions to MIME types for HTTP `Content-Type` headers | ~30 lines |

### Resource resolution flow (proposed)

```text
Browser requests: http://127.0.0.1:18080/<projectId>/css/responsive.css
│
▼
ProjectFileServer receives request
│
▼
Validate: path starts with /<projectId>/
Reject: path contains ".." or escapes project scope
│
▼
ProjectFileResolver.resolve(projectId, "css/responsive.css")
│
├─ Split path: ["css", "responsive.css"]
├─ Find folder "css" at root level (parentId == null)
├─ Find file "responsive.css" with parentId == css.id
└─ Return FileNode
│
▼
FileContentRepository.readFile(projectId, node.id)
│
▼
Respond: 200 OK, Content-Type: text/css, body: file content
(or 404 if node not found)
```

### Project isolation
- All URLs are scoped under `/<projectId>/`
- The resolver only searches nodes belonging to the requested `projectId`
- Path traversal (`..`, absolute paths) is rejected before resolution
- The server binds to `127.0.0.1` only — no external access

### Origin and storage
- Use a **preferred fixed port** (e.g., 18080) with a small fallback range (18080–18089)
- This provides a stable origin `http://127.0.0.1:18080` across app restarts
- `localStorage`, `sessionStorage`, and IndexedDB persist under this origin
- Document the port choice in a new ADR

### Why this option over alternatives
1. **Zero new dependencies** — `dart:io` is in the SDK
2. **No native Android code** — pure Dart implementation
3. **Supports all resource types** — HTML, CSS, JS, ES modules, images, fonts, JSON
4. **Consistent origin** — single mechanism for all resources
5. **Preserves all existing architecture** — no domain, database, or editor changes
6. **Minimal code surface** — ~210 new lines + ~80 modified lines

---

## F. Implementation Sequence

### MF-1: Server Foundation & Path Resolution
- Implement `MimeTypeResolver` (pure utility, fully testable)
- Implement `ProjectFileResolver` (tree walk, testable with fake nodes)
- Implement `ProjectFileServer` (bind, serve, 404, traversal rejection)
- Add unit tests for all three components
- Add `INTERNET` permission and network security config
- **Does NOT modify `WebPreviewView` yet** — server is testable in isolation
- **Dependency:** None

### MF-2: Preview Integration
- Modify `WebPreviewView` to start/stop `ProjectFileServer`
- Replace `_assembleDocument()` + `loadHtmlString()` with `loadRequest()` to server URL
- Handle server lifecycle (start on preview open, stop on close/pause)
- Update preview tests to accommodate the new loading mechanism
- **Dependency:** MF-1

### MF-3: Multi-File Validation & Edge Cases
- Create the MFProbe test project (nested CSS, JS, ES modules, images)
- Validate all 12 test cases from the brief on a physical Android device
- Handle binary file serving (images, fonts) — may need `readAsBytes()` path
- Test project switching (ensure previous project resources are not served)
- Test offline behavior
- Test large file performance
- **Dependency:** MF-2

### MF-4: Hardening & Documentation
- Finalize ADR for the server architecture
- Performance benchmarking and memory profiling
- Error handling edge cases (server bind failure, concurrent requests)
- Update user-facing documentation if needed
- **Dependency:** MF-3

---

## G. Risks and Open Questions

| # | Risk / Question | Impact | Verification Plan |
|---|---|---|---|
| 1 | **Port collision** — another app uses port 18080 | Preview fails to start | Fallback port range (18080–18089); test on device with common apps running |
| 2 | **Android cleartext policy** — some Android versions may block `http://127.0.0.1` even with security config | Preview blank | Test on Android 12, 13, 14 physical devices |
| 3 | **Binary file serving** — current `FileContentRepository` reads as `String` | Images/fonts corrupted | May need a `readFileBytes()` method or direct filesystem read for binary types; investigate in MF-3 |
| 4 | **ES module MIME strictness** — browsers require `application/javascript` for ES modules | `import` fails | Verify MIME type in MF-3 test cases |
| 5 | **Server lifecycle on app background** — Android may kill the server process | Preview stale on resume | Test app pause/resume cycle; restart server if needed |
| 6 | **`localStorage` origin change** — if port changes, stored data is lost | User data loss | Fixed port strategy mitigates; document limitation |
| 7 | **Concurrent requests** — `HttpServer` default handles one request at a time | Slow preview with many resources | Use `HttpServer.bind(..., shared: true)` or `runZoned`; measure in MF-3 |
| 8 | **File size** — no limit defined; `readAsStringSync()` loads entire file | OOM on very large files | Measure practical limit in MF-3; consider streaming for files >1MB |

---

## H. Test and Device-Validation Plan

### Existing automated tests (must continue to pass)
| Test File | Tests | Status |
|---|---|---|
| `packages/nomad_core/test/*` | 20 tests | ✅ All passing |
| `apps/nomad_mobile/test/ui/web_preview_view_test.dart` | 6 widget tests | ⚠️ Will need updates in MF-2 (new loading mechanism) |
| `apps/nomad_mobile/test/data/*` | Repository tests | ✅ Should remain unaffected |
| `apps/nomad_mobile/test/editor/*` | Editor tests | ✅ Should remain unaffected |

### New tests to write (MF-1)
- `MimeTypeResolver` — extension mapping for all supported types
- `ProjectFileResolver` — root file, nested file, missing file, traversal rejection, folder-as-target rejection
- `ProjectFileServer` — bind, serve 200, serve 404, reject traversal, reject cross-project access, stop/restart

### Physical device checks (MF-3)
| Check | Device | Expected |
|---|---|---|
| Root CSS loads | Android 12+ | `style.css` renders correctly |
| Nested CSS loads | Android 12+ | `css/responsive.css` applies |
| Multiple JS files | Android 12+ | Both scripts execute |
| ES module import | Android 12+ | `import` resolves and executes |
| Image asset loads | Android 12+ | PNG renders in preview |
| CSS `url()` reference | Android 12+ | Background image/font loads |
| Missing resource | Android 12+ | 404 in console, no crash |
| Path traversal | Android 12+ | Rejected, 403/404 |
| Project switch | Android 12+ | Old project resources not served |
| Save and refresh | Android 12+ | Updated content appears |
| `localStorage` | Android 12+ | Data persists across refresh |
| Offline preview | Android 12+ (airplane mode) | Preview works without internet |

---

## I. Architecture Decision Status

**Classification: Ready for approval**

Evidence supports a clear, minimal approach:

1. The Dart `webview_flutter` API cannot intercept sub-resources (eliminates Candidate A)
2. Android `WebViewAssetLoader` requires native code (eliminates Candidate C)
3. `dart:io` `HttpServer` requires zero dependencies and satisfies all requirements (Candidate B)
4. A hybrid is unnecessary because a single mechanism handles all cases consistently
5. All existing domain contracts, repositories, and UI components remain unchanged
6. The implementation surface is ~290 lines of new/modified code in `nomad_mobile` only

### Proposed ADR

**ADR-0006: Embedded HTTP Server for Multi-File Web Preview**

- **Status:** Proposed (awaiting senior review approval)
- **Context:** The current preview concatenates exactly 3 hardcoded files. Multi-file web projects require serving arbitrary resources (CSS, JS, ES modules, images, fonts) to the Android WebView. The `webview_flutter` Dart API provides no sub-resource interception.
- **Decision:** Introduce a lightweight `dart:io` `HttpServer` bound to `127.0.0.1` that serves workspace files resolved through the `FileNode` tree. Replace `loadHtmlString()` with `loadRequest()` to the server URL for consistent origin. Add `INTERNET` permission and localhost-only cleartext network security config.
- **Alternatives considered:** (A) Dart WebView interception — not available in API. (C) Android WebViewAssetLoader — requires native code. (A+B hybrid) — cross-origin mismatch makes it unworkable.
- **Consequences:** One new Android permission. One new network security config file. ~290 lines of new/modified Dart code in `nomad_mobile`. Zero changes to `nomad_core`. Zero new dependencies.

---

## Appendix: Files Inspected

| File | Reason |
|---|---|
| `apps/nomad_mobile/pubspec.yaml` | Dependencies, `webview_flutter` version |
| `packages/nomad_core/pubspec.yaml` | Core dependencies (zero) |
| `apps/nomad_mobile/pubspec.lock` | Exact resolved versions |
| `docs/ARCHITECTURE.md` | System architecture and principles |
| `docs/adr/ADR-0003-workspace-and-file-model.md` | Workspace domain decisions |
| `docs/adr/ADR-0004-file-content-storage-and-editor.md` | File content storage decisions |
| `apps/nomad_mobile/lib/ui/web_preview_view.dart` | Current preview implementation (282 lines) |
| `packages/nomad_core/lib/src/domain/workspace_repository.dart` | Workspace contract |
| `packages/nomad_core/lib/src/domain/file_content_repository.dart` | Content contract |
| `packages/nomad_core/lib/src/domain/file_node.dart` | FileNode entity (70 lines) |
| `packages/nomad_core/lib/src/domain/file_node_type.dart` | File/folder enum |
| `packages/nomad_core/lib/src/identifiers/unique_id.dart` | EntityId wrapper |
| `packages/nomad_core/lib/nomad_core.dart` | Barrel exports |
| `apps/nomad_mobile/lib/data/repositories/local_workspace_repository.dart` | SQLite workspace impl (110 lines) |
| `apps/nomad_mobile/lib/data/repositories/local_file_content_repository.dart` | Filesystem content impl (74 lines) |
| `apps/nomad_mobile/lib/data/database/app_database.dart` | SQLite schema (73 lines) |
| `apps/nomad_mobile/lib/ui/editor_view.dart` | Editor implementation (342 lines) |
| `apps/nomad_mobile/lib/ui/workspace_view.dart` | File explorer (364 lines) |
| `apps/nomad_mobile/lib/data/templates/web_template.dart` | Default project template |
| `apps/nomad_mobile/android/app/src/main/AndroidManifest.xml` | Android permissions |
| `apps/nomad_mobile/android/app/build.gradle.kts` | Android build config |
| `apps/nomad_mobile/test/ui/web_preview_view_test.dart` | Existing preview tests (323 lines) |

## Appendix: Commands Executed

| Command | Result |
|---|---|
| `git branch --show-current` | `main` |
| `git log -1` | `5bf75e04...` |
| `git status --short` | (empty — clean) |
| `cd packages/nomad_core && dart test` | 00:02 +20: All tests passed! |
| `cd apps/nomad_mobile && flutter analyze` | No issues found! |

---

*Report generated by MF-0 inspection. No production code was modified.*
*Awaiting senior review approval before proceeding to MF-1.*
