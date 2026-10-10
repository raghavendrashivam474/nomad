# MF-2 Post-Completion Report: Preview Integration

**Sprint:** MF-2 — Preview Integration: From Static HTML Rendering to a Working Local HTTP Preview
**Baseline:** MF-1 (`v-mf1`, commit `85ee726`)
**Status:** ✅ Complete
**Date:** 2025-07-13

---

## 1. Summary of Implementation

MF-2 integrated the existing `ProjectFileServer` (built in MF-1) into the
`WebPreviewView` widget. The preview no longer inlines CSS and JavaScript into
a single HTML string. Instead, it starts a local loopback HTTP server, loads
the project's `index.html` via `http://127.0.0.1:<port>/<projectId>/index.html`,
and lets the WebView's browser engine resolve CSS, JavaScript, and other
resources through normal HTTP requests.

Key changes:
- Replaced `loadHtmlString()` + `_assembleDocument()` with `loadRequest()` over
  the embedded HTTP server.
- Added server lifecycle management (start on init, stop on dispose, restart on
  project switch).
- Added a `_loadToken` guard to discard stale async callbacks after project
  switches or widget disposal.
- Refined `ProjectFileServer.stop()` to nullify internal references immediately
  before awaiting I/O cleanup, ensuring `isRunning` reflects the logical state
  synchronously.
- Added `serverPort` parameter (default `18080`) to `WebPreviewView` for
  testability (ephemeral port `0` in tests).
- Made `WebPreviewViewState` public with read-only `controller` and `server`
  getters for test verification.

---

## 2. Files Changed and Why

### Substantive changes

| File | Change |
|------|--------|
| `apps/nomad_mobile/lib/ui/web_preview_view.dart` | Full integration: server lifecycle, HTTP loading, error states, token guard, public state class |
| `apps/nomad_mobile/lib/server/project_file_server.dart` | Refined `stop()` to set `_server = null` and `_subscription = null` before awaiting async cleanup |
| `apps/nomad_mobile/test/ui/web_preview_view_test.dart` | Added HTTP URL verification test, server cleanup test; updated existing tests with `serverPort: 0`; fixed platform controller cast |

### Formatting-only changes (dart format)

| File |
|------|
| `apps/nomad_mobile/lib/server/mime_type_resolver.dart` |
| `apps/nomad_mobile/lib/server/project_file_resolver.dart` |
| `apps/nomad_mobile/test/server/mime_type_resolver_test.dart` |
| `apps/nomad_mobile/test/server/project_file_resolver_test.dart` |
| `apps/nomad_mobile/test/server/project_file_server_test.dart` |

No changes to `nomad_core`, `pubspec.yaml`, Android configuration, or branding.

---

## 3. Tests Added or Modified

### New tests (in `web_preview_view_test.dart`)

- **`starts server and loads the exact project URL over HTTP`** — Verifies that
  `loadRequest()` is called with `http://127.0.0.1:<port>/proj-123/index.html`.
- **`cleans up server resources completely on dispose`** — Verifies that
  `server.isRunning` becomes `false` after the widget is removed from the tree.

### Modified tests

- All existing `WebPreviewView` widget tests now pass `serverPort: 0` to use
  ephemeral ports, preventing port conflicts in CI.
- Test stub `TestPlatformWebViewController` now tracks `lastLoadedUri` from
  `loadRequest()` calls.

### Regression coverage

- All 11 existing `ProjectFileServer` tests continue to pass unchanged.
- All 20 `nomad_core` tests continue to pass unchanged.
- All 88 other `nomad_mobile` tests continue to pass unchanged.

---

## 4. Commands Executed and Results

```text
### nomad_core
cd packages/nomad_core
flutter analyze # No issues found!
flutter test # 00:01 +20: All tests passed!

### nomad_mobile
cd apps/nomad_mobile
flutter analyze # No issues found!
flutter test # 00:35 +100: All tests passed!
```

**Total: 120 tests passing, 0 failures, 0 analysis issues.**

---

## 5. Android Device/Emulator Verification

⚠️ **Not performed.** No Android emulator or physical device was available in
the current development environment. This is recorded as an uncompleted
verification item per the sprint brief.

