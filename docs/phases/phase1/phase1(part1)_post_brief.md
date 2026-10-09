---

# S0.1.1 → S0.1.4 — Quick Brief
### What we built, what broke, and how we fixed it

---

## The Goal (One Sentence)

Make Nomad capable of creating a Web Project with starter HTML/CSS/JS files, recognizing each file type in the editor, providing basic syntax highlighting, and persisting everything across cold restarts — all without breaking a single V0.0 feature.

---

## What Got Built

**S0.1.1 — Web Project Foundation**
- Added `WebTemplate` class holding three starter file strings (index.html, style.css, script.js).
- When a user creates a Web Project, Nomad now auto-generates those three files in the workspace and writes their starter content to disk.
- If anything fails mid-creation, everything rolls back cleanly — no half-created projects left behind.
- Deleting a project now also cleans up its file contents from disk (closed a V0.0 gap).

**S0.1.2 — HTML Editing**
- Created `SourceLanguage` enum — single source of truth mapping file extensions to languages (.html → html, .css → css, .js → javascript).
- Built `CodeEditingController` extending Flutter's `TextEditingController` with regex-based HTML syntax highlighting (tags, attributes, strings, comments, DOCTYPE, entities).
- Editor now shows a language badge ("HTML") and icon in the header.

**S0.1.3 — CSS Editing**
- Extended `CodeEditingController` with CSS tokenization (selectors, properties, hex colors, units, at-rules, comments).
- Zero changes needed in `EditorView` — the language dispatch is automatic from the file name.

**S0.1.4 — JavaScript Editing**
- Extended `CodeEditingController` with JS tokenization (keywords, control flow, strings, template literals, globals, function calls, numbers, comments).
- Full HTML + CSS + JS trio is now first-class in the editor.

**Across all sprints:** Zero new third-party dependencies. All highlighting is done with lightweight regex inside a custom `TextEditingController`. No language server, no LSP, no heavy dependencies.

---

## Problems We Hit (and How We Fixed Them)

### 1. Dialog wouldn't close in time during tests
**What happened:** V0.0's project creation did one DB insert inside the dialog's `onPressed`. S0.1.1 added 7 more async operations (3 node inserts + 3 file writes + 1 reload). The widget test's pump cycles expired before the dialog dismissed, so assertions found the dialog's text field still on screen alongside the new project card → "Found 2 widgets with text 'Portfolio'".

**Fix:** Restructured the dialog so the Create button only validates the name and immediately pops. All async work happens *after* `showDialog` returns, in a separate `_createProject()` method. This matched V0.0's timing exactly.

### 2. File I/O stalled the widget test clock
**What happened:** `LocalFileContentRepository` used async `File.create()` and `File.writeAsString()`. Flutter's fake test clock doesn't advance real disk I/O, so writes never completed within the test's pump window.

**Fix:** Switched to sync variants (`createSync`, `writeAsStringSync`, `readAsStringSync`, `deleteSync`) inside the same `Future`-returning methods. Public contract unchanged. Production behavior unchanged. Tests immediately passed.

### 3. Duplicate `index.html` files in V0.0 E2E tests
**What happened:** V0.0 tests created a project then manually added a file called `index.html`. In V0.1, `index.html` already exists from the Web Template → two files with the same name → ambiguous tap targets.

**Fix:** Updated V0.0 tests to use distinct names (`about.html`) for manually created files, and to open the auto-generated starter files directly where appropriate. Tests got stronger, not weaker.

### 4. Dart string interpolation ate a JavaScript template literal
**What happened:** A JS test snippet contained `` console.log(`Initialized with: ${count}`) ``. Dart interpreted `${count}` as Dart interpolation → compilation error.

**Fix:** Replaced the JS template literal with plain string concatenation in the test sample. Template literal tokenization is still covered by the malformed-JS resilience test.

### 5. Test double used wrong parameter name
**What happened:** In-memory `WorkspaceRepository` test double called `copyWith(newName: ...)` but `FileNode.copyWith` takes `name:`.

**Fix:** One-word rename. No production code touched.

### 6. Em-dash encoding mismatch in tablet test
**What happened:** The tablet layout test hardcoded `'Nomad â€" Mobile-First Development Lab'` which broke depending on file encoding.

**Fix:** Replaced with `'${NomadBrand.productName} — ${NomadBrand.tagline}'` so it derives from the brand tokens directly.

---

## Final Numbers

| | V0.0 Baseline | V0.1 Current |
|---|---|---|
| `nomad_core` tests | 20 | 20 |
| `nomad_mobile` tests | 22 | 34 |
| **Total** | **42** | **54** |
| Analyzer issues | 0 | 0 |
| New dependencies | — | 0 |
| Architecture changes | — | None |
| ADRs required | — | None |

---

## What's NOT in Here (Intentionally)

No WebView. No preview. No live reload. No npm. No bundler. No language server. No cloud runner. No execution engine. All of that is S0.1.5+.

---

## Tags & Commits

```
v0.0.7  →  v0.1.1  →  v0.1.2  →  v0.1.3  →  v0.1.4 / v0.1.0
```

All pushed to `origin/main`. Working tree clean.