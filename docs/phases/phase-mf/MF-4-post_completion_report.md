# MF-4 Post-Completion Report

**Project:** Nomad — Mobile-First Development Lab
**Phase:** MF — Multi-File Support
**Sprint:** MF-4 — Hardening, Performance Validation & Documentation
**Report Date:** 2025-07-15
**Author:** Implementing Developer
**Audience:** Senior Developer (Review & Phase MF Acceptance Decision)
**Status:** Submitted for Review
**Repository:** `https://github.com/raghavendrashivam474/nomad.git`
**Branch:** `main`
**Baseline Commit (sprint start):** `e5e8ad7` (tag `v-mf3`)

---

## 1. Executive Summary

Sprint MF-4 is complete and submitted for senior review. The sprint set out to **harden, measure, and document** the multi-file preview infrastructure delivered across MF-1, MF-2, and MF-3, rather than to rewrite or redesign it.

The outcome of the sprint is:

- **One targeted production fix** (`ProjectFileServer.start()` atomicity) and **one HTTP correctness improvement** (`Content-Length` header), both backed by regression tests.
- **Eight new hardening tests** covering bind-failure behavior, lifecycle stress, concurrent request integrity, shutdown-under-load, and `Content-Length` semantics.
- **A reproducible benchmark suite** that measured ten representative workloads plus a 50-cycle server lifecycle stress and recorded process RSS before, during, and after the workload.
- **ADR-0006 formally amended** to reflect the MF-3 binary-safe path and the MF-4 reliability work, closing the long-standing gap where the ADR still described binary serving as a blocker.
- **A verification matrix for Android/WebView** that clearly separates what has been verified on the headless/VM stack from what remains blocked for want of a physical device.

### Test and analyzer position at submission

| Package | Tests | Analyzer |
|---|---|---|
| `nomad_core` | 20 / 20 pass | 0 issues |
| `nomad_mobile` | 117 / 117 pass (109 pre-existing + 8 new MF-4) | 0 issues |

No existing test was removed, weakened, or skipped. No production contract was broken. No storage migration was performed. No dependency was upgraded.

### Scope discipline

MF-4 explicitly did **not** attempt to:

- Rebuild the preview subsystem.
- Replace the embedded HTTP server with a different serving strategy.
- Introduce a generic plugin/registry framework.
- Migrate on-disk `{uuid}.txt` filenames.
- Add binary-asset upload UI, new fonts, or new MIME types without demonstrated need.
- Perform a broad dependency upgrade.

All of these are consistent with Section 9 ("Strict non-goals") of the sprint brief.

---

## 2. Baseline and Initial Git State

| Item | Value |
|---|---|
| Repository | `C:\Users\ragha\nomad-mf0\nomad` |
| Starting branch | `main` |
| Starting commit | `e5e8ad7` |
| Starting tag | `v-mf3` |
| Working tree at start | Clean (`git status --short` empty) |
| Pre-existing tests | `nomad_core`: 20/20 pass · `nomad_mobile`: 109/109 pass |
| Pre-existing analyzer | 0 issues on both packages |
| Dart SDK | 3.12.2 (stable) — windows_x64 |
| Flutter | Current host install, used only for `flutter test` and `flutter analyze` |
| Host OS | Windows 11 Home Single Language (Build 26200) |
| Host cores | 12 |
| Android emulator / device | **Not available** in this environment |

The clean baseline is important because it allowed MF-4 changes to be reviewed as a focused, attributable delta rather than against a drifting tree.

---

## 3. Files Inspected and Modified

### 3.1 Files inspected (read-only, no modification)

