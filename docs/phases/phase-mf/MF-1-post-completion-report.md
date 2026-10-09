# Nomad — Sprint MF-1 Post-Completion Implementation Report
**Resource-Serving Foundation**

* **Project:** Nomad — Mobile-First Development Lab
* **Phase:** Phase MF — Multi-File Support
* **Sprint:** MF-1 — Resource-Serving Foundation
* **Target Platform:** Android-first, Flutter/Dart
* **Date:** 2025-07-11
* **Baseline Starting Commit:** `59b9e2ccef1e2321e4f47f981d09c702c60f59dc` (Tag: `v-mf0`)
* **Status:** Complete — Ready for Senior Review

---

## 1. Executive Summary

Sprint MF-1 implemented the core resource-serving foundation required for multi-file web project preview in Nomad. It introduces an embedded, loopback-bound HTTP server (`ProjectFileServer`), a path-hierarchy resolver (`ProjectFileResolver`), and a case-insensitive MIME resolver (`MimeTypeResolver`).

In accordance with the preservation-first brief:
* **No production preview behavior was modified:** `WebPreviewView` remains untouched.
* **No domain, database, or editor contracts were altered:** All existing models, repositories, and editor controllers operate without modification.
* **Zero third-party dependencies added:** Implementation relies exclusively on built-in `dart:io` and standard library components.
* **Strict Android network scoping:** Added the `INTERNET` permission and configured `network_security_config.xml` to permit cleartext traffic strictly to loopback addresses (`127.0.0.1`, `localhost`).

All unit tests across both `nomad_core` (20/20) and `nomad_mobile` (99/99, including 26 server-specific unit tests) pass cleanly. `flutter analyze` and `dart analyze` report zero issues.

---

## 2. Baseline and Git State

* **Repository Root:** `C:/Users/ragha/nomad-mf0/nomad`
* **Initial Commit:** `59b9e2c` (`docs(phase-mf): add formal post-MF-0 completion report for senior review`)
* **Working Tree:** Clean prior to sprint work.

### Untouched Subsystems
* `packages/nomad_core/` — All entities, contracts, and tests left untouched.
* `apps/nomad_mobile/lib/ui/web_preview_view.dart` — Kept in existing single-file assembly mode; preview integration deferred to MF-2.
* `apps/nomad_mobile/lib/editor/` — Coding input, accessory bar, and editor logic untouched.
* `apps/nomad_mobile/lib/data/database/` — App database and SQLite schema untouched.

---

## 3. Architecture Implemented

```text
       Incoming HTTP Request (e.g. GET /<projectId>/css/responsive.css)
                                   |
                                   v
                         [ ProjectFileServer ]
                       (dart:io HttpServer on 127.0.0.1)
                                   |
                    +--------------+--------------+
                    |                             |
                    v                             v
        [ ProjectFileResolver ]          [ MimeTypeResolver ]
     (Walks FileNode hierarchy tree)   (Resolves Content-Type header)
                    |
                    v
        [ FileContentRepository ]
      (Reads persisted file content)
                    |
                    v
         HTTP 200 OK Response (with byte payload & MIME header)

```

### Components Built

#### `MimeTypeResolver` (`apps/nomad_mobile/lib/server/mime_type_resolver.dart`)

