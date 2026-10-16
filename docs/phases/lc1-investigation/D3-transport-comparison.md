# D3 — Transport Architecture Comparison

**Sprint:** LC-1 (Connectivity Foundation & Transport Validation)  
**Date:** 2025-07-12  
**Target Environment:** Nomad Android WebView (Chromium runtime on Android)  
**Constraints Applied:** No cloud servers, no third-party libraries, no laptop/terminal workflows, vanilla web UI, zero unauthorized modifications to existing preview server.

---

## 1. Candidate Overview

We evaluate three potential architectural paths for local two-device communication:

1. **Option 1 — Direct WebRTC DataChannel (Browser-Level P2P):**
   Runs entirely inside the WebView via standard WebRTC JavaScript APIs (`RTCPeerConnection`, `RTCDataChannel`). DTLS-SRTP encryption handles transport. Signaling is performed without cloud infrastructure (user-mediated SDP exchange).

2. **Option 2 — Nomad-Hosted LAN WebSocket Server (Dart Host-Level):**
   A dedicated Dart `HttpServer` / WebSocket listener bound to `InternetAddress.anyIPv4` (0.0.0.0) or the device's LAN IP. The WebView connects to this server across the local network.

3. **Option 3 — Native Dart Raw Sockets + Bidirectional JS Bridge:**
   Nomad Dart host opens raw TCP/UDP sockets (`dart:io Socket` / `RawDatagramSocket`) and exposes a bespoke messaging bridge into the WebView via `addJavaScriptChannel` and `runJavaScript`.

---

## 2. Detailed Candidate Evaluation

### Option 1: Direct WebRTC DataChannel

* **Evidence Support:**
  - `webview_flutter: ^4.10.0` uses modern Android Chromium WebView (supporting WebRTC DataChannel since Chrome 57).
  - `JavaScriptMode.unrestricted` is active in `WebPreviewView`.
  - Android `INTERNET` permission is declared in `AndroidManifest.xml`.
* **Peer Discovery:**
  - In a cloudless, zero-dependency environment, automated mDNS discovery is not available inside the browser sandbox.
  - Discovery is user-mediated: Device A and Device B share network presence out-of-band (e.g. being on the same Wi-Fi / hotspot).
* **Signaling / Connection Setup:**
  - Step 1: Device A creates an Offer SDP + gathers host ICE candidates.
  - Step 2: Full session description (SDP string) is copied or presented (e.g. text / compressed token).
  - Step 3: Device B pastes the Offer, creates an Answer SDP, and gathers candidates.
  - Step 4: Device A pastes the Answer. WebRTC DTLS handshake completes directly over local UDP.
  - *No cloud STUN/TURN server required for direct LAN/hotspot connections between two devices on the same subnet.*
* **Internet Independence:** 100% offline. DTLS peer-to-peer over local Wi-Fi or mobile hotspot.
* **Host Component Required:** None. Runs 100% in project JavaScript.
* **Permissions & Configuration Impact:** **Zero.** No manifest changes, no network security changes. WebRTC DTLS traffic bypasses Android cleartext HTTP restrictions.
* **Security & Lifecycle:**
  - Communication is end-to-end encrypted via DTLS.
  - Sandbox isolation: Project JS has no access to native host filesystem or OS.
  - Teardown is deterministic: `peerConnection.close()` frees local sockets.
* **Limitations:**
  - Manual signaling UX (copy-pasting SDP or token exchange) requires multi-step user interaction to initiate.
  - Relies on Chromium WebView properly generating local host ICE candidates without external STUN.

---

### Option 2: Nomad-Hosted LAN WebSocket Server

* **Evidence Support:**
  - Dart `dart:io` contains full `HttpServer` and `WebSocketTransformer` support.
  - However, `ProjectFileServer` is strictly bound to `127.0.0.1` and cannot be reused (ADR-0006).
* **Peer Discovery:**
  - Requires Device A (host) to know and display its local LAN IP (e.g. `192.168.1.50:8080`).
  - Without `ACCESS_WIFI_STATE` permission, Dart cannot reliably determine its Wi-Fi IP programmatically on modern Android; user must check OS settings.
* **Signaling / Connection Setup:**
  - Device A starts Dart LAN WebSocket server.
  - Device B's WebView connects via `new WebSocket('ws://192.168.1.50:8080')`.