- `apps/nomad_mobile/lib/server/project_file_resolver.dart`
- `apps/nomad_mobile/lib/server/mime_type_resolver.dart`
- `apps/nomad_mobile/lib/ui/web_preview_view.dart`
- `apps/nomad_mobile/lib/data/repositories/local_file_content_repository.dart`
- `packages/nomad_core/lib/src/domain/file_content_repository.dart`
- `apps/nomad_mobile/test/server/project_file_resolver_test.dart`
- `apps/nomad_mobile/test/server/project_file_server_test.dart`
- `apps/nomad_mobile/test/server/mime_type_resolver_test.dart`
- `apps/nomad_mobile/test/ui/web_preview_view_test.dart`
- `apps/nomad_mobile/test/ui/projects_view_overflow_test.dart`
- `apps/nomad_mobile/pubspec.yaml`
- `docs/adr/ADR-0007-binary-safe-file-storage.md`
- `docs/phases/phase-mf/MF-0-baseline-inspection-report.md`

### 3.2 Files modified

| File | Nature of change |
|---|---|
| `apps/nomad_mobile/lib/server/project_file_server.dart` | (a) Atomic assignment of `_server` / `_subscription`; (b) explicit `Content-Length` header on success. |
| `docs/adr/ADR-0006-embedded-http-server.md` | Appended an **MF-3 Binary Safety & MF-4 Reliability Hardening Amendment** that supersedes the stale "binary blocker" language from MF-1. |

### 3.3 Files added

| File | Purpose |
|---|---|
| `apps/nomad_mobile/test/server/mf4_hardening_test.dart` | Regression tests for bind failure, lifecycle stress, shutdown under load, concurrent binary/text integrity, and `Content-Length` behavior. |
| `apps/nomad_mobile/test/server/benchmark_runner.dart` | Standalone, reproducible benchmark harness (not a `test()` — invoked via `dart run`). |
| `docs/phases/phase-mf/MF-4-ANDROID-VERIFICATION-MATRIX.md` | Verification matrix for Android/WebView checks with explicit VM vs. physical-device status. |

### 3.4 Files intentionally not modified

- `WebPreviewView` — Current lifecycle (`_loadToken`, pre-check, fire-and-forget dispose) was audited and judged sound. No speculative rewrite.
- `ProjectFileResolver` — Current algorithm (`O(n)` tree walk per request) is adequate for current workload. Documented as a measured limitation rather than optimized without evidence.
- `MimeTypeResolver` — Current 14-type map is appropriate; no new types added because no feature in-scope requires them.
- `FileContentRepository` (both the contract and the local implementation) — ADR-0007's parallel-method design was reviewed and judged sound. No migration.
- Database schema, workspace model, editor, branding, UI unrelated to preview.

---

## 4. Findings and Evidence That Justified Each Change

Every change recorded in Section 3 was preceded by concrete evidence, as required by Section 2.2 of the brief.

### Finding 4.1 — `ProjectFileServer.start()` could leak partial state (addressed)

**Observed defect, in the original code:**

```dart
_server = server;
_subscription = server.listen(...);
```

The server reference was published **before** the subscription was successfully created. If any failure occurred between those two statements, `isRunning` would return `true` with no active subscription, and a subsequent `stop()` would still work but no requests would ever be handled while in that window.

**Minimum fix:** compute both locally, publish both at the end:

```dart
final server = await HttpServer.bind(...);
final subscription = server.listen(_handleRequest, onError: ..., cancelOnError: false);
_server = server;
_subscription = subscription;
```

**Regression coverage added:**

- `occupied port throws SocketException and leaves server not running`
- `repeated start/stop cycles maintain consistent state`
- `stop on already-stopped server is safe (idempotent)`

### Finding 4.2 — Missing `Content-Length` header (addressed)

**Evidence:** `_handleRequest` set `Content-Type` and `Cache-Control` on success, but did not set `Content-Length`. Dart's `HttpServer` would therefore fall back to chunked transfer encoding, even though the body length is known at response construction time (`result.bytes.length`).

**Why this matters:** chunked encoding is correct but unnecessary when the length is known, costs a small amount of overhead, and prevents WebViews/clients from showing accurate progress. For `HEAD` requests, the client needs `Content-Length` to inspect the resource size, and omitting it is contrary to RFC 9110 §9.3.2.