Manual smoke testing on a real device or emulator is recommended before
release to verify:
1. WebView renders the HTTP-served page correctly.
2. CSS and JavaScript load via relative URLs.
3. Cleartext loopback traffic is permitted by the existing network security
   configuration.

---

## 6. Architectural Decisions

### Decision 1: Server ownership by WebPreviewViewState

**Problem:** The server needs a clear lifecycle owner.
**Decision:** `WebPreviewViewState` owns the `ProjectFileServer` instance.
It creates the server on `initState()` (or project change), and stops it in
`dispose()`. No global server manager or service registry was introduced.
**Rationale:** Smallest safe implementation. One owner, one server, clear
cleanup. A shared server can be introduced later if multiple simultaneous
previews are needed.

### Decision 2: Synchronous state nullification in `stop()`

**Problem:** `dispose()` is synchronous but `HttpServer.close()` is async.
The test observed `isRunning == true` immediately after disposal because
`_server` was still non-null during the async close.
**Decision:** `stop()` now captures `_server` and `_subscription` into local
variables and sets the fields to `null` *before* awaiting the async cleanup.
**Rationale:** `isRunning` reflects the logical intent (server is shutting
down) immediately, while the socket closes cleanly in the background. This
prevents stale state without blocking the widget lifecycle.

### Decision 3: Public state class for testability

**Problem:** Dart's library-level privacy (`_` prefix) prevented tests from
inspecting the server and controller state.
**Decision:** Renamed `_WebPreviewViewState` to `WebPreviewViewState` and
exposed read-only `controller` and `server` getters.
**Rationale:** Minimal API surface increase. The getters are read-only and
only useful for testing. No new abstraction layer was introduced.

---

## 7. Known Limitations and Deferred Issues

### Origin change (localStorage compatibility)

The old preview used `baseUrl: 'https://localhost/'`. The new preview uses
`http://127.0.0.1:18080/`. These are different origins. Any `localStorage`
or `sessionStorage` data written by the old preview will not be accessible
from the new preview.

**Impact:** Low. The current starter projects do not use browser storage.
**Decision:** No migration implemented. Documented for future reference.
If a project relies on stored data, the user will need to re-initialize it.

### Binary asset limitations

`FileContentRepository.readFile()` returns `String`, and the resolver
UTF-8 encodes it to bytes. This works correctly for text-based resources
(HTML, CSS, JS, JSON, SVG) but may corrupt binary files (PNG, JPEG, fonts).

**Impact:** Low for MF-2 scope. Current starter projects use only text
resources.
**Decision:** No storage rewrite. Binary asset support should be addressed
in a future sprint with a reviewed architectural proposal.

### Fixed port (18080)

The default port remains `18080`. If the port is occupied, the server
reports a visible error (`server_failed` state). No silent fallback port
was implemented, per the sprint brief.

---

## 8. Commit Information

- **Baseline:** `85ee726` (tag: `v-mf1`)
- **Branch:** `main`
- **MF-2 changes:** Uncommitted at time of report (ready for commit)
- **Recommended tag:** `v-mf2` after commit

---

## 9. Discrepancies

No discrepancies between local and remote branch state at baseline.
The local working tree contains the MF-2 changes ready for commit and push.

---

## 10. Acceptance Criteria Checklist

- [x] Existing preview implementation inspected and documented.
- [x] `ProjectFileServer` integrated without duplicating its functionality.
- [x] Initial HTTP document loads only after server startup succeeds.
- [x] Correct project paths and supported relative resources resolve.
- [x] Refresh-on-save behavior is preserved.
- [x] Server lifecycle and cleanup are tested.
- [x] Startup failure is visible and does not silently fall back.
- [x] Existing workspace, editor, persistence, and starter-project behavior
      passes relevant regression tests (120/120).
- [x] Origin/localStorage compatibility risks are investigated and documented.
- [x] Binary-storage limitations are documented without unsupported claims.
- [x] Automated tests and static analysis pass (0 issues, 120 tests green).
- [ ] Android smoke testing is completed — **deferred, no device available**.
- [x] Architecture changes are documented (see Section 6).
- [x] No unrelated refactoring, dependency additions, or branding changes.
