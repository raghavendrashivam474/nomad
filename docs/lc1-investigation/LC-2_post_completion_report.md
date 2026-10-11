# Nomad — Sprint LC-1 & LC-2 Post-Completion Report

## Connectivity Foundation, Transport Validation & LAN Chat Implementation

| Field | Value |
|---|---|
| **Project** | Nomad — Mobile-First Development Lab |
| **Phase** | LC — Local Connectivity Capability |
| **Sprints** | LC-1 (Investigation & Architecture) + LC-2 (Implementation & Validation) |
| **Status** | Complete — Ready for Senior Review |
| **Date** | 2025-07-12 |
| **Baseline** | Post-WX3 (`v-wx2`), branch `main` |
| **Pre-existing tests** | `nomad_core` 20/20, `nomad_mobile` 99/99 — all passing |
| **Post-sprint tests** | `nomad_core` 20/20, `nomad_mobile` 99/99 — all passing, zero regressions |
| **Production files modified** | **0** |
| **Production files added** | **0** |
| **New asset files created** | 4 (under `assets/starter_projects/lan_chat/`) |
| **New documentation files** | 10 (under `docs/lc1-investigation/`) |

---

## 1. Executive Summary

Sprint LC-1 was chartered as a **read-only investigation and validation sprint**. Its mandate was to determine, with source-level evidence rather than assumption, whether Nomad's existing Android WebView execution environment can support direct device-to-device communication between two Nomad instances on the same local network — without cloud infrastructure, new dependencies, or modifications to the existing preview server.

Sprint LC-2 was the **implementation sprint** that followed LC-1's formal architectural decision. It produced the reusable transport driver and a reference LAN Chat application, both running entirely as vanilla JavaScript inside the existing WebView.

### Headline Outcome

**WebRTC DataChannel over local DTLS is the only transport that satisfies all hard constraints without requiring any modification to Nomad's existing Dart code, Android manifest, network security configuration, or dependency manifest.**

Two alternative architectures — a Nomad-hosted LAN WebSocket server and a Dart native-socket bridge — were evidence-rejected during LC-1. The first is blocked at the Android OS network stack level by the cleartext traffic policy in `network_security_config.xml`. The second violates the scope, reusability, and minimal-blast-radius constraints of the sprint.

The LC-2 implementation produced a working, dependency-free WebRTC DataChannel driver (`nomad-transport.js`) and a complete LAN Chat reference application. A dual-peer browser smoke test confirmed the full offer-answer-accept-connected flow and real-time bidirectional messaging on first attempt. On-device Android validation remains the final acceptance gate.

### Change-Safety Confirmation

**Zero existing production files were modified across both sprints.** All new code lives in the starter project assets directory. All investigation artifacts live in the documentation directory. The full Flutter test suite passes unchanged.

---

## 2. Sprint Scope, Mandate, and Hard Constraints

### LC-1 Mandate

Investigate Nomad's existing Android WebView execution environment and determine the smallest safe, reusable architecture for communication between two Nomad instances on the same local network. Produce an evidence-backed architecture decision. Do not implement. Do not modify existing code.

### LC-2 Mandate

Implement the architecture selected by LC-1 as a minimal, reusable connectivity driver and a reference LAN Chat application. Preserve all existing Nomad behavior.

### Hard Constraints (Both Sprints)

These were acceptance constraints, not optional preferences:

1. Use Nomad's existing Android WebView as the target execution environment.
2. Use vanilla HTML, CSS, and JavaScript for the project-facing API and UI.
3. No cloud-hosted signaling, relay, backend, or required internet service.
4. No downloaded tools, additional applications, external libraries, frameworks, or new dependencies.
5. No laptop or terminal-based workflow as a substitute for on-device validation.
6. Do not modify existing files without explicit written authorization.
7. Preserve current project opening, multi-file loading, preview navigation, and existing WebView behavior.
8. Investigate and document before proposing any architectural change.

---

## 3. What Was Inspected (LC-1 Source Investigation)