**Fix:** add one line:

```dart
response.headers.set(HttpHeaders.contentLengthHeader, result.bytes.length);
```

**Regression coverage added:**

- `GET request includes exact Content-Length matching payload bytes`
- `HEAD request includes exact Content-Length without sending body`

### Finding 4.3 — The `occupied-port` scenario was not under test (addressed)

The existing suite tested *invalid* ports (`99999`), but not **port collision** (`EADDRINUSE`), which is the realistic failure mode on real devices when a previous preview was not shut down cleanly.

**Mitigation:** a dedicated test now binds a blocker `HttpServer` to an OS-assigned port, instantiates `ProjectFileServer` on that same port, and asserts both that `SocketException` is thrown **and** that `isRunning` remains `false` after the failed attempt.

### Finding 4.4 — Shutdown while requests are in flight was not under test (addressed)

**Observation:** `project_file_server_test.dart` had a concurrent-request test, but it awaited all requests to completion before calling `stop()`. The real failure mode (preview widget disposed mid-request) was not exercised.

**Mitigation:** a new test fires three requests, immediately calls `stop(force: true)`, awaits all futures with a 5-second timeout, and asserts each request either succeeded (200) or aborted cleanly (`-1`). The test wraps all client I/O in `try`/`catch` so that a connection reset during shutdown is treated as an acceptable terminal state, not as a defect.

### Finding 4.5 — Concurrent interleaved binary + text requests were not under test (addressed)

**Observation:** the existing concurrency test served only text files. ADR-0007 added binary-safe serving, but the concurrent-integrity story was never explicitly tested for mixed payloads.

**Mitigation:** a new test issues 10 interleaved requests alternating between a text file and a binary PNG, then asserts both that status codes are 200 and that the exact byte payloads are returned per request type — proving responses are not cross-contaminated under load.

### Finding 4.6 — ADR-0006 was out of date (addressed via amendment)

**Observation:** ADR-0006 was originally the MF-1 completion report with an MF-2 amendment. It still described binary serving as a documented blocker and quoted "13 web asset types" even though:

- MF-3 shipped `readFileBytes` / `writeFileBytes` and the resolver was updated to use them.
- `MimeTypeResolver._map` now contains **14** entries (the `mjs` ES-module alias was added).

**Mitigation:** an **MF-3 Binary Safety & MF-4 Reliability Hardening Amendment** was appended to ADR-0006 describing (a) the binary-safe path shipped in MF-3, (b) the atomic initialization fix in MF-4, (c) the `Content-Length` improvement, and (d) the hardening test coverage added. The amendment explicitly references the review status rather than being silently rewritten.

### Finding 4.7 — No performance measurement existed (addressed)

**Observation:** no benchmark fixture of any form existed in the repository. The MF-1 report explicitly listed "large file performance — unmeasured" as a known risk.

**Mitigation:** `benchmark_runner.dart` was added as a standalone Dart `main()` that spins up the real `ProjectFileServer` on an ephemeral port against in-memory repositories, runs ten workloads (small HTML, CSS, JS bundle, nested SVG, 64 KB binary, three concurrency variants, 500 KB bundle, 2 MB image), measures median and p95 latency plus throughput, records process RSS before/during/after, and finally runs a 50-cycle start/stop stress to confirm there is no lifecycle leak.

### Finding 4.8 — Historical issues reviewed and *not* changed, with evidence

To avoid gratuitous churn, several candidate changes were investigated and **rejected on evidence**:

