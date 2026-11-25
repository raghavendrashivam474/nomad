# AL-1 Gradle Build Execution Root Cause Investigation
**Date**: 2026-10-25  
**Document**: `06-al1-build-execution-investigation.md`  
**Milestone**: AL-1

## 1. Symptom & Initial Observation
During benchmark test execution (`real_gradle_build_benchmark_test.dart`):

```text
Cold Build 1 Status: BuildStatus.failure
Cold Build 1 Duration: 106 ms
Cold Build 1 Error: ProcessException: The system cannot find the file specified
  Command: gradlew.bat assembleDebug --no-daemon --console=plain
```

The test suite passed (`All tests passed!`) because the benchmark assertion checked `expect(result1.status, anyOf(BuildStatus.success, BuildStatus.failure))`.

## 2. Root Cause Analysis

* **Windows Process Execution Semantics**:
  * Dart's `dart:io` `Process.start(executable, ...)` on Windows invokes `CreateProcessW`.
  * When a relative executable name such as `gradlew.bat` is passed, Windows looks in the system `%PATH%` and current process working directory, not the `workingDirectory` parameter passed to `Process.start`.
  * Because `gradlew.bat` is inside the temporary materialized project directory (e.g., `C:\Users\...\AppData\Local\Temp\nomad_android_...`), `Process.start` throws `ProcessException: The system cannot find the file specified` in ~100 ms before Gradle can ever start.

* **Wrapper Executable Resolution**:
  * `AndroidBuildService.build` constructed the executable as:
    ```dart
    final isWindows = Platform.isWindows;
    final executable = isWindows ? 'gradlew.bat' : './gradlew';
    ```
  * On Windows, this must be an absolute path: `p.join(tempDirPath, 'gradlew.bat')`.
  * On POSIX, `p.join(tempDirPath, 'gradlew')` is also standard and unambiguous, with executable permissions verified.

* **Host Android Directory Resolution**:
  * When instantiated in tests or the app, `hostAndroidDir` could be provided as a relative path (`'android'`).
  * Normalizing to an absolute canonical directory ensures wrapper file injection reliably finds `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and `gradle/wrapper/gradle-wrapper.properties`.

## 3. Minimal Justified Fix Plan

1. **In `AndroidBuildService`**:
   * Compute `final executable = p.join(tempDirPath, isWindows ? 'gradlew.bat' : 'gradlew');`.
   * On POSIX, ensure `chmod +x` is set on `gradlew` if required.
   * Use absolute paths for process execution.
2. **In `AndroidBuildService._injectGradleWrapper`**:
   * Ensure all wrapper components (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`, `gradle-wrapper.properties`) are injected if present in `hostAndroidDir`.
3. **In `real_gradle_build_benchmark_test.dart`**:
   * Ensure `hostAndroidDir` resolves to absolute `Directory('android').absolute.path`.
   * Assert `expect(result1.isSuccess, isTrue)` and verify the resulting APK is valid on disk.

## 4. Preservation & Safety Guarantees

* No shell injection vulnerability introduced.
* Strict bounded log capture preserved.
* No arbitrary user command arguments permitted.