The following source and documentation targets were inspected in strict priority order. No file outside the dependency chain of these targets was explored.

| # | Target | Path | Lines | Key Finding |
|---|---|---|---|---|
| 1 | `ProjectFileServer` | `apps/nomad_mobile/lib/server/project_file_server.dart` | 147 | Hardcoded loopback bind, GET/HEAD only, no WebSocket |
| 2 | `ProjectFileServer` tests | `apps/nomad_mobile/test/server/project_file_server_test.dart` | 402 | Confirms loopback, 403 on traversal, project isolation |
| 3 | `WebPreviewView` | `apps/nomad_mobile/lib/ui/web_preview_view.dart` | 489 | JS unrestricted, `NomadDiag` channel is diagnostic-only |
| 4 | `AndroidManifest.xml` | `apps/nomad_mobile/android/app/src/main/AndroidManifest.xml` | 47 | Only `INTERNET` permission declared |
| 5 | `network_security_config.xml` | `apps/nomad_mobile/android/app/src/main/res/xml/network_security_config.xml` | 7 | **Cleartext permitted only for loopback — critical blocker** |
| 6 | `pubspec.yaml` | `apps/nomad_mobile/pubspec.yaml` | 30 | `webview_flutter: ^4.10.0`, no networking packages |
| 7 | `ADR-0006` | `docs/adr/ADR-0006-embedded-http-server.md` | 291 | Server is preview-only by architectural decision |
| 8 | `ADR-0009` | `docs/adr/ADR-0009-live-activity-state-and-runtime-diagnostics.md` | 44 | `NomadDiag` cannot be used as a command bridge |

---

## 4. Critical Findings From Source Inspection

### 4.1 `ProjectFileServer` Is Architecturally Sealed

The embedded preview server cannot serve as a LAN transport. This is not a limitation to be worked around — it is a deliberate architectural boundary.

* **Line 41:** `InternetAddress.loopbackIPv4` — the bind address is hardcoded. The server is unreachable from any other device on the LAN.
* **Line 73:** `if (request.method != 'GET' && request.method != 'HEAD')` — all other HTTP methods return 405. No POST, no WebSocket upgrade.
* **Line 43:** `shared: false` — the socket is exclusive. No parallel listener can share port 18080.
* **Line 82:** URL contract is `/<projectId>/<path>` with path-traversal protection and project boundary isolation.
* **No CORS headers, no API routes, no WebSocket support.** The server is a read-only static file pipe.

ADR-0006 explicitly scopes this server to preview serving and states that alternatives will be reconsidered "only when concrete evidence justifies reconsideration." LC-1's investigation does not justify reconsideration — it justifies building a parallel, non-interfering capability in the JavaScript layer.

### 4.2 `WebPreviewView` Provides a Full Browser Runtime

* **Line 68:** `JavaScriptMode.unrestricted` — the full modern Chromium JavaScript API surface is available, including `fetch`, `WebSocket`, `RTCPeerConnection`, and `RTCDataChannel`.
* **Lines 222–223, 241–242:** The WebView loads from `http://127.0.0.1:${_server!.boundPort}`. The origin is loopback, which has cross-origin implications for LAN fetch calls.
* **Line 106:** A single `JavaScriptChannel` named `NomadDiag` is installed. Per ADR-0009, it is one-way (JS→Dart), capped at 4096 bytes, strictly validated, and explicitly forbidden from serving as a general-purpose bridge.
* **`webview_flutter: ^4.10.0`:** Maps to the modern Chromium-based Android System WebView, which supports the full WebRTC API natively.

### 4.3 The Cleartext Policy Blocker (The Most Important Discovery)

`network_security_config.xml` contains exactly seven lines:

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
</network-security-config>
```

There is **no `<base-config>` element**. Under Android API 28+, the absence of a base config means cleartext HTTP traffic is denied by default for all domains not explicitly listed. Only `127.0.0.1` and `localhost` are listed.

**Operational consequence:** Any attempt by the WebView to connect to a LAN IP address via plain HTTP (`http://192.168.1.50:8080`) or plain WebSocket (`ws://192.168.1.50:8080`) will be silently rejected at the Android network stack. The JavaScript layer will receive a generic network error with no indication that the OS blocked the connection.

