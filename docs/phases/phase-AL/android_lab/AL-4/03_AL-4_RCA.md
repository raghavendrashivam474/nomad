# Nomad Android Lab — Root Cause Analysis (RCA)
**Document ID:** AL-4-RCA-01  
**Sprint Classification:** Reliability Engineering, Root Cause Analysis, Lifecycle Hardening  
**Target Baseline:** AL-3 (commit `1872ae3`)  
**Status:** Approved & Verified  

---

## 1. Executive Summary
During Sprint AL-3, on-device Android builds initiated from the Kotlin editor in Nomad exhibited two primary failure modes:
1. **Persistent Loading / Apparent Hang:** Initiating a build displayed a static circular loading indicator that did not update progress or terminate in a timely manner.
2. **Artifact Discard on Successful Build:** When Gradle succeeded on the companion daemon, the resulting APK was deleted immediately after transfer due to a hardcoded placeholder SHA-256 hash (`'_'`).

This RCA provides evidence-backed analysis for these defects and five contributing secondary failure mechanisms.

---

## 2. Primary Root Causes

### RCA-01: Unbounded Network Stream Operations in `CompanionBuildProvider`
* **Component:** `apps/nomad_mobile/lib/android_build/providers/companion_build_provider.dart`
* **Defect:** In multiple asynchronous operations (`getCapabilities`, `build` submission, status polling, and artifact streaming), timeouts were placed only on `httpClient.getUrl()` / `httpClient.postUrl()`, but **NOT** on the critical `req.close()` and `utf8.decodeStream()` futures.
* **Mechanism:** In Dart's `dart:io` `HttpClient`, `getUrl()` only creates the request object. The actual TCP socket transmission, TLS/handshake negotiation, server processing, and HTTP header retrieval occur on `req.close()`. If the remote daemon (or loopback socket) accepts the TCP handshake but delays or stalls header transmission, `await req.close()` suspends the Dart async event loop indefinitely.
* **Evidence:** Code analysis of `companion_build_provider.dart`:
  ```dart
  // Vulnerable pattern:
  final statusReq = await httpClient.getUrl(...).timeout(Duration(seconds: 3));
  final statusRes = await statusReq.close(); // NO TIMEOUT - CAN HANG FOREVER
  final statusBody = await utf8.decodeStream(statusRes); // NO TIMEOUT - CAN HANG FOREVER

```

* **Severity:** Critical
* **Corrective Action:** Wrap every discrete HTTP stage (`req.close()`, response body streaming, artifact download pipe) in bounded `Future.timeout()` handlers and propagate structured communication errors.

### RCA-02: Hardcoded Checksum Placeholder in `agent.dart` Rejecting Real Artifacts

* **Component:** `experiments/android_lab_on_device/companion_agent/agent.dart` (lines 225-230)
* **Defect:** `agent.dart` assigned `job.apkSha256 = '_';` as a placeholder instead of computing the real cryptographic SHA-256 digest of the produced `.apk` file.
* **Mechanism:**
1. The client requested `GET /api/v1/builds/{jobId}/status`.
2. The server responded with `{"status": "success", "apkSha256": "_"}`.
3. Client's `_downloadAndStoreArtifact()` received `expectedSha256 = '_'`.
4. Client computed the real SHA-256 hash (e.g., `9f83...61a2`) and evaluated `actualSha256 != expectedSha256` (`"9f83..." != "_"` -> `true`).
5. Client threw a `StateError('APK SHA-256 mismatch! Expected: _, Actual: ...')`.
6. The error was caught by `catch (_) { return null; }`, which silently deleted the temp file and returned `null`.
7. Client controller concluded the build succeeded without an APK artifact (`_lastArtifact == null`).


* **Evidence:** `experiments/android_lab_on_device/companion_agent/agent.dart`:
```dart
// Length and size verification
job.apkSha256 = '_';
job.apkByteSize = bytes.length;
job.apkPath = producedApk.path;
job.status = 'success';

```


* **Severity:** Critical
* **Corrective Action:** Implement genuine SHA-256 digest computation in `agent.dart` and standalone package configuration (`pubspec.yaml` with `crypto`).

---

## 3. Secondary & Contributing Defects

### RCA-03: Lack of Live Progress Feedback in Status Poll Loop

* **Component:** `CompanionBuildProvider` & `AndroidBuildController`
* **Defect:** During Gradle compilation (which takes 30s to 3m on mobile ARM64 devices), the polling loop silently waited without notifying listeners or updating `statusMessage` with recent Gradle log lines or compilation duration.
* **Impact:** The user perceived the application as frozen or crashed during legitimate compilation work.
* **Corrective Action:** Emit live progress / status message updates during the poll loop.

### RCA-04: Quadratic Buffer Allocation in Agent Log Capture

* **Component:** `agent.dart`
* **Defect:** On every chunk received from `proc.stdout` and `proc.stderr`, `agent.dart` converted the entire accumulated `StringBuffer` to string and concatenated it (`job.log = _truncate('${stdoutBuf.toString()}\n${stderrBuf.toString()}');`).
* **Impact:** On high-output Gradle runs (e.g., Kotlin compiler warnings/dependencies), memory allocation scaled quadratically, stalling the agent's event loop.
* **Corrective Action:** Decouple chunk ingestion from log serialization and cap buffer sizes cleanly.

### RCA-05: Missing Cancellation UI Affordance in `EditorView`

* **Component:** `apps/nomad_mobile/lib/ui/editor_view.dart`
* **Defect:** When `controller.isBusy` was `true`, the build action button was replaced with a non-interactive `CircularProgressIndicator`, preventing the user from cancelling an in-flight build.
* **Corrective Action:** Provide an interactive cancel action or cancel tooltip in the editor action bar.

---

## 4. Verification Matrix

| RCA ID | Reproduction Test | Regression Guard |
| --- | --- | --- |
| **RCA-01** | Stalled mock socket test | `CompanionBuildProviderTest` with hanging socket triggers bounded timeout. |
| **RCA-02** | Artifact download test with mock agent | Verify `actualSha256 == expectedSha256` succeeds and stores APK in `ArtifactManager`. |
| **RCA-03** | Progress event listener test | Verify `AndroidBuildController` emits progress messages while polling. |
| **RCA-04** | High-volume log load test | Companion agent streams 5000 lines without latency spike. |
| **RCA-05** | Editor widget test | Cancel button cancels active build and returns controller to idle/cancelled. |

```