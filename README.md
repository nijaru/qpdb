# BW-Tree Storage Engine

SOTA latch-free BW-Tree storage engine with MVCC, delta chains, and value separation.

[![License](https://img.shields.io/badge/license-Elastic%202.0-blue.svg)](LICENSE)

> **Experimental**: Research-grade implementation exploring modern storage engine design.

## Overview

Modern storage engine based on BW-Tree principles with latch-free concurrency, MVCC semantics, and value separation. Designed for high-throughput, multi-core systems.

## Features

- Latch-free delta chains using atomic CAS operations
- MVCC (Multi-Version Concurrency Control) for snapshot isolation
- Value separation for large values (WiscKey-style vLog)
- Write-ahead logging with group commit
- Background consolidation and garbage collection
- SIMD-optimized key comparison and checksums

## Architecture

Core components:
- **Logical Index Layer**: BW-Tree with delta chains (latch-free)
- **Page Table**: Maps logical page IDs to physical locations
- **Value Storage**: Inline small values, external vLog for large values
- **Transaction Layer**: MVCC with snapshot isolation
- **WAL**: Write-ahead log for durability
- **Background Services**: Delta consolidation, vLog GC, checkpointing

See [ai/design/architecture.md](ai/design/architecture.md) for detailed design.

## Getting Started

```bash
# Requires Mojo 0.25.6+
mise install mojo

# Run tests
mojo test tests/

# Run benchmarks
mojo run benchmarks/basic_ops.mojo
```

## Project Status

**Phase**: Initial implementation

Current focus: Core data structures and atomic primitives

See [ai/STATUS.md](ai/STATUS.md) for detailed status.

## Why Mojo?

- First-class SIMD support (2-4x faster key comparison, checksums)
- Built-in atomic primitives (CAS, memory ordering)
- Easier parallelism for background workers
- MLIR auto-vectorization
- Experimental platform for modern storage engine research

## References

- "The Bw-Tree: A B-tree for New Hardware Platforms" (Levandoski et al., 2013)
- "Building a Bw-Tree Takes More Than Just Buzz Words" (Wang et al., 2018)
- "WiscKey: Separating Keys from Values in SSD-conscious Storage" (Lu et al., 2016)

## License

[Elastic License 2.0](LICENSE) - Free to use and modify, cannot resell as managed service.
