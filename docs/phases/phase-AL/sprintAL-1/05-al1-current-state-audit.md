# AL-1 Current State Audit (Micro-Sprint A)

**Date**: 2026-10-25
**Auditor**: Implementation Engineer
**Milestone**: AL-1 — Android Lab Usability & Build Reliability
**Baseline Commit**: 9eec462 (tag: v-AL-0, branch: main, clean working tree)

## 1. Executive Summary & Git Baseline
A thorough, read-only inspection was executed across pps/nomad_mobile, packages/nomad_core, and the local toolchain.
Contrary to the initial AL-0 report note suggesting uncommitted changes, Git inspection confirms that all AL-0 deliverables are committed, tagged as \-AL-0\, and merged cleanly into \main\ at commit \9eec462\. The working tree is clean.

## 2. Host Toolchain & Environment
- **Operating System**: Windows 11 (AMD64)
- **Free Disk Space**: 195.9 GB on C:
- **Java**: JDK 25 runtime active; JDK 21 at \C:\Users\ragha\.tools\jdk-21\
- **Android SDK**: Present at \C:\Users\ragha\AppData\Local\Android\Sdk\
- **SDK Platforms**: \ndroid-34\, \ndroid-35\, \ndroid-36\, \ndroid-36.1\
- **Build Tools**: \34.0.0\, \36.0.0\, \36.1.0\, \37.0.0\
- **Host Gradle Wrapper**: \pps/nomad_mobile/android\ contains \gradlew\, \gradlew.bat\, and \gradle/wrapper/gradle-wrapper.jar\ with Gradle 9.1.0 configured.
- **ADB**: \1.0.41\ present and responsive. No physical device or running emulator currently connected.

## 3. Existing Code & Component Responsibilities
- **\AndroidTemplate\** (\pps/nomad_mobile/lib/data/templates/android_template.dart\):
  Generates 7 project files for Kotlin 2.0.21, AGP 8.7.3, Compose BOM 2024.12.01, Compile SDK 35, Min SDK 24.
- **\BuildResult\** (\pps/nomad_mobile/lib/android_build/build_result.dart\):
  Immutable model holding \status\ (\success\, \ailure\, \	imeout\, \cancelled\), \pkPath\, \log\, \duration\, and \errorMessage\.
- **\ProjectMaterializer\** (\pps/nomad_mobile/lib/android_build/project_materializer.dart\):
  Projects SQLite nodes onto the filesystem into a temporary directory (\
omad_android_*\). Resolves hierarchical folder paths cleanly. One-way projection from SQLite to filesystem; does not write back.
- **\AndroidBuildService\** (\pps/nomad_mobile/lib/android_build/android_build_service.dart\):
  Executes \gradlew.bat assembleDebug --no-daemon --console=plain\ within the materialized temp directory. Copies produced APK to \
omad_builds/<projectId>-<timestamp>.apk\. Enforces 5-minute timeout and 100 KB log truncation.

## 4. Current Test Baseline
- **Execution**: \lutter test\ in \pps/nomad_mobile\
- **Result**: **257 / 257 tests passed** (0 failures).
- **Analyzer**: Single pre-existing warning: \The declaration '_PhoneHomeLayout' isn't referenced\ in \lib/app/app_shell.dart:641:7\.

## 5. Verified Gaps Identified for AL-1
1. **No UI Build Trigger**: \WorkspaceView\ has actions for New Folder and New File, but no "Build APK" button for Android projects.
2. **Build State & Concurrency**: \AndroidBuildService\ lacks concurrency guards (overlapping builds could clash or exhaust memory) and does not notify UI of intermediate states (idle, preparing, compiling, cancelling).
3. **Diagnostics Presentation**: No dedicated dialog or bottom sheet to view categorized error explanations or Gradle console output.
4. **Artifact Management**: Generated APKs are saved to temp directory but cannot be viewed, shared, or installed from Nomad UI.
5. **Adb Device Management**: No service to detect connected devices or trigger \db install\ safely.
6. **Repeated Build Reliability**: Only 1 cold build was ever recorded in AL-0; warm and repeated builds have not been measured.
