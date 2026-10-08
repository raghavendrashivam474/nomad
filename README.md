# Nomad — Mobile-First Development Lab

Nomad is a mobile-first development lab designed to build real small applications directly from phones and tablets, delegating heavy computation to personal or cloud runners.

## Current Sprint: S0.0.1 (Repository & Application Foundation)

### What Exists in S0.0.1
- **Repository Architecture:** Monorepo with `apps/` and `packages/` boundaries.
- **`packages/nomad_core`:** Pure Dart library for identifiers and domain exceptions.
- **`apps/nomad_mobile`:** Flutter application with responsive phone/tablet shell.
- **Responsive Breakpoint:** Adaptive layouts dynamically responding to screen width (`<600dp` compact phone, `>=600dp` tablet).
- **Engineering Baseline:** Static analysis, unit tests, widget tests, and CI configuration.

### What is Explicitly Out of Scope in S0.0.1
- Web / Android Lab code editors
- Local SQLite / Drift storage (coming in S0.0.3)
- Runner execution / remote compute
- Authentication / Cloud sync

## Repository Layout
```text
nomad/
├── apps/
│   └── nomad_mobile/       # Flutter application (Phone + Tablet)
├── packages/
│   └── nomad_core/         # Pure Dart core primitives & contracts
├── docs/
│   └── adr/                # Architecture Decision Records
└── .github/
    └── workflows/          # Continuous Integration workflows
```

## Running & Testing

### 1. Nomad Core (Dart)
```Bash
cd packages/nomad_core
dart pub get
dart analyze
dart test
```

### 2. Nomad Mobile (Flutter)

```Bash
cd apps/nomad_mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

### 3. Build Verification (Android Debug APK)

```Bash
cd apps/nomad_mobile
flutter build apk --debug
```