---

**TO:** Senior Developer, Nomad Project
**FROM:** Junior Developer, Mobile Experience
**DATE:** 2026
**RE:** Post-Implementation Report — MS1.75 Nomad Coding Input
**STATUS:** Delivered · Tag `v0.75.1` · Commit `50ad6f6`

---

# Post-Implementation Report: MS1.75 — Nomad Coding Input

## 1. Purpose of This Report

This report documents the completion of micro-sprint **MS1.75 (Mobile Coding Experience — Nomad Coding Input)** against the implementation brief issued at the start of Phase 1.75. It covers:

- What was implemented and why
- The technical approach taken for each component
- Problems encountered during implementation and how each was mitigated
- Testing coverage and verification results
- Known limitations and recommended follow-up work
- Git handover and release artifact details

The report is written for engineering review and does not require any supplementary artifact to reproduce the implementation state.

---

## 2. Mission Recap

The MS1.75 brief required a lightweight, incremental extension of the existing mobile editor that would reduce friction when writing HTML, CSS, and JavaScript on an ordinary Android keyboard. The central product principle was explicit:

> *Keep the familiar Android keyboard, add the coding controls developers need, and make those controls operate naturally on the existing editor.*

The brief prohibited replacing the editor, implementing a custom input method, introducing a plugin registry, or adding a general-purpose state-management framework. It also required that no architectural changes be made to `nomad_core` solely to simplify a UI feature.

The implementation delivered in this sprint adheres to each of these constraints.

---

## 3. Baseline and Repository State at Sprint Start

Before any code was written, a repository inspection was performed per Section 4 of the brief. The baseline state was recorded as follows:

| Field | Value |
|---|---|
| Branch | `main` |
| HEAD | `2e44b2c` (tag `v0.15`) |
| Working tree | Clean |
| Analyzer | 0 issues |
| Tests (nomad_mobile) | 41 passing |
| Tests (nomad_core) | 20 passing |
| Flutter | 3.44.2 stable |
| Dart | 3.12.2 |

A tag housekeeping step was performed: the tag `v0.1.9` (which pointed at the create-project dialog keyboard-overflow fix on commit `b114ef1`) was deleted and replaced by the equivalent tag `v0.15.1` on the same commit, bringing the tag taxonomy into alignment with the current Phase 1.75 versioning scheme. No commits were moved or rewritten; only tag labels were adjusted.

Key existing files were inspected to establish the integration surface:

- `apps/nomad_mobile/lib/editor/code_editing_controller.dart` — Confirmed to extend `TextEditingController` and override only `buildTextSpan` for regex-based syntax highlighting. No existing editing-operation overrides. Safe to extend by programmatic value assignment.
- `apps/nomad_mobile/lib/editor/source_language.dart` — Confirmed to expose `SourceLanguage.fromFileName` and the four-value enum (`html`, `css`, `javascript`, `plainText`). Already consumed by `EditorView`.
- `apps/nomad_mobile/lib/ui/editor_view.dart` — Confirmed to be a stateful widget owning the controller and language. No explicit `FocusNode`; relied on `autofocus: true`. Dirty-state tracked via `onChanged` string comparison against `_initialContent`.
- `apps/nomad_mobile/test/editor/*` — Confirmed existing test conventions using `EntityId` identifiers and an `InMemoryFileContentRepository` mock pattern.
- `apps/nomad_mobile/pubspec.yaml` — Confirmed no keyboard, snippet, or editor-related third-party dependencies would be needed.

---

## 4. Components Implemented

### 4.1 `CodeInputActions` (`lib/editor/code_input_actions.dart`)

A stateless static helper class providing nine editing operations. It was deliberately scoped as a library-private, test-first module rather than as a mixin on `CodeEditingController` to keep text manipulation decoupled from the highlighting pipeline.

| Operation | Behavior |
|---|---|
| `insertText(controller, text)` | Replaces active selection or inserts at cursor; returns new cursor offset |
| `insertPaired(controller, open, close)` | For collapsed cursor: inserts both delimiters and places cursor between them. For selection: wraps the selection and preserves it |
| `moveCursorLeft/Right(controller, count)` | Shifts the collapsed cursor with boundary clamping |
| `moveCursorToLineStart(controller)` | Jumps to the first character of the current line |
| `moveCursorToLineEnd(controller)` | Jumps to the last character of the current line |
| `indent(controller, indent)` | Prepends `indent` (default two spaces) to the current line, or to every line in the selection |
| `unindent(controller, indent)` | Removes up to `indent.length` leading characters from the current line or selection |
| `insertTemplate(controller, template, cursorOffset)` | Inserts a multi-line template and places the cursor at the specified interior offset |

