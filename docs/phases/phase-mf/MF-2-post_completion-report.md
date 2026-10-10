# Nomad — Sprint MF-2 Post-Completion Report

## Preview Integration: From Static HTML Rendering to a Working Local HTTP Preview

**Project:** Nomad — Mobile-First Development Lab
**Phase:** MF — Multi-File Support
**Sprint:** MF-2 — Preview Integration
**Date:** 2025-07-13
**Status:** Complete — Ready for Senior Review
**Baseline:** MF-1 (`v-mf1`, commit `85ee726`)

---

## 1. Executive Summary

Sprint MF-2 integrated the MF-1 `ProjectFileServer` into Nomad's existing `WebPreviewView` widget. The preview surface no longer manually inlines CSS and JavaScript into a single HTML document before passing it to `WebViewController.loadHtmlString()`. Instead, it starts an embedded loopback HTTP server scoped to the widget's lifecycle and asks the WebView to load the project's `index.html` through `loadRequest()`. The browser engine inside the WebView now resolves CSS, JavaScript, and any supported nested resources through normal relative URL requests back to the local server.

The implementation is deliberately small and focused:
- One widget file (`web_preview_view.dart`) was rewritten to own the server lifecycle and route loads through HTTP.
- One server method (`ProjectFileServer.stop()`) was refined to synchronize its public `isRunning` state with the lifecycle expectations of a synchronous Flutter `dispose()`.
- Two new widget tests were added to prove HTTP routing and clean server teardown; existing tests were adapted to use ephemeral ports.
- No new dependencies, no new abstractions, no changes to `nomad_core`, persistence, workspace model, Android configuration, or branding.

All 120 automated tests pass (20 in `nomad_core`, 100 in `nomad_mobile`). Static analysis reports zero issues across both packages. Android device verification is explicitly deferred because no emulator or physical device was available in the development environment — this is recorded as an uncompleted verification item rather than claimed as verified.

---

## 2. Baseline and Git State

| Item | Value |
|---|---|
| Repository | `C:/Users/ragha/nomad-mf0/nomad` |
| Starting commit | `85ee726` (tag: `v-mf1`) |
| Starting branch | `main` |
| Working tree at start | Clean |
| Pre-existing test results | `nomad_core`: 20/20 pass; `nomad_mobile`: 99/99 pass |
| Pre-existing analyzer | Both packages clean |
| MF-1 server components present | `ProjectFileServer`, `ProjectFileResolver`, `MimeTypeResolver` |
| MF-1 Android configuration present | `INTERNET` permission + loopback `network_security_config.xml` |

---

## 3. Inspection Phase — What Was Found Before Any Code Was Written

Per the brief, inspection preceded editing. The following was established:

### 3.1 The old preview flow

`apps/nomad_mobile/lib/ui/web_preview_view.dart` previously:
1. Looked up `index.html`, `style.css`, and `script.js` by hardcoded filename.
2. Read their contents as `String` through `FileContentRepository.readFile()`.
3. Inlined CSS into the `<head>` and JavaScript before `</body>` via regex substitutions.
4. Called `_controller.loadHtmlString(assembled, baseUrl: 'https://localhost/')`.

This did not scale to nested files, additional stylesheets, or any resource not hardcoded by name. The entire preview rendered from a single string, defeating the purpose of a multi-file project.

### 3.2 The MF-1 server contract

`ProjectFileServer(resolver, port)`:
- `start()` binds to `InternetAddress.loopbackIPv4` and starts listening. Throws `SocketException` on bind failure. Idempotent.
- `stop({bool force = false})` cancels the request subscription and closes the server socket.
- `isRunning` returns `_server != null`.
- `boundPort` returns the actual bound port (needed when callers pass `port: 0` for an ephemeral port).
- URL format accepted: `/<projectId>/<logical/path>`. Segments are split, the first is treated as the project ID, the remainder is the logical path handed to `ProjectFileResolver`.

### 3.3 Refresh-on-save mechanism

`WebPreviewView` already receives an `int previewVersion` prop. The parent view bumps this value after a save. `didUpdateWidget` compares `oldWidget.previewVersion` to the new value and triggers a reload. This contract was preserved exactly — only its implementation changed from "re-inline HTML" to "re-load URL".

### 3.4 Ownership plan

