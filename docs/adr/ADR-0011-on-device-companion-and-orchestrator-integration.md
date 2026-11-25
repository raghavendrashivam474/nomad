# ADR-0011: On-Device Companion Provider and Orchestrator Integration

**Status:** Accepted  
**Date:** March 2026  
**Context:** Sprint AL-3  

## Context
Nomad Android Lab requires generating real native Android APKs directly on a physical phone. Because standard Android application sandboxes cannot spawn unconfined compilation toolchains directly, compilation is delegated to an on-device companion daemon running in Termux over loopback HTTP (127.0.0.1:8089).

## Decision
1. \AndroidBuildController\ will accept a \BuildProvider\ (defaulting to \BuildOrchestrator\) instead of being hard-coupled to \AndroidBuildService\.
2. \BuildOrchestrator\ will maintain registered providers: \LocalHostBuildProvider\ (for desktop OS) and \CompanionBuildProvider\ (for on-device/loopback Termux daemon).
3. \CompanionBuildProvider\ will snapshot workspace files, upload them via HTTP POST, poll execution status, stream the resulting APK into \ArtifactManager\, and verify SHA-256 integrity.
4. On desktop workstations, \LocalHostBuildProvider\ executes in-process via \AndroidBuildService\.
5. On Android devices, if the companion agent is running, builds execute via \CompanionBuildProvider\. If not running, a clear preflight diagnostic is displayed prompting the user to start the companion in Termux.

## Consequences
- 100% backward compatibility for desktop workstations and existing UI controllers.
- True native on-device compilation when running in companion mode on Android.
- Zero bypass or weakening of mobile OS sandbox constraints.
