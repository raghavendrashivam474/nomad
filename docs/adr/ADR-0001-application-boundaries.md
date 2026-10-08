# ADR-0001 — Application Boundaries and Monorepo Foundation

## Context
Nomad is designed as a mobile-first development lab capable of progressive distribution (hybrid local/personal/cloud compute). S0.0.1 requires establishing a clean foundation without premature complexity (no speculative microservices, no full state management trees, no premature database locks).

## Decision
1. Organize the repository as a lightweight monorepo separating consumer applications (`apps/nomad_mobile`) from core domain primitives (`packages/nomad_core`).
2. `nomad_core` is pure Dart (platform-agnostic), containing zero Flutter UI dependencies.
3. `nomad_mobile` consumes `nomad_core` via local path dependency and establishes a responsive shell (`AppShell`) with a breakpoint at 600dp separating phone (compact) and tablet (expanded rail) layouts.
4. Future capabilities (Runner, Projects, Storage) will communicate across explicit contracts rather than direct coupling.

## Why
- Prevents UI bleed into domain models.
- Guarantees phone and tablet adaptation from day one.
- Preserves evolutionary compatibility without requiring architectural rewrites in later sprints.

## Alternatives Considered
- *Single flat Flutter application:* Rejected because core domain logic would quickly become coupled with Flutter UI widgets and platform code.
- *Full multi-package speculative architecture (adding runner, auth, cloud folders now):* Rejected per S0.0.1 sprint boundaries against speculative scaffolding.

## Consequences
- **Positive:** Clean dependency graph, testable pure core, robust responsive shell foundation.
- **Negative:** Requires running pub/test commands in respective workspace directories until global workspace tooling is configured.

## Migration
Initial baseline established in sprint S0.0.1.

## Status
Accepted
