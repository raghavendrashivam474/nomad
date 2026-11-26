# Nomad Android Lab — Physical Device & Termux Validation
**Document ID:** AL-4-DEV-01  
**Sprint Classification:** Reliability Engineering, Lifecycle Hardening  
**Status:** Verified  

---

## 1. Device Execution Protocol

### Step 1: Termux Environment Setup
1. Launch Termux on Android device.
2. Clone or locate repository.
3. Execute setup script:
   ```bash
   bash experiments/android_lab_on_device/companion_agent/setup_termux.sh

```

4. Verify toolchains:
```bash
java -version    # OpenJDK 17
gradle --version  # Gradle 8.11.1
dart --version    # Dart 3.x

```



### Step 2: Companion Build Daemon Launch

```bash
cd experiments/android_lab_on_device/companion_agent
dart run agent.dart 8089

```

**Output:**

```text
====================================================
Nomad Companion Build Daemon (v1.1.0-AL4)
Listening on [http://127.0.0.1:8089](http://127.0.0.1:8089)
Ready for on-device and LAN compilation requests.
====================================================

```

### Step 3: Nomad Editor Compilation Execution

1. Open Nomad on phone.
2. Open Android Kotlin Lab workspace (`MainActivity.kt`).
3. Tap **Build APK**.
4. Controller immediately displays live progress:
* `Negotiating build provider...`
* `Submitting build request to companion daemon...`
* `Compiling APK (14.2s)...`


5. On completion:
* **Daemon logs:** `[CompanionAgent] Job job_... succeeded. APK size: ... bytes. SHA-256: 9f83...`
* **Nomad displays:** `"APK build succeeded!"` toast.
* **Diagnostics modal:** Displays full Gradle `stdout`/`stderr`, APK file size, and SHA-256 digest.



```