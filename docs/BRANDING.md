```markdown
# Nomad — Brand Identity & Design System

**Established:** Sprint S0.0.7 (V0.0 Seed → V0.1 Web Lab Transition)  
**Status:** Authoritative  

---

## 1. Authoritative Mark

The Nomad logo is the primary, authoritative product mark.

```text
Asset Path: apps/nomad_mobile/assets/branding/nomad_logo.jpeg
Critical Rule
The approved Nomad logo is the authoritative product mark. It must not be altered, redrawn, recolored, re-proportioned, or replaced without explicit product and design approval.

```

## 2. Product Identity

* **Product Name:** Nomad
* **Tagline:** Mobile-First Development Lab
* **Sub-tagline:** Development. Everywhere You Go.
* **Android App Label:** Nomad
* **Internal Flutter Package:** `nomad_mobile`
* **Internal Domain Package:** `nomad_core`

---

## 3. Brand Tokens (`NomadBrand`)

Located in: `apps/nomad_mobile/lib/branding/nomad_brand.dart`

### Color Palette (Sampled from Authoritative Mark)

| Token | Hex Value | Role & Usage |
| --- | --- | --- |
| `primary` | `#D97706` | Warm Amber / Desert Ochre (Core accent) |
| `primaryVariant` | `#B45309` | Deep Amber (Light theme primary) |
| `accent` | `#F59E0B` | Golden Ochre (Dark theme primary) |
| `earth` | `#462C1D` | Deep leather / warm earth tone |
| `sand` | `#DDD1C5` | Light sand tone |
| `surfaceLight` | `#F8FAFC` | Clean slate light surface |
| `surfaceDark` | `#0B0F17` | Deep slate midnight surface |
| `surfaceContainerDark` | `#161E2E` | Elevated dark container surface |
| `cardDark` | `#1E293B` | Card elevation dark |

### Spacing Scale

* `space4`: `4.0`
* `space8`: `8.0`
* `space12`: `12.0`
* `space16`: `16.0`
* `space24`: `24.0`
* `space32`: `32.0`
* `space48`: `48.0`

### Radius Scale

* `radiusSmall`: `8.0` (Buttons, inputs)
* `radiusMedium`: `12.0` (Cards, list tiles)
* `radiusLarge`: `16.0` (Dialogs, bottom sheets)
* `radiusCircular`: `999.0` (Badges, circular elements)

---

## 4. Reusable Widgets

### `NomadLogo`

Located in: `apps/nomad_mobile/lib/branding/nomad_logo_widget.dart`

```dart
NomadLogo(
  size: 28.0,         // Proportional scaling
  showBorder: true,   // Subtle border outline
)

```

* Preserves exact aspect ratio and visual geometry.
* Provides fallback rendering for test environments.

---

## 5. UI Surfaces & Restraint

The Nomad mark is used strategically and with restraint:

* **Android Launcher:** Multi-density mipmap icons (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
* **Startup / Splash:** Featured prominently on initial application launch.
* **AppShell Header:** Compact 24px branded mark alongside product title.
* **Tablet Navigation Rail:** Prominent leading brand mark.
* **Workspaces & Editor:** Keeps the development workspace visually subordinate to the user's code.

---

---

# Sprint S0.0.7 — Post Completion Report

## Nomad Identity & Branding Micro-Sprint

**Sprint:** `S0.0.7 — Identity & Branding`

**Phase:** `V0.0 Seed -> V0.1 Web Lab Transition`

**Status:** `COMPLETE`

**Date:** October 2026

**Test Suite:** `nomad_core: 20/20` | `nomad_mobile: 22/22` (100% green)

---

## 1. Executive Summary

Sprint S0.0.7 established the first official visual identity and branding layer for the Nomad product prior to entering Phase 1 (V0.1 Web Lab).

The authoritative Nomad mark has been fully integrated into the Flutter mobile application, Android platform manifest, and launcher icon resources, backed by a centralized design token system.

---

## 2. Key Deliverables

1. **Authoritative Logo Integration:**
* Asset location: `apps/nomad_mobile/assets/branding/nomad_logo.jpeg`.
* Reusable `NomadLogo` widget preserving original proportions and visual fidelity.


2. **Android Application Identity:**
* Updated Android manifest label from `nomad_mobile` to `Nomad`.
* Generated mipmap launcher icons across all standard densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
* Verified release and debug APK compilation (`app-release.apk` 48.18 MB).


3. **Centralized Brand System (`NomadBrand`):**
* Palette sampled directly from the authoritative mark.
* Material 3 compliant Light and Dark theme definitions.
* Centralized tokens for spacing and corner radii.


4. **Branded Application Surfaces:**
* Branded AppShell header with non-overflowing responsive title row.
* Branded phone home/startup view and tablet navigation rail layout.
* Branded empty states and dialogs for Projects and Workspace views.


5. **Documentation:**
* `docs/BRANDING.md`: Complete design system tokens and modification rules.
* S0.0.7 Post-Completion Report.



---

## 3. Test & Verification Matrix

| Package | Test Scope | S0.0.6 Baseline | S0.0.7 Result | Status |
| --- | --- | --- | --- | --- |
| `nomad_core` | Domain & Entities | 20 passed | 20 passed | ✔ PASS |
| `nomad_mobile` | UI, E2E, Persistence, Branding | 16 passed | 22 passed | ✔ PASS |
| **Total** |  | **36 passed** | **42 passed** | **✔ 100% Green** |

---

## 4. Modified & Created Files

* `apps/nomad_mobile/assets/branding/nomad_logo.jpeg`
* `apps/nomad_mobile/lib/branding/nomad_brand.dart`
* `apps/nomad_mobile/lib/branding/nomad_logo_widget.dart`
* `apps/nomad_mobile/test/branding/nomad_branding_test.dart`
* `apps/nomad_mobile/android/app/src/main/res/mipmap-*/ic_launcher.png`
* `apps/nomad_mobile/android/app/src/main/AndroidManifest.xml`
* `apps/nomad_mobile/pubspec.yaml`
* `apps/nomad_mobile/lib/app/nomad_app.dart`
* `apps/nomad_mobile/lib/app/app_shell.dart`
* `apps/nomad_mobile/lib/ui/projects_view.dart`
* `apps/nomad_mobile/lib/ui/workspace_view.dart`
* `docs/BRANDING.md`
* `docs/phases/phase0/s0.0.7/post_completion_report.md`
* `README.md`

```

```