This single finding disqualified the LAN WebSocket server architecture (Option 2) under the sprint's hard constraints, because making it work would require widening this file — an architectural change explicitly outside LC-1's authority.

### 4.4 Minimal Android Permissions

Only `android.permission.INTERNET` is declared. The following are absent: `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_FINE_LOCATION`, `NEARBY_WIFI_DEVICES`. This means Dart cannot programmatically discover the device's LAN IP, and UDP multicast discovery is unavailable.

### 4.5 ADR Boundaries Respected

* **ADR-0006** confirms `ProjectFileServer` is preview-only. LC-1 did not propose repurposing it.
* **ADR-0009** confirms `NomadDiag` is diagnostic-only with four non-negotiable constraints. LC-1 did not propose widening it.

---

## 5. Transport Architecture Evaluation

Three candidate architectures were evaluated against all hard constraints.

### Option 1 — Direct WebRTC DataChannel (Selected)

Runs 100% inside the WebView as project JavaScript. Uses `RTCPeerConnection` with no ICE servers, gathers local host candidates, and exchanges SDP as compact Base64 tokens via user-mediated copy-paste.

| Constraint | Result |
|---|---|
| Permissions required | **Zero** (uses existing `INTERNET`) |
| Manifest changes | **Zero** |
| Security config changes | **Zero** (DTLS is encrypted, bypasses cleartext policy) |
| Dart code changes | **Zero** |
| Dependency changes | **Zero** |
| Internet dependency | **None** (host ICE candidates are local) |
| Existing preview impact | **None** |
| UX cost | One-time token copy-paste per session |

### Option 2 — Nomad-Hosted LAN WebSocket Server (Rejected)

A new Dart `HttpServer` bound to the LAN interface, with the second device's WebView connecting via `ws://<lan-ip>:<port>`.

**Rejection evidence:**
1. `network_security_config.xml` blocks cleartext to non-loopback addresses. The WebView cannot connect to `ws://192.168.*`.
2. Dart cannot resolve the device's LAN IP without `ACCESS_WIFI_STATE`.
3. Requires a new Dart server component, lifecycle management, and protocol design.
4. Would require an Architecture Change Proposal and modifications to two platform config files.

### Option 3 — Dart Native Sockets + Bidirectional JS Bridge (Rejected)

Dart opens raw TCP/UDP sockets and exposes them to JavaScript through a new native channel.

**Rejection evidence:**
1. Requires `CHANGE_WIFI_MULTICAST_STATE` and network state permissions.
2. Requires designing a bespoke IPC protocol between Dart and JavaScript.
3. Produces a Nomad-proprietary API rather than a standard web platform surface, destroying reusability.
4. High blast radius, high maintenance cost, no measurable benefit over Option 1.

### Formal Decision

**Option 1 is adopted.** No Architecture Change Proposal is required because no existing file needs modification. The decision is recorded in `docs/lc1-investigation/D6-architecture-decision.md`.

---

## 6. What Was Implemented (LC-2)

With LC-1's decision formalized, LC-2 produced four files under `apps/nomad_mobile/assets/starter_projects/lan_chat/`:

### 6.1 `nomad-transport.js` (9.6 KB) — Reusable WebRTC DataChannel Driver

This is the core deliverable: a standalone, dependency-free JavaScript class implementing the D4 Reusable Connectivity Contract.

