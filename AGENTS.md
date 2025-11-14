# BW-Tree Storage Engine - Project Overview

## Vision

Research-grade latch-free BW-Tree storage engine exploring modern concurrency primitives and SIMD optimization in Mojo.

## Objectives

1. Implement production-quality BW-Tree with delta chains
2. Achieve latch-free concurrency using atomic CAS operations
3. Leverage Mojo's SIMD for 2-4x performance gains
4. Support MVCC with snapshot isolation
5. Value separation for write amplification reduction

## Non-Goals

- Not targeting immediate production use (experimental)
- Not building SQL layer (key-value focus)
- Not competing with seerdb for vector database workloads

## Architecture

**Core:** BW-Tree with delta chains, page table, MVCC
**Storage:** Value log (vLog) for large values, inline for small
**Durability:** WAL with group commit
**Background:** Consolidation, GC, checkpointing

See [ai/design/architecture.md](ai/design/architecture.md) for details.

## Technology Stack

- **Language:** Mojo 0.25.6+
- **Atomics:** `stdlib/os/atomic.mojo` (CAS, memory ordering)
- **SIMD:** First-class SIMD types
- **Testing:** Mojo test framework
- **Benchmarking:** Custom harness

## Development Workflow

- TDD where applicable (complex concurrency logic)
- Frequent commits, regular pushes
- State tracked in ai/ files (STATUS, TODO, DECISIONS)
- Benchmarks in benchmarks/, tests in tests/

## Performance Targets

**Initial (Phase 0-1):**
- Establish baseline concurrent insert/lookup throughput
- Validate SIMD gains (2-4x for key comparison)

**Later phases:**
- Compare vs RocksDB, seerdb on point operations
- Measure write amplification vs traditional B-tree

## Current Status

**Phase:** Foundation (0.0.1)
**Focus:** Core data structures, atomic primitives
**Next:** Implement node structure with delta chains

See [ai/STATUS.md](ai/STATUS.md) for detailed status.

## References

- "The Bw-Tree: A B-tree for New Hardware Platforms" (Levandoski et al., 2013)
- "Building a Bw-Tree Takes More Than Just Buzz Words" (Wang et al., 2018)
- Mojo atomic stdlib: `modular/mojo/stdlib/stdlib/os/atomic.mojo`

## License

Elastic License 2.0 - Source-available, free to use/modify, cannot resell as managed service.
