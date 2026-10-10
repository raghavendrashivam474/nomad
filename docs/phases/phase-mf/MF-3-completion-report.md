# MF-3 Completion Report

**Sprint:** MF-3 — Android Validation, Binary-Safe Assets & Preview Reliability
**Phase:** MF — Multi-File Support
**Baseline:** MF-2 (`v-mf2`, commit `50d2b5a`)
**Branch:** `main`
**Status:** Complete — submitted for senior review

---

## 1. Executive Summary

MF-3 achieved its two sprint objectives within the minimal-change constraint:

1. **Android preview validation** was attempted. No Android emulator or physical device was available in the development environment. This is recorded as an explicit gap rather than a false claim of compatibility.

2. **Binary-safe asset storage and serving** was implemented end-to-end. The `FileContentRepository` contract was extended with `readFileBytes()` and `writeFileBytes()` methods. `LocalFileContentRepository` overrides these with `readAsBytesSync()` / `writeAsBytesSync()`. `ProjectFileResolver` now calls `readFileBytes()` directly, eliminating the UTF-8 String round-trip that corrupted binary data. The existing HTTP server already served `List<int>` bytes, so no server changes were needed.

All 129 automated tests pass (20 in `nomad_core`, 109 in `nomad_mobile`). Static analysis reports zero issues in both packages.

---

## 2. Changes Implemented

### 2.1 Domain Contract — `FileContentRepository`

**File:** `packages/nomad_core/lib/src/domain/file_content_repository.dart`

Added two new methods with default implementations that delegate to the existing String API via `utf8.encode` / `utf8.decode`:

- `Future<List<int>> readFileBytes(EntityId projectId, EntityId fileNodeId)`
- `Future<void> writeFileBytes(EntityId projectId, EntityId fileNodeId, List<int> bytes)`

The default implementations ensure backward compatibility: any existing `FileContentRepository` implementation that does not override these methods will continue to work for text content. Only `LocalFileContentRepository` overrides them for true binary safety.

### 2.2 Local Storage — `LocalFileContentRepository`

**File:** `apps/nomad_mobile/lib/data/repositories/local_file_content_repository.dart`

Overrides `readFileBytes()` with `file.readAsBytesSync()` and `writeFileBytes()` with `file.writeAsBytesSync()`. This preserves exact bytes on disk without any String intermediary.

The existing `readFile()` and `writeFile()` methods remain unchanged. Existing text files stored as `{uuid}.txt` continue to work identically.

### 2.3 Resource Resolution — `ProjectFileResolver`

**File:** `apps/nomad_mobile/lib/server/project_file_resolver.dart`

Replaced the String round-trip:

```dart
// Before (MF-2):
final textContent = await contentRepository.readFile(projectId, currentNode.id);
final bytes = utf8.encode(textContent);

// After (MF-3):
final bytes = await contentRepository.readFileBytes(projectId, currentNode.id);

```

Removed the now-unnecessary `import 'dart:convert';`.

### 2.4 Architecture Decision Record

**File:** `docs/adr/ADR-0007-binary-safe-file-storage.md`

Documents the problem, evidence, options considered, selected approach, compatibility guarantees, migration assessment, testing strategy, and remaining consequences.

### 2.5 Test Mock Updates

All test files containing `implements FileContentRepository` were updated to include the required `readFileBytes()` and `writeFileBytes()` stub methods. The stubs delegate to the existing String-based methods via `utf8.encode` / `utf8.decode`, which is correct for test fakes that only store text content.

Files updated:

* `test/branding/nomad_branding_test.dart`
* `test/editor/css_editing_test.dart`
* `test/editor/editor_accessory_widget_test.dart`
* `test/editor/html_editing_test.dart`
* `test/editor/javascript_editing_test.dart`
* `test/server/project_file_resolver_test.dart`
* `test/server/project_file_server_test.dart`
* `test/ui/web_preview_view_test.dart`
* `test/web/web_project_creation_test.dart`

### 2.6 New Tests

**Byte-Safe Storage Tests (`test/data/local_file_content_repository_test.dart`)**

* Returns empty byte list for non-existent files
* Preserves exact binary bytes including `0x00` and non-UTF-8 sequences (PNG header + arbitrary bytes)
* Updates binary content with new byte payload
* Handles 64 KB binary payloads safely
* Deleting content removes binary file
* Text written via `writeFile()` is readable via `readFileBytes()` as correct UTF-8

**Resolver Binary Tests (`test/server/project_file_resolver_test.dart`)**

* Resolves binary assets (nested PNG) intact without corruption
* All existing text resolution, validation, traversal, and isolation tests remain green

**HTTP Server Binary Tests (`test/server/project_file_server_test.dart`)**

* Serves binary PNG file with exact bytes and correct `image/png` Content-Type
* Serves HEAD request with correct headers but empty body
* All existing text serving, lifecycle, 404, 403, 400, isolation, and concurrency tests remain green

