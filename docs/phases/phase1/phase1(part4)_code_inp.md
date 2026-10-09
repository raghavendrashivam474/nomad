# MS1.75 Completion Brief — Nomad Coding Input

---

## Executive Summary

**Micro-sprint MS1.75** delivered the first usable version of **Nomad Coding Input**, a mobile-oriented coding interaction layer that reduces the friction of writing HTML, CSS, and JavaScript source code on an ordinary Android phone keyboard.

The implementation follows the hybrid input model established in the product brief: the existing Android soft keyboard remains the primary text-entry mechanism, while a compact accessory bar and an expandable contextual panel provide one-tap access to programming symbols, paired delimiters, cursor navigation, indentation controls, and language-aware code snippets.

All editing operations flow through the existing `CodeEditingController` and `EditorView` dirty-state pipeline. No editor replacement, no custom input method, no new dependencies.

**Tag:** `v0.75.1` · **Commit:** `50ad6f6` · **Tests:** 73/73 passing · **Analyzer:** 0 issues

---

## What Was Built

### 1. `CodeInputActions` — Safe Editing Operations

A static helper class providing nine deterministic text-manipulation operations that work directly on Flutter's `TextEditingController`:

| Operation | Behavior |
|---|---|
| `insertText` | Inserts text at cursor, replaces selection if active |
| `insertPaired` | Inserts matched delimiters; wraps selection or places cursor between pair |
| `moveCursorLeft / Right` | Single-character cursor movement with boundary clamping |
| `moveCursorToLineStart / End` | Line-aware cursor jumping using newline detection |
| `indent / unindent` | Prepends or strips indentation from current or selected lines |
| `insertTemplate` | Inserts a multi-character snippet and places the cursor at a defined interior position |

Every operation validates selection bounds, handles empty documents, handles invalid selections gracefully, and triggers the controller's change listeners so that dirty-state tracking and syntax highlighting update automatically.

### 2. `CodeAccessoryBar` — Compact Symbol Bar

A 44px-tall, horizontally scrollable bar that docks below the editor and above the system keyboard. It provides:

- **Paired delimiters:** `{}` `()` `[]` `""` `''` `` `` `` and `<>` (HTML only)
- **Common symbols:** `=` `;` `:` `/` `.` `,` `!` `&` `|` `+` `-` `*` `?`
- **Indentation:** Indent and Unindent buttons
- **Navigation:** Cursor Left and Cursor Right
- **Panel toggle:** Opens or closes the expanded contextual panel

The bar uses a `FocusNode`-aware tap handler to ensure that pressing any button inserts the character without dismissing the soft keyboard or stealing editor focus.

### 3. `ContextualCodePanel` — Expandable Tool Drawer

A collapsible panel (max 220px height) that slides open above the accessory bar. It provides:

- **Navigation section:** Line Start, Line End, Indent, Unindent
- **Language-specific snippets:**
  - **HTML:** `<div>`, `<p>`, `<button>`, `<script>`, `class=""`, `id=""`, `<!-- comment -->`
  - **CSS:** `rule {}`, `flex center`, `color`, `margin`, `padding`, `/* comment */`
  - **JavaScript:** `function()`, `() => {}`, `const`, `let`, `console.log()`, `if () {}`, `// comment`
  - **Plain Text:** Tab, List Item, Todo Item

Each snippet defines an explicit cursor placement offset so the developer lands inside the template ready to type.

### 4. `EditorView` Integration

The existing `EditorView` was extended with:

- An explicit `FocusNode` to manage focus between the text field and accessory controls
- A direct `_controller.addListener` subscription replacing the `onChanged` callback, ensuring that programmatic edits from the accessory bar trigger dirty-state updates identically to keyboard input
- A `Column` layout restructuring the body to `[Expanded TextField | ContextualCodePanel | CodeAccessoryBar]`
- Panel state reset on file switch to prevent stale language context

All existing behavior — syntax highlighting, save shortcuts (Ctrl/Cmd+S), preview toggle, loading states, error handling — remains unchanged.

---

## Architecture Decisions

### Why a static helper instead of extending `CodeEditingController`?

`CodeEditingController` currently overrides only `buildTextSpan` for syntax highlighting. Adding editing operations directly to the controller would couple text manipulation logic to the highlighting lifecycle and complicate future controller refactoring. A stateless static helper keeps the operations testable in isolation with a plain `TextEditingController`, requires no changes to the controller's inheritance chain, and can be called from any widget that holds a controller reference.

### Why a controller listener instead of `TextField.onChanged`?

