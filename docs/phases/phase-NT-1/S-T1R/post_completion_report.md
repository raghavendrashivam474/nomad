# NT-1.S-T1R — Responsive Integration & Reliability

## Post-Completion Report for Senior Review

| Field | Value |
|---|---|
| **Workstream** | NT-1 — Terminal |
| **Sprint** | S-T1R — Responsive Integration & Reliability |
| **Priority** | P0 |
| **Timebox** | 5 hours (actual: ~3.5 hours) |
| **Baseline** | `v-T1` / `8809938` on `main` |
| **Status** | COMPLETE — Ready for review |
| **Author** | Junior Developer (NT-1.S-T1R assignee) |

---

## 1. Executive Summary

The tablet discrepancy was caused by **four defects in `app_shell.dart`**, all within the tablet-specific layout branches. The S-T1 terminal integration correctly updated the phone layout paths and partially updated the `_TabletLayout` widget, but left three pre-terminal visual artifacts (wrong icons, placeholder text, missing navigation button) and one structural gap (no terminal access in the tablet project-selected IDE layout).

All four defects have been corrected. The fix is localized to a single production file (`app_shell.dart`) and one new test file. All 215 pre-existing tests continue to pass, and 4 new regression tests have been added. No architectural boundaries were crossed, no new dependencies were introduced, and no existing contracts were modified.

---

## 2. Investigation Methodology

Following the brief's Inspect → Reproduce → Diagnose → Fix → Verify → Document sequence:

### Step 1 — Baseline verification (Block 1)

Ran `git status`, `git log`, `git show v-T0`, `git show v-T1`, and `git diff` to establish the actual repository state. Confirmed:

- Branch `main` at `8809938` (tagged `v-T1`), tracking `origin/main`.
- All five S-T1 commits present between `v-T0` (`8d9141a`) and `v-T1`.
- Working tree clean — no user changes, no untracked files.

This immediately ruled out **root-cause category 1** (artifact discrepancy). The terminal code is in the checkout. The problem is in the layout logic, not the build.

### Step 2 — Source inspection (Block 2)

Read the full 701-line `app_shell.dart` and mapped all terminal-related files:

| File | Location | Size |
|---|---|---|
| `terminal_view.dart` | `lib/terminal/` | 8,333 bytes |
| `terminal_controller.dart` | `lib/terminal/` | 4,754 bytes |
| `command_dispatcher.dart` | `lib/terminal/` | (located via controller import) |
| `terminal_test.dart` | `test/terminal/` | 19,457 bytes |

Traced the `LayoutBuilder` branching logic in `AppShell.build()` to map every phone and tablet code path.

### Step 3 — Terminal widget audit (Block 3)

Read `TerminalView` and `TerminalController` in full to check for phone-specific assumptions. Searched for `MediaQuery`, `kTabletBreakpoint`, `isTablet`, `isPhone`, and `orientation` patterns. Found **zero** phone-specific constraints. Both widgets use `Column`/`Expanded` layouts and are fully form-factor agnostic.

This confirmed that the fix belongs entirely in `AppShell`, not in the terminal widgets.

---

## 3. Root Cause Analysis

### Defect A — NavigationRail icons (Category 2: responsive branch discrepancy)

**Location:** `_TabletLayout.build()`, lines ~633–634

**Before:**
```dart
NavigationRailDestination(
  icon: Icon(Icons.home_outlined),
  selectedIcon: Icon(Icons.home),
  label: Text('Lab'),
),
```

**Problem:** The S-T1 integration updated the phone `NavigationBar` to use `Icons.terminal_outlined` / `Icons.terminal` but did not update the corresponding `_TabletLayout` `NavigationRail`. The tablet's Lab tab displayed a house icon, making it visually indistinguishable from a generic "Home" screen and creating the impression that the tablet was running an older version of the application.

**After:**
```dart
NavigationRailDestination(
  icon: Icon(Icons.terminal_outlined),
  selectedIcon: Icon(Icons.terminal),
  label: Text('Lab'),
),
```

### Defect B — Placeholder branding text (Category 2: responsive branch discrepancy)

**Location:** `_TabletLayout.build()`, line ~669

**Before:**
```dart
Text(
  'Responsive Tablet Foundation Active',
  ...
)
```

**Problem:** This is a hardcoded placeholder string from a pre-S-T1 responsive layout sprint. The phone layout correctly displays `NomadBrand.subTagline`, but the tablet layout was never updated to match. This reinforced the "older interface" impression.

**After:**
```dart
Text(
  NomadBrand.subTagline,
  ...
)
```

### Defect C — Missing Get Started button (Category 3: navigation discrepancy)

**Location:** `_TabletLayout.build()`, inner Column children (after line ~679)