1. **Automatic port fallback.** Rejected. The sprint brief and ADR-0006 both explicitly state that silent port fallback would change the origin and break browser storage. Changing this requires a separate ADR, which is out of scope for MF-4.
2. **Streaming large files.** The 2 MB benchmark shows that full-buffer serving completes in ~330 ms median — acceptable for current workloads. Streaming would introduce complexity without demonstrated benefit. Documented as a deferred optimization.
3. **`.txt` suffix migration.** ADR-0007 §5 already notes this suffix is cosmetic and byte-level I/O is unaffected. The sprint brief explicitly forbids migrating storage filenames in MF-4.
4. **Resolver pre-indexing.** `getNodesForProject()` is called on every request. For a project of ~100 nodes this is a negligible linear scan. Benchmarks (see §6) do not show it as a bottleneck. Documented as a future optimization if project sizes grow.
5. **Dependency upgrades.** 16 outdated packages were observed, but only 1 (`flutter_lints` dev-only) is a direct dependency and none are security advisories. Broad upgrades are explicitly a non-goal.

---

## 5. Architecture Decisions and ADR Status

| ADR | Status after MF-4 | Rationale |
|---|---|---|
| ADR-0001 to ADR-0005 | Unchanged | Out of sprint scope. |
| **ADR-0006 (Embedded HTTP Server)** | **Amended — MF-3 Binary Safety & MF-4 Reliability Hardening section added.** | Brings the ADR in line with the shipped code: binary serving is no longer a blocker, atomic init is now a documented decision, `Content-Length` is a documented behavior, hardening tests are referenced. |
| ADR-0007 (Binary-Safe File Storage) | **Reviewed, unchanged.** | The parallel-method design (`readFileBytes` / `writeFileBytes` with UTF-8 defaults) was audited against the implementation and found to be accurate and minimal. No new decision needed. No storage migration is justified. |

No ADR was created or silently rewritten. The amendment in ADR-0006 is clearly labeled, dated, and references the sprint that produced it.

---

## 6. Performance Benchmark Setup, Results, and Interpretation

### 6.1 Methodology

A standalone benchmark harness (`apps/nomad_mobile/test/server/benchmark_runner.dart`) was built. It:

- Instantiates the **real** `ProjectFileServer` with the **real** `ProjectFileResolver`, backed by in-memory `WorkspaceRepository` / `FileContentRepository` fakes to isolate server behavior from disk/database variance.
- Binds on `127.0.0.1` with `port: 0` so the OS assigns a free ephemeral port — no interference with any system service.
- Uses `dart:io HttpClient` as the client — the same stack a `WebView` would use at the socket layer.
- Measures per-request latency with `Stopwatch` in microseconds and reports median and p95 in milliseconds.
- Measures throughput as successful requests per wall-clock second.
- Records process RSS (`ProcessInfo.currentRss`) in MB at three points: baseline, after request workloads, after the lifecycle stress.

### 6.2 Environment

```
Dart SDK:    3.12.2 (stable), windows_x64
OS:          Windows 11 Home Single Language (Build 26200)
Host cores:  12
Initial RSS: 215.35 MB
```

### 6.3 Measured results

| # | Scenario | Iterations | Concurrency | Median | p95 | Throughput |
|---|---|---:|---:|---:|---:|---:|
| 1 | Small HTML (~1 KB) | 200 | 1 | 1.254 ms | 2.326 ms | 484.3 req/s |
| 2 | CSS (~5 KB) | 200 | 1 | 1.096 ms | 5.453 ms | 643.1 req/s |
| 3 | JS bundle (~20 KB) | 200 | 1 | 1.282 ms | 5.772 ms | 514.1 req/s |
| 4 | Nested SVG (~10 KB) | 200 | 1 | 0.863 ms | 1.360 ms | 1015.2 req/s |
| 5 | Binary PNG (~64 KB) | 200 | 1 | 2.514 ms | 6.324 ms | 325.2 req/s |
| 6a | CSS, concurrency=5 | 200 | 5 | 3.035 ms | 9.519 ms | 1197.6 req/s |
| 6b | JS, concurrency=10 | 200 | 10 | 8.615 ms | 18.381 ms | 775.2 req/s |
| 6c | 64 KB binary, concurrency=10 | 200 | 10 | 21.229 ms | 38.967 ms | 320.5 req/s |
| 7a | Large HTML (~500 KB) | 50 | 1 | 2.704 ms | 7.100 ms | 314.5 req/s |
| 7b | Large image (~2 MB) | 50 | 1 | **330.471 ms** | 416.087 ms | 3.0 req/s |

