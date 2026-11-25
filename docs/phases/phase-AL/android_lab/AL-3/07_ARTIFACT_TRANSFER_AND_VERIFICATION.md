# Nomad AL-3: Artifact Transfer & Verification Protocol

## 1. Flow
1. Upon Gradle exit code 0, daemon locates pp/build/outputs/apk/debug/app-debug.apk.
2. Daemon computes SHA-256 and byte size, caching them with the completed jobId.
3. Nomad issues GET /api/v1/builds/{jobId}/artifact.
4. Nomad writes the incoming octet stream to a temporary file.
5. Nomad computes SHA-256 and compares it against X-APK-SHA256 from the response.
6. On checksum match, Nomad delegates to ArtifactManager.storeArtifact(), retaining the newest 3 builds and deleting older artifacts.