* Deterministic mapping of supported web extensions (`.html`, `.css`, `.js`, `.mjs`, `.json`, `.svg`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.ico`, `.txt`).
* Case-insensitive extension resolution.
* Fallback to `application/octet-stream` for unknown or missing extensions.
* Sets `application/javascript; charset=utf-8` for `.js` and `.mjs` files to ensure ES module compatibility.

#### `ProjectFileResolver` (`apps/nomad_mobile/lib/server/project_file_resolver.dart`)

* Resolves logical paths (e.g., `css/style.css`) by safely traversing the flat `List<FileNode>` retrieved from `WorkspaceRepository.getNodesForProject()`.
* Rejects empty paths, absolute paths, backslashes, directory traversal (`..`, `.`), and malformed segments.
* Enforces strict project boundary isolation.
* Verifies target nodes are files (rejects directory targets with `targetIsDirectory`).
* Returns structured `FileResolutionResult` (`FileResolutionSuccess` or `FileResolutionFailure`).

#### `ProjectFileServer` (`apps/nomad_mobile/lib/server/project_file_server.dart`)

* Wraps `dart:io` `HttpServer`.
* Binds strictly to `InternetAddress.loopbackIPv4` (`127.0.0.1`).
* Default port: `18080` (configurable, supporting ephemeral port `0` for testing).
* Routes `GET` and `HEAD` requests matching `/<projectId>/<logicalPath>`.
* Implements `start()` and `stop()` lifecycle methods with socket release.
* Rejects path traversal with `403 Forbidden` or `400 Bad Request` and missing files with `404 Not Found`.

#### Android Network Security Configuration

* **Manifest:** Added `<uses-permission android:name="android.permission.INTERNET"/>`.
* **Config:** Created `apps/nomad_mobile/android/app/src/main/res/xml/network_security_config.xml` restricting cleartext HTTP strictly to `127.0.0.1` and `localhost`.
* Attached configuration to `<application>` in `AndroidManifest.xml`.

#### ADR-0006 (`docs/adr/ADR-0006-embedded-http-server.md`)

* Formally documented architecture decision, single-mechanism rationale, binary content limitations, lifecycle, port/origin considerations, and reconsidering criteria.

---

## 4. Files Added and Modified

### Added Files

* `docs/adr/ADR-0006-embedded-http-server.md`
* `apps/nomad_mobile/lib/server/mime_type_resolver.dart`
* `apps/nomad_mobile/lib/server/project_file_resolver.dart`
* `apps/nomad_mobile/lib/server/project_file_server.dart`
* `apps/nomad_mobile/test/server/mime_type_resolver_test.dart`
* `apps/nomad_mobile/test/server/project_file_resolver_test.dart`
* `apps/nomad_mobile/test/server/project_file_server_test.dart`
* `apps/nomad_mobile/android/app/src/main/res/xml/network_security_config.xml`
* `docs/phases/phase-mf/MF-1-post-completion-report.md`

### Modified Files

* `docs/adr/README.md` (Updated decision table with ADR-0006)
* `apps/nomad_mobile/android/app/src/main/AndroidManifest.xml` (Added INTERNET permission and networkSecurityConfig)

---

## 5. Automated Tests and Results

### Test Execution Summary

* **`packages/nomad_core`:** 20/20 passed (`dart test`)
* **`apps/nomad_mobile`:** 99/99 passed (`flutter test`)
* **Static Analysis (`nomad_core`):** Clean (0 issues)
* **Static Analysis (`nomad_mobile`):** Clean (0 issues)

### Server Test Breakdown

* **`MimeTypeResolver` (5 tests):** Extension resolution, case-insensitivity, path strings, image/asset types, fallback handling.
* **`ProjectFileResolver` (10 tests):** Empty path rejection, absolute/backslash rejection, path traversal rejection, empty segment rejection, root file resolution, nested folder file resolution, folder-as-target rejection, non-existent segment handling, file-as-folder parent rejection, strict project isolation.
* **`ProjectFileServer` (11 tests):** Loopback bind & clean shutdown, server restart, startup failure on invalid port, root HTML serving with UTF-8 Content-Type, nested CSS serving with `text/css`, JS serving with `application/javascript` for ES modules, 404 for missing resources, 403 for path traversal, 400 for malformed requests, multi-project request isolation, concurrent request handling.

---

## 6. Binary Asset Handling

As documented in ADR-0006 and the baseline inspection:

1. Current `FileContentRepository` defines `readFile(projectId, fileNodeId)` returning `Future<String>`, backed by `LocalFileContentRepository` reading `.txt` files via `readAsStringSync()`.
2. Text assets (HTML, CSS, JS, JSON, SVG) are UTF-8 encoded into bytes by `ProjectFileResolver` and served with high fidelity.
3. Arbitrary binary assets (e.g., PNG, JPEG, WOFF2) would suffer byte corruption if read through the existing text-decoding storage contract.

In accordance with the sprint brief, no breaking database or storage migration was forced in MF-1. Full binary asset round-tripping will be addressed as a prerequisite in MF-3 prior to physical device validation.

---

## 7. Origin, Port, and Lifecycle Decisions

* **Host:** Bound exclusively to `127.0.0.1` (IPv4 loopback).
* **Default Port:** `18080`.
* **Conflict Handling:** Server explicitly throws `SocketException` on port collision during startup. Silent fallback across ports is avoided to prevent hidden `localStorage` origin fragmentation.
* **Preview Integration:** Deferred to MF-2. Existing `WebPreviewView` continues to function independently.

---

## 8. Definition-of-Done Checklist

* [x] Revised ADR-0006 created in `docs/adr/` and registered in `README.md`.
* [x] `MimeTypeResolver` implemented with case-insensitivity and deterministic fallback.
* [x] `ProjectFileResolver` implemented with tree-walk resolution, path traversal defense, and project isolation.
* [x] `ProjectFileServer` implemented with loopback binding, error routing, and clean lifecycle management.
* [x] Minimal Android network configuration added and verified.
* [x] Isolated automated unit tests written for all components (26 new tests, 100% passing).
* [x] All existing tests continue to pass (20 in core, 73 pre-existing in mobile; 119 total).
* [x] `dart analyze` and `flutter analyze` pass with 0 issues.
* [x] `WebPreviewView` and existing preview loading untouched.
* [x] Comprehensive MF-1 report compiled.

```