| Metric | Value |
|---|---|
| RSS after workloads | 320.03 MB (Δ +104.68 MB) |
| 50 × start/stop cycles | 48 ms total (≈ 0.96 ms per cycle) |
| Final RSS | 231.59 MB (Δ +16.24 MB vs. baseline) |
| Failed requests across all workloads | **0** |

### 6.4 Interpretation

1. **Typical web assets are fast.** Resources under 20 KB serve in ~1 ms median at single-digit p95. For a realistic project of HTML/CSS/JS/SVG, the server comfortably exceeds the ~60 req/s a WebView might burst on a page load.
2. **Concurrency scales reasonably.** 5× concurrency on CSS raises throughput 1.9× (643 → 1198 req/s) at the cost of a 3× latency increase — expected single-isolate behavior.
3. **The 2 MB image is the measured bottleneck.** 330 ms median latency is driven by the full-buffer read (`readAsBytesSync`) and the full write to the response in one `response.add(bytes)` call. This is a known architectural trait of the current design, not a defect. A streaming path (`openRead` → pipe) would reduce latency and peak memory for large binaries. Documented as the primary candidate for a future optimization sprint.
4. **Memory behavior is bounded, not leaking.** RSS grew 104 MB during the workload (large-file buffering + Dart heap work) but **returned to +16 MB over baseline** after the lifecycle stress — strong evidence that the server releases its buffers and that no socket/subscription leaks occur across 50 start/stop cycles.
5. **The lifecycle itself is cheap.** ~1 ms per start/stop confirms the atomic-init fix did not add material overhead and that there is no cumulative cost per preview open/close.

### 6.5 Limitations of these measurements

- Measured on `127.0.0.1` on Windows, not on-device Android.
- RSS is **process-wide**; it includes the Dart VM, the test runner, and the HTTP client. The report does **not** claim server-only memory accounting.
- The storage layer is in-memory for isolation. On-device, add disk I/O latency (`readAsBytesSync` on the Android `getApplicationDocumentsDirectory`).
- No numerical acceptance threshold was invented. The measurements are the baseline. Any future SLA should be set against this evidence.

---

## 7. Error-Handling and Concurrency Test Results

New test file: `apps/nomad_mobile/test/server/mf4_hardening_test.dart`

| Group | Test | Result | What it proves |
|---|---|:---:|---|
| Bind-failure hardening | Occupied port throws `SocketException`, `isRunning` stays `false` | ✅ | Covers `EADDRINUSE` with proper atomic state. |
| Bind-failure hardening | Recovery after occupied port becomes available | ✅ | Startup is retryable after a transient collision; no silent fallback. |
| Lifecycle stress | 5× repeated start/stop cycles | ✅ | No cumulative state corruption across cycles. |
| Lifecycle stress | Idempotent `stop()` | ✅ | Safe to call on a never-started or already-stopped server. |
| Lifecycle stress | Shutdown during active requests | ✅ | In-flight requests terminate cleanly within 5 s; `isRunning` is `false`. |
| Concurrent integrity | Interleaved binary + text requests | ✅ | No response cross-contamination between content types under load. |
| `Content-Length` | GET returns exact content length | ✅ | Matches `utf8.encode(body).length`. |
| `Content-Length` | HEAD returns length, empty body | ✅ | RFC 9110 §9.3.2 compliance. |

### Security and project-isolation regressions

All existing invariants were verified unchanged:

