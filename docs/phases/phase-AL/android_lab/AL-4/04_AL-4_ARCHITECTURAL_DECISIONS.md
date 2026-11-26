# Nomad Android Lab — Architectural Decisions (AL-4)

* **Document ID:** `AL-4-ADR-01`
* **Sprint Classification:** Reliability Engineering, Lifecycle Hardening
* **Target Baseline:** `AL-3`
* **Status:** Approved

---

## ADR-0012: Bounded Multi-Stage HTTP Execution & Correlation Tracing

### 1. Problem
Network operations between Nomad Mobile and the Companion Daemon lacked stage-level timeout guarantees and end-to-end correlation tracing, making diagnosing transient network failures, hanging sockets, and long-running Gradle jobs difficult.

### 2. Evidence
* `httpClient.getUrl().timeout()` did not protect `req.close()` or `res` stream consumption.
* Lack of correlated build IDs prevented tracing requests from Flutter UI to Termux Gradle logs.

### 3. Decisions
* **Correlation ID:** Every build request generates a unique `buildId` (e.g., `nomad-YYYYMMDD-HHmmss-<nonce>`) included in HTTP headers (`X-Nomad-Build-ID`) and payload.
* **Bounded HTTP Stages:**
  * **Capabilities probe:** `2s` total timeout.
  * **Build submission:** `5s` request close timeout.
  * **Status polling:** `3s` per probe with backoff.
  * **Artifact transfer:** `30s` stream pipe timeout.
* **Structured Diagnostics:** Emits lightweight typed `BuildEvent` objects for state transitions without logging confidential code content.
* **Standalone Companion Package:** Provide a dedicated `pubspec.yaml` in `experiments/android_lab_on_device/companion_agent` declaring `crypto` and `path` to ensure reliable standalone execution in Termux.

### 4. Compatibility & Migration
* Fully backwards compatible with existing `BuildProvider`, `BuildRequest`, `BuildResult`, and `ArtifactManager` contracts.
* No breaking changes to SQLite database schemas or project file structures.