**What it implements:**
* **`NomadTransport` class** with a five-state lifecycle machine: `idle` → `connecting` → `connected` → `disconnected` / `failed`.
* **`createHostOffer()`** — Creates an `RTCPeerConnection` with no ICE servers, opens a DataChannel, generates an SDP offer, waits for ICE gathering (with a 2.5-second timeout fallback), and returns a compact Base64-encoded token containing the full session description.
* **`joinHost(offerToken)`** — Decodes the host's offer, sets it as the remote description, creates an SDP answer, gathers local ICE candidates, and returns a Base64 answer token.
* **`acceptAnswer(answerToken)`** — Completes the host-side handshake by setting the joiner's answer as the remote description. The DTLS handshake then proceeds automatically over local UDP.
* **`send(type, payload)`** — Wraps application data in the D4 JSON envelope (`v`, `id`, `type`, `sender`, `ts`, `payload`) and sends it over the DataChannel. Enforces a 64 KB payload ceiling.
* **`disconnect()`** — Sends a best-effort `system.close` notification, closes the DataChannel, closes the `RTCPeerConnection`, and transitions to `disconnected`.
* **`on(event, callback)` / `off(event, callback)`** — Event subscription for `statechange`, `message`, `error`, and `peer_disconnected`.
* **Automatic teardown** via `beforeunload` and `unload` listeners to prevent orphaned sockets on page reload or project switch.

**How it works at the network level:**
1. Both devices create an `RTCPeerConnection` with an empty `iceServers` array (no STUN/TURN).
2. The browser's ICE agent gathers `typ host` candidates — the device's local IP on the Wi-Fi/hotspot subnet.
3. The SDP offer/answer (containing these host candidates) is exchanged via user-mediated token copy-paste.
4. The ICE agent connects directly over local UDP using the host candidates.
5. DTLS-SRTP encryption is established automatically (mandated by the WebRTC specification).
6. The DataChannel opens over the encrypted DTLS connection.
7. Because DTLS is encrypted, Android's cleartext traffic policy does not apply.

### 6.2 `index.html` (4.9 KB) — Chat Application Markup

A semantic, mobile-optimized HTML structure with:
* A header bar containing the local peer ID and a live connection status badge.
* A two-tab connection setup panel (Host / Join) with a two-step workflow for each mode.
* A chat panel with a scrollable message stream and a fixed input bar.
* A toast notification overlay for user feedback.

### 6.3 `style.css` (7.8 KB) — Mobile-First Dark Theme

A complete stylesheet using CSS custom properties matching Nomad's design tokens:
* Dark background (`#0d1117`), card surfaces (`#161b22`), and input fields (`#21262d`).
* State-colored status badges (gray for idle, amber for connecting, green for connected, red for failed).
* Chat message bubbles with self/remote alignment and distinct background colors.
* Touch-friendly button targets (minimum 40px tap zones).
* Smooth animations for the connecting spinner and toast notifications.

### 6.4 `app.js` (7.9 KB) — Application Controller

Binds all DOM interactions to the `NomadTransport` driver:
* Tab switching between Host and Join workflows.
* Offer generation, clipboard copy (with fallback for non-HTTPS contexts), and answer acceptance.
* Real-time message stream rendering with sender labels and timestamps.
* State-driven UI transitions (connect panel ↔ chat panel).
* Disconnect confirmation and graceful teardown.

---

## 7. Problems Encountered and Mitigations

### Problem 1: The Cleartext Policy Blocker Was Not Obvious

**What happened.** The intuitive first candidate for LAN communication was "stand up a Dart WebSocket server on the LAN interface." This feels like a natural extension of `ProjectFileServer`. Initial investigation focused on the server code and the manifest, both of which appeared permissive (`INTERNET` permission present, `HttpServer` available in `dart:io`).

**How it was discovered.** Reading `network_security_config.xml` — a 7-line file that is easy to overlook — revealed that cleartext HTTP is permitted only for loopback addresses. The absence of a `<base-config>` element means Android's platform default denies cleartext to all other addresses. This is a network-stack-level block that occurs before the WebView's JavaScript layer sees an error, making it invisible to browser-level debugging.

**How it was mitigated.** The finding was immediately classified as a hard blocker in the D2 Capability Matrix, with a clear separation between "API exists in the browser" and "traffic can actually reach the LAN." This separation became the analytical framework for evaluating all subsequent candidates. Option 1 (WebRTC) was elevated specifically because DTLS encryption bypasses the cleartext restriction without requiring any config change.