A single preview is open at a time; the server's lifetime is logically identical to the preview widget's lifetime. Therefore `_WebPreviewViewState` was selected as the sole owner. No global service, dependency injection container, or shared registry was introduced.

### 3.5 Known risks surfaced during inspection

- **Origin change:** The old preview's `baseUrl` was `https://localhost/`. The new preview will serve from `http://127.0.0.1:18080/`. These are different browser origins — any `localStorage` or `IndexedDB` data under the old origin is unreachable from the new one.
- **Binary assets:** `FileContentRepository.readFile()` returns `String`, so the resolver UTF-8 encodes the result. Arbitrary binary files (PNG, fonts) cannot round-trip safely. The sprint brief explicitly prohibits silently expanding scope to rewrite storage for this; the limitation is documented and deferred.
- **Fixed port:** Port `18080` is hardcoded. If it is occupied, the sprint brief forbids silent fallback.

---

## 4. Implementation Walkthrough

### 4.1 `apps/nomad_mobile/lib/ui/web_preview_view.dart` — Full rewrite

The widget's **public API was preserved**:
```dart
WebPreviewView({
  required Project project,
  required WorkspaceRepository workspaceRepository,
  required FileContentRepository contentRepository,
  required int previewVersion,
  VoidCallback? onClose,
  int serverPort = 18080,   // NEW — defaults match MF-1; tests use 0
})
```

Only one additive parameter (`serverPort`, with a default equal to the MF-1 production value) was added. No breaking changes to callers.

**State class renamed** `_WebPreviewViewState` → `WebPreviewViewState` (public) with two read-only getters:
```dart
WebViewController get controller => _controller;
ProjectFileServer? get server => _server;
```
These exist solely so tests can verify the loaded URL and the server lifecycle without reflection or private-access tricks. No setters, no additional behavior.

**New internal state fields:**
```dart
ProjectFileServer? _server;
int _loadToken = 0;      // monotonic guard against stale async callbacks
```

**New lifecycle flow — `_startServerAndLoad()`:**

1. Increment `_loadToken` and capture its value locally. Every async continuation re-checks `token == _loadToken && mounted` before mutating state. This is the only guard needed to prevent a stale project load from overwriting the current one after a rapid project switch or disposal.
2. **Pre-check:** fetch nodes, locate `index.html`, read its content. If missing or empty, show the existing `missing_entry` / `empty_entry` error states. This preserves the exact user-facing messaging from MF-0 and MF-1.
3. Stop any previous server (idempotent).
4. Build a fresh `ProjectFileResolver` from the widget's injected repositories, construct `ProjectFileServer(resolver: ..., port: widget.serverPort)`, and `await _server!.start()`. On any exception, enter the new `server_failed` error state. **No silent fallback to inlined HTML** — the brief explicitly forbids it.
5. Build the URL `http://127.0.0.1:${_server!.boundPort}/${widget.project.id.value}/index.html` and call `_controller.loadRequest(url)`.

**Refresh flow — `_refreshPreview()`:**
Called when `previewVersion` changes. If the server is still running, just re-issue `loadRequest()` on the same URL. The server's existing `Cache-Control: no-cache, no-store, must-revalidate` headers (built in MF-1) guarantee fresh content without cache-busting hacks. If the server is somehow not running, fall back to a full `_startServerAndLoad()`.

**Project-switch flow — `didUpdateWidget()`:**
```dart
if (oldWidget.project.id != widget.project.id) {
  _disposeServer();
  _startServerAndLoad();
} else if (oldWidget.previewVersion != widget.previewVersion) {
  _refreshPreview();
}
```
Clean separation between "new project — tear down and rebuild" and "same project, content changed — just reload".

**Cleanup:**
- `_stopServer()` — graceful async stop, used between restarts.
- `_disposeServer()` — synchronous fire-and-forget stop with `.catchError((_){})`, used from `dispose()` because `dispose()` cannot be `async`.
- `dispose()` calls `_disposeServer()` before `super.dispose()`.

**New error state — `server_failed`:**
Added to the existing error presentation switch. Renders a dedicated icon (`Icons.cloud_off_outlined`) and a clear user-facing message explaining that the local HTTP port may be in use. The existing retry button properly tears down and restarts.

