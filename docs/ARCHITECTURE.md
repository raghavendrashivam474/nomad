# Nomad — Architecture & Engineering Principles

## 1. Product Vision
Nomad is a **mobile-first development lab** enabling developers to build small, real applications directly from phones and tablets. It is not intended to be a heavyweight desktop IDE squeezed onto a mobile screen, nor a permanent cloud VM client. It is a lightweight, local-first development studio that delegates heavy computation on demand.

---

## 2. Core Architectural Pillars

Nomad is architected around five locked principles:

### 2.1 Hybrid Execution
Compute runs in the simplest and closest tier that makes sense:
- **Local (Mobile Device):** Lightweight, latency-sensitive operations (editing, tree parsing, local project management, local file changes).
- **Personal Runner (PC / Home Server):** Heavy compilation, packaging, and builds without cloud cost.
- **Cloud Runner:** Elastic, on-demand compute when personal compute is unavailable.

### 2.2 Contract-Driven Design
Capabilities communicate strictly across defined interfaces/contracts (e.g., `WorkspaceContract`, `ProjectContract`, `FileContract`, `RunnerContract`). Contracts declare *what* a capability promises, isolating implementation details.

### 2.3 Capability-Oriented Structure
Capabilities (e.g., Projects, File Explorer, Web Lab, Android Lab, Runner) are added modularly. Cross-cutting features should be introduced as distinct capabilities rather than intertwined into unrelated code.

### 2.4 Evolution-Compatible
Future technology shifts (e.g., migrating from local storage to alternative storage engines, switching transport from HTTP to gRPC) must not necessitate a complete rewrite of domain logic or user interfaces.

### 2.5 Strict Module Boundaries
- `nomad_core`: Pure Dart domain primitives, entities, contracts, and exceptions. Zero Flutter UI dependencies.
- `nomad_mobile`: Presentation layer, responsive layouts, device interactions, and state binding.


```text
┌───────────────────────────────────────────────┐
│                 nomad_mobile                  │
│       (Flutter UI / Responsive Shell)         │
│  ┌─────────────────────────────────────────┐  │
│  │  Infrastructure (LocalProjectRepository │  │
│  │  + SQLite/sqflite persistence)          │  │
│  └──────────────────┬──────────────────────┘  │
└─────────────────────┼─────────────────────────┘
                      │
                      ▼  (Contracts & Primitives)
┌───────────────────────────────────────────────┐
│                  nomad_core                   │
│          (Pure Dart Domain Logic)             │
│  Project · ProjectType · ProjectRepository    │
│  EntityId · NomadException                    │
└───────────────────────────────────────────────┘
```

## 3. Contract Governance Model

Contracts represent system-level engineering invariants:

- **Developer**: Defines, versions, and evolves contracts and architectural policies.
- **Admin (Future)**: Configures authorized policies and operational capabilities.
- **User**: Utilizes capabilities strictly permitted by policy; cannot modify or bypass architectural contracts.

## 4. Repository Layout

```text
nomad/
├── apps/
│   └── nomad_mobile/       # Flutter client application
├── packages/
│   └── nomad_core/         # Core domain primitives and contracts
├── docs/
│   ├── ARCHITECTURE.md     # System architecture & guidelines
│   └── adr/                # Architecture Decision Records
└── .github/
    └── workflows/          # Automated verification workflows
```

## 5. Sprint Evolution Roadmap

- **S0.0.1** ✅: Repository & Application Foundation, Responsive App Shell.
- **S0.0.2** ✅: Project Domain Model (Project, ProjectType, EntityId, invariants).
- **S0.0.3** ✅: Local Persistence & Storage Contracts (SQLite/sqflite, ProjectRepository, ProjectMapper).
- **S0.0.4 (Current)**: File Explorer & Virtual Workspace.
- **S0.0.5**: Mobile Editor Foundation.
