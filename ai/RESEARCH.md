# Research Findings

Index of research for qpdb implementation. Detailed research in `ai/research/` subdirectory.

## SOTA Storage Engines (2024-2025)

| Technology | Status | Key Finding |
|------------|--------|-------------|
| **LeanStore** (VLDB 2024) | Active | Pointer swizzling = 40-60% buffer pool speedup |
| **ScaleCache** (VLDB 2025) | Production | SIMD-accelerated hash table for page-to-buffer translation |
| **redb** (Rust) | Stable | Clean CoW B-tree reference (~18K SLOC) |
| **Limbo** (Rust) | Announced Dec 2024 | SQLite rewrite (too complex for reference) |

## Key Insights

**Pointer Swizzling** (LeanStore innovation):
- Traditional: Page access → hash table lookup → address
- LeanStore: Hot page? → Direct pointer (one `if`)
- Result: 40-60% speedup for in-memory workloads

**Incremental Approach**:
- Start: CoW B-tree (redb-style) for correctness
- Then: Add pointer swizzling for performance
- Later: OLC, SIMD, variable pages

**Best References**:
- **redb**: Study for clean Rust B-tree implementation
- **LeanStore papers**: Study for pointer swizzling theory
- **VLDB 2024-2025**: Latest buffer management research

## Papers to Read

**Primary**:
- [x] LeanStore VLDB 2024 - Complete architecture overview
- [x] ScaleCache VLDB 2025 - Production buffer management
- [ ] Indirection Skipping VLDB 2025 - Direct access paths

**Secondary**:
- [ ] Autonomous Commits SIGMOD 2025 - Durability without group commit
- [ ] Managing NVMe Arrays 2025 - I/O optimization

## Code to Study

**redb** (`github.com/cberner/redb`):
- `src/tree/btree.rs` - B-tree logic
- `src/transaction.rs` - MVCC patterns
- `docs/design.md` - Architecture decisions
- `tests/` - Correctness tests

**LeanStore** (`github.com/leanstore/leanstore`):
- `buffer-manager/` - Pointer swizzling
- Latest branches: `latency`, `blob`

## Reference Repositories

| Repo | Purpose | SLOC | Status |
|------|---------|------|--------|
| redb | Primary Rust reference | ~18K | Active |
| LeanStore | Pointer swizzling concepts | ~50K C++ | Research |
| sled | Historical Rust B-tree | ~20K | Less active |
| LMDB | Memory-mapped B-tree | ~50K C | Stable |