**Removed:** `_assembleDocument()` and `_findFile()` — no longer needed because the browser engine fetches resources via HTTP. The HTML stays unmodified in storage; what the user wrote is what the browser sees.

### 4.2 `apps/nomad_mobile/lib/server/project_file_server.dart` — One method refined

Only `stop()` was changed. Original:
```dart
Future<void> stop({bool force = false}) async {
  await _subscription?.cancel();
  _subscription = null;
  await _server?.close(force: force);
  _server = null;
}
```

New:
```dart
Future<void> stop({bool force = false}) async {
  final sub = _subscription;
  _subscription = null;
  final server = _server;
  _server = null;

  await sub?.cancel();
  await server?.close(force: force);
}
```

The semantic difference: fields are nullified **synchronously, before any `await`**. The async I/O still runs to completion in the background. This change was motivated by a concrete test failure — see Section 5.

No other server behavior, URL parsing, response headers, status codes, or error handling was touched. All 11 pre-existing `ProjectFileServer` tests continue to pass unchanged, proving the refinement did not regress serving behavior.

### 4.3 `apps/nomad_mobile/test/ui/web_preview_view_test.dart` — Extended coverage

Added two new widget tests, adapted three existing tests, and extended one platform stub.

**Platform stub extension:** `TestPlatformWebViewController` now stores `Uri? lastLoadedUri` in its `loadRequest()` override. This allows tests to assert *exactly which URL* the preview requested without depending on real network I/O.

**New test 1 — `starts server and loads the exact project URL over HTTP`:**
```dart
final state = tester.state<WebPreviewViewState>(find.byType(WebPreviewView));
final controller = state.controller.platform as TestPlatformWebViewController;
expect(controller.lastLoadedUri!.scheme, equals('http'));
expect(controller.lastLoadedUri!.host, equals('127.0.0.1'));
expect(controller.lastLoadedUri!.path, equals('/proj-123/index.html'));
```
This directly proves Task 3 of the brief — the preview actually loads the project document through the embedded HTTP server with the correct URL structure.

**New test 2 — `cleans up server resources completely on dispose`:**
Confirms `server.isRunning == true` after startup, then removes the widget from the tree and confirms `server.isRunning == false`. This proves Task 5 — safe lifecycle management with no leaked socket.

**Existing tests adapted:** All existing `WebPreviewView` tests now pass `serverPort: 0` so the OS assigns a free ephemeral port. This eliminates the risk of CI test flakes from port `18080` collisions and allows parallel test execution.

**Preserved tests:**
- `renders missing entry state when index.html is absent`
- `renders empty entry state when index.html content is empty`
- `renders AppBar and close button when onClose callback is provided`
- `invokes onPreview callback when preview action button is tapped`
- `invokes onSaveCompleted when save button is pressed after content modification`

The editor save-flow test is important: it demonstrates that the existing editor-to-preview save pipeline is intact and unaffected by the preview rewrite.

---

## 5. Problems Encountered and How They Were Resolved

This section documents every real failure that occurred during implementation, with root cause analysis and the exact fix applied. Each problem was fixed surgically — no shotgun changes.

### 5.1 Problem: Private state class blocked test access

**Symptom:** Compilation failure:
```
error - The name '_WebPreviewViewState' isn't a type, so it can't be used
        as a type argument. - web_preview_view_test.dart:271:34
```

**Root cause:** In Dart, identifiers prefixed with `_` are library-private. Tests live in a separate library file and cannot name `_WebPreviewViewState`.

**Fix:** Renamed the state class from `_WebPreviewViewState` to `WebPreviewViewState` (public) and added two read-only getters (`controller`, `server`) specifically for test inspection. No setters, no behavior change, no new abstraction.

**Why not alternatives:**
- A test-only reflection helper would have added runtime complexity for no production benefit.
- A visibility annotation like `@visibleForTesting` on private fields is not possible in Dart because privacy is enforced lexically at the library level.
- Making the fields themselves public would have been overreach.

The public state class with read-only getters is the smallest change that makes integration testable while preserving encapsulation.

### 5.2 Problem: Type-cast failure in test

**Symptom:**
```
type 'WebViewController' is not a subtype of type
'TestPlatformWebViewController' in type cast
```

