# Nomad AL-3: Security, Failure Modes & Reliability Guardrails

## 1. Network Boundary
- The companion daemon binds strictly to InternetAddress.loopbackIPv4 (127.0.0.1).
- It is never exposed on 0.0.0.0.
- Only processes running on the physical phone can communicate with port 8089.

## 2. File and Path Safety
- Relative file paths uploaded via /api/v1/builds are validated against directory traversal.
- Any path containing '..' or leading '/' is discarded.
- Workspaces are isolated inside unique temporary directories (nomad_companion_job_*).

## 3. Process Lifetime & Cancellation
- The Gradle process is held in a job table.
- Calling /cancel sends SIGTERM to the process tree and cleans up temp files.
- Builds timeout after 5 minutes to prevent battery exhaustion.

## 4. Artifact Integrity
- The daemon calculates SHA-256 upon APK generation and supplies it in X-APK-SHA256.
- CompanionBuildProvider recalculates SHA-256 upon byte reception and rejects mismatched downloads.
