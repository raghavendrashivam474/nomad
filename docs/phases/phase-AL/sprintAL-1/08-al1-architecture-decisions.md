# AL-1 Architecture Decisions

**Date**: 2026-10-25
**Document**: 08-al1-architecture-decisions.md
**Milestone**: AL-1

## Summary of Architectural Evaluation
No material architectural changes to existing shared contracts are required.
Existing contracts (\WorkspaceRepository\, \FileContentRepository\, \ProjectType\, \ProjectRepository\, \ProjectMaterializer\) are preserved intact.

## Key Design Decisions

### ADR-AL1-1: Dedicated Build Diagnostics UI vs Overloading LiveActivityController
- **Context**: AL-0 had no UI for build logs. LiveActivityController is currently tailored for Web preview iframe/server logs with preview session IDs.
- **Decision**: Keep \LiveActivityController\ dedicated to Web preview and introduce \BuildDiagnosticsSheet\ directly reading \BuildResult\ from \AndroidBuildController\.
- **Rationale**: Prevents coupling Android build lifecycles to Web session semantics and eliminates risk of regressing existing Web preview tests.

### ADR-AL1-2: Non-daemon Gradle Builds & Explicit Concurrency Mutex
- **Context**: Android builds on mobile host must be conservative with memory and resources.
- **Decision**: Continue utilizing \--no-daemon --console=plain\ and enforce a strict singleton build mutex in \AndroidBuildController\.
- **Rationale**: Prevents Gradle daemon memory retention on constrained host environments and avoids concurrent build collisions.