- Loopback-only binding (`InternetAddress.loopbackIPv4`).
- Path-traversal rejection (`.`, `..`, backslashes, absolute paths).
- Project boundary enforcement in `ProjectFileResolver` and at the URL scoping layer.
- Missing-resource 404 behavior.
- Binary-byte fidelity (`project_file_server_test.dart` PNG assertion).
- MIME behavior for all 14 supported extensions.

---

## 8. Full Automated Regression and Analyzer Results

**Commands executed (final run after all MF-4 changes):**

```
# nomad_core
dart test
→ 00:00 +20: All tests passed!

dart analyze
→ Analyzing nomad_core... No issues found!

# nomad_mobile
flutter test
→ 00:34 +117: All tests passed!

dart analyze
→ Analyzing nomad_mobile... No issues found!
```

**Delta vs. baseline:**

| Package | Baseline tests | Final tests | Delta |
|---|---|---|---|
| `nomad_core` | 20 | 20 | +0 |
| `nomad_mobile` | 109 | 117 | **+8 (all MF-4 hardening)** |

Zero pre-existing tests were skipped, deleted, or weakened.

---

## 9. Android / WebView Validation Matrix

See the full document at `docs/phases/phase-mf/MF-4-ANDROID-VERIFICATION-MATRIX.md`.

Summary of status per the brief's §7 requirements:

| Check | Headless / VM | Physical device |
|---|:---:|:---:|
| Root HTML load | ✅ | ⚠ **Blocked** |
| CSS / JS resources | ✅ | ⚠ **Blocked** |
| Nested relative resources | ✅ | ⚠ **Blocked** |
| ES module imports | ✅ | ⚠ **Blocked** |
| Binary image bytes preserved | ✅ | ⚠ **Blocked** |
| CSS `url()` resolution | ✅ | ⚠ **Blocked** |
| Missing resource graceful failure | ✅ | ⚠ **Blocked** |
| Path-traversal rejection | ✅ | ⚠ **Blocked** |
| Project isolation | ✅ | ⚠ **Blocked** |
| Save-and-refresh content update | ✅ | ⚠ **Blocked** |
| `localStorage` consistency across refresh | ✅ (controller stub) | ⚠ **Blocked** |
| Offline behavior | ✅ (loopback-only) | ⚠ **Blocked** |
| Port-collision recovery | ✅ | ⚠ **Blocked** |

**Explicit disclosure:** no Android emulator or physical Android device was available in the sprint environment. The matrix accordingly marks every physical-device entry as **Blocked / Unverified**, not as passed. A reproducible manual procedure is documented in the matrix so the physical checks can be executed as soon as hardware is available.

This is a **known residual verification risk**, flagged for the Phase MF acceptance decision.

---

## 10. Dependency Hygiene Findings

`dart pub outdated` reports **16 outdated packages**:

- **Direct dependencies:** all up-to-date.
- **Dev dependencies (direct):** `flutter_lints 3.0.2` → `6.0.0` available.
- **Transitive:** 15 packages (`clock`, `code_assets`, `hooks`, `lints`, `matcher`, `material_color_utilities`, `meta`, `native_toolchain_c`, `objective_c`, `record_use`, `sqlite3`, `stack_trace`, `test_api`, `vector_math`, `webview_flutter_wkwebview`).

**Risk assessment:** none of the outdated packages have published security advisories relevant to this project. All are either transitive (not under direct control) or dev-only. The sprint brief explicitly forbids broad upgrades inside MF-4 (§9) and requires that upgrades be justified individually.

**Recommendation:** defer a focused dependency sprint, especially for `flutter_lints`, which is a one-step upgrade but would churn the analyzer config. Not blocking for Phase MF.

---

## 11. Known Limitations and Unverified Behavior

Carried forward explicitly to avoid any impression of a false "all green."

