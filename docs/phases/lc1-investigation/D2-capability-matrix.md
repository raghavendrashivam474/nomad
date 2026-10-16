# D2 — Capability Validation Matrix

**Generated:** 2026-10-11 13:42:59
**Evidence basis:** Source inspection (Blocks 2a-2d), Android config analysis, documented Chromium WebView behavior.
**Classification key:**
- **Confirmed** — Direct evidence from target environment or source code.
- **Source-confirmed** — Supported by inspected source/config, not physically tested on device.
- **Unverified** — Not tested; evidence insufficient to confirm or deny.
- **Unavailable** — Tested or proven not to work under stated constraints.

---

## 1. WebView Runtime Capabilities

These assess whether the JavaScript APIs exist inside the WebView at all.

| Capability | Classification | Evidence |
|---|---|---|
| JavaScript execution | **Confirmed** | `JavaScriptMode.unrestricted` at web_preview_view.dart:68 |
| `fetch()` API | **Source-confirmed** | webview_flutter ^4.10.0 uses Android system WebView (Chromium 70+). `fetch()` has been available since Chrome 42. Unrestricted JS mode permits its use. |
| `WebSocket` API | **Source-confirmed** | Chromium WebView supports WebSocket since Chrome 16. Available in unrestricted mode. |
| `RTCPeerConnection` API | **Source-confirmed** | Chromium WebView supports WebRTC since Chrome 56 (Android 7.0+). `webview_flutter: ^4.10.0` targets modern Android. Requires `android.permission.INTERNET` (present). |
| `RTCDataChannel` API | **Source-confirmed** | Available alongside RTCPeerConnection since Chrome 57. |
| `navigator.mediaDevices` | **Source-confirmed** | API exists in Chromium WebView. However, no camera/microphone permissions are declared. Not needed for text-only DataChannel but required for some ICE candidate gathering paths. |
| `XMLHttpRequest` | **Source-confirmed** | Legacy API, available in all Chromium versions. Subject to same network restrictions as `fetch()`. |

## 2. Network Reachability

These assess whether traffic from the WebView can actually reach another device on the LAN. This is where the critical blockers live.

| Capability | Classification | Evidence |
|---|---|---|
| HTTP to loopback (127.0.0.1) | **Confirmed** | `network_security_config.xml` explicitly permits cleartext to `127.0.0.1` and `localhost`. ProjectFileServer binds to loopbackIPv4 (project_file_server.dart:41). Preview loads successfully. |
| HTTP to LAN IPs (192.168.x.x, 10.x.x.x) | **Unavailable** | `network_security_config.xml` has NO `<base-config>` element. Default Android behavior (API 28+) denies cleartext to all domains not explicitly listed. Only loopback is listed. **Any `fetch()` or `WebSocket` to a LAN IP over plain HTTP will be blocked by the Android network stack.** |
| HTTPS to LAN IPs | **Unverified** | The cleartext restriction does not apply to TLS connections. If a LAN server presented a valid (or self-signed + trusted) certificate, HTTPS traffic would pass. However, no HTTPS infrastructure exists in Nomad, and certificate management on local-only devices is complex. |
| WebRTC SRTP/DTLS to LAN peers | **Source-confirmed (theoretical)** | WebRTC media and data channels use DTLS-SRTP, which is encrypted. The Android cleartext policy does NOT apply to DTLS traffic — it only governs HTTP/HTTPS. WebRTC connections to LAN peers should bypass the cleartext restriction entirely. **This is the strongest argument for Option 1.** |
| UDP traffic (ICE candidates) | **Unverified** | WebRTC ICE gathering requires UDP. The `INTERNET` permission covers both TCP and UDP. However, the actual ICE candidate types (host, srflx, relay) depend on the device's network configuration and NAT. No STUN/TURN server is available (constraint: no cloud services). |

## 3. Peer Discovery Capabilities

How would two Nomad devices find each other on the same Wi-Fi?

