# LC-3 — Background & Foreground Connection Recovery Plan

**Sprint:** LC-3 (Reliability Micro-Sprint)  
**Target Assets:** `nomad-transport.js`, `app.js`, `style.css`, `index.html`, `nomad_transport_source.dart`  
**Date:** 
2026-10-12 03:32:31

---

## 1. Problem Statement

When Android backgrounds Nomad or suspends the WebView:
1. Networking/socket processing may pause or drop UDP packets.
2. `RTCPeerConnection` or `RTCDataChannel` may temporarily report `disconnected` or `connecting`.
3. Prematurely treating temporary OS suspension as permanent failure destroys connection state.
4. Reloading the web page destroys the WebRTC local credentials, forcing an unnecessary full re-handshake.

---

## 2. Proposed State Machine & Recovery Architecture

### New State Extension: `reconnecting`

We extend the 5-state lifecycle model (`idle`, `connecting`, `connected`, `disconnected`, `failed`) with an explicit recovery phase:

```text
                       +---------------------+
                       |      connected      |
                       +---------------------+
                          │               ▲
      Page Hidden /       │               │ Grace Period Success
      Temporary Interrupt │               │ (resumed & ready)
                          v               │
                       +---------------------+
                       |    reconnecting     |
                       +---------------------+
                          │
                          │ Grace Period Timeout (5s) OR
                          │ ConnectionState == "failed" / "closed"
                          v
                       +---------------------+
                       |       failed        | (Shows "Reconnect" UI Action)
                       +---------------------+
```

---

## 3. Implementation Steps

1. **Page Visibility Observer in `nomad-transport.js`:**
   - Listen for `document.addEventListener("visibilitychange", ...)`
   - On `hidden`: Start background grace timer (5000ms default). Transition state to `reconnecting` if WebRTC state drops.
   - On `visible`: Inspect connection states (`peerConnection.connectionState`, `iceConnectionState`, `dataChannel.readyState`).
   - If `dataChannel.readyState === "open"`, cancel grace timer and transition back to `connected`.
   - If `dataChannel.readyState !== "open"`, perform active probe send or wait for grace timer expiry.
2. **Reconnect Action in `app.js` & `index.html`:**
   - Add a "Reconnect" button/banner when state enters `failed` or `disconnected`.
   - Preserves chat transcript and DOM state without refreshing the page.
   - Allows restarting the Host or Join token exchange cleanly.
3. **Update Embedded Source & Verify Tests:**
   - Mirror updates in `nomad_transport_source.dart`.
   - Run Flutter test suite to verify 0 regressions.