Flutter's `TextField.onChanged` fires only on platform text-input events. Programmatic mutations via `controller.value = ...` (which is how `CodeInputActions` operates) trigger the controller's listener list but not the `onChanged` callback. By subscribing to `_controller.addListener` directly, all edits — whether from the soft keyboard, the accessory bar, or the contextual panel — flow through a single dirty-state check.

### Why no new dependencies?

The brief explicitly prohibited introducing keyboard frameworks, plugin registries, or state-management packages for this feature. The entire implementation uses only `flutter/material.dart` and the existing `nomad_core` domain types. This keeps the APK size impact minimal and avoids version-conflict risk.

---

## Testing Summary

| Suite | Tests | Status |
|---|---|---|
| `code_input_actions_test.dart` | 29 unit tests | ✅ All passing |
| `editor_accessory_widget_test.dart` | 3 widget tests | ✅ All passing |
| Existing editor tests (HTML, CSS, JS) | 12 tests | ✅ All passing |
| Existing data, UI, web, branding tests | 29 tests | ✅ All passing |
| **Total (nomad_mobile)** | **73 tests** | **✅ All passing** |
| **Total (nomad_core)** | **20 tests** | **✅ All passing** |
| **Flutter Analyzer** | — | **✅ 0 issues** |

### Key test coverage areas

- Insertion at beginning, middle, end of document
- Selection replacement and preservation
- Paired delimiter wrapping and cursor placement
- Cursor boundary clamping (start/end of document, start/end of line)
- Single-line and multiline indentation/unindentation
- Empty documents and empty lines
- Template insertion with interior cursor positioning
- Accessory bar rendering and panel toggle lifecycle
- Dirty-state activation from programmatic edits
- Language-specific snippet rendering (HTML vs JavaScript)

---

## Known Limitations and Deferred Items

| Item | Reason | Future Sprint |
|---|---|---|
| No undo/redo stack beyond platform default | Flutter's `TextEditingController` does not expose a multi-step undo history. The platform keyboard's built-in undo gesture works for recent keystrokes. A custom undo stack would require a significant controller architecture change. | Post-MS2 |
| No syntax-aware auto-pairing | Paired insertion is explicit (user taps the pair button). Automatic quote-skipping, bracket-closing on keystroke, and context-aware pairing require parser integration. | Post-MS2 |
| No autocomplete or LSP | Explicitly out of scope per the MS1.75 brief. | Phase 2+ |
| Tablet layout not optimized | The accessory bar and panel render correctly on tablets but are not yet adapted to wider layouts or split-pane workflows. | MS1.75+ tablet pass |
| No custom snippet persistence | Snippets are hardcoded per language. User-defined or project-level snippets require a persistence layer. | Post-MS2 |

---

## Files Changed

### New files (5)

| File | Lines | Purpose |
|---|---|---|
| `lib/editor/code_input_actions.dart` | ~175 | Safe text-editing operations |
| `lib/editor/code_accessory_bar.dart` | ~195 | Compact symbol bar widget |
| `lib/editor/contextual_code_panel.dart` | ~195 | Expandable contextual panel widget |
| `test/editor/code_input_actions_test.dart` | ~210 | Unit tests for editing operations |
| `test/editor/editor_accessory_widget_test.dart` | ~120 | Widget tests for accessory UI |

### Modified files (3)

| File | Change |
|---|---|
| `lib/ui/editor_view.dart` | Added FocusNode, controller listener, Column layout with accessory bar and panel |
| `lib/ui/web_preview_view.dart` | Formatting only (dart format) |
| `test/ui/projects_view_overflow_test.dart` | Formatting only (dart format) |

**Total diff:** 9 files changed, 1,190 insertions, 34 deletions

---

## Git Handover

| Field | Value |
|---|---|
| Branch | `main` |
| Commit | `50ad6f6` |
| Tag | `v0.75.1` |
| Working tree | Clean |
| Force-push | None |
| History rewrite | None |

---

## What Comes Next

MS1.75 establishes the foundation. The natural follow-up sprints would address:

1. **Real-device usability tuning** — Adjusting bar height, button sizing, and scroll physics based on physical-device testing with actual Android keyboards (Gboard, Samsung Keyboard, etc.).
2. **Composing-text awareness** — Ensuring accessory bar taps interact correctly with the IME composing region during CJK or predictive-text input.
3. **Extended language support** — Adding Python, Dart, or Markdown contextual controls as Nomad's language support grows.
4. **Custom undo stack** — Implementing a bounded undo/redo history within `CodeEditingController` to support multi-step accessory edits.
5. **Tablet-optimized layout** — Adapting the accessory bar to a persistent sidebar or floating toolbar on wider screens.

---

*MS1.75 delivered a working, tested, zero-dependency coding input experience that makes writing code in Nomad materially easier on a phone — without disrupting the existing editor, persistence, or preview workflows.*