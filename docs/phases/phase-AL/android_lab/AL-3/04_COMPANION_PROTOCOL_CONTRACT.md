# Nomad AL-3: Companion Agent Protocol Contract (v1)

**Canonical Port:** `127.0.0.1:8089`  
**Wire Format:** JSON over HTTP + Binary Octet-Stream for APK  

---

## Endpoint Specification

### 1. `GET /api/v1/capabilities`

Probe daemon availability, platform, and supported JDKs.

**Response (`200 OK`):**
```json
{
  "providerType": "companion",
  "isAvailable": true,
  "supportsCompose": true,
  "supportsOffline": true,
  "os": "android",
  "osVersion": "14",
  "supportedJdkVersions": ["17", "21"],
  "port": 8089
}
```

### 2. `POST /api/v1/builds`

Submit project files snapshot and initiate asynchronous compilation.

**Request Payload:**
```json
{
  "projectId": "proj_123",
  "buildType": "debug",
  "files": {
    "build.gradle.kts": "...",
    "settings.gradle.kts": "...",
    "app/build.gradle.kts": "...",
    "app/src/main/AndroidManifest.xml": "...",
    "app/src/main/java/com/nomad/lab/MainActivity.kt": "..."
  }
}
```

**Response (`202 Accepted`):**
```json
{
  "jobId": "job_1740000000",
  "status": "building",
  "projectId": "proj_123"
}
```

### 3. `GET /api/v1/builds/{jobId}/status`

Poll live compilation progress, console logs, and completion status.

**Response (`200 OK`):**
```json
{
  "jobId": "job_1740000000",
  "projectId": "proj_123",
  "status": "success",
  "durationMs": 42150,
  "log": "...[Gradle output]...",
  "errorMessage": null,
  "apkAvailable": true,
  "apkSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "apkByteSize": 9214512
}
```

### 4. `GET /api/v1/builds/{jobId}/artifact`

Stream raw APK bytes into Nomad's sandbox.

**Response Headers (`200 OK`):**
```http
Content-Type: application/vnd.android.package-archive
Content-Length: 9214512
X-APK-SHA256: e3b0c442...
```

### 5. `POST /api/v1/builds/{jobId}/cancel`

Terminate running Gradle process tree.

**Response (`200 OK`):**
```json
{
  "status": "cancelled",
  "jobId": "job_1740000000"
}
```