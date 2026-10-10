# MF-3 Post-Completion Report

**To:** Senior Development Lead
**From:** MF-3 Implementation Team
**Date:** October 2025
**Project:** Nomad — Mobile-First Development Lab
**Sprint:** MF-3 — Android Validation, Binary-Safe Assets & Preview Reliability
**Phase:** MF — Multi-File Support
**Baseline:** MF-2 (`v-mf2`, commit `50d2b5a`)
**Branch:** `main`
**Status:** Submitted for senior review

---

## 1. Executive Summary

MF-3 was executed as a narrowly scoped reliability sprint, strictly honoring the brief's directive to make the existing MF-2 application work more reliably rather than to redesign it. Two priorities were addressed:

1. **Priority 1 (Android preview validation):** Attempted. Not completed due to the absence of any Android emulator or physical device in the development environment. This limitation is disclosed explicitly rather than being masked by a claim of compatibility.

2. **Priority 2 (Binary-safe asset support):** Fully implemented end-to-end. The `FileContentRepository` contract was extended with byte-oriented operations, the local implementation was overridden for true binary safety, and `ProjectFileResolver` was updated to call the byte-safe path directly. Existing text-file behavior, persistence, callers, and tests were preserved without modification to their semantic contract.

**Final verification results:**

| Package | Analyzer | Tests |
|---|---|---|
| `packages/nomad_core` | ✅ No issues found | ✅ 20 passed |
| `apps/nomad_mobile` | ✅ No issues found | ✅ 109 passed |

**Total:** 129 automated tests passing. Zero regressions. Zero unrelated changes.

---

## 2. Scope of Changes

### 2.1 Production code (3 files)

| File | Nature of change | Lines affected |
|---|---|---|
| `packages/nomad_core/lib/src/domain/file_content_repository.dart` | Added two methods (`readFileBytes`, `writeFileBytes`) with default UTF-8 delegating bodies to preserve backward compatibility | +23 |
| `apps/nomad_mobile/lib/data/repositories/local_file_content_repository.dart` | Overrode `readFileBytes` / `writeFileBytes` with `readAsBytesSync` / `writeAsBytesSync` for exact-byte I/O | +26 |
| `apps/nomad_mobile/lib/server/project_file_resolver.dart` | Replaced the String → UTF-8 round-trip with a direct `readFileBytes()` call. Removed now-unused `import 'dart:convert';` | –6, +3 |

### 2.2 Test code (10 files)

Nine existing test files containing fake/in-memory `FileContentRepository` implementations were updated to supply the two new byte-oriented stub methods. One test file (`local_file_content_repository_test.dart`) received six new tests covering binary round-trip equality and backward-compatible text behavior. Two existing test files (`project_file_resolver_test.dart`, `project_file_server_test.dart`) received new tests for binary resolution and binary HTTP serving.

### 2.3 Documentation (1 file)

| File | Purpose |
|---|---|
| `docs/adr/ADR-0007-binary-safe-file-storage.md` | Documents the problem, evidence, four options considered, selected approach, compatibility guarantees, migration assessment, testing strategy, and remaining consequences |

### 2.4 Explicitly unchanged

Per the brief's non-goals, the following were deliberately NOT modified:

- `WebPreviewView` (no demonstrated defect to justify change)
- `FileNode`, `WorkspaceRepository`, `LocalWorkspaceRepository` (no schema change required)
- `MimeTypeResolver` (existing coverage is sufficient for the targeted asset scope)
- `ProjectFileServer` (already byte-oriented; no change needed)
- `AndroidManifest.xml`, `network_security_config.xml` (correct as-is; broadening cleartext would exceed the justified loopback scope)
- `pubspec.yaml` (no new dependencies required)
- Default port `18080`, editor save pipeline, starter projects, branding, ADR-0006

---

## 3. Technical Implementation

### 3.1 The problem

The MF-2 architecture had a correct separation between the HTTP server (byte-oriented, serving `List<int>`) and the storage layer (text-oriented, exposing only `Future<String> readFile(...)`). The resolver bridged these two by UTF-8-encoding the String retrieved from storage:

```dart
final textContent = await contentRepository.readFile(projectId, currentNode.id);
final bytes = utf8.encode(textContent);
```

This bridge works correctly for valid UTF-8 text content but silently corrupts any binary content. Any byte sequence that is not valid UTF-8 would be rejected by `readAsStringSync()` on the way in, and even if it survived, the round-trip through a Dart `String` would re-encode and alter bytes.

### 3.2 The decision

Four options were documented in ADR-0007:

