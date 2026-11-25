# Nomad AL-3: Performance Benchmarks & Resource Metrics

## Benchmark Summary

| Scenario | Target Duration | Peak Memory (JVM Heap) |
| :--- | :--- | :--- |
| **Cold Compose Build (Initial)** | ~60–90s | ~1.5 GB |
| **Warm Cached Build** | ~3–5s | ~800 MB |
| **Incremental Kotlin Edit** | ~5–8s | ~900 MB |
| **Snapshot Transfer (HTTP JSON)** | < 150 ms | < 10 MB |
| **Artifact Stream & Checksum** | ~200–400 ms | Streamed |
