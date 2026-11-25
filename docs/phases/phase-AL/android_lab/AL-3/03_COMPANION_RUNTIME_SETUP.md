# Nomad AL-3: On-Device Companion Runtime Setup Guide

**Target Environment:** Android ARM64  
**Primary Runtime:** Termux (Bionic libc environment) + OpenJDK 17 + Gradle + Android SDK  
**Port:** 127.0.0.1:8089  

---

## 1. Prerequisites on Physical Android Device

1. Install **Termux** (v0.118.1+ from F-Droid or GitHub Releases - avoid Google Play version due to deprecation).
2. Install **Termux:API** (optional, recommended for battery/thermal status).
3. Ensure at least **4 GB free storage** on internal memory for toolchains and Gradle caches.

---

## 2. One-Line Toolchain Installation in Termux

Inside the Termux terminal app on your phone, run:

\\\ash
pkg update -y
pkg install -y openjdk-17 gradle dart git wget curl tar
\\\

### Environment Verification Commands
\\\ash
java -version
# Expected: openjdk version "17.0.x"

gradle --version
# Expected: Gradle 8.x

dart --version
# Expected: Dart SDK version 3.x
\\\

---

## 3. Starting the Nomad Companion Daemon

In Termux:
\\\ash
dart run experiments/android_lab_on_device/companion_agent/agent.dart
\\\

Output:
\\\
[CompanionAgent] Listening on http://127.0.0.1:8089
Nomad Companion Build Daemon is running on port 8089.
Keep this Termux session active while building projects in Nomad.
\\\

---

## 4. Lifecycle Management
- When Nomad Mobile runs in the foreground and the user presses **Build**, Nomad discovers \http://127.0.0.1:8089/api/v1/capabilities\.
- The Termux session should be acquired with \	ermux-wake-lock\ if long builds run in the background.