| Option | Verdict |
|---|---|
| A. Replace String API with `List<int>` everywhere | **Rejected** — breaks every existing caller and starter project |
| B. Base64-encode binary in the String API | **Rejected** — doubles storage, fragile, no architectural win |
| C. Add parallel byte-oriented methods with text-delegating defaults | **Selected** — minimal surface area, 100% backward compatible |
| D. Build a separate asset storage subsystem | **Rejected** — over-engineered, violates minimal-change principle |

Option C was selected because it:
- Keeps the existing text API semantically identical
- Requires no database schema change
- Requires no migration of existing project data
- Can be adopted incrementally by consumers that need it (initially, only `ProjectFileResolver`)
- Has a tiny blast radius: ~20 lines of production code

### 3.3 The implementation

**Contract extension** (`FileContentRepository`):

```dart
Future<List<int>> readFileBytes(EntityId projectId, EntityId fileNodeId) async {
  final text = await readFile(projectId, fileNodeId);
  return utf8.encode(text);
}

Future<void> writeFileBytes(
    EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
  await writeFile(projectId, fileNodeId, utf8.decode(bytes));
}
```

The default implementations delegate to the String methods so that any implementation (including future ones or test fakes) remains functional for text content without implementing the new methods.

**Local implementation override** (`LocalFileContentRepository`):

```dart
@override
Future<List<int>> readFileBytes(
    EntityId projectId, EntityId fileNodeId) async {
  try {
    final file = await _getFile(projectId, fileNodeId);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
    return <int>[];
  } catch (e) {
    throw DomainException('Failed to read file bytes', cause: e);
  }
}

@override
Future<void> writeFileBytes(
    EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
  try {
    final file = await _getFile(projectId, fileNodeId);
    file.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  } catch (e) {
    throw DomainException('Failed to write file bytes', cause: e);
  }
}
```

The on-disk filename convention (`{uuid}.txt`) was preserved intentionally. The `.txt` extension is cosmetic — the underlying file I/O is binary — and changing it would require a migration of existing project data that the brief explicitly forbids.

**Resolver update** (`ProjectFileResolver`):

```dart
// 4. Retrieve content safely as raw bytes.
// Uses the byte-safe repository path to preserve binary assets.
final bytes =
    await contentRepository.readFileBytes(projectId, currentNode.id);
```

The HTTP server (`ProjectFileServer`) required no modification — its handler already serves `List<int>` via `response.add(result.bytes)` and already sets the correct Content-Type via `MimeTypeResolver`.

---

## 4. Problems Encountered and Mitigations

This section documents every real issue hit during the sprint, the root cause, and the concrete mitigation. These are preserved verbatim as a reference for future implementers.

### 4.1 PowerShell UTF-8 corruption of em-dash characters

**Symptom:** After the first automated patch pass, `flutter test` failed in `nomad_branding_test.dart` and `web_preview_view_test.dart`:

```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Nomad â€” Mobile-First Development Lab">
```

**Root cause:** Windows PowerShell 5.1's `Get-Content` reads UTF-8 files without a BOM as Windows-1252 (ANSI) by default. The em-dash character `—` (U+2014, encoded in UTF-8 as `0xE2 0x80 0x94`) was read as three separate characters `â€”` and then re-written through `Set-Content -Encoding UTF8`, producing a double-encoded sequence that no longer matched the production code's literal.

**Mitigation:** We restored all affected test files to their pristine baseline with `git checkout --` and then performed all subsequent file modifications via a dedicated Dart script (`patcher.dart`) which uses `File.readAsStringSync()` and `File.writeAsStringSync(..., encoding: utf8)` — both of which honor UTF-8 correctly regardless of host OS. This mitigation is now the preferred pattern for any future file-rewriting work in this project.

**Lesson:** Never round-trip source files containing non-ASCII characters through PowerShell 5.1. Use Dart or `pwsh` (PowerShell 7+) if automation is required.

### 4.2 Dart `implements` ignores default method bodies

**Symptom:** After adding `readFileBytes` and `writeFileBytes` to the abstract `FileContentRepository` with default implementations, `flutter analyze` reported ten errors across all nine test files:

```
error - Missing concrete implementations of 'FileContentRepository.readFileBytes'
and 'FileContentRepository.writeFileBytes'. Try implementing the missing methods,
or make the class abstract
```

**Root cause:** In Dart, when a class uses `implements` (rather than `extends`), it must provide concrete implementations of **every** method in the interface, including methods that have default bodies in the abstract parent. This is a well-known Dart language rule: `implements` extracts only the interface signature; it does not inherit bodies. All test fakes in this codebase used `implements FileContentRepository` for maximum flexibility.

**Mitigation:** We wrote a Dart script that scanned the test tree with a regex (`class\s+\w+\s+implements\s+FileContentRepository\s*\{`), located all nine affected classes, and injected the two stub methods directly after each opening brace. The stubs delegate to `readFile` / `writeFile` via UTF-8 encode/decode, which is semantically correct for test fakes that only store text content.

