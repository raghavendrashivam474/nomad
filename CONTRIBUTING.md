# Contributing to Nomad

Thank you for contributing to Nomad — the mobile-first development lab.

---

## 1. Golden Rules for Development

1. **Build the Smallest Clean Foundation:** Do not implement speculative architecture or unearned capabilities. Build only what is scoped for the active sprint.
2. **Strict Module Boundaries:**
   - `packages/nomad_core`: Pure Dart only. Zero Flutter UI dependencies.
   - `apps/nomad_mobile`: Presentation layer and device integration.
3. **Contract-Driven Design:** Inter-capability communication occurs strictly through explicit domain contracts.
4. **Document Architectural Changes:** Any structural or boundary change requires an Architecture Decision Record in `docs/adr/`.
5. **Pre-Implementation Safety:** Always run `git status` and inspect existing code before modifying. Never run destructive Git commands (`git reset --hard`, `git clean -fd`).

---

## 2. Development Workflow

### Prerequisites
- Dart SDK `>= 3.0.0`
- Flutter SDK (stable channel)
- Android SDK / build tools

### Working on `nomad_core` (Pure Dart)
```bash
cd packages/nomad_core
dart pub get
dart analyze --fatal-infos
dart test
dart format .
```

### Working on nomad_mobile (Flutter)

```Bash
cd apps/nomad_mobile
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter format .
flutter run
```

## 3. Pull Request & Commit Checklist

Before submitting changes or committing:

- ☐ Code is formatted (dart format .).
- ☐ Static analysis passes with zero issues (dart analyze / flutter analyze).
- ☐ All automated unit and widget tests pass (dart test / flutter test).
- ☐ Android debug build passes (flutter build apk --debug).
- ☐ Any architectural modification includes an ADR in docs/adr/.
- ☐ No speculative folders or unneeded dependencies were introduced.