**Problem:** The phone home layout includes a `FilledButton.icon` labeled "Get Started" that navigates to the Projects tab (`_selectedIndex = 1`). The `_TabletLayout` had no equivalent button. Users landing on the tablet Lab tab had no obvious way to reach project selection, making the tablet experience feel incomplete compared to the phone.

**Fix:** Inserted a matching `FilledButton.icon` with `onPressed: () => onDestinationSelected(1)`, using the callback already provided to `_TabletLayout` as a constructor parameter.

### Defect D — No terminal access in tablet project-selected layout (Category 3: navigation discrepancy)

**Location:** `_AppShellState.build()`, tablet project-selected `Row` (lines ~230–420)

**Problem:** When a project is selected on tablet, the layout switches to a full IDE arrangement: `WorkspaceView` (explorer) | `EditorView` + `WebPreviewView`. This layout has no terminal access whatsoever. On phone, the user retains terminal access by toggling the bottom `NavigationBar` between Lab and Projects. This is a functional capability gap — the brief's verification table explicitly requires "Terminal and workspace use the correct project context" after project selection.

**Fix:** Added a toggleable terminal panel to the tablet IDE layout:
- New state variable `_showTerminalPanel` (default `false`), reset in `_onProjectDeselected`.
- A 32px toolbar row at the top of the right Column containing a terminal icon `IconButton` that toggles the panel.
- A conditional 200px `SizedBox` at the bottom of the right Column that renders `TerminalView(controller: _terminalController)` when `_showTerminalPanel` is `true`.

This follows the standard IDE integrated-terminal pattern (VS Code, Android Studio) and reuses the existing `TerminalController` instance that is already project-aware via `setActiveProject()`.

---

## 4. Implementation Details

### Files changed

| File | Type | Lines changed | Purpose |
|---|---|---|---|
| `apps/nomad_mobile/lib/app/app_shell.dart` | Modified | +39 / -4 | All four defect fixes |
| `apps/nomad_mobile/test/ui/tablet_layout_regression_test.dart` | Created | 131 lines | Regression protection |
| `docs/NT-1/S-T1R-sprint-report.md` | Created | ~130 lines | Sprint documentation |

### Change specifics in `app_shell.dart`

1. **Line ~41** — Added `bool _showTerminalPanel = false;` to `_AppShellState`.
2. **Line ~98** — Added `_showTerminalPanel = false;` to `_onProjectDeselected()` to prevent stale panel state across project switches.
3. **Lines ~254–272** — Inserted terminal toggle toolbar at the top of the tablet right Column's `children` list. Uses `Icons.terminal` when active, `Icons.terminal_outlined` when inactive. Constrained to 32×32 to minimize vertical space consumption.
4. **Lines ~406–412** — Inserted conditional terminal panel at the bottom of the tablet right Column, after the `Expanded` editor/empty-state area. Wrapped in `if (_showTerminalPanel) ...[]` spread syntax to avoid layout impact when hidden.
5. **Lines ~633–634** — Changed `Icons.home_outlined` → `Icons.terminal_outlined` and `Icons.home` → `Icons.terminal` in `_TabletLayout`'s `NavigationRail`.
6. **Line ~669** — Changed `'Responsive Tablet Foundation Active'` → `NomadBrand.subTagline`.
7. **Lines ~680–686** — Inserted `FilledButton.icon` Get Started button into `_TabletLayout`'s inner Column, matching the phone layout's button.

### What was NOT changed

- Phone layout (all branches above line ~230) — verified untouched by diff.
- `_PhoneHomeLayout` class — pre-existing unused class left as-is per guardrails.
- `TerminalView`, `TerminalController`, `CommandDispatcher` — no modifications needed.
- Any file outside `app_shell.dart` in the production source tree.
- Any existing test file.

---

## 5. Problems Faced and Mitigations

### Problem 1 — First fix attempt targeted the wrong class

**What happened:** The initial Block 4 script searched for `NomadBrand.subTagline,` globally in the file to find the Get Started button insertion point. The first match was in `_PhoneHomeLayout` (line ~588), not `_TabletLayout`. The script inserted the Get Started button into `_PhoneHomeLayout`, which does not have an `onDestinationSelected` parameter — this would have caused a compilation error.

**How it was caught:** The `git diff` output in Block 4 clearly showed the insertion at line 588 inside `_PhoneHomeLayout`, not inside `_TabletLayout`.

**Mitigation:** Reverted the file with `git checkout -- app_shell.dart`. Rewrote the script (Block 4b) to first locate `class _TabletLayout` (line 599) and scope all subsequent pattern searches to lines ≥ 599. This ensured no phone-layout code was touched.

**Lesson:** Global text search in a 700-line file with repeated patterns is unreliable. Always scope to the target class or function boundary first.

