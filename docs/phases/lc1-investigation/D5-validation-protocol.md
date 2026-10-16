# D5 — Validation Protocol & Test Procedure

**Sprint:** LC-1  
**Purpose:** Define the offline two-device validation protocol for WebRTC DataChannel transport in LC-2.

---

## 1. Test Environment Requirements

1. **Hardware:** Two independent Android devices (Device A and Device B).
2. **Network:** Same Wi-Fi network OR one device hosting a Wi-Fi Hotspot with the second connected to it.
3. **Internet State:** Router disconnected from WAN (or Mobile Data disabled on Hotspot) to prove 100% offline independence.
4. **App Build:** Standard Nomad debug build running on both devices.

---

## 2. Test Execution Protocol

| Step | Action | Expected Result | Pass Criteria |
|---|---|---|---|
| **T1: Discovery & Token Gen** | Device A opens LAN Chat project, clicks "Host", generates Offer Token. | Offer token displayed in text box. Host ICE candidates gathered within 2s. | Non-empty base64 token generated without STUN error. |
| **T2: Handshake Exchange** | Device B pastes Offer Token into "Join", clicks "Connect", copies Answer Token. Device A pastes Answer Token into "Accept". | State transitions: `idle` -> `connecting` -> `connected` on both devices. | Status badge turns GREEN (`connected`) on both screens. |
| **T3: Bidirectional Text** | Device A sends "Hello B". Device B sends "Hello A". | Messages render instantly in respective chat streams. | Zero message drops, correct sender labels and timestamps. |
| **T4: Boundary / Size Test** | Send 32 KB text block. | Delivered without truncation or frame error. | Payload intact. |
| **T5: Clean Teardown** | Device A closes preview or clicks "Disconnect". | Device B reflects state transition to `disconnected`. Sockets released. | No lingering connection or memory leak. |
| **T6: Preview Non-Regression** | Open multi-file CSS/PNG project preview. | Assets load normally from `ProjectFileServer`. | 100% preview functionality intact. |

---

## 3. Unverified Claims / Known Residual Risks

* **AP Isolation Risk:** Some institutional Wi-Fi networks block client-to-client UDP. (Mitigation: Use phone hotspot).
* **Local ICE Gathering Timeout:** In airplane mode with only Wi-Fi enabled, candidate gathering must resolve `host` IP promptly.