| Capability | Classification | Evidence |
|---|---|---|
| Programmatic LAN IP discovery (Dart) | **Unavailable** | `ACCESS_WIFI_STATE` and `ACCESS_NETWORK_STATE` permissions are NOT declared in AndroidManifest.xml. Dart's `NetworkInterface.list()` may work with just `INTERNET` on some Android versions but is unreliable without `ACCESS_NETWORK_STATE`. |
| Programmatic LAN IP discovery (JS) | **Unavailable** | Browser JS has no API to read the device's own IP address. `RTCPeerConnection` ICE candidates can leak local IPs, but this is browser-dependent and increasingly restricted for privacy. |
| User-mediated IP exchange | **Source-confirmed** | No technical blocker. Users can read their IP from Wi-Fi settings and type/paste it into the app. Clunky but functional for a first prototype. |
| mDNS / DNS-SD discovery | **Unavailable** | No `NSD` (Network Service Discovery) API usage in Nomad. Would require native Android code and new permissions. Out of scope for LC-1/LC-2. |
| QR code exchange | **Unverified** | Could encode connection details (IP, offer SDP) in a QR code. Would require camera permission and a QR library — both are new dependencies. Out of scope unless separately approved. |

## 4. Native Bridge Capabilities

| Capability | Classification | Evidence |
|---|---|---|
| `NomadDiag` JS channel (JS → Dart) | **Confirmed** | Installed at web_preview_view.dart:106. One-way: JS calls `NomadDiag.postMessage(json)`. |
| `NomadDiag` payload scope | **Confirmed** | Strictly validated JSON: `level`, `message`, `details`, `source`, `line`, `column`. 4096-byte ceiling. ADR-0009 explicitly states: "cannot be abused as an arbitrary native command bridge." |
| `NomadDiag` as signaling channel | **Unavailable** | One-way only (JS→Dart). No Dart→JS response path through this channel. Designed for diagnostics, not data transport. Repurposing would violate ADR-0009's security contract. |
| Dart → JS execution | **Source-confirmed** | `WebViewController.runJavaScript()` is available in webview_flutter ^4.x. Nomad could push data into the WebView by calling JS functions. However, this is host→project, not peer→peer. |
| Bidirectional native bridge | **Unverified** | Could be built using `addJavaScriptChannel` (JS→Dart) + `runJavaScript` (Dart→JS). Would require new Dart code and a new channel name. Not currently implemented. |

## 5. Existing Infrastructure Reuse

| Component | Reusable for LAN transport? | Evidence |
|---|---|---|
| `ProjectFileServer` | **No** | Loopback-only (L41), GET/HEAD only (L73), no WebSocket, no CORS, `shared: false`. ADR-0006 confirms preview-only scope. |
| `ProjectFileResolver` | **No** | Resolves logical paths to FileNode hierarchy. No relevance to network transport. |
| `MimeTypeResolver` | **No** | Extension-to-MIME mapping. No relevance. |
| `WebPreviewView` | **Partial** | Provides the WebView runtime and JS execution environment. The transport consumer will run *inside* this WebView as project JavaScript. The view itself does not need modification. |
| `ActivityController` | **No** | In-memory diagnostic event holder. No transport relevance. |
| `NomadDiag` channel | **No** | Diagnostic-only, one-way, size-limited, security-constrained per ADR-0009. |

---

## Summary: What Can Actually Carry Data Between Two Devices?

| Transport | Viable? | Blocker |
|---|---|---|
| HTTP fetch to LAN server | **No** | Cleartext policy blocks plain HTTP to non-loopback addresses |
| WebSocket to LAN server | **No** | Same cleartext blocker (ws:// is cleartext) |
| WSS (WebSocket Secure) to LAN | **Theoretically** | Requires TLS cert management — complex, no existing infra |
| WebRTC DataChannel | **Most viable** | Encrypted (DTLS), bypasses cleartext policy. Needs signaling solution. |
| Native Dart socket (TCP/UDP) | **Theoretically** | Would require new Dart code, new permissions, new JS bridge. Heavy lift. |
| Bluetooth / Wi-Fi Direct | **No** | No permissions, no APIs, massive scope. Out of bounds. |