* **Internet Independence:** 100% offline (LAN/hotspot).
* **Host Component Required:** Substantial. A new Dart LAN server service, lifecycle management, port binding, and WebSocket router.
* **Permissions & Configuration Impact:** **CRITICAL BLOCKER.**
  - `network_security_config.xml` permits cleartext *only* to `127.0.0.1` and `localhost`. Android blocks cleartext `ws://192.168.x.x` by default.
  - To make this work, `network_security_config.xml` would require widening (`cleartextTrafficPermitted="true"` or IP range exceptions).
  - May require `ACCESS_NETWORK_STATE` and `ACCESS_WIFI_STATE` in `AndroidManifest.xml`.
* **Security & Lifecycle:**
  - Opens unencrypted listening port on LAN. Any device on the Wi-Fi could connect to Nomad.
  - Must manage server start/stop across app lifecycle, pauses, and backgrounding.
* **Limitations:**
  - Requires multiple architectural alterations (manifest, network security, new Dart server architecture).
  - Violates constraint of zero-config, low-surface changes for LC-1/LC-2.

---

### Option 3: Dart Native Sockets + Bidirectional Native Bridge

* **Evidence Support:**
  - Dart `dart:io` supports `RawDatagramSocket` (UDP) and `ServerSocket` (TCP).
  - `WebViewController` supports `addJavaScriptChannel` (JS→Dart) and `runJavaScript` (Dart→JS).
* **Peer Discovery & Signaling:**
  - Dart could send UDP broadcast packets on the subnet for automated peer discovery.
* **Internet Independence:** 100% offline.
* **Host Component Required:** Massive. Nomad would have to build:
  1. Native UDP/TCP socket manager in Dart.
  2. A new custom IPC protocol bridging JS calls to Dart sockets.
  3. Dart-to-JS event streaming mechanism.
* **Permissions & Configuration Impact:**
  - Requires adding `CHANGE_WIFI_MULTICAST_STATE` and network state permissions for UDP broadcast.
  - High blast radius across Flutter/Dart architecture.
* **Security & Lifecycle:**
  - Bypasses web platform security models.
  - Exposes native networking primitives to project JS if not rigorously restricted.
* **Limitations:**
  - Far exceeds the scope of a minimal reusable foundation.
  - High maintenance overhead and complex debugging across the bridge.

---

## 3. Side-by-Side Comparison Matrix

| Criteria | Option 1: WebRTC DataChannel | Option 2: Dart LAN WebSocket Server | Option 3: Dart Native Socket Bridge |
|---|---|---|---|
| **Feasibility Under Current Config** | **High** (Native WebView capability) | **Blocked** (Cleartext policy forbids LAN HTTP/WS) | **Medium** (Requires extensive new Dart bridge) |
| **Android Manifest Changes** | **0** (Uses existing `INTERNET`) | **1–2** (`ACCESS_WIFI_STATE`, etc.) | **2–3** (Multicast, Network state) |
| **Network Security Config Changes** | **0** (DTLS is encrypted) | **1** (Must permit LAN cleartext) | **0** (Bypasses WebView HTTP stack) |
| **Dart / Nomad Core Code Changes** | **0** (Runs in Project JS) | **High** (New server module + lifecycle) | **Very High** (Socket engine + JS bridge) |
| **Existing Preview Server Impact** | **Zero** (`ProjectFileServer` untouched) | **Zero** (Requires parallel server) | **Zero** (Separate subsystem) |
| **Offline LAN / Hotspot Operation** | **Yes** (Direct P2P over Wi-Fi) | **Yes** (Direct LAN IP) | **Yes** (UDP/TCP broadcast) |
| **External / Cloud Dependencies** | **None** | **None** | **None** |
| **Connection Setup Complexity (UX)** | Medium (Manual SDP/token exchange) | Low (Enter IP:Port) | Zero (Automated UDP discovery) |
| **Architectural Reusability** | **High** (Standard Web Standards API) | Medium (Nomad-specific HTTP protocol) | Low (Proprietary Nomad JS bridge) |
| **Estimated Implementation Scope (LC-2)** | **Small & Contained** (Project JS only) | **Medium–Large** (Dart + Config + JS) | **Very Large** (Native + Dart + IPC + JS) |

---

## 4. Conclusion & Recommendation

* **Option 2 (LAN WebSocket)** is **architecturally blocked** by Android's default cleartext policy in `network_security_config.xml` unless authorized to amend platform security configs.
* **Option 3 (Native Socket Bridge)** introduces unnecessary architectural weight and violates the principle of using standard web platform primitives.
* **Option 1 (Direct WebRTC DataChannel)** is the **clear recommended path**:
  1. It operates 100% within the standard web platform available in the existing unrestricted WebView.
  2. It requires **zero changes** to AndroidManifest.xml, `network_security_config.xml`, `ProjectFileServer`, or Nomad's core Dart code.
  3. It is fully encrypted, offline-capable, and standard-compliant.