### Problem 2: Signaling Without a Cloud Server

**What happened.** Standard WebRTC requires a signaling mechanism to exchange SDP offers, answers, and ICE candidates between peers. Textbook implementations use a WebSocket signaling server, STUN/TURN infrastructure, or a cloud relay — all of which violate the "no cloud, no internet dependency" constraint.

**How it was mitigated.** The signaling exchange was redesigned to be fully user-mediated. The SDP offer and answer are serialized to compact Base64 tokens that users copy between devices manually, exactly once per session. The adapter enforces a bounded ICE-gathering timeout (2.5 seconds) so the token is produced promptly even when the ICE agent does not reach the `complete` state. The dual-peer smoke test confirmed this flow works: three copy-paste operations to establish a connection, after which messaging is instantaneous.

### Problem 3: Cannot Discover the Device's Own LAN IP

**What happened.** For Option 2 to work, the host device would need to display its LAN IP so the joining user could type it in. Dart's `NetworkInterface.list()` requires `ACCESS_WIFI_STATE` on modern Android, which is not declared. Browser JavaScript has no API that reveals the device's own IP address.

**How it was mitigated.** This problem was eliminated when Option 2 was rejected on cleartext grounds. Option 1 does not require either device to know its own IP, because the ICE candidates generated by `RTCPeerConnection` encode the device's local addresses and are embedded directly in the SDP token. The IP discovery problem is solved implicitly by the WebRTC ICE agent.

### Problem 4: The `NomadDiag` Channel Is Tempting but Off-Limits

**What happened.** An existing `JavaScriptChannel` is installed on the WebView. During investigation, the question arose whether it could serve as a signaling relay or a data transport bridge.

**How it was mitigated.** ADR-0009 explicitly prohibits this. The channel is one-way (JS→Dart), capped at 4096 bytes, strictly validated for diagnostic JSON, and the ADR states it "cannot be abused as an arbitrary native command bridge." The capability matrix records `NomadDiag` as transport-ineligible with a direct ADR citation. This prevents future sprints from re-litigating the question without reading the architectural record.

### Problem 5: Two-Device Validation Cannot Be Completed Under LC-1 Constraints

**What happened.** LC-1's hard constraints include "no laptop or terminal-based workflow for the requested validation" and "do not modify existing files without explicit authorization." Under these conditions, physical two-device Android testing was not possible during the investigation sprint.

**How it was mitigated through a three-layer approach:**
1. All transport-feasibility claims in the D2 Capability Matrix are classified as **Source-confirmed**, not **Confirmed**. The report nowhere claims device-level verification where none was performed.
2. A formal six-step validation protocol (D5) was written, specifying the exact environment (two Android devices on shared Wi-Fi or hotspot), the exact test actions, and the exact pass criteria.
3. During LC-2, a browser-based dual-peer smoke test was executed on a workstation. Two Chromium tabs completed the full offer-answer-accept-connected flow and exchanged bidirectional text messages in real time through the exact `nomad-transport.js` driver. This proves the driver's logic is sound but does not substitute for on-device Android validation, which remains the formal acceptance gate.

### Problem 6: PowerShell Tooling Limitations During Investigation

**What happened.** The investigation was executed through a sequence of PowerShell scripts. Several Windows PowerShell 5.1 limitations caused parsing failures: the ternary operator (`? :`) is unavailable (PS 7+ only), `$matches` is a reserved automatic variable that collides with array assignment, and verbatim here-strings containing ampersands or curly apostrophes trigger parser errors.

**How it was mitigated.** Each failure was fixed with a minimal syntactic change: `if/else` blocks instead of ternaries, renamed collection variables (e.g., `$hits` instead of `$matches`), and line-array construction instead of here-strings for content containing special characters. None of these mechanical issues affected the correctness of any finding. All generated documentation was verified after each block.

### Problem 7: Scope Creep Pressure Toward Premature Implementation