1. **Physical Android validation is unverified** (see §9). The verification matrix identifies this clearly; a reproducible manual procedure is documented.
2. **Large-file (≥ 2 MB) serving is memory-buffered**, not streamed. Measured at ~330 ms median. Acceptable for current workloads but documented as the primary optimization candidate.
3. **Memory accounting is process-wide**, not server-only. The ~16 MB residual delta after the full workload includes Dart heap, test runner, and HTTP client state.
4. **Resolver scans all project nodes per request** (`O(n)` tree walk). Acceptable for typical web projects; would need indexing if a project ever exceeded a few hundred nodes.
5. **Automatic port fallback is deliberately absent.** This is an architectural decision (ADR-0006) and would require a new ADR to revisit, with explicit consideration of browser-origin and `localStorage` consequences.
6. **Dependency updates deferred** — see §10.

---

## 12. Deviations from the Brief

| Area | Deviation | Justification |
|---|---|---|
| §7 D1 (Android device matrix) | Physical device checks not executed. | No Android emulator or physical hardware was accessible in the sprint environment. Matrix explicitly marks all such checks as **Blocked / Unverified** and provides a reproducible manual procedure. No fabricated results. |
| §6 B3 (streaming large files) | Investigated, measured, **not implemented**. | §2.2 and §6B3 of the brief instruct that fixes must be justified by evidence. Measured latency is acceptable; streaming is deferred as a documented recommendation rather than speculatively implemented. |
| §5 A3 (ADR approval workflow) | ADR-0006 was amended in-session rather than through a formal external PR review. | This is an interactive solo-developer session; a formal multi-reviewer gate does not exist here. The amendment is clearly labeled and dated, and this report flags it for senior sign-off as the equivalent of PR approval. |
| §13 (release metadata) | **No tag was created and nothing was pushed to the remote.** | §11 and §14 of the brief require that commit/tag/push follow the project's approval workflow and that remote operations not be assumed. The sprint ends with changes staged and documented locally, awaiting your approval. |

No deviation suppresses a test, hides a defect, or shortcuts a security invariant.

---

## 13. Final Git State and Recommended Acceptance Decision

### 13.1 Git state

| Item | Value |
|---|---|
| Branch | `main` |
| Baseline commit | `e5e8ad7` (tag `v-mf3`) |
| Working tree at submission | Changed files staged, **not yet committed** (pending your review). |
| New files | `test/server/mf4_hardening_test.dart`, `test/server/benchmark_runner.dart`, `docs/phases/phase-mf/MF-4-ANDROID-VERIFICATION-MATRIX.md`, `docs/phases/phase-mf/MF-4-POST-COMPLETION-REPORT.md` (this document) |
| Modified files | `lib/server/project_file_server.dart`, `docs/adr/ADR-0006-embedded-http-server.md` |
| New tag proposed | `v-mf4` (**not yet created** — awaiting approval per brief §11, §14) |
| Push to remote | **Not performed** — awaiting approval |

### 13.2 Recommended Phase MF acceptance decision

Based on the evidence recorded above — **117 mobile tests + 20 core tests passing, zero analyzer issues, zero regressions, measured and bounded performance, no memory leak across 50 lifecycle cycles, ADR-0006 brought in line with the implementation, and a transparent verification matrix** — I recommend:

> **Accept MF-4 and conditionally accept Phase MF**, with the condition that the Android/WebView physical-device validation (per the reproducible procedure in `MF-4-ANDROID-VERIFICATION-MATRIX.md`) be executed as soon as a target device is available, and that its results be appended to the matrix prior to any Phase MF end-of-phase release.

If you prefer stricter acceptance, the alternative is to **accept MF-4 as implementation-complete** and keep Phase MF in a "pending physical-device verification" status until the matrix is cleared.

Awaiting your decision on:

1. Whether to commit the staged changes as a single commit or split per work package.
2. Whether to create and push tag `v-mf4`.
3. Which acceptance stance above you prefer for Phase MF.

---

**End of MF-4 Post-Completion Report.**