**Lesson:** When extending an abstract contract that is widely implemented via `implements` rather than `extends`, assume every existing implementation site must be touched. Default method bodies on the interface do not reach `implements` sites.

### 4.3 Resolver appeared updated but was not

**Symptom:** After running the Dart patcher, static analysis was clean but two binary tests still failed:

```
ProjectFileResolver Resolution Tests resolves binary assets intact without corruption [E]
  Expected: <Instance of 'FileResolutionSuccess'>
    Actual: <Instance of 'FileResolutionFailure'>

ProjectFileServer HTTP Serving Tests serves binary PNG file with exact bytes and correct Content-Type [E]
  Expected: <200>
    Actual: <404>
```

**Investigation:** We constructed a standalone Dart diagnostic that reproduced the exact test setup (two FileNodes: `images` folder + `logo.png` file; byte-safe fake repository containing `[1, 2, 3]`). It ran against the compiled production resolver and returned `FileResolutionSuccess`. The test failed; the diagnostic succeeded. This meant the resolver on disk did not match what we believed we had written.

**Root cause:** The patcher used a precise multi-line regex to match the original three-line block containing the UTF-8 round-trip. However, the baseline file on disk was formatted slightly differently than the string literal in the patcher — subtle whitespace / line-ending differences meant the regex never matched. The patcher silently reported `[WARN] ProjectFileResolver pattern not found or already replaced` but we overlooked the warning given everything else was green. The resolver was still calling `contentRepository.readFile()` + `utf8.encode()`.

Then why did the diagnostic pass? Because the diagnostic's fake repository defines `readFile` to **return** `''` and defines `readFileBytes` properly — but the fake also had `writeFileBytes` populating `_byteStorage`. When the resolver called `readFile`, it got `''`, then `utf8.encode('')` returned `[]`, and because the FileNode still resolved cleanly, the result was a `FileResolutionSuccess` with an **empty** byte list. The test asserted `success.bytes equals rawImageBytes` and would have failed on content comparison — but our earlier diagnostic only printed the result type, not the content. The diagnostic was insufficiently rigorous.

**Mitigation:** We abandoned patch-and-regex and instead rewrote `project_file_resolver.dart` in full via Dart, using an exact literal of the complete desired source. The file was now guaranteed to be in the intended state.

**Lesson:** When a patcher reports "pattern not found," treat it as a hard failure, not a warning. When a diagnostic contradicts a test, make the diagnostic rigorous enough to assert exact content equality, not just type. In doubt, rewrite the file in full rather than patching.

### 4.4 Dependency version warnings

**Symptom:** Every `flutter pub get` emits noise about 16 packages with newer-but-incompatible versions available (`clock`, `code_assets`, `flutter_lints`, etc.).

**Root cause:** The project pins specific dependency constraints via `pubspec.yaml` and `pubspec.lock`. Flutter's resolver reports available upgrades blocked by those constraints.

**Mitigation:** None required. These are informational, not errors. Changing dependency versions is explicitly out of scope for MF-3.

### 4.5 Android device unavailable

**Symptom:** `flutter devices` returned only Windows desktop, Chrome, and Edge. `flutter emulators` reported no emulators available.

**Root cause:** No Android SDK emulator image or physical device is present on this host.

**Mitigation:** We did not fabricate verification. The Android configuration (INTERNET permission in all three manifest variants, `network_security_config.xml` permitting cleartext for `127.0.0.1` and `localhost`) was inspected and confirmed correct. The runtime behavior remains unverified and is disclosed in Section 5.

---

## 5. Verification Evidence

### 5.1 Static analysis

**`packages/nomad_core`:**
```
Analyzing nomad_core...
No issues found!
```

**`apps/nomad_mobile`:**
```
Analyzing nomad_mobile...
No issues found! (ran in 3.4s)
```

### 5.2 Automated tests

**`packages/nomad_core`:**
```
00:01 +20: All tests passed!
```

**`apps/nomad_mobile`:**
```
00:35 +109: All tests passed!
```

### 5.3 Test coverage additions

**Byte-safe storage** (`test/data/local_file_content_repository_test.dart`), group `LocalFileContentRepository Binary Safety (MF-3)`:

- `returns empty byte list when reading non-existent file`
- `preserves exact binary bytes including 0x00 and non-UTF8 sequences`
- `updates binary content with new byte payload`
- `handles larger binary payloads safely` (64 KB)
- `deleting content removes binary file`
- `text written via writeFile is readable via readFileBytes as UTF-8`

**Binary resolution** (`test/server/project_file_resolver_test.dart`):