Every operation writes through `controller.value = TextEditingValue(...)` so that controller listeners are notified. This design decision proved critical during integration (see Section 5.2).

### 4.2 `CodeAccessoryBar` (`lib/editor/code_accessory_bar.dart`)

A 44-pixel-tall horizontal bar that docks between the editor text field and the system keyboard. The bar contains:

- A panel-toggle button (leftmost) that opens or closes the contextual panel. It changes icon and background color to reflect state.
- A horizontally scrollable row of monospace symbol buttons grouped into logical sections separated by thin vertical dividers.
  - **Paired delimiters:** `{}`, `()`, `[]`, `""`, `''`, `` `` ``, and `<>` (shown only when the active language is HTML).
  - **Punctuation and operators:** `=`, `;`, `:`, `/`, `.`, `,`, `!`, `&`, `|`, `+`, `-`, `*`, `?`.
  - **Indentation icons:** Indent and Unindent.
  - **Navigation icons:** Cursor Left and Cursor Right.

Every button is wrapped in a `_keepFocus` helper that invokes the action and then re-requests focus on the editor's `FocusNode` if focus was lost. This guarantees that tapping an accessory button never dismisses the soft keyboard.

### 4.3 `ContextualCodePanel` (`lib/editor/contextual_code_panel.dart`)

An expandable panel with a maximum height of 220 pixels that opens above the accessory bar. It is composed of:

- A 36-pixel header displaying `{Language} Tools` and a close button.
- A navigation section exposing Line Start, Line End, Indent, and Unindent as `ActionChip`s.
- A language-specific snippet section that renders a different set of chips based on `SourceLanguage`:
  - **HTML:** `<div>`, `<p>`, `<button>`, `<script>`, `class=""`, `id=""`, `<!-- comment -->`
  - **CSS:** `rule {}`, `flex center` (a three-line flex-centering declaration), `color`, `margin`, `padding`, `/* comment */`
  - **JavaScript:** `function()`, `() => {}`, `const`, `let`, `console.log()`, `if () {}`, `// comment`
  - **Plain Text:** Tab, List Item, Todo Item

Each snippet declares an explicit `cursorOffset` so the user lands inside the template at the position where they are most likely to type next (e.g., between the `()` of `console.log()`).

### 4.4 `EditorView` Integration (`lib/ui/editor_view.dart`)

The existing editor was extended with the following changes:

- A dedicated `FocusNode` is now instantiated in `initState` and disposed in `dispose`.
- The dirty-state mechanism was refactored. The previous implementation relied on `TextField.onChanged` comparing the live text against `_initialContent`. The new implementation subscribes to `_controller.addListener(_onControllerChanged)` directly. See Section 5.2 for why this was necessary.
- The editor body was restructured from a single `TextField` inside a `Padding` into a `Column` with three children:
  1. `Expanded` wrapping the `TextField`.
  2. The optional `ContextualCodePanel` (shown when `_isPanelExpanded` is true).
  3. The persistent `CodeAccessoryBar`.
- A `_togglePanel` setState handler was added to flip the panel's visibility.
- The `didUpdateWidget` lifecycle correctly tears down and reattaches the controller listener when the active file changes, and resets `_isPanelExpanded` to false to prevent stale panel state.

All existing behavior — syntax highlighting, Ctrl/Cmd+S save shortcut, preview toggle, load/retry/error flows, snackbar notifications — was preserved without modification.

---

## 5. Problems Encountered and Mitigations

Four substantive problems arose during implementation. Each is documented here with the diagnosis and the fix applied.

### 5.1 `RangeError` in `indent` and `unindent` at Document Start

**Problem.** The initial implementation of `indent` and `unindent` computed the current line start using `text.lastIndexOf('\n', start - 1) + 1`. When the selection or cursor was at offset zero (either in an empty document or on the first line of a document), `start - 1` evaluated to `-1`. Dart's `String.lastIndexOf` validates the `start` parameter against the inclusive range `[0, text.length]` and throws a `RangeError` when passed `-1`.

Two unit tests surfaced the defect immediately:
- `indent multiline selection` (selection from offset 0 to 11)
- `indent empty line` (cursor at offset 0 in a one-character document)

**Mitigation.** The computation was rewritten to short-circuit when the cursor is already at the document start:

```dart
final searchStart = (start - 1).clamp(0, text.length);
final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', searchStart) + 1;
```

The same guard was applied to `moveCursorToLineStart`. After the fix, all 29 unit tests in `code_input_actions_test.dart` passed, and the full mobile test suite rose from 68 passing / 2 failing to 70 passing / 0 failing.

**Lesson.** The brief's requirement to write unit tests before wiring operations to UI buttons was validated. The defect would have been materially harder to debug through the UI, and could have reached a user if the accessory bar had been built first.

### 5.2 Dirty State Not Updating on Accessory-Bar Edits

**Problem.** The widget test `Tapping accessory symbol inserts text and sets dirty state` failed. The test tapped the `;` button on the accessory bar and asserted that the save button's `onPressed` callback became non-null (indicating dirty state). The assertion failed because `onPressed` remained `null`.

**Diagnosis.** The original `EditorView` used Flutter's `TextField.onChanged` callback for dirty tracking. However, `onChanged` is only invoked for text-input events originating from the platform (physical or soft keyboard). Programmatic mutations via `controller.value = ...` — which is how `CodeInputActions` operates — fire the controller's listener list but **do not** trigger `onChanged`. The accessory bar edits were therefore invisible to the dirty-state check.

**Mitigation.** The dirty-tracking subscription was moved from `onChanged` to a direct controller listener:

```dart
_controller.addListener(_onControllerChanged);

void _onControllerChanged() {
  final dirty = _controller.text != _initialContent;
  if (dirty != _isDirty) {
    setState(() => _isDirty = dirty);
  }
}
```

The `onChanged` prop was removed from the `TextField`. The listener is correctly added in `initState`, removed and re-added in `didUpdateWidget` when the file changes, and removed in `dispose`.

This change unified the dirty-tracking path: keystrokes from the soft keyboard, programmatic insertions from the accessory bar, and template insertions from the contextual panel now all flow through the same code path.

**Lesson.** Flutter's `TextField` callback semantics differentiate between platform-sourced and programmatic edits. For a hybrid input model where both pathways coexist, controller listeners are the correct integration point.

### 5.3 Widget Test Compilation Failures Against `nomad_core` Contracts

**Problem.** The first draft of `editor_accessory_widget_test.dart` failed to compile with eleven analyzer errors. The mock repository used `String` parameters where `nomad_core.FileContentRepository` requires `EntityId`, declared a non-existent `deleteFile` method, missed the required `deleteContent` and `deleteAllContentForProject` methods, and the `FileNode` instantiation passed a `path` named parameter that does not exist on the model.

**Diagnosis.** The failing test file was authored by extrapolation from the brief's examples rather than from the actual `nomad_core` contracts. The brief had explicitly instructed that existing test conventions be reused.

**Mitigation.** A targeted inspection script was run against `apps/nomad_mobile/test/` to locate existing uses of `FileNode(` and `implements FileContentRepository`. The inspection surfaced two authoritative references:

- `test/editor/css_editing_test.dart` — Showed the correct `FileNode` constructor signature (no `path` parameter) and the correct `EntityId` usage.
- `test/branding/nomad_branding_test.dart` and `test/editor/css_editing_test.dart` — Showed the correct `FileContentRepository` mock surface with `readFile`, `writeFile`, `deleteContent`, and `deleteAllContentForProject` all accepting `EntityId` parameters.

The test file was rewritten to match these conventions, and `EntityId` instances were declared `const` to satisfy the `prefer_const_declarations` lint. After the fix, the three widget tests passed and the analyzer returned zero issues.

**Lesson.** Section 4.1 of the brief — "Mandatory Repository Inspection Before Coding" — exists precisely to prevent this class of error. When writing a new test file, the first action should always be a `grep` against existing tests for the exact types involved.

### 5.4 Tag Taxonomy Drift

**Problem.** The repository had two tags pointing to adjacent-but-distinct conceptual releases: `v0.1.9` (the MS0.1.9 keyboard overflow fix) and `v0.15` (the Phase 1 part 3 documentation compilation). The intent at MS1.75 start was to retire `v0.1.9` in favor of `v0.15.1`, aligning the tag minor-version with the active Phase 1.75 scheme.

A tag-creation command was executed before the deletion command, which temporarily left both `v0.1.9` and `v0.15.1` pointing to the same commit.

