# ADR-0009: Live Activity In-Memory State and Diagnostic Bridge Architecture

## Status
Accepted

## Context
Nomad Sprint WX-3 introduces "Live Activity," a lightweight, contextual activity surface that provides real-time feedback on preview lifecycle events, resource loading failures, and runtime warnings/errors.

Previous sprints (WX-1 and WX-2) established a local-first, lightweight architecture with zero third-party state-management frameworks (e.g., Riverpod, Bloc, Redux). We needed to introduce real-time event aggregation and diagnostic collection while respecting Nomad's non-negotiable architectural constraints:
1. Zero new dependencies.
2. In-memory, bounded retention to protect device RAM from noisy web pages or infinite error loops.
3. Strict session isolation to prevent stale asynchronous callbacks from previous preview loads from contaminating new sessions.
4. A safe, strictly validated diagnostic channel that cannot be abused as an arbitrary native command bridge.

## Decision
1. **In-Memory Bounded State Holder (`ActivityController`):**
   - Implemented as a lightweight `ChangeNotifier` located in `apps/nomad_mobile/lib/activity/activity_controller.dart`.
   - Uses a strict capacity limit (default 200 events) with oldest-first eviction (`removeAt(0)`), guaranteeing that the newest diagnostic errors are never dropped.
   - Implements a monotonic `_sessionId` guard. Each preview load triggers `beginSession()`. Asynchronous callbacks tagged with a mismatched session ID are silently dropped.

2. **Immutable Structured Event Model (`ActivityEvent`):**
   - Events are categorized into three distinct domains: `lifecycle`, `resource`, and `runtime`.
   - Severities are strictly typed (`info`, `warning`, `error`).
   - Distinguishes main-frame loading failures (`error`) from sub-resource 404s (`warning`), ensuring accurate status communication.

3. **Narrow, Validated Diagnostic JavaScript Channel (`NomadDiag`):**
   - Installed on `WebViewController` via `addJavaScriptChannel('NomadDiag')`.
   - Enforces a strict message size ceiling (4096 bytes).
   - Validates JSON structure (`level`, `message`, `details`, `source`, `line`, `column`).
   - Defensive try-catch parsing prevents malformed payloads from crashing the workspace UI or invoking unauthorized native actions.

4. **Workspace and AppShell Integration:**
   - AppShell owns the `ActivityController` lifecycle and passes it down to `WebPreviewView`.
   - Navigation callbacks map event file/line locations to workspace `FileNode` instances, enabling seamless tap-to-source navigation.

## Consequences
- **Positive:**
  - Zero external package dependencies introduced.
  - Predictable, bounded memory profile on mobile devices.
  - Safe against race conditions and stale callbacks across rapid page reloads.
  - Preserves 100% of existing WX-1 adaptive layout and WX-2 panel resizing capabilities.
- **Negative / Limitations:**
  - In-memory only: history is cleared when the project is closed (by design per WX-3 scope).
  - Runtime diagnostics rely on explicit `NomadDiag` channel calls or standard WebView callback hooks.