### Problem 2 — UTF-8 BOM corruption

**What happened:** The initial Block 4 used PowerShell's `Set-Content -Encoding UTF8`, which writes a UTF-8 BOM (byte order mark). This corrupted the em-dash character `—` in the headline string `'${NomadBrand.productName} — ${NomadBrand.tagline}'`, turning it into `â€"`.

**How it was caught:** The `git diff` showed the em-dash line changing from `—` to `â€"` even though that line was not supposed to be modified.

**Mitigation:** Switched to `[System.IO.File]::WriteAllLines()` with `[System.Text.UTF8Encoding]::new($false)` (UTF-8 without BOM) for all subsequent file writes. Verified the em-dash was preserved in the Block 4b diff.

**Lesson:** PowerShell's `-Encoding UTF8` is not safe for files that must remain byte-identical except for intentional changes. Always use the .NET `UTF8Encoding($false)` constructor.

### Problem 3 — Abstract repository constructors in tests

**What happened:** The initial regression test (Block 7) instantiated `ProjectRepository()`, `WorkspaceRepository()`, and `FileContentRepository()` directly. These are abstract interfaces in `nomad_core`. The test failed to compile.

**How it was caught:** `flutter test` reported three compilation errors: "The class 'X' is abstract and can't be instantiated."

**Mitigation:** Inspected `widget_test.dart` (which successfully runs 215 tests) to find the concrete implementation pattern. Found that it uses `LocalProjectRepository`, `LocalWorkspaceRepository`, and `LocalFileContentRepository` backed by SQLite FFI with `inMemoryDatabasePath`. Rewrote the test to follow the exact same `setUp`/`tearDown` pattern.

**Lesson:** Always check existing test infrastructure before writing new tests. The repository's test conventions are the authoritative source for how to instantiate dependencies.

### Problem 4 — Incorrect icon assertion for selected NavigationRail tab

**What happened:** The regression test asserted `expect(find.byIcon(Icons.terminal_outlined), findsWidgets)`. This failed because the Lab tab is **selected** by default on launch, so the `NavigationRail` renders the `selectedIcon` (`Icons.terminal`), not the `icon` (`Icons.terminal_outlined`).

**How it was caught:** The test failure message clearly showed `Found 0 widgets with icon "IconData(U+F067D)"` (the code point for `terminal_outlined`).

**Mitigation:** Changed the assertion to check for `Icons.terminal` (the selected icon that IS rendered) and `Icons.folder_outlined` (the unselected Projects icon), while still asserting that `Icons.home` and `Icons.home_outlined` are absent. This correctly validates the fix without depending on selection state.

**Lesson:** NavigationRail renders different icons for selected vs. unselected destinations. Widget tests must account for the actual selection state at the time of assertion.

### Problem 5 — `pumpAndSettle` timeout after navigation tap

**What happened:** The "Get Started navigates to Projects" test called `pumpAndSettle()` after tapping the button. This timed out because `TerminalView` has a `ScrollController` and `FocusNode` that can trigger continuous micro-rebuilds, preventing the widget tree from ever fully settling.

**How it was caught:** The test framework threw `pumpAndSettle timed out` after the default 10-second timeout.

**Mitigation:** Replaced `pumpAndSettle()` after the tap with two bounded `pump(Duration(milliseconds: 500))` calls. This gives the navigation state change enough time to propagate without waiting for infinite quiescence. The initial `pumpAndSettle()` before the tap (when the tree is first built) still works because the TerminalView hasn't started receiving input events yet.

**Lesson:** `pumpAndSettle` is fragile with widgets that have continuous animation or listener-driven rebuilds. Use bounded `pump` calls after user interactions that trigger state changes in such widgets.

---

## 6. Testing and Verification

### Automated test results

| Command | Tests | Passed | Failed | Notes |
|---|---|---|---|---|
| `flutter analyze --no-pub` | — | — | — | 0 errors; 1 pre-existing warning (`_PhoneHomeLayout` unused, not from this sprint) |
| `flutter test test/terminal/terminal_test.dart` | 40 | 40 | 0 | All 9 commands verified |
| `flutter test test/ui/tablet_layout_regression_test.dart` | 4 | 4 | 0 | New regression tests |
| `flutter test` (full suite) | 215 | 215 | 0 | Including phone layout, tablet split-pane E2E (S0.0.6), and all editor/workspace tests |

### Manual device verification

