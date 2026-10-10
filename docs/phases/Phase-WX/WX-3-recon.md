# WX-3 Reconnaissance — Event-Source Map

**Sprint:** WX-3 — Live Activity
**Baseline:** `v-wx2` (commit 1d72ef5)
**Branch:** `sprint/wx-3`
**Author:** WX-3 implementation
**Status:** Pre-implementation inspection

---

## 1. Confirmed baseline facts

- Working tree clean on `main` at tag `v-wx2`.
- `flutter test`: **138/138 passing**.
- `flutter analyze`: 4 pre-existing `deprecated_member_use` infos in
  `lib/ui/workspace_view.dart` (Radio API). **Not in WX-3 scope.** WX-3
  must not introduce any *new* analyzer issues.
- WebView plugin in use: **`webview_flutter`** (official), with
  `webview_flutter_android` and `webview_flutter_wkwebview` platform impls.
- No existing `ChangeNotifier` / `ValueNotifier` / `Stream` / `Riverpod` /
  `Bloc` usage was found in `apps/` or `packages/`.
- Error typing: `FileResolutionResult` / `FileResolutionSuccess` /
  `FileResolutionFailure` already exist in
  `lib/server/project_file_resolver.dart`.

---

## 2. Signals already observable (reuse)

| Signal                        | Source                                                                 | Current behavior                                 | WX-3 use                              |
|------------------------------|------------------------------------------------------------------------|--------------------------------------------------|--------------------------------------|
| Page load started            | `WebPreviewView` -> `NavigationDelegate.onPageStarted`                 | `debugPrint` only                                | Emit `lifecycle` info event          |
| Page load finished           | `WebPreviewView` -> `NavigationDelegate.onPageFinished`                | `debugPrint` only                                | Emit `lifecycle` info event          |
| WebView resource error       | `WebPreviewView` -> `NavigationDelegate.onWebResourceError`            | `debugPrint` only                                | Emit `resource` warning/error event  |
| File resolution failure      | `ProjectFileServer` -> branch on `FileResolutionFailure` (line ~115)   | Returns HTTP response; details discarded post-send | Emit `resource` error event with `FileResolutionErrorType` |

All four hook points already exist. WX-3 does **not** need to add any new
callback registrations to `webview_flutter` for lifecycle/resource events.

---

## 3. Signals NOT currently observable (gap analysis)

| Signal                       | Status                                               | Decision for WX-3                                                |
|-----------------------------|------------------------------------------------------|------------------------------------------------------------------|
| JavaScript runtime errors    | Not captured. `webview_flutter` 4.x on this project does not expose `onConsoleMessage`. | Add a **narrow, validated** `JavaScriptChannel` named `NomadDiag` that only accepts `{level, message, source?, line?, col?}` JSON. Enforced max payload size. No arbitrary native commands. Covered by ADR-0009 if introduced. |
| JavaScript warnings          | Same as above                                        | Same bridge handles `level: "warn"`.                             |
| HTTP response status for resource requests from inside the page | Not observable from `webview_flutter` API. Only top-level nav errors + our own server logs. | Represent only what the embedded `ProjectFileServer` observes. Document the limitation. **Do not fabricate.** |

---

## 4. Proposed event model (initial, minimal)

File: `apps/nomad_mobile/lib/activity/activity_event.dart` (new, small)

```dart
enum ActivityCategory { lifecycle, resource, runtime }
enum ActivitySeverity { info, warning, error }

class ActivityEvent {
  final String id;              // monotonic / UUID-ish
  final DateTime timestamp;
  final ActivityCategory category;
  final ActivitySeverity severity;
  final String message;         // short summary
  final String? details;        // optional long form (preserved original)
  final String? sourceUri;      // optional file / URL
  final int? line;              // optional nav location
  final int? column;
  final int sessionId;          // preview session; discards stale callbacks
}
```

No `freezed`, no new dependency. Immutable via `final` fields and a
`const`-friendly constructor.

## 5. Proposed state holder (minimal)

File: `apps/nomad_mobile/lib/activity/activity_controller.dart` (new)


* `class ActivityController extends ChangeNotifier`
    - `List<ActivityEvent> get events` (unmodifiable view)
    - `void add(ActivityEvent e)` — enforces bounded history (default 200)
    - `void dismiss(String id)`
    - `void clear()`
    - `int get currentSessionId`
    - `void beginSession()` — increments session id; does not clear history
    - `void dispose()` — notifier teardown

**Rationale**: `ChangeNotifier` is in `package:flutter/foundation.dart` — zero
new dependencies, matches Flutter idioms, trivially testable, trivially
disposable. See ADR-0009 (to be drafted) for the "first notifier" decision.

## 6. Proposed file-change list (narrow)

New (small, scoped):

- `lib/activity/activity_event.dart`
- `lib/activity/activity_controller.dart`
- `lib/activity/activity_bounded_history.dart` (optional helper if list grows)
- `lib/ui/activity/live_activity_panel.dart`
- `lib/ui/activity/activity_tile.dart`
- `test/activity/activity_event_test.dart`
- `test/activity/activity_controller_test.dart`
- `test/ui/activity/live_activity_panel_test.dart`
- `test/fixtures/activity/ok.html`
- `test/fixtures/activity/throws.html`
- `test/fixtures/activity/missing_resource.html`
- `test/fixtures/activity/noisy.html`
- `docs/adr/ADR-0009-activity-state-and-diagnostic-bridge.md` (if JS bridge is used)

### Modified (minimal diffs, additive): 

- `lib/ui/web_preview_view.dart` — accept optional ActivityController;
translate existing onPageStarted/Finished/WebResourceError into events.
Optionally install NomadDiag JS channel if WX-3C uses the bridge.
- `lib/server/project_file_server.dart` — accept optional sink/callback for
FileResolutionFailure reporting. No HTTP contract change.
lib/app/app_shell.dart — mount LiveActivityPanel responsively,
preserving WX-1 keyboard behavior and WX-2 divider.     

### Untouched (regression-protected):

- `project_file_resolver.dart` (consume existing types only)
- All existing workspace file ops
- All existing WX-1/WX-2 widgets and dividers


## 7. Explicit non-goals (do not implement in WX-3)

* No terminal, shell, or REPL.
* No build engine / compiler.
* No persistent event storage (in-memory only).
* No remote telemetry / analytics.
* No AI diagnosis.
* No general-purpose JS->native command bridge. The NomadDiag channel,
  if added, accepts only diagnostic payloads and performs structural
  validation + size limits.
* No new dependencies.

## 8. Risk register

| Risk | Mitigation |
| :--- | :--- |
| Stale `onPageFinished` from previous preview | `sessionId` guard; `beginSession()` on each load |
| Unbounded growth from noisy page | Bounded ring buffer (default 200) with newest-preserved eviction |
| Malformed JS bridge payload | `try/catch` + size cap + schema check; drop silently with `debugPrint` |
| Divider / keyboard regression | Mount panel outside the WX-2 divider column; widget tests for both layouts |
| New analyzer warnings | CI check: `flutter analyze` must not increase issue count |
| Cross-project leakage | `sessionId` is tied to preview load; UI filters stale |


## 9. Exit from recon

* Implementation may begin once this document is committed. First
* implementation block is the event model (WX-3A, Block 3).
