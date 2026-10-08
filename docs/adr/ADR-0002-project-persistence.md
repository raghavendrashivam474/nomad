# ADR-0002: Project Persistence and Repository Boundaries

## Status
Accepted

## Context
In S0.0.2, the pure Dart Project entity and ProjectRepository contract interface were introduced in 
omad_core. In S0.0.3, Nomad requires persisting projects locally so they survive application restarts.

We must ensure that:
1. 
omad_core remains pure Dart and has no dependencies on SQLite, Drift, or Flutter.
2. The persistence layer implements the ProjectRepository boundary.
3. The database schema remains minimal and strictly scoped to current requirements.

## Decision
1. Retain the ProjectRepository abstract contract inside 
omad_core.
2. Implement LocalProjectRepository inside 
omad_mobile using SQLite (sqflite).
3. Maintain an explicit ProjectMapper separating database row representation from the domain entity.
4. Schema for projects table:
   - id: TEXT PRIMARY KEY
   - 
ame: TEXT NOT NULL
   - 	ype: TEXT NOT NULL
   - created_at: TEXT NOT NULL (ISO-8601)
   - updated_at: TEXT NOT NULL (ISO-8601)

## Consequences
- Nomad_core remains 100% decoupled from persistence mechanisms.
- Testing persistence is decoupled via SQLite FFI in-memory databases.
- Future migration to Drift or other engines will only require updating the infrastructure repository implementation without altering domain code.
