# D4 — Reusable Nomad Connectivity Contract

**Sprint:** LC-1  
**Status:** Proposed Architecture Specification  
**First Planned Consumer:** LC-2 (LAN Chat)  
**Target Runtime:** Nomad Android WebView (Vanilla JavaScript ES2020+)

---

## 1. Architectural Boundary & Layering

The connectivity architecture separates application logic from low-level transport details:

```text
+-------------------------------------------------------------------+
|                        Application Layer                          |
|             (e.g., LAN Chat UI, Collaborative Canvas)              |
+-------------------------------------------------------------------+
                                 |
                                 | Consumes NomadTransport API
                                 v
+-------------------------------------------------------------------+
|                   Nomad Connectivity Adapter                      |
|  - Lifecycle State Machine (idle -> connecting -> connected ...)   |
|  - Message Framing & Serialization                                 |
|  - Heartbeat / Keepalive & Teardown Management                    |
+-------------------------------------------------------------------+
                                 |
                                 | Abstract Driver Interface
                                 v
+-------------------------------------------------------------------+
|                     Selected Transport Driver                     |
|           (WebRTC DataChannel Driver / Local Signaling)           |
+-------------------------------------------------------------------+
                                 |
                                 | Standard Web APIs
                                 v
+-------------------------------------------------------------------+
|                 Nomad WebView Sandbox (Android)                   |
|                  RTCPeerConnection / DTLS Sockets                 |
+-------------------------------------------------------------------+
```

---

## 2. Connection Lifecycle & State Transitions

### 2.1 Formal Connection States

The connection state machine defines five distinct states:

* `idle`: Initial uninitialized state. No active peer connection or socket allocated.
* `connecting`: Signaling in progress (gathering candidates, awaiting answer/offer exchange, or negotiating DTLS handshake).
* `connected`: Data channel is open, verified bidirectional, and ready for message transmission.
* `disconnected`: Connection was gracefully terminated by either peer or closed cleanly.
* `failed`: Transport error, ICE negotiation timeout, or unrecoverable network failure.

### 2.2 State Transition Diagram

```text
               +----------------------------------+
               |              idle                |
               +----------------------------------+
                                 |
                        create() / join()
                                 v
               +----------------------------------+
        +----->|           connecting             |<----+
        |      +----------------------------------+     |
        |             |                      |          |
        |     handshake success       handshake failure |
        |             v                      v          |
        |      +--------------+      +--------------+   |
        |      |  connected   |      |    failed    |---+ (retry)
        |      +--------------+      +--------------+
        |             |                      |
  reconnect    close() / lost peer       close()
        |             v                      v
        +------+--------------+      +--------------+
               | disconnected |----->|     idle     |
               +--------------+      +--------------+
```

---

## 3. JavaScript Application Interface Contract

The proposed project-facing interface is defined in plain vanilla JavaScript (with zero external dependencies).

```javascript
/**
 * Proposed NomadTransport Interface Specification
 */
class NomadTransport {
  /**
   * Current connection state: "idle" | "connecting" | "connected" | "disconnected" | "failed"
   * @returns {string}
   */
  get state();

  /**
   * Unique session identifier for the local peer.
   * @returns {string}
   */
  get localPeerId();

  /**
   * Initializes host mode (Device A creates offer).
   * Generates a portable connection token (SDP + ICE candidates).
   * @returns {Promise<string>} Base64/Compressed Offer Token
   */
  async createHostOffer();

  /**
   * Accepts an answer token from Device B to complete the host-side handshake.
   * @param {string} answerToken
   * @returns {Promise<void>}
   */
  async acceptAnswer(answerToken);

  /**
   * Initializes join mode (Device B accepts host offer and produces answer token).
   * @param {string} hostOfferToken
   * @returns {Promise<string>} Base64/Compressed Answer Token
   */
  async joinHost(hostOfferToken);

  /**
   * Sends a structured message payload across the active transport.
   * @param {string} type - Message type discriminator (e.g. "chat.text", "ping")
   * @param {any} payload - JSON-serializable payload object
   * @returns {boolean} - true if queued/sent, false if channel unavailable
   */
  send(type, payload);

  /**
   * Gracefully terminates the connection and releases all sockets.
   */
  disconnect();

  /**
   * Event listener subscription.
   * Supported events:
   *  - "statechange": (newState, previousState) => void
   *  - "message": (envelope) => void
   *  - "error": (errorDetails) => void
   *  - "peer_disconnected": () => void
   */
  on(event, callback);
  off(event, callback);
}
```

---

## 4. Message Framing & Serialization Contract

All transport packets across the underlying WebRTC DataChannel must adhere to a standardized JSON envelope structure:

```json
{
  "v": 1,
  "id": "msg_01hy7q8w9z",
  "type": "chat.text",
  "sender": "peer_a",
  "ts": 1720800000000,
  "payload": {
    "text": "Hello from Device A!"
  }
}
```

### Envelope Fields:
* `v` (integer, required): Protocol version (initially `1`).
* `id` (string, required): Monotonic or UUID message identifier for deduplication.
* `type` (string, required): Domain message identifier (`chat.text`, `system.ping`, `system.ack`).
* `sender` (string, required): Peer identifier.
* `ts` (number, required): Unix timestamp in milliseconds (`Date.now()`).
* `payload` (object, required): Application-specific data.

### Message Integrity & Error Handling:
* **Size Ceiling:** Maximum single message size limited to 64 KB (standard WebRTC DataChannel safe threshold).
* **Malformed Payloads:** Receivers must wrap payload parsing in defensive `try/catch`. Malformed JSON will trigger an `error` event and be dropped without terminating the connection.
* **Type Validation:** Payloads with unknown `type` fields must be safely routed to an unhandled message callback rather than crashing the application.

---

## 5. Teardown & Resource Cleanup Contract

To prevent orphaned sockets, memory leaks, and phantom connections when switching projects or refreshing previews:

1. **Page Unload Hook:**
   The transport driver registers a listener for `window.addEventListener("beforeunload", ...)` and `window.addEventListener("unload", ...)`.
2. **Deterministic Cleanup Routine:**
   ```javascript
   function teardown() {
     // 1. Send best-effort disconnect notification packet
     try { send("system.close", { reason: "unload" }); } catch(_) {}
     // 2. Close DataChannel
     if (dataChannel) { dataChannel.close(); }
     // 3. Close RTCPeerConnection (releases local UDP sockets)
     if (peerConnection) { peerConnection.close(); }
     // 4. Update state
     _transitionState("disconnected");
   }
   ```
3. **Nomad Host Boundary:**
   When `WebPreviewView` reloads or closes, the WebView entire JavaScript execution context is destroyed by Android, releasing all associated OS socket handles.

---

## 6. Security Boundaries

* **No Native OS Exposure:** The connectivity contract operates entirely within the JavaScript standard runtime. It does not introduce any custom native commands to Dart.
* **No File Access:** The transport cannot read, write, or query workspace files directly.
* **End-to-End Encryption:** Direct WebRTC channels mandate DTLS-SRTP encryption by specification.
