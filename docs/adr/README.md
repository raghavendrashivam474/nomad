# Nomad — Architecture Decision Records (ADRs)

This directory documents all significant architectural decisions made within the Nomad project.

## Index of Decisions

| ADR | Title | Status | Sprint |
|---|---|:---:|:---:|
| [ADR-0001](ADR-0001-application-boundaries.md) | Application Boundaries & Monorepo Foundation | **Accepted** | S0.0.1 |

---

## When to Write an ADR

An ADR must be created whenever:
1. A new package or architectural boundary is introduced.
2. An existing architectural constraint or communication contract is changed.
3. A major dependency, persistence engine, or execution paradigm is adopted or replaced.

---

## Standard ADR Template

New ADRs should follow this structure:

```markdown
# ADR-XXXX — <Title>

## Context
What problem exists?

## Decision
What are we changing?

## Why
Why is this better?

## Alternatives Considered
What alternatives were evaluated and why were they rejected?

## Consequences
What improves? What becomes harder or requires careful handling?

## Migration
How do we move safely from the previous design?

## Status
Accepted / Proposed / Superseded