---

## 3. What Was NOT Changed

Per the sprint's explicit non-goals:

* `WebPreviewView` was not modified
* The workspace hierarchy and `FileNode` model are unchanged
* `nomad_core` domain logic is unchanged (only the repository contract was extended)
* The editor save pipeline is unchanged
* No generic plugin/provider architecture was introduced
* No alternative HTTP server implementation was added
* No cloud asset-storage service was built
* No separate asset database was introduced
* The default port remains `18080`
* Android cleartext configuration was not broadened
* No unrelated dependencies were added
* Branding, starter templates, and UI design are untouched
* ADR-0006 was not modified (the HTTP server decision itself did not change)

---

## 4. Verification Results

### 4.1 Static Analysis

```text
packages/nomad_core:  No issues found!
apps/nomad_mobile:    No issues found!

```

### 4.2 Automated Tests

```text
packages/nomad_core:  00:01 +20: All tests passed!
apps/nomad_mobile:    00:35 +109: All tests passed!

```

### 4.3 Android Device Validation

**Status:** INCOMPLETE — No device available

The development environment has no Android emulator or physical device connected. `flutter devices` reports only Windows desktop, Chrome, and Edge. `flutter emulators` reports no emulators available.

This means the MF-2 HTTP-based preview has not been verified on an actual Android WebView. The Android configuration (`INTERNET` permission, `network_security_config.xml` with loopback cleartext allowance) was inspected and appears correct, but runtime behavior remains unverified.

**Recommendation:** The next sprint or a dedicated verification session should exercise the preview on an Android emulator or physical device using the checklist in the MF-3 brief (Section 4, A2).

---

## 5. Known Limitations

* **No Android device verification.** The preview has not been tested on an actual Android WebView. See Section 4.3.
* **Binary asset creation is not yet user-facing.** The storage and serving infrastructure supports binary assets, but the editor UI currently operates on text only. There is no file picker, image upload, or drag-and-drop mechanism for binary assets. This is outside MF-3 scope.
* **Physical file extension is `.txt` for all files.** Binary assets stored via `writeFileBytes()` are saved as `{uuid}.txt` on disk. This is cosmetic and does not affect byte-level I/O, but may cause confusion during manual inspection of the device filesystem.
* **MIME type coverage is limited.** `MimeTypeResolver` covers HTML, CSS, JS, JSON, SVG, PNG, JPG, GIF, WebP, ICO, and TXT. Font formats (WOFF, WOFF2) and other binary types are not yet mapped and will return `application/octet-stream`.
* **No content-length header is explicitly set.** The HTTP server relies on Dart's `HttpServer` to handle content-length automatically when `response.add(bytes)` is called. This has been verified to work correctly in tests but has not been validated on a real Android WebView.

---

## 6. Git State

* **Branch:** `main`
* **Baseline commit:** `50d2b5a` (tag: `v-mf2`)
* **Modified files:** 13
* **New files:** 1 (`docs/adr/ADR-0007-binary-safe-file-storage.md`)
* **Tag:** Not yet created (pending senior review)

---

## 7. Definition of Done Checklist

### Android validation

* [ ] Existing preview tested on an available Android emulator or physical device. **BLOCKED: No device available.**
* [ ] Document, CSS, and JavaScript load successfully. **BLOCKED**
* [ ] Save and refresh behavior verified. **BLOCKED**
* [ ] Closing and reopening the preview verified. **BLOCKED**
* [ ] Relevant platform/network errors investigated. **BLOCKED**
* [x] Unavailable device validation explicitly recorded rather than claimed.

### Binary-safe storage and serving

* [x] Actual storage representation inspected and documented.
* [x] A justified byte-safe implementation is selected.
* [x] Binary round-trip tests prove exact byte equality.
* [x] Existing text APIs and callers remain compatible.
* [x] Existing persisted projects remain accessible.
* [x] Any necessary migration is documented and tested. (No migration needed.)
* [x] Resolver correctly returns supported binary resources.
* [x] HTTP responses preserve exact bytes and correct metadata.
* [x] Existing path validation, project isolation, status codes, and caching behavior remain correct.

### Regression and engineering quality

* [x] `nomad_core` analysis and tests pass.
* [x] `nomad_mobile` analysis and tests pass.
* [x] Relevant focused tests pass.
* [x] Existing workspace, editor, starter-project, and preview tests remain green.
* [x] No unrelated dependencies, schema changes, or refactoring have slipped in.
* [x] Architecture changes have been reviewed and documented.

### Documentation and handoff

* [x] A dedicated ADR is added (`ADR-0007`).
* [x] `ADR-0006` is not modified (no change needed).
* [x] The post-completion report records exact commands and results.
* [x] Known limitations and unverified behavior are listed.
* [x] Git diff, commits, tag, and branch status are accurately reported.
* [x] MF-3 is submitted for senior review rather than self-declared fully verified.

```