**What happened.** Several moments during LC-1 invited premature implementation. The WebView is unrestricted, WebRTC is available, the signaling flow is straightforward. The temptation to "just write the driver" during the investigation was constant.

**How it was mitigated.** The sprint brief's boundary was enforced strictly: LC-1 is validation and design; LC-2 is implementation. The reusable contract (D4) was drafted as a specification, not as code. The driver and the chat application were written only in LC-2, after the architectural decision was formalized and the change-safety audit confirmed zero existing files had been modified. This discipline is what allows this report to claim, with confidence, that both sprints were completed with zero regression risk.

---

## 8. Validation Results

### 8.1 Static Validation (LC-2 Block 3)

A 20-point automated validation suite was executed against all generated files:

| Category | Checks | Result |
|---|---|---|
| File existence | 4 files | 4/4 present |
| HTML cross-references | Script src, CSS href, DOCTYPE, DOM IDs | All 25 JS `getElementById` targets found in HTML |
| JavaScript syntax balance | Braces, parens, brackets for both JS files | All balanced |
| CSS validation | Brace balance, custom properties | 67 rule blocks, 74 variables |
| Git safety | Production file modifications | **Zero** |
| **Total** | **20 checks** | **20/20 PASSED** |

### 8.2 Dual-Peer Browser Smoke Test (LC-2 Block 4)

A local HTTP server was started on `127.0.0.1:8888` and two browser tabs were opened to simulate Device A and Device B.

| Test Step | Action | Result |
|---|---|---|
| T1: Offer generation | Tab 1 clicked "Generate Offer Token" | Base64 token produced within 2 seconds |
| T2: Answer generation | Tab 2 pasted offer, clicked "Generate Answer Token" | Answer token produced within 2 seconds |
| T3: Handshake completion | Tab 1 pasted answer, clicked "Connect" | Both tabs transitioned to `CONNECTED` (green badge) |
| T4: Bidirectional messaging | Typed messages in both tabs | Messages appeared instantly on the opposite tab |
| T5: Teardown | Closed Tab 1 | Tab 2 immediately showed `DISCONNECTED` |
| **Result** | | **All steps passed on first attempt** |

### 8.3 Flutter Test Suite (LC-2 Block 5)

| Package | Tests | Result |
|---|---|---|
| `nomad_core` | 20/20 | **ALL PASSED** |
| `nomad_mobile` | 99/99 | **ALL PASSED** |
| **Regressions** | | **ZERO** |

### 8.4 On-Device Android Validation (Pending)

The formal D5 validation protocol requires two physical Android devices on a shared Wi-Fi network or mobile hotspot. This test has not yet been executed and is the **final acceptance gate** for LC-2. A debug APK build script has been prepared to facilitate this test.

---

## 9. Reusable Connectivity Contract (D4 Summary)

The contract governs how any future Nomad project consumes the connectivity capability:

**Lifecycle states:** `idle` → `connecting` → `connected` → `disconnected` / `failed`

**API surface (vanilla JavaScript, zero dependencies):**
* `createHostOffer()` → Base64 Offer Token
* `joinHost(offerToken)` → Base64 Answer Token
* `acceptAnswer(answerToken)` → completes handshake
* `send(type, payload)` → framed message (64 KB ceiling)
* `disconnect()` → graceful teardown
* `on(event, callback)` → subscribe to `statechange`, `message`, `error`, `peer_disconnected`

**Message envelope:** `{ v, id, type, sender, ts, payload }` — standardized JSON with version, deduplication ID, type discriminator, sender identifier, timestamp, and application payload.

**Security:** End-to-end DTLS encryption (mandated by WebRTC spec). No native OS exposure. No filesystem access. No new Dart↔JS bridge.

**Teardown:** Automatic on `beforeunload`/`unload`. Deterministic socket release via `RTCPeerConnection.close()`.

---

## 10. Deliverables Index

### LC-1 Investigation Artifacts (`docs/lc1-investigation/`)