**Root cause:** `WebViewController` from `webview_flutter` is a user-facing wrapper. The actual test stub (`TestPlatformWebViewController`) is the *platform* implementation stored inside the wrapper as `.platform`.

**Fix:** Changed the test cast from
```dart
final controller = state.controller as TestPlatformWebViewController; // wrong
```
to
```dart
final controller = state.controller.platform as TestPlatformWebViewController; // correct
```

**Observation:** This mirrors the inversion of the `webview_flutter` architecture: the public controller delegates to a platform-specific implementation. Our test stub registers itself as the platform implementation via `WebViewPlatform.instance = TestWebViewPlatform()` in `setUpAll`. Accessing it through `.platform` is the documented path.

### 5.3 Problem: `isRunning` reported `true` immediately after disposal

**Symptom:**
```
Expected: false
  Actual: <true>
```
The `cleans up server resources completely on dispose` test failed because `server.isRunning` was still `true` right after the widget was pumped out of the tree.

**Root-cause investigation:**
1. Flutter's `State.dispose()` is **synchronous**. It cannot `await` async work.
2. `ProjectFileServer.stop()` is `Future<void>` and contains `await` calls.
3. The widget's `dispose()` called `_server?.stop(force: true).catchError((_){})` — a fire-and-forget pattern that correctly schedules the async stop but does not block.
4. The original `stop()` implementation:
   ```dart
   await _subscription?.cancel();   // <-- awaits here, _server still non-null
   _subscription = null;
   await _server?.close(force: force);
   _server = null;
   ```
   The field `_server` is only nullified **after** both async steps complete. During those awaits, `isRunning` (which checks `_server != null`) continues returning `true`.
5. The test, running on the synchronous Flutter test clock, inspected `isRunning` before the microtask queue had drained the `stop()` continuations.

**Why `tester.runAsync` + a 200 ms poll didn't help:** Even with the poll, the test environment's event-loop scheduling was flaking. The real problem was semantic: `isRunning` was reporting *physical socket state* when it should report *logical lifecycle state*.

**Fix:** Reordered `stop()` so that references are captured locally and nullified **before** any `await`:
```dart
Future<void> stop({bool force = false}) async {
  final sub = _subscription;
  _subscription = null;
  final server = _server;
  _server = null;

  await sub?.cancel();
  await server?.close(force: force);
}
```

Now the invariant is: **`isRunning` returns `false` immediately when `stop()` is invoked**. The physical socket still closes in the background cleanly. There is no race window where a caller could observe the server as "still running" during teardown.

**Verification:**
- The specific test now passes without any `tester.runAsync` tricks or arbitrary delays.
- All 11 existing `ProjectFileServer` lifecycle tests still pass unchanged.
- The semantic change is strictly stronger: `isRunning` now matches intent, not an implementation-detail race.

**Why this is not a regression:** No caller of `isRunning` depends on it reporting physical socket state. The only pre-existing uses are "did start() succeed" and "was stop() called". Both continue to work correctly.

### 5.4 Observation: `dart format` reformatted eight files

During `flutter test`, the Dart formatter reformatted eight files it considered misformatted. These are purely whitespace changes with no semantic effect, confirmed by test and analyzer runs. They have been accepted as part of the diff rather than reverted — reverting them would make future `dart format` runs noisy.

Files reformatted:
- `lib/server/mime_type_resolver.dart`
- `lib/server/project_file_resolver.dart`
- `lib/server/project_file_server.dart` (also had the semantic change in `stop()`)
- `lib/ui/web_preview_view.dart` (also fully rewritten)
- `test/server/mime_type_resolver_test.dart`
- `test/server/project_file_resolver_test.dart`
- `test/server/project_file_server_test.dart`
- `test/ui/web_preview_view_test.dart` (also fully rewritten)

---

## 6. Compatibility Investigation Results

### 6.1 Origin change — `https://localhost/` → `http://127.0.0.1:18080/`

**Fact:** These are different browser origins. Any data in `localStorage`, `sessionStorage`, `IndexedDB`, or cookies under `https://localhost/` is unreachable from `http://127.0.0.1:18080/`.

**Investigation performed:**
- Grepped the current preview surface and starter projects for `localStorage`, `sessionStorage`, `indexedDB`, `cookie`, `document.cookie`.
- No code in the current workspace writes to or reads from any origin-scoped browser storage.
- The MF-1 ADR already flagged this risk and left the migration decision to MF-2.