**Mitigation.** The `v0.1.9` tag was deleted locally with `git tag -d v0.1.9`, and `v0.15.1` was reaffirmed with `git tag -f v0.15.1 b114ef1`. No commits were moved and no history was rewritten. The final tag list contains `v0.15.1` on `b114ef1` and `v0.75.1` on the MS1.75 completion commit.

**Lesson.** For tag label changes, the correct ordering is to delete first and recreate second, confirmed in a single scripted block to avoid intermediate inconsistent states.

---

## 6. Testing and Verification Summary

### 6.1 Automated Test Results

| Suite | Count | Result |
|---|---|---|
| `code_input_actions_test.dart` (new) | 29 | Pass |
| `editor_accessory_widget_test.dart` (new) | 3 | Pass |
| `html_editing_test.dart` (existing) | — | Pass |
| `css_editing_test.dart` (existing) | — | Pass |
| `javascript_editing_test.dart` (existing) | — | Pass |
| All other `nomad_mobile` tests (existing) | — | Pass |
| **Total `nomad_mobile`** | **73** | **Pass** |
| **Total `nomad_core`** | **20** | **Pass** |

### 6.2 Analyzer and Formatter

- `flutter analyze` — 0 issues across the entire `nomad_mobile` package.
- `dart format .` — Formatted 47 files; 8 required reformatting (the new MS1.75 files plus two pre-existing files touched by the import ordering). All formatting changes were cosmetic.

### 6.3 Coverage of Brief Requirements

| Requirement | Status |
|---|---|
| FR-01 Preserve ordinary keyboard entry | Met. `TextField` remains the primary input; accessory is additive. |
| FR-02 Insert at correct location | Met. All operations respect selection and cursor. |
| FR-03 Paired delimiters | Met. Deterministic insertion with explicit cursor placement. |
| FR-04 Cursor navigation | Met. Left, right, line start, line end, all with bounds clamping. |
| FR-05 Indentation | Met. Single-line, multi-line, empty-line, and document-start cases tested. |
| FR-06 Simple snippets | Met. HTML, CSS, JS, and plain text snippets each specify cursor offset. |
| FR-07 Language awareness | Met. `SourceLanguage` drives both the accessory bar (HTML-only `<>` button) and the contextual panel's snippet set. |
| FR-08 Editor state integration | Met. All edits flow through controller listener → dirty state → save pipeline. |
| FR-09 Undo and redo | Partially met. Platform keyboard undo works for recent native keystrokes. Programmatic edits are not captured in an undo stack. Documented limitation. |
| FR-10 Phone-first usability | Met. 44-pixel bar, 220-pixel panel maximum, horizontal scrolling, no overflow at narrow widths. |

### 6.4 Manual Device Verification

No physical Android device was available during this sprint. All verification was performed via Flutter widget tests. This is documented in the "Known Limitations" section below and should be addressed in a follow-up pass before Phase 2 kicks off.

---

## 7. Known Limitations and Deferred Items

| Limitation | Rationale | Suggested Follow-Up |
|---|---|---|
| No programmatic undo/redo | `TextEditingController` lacks a multi-step history API. Implementing one requires non-trivial controller refactoring. | Post-MS2 — propose a `HistoryAwareTextController` as an ADR. |
| Platform device testing deferred | No physical Android device available in this sprint. | Add a device-pass sub-sprint before Phase 2. |
| No composing-text handling for IMEs | CJK and predictive-text composing regions were not explicitly tested. | Validate on Gboard and Samsung Keyboard; adjust if accessory taps disrupt composition. |
| Tablet layout not reoptimized | The bar and panel render correctly but are not adapted for larger screens. | Dedicated tablet pass in Phase 2. |
| No user-defined snippets | Snippets are hardcoded in `ContextualCodePanel._buildLanguageSnippets`. | Introduce a snippet persistence layer when Phase 2 adds project settings. |
| Haptic feedback not implemented | Not required by the brief. | Add on-tap haptics in a usability refinement pass. |

None of these limitations violates the MS1.75 exit criteria. Each is explicitly listed in accordance with Section 13 of the brief, which requires that unmet or partially met criteria be reported rather than silently closed.

---

## 8. Architectural Compliance

The brief listed several explicit prohibitions. Compliance for each is documented below.

| Prohibition | Compliance |
|---|---|
| Do not replace the editor | Preserved. `TextField` and `CodeEditingController` are unchanged. |
| Do not implement a custom input method | Preserved. The Android soft keyboard remains primary. |
| Do not introduce a new state-management framework | Preserved. Only `setState` is used. |
| Do not add a plugin registry | Preserved. No plugin surface was introduced. |
| Do not modify `nomad_core` for UI convenience | Preserved. Zero changes to `nomad_core` in this sprint. |
| Do not add new dependencies without justification | Preserved. `pubspec.yaml` is unchanged. |
| Do not force-push or rewrite history | Preserved. Only tag label changes were made, and only via standard `git tag -d` and `git tag -f` on local refs. |

No Architecture Decision Record was required for this sprint because no shared contract, persistence boundary, or public interface was modified.

---

## 9. Files Changed

### New files

| Path | Approximate LOC | Purpose |
|---|---|---|
| `apps/nomad_mobile/lib/editor/code_input_actions.dart` | 175 | Static editing-operation helper |
| `apps/nomad_mobile/lib/editor/code_accessory_bar.dart` | 195 | Compact accessory bar widget |
| `apps/nomad_mobile/lib/editor/contextual_code_panel.dart` | 195 | Expandable contextual panel widget |
| `apps/nomad_mobile/test/editor/code_input_actions_test.dart` | 210 | Unit tests for editing operations |
| `apps/nomad_mobile/test/editor/editor_accessory_widget_test.dart` | 120 | Widget tests for accessory UI |

### Modified files

| Path | Change |
|---|---|
| `apps/nomad_mobile/lib/ui/editor_view.dart` | Added `FocusNode`, controller listener, Column layout with accessory bar and panel, panel toggle handler, panel reset on file switch |
| `apps/nomad_mobile/lib/ui/web_preview_view.dart` | `dart format` whitespace only |
| `apps/nomad_mobile/test/ui/projects_view_overflow_test.dart` | `dart format` whitespace only |

### Renamed

| Old | New |
|---|---|
| `docs/phases/phase1/s0.1.9/post_completion_report.md` | `docs/phases/phase1/MS0.15/post_completion_report.md` |

**Aggregate diff:** 9 files changed, 1,190 insertions, 34 deletions.

---

## 10. Git Handover

| Field | Value |
|---|---|
| Branch | `main` |
| Head commit | `50ad6f6` |
| Head commit message | `feat(editor): implement Nomad Coding Input mobile accessory bar and contextual panel (MS1.75)` |
| Release tag | `v0.75.1` (annotated) |
| Tag housekeeping | `v0.1.9` deleted, `v0.15.1` created on `b114ef1` |
| Working tree | Clean |
| Remote push | Not yet performed. Awaiting senior review before pushing `main` and tag `v0.75.1` to `origin`. |
| Force-push | None |
| History rewrite | None |

Release APK was built prior to the commit from the equivalent working-tree state and is available at `apps/nomad_mobile/build/app/outputs/flutter-apk/app-release.apk`.

---

## 11. Recommendations for Review

I would appreciate senior review focus on the following:

1. **Dirty-state refactor in `EditorView`.** The move from `TextField.onChanged` to `_controller.addListener` is semantically correct for the hybrid input model but changes the editor's primary change-notification source. Please confirm that no downstream consumer depends on the previous `onChanged`-sourced behavior.
2. **Snippet cursor offsets.** The cursor offsets in `ContextualCodePanel._buildLanguageSnippets` were chosen by hand. If the team prefers a declarative snippet format (for example `|` as a cursor marker), this would be a reasonable moment to standardize before more snippets are added.
3. **Scope of the paired-delimiter model.** The current `insertPaired` operation is deliberately dumb (no quote-skipping, no auto-closing on typed delimiters). A smarter model would require either controller-level keystroke interception or a parse-aware wrapper. I'd like guidance on whether that is a Phase 2 item or sooner.
4. **Device verification.** The absence of physical-device testing is the one open gap against Section 11.D of the brief. Please advise whether a dedicated device-pass sub-sprint is warranted before pushing to `origin/main`.

---

## 12. Closing Note

MS1.75 delivered a working, tested, zero-dependency coding input experience that materially reduces the friction of writing HTML, CSS, and JavaScript on a mobile phone, without disturbing the existing editor, persistence, or preview workflows. The sprint followed the mandated inspect-first, test-first, UI-second sequence, and every production change is backed by an automated test.

Three implementation defects were caught by the test suite before they could reach a user, and each is documented above with its mitigation. The architectural prohibitions in the brief were observed in full. No ADR was required.

The feature is ready for senior review and, pending that review, for push to `origin/main` with tag `v0.75.1`.

---

*End of report.*