| ID | File | Purpose |
|---|---|---|
| D1 | `inspection-log.md` | Baseline inventory with source extracts and line references |
| D2 | `D2-capability-matrix.md` | 25+ capabilities classified by evidence category |
| D3 | `D3-transport-comparison.md` | Side-by-side evaluation of all three candidate transports |
| D4 | `D4-reusable-contract.md` | Application-facing API, lifecycle, and message envelope specification |
| D5 | `D5-validation-protocol.md` | Six-step on-device test procedure |
| D6 | `D6-architecture-decision.md` | Formal selection of WebRTC DataChannel with rejection rationale |
| D7 | `D7-lc2-implementation-plan.md` | Bounded implementation plan with explicit file blast radius |
| D8 | `D8-change-safety-report.md` | Git audit confirming zero existing files modified |
| — | `LC-2-completion-report.md` | Post-implementation summary |
| — | `dump-*.txt` / `dump-*.md` | Raw source dumps for offline review |

### LC-2 Implementation Assets (`apps/nomad_mobile/assets/starter_projects/lan_chat/`)

| File | Size | Purpose |
|---|---|---|
| `nomad-transport.js` | 9.6 KB | Reusable WebRTC DataChannel driver |
| `index.html` | 4.9 KB | Chat UI with host/join flow |
| `style.css` | 7.8 KB | Mobile-first dark theme |
| `app.js` | 7.9 KB | Application controller |

---

## 11. Line-Referenced Evidence Index

For the senior reviewer who wants to spot-check findings against the source:

| Claim | File | Line(s) |
|---|---|---|
| Server binds to loopback IPv4 | `project_file_server.dart` | 41 |
| Server port default 18080 | `project_file_server.dart` | 24 |
| Only GET/HEAD accepted | `project_file_server.dart` | 73 |
| URL format `/<projectId>/<path>` | `project_file_server.dart` | 82 |
| Socket exclusive (`shared: false`) | `project_file_server.dart` | 43 |
| `JavaScriptMode.unrestricted` | `web_preview_view.dart` | 68 |
| WebView loads from `127.0.0.1` | `web_preview_view.dart` | 222–223, 241–242 |
| `NomadDiag` channel installed | `web_preview_view.dart` | 106 |
| Only `INTERNET` permission | `AndroidManifest.xml` | 2 |
| No `<base-config>` in security policy | `network_security_config.xml` | entire file |
| Cleartext only for loopback | `network_security_config.xml` | 3–6 |
| `webview_flutter: ^4.10.0` | `pubspec.yaml` | 18 |
| Server scoped to preview (ADR) | `ADR-0006-embedded-http-server.md` | §3.3, §4 |
| `NomadDiag` not a command bridge (ADR) | `ADR-0009-...-diagnostics.md` | §Context 4, §Decision 3 |

---

## 12. Recommendations for Senior Review

1. **Approve the LC-1 architectural decision** as recorded in D6. The evidence trail is complete and no Architecture Change Proposal is required.

2. **Authorize on-device D5 validation.** This requires two Android devices on a shared Wi-Fi network or mobile hotspot and approximately 15 minutes to execute all six test cases. A debug APK build is ready.

3. **Treat `nomad-transport.js` as a reusable Nomad capability**, not a LAN-Chat-specific module. Future projects (collaborative canvas, peer code share, multiplayer utilities) can consume the same driver through the D4 contract by including a single `<script>` tag.

4. **Consider promoting the D4 contract to a formal ADR** once on-device validation passes. The contract is sufficiently stable to warrant an architectural decision record, giving future transport drivers a documented interface to implement against.

5. **No changes to ADR-0006 or ADR-0009 are required.** LC-1's investigation reaffirmed both decisions. The connectivity capability operates entirely within the existing WebView sandbox and does not interact with the preview server or the diagnostic bridge.

---

**End of report.**

**Prepared by:** Junior Developer
**For review by:** Senior Developer
**Recommended action:** Approve LC-1/LC-2 exit gate; authorize on-device D5 validation; proceed to formal sprint sign-off.