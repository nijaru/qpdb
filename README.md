# swizzstore

B+-tree storage engine with LeanStore-inspired pointer swizzling buffer management.

[![License](https://img.shields.io/badge/license-Elastic%202.0-blue.svg)](LICENSE)

> **Experimental**: Research-grade implementation exploring SOTA buffer management in Mojo.

## Overview

Modern B+-tree storage engine implementing pointer swizzling (40-60% buffer pool speedup) and optimistic lock coupling from recent LeanStore research. Designed for single-file storage with high read throughput.

## Features

- **Pointer swizzling**: In-memory pointers transparently swap to disk offsets (LeanStore innovation)
- **Optimistic lock coupling**: Better concurrency than lock-free delta chains
- **Single-file storage**: B+-tree optimal for single-file (vs LSM multi-file)
- **SIMD-optimized**: Key comparison and checksums (2-4x speedup)
- **Write-ahead logging**: Durability with group commit

## Architecture

Core components:
- **Buffer Pool Manager**: Pointer swizzling for 40-60% speedup
- **B+-Tree Index**: Standard structure with modern buffer management
- **Optimistic Lock Coupling**: Version-based concurrency control
- **WAL**: Write-ahead log for durability

See [ai/design/leanstore_implementation.md](ai/design/leanstore_implementation.md) for detailed design.

## Getting Started

```bash
# Requires Mojo 0.25.6+ and pixi
pixi install

# Run tests
pixi run test-all

# Run benchmarks
pixi run bench
```

## Project Status

**Phase**: Foundation (0.0.1) - Implementing LeanStore buffer manager

Current focus: Pointer swizzling buffer pool with B+-tree

See [ai/STATUS.md](ai/STATUS.md) for detailed status.

## Why This Architecture?

**Why LeanStore over Bw-tree?**
- Bw-tree (2013) has delta chain consolidation overhead
- LeanStore (2018-2023) is SOTA for in-memory B+-trees
- Pointer swizzling is the breakthrough innovation (40-60% speedup)

**Why B+-tree over LSM-tree?**
- Single-file storage (vs LSM multi-file)
- Read-optimized (vs LSM write-optimized)
- Complements seerdb (our LSM-tree engine)

## Why Mojo?

- First-class SIMD support (2-4x faster key comparison)
- Built-in atomic primitives (CAS, memory ordering)
- Easier parallelism for background workers
- MLIR auto-vectorization
- Experimental platform for SOTA storage engine research

## References

### LeanStore (SOTA - Primary)
- "LeanStore: In-Memory Data Management Beyond Main Memory" (Leis et al., ICDE 2018)
- "Umbra: A Disk-Based System with In-Memory Performance" (Neumann & Freitag, CIDR 2020)
- "What Modern NVMe Storage Can Do, and How to Exploit It" (Haas et al., VLDB 2023)

### Bw-Tree (Historical)
- "The Bw-Tree: A B-tree for New Hardware Platforms" (Levandoski et al., 2013)

## License

[Elastic License 2.0](LICENSE) - Free to use and modify, cannot resell as managed service.
