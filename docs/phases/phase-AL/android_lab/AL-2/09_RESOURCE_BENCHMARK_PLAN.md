# AL-2: Resource & Performance Benchmark Methodology
**Subsystem:** Android Lab (AL)  
**Sprint:** AL-2 — On-Device Native Development Feasibility & Architecture  
**Status:** COMPLETE — Benchmark Protocol  
**Date:** 2026-10-24  

---

## 1. Benchmark Dimensions & Metrics

To establish real hardware viability, the following parameters must be tracked across build runs:

| Dimension | Primary Metric | Tool / Instrumentation | Target Threshold |
|---|---|---|---|
| **Wall-Clock Duration** | Cold build (fresh cache) | `Stopwatch.elapsedMilliseconds` | < 120s (Mobile) / < 35s (Host) |
| | Warm build (recompilation) | `Stopwatch.elapsedMilliseconds` | < 30s (Mobile) / < 8s (Host) |
| **Peak RAM Footprint** | Peak RSS / Resident Memory | `/proc/meminfo` or `Debug.getPss()` | < 1.5 GB Peak |
| **Storage Usage** | Gradle cache + build outputs | Directory disk walk (`du -sh`) | < 800 MB total |
| **CPU / Thermal Impact** | Core frequencies & throttling | `/sys/devices/virtual/thermal/` | Zero thermal shutdown |
| **Battery Consumption** | Battery drain % per 10 builds | Android BatteryManager API | < 5% per 10 builds |
| **Process Survival** | Phantom killer / OOM terminations | Exit code / Logcat inspection | 100% survival on >= 6GB RAM |

---

## 2. Test Execution Protocol

1. **Test A: Cold Build Baseline:** Clear all Gradle and build caches (`rm -rf ~/.gradle/caches/`, remove materialized temp dir). Run full compilation of Hello Nomad template.
2. **Test B: Warm Build (No Code Changes):** Run immediate rebuild. Gradle configuration cache and task up-to-date checks should return success within seconds.
3. **Test C: Incremental Build (Kotlin Change):** Modify greeting string in `MainActivity.kt`. Verify incremental Kotlin compilation and DEX patching.
4. **Test D: Cancellation & Interruption:** Trigger build, wait 5 seconds, issue cancellation request. Verify process kill within 500ms and zero file corruption.
5. **Test E: Repetitive Stress (5 Consecutive Builds):** Run 5 successive builds to detect memory leaks, orphaned JVM processes, or file handle exhaustion.
