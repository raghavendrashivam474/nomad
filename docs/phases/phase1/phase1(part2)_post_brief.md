# Nomad Web Lab — Sprint Brief
## S0.1.5 → S0.1.8 · What We Built, How, and What Broke Along the Way

**Baseline:** `b685e72` (v0.1)  
**Final:** `3c634ad` (v0.1.8)  
**Tags:** `v0.1.5` · `v0.1.6` · `v0.1.7` · `v0.1.8`  
**Tests:** 60/60 green · Analyzer: clean · APK: built & device-verified

---

## What was done

Nomad went from “edit HTML/CSS/JS on your phone” to “edit, save, and *see it run* inside the app.”

| Sprint | What shipped |
|--------|--------------|
| **S0.1.5** | A real preview surface. Open a Web project, tap Preview, see `index.html` rendered with its CSS and JS. Loading / missing-file / empty-file / error states. Manual refresh. |
| **S0.1.6** | Live reload on save. Save `index.html`, `style.css`, or `script.js` → preview updates automatically. Unsaved edits stay unsaved. No reload storms. Manual refresh still works. |
| **S0.1.7** | Phone + tablet workflow. Phone: full-screen editor ↔ full-screen preview, back returns to the same file. Tablet: side-by-side editor + preview. Same shell, no parallel navigation. |
| **S0.1.8** | Hardening. Edge cases covered. Tests green. Real-device smoke test. DOM storage unlocked so apps like QuickNotes can use `localStorage`. |

End result: create a Web project → edit → save → preview → see changes live → run real browser APIs — on phone and tablet — without touching the existing editor, repos, or branding.

---

## How it was done

**Primary rule followed:** extend, don’t rebuild. Editor, workspace, persistence, and shell stayed as-is.

1. **Dependency**  
   Added `webview_flutter` (official Flutter plugin). Confirmed Android `minSdk` was already high enough. No other major deps.

2. **Content path**  
   Preview reads only through existing contracts:
   - `WorkspaceRepository.getNodesForProject()` to find files by name  
   - `FileContentRepository.readFile()` for content  
   Never touches DB tables or disk paths directly.

3. **Rendering strategy**  
   Files on disk are UUID `.txt` blobs; HTML links `style.css` / `script.js` by name.  
   **Chosen approach:** read the three files, strip the `<link>` / `<script src>` tags, inject CSS into `<head>` and JS before `</body>`, then `loadHtmlString(...)`.  
   Why not `file://` temp dirs? Android WebView is hostile to `file://` origins and relative loads; inlining is reliable for the three-file V0.1 scope. Trade-off documented: extra relative assets (e.g. images) won’t resolve yet.

4. **Live reload**  
   No event bus, no new state library.  
   `EditorView` got an `onSaveCompleted` callback.  
   `AppShell` owns a `previewVersion` counter. On successful save of the three starter files, it increments the counter.  
   `WebPreviewView.didUpdateWidget` re-renders when version or project changes.  
   Flutter’s frame coalescing handles rapid saves. Project switch uses `ValueKey(project.id)` so old WebViews die cleanly.

5. **Layouts**  
   Phone: if preview flag on → full-screen `WebPreviewView`; back closes it and returns to the open editor tab.  
   Tablet (≥600px): same flag splits the right pane into Editor | Preview. Workspace sidebar stays put.

6. **Security / origin**  
   Preview runs user JS. No native bridges, no FS access.  
   Final fix: `loadHtmlString(html, baseUrl: 'https://localhost/')` so the page has a real origin (needed for storage APIs) without leaving the device.

---

## Problems faced and how they were fixed

| # | Problem | Impact | Fix |
|---|---------|--------|-----|
| 1 | **PowerShell mangled Dart regexes** when writing spike files (nested quotes in here-strings). | Spike wouldn’t analyze. | Simplified regexes to one quote style; rewrote spike cleanly. Later deleted spike entirely. |
| 2 | **No WebView in widget tests.** `WebViewController()` asserts if `WebViewPlatform.instance` is null. | New tests crashed the suite. | Built a headless `TestWebViewPlatform` + controller/widget/delegate stubs. Registered in `setUpAll`. |
| 3 | **`pumpAndSettle` timed out** even after the stub. Loading spinner never stopped because `onPageFinished` never fired. | One test hung forever. | Stub’s `loadHtmlString` now manually fires the stored `onPageFinished` callback so `_isLoading` clears. |
| 4 | **Analyzer: `depend_on_referenced_packages`** — tests imported `webview_flutter_platform_interface` which was only transitive. | Lint noise. | Added it as an explicit `dev_dependency`. |
| 5 | **Real device: QuickNotes “Saving failed. Check browser storage permissions.”** | Preview looked fine but any app using `localStorage` was broken. | Root cause: `loadHtmlString` without `baseUrl` → opaque origin (`about:blank`) → browsers block storage. **Fix:** `baseUrl: 'https://localhost/'`. Unlocked `localStorage` / `sessionStorage` / IndexedDB. Confirmed on device. |
| 6 | **Filename vs storage mismatch** (UUID files vs `href="style.css"`). | Couldn’t just point WebView at a folder. | Forced the “resolve by display name + inline” design from day one; never assumed path-based loading. |

No core contracts were broken. No ADRs needed — we didn’t change domain models, repos, navigation ownership, or storage format. Sync `dart:io` inside the local file repo was left alone (brief said don’t touch it casually); preview didn’t expose a responsiveness problem from it.

---

## What we deliberately did *not* do

- No rewrite of editor, shell, or persistence  
- No global state framework / event bus  
- No Node, no dev server, no package install, no console UI  
- No HMR or preserving JS runtime state across reloads  
- No Coding Input keyboard (explicitly deferred)  
- No claim of full browser compatibility — three-file Web Lab only, limitations written down  

---

## Bottom line

**S0.1.5** proved we can render.  
**S0.1.6** made save drive refresh without lying about dirty state.  
**S0.1.7** made the loop usable on phone and tablet inside the existing shell.  
**S0.1.8** made it dependable — including the hard-won `localStorage` fix after a real app failed on device.

Implementation stayed behind repository boundaries, kept the preview isolated from the editor, and left 54 old tests green while adding 6 new ones. History is linear and tagged per sprint. Web Lab V0.1.8 is ready for senior review and the next phase.