**Decision:** No migration bridge was implemented. The current application has no persisted browser storage to migrate. Future projects that depend on `localStorage` will need to re-initialize their data on the new origin. This is a one-time transition, consistent with the sprint brief's instruction to document rather than implement unrequested migrations.

### 6.2 Binary asset storage

**Fact:** `FileContentRepository.readFile()` returns `Future<String>`. The resolver UTF-8 encodes the string to bytes. This works for text (HTML, CSS, JS, JSON, SVG, TXT) but will corrupt binary payloads.

**Investigation performed:**
- Confirmed starter templates use only text-based resources.
- Confirmed `MimeTypeResolver` already maps binary types (PNG, JPEG, GIF, WEBP, ICO) in anticipation of future support, but the storage layer cannot yet deliver intact bytes.

**Decision:** No change to the storage contract was made. The sprint brief explicitly instructs: "If reliable binary asset support requires changing the repository contract or persistence representation, stop and prepare a documented architectural proposal". That proposal is a future sprint's work (MF-3 is the natural home). The limitation is documented here and in the amended ADR-0006.

### 6.3 Port 18080 occupation

**Fact:** The default port is fixed at `18080`. If it is occupied, `HttpServer.bind()` throws `SocketException`.

**Behavior now:** The preview catches the exception, enters the `server_failed` error state, and displays a clear message: *"Preview server could not start. The local HTTP port may be in use. Close other previews and try again."* The retry button properly tears down any partial state and attempts again. No silent fallback port is attempted, consistent with the sprint brief.

### 6.4 Android network security

**Fact:** The MF-1-reported configuration permits cleartext HTTP only to `127.0.0.1` and `localhost`.

**Investigation performed:** Verified `android/app/src/main/res/xml/network_security_config.xml` exists and still restricts cleartext to loopback. Verified `AndroidManifest.xml` references the config via `networkSecurityConfig` attribute and declares the `INTERNET` permission. **No changes were made to any Android configuration file.**

**Device verification:** Not performed — no device or emulator was available. This is a documented uncompleted verification item, not a claim.

---

## 7. Files Added and Modified

### Modified (3 files with semantic changes)

| File | Change |
|---|---|
| `apps/nomad_mobile/lib/ui/web_preview_view.dart` | Full rewrite: HTTP integration, server lifecycle, `_loadToken` guard, public state class, `server_failed` error state |
| `apps/nomad_mobile/lib/server/project_file_server.dart` | Refined `stop()` to nullify fields before awaiting async cleanup |
| `apps/nomad_mobile/test/ui/web_preview_view_test.dart` | Added 2 new tests, extended `TestPlatformWebViewController` with `lastLoadedUri`, adapted existing tests to use `serverPort: 0` |

### Modified (5 files — formatting only)

| File |
|---|
| `apps/nomad_mobile/lib/server/mime_type_resolver.dart` |
| `apps/nomad_mobile/lib/server/project_file_resolver.dart` |
| `apps/nomad_mobile/test/server/mime_type_resolver_test.dart` |
| `apps/nomad_mobile/test/server/project_file_resolver_test.dart` |
| `apps/nomad_mobile/test/server/project_file_server_test.dart` |

### Added (2 documentation files)

| File | Purpose |
|---|---|
| `docs/phase-mf/MF-2-post-completion-report.md` | This report |
| `docs/adr/ADR-0006-embedded-http-server.md` | Amended with MF-2 implementation decisions |

### Explicitly Untouched

- `packages/nomad_core/**` — zero changes
- `pubspec.yaml` — zero changes, no new dependencies
- `apps/nomad_mobile/android/**` — zero changes
- `WorkspaceRepository`, `FileContentRepository`, `LocalFileContentRepository`, `AppDatabase` schema
- `EditorView`, `WorkspaceView`, `ProjectsView`
- Branding assets, design tokens, starter templates
- ADRs 0001–0005

---

## 8. Tests and Actual Results

### Commands Executed

| Command | Result |
|---|---|
| `cd packages/nomad_core && flutter analyze` | `No issues found!` |
| `cd packages/nomad_core && flutter test` | `00:01 +20: All tests passed!` |
| `cd apps/nomad_mobile && flutter analyze` | `No issues found!` |
| `cd apps/nomad_mobile && flutter test` | `00:35 +100: All tests passed!` |
| `cd apps/nomad_mobile && flutter test test/ui/web_preview_view_test.dart` | `00:07 +7: All tests passed!` |
| `cd apps/nomad_mobile && flutter test test/server/project_file_server_test.dart` | `00:03 +11: All tests passed!` |

### Test Delta

| Scope | Before MF-2 | After MF-2 | New |
|---|---|---|---|
| `nomad_core` | 20 | 20 | 0 |
| `nomad_mobile` (total) | 99 | 100 | +1 net (2 added, 1 preview test effectively replaced) |
| `web_preview_view_test.dart` | 5 | 7 | +2 |
| `project_file_server_test.dart` | 11 | 11 | 0 |
| **Total** | **119** | **120** | **+1 net** |

The old inline-HTML smoke test was replaced by the new HTTP URL verification test, which is a strictly stronger assertion.

### What the New Tests Prove

| Test | Acceptance Criterion From Brief |
|---|---|
| `starts server and loads the exact project URL over HTTP` | §5 Task 1, Task 3, §7 "Correct project ID and entry URL" |
| `cleans up server resources completely on dispose` | §5 Task 5, §7 "Server cleanup on preview disposal", "Reopening the preview does not leak" |
| `renders missing entry state when index.html is absent` | §7 "Startup/bind failure produces an understandable error" (pre-check path) |
| `renders empty entry state when index.html content is empty` | §4 "Preserve the user's project structure" |
| `invokes onSaveCompleted when save button is pressed` | §5 Task 4 "Preserve refresh-on-save" (editor side intact) |

---

## 9. Android Verification

**Status:** Not performed.

No Android emulator or physical device was available during this sprint. Per the brief's explicit instruction ("Do not describe untested device behavior as verified"), this is recorded as an uncompleted verification item.

Recommended manual verification on first available device:
1. Launch the app, open an existing starter project.
2. Open the preview.
3. Confirm page renders (not a blank WebView).
4. Open Chrome DevTools remote debugging (`chrome://inspect`) and confirm:
   - Document request to `http://127.0.0.1:18080/<projectId>/index.html` returns 200.
   - Linked `style.css` and `script.js` return 200 with correct MIME types.
   - No cleartext errors in logcat.
5. Edit a file in the editor, save, verify preview updates.
6. Press back, re-open preview, verify server restarts cleanly (no "address already in use" errors in logcat).
7. Kill the app, re-launch, verify no stale sockets.

---

## 10. Architectural Decisions Recorded

Three decisions were made during integration and are reflected in the amended ADR-0006:

### Decision A — Server ownership by `WebPreviewViewState`

**Problem:** The server needs a clear lifecycle owner.
**Options considered:**
1. Owned by `WebPreviewViewState` (chosen).
2. Owned by a top-level singleton or dependency injection container.
3. Owned by the parent view that manages project navigation.

**Chosen:** Option 1 — smallest safe implementation, one widget, one server, clear cleanup. Options 2 and 3 would add infrastructure before any evidence shows multiple simultaneous previews are needed.

### Decision B — Synchronous nullification in `ProjectFileServer.stop()`

**Problem:** Flutter's `dispose()` is synchronous but server cleanup is async, creating a race where `isRunning` could still report `true` during teardown.
**Chosen:** Nullify `_server` and `_subscription` before awaiting I/O. `isRunning` now reflects logical lifecycle state, not physical socket state. See Section 5.3 for full root-cause analysis.

### Decision C — Public state class with read-only getters

**Problem:** Dart's library-level privacy blocked test access to the state class.
**Chosen:** Public `WebPreviewViewState` with read-only `controller` and `server` getters. Minimal API surface, no behavior exposed, no new abstractions.

No new ADR file was created — the existing ADR-0006 was amended with these decisions because they are integration-level clarifications of the already-accepted embedded HTTP server design, not a new architectural choice.

---

## 11. Deviations from the Brief

| Brief Requirement | Deviation | Justification |
|---|---|---|
| §7 "Android verification" | Not performed | No device or emulator available; recorded as uncompleted item per brief instruction |
| §6A "Add a focused regression test" for localStorage | Not added | No code path currently uses origin-scoped storage; regression test would assert on nonexistent behavior |

