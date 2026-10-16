# D7 — LC-2 Implementation Plan

**Sprint:** LC-2 (LAN Chat Implementation)  
**Scope:** Vanilla JS Reusable Transport Driver + LAN Chat Reference Project  
**Estimated Effort:** 1 Sprint  

---

## 1. Implementation Task Breakdown

### Phase 1: Reusable Transport Driver (`nomad-transport.js`)
* Implement `NomadTransport` class complying with D4 Contract.
* Implement SDP serialization / base64 compact packaging.
* Implement ICE candidate gathering with fallback timeout.
* Implement structured JSON message framing, parsing, and error guards.
* Implement `beforeunload` teardown hooks.

### Phase 2: LAN Chat Reference Application
* Create `apps/nomad_mobile/assets/starter_projects/lan_chat/`:
  * `index.html`: Responsive layout with Connection Banner, Token Exchange Modal, and Chat Stream.
  * `style.css`: Clean mobile-first UI themed to match Nomad design tokens.
  * `app.js`: Application logic binding DOM events to `NomadTransport`.

### Phase 3: Verification & Device Validation
* Execute D5 Test Protocol across two physical Android devices on local hotspot.
* Verify clean teardown, disconnect states, and zero impact on `ProjectFileServer`.

---

## 2. File Blast Radius & Safety

| File Target | Action | Risk |
|---|---|---|
| `ProjectFileServer.dart` | **NO CHANGE** | Zero |
| `WebPreviewView.dart` | **NO CHANGE** | Zero |
| `AndroidManifest.xml` | **NO CHANGE** | Zero |
| `network_security_config.xml` | **NO CHANGE** | Zero |
| `pubspec.yaml` | **NO CHANGE** | Zero |
| Project Workspace Files (`.html`, `.js`, `.css`) | **NEW ASSETS ONLY** | Zero host impact |
