# Active Decisions

## Language: Mojo

**Rationale:**
- First-class SIMD (2-4x for key comparison, checksums, delta merge)
- Built-in atomic primitives (CAS, memory ordering)
- Easier parallelism syntax for background workers
- MLIR auto-vectorization
- Learning value for experimental project

**Trade-offs:**
- Language still unstable (v0.25.x, breaking changes)
- Smaller ecosystem vs Rust
- Production-readiness: 6-12 months out

**Alternatives considered:** Rust (more stable, but harder SIMD/atomic syntax)

## Mojo Version: Nightly 0.25.7

**Decision:** Use nightly builds, stay current with latest features

**Rationale:**
- Research/experimental project benefits from cutting edge
- Modular's own examples use nightly
- Language evolving rapidly, tracking latest reduces future migration
- API changes needed regardless (0.25.6 also incompatible with current code)
- Better to iterate with Mojo as it stabilizes

**Trade-offs:**
- Occasional instability from nightly builds
- More frequent API changes to track
- Must maintain ai/MOJO_REFERENCE.md with common mistakes

**Date:** 2025-11-14
**Status:** Active - currently on 0.25.7.0.dev2025111305

## License: Elastic 2.0

**Rationale:**
- Matches seerdb/omendb stack
- Prevents cloud provider exploitation
- Source-available, free to use/modify
- Cannot resell as managed service

## Memory Reclamation: Epoch-Based (TBD)

**Status:** To be implemented

**Plan:**
- Use Mojo atomics to build epoch-based reclamation
- Similar to crossbeam-epoch in Rust
- Needed for safe delta chain traversal

**Alternatives:**
- Hazard pointers (more overhead)
- Reference counting (not suitable for lock-free)

## SIMD Strategy: Explicit Vectorization

**Plan:**
- Use SIMD for key comparison in nodes (binary search)
- Vectorize checksum validation
- Parallelize delta consolidation memcpy

**Target:** 2-4x speedup vs scalar code

## Value Separation Threshold

**TBD:** Benchmark to determine optimal inline threshold

**Initial target:** 128 bytes (similar to WiscKey)