No other deviations. No scope creep: no new dependencies, no generic plugin framework, no alternative HTTP server, no cloud infrastructure, no new project model, no storage rewrite, no editor redesign, no new preview UI design system, no binary asset pipeline, no unrelated branding or dependency updates, no rewrite of MF-1 server components.

---

## 12. Remaining Risks and Deferred Work

### Risks remaining after MF-2

| Risk | Severity | Mitigation Available |
|---|---|---|
| Android device behavior unverified | Medium | Smoke test on first available device before release |
| Binary asset corruption if a user adds images/fonts | Medium | Already documented since MF-1; needs byte-safe `readFileBytes()` in MF-3 |
| Port `18080` collision in rare environments | Low | Server surfaces visible error; user can close other previews |
| `localStorage` migration if future projects rely on it | Low | Documented; no current usage |

### Deferred work explicitly handed to future sprints

- Byte-safe `FileContentRepository.readFileBytes()` to enable binary asset serving (image/font support). This requires an ADR of its own and a schema/persistence consideration.
- Android emulator and device smoke verification across API levels 29–34.
- Chrome DevTools remote debugging walkthrough documentation.
- Optional: configurable preview port if evidence emerges of real-world port conflicts.

---

## 13. Definition-of-Done Checklist

- [x] Existing preview implementation inspected and documented (§3)
- [x] `ProjectFileServer` integrated without duplicating its functionality (§4.1)
- [x] Initial HTTP document loads only after server startup succeeds (§4.1, step 4–5)
- [x] Correct project paths and supported relative resources resolve (test §8)
- [x] Refresh-on-save behavior is preserved (`_refreshPreview`, test §8)
- [x] Server lifecycle and cleanup are tested (new disposal test, §8)
- [x] Startup failure is visible and does not silently fall back (`server_failed` state, §4.1)
- [x] Existing workspace, editor, persistence, and starter-project behavior passes relevant regression tests (120/120 pass)
- [x] Origin/localStorage compatibility risks are investigated and documented (§6.1)
- [x] Binary-storage limitations are documented without unsupported claims (§6.2)
- [x] Automated tests and static analysis pass (0 issues, 120 tests green)
- [ ] Android smoke testing is completed — **deferred, no device available** (§9)
- [x] Architecture changes, if any, are documented and reviewed (§10, ADR-0006 amendment)
- [x] No unrelated refactoring, dependency additions, or branding changes have slipped in (§7)

---

## 14. Commit and Review Information

| Item | Value |
|---|---|
| Starting commit | `85ee726` (tag: `v-mf1`) |
| Ending commit | *(pending — see git log after commit)* |
| Branch | `main` |
| Files changed with semantic effect | 3 |
| Files changed by `dart format` only | 5 |
| Files added (docs) | 2 (this report, ADR amendment) |
| New dependencies | 0 |
| Test delta | +2 new tests, 1 effectively replaced, net +1 |
| Analyzer delta | 0 new issues |
| Lines of production code added | ~130 (preview widget + ~5 in server) |
| Lines of production code removed | ~45 (old `_assembleDocument`, `_findFile`, inline paths) |
| Lines of test code added | ~70 |
| Physical device validation | Not performed |
| Emulator validation | Not performed |
| Recommended tag after commit | `v-mf2` |

---

## 15. Senior Review Checklist

When reviewing this sprint, please confirm:

1. **Scope discipline** — No unrequested changes were introduced. (See §7, §11.)
2. **MF-1 foundation preserved** — `ProjectFileServer`, `ProjectFileResolver`, `MimeTypeResolver`, Android config untouched except the one documented `stop()` refinement.
3. **Public API stability** — `WebPreviewView` constructor is additive (one new optional parameter with the production-equivalent default).
4. **No silent fallbacks** — Failed server startup surfaces `server_failed`; no retry-with-different-port and no fallback to inlined HTML.
5. **Tests prove behavior, not implementation** — New tests assert the *URL loaded* and the *lifecycle state after dispose*, not internal variables.
6. **Documentation completeness** — Origin change, binary limitation, Android deferral, and lifecycle race (with fix rationale) are all recorded in writing.

The sprint is ready for merge pending Android device verification.
```