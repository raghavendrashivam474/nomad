# ADR-0005: Responsive Foundation & Multi-File Workspace Layout

## Status
Accepted

## Context
In S0.0.1–S0.0.5, Nomad developed the Project domain, SQLite metadata persistence, FileNode workspace trees, and the basic text editor. In S0.0.6, these capabilities must be composed into a responsive developer workspace that behaves naturally on both constrained phones (390×844) and expansive tablets/desktops (1024×768).

## Decision
1. **Adaptive Navigation & Presentation**:
   - **Phone Mode (< 600px)**: Sequential stack navigation.
     - Projects → Workspace File Tree → Fullscreen Monospaced Editor.
     - Bottom navigation bar hides during active project editing for maximum usable code space.
   - **Tablet Mode (>= 600px)**: Side-by-side IDE workspace.
     - Left pane: 300px collapsible workspace file explorer.
     - Right pane: Multi-file tab bar + monospaced editor / empty state placeholder.

2. **Multi-File Tab Bar (Tablet)**:
   - Opening a file creates or activates a tab.
   - Tab switching allows editing multiple files (`index.html`, `style.css`, `script.js`) without navigating away.
   - Closing a tab cleanly transfers focus to the nearest open tab or returns to the placeholder.

3. **Active Selection Highlighting**:
   - File trees highlight the currently open file node to maintain clear visual context across split layouts.

## Consequences
- Single codebase naturally adapts between handheld and tablet/desktop form factors.
- Developers maintain full context on large screens while preserving clean ergonomics on small screens.
