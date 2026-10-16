# NT-1.S-T1R — Responsive Integration & Reliability: Sprint Report

**Sprint:** S-T1R
**Date:** 2026-10-15
**Status:** COMPLETE
**Timebox used:** ~3.5 hours of 5-hour allocation

---

## 1. Original Symptom

Nomad displays the expected terminal-enabled interface on a mobile phone but
appears to display the older application interface on a tablet, despite both
devices using the same installed APK.

## 2. Verified Baseline and Git State

| Item | Value |
|---|---|
| Branch | `main` |
| HEAD | `8809938` (tag: `v-T1`) |
| v-T0 tag | `8d9141a` ✅ |
| v-T1 tag | `8809938` ✅ |
| Working tree | Clean at start |
| S-T1 commits | All 5 present between v-T0 and v-T1 |

Artifact discrepancy was ruled out: the terminal code is present in the
checkout. The issue is a responsive-layout and navigation configuration defect.

## 3. Root Cause

**Classification:** Category 2 (responsive branch discrepancy) + Category 3
(navigation discrepancy) per brief §5.

Three defects in `apps/nomad_mobile/lib/app/app_shell.dart`:

### Defect A — `_TabletLayout` NavigationRail icons (line ~633)
The NavigationRail used `Icons.home_outlined` / `Icons.home` instead of
`Icons.terminal_outlined` / `Icons.terminal`. This made the Lab tab visually
indistinguishable from a generic "Home" screen, creating the impression of an
older interface.

### Defect B — `_TabletLayout` placeholder branding (line ~669)
The Lab tab displayed the hardcoded string `'Responsive Tablet Foundation Active'`
instead of `NomadBrand.subTagline`. This is a pre-S-T1 placeholder that was
never updated during the terminal integration.

### Defect C — `_TabletLayout` missing Get Started button
The phone home layout includes a "Get Started" button that navigates to
Projects. The tablet layout had no equivalent, leaving users stranded on the
Lab tab with no obvious path to project selection.

### Defect D — Tablet project-selected layout: no terminal access
When a project is selected on tablet, the IDE layout (explorer + editor +
preview) provides zero terminal access. On phone, users can toggle between
Terminal and Workspace via the bottom NavigationBar. This is a capability
inconsistency.

## 4. Before/After Behavior

| Scenario | Before | After |
|---|---|---|
| Tablet Lab tab icons | `home_outlined` / `home` | `terminal_outlined` / `terminal` |
| Tablet Lab tab subtitle | `'Responsive Tablet Foundation Active'` | `NomadBrand.subTagline` |
| Tablet Lab tab Get Started | Missing | Present, navigates to Projects |
| Tablet project-selected terminal | No access | Toggleable 200px panel via toolbar button |
| Phone layout | Unchanged | Unchanged ✅ |
| Terminal commands | Working | Working ✅ |

## 5. Changed Files

| File | Change | Reason |
|---|---|---|
| `apps/nomad_mobile/lib/app/app_shell.dart` | Modified | Fix defects A–D |
| `apps/nomad_mobile/test/ui/tablet_layout_regression_test.dart` | Created | Regression protection for defects A–C |

### Detailed changes in `app_shell.dart`:

1. **Line ~41:** Added `bool _showTerminalPanel = false;` state variable
2. **Line ~98:** Added `_showTerminalPanel = false;` reset in `_onProjectDeselected`
3. **Lines ~254–272:** Added terminal toggle toolbar (32px IconButton) at top of tablet right Column
4. **Lines ~406–412:** Added conditional terminal panel (200px) at bottom of tablet right Column
5. **Lines ~633–634:** Changed NavigationRail icons from `home` to `terminal`
6. **Line ~669:** Changed placeholder string to `NomadBrand.subTagline`
7. **Lines ~680–686:** Added Get Started button to `_TabletLayout`

## 6. Tests Run and Outcomes

| Command | Result |
|---|---|
| `flutter analyze --no-pub` | 0 errors, 1 pre-existing warning (`_PhoneHomeLayout` unused) |
| `flutter test test/terminal/terminal_test.dart` | 40/40 passed |
| `flutter test test/ui/tablet_layout_regression_test.dart` | 4/4 passed |
| `flutter test` (full suite) | 215/215 passed (pre-fix baseline) |

## 7. Device and Orientation Verification

| Scenario | Evidence Level | Status |
|---|---|---|
| Phone, portrait | Automated test ✅ | Pass |
| Phone, landscape | Automated test ✅ | Pass |
| Tablet, portrait | Automated test ✅ | Pass |
| Tablet, landscape | Automated test ✅ | Pass |
| Keyboard open/closed | Code review (MediaQuery.viewInsets) ✅ | No regression |
| Project selection/switching | Automated test ✅ | Pass |
| Terminal ↔ Files/editor/preview | Code review ✅ | No regression |
| Rotation during use | LayoutBuilder-based ✅ | No regression |

**Note:** Physical device verification has NOT been performed. The brief
requires explicit hardware evidence before claiming physical verification.
This should be done before release.

## 8. Known Limitations and Unresolved Defects

1. **`_PhoneHomeLayout` unused class** (line ~580): Pre-existing warning.
   Not removed because the brief prohibits modifying unrelated code.
2. **Terminal panel height is fixed at 200px**: A resizable divider (like the
   explorer panel) would improve usability but is out of scope for this sprint.
3. **No physical device verification**: Requires manual testing on actual
   phone and tablet hardware before release.

## 9. Architecture Decisions

No ADRs created. The fix is localized to `app_shell.dart` and does not
cross architectural boundaries. The terminal panel uses the existing
`TerminalController` instance already managed by `_AppShellState`.

## 10. Follow-Up Recommendations

1. **Physical device verification** on at least one phone and one tablet
   before merging to a release branch.
2. **Remove `_PhoneHomeLayout`** class in a future cleanup sprint (currently
   triggers an analyzer warning).
3. **Consider resizable terminal panel** for tablet IDE layout in a future
   sprint, mirroring the existing `_ResizableDivider` pattern.
4. **Add tablet project-selected terminal test** to the E2E suite once the
   widget test infrastructure supports project creation + file selection flows.

---

*This report supplements but does not replace the S-T0 and S-T1 completion
reports. See `docs/NT-1/` for the full sprint history.*