- `resolves binary assets intact without corruption` (nested PNG with non-UTF-8 bytes)

**Binary HTTP serving** (`test/server/project_file_server_test.dart`):

- `serves binary PNG file with exact bytes and correct Content-Type`
- `serves HEAD request with headers but no body`

All existing tests (CRUD, project isolation, path validation, path traversal, lifecycle, 404/403/400, concurrency, text file serving, cache-control) continue to pass without modification to their assertions.

### 5.4 Android validation status

**Not verified.** The checklist in the brief (Section 4.A2) remains unexecuted:

- [ ] Launch Nomad on Android — not possible without a device
- [ ] Open existing project, open preview, verify render — not verified
- [ ] Verify save-and-refresh behavior — not verified
- [ ] Verify server lifecycle across preview close/reopen — not verified
- [ ] Verify application restart does not leave stale port state — not verified

The Android configuration appears correct based on static inspection:

- `AndroidManifest.xml` (debug, main, profile) all declare `<uses-permission android:name="android.permission.INTERNET"/>`
- `network_security_config.xml` permits cleartext traffic to `127.0.0.1` and `localhost` with `includeSubdomains="true"`
- The main manifest references the network security config via `android:networkSecurityConfig`

No defects in the Android configuration were observed. However, static inspection cannot substitute for runtime verification in a WebView.

---

## 6. Git State

- **Branch:** `main`
- **Baseline commit:** `50d2b5a` (tag: `v-mf2`)
- **Modified production files:** 3
  - `packages/nomad_core/lib/src/domain/file_content_repository.dart`
  - `apps/nomad_mobile/lib/data/repositories/local_file_content_repository.dart`
  - `apps/nomad_mobile/lib/server/project_file_resolver.dart`
- **Modified test files:** 10
- **New files:** 2
  - `docs/adr/ADR-0007-binary-safe-file-storage.md`
  - `docs/phases/phase-mf/MF-3-completion-report.md`
  - `docs/phases/phase-mf/MF-3-post_completion-report.md` (this document)
- **Deleted files:** 0
- **Pending commit, tag `v-mf3`, and push:** awaiting senior review approval

---

## 7. Known Limitations and Deferred Items

| # | Limitation | Impact | Deferred to |
|---|---|---|---|
| 1 | No Android device runtime verification | Preview behavior on actual WebView is theoretically but not empirically correct | Next sprint or dedicated verification session |
| 2 | Binary asset creation has no user-facing UI | Developers cannot upload images into a project through the app | Future sprint (editor capability expansion) |
| 3 | Physical files stored as `{uuid}.txt` | Cosmetic — manual filesystem inspection may be confusing | Future sprint if deemed worth a migration |
| 4 | WOFF / WOFF2 and other binary MIME types not mapped | Fonts and uncommon binary types fall back to `application/octet-stream` | Future sprint when font support is prioritized |
| 5 | HTTP Content-Length header not explicitly set | Relies on Dart `HttpServer` default behavior; works in tests but unverified on Android WebView | Covered by Limitation #1 above |

None of these block the sprint's acceptance criteria. All are documented so that a future implementer does not rediscover them as surprises.

---

## 8. Recommendations for Senior Review

1. **Review ADR-0007** for architectural soundness. The core question for the reviewer: is adding two methods with default implementations the right boundary, or should the long-term direction be a unified byte-oriented API with text as a convenience layer?

2. **Confirm the `{uuid}.txt` on-disk convention is acceptable** for binary content, or decide a migration to `{uuid}.bin` / extensionless storage is warranted. The current choice is a conservative compatibility decision; a cleaner naming scheme would require migration tooling.

3. **Schedule Android verification** as a prerequisite before any sprint that adds user-visible binary asset features. The current implementation is correct by test, but a WebView may surface edge cases (CORS, Content-Length requirement, caching idiosyncrasies) that unit tests cannot catch.

4. **Tag approval:** Pending review approval, we will commit the changes with a semantic message, create the `v-mf3` tag, and push to `origin/main`.

5. **Dependency hygiene:** The 16 outdated dependency warnings are informational, but a dedicated maintenance sprint to review and update constraints should be scheduled before MF-4 to prevent incompatibility risk accumulating further.

---

## 9. Closing Statement

MF-3 was executed with discipline against the brief's explicit non-goals. Every change made was justified by concrete evidence of a defect or required capability. Every change not made was deliberately omitted to preserve existing behavior. The sprint's success criterion — Nomad can serve supported binary assets without corruption, and existing text behavior is preserved — has been met and verified by automated tests.

The Android validation gap is disclosed honestly. The implementation is submitted for senior review rather than self-declared as fully verified.

Respectfully submitted.

**— MF-3 Implementation Team**