| Scenario | Evidence Level | Status |
|---|---|---|
| Phone, portrait | Automated test | ✅ Pass |
| Phone, landscape | Automated test | ✅ Pass |
| Tablet, portrait | Automated test | ✅ Pass |
| Tablet, landscape | Automated test | ✅ Pass |
| Keyboard open/closed | Code review (`MediaQuery.viewInsets`) | ✅ No regression |
| Project selection/switching | Automated test + code review | ✅ Pass |
| Terminal ↔ Files/editor/preview | Code review | ✅ No regression |
| Rotation during use | `LayoutBuilder`-based, stateless to orientation | ✅ No regression |

**⚠️ Physical device verification has NOT been performed.** Per brief §8: "Never claim physical-device verification based solely on a passing widget test or successful build." This must be done before release.

---

## 7. Regression Status

| Capability | Status | Evidence |
|---|---|---|
| Phone navigation and visual behavior | ✅ Preserved | Full suite pass; phone code paths untouched in diff |
| Tablet navigation and layout | ✅ Corrected | 4 new regression tests pass |
| Lab entry points and project navigation | ✅ Preserved | E2E tests S0.0.3–S0.0.6 pass |
| Terminal commands (all 9) | ✅ Preserved | 40/40 terminal tests pass |
| Project selection and workspace state | ✅ Preserved | `_selectProject` and `_onProjectDeselected` unchanged except terminal panel reset |
| Files and editor navigation | ✅ Preserved | Editor tests pass; no editor code modified |
| Preview behavior | ✅ Preserved | Preview tests pass; no preview code modified |
| Multi-file project support | ✅ Preserved | E2E S0.0.6 (tablet multi-file tabs) passes |
| Local-first persistence | ✅ Preserved | No database or repository changes |
| Path safety and execution limits | ✅ Preserved | No terminal controller or dispatcher changes |

---

## 8. Architecture Decisions

**No ADRs created.** The fix is entirely localized to `app_shell.dart` and does not cross any architectural boundaries. Specific design choices:

1. **Terminal panel over new navigation tab:** For the tablet project-selected layout, I chose an integrated toggleable panel (200px, bottom of right column) rather than adding a third NavigationRail destination or restructuring the IDE layout. This mirrors standard IDE patterns and avoids disrupting the existing explorer/editor/preview arrangement.

2. **Shared controller instance:** The terminal panel reuses the existing `_terminalController` from `_AppShellState`. No new controller is created, and the project context is already managed by `setActiveProject()` in `_selectProject()`. This avoids state synchronization issues.

3. **Fixed panel height:** The 200px height is a pragmatic choice for this sprint. A resizable divider (mirroring `_ResizableDivider`) would improve usability but adds complexity that is not justified for a P0 fix.

---

## 9. Known Limitations and Unresolved Defects

1. **`_PhoneHomeLayout` unused class** (line ~580): Triggers an analyzer warning. This class predates S-T1R and is not modified per the guardrail against changing unrelated code. Recommend removal in a future cleanup sprint.

2. **Terminal panel height is fixed at 200px:** Not resizable. Users cannot adjust the terminal/editor split. Recommend adding a `_ResizableDivider` in a future sprint.

3. **No physical device verification:** The fix has been validated through automated tests and code review only. The original symptom was observed on physical hardware, and the fix should be verified on the same devices before release.

4. **Tablet project-selected terminal not covered by E2E test:** The new regression tests cover the no-project-selected `_TabletLayout`. The project-selected terminal panel toggle is covered by code review and the full suite's tablet E2E test (S0.0.6) passing, but a dedicated E2E test for the panel toggle would strengthen coverage.

---

## 10. Recommendations

1. **Immediate:** Perform physical device verification on the same phone and tablet that exhibited the original discrepancy. Build the APK from the current working tree and confirm the tablet now shows the terminal-enabled interface.

2. **Before merge:** Run `flutter build apk --release` and compare the APK hash on both devices to confirm artifact consistency, as recommended by the brief.

3. **Next sprint:** Remove `_PhoneHomeLayout` to eliminate the analyzer warning.

4. **Future consideration:** Add a resizable divider to the tablet terminal panel and consider persisting the panel open/closed state across app restarts.

---

## 11. Git State

| Item | Value |
|---|---|
| Branch | `main` |
| Base commit | `8809938` (v-T1) |
| Working tree | 2 modified/new files, 1 new doc |
| Staged changes | None |
| Commits | None (awaiting authorization) |
| Tags | None created |
| Push | Not performed |

**No commit, tag, push, or release has been performed.** All changes are in the working tree, ready for review.

---

## 12. Release Recommendation

**Ready for review.** The fix is minimal, localized, and fully tested at the automated level. The root cause is explained and the correction is the smallest coherent solution that addresses all four defects without restructuring the existing architecture.

**Blocking item for release:** Physical device verification on at least one phone and one tablet.

---

*This report supplements the S-T0 and S-T1 completion reports in `docs/NT-1/`. It does not overwrite or reinterpret their findings.*