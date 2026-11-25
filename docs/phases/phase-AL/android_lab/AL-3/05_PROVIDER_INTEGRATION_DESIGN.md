# Nomad AL-3: Production Provider Integration Design

## 1. Architectural Strategy

The design preserves:

* `AndroidBuildController` public API (methods, properties, and change notifications).
* Existing UI listeners (`BuildDiagnosticsSheet`, `WorkspaceView`, `EditorView`).
* Local host builds on desktop workstations.
* Host platform sandbox rejection in `AndroidBuildService`.

---

## 2. Ingestion Architecture

```text
[ AppShell / WorkspaceView ]
            │
            ▼
[ AndroidBuildController ]
            │
            ▼
   [ BuildOrchestrator ]
            │
    ┌───────┴───────────────────────┐
    ▼                               ▼
[ LocalHostBuildProvider ]    [ CompanionBuildProvider ]
    │ (desktop only)                │ (loopback HTTP)
    ▼                               ▼
[ AndroidBuildService ]       [ Termux Daemon 127.0.0.1:8089 ]
```

---

## 3. Provider Selection Priority

* **On Desktop (Windows/macOS/Linux):** `LocalHostBuildProvider` is preferred.
* **On Mobile (Android/iOS):**
  * Probes `CompanionBuildProvider`.
  * If available on loopback port `8089`, uses it for compilation, snapshot upload, and artifact retrieval.
  * If unavailable, emits diagnostic: *"No on-device build provider available. The Nomad Companion Daemon was not detected on 127.0.0.1:8089. Please start the companion agent in Termux."*