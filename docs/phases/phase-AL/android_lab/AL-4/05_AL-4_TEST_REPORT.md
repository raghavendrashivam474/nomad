# Nomad Android Lab — Sprint AL-4 Test & Verification Report
**Document ID:** AL-4-TEST-01  
**Sprint Classification:** Reliability Engineering, Root Cause Analysis, Lifecycle Hardening  
**Target Baseline:** AL-3 (commit `1872ae3`)  
**Status:** All Tests Passing  

---

## 1. Test Suite Summary
- **Total Android Build Tests:** 28 passing / 0 failing
- **Total Mobile App Tests:** 282 passing / 0 failing
- **Companion Integration Tests:** 6 comprehensive protocol and lifecycle scenarios passing

---

## 2. Detailed Verification Matrix

| ID | Test Scenario | Target Component | Expected Outcome | Result |
|---|---|---|---|---|
| **T-01** | Capabilities probe (online) | `CompanionBuildProvider` | Returns `isAvailable = true`, provider type `onDeviceCompanion` | **PASSED** |
| **T-02** | Capabilities probe (offline / disconnected) | `CompanionBuildProvider` / `BuildOrchestrator` | Returns `isAvailable = false`, fallback message instructing Termux daemon startup | **PASSED** |
| **T-03** | Snapshot transfer & Job Submission | `CompanionBuildProvider` & `agent.dart` | Materializes Kotlin files, generates unique `jobId` & `buildId` | **PASSED** |
| **T-04** | Status polling & progress streaming | `CompanionBuildProvider` -> `AndroidBuildController` | Emits live progress messages (`Compiling APK (X.Xs)...`) | **PASSED** |
| **T-05** | SHA-256 Checksum verification (valid) | `CompanionBuildProvider` & `ArtifactManager` | Calculates SHA-256 matching agent header, writes APK to `ArtifactManager` | **PASSED** |
| **T-06** | SHA-256 Checksum mismatch (corrupt) | `CompanionBuildProvider` | Detects mismatch, deletes temporary corrupted file, returns null APK path safely | **PASSED** |
| **T-07** | Mid-flight build cancellation | `AndroidBuildController` & `CompanionBuildProvider` | Transitions controller to `cancelled`, hits agent `/cancel` endpoint, clears `isBusy` | **PASSED** |
| **T-08** | Build deadline / timeout | `CompanionBuildProvider` | Exceeds timeout budget, transitions to `timeout`, sets actionable error message | **PASSED** |
| **T-09** | Independent retry after failure | `AndroidBuildController` | First build fails, subsequent build runs in fresh session and succeeds | **PASSED** |
| **T-10** | Concurrent build prevention | `AndroidBuildController` | Throws `StateError` if another build is active | **PASSED** |

---

## 3. Regression Safety

```text
Full test suite executed across `nomad_mobile`: 282 / 282 tests passed.
```