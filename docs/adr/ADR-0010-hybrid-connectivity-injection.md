# ADR-0010: Hybrid Connectivity Capability Delivery & Virtual System Routing

## Status
Proposed / Pending Implementation

## Context
In Sprint LC-2, Nomad introduced `nomad-transport.js` as a WebRTC DataChannel connectivity driver. Currently, projects must manually include `nomad-transport.js` in their workspace files. This introduces friction for developers:
1. Copying `nomad-transport.js` into every project workspace creates clutter and maintenance overhead.
2. Forgetting to include the file causes `404 Not Found` resource failures inside `ProjectFileServer` and crashes WebPreviewView JS runtime with `Uncaught ReferenceError`.
3. Relying *only* on host JS injection breaks standard web conventions and makes projects non-portable outside Nomad.

We require an unkillable delivery mechanism that delivers 100% developer convenience without breaking web standards or workspace overrides.

---

# Decision

Implement a **4-Tier Hybrid Delivery Architecture** for project connectivity:

### Tier 1: Virtual System Route (`/_nomad/transport.js`) — Primary Delivery

* `ProjectFileServer` intercepts requests matching `/_nomad/transport.js` or `/*/_nomad/transport.js`.
* Serves the built-in `nomad-transport.js` driver directly from host memory (`nomad_transport_source.dart`).
* **Content-Type:** `application/javascript; charset=utf-8`.
* **Cache-Control:** `no-cache, no-store, must-revalidate`.

### Tier 2: Workspace Override Priority — Developer Override

* Before serving from the virtual system route for a relative file request (`nomad-transport.js`), `ProjectFileResolver` checks if the project workspace contains a user-created `nomad-transport.js`.
* If a local file exists, the user's workspace version takes priority over the system version.

### Tier 3: Host Auto-Inject Guard — Safety Net

* In `WebPreviewView.dart`, when `onPageFinished` fires, the host executes a light guard script via `controller.runJavaScript`:
```javascript
if (typeof window.NomadTransport === 'undefined') {
  /* Inject built-in driver string */
}

```


* If the developer forgot to include `<script src="/_nomad/transport.js"></script>` in their HTML, the host safely injects it into global window scope as a fallback.

### Tier 4: Idempotent JS Execution Guard — Duplication Prevention

* At the top of `nomad-transport.js`, an idempotency check prevents re-declaration:
```javascript
if (typeof window !== 'undefined' && window.NomadTransport) {
  // Already defined — skip execution
} else {
  // Define NomadTransport
}

```



---

## Technical Specifications & Blast Radius

### Files Added:

* `apps/nomad_mobile/lib/server/nomad_transport_source.dart`
* Holds the immutable bundled JavaScript source string in Dart.



### Files Modified (Minimal Blast Radius):

* `apps/nomad_mobile/lib/server/project_file_server.dart` (~12 lines added)
* Intercepts `/_nomad/` requests and routes to `NomadTransportSource`.


* `apps/nomad_mobile/lib/ui/web_preview_view.dart` (~8 lines added)
* Adds `onPageFinished` fallback injection guard.


* `apps/nomad_mobile/assets/starter_projects/lan_chat/nomad-transport.js` (2 lines added)
* Wraps definition in idempotency check.



---

## Consequences

### Positive:

* **Zero Boilerplate:** Users can write `<script src="/_nomad/transport.js"></script>` OR write 0 script tags at all — it works either way.
* **Zero 404 Errors:** Forgotten files will never crash the preview again.
* **100% Web Compliant & Portable:** Exported projects work on standard web servers.
* **Deterministic Execution:** Eliminates race conditions for script order.

### Negative / Trade-offs:

* Modifies `ProjectFileServer` routing slightly to recognize the reserved system prefix `/_nomad/`.

---

## Verification Criteria

* Web project using `<script src="/_nomad/transport.js"></script>` loads driver successfully via `ProjectFileServer` (200 OK).
* Web project with NO script tags gets auto-injected by `WebPreviewView` on page finish without JS errors.
* Web project with custom workspace `nomad-transport.js` overrides system driver.
* All existing 119 unit/widget tests in `nomad_core` and `nomad_mobile` continue to pass with 0 regressions.