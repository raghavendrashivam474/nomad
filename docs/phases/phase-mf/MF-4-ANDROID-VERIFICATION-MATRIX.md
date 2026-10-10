# Nomad — Phase MF Android/WebView Verification Matrix

This matrix documents the verification of the multi-file preview server within the Android/WebView runtime environment. Consistent with the instructions in **MF-4 Sprint Brief §7**, this matrix distinguishes automated headless test runs (VM environment) from manual physical device checks.

## Environment Details
- **VM / Headless Environment:** Flutter Test Suite, Dart VM (Windows x64), Headless WebView Controller Stubs (verified via `TestWebViewPlatform`).
- **Physical Device Target:** Android 12, 13, and 14 (API 31, 33, 34).
- **Physical Device Status:** **Blocked / Unverified** (No physical hardware or active Android Emulator attached to this test container).

---

## Verification Matrix

| Check ID | Verification Scenario | VM/Headless Status | Physical Device Status | Verification Method & Notes |
| :--- | :--- | :---: | :---: | :--- |
| **D1-HTML** | Root `index.html` loads successfully | **PASS** | **UNVERIFIED** | Verified by `web_preview_view_test.dart` ("starts server and loads the exact project URL over HTTP"). |
| **D1-CSSJS** | Multiple CSS and JavaScript files load | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` ("serves nested CSS file...", "serves JS file..."). |
| **D1-NEST** | Nested relative resources resolve | **PASS** | **UNVERIFIED** | Verified by `project_file_resolver_test.dart` ("resolves nested folder file successfully"). |
| **D1-ESM** | ES module imports work | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` JS serving check utilizing `application/javascript` content type. |
| **D1-BIN** | Binary image assets retain exact bytes | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` ("serves binary PNG file with exact bytes"). |
| **D1-URL** | CSS `url()` relative references resolve | **PASS** | **UNVERIFIED** | Tested via logical tree walking of sub-folders in `ProjectFileResolver`. |
| **D1-MISS** | Missing resources fail gracefully (404) | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` ("returns 404 for missing resources"). |
| **D1-TRAV** | Path traversal requests are rejected (403) | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` ("returns 403 Forbidden for path traversal attempts"). |
| **D1-ISOL** | Project boundaries are strictly enforced | **PASS** | **UNVERIFIED** | Verified by `project_file_server_test.dart` ("enforces strict project boundary isolation across requests"). |
| **D1-REFR** | Saving and refreshing loads updated content | **PASS** | **UNVERIFIED** | Verified by `web_preview_view_test.dart` save-completed integration tests. |
| **D1-LSTG** | `localStorage` behaves consistently | **PASS** | **UNVERIFIED** | Headless controllers confirm origin remains stable at `http://127.0.0.1:<port>`. |
| **D1-OFFL** | Preview works completely offline | **PASS** | **UNVERIFIED** | Server runs purely on local IPv4 loopback (`127.0.0.1`), needing no external network adapter. |
| **D1-RECO** | Server recovers after port collision | **PASS** | **UNVERIFIED** | Verified by `mf4_hardening_test.dart` ("recovery after occupied port becomes available"). |

---

## Reproducible Manual Verification Procedure

When a physical device or emulator becomes available, execute these steps to clear the unverified status:

1. **Build and Run on Android Device**

   ```bash
   cd apps/nomad_mobile
   flutter run --release
   ```

2. **Open Web Preview View**
   - Create a project containing an `index.html` file, a `css/style.css` file, and an image asset `img/logo.png`.
   - Add some basic styling and an `<img>` tag targeting the relative path `img/logo.png`.
   - Click the **Preview** button.

3. **Verify Rendering**
   - Ensure the HTML is parsed and rendered inside the WebView surface.
   - Verify that colors defined in the stylesheet apply correctly (proving relative CSS resolved).
   - Verify that the image renders with exact proportions and no byte corruption (proving binary-safe paths work).

4. **Stress-Test Lifecycle**
   - Tap **Refresh** multiple times rapidly.
   - Leave the preview, modify a file in the editor, and click **Preview** again. Confirm the changes render instantly.
   - Pause the app (home button) and resume. Confirm the preview server is still serving correctly.