# Nomad — Architecture Decision Records (ADRs)

This directory documents all significant architectural decisions made within the Nomad project.

## Index of Decisions

| ADR | Title | Status | Sprint |
|---|---|:---:|:---:|
| [ADR-0001](ADR-0001-application-boundaries.md) | Application Boundaries & Monorepo Foundation | **Accepted** | S0.0.1 |
| [ADR-0002](ADR-0002-project-persistence.md) | Project Domain Persistence & SQLite Strategy | **Accepted** | S0.0.3 |
| [ADR-0003](ADR-0003-workspace-and-file-model.md) | Workspace and File Hierarchy Domain Model | **Accepted** | S0.0.4 |
| [ADR-0004](ADR-0004-file-content-storage-and-editor.md) | File Content Persistence & Basic Editor Architecture | **Accepted** | S0.0.5 |
| [ADR-0005](ADR-0005-responsive-workspace-layout.md) | Responsive Foundation & Multi-File Workspace Layout | **Accepted** | S0.0.6 |
| [ADR-0006](ADR-0006-embedded-http-server.md) | Embedded HTTP Server for Multi-File Web Preview | **Proposed** | MF-1 |

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
