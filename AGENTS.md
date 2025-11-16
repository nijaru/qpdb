# swizzstore - Pointer Swizzling Storage Engine

## Vision

Research-grade B+-tree storage engine with LeanStore-inspired pointer swizzling, implementing SOTA buffer management in Mojo.

## Objectives

| Goal | Approach |
|------|----------|
| **Pointer swizzling** | 40-60% buffer pool speedup (LeanStore innovation) |
| **Optimistic lock coupling** | Better than Bw-tree's lock-free delta chains |
| **High performance** | SIMD optimization (2-4x gains for key ops) |
| **Single-file storage** | B+-tree optimal for single-file (vs LSM multi-file) |
| **Durability** | WAL with group commit |

## Non-Goals

| What | Why |
|------|-----|
| Production use (immediate) | Experimental/research focus |
| SQL layer | Key-value interface only |
| LSM-tree workloads | seerdb optimized for that |

## Architecture

**Core:** B+-tree with LeanStore pointer swizzling buffer manager
**Innovation:** In-memory pointers swapped to disk offsets transparently (40-60% speedup)
**Concurrency:** Optimistic lock coupling (not lock-free delta chains)
**Storage:** Single-file B+-tree (unlike LSM multi-level)
**Durability:** WAL with group commit

See [ai/design/leanstore_implementation.md](ai/design/leanstore_implementation.md) for complete architecture spec.

---

## Research Foundation (November 14, 2025)

**SOTA Research Complete** (from omendb parent project):

**Phase 4: General Storage Engines** (`ai/research/general_storage_engine_sota.md`)
- LeanStore pointer swizzling (40-60% buffer pool speedup)
- Bw-tree lock-free design (100% improvement over baseline)
- Mini-page optimization for in-memory workloads
- Why LeanStore > Bw-tree for modern workloads

**Architecture Spec** (`ai/design/leanstore_implementation.md`)
- Complete 6-phase implementation guide
- Pointer swizzling mechanics with code examples
- Buffer frame lifecycle (unswizzle → pin → access → unpin → swizzle)
- Optimistic lock coupling for concurrency
- Performance targets and optimization strategies

**Key Insight from Research**:
- Bw-tree (2013) is outdated - delta chain overhead
- LeanStore (2018-2023) is SOTA for in-memory B+-trees
- Pointer swizzling is the breakthrough innovation
- Single-file B+-tree complements seerdb's multi-file LSM-tree

---

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Language | Mojo 0.25.6+ | First-class SIMD, atomic primitives |
| Package Manager | pixi | Mojo version management, dependencies |
| Atomics | `stdlib/os/atomic.mojo` | CAS, memory ordering (acquire/release) |
| SIMD | `SIMD[DType, width]` | Vectorized key comparison, checksums |
| Testing | `mojo run tests/` | Unit and concurrency tests |
| Benchmarking | Custom harness | Performance validation |

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `src/` | Core BW-Tree implementation |
| `tests/` | Unit and integration tests |
| `benchmarks/` | Performance benchmarks |
| `ai/` | **AI session context** - Agent workspace for state across sessions |
| `docs/` | User documentation (future) |

### AI Context Organization

**Purpose:** AI agents use `ai/` to maintain continuity between sessions.

**Session files** (ai/ root - read every session):

| File | Purpose | Guidelines |
|------|---------|------------|
| `STATUS.md` | Current state, blockers | Read FIRST. Current/active only, no history |
| `TODO.md` | Active tasks | No "Done" sections, current work only |
| `DECISIONS.md` | Active architectural decisions | Superseded → ai/decisions/ |
| `RESEARCH.md` | Research findings index | Details → ai/research/ |
| `MOJO_REFERENCE.md` | Mojo patterns & v0.25.6+ gotchas | Always reference when coding |

**Reference files** (subdirectories - loaded only when needed):

| Directory | Purpose |
|-----------|---------|
| `ai/research/` | Detailed research findings |
| `ai/design/` | Design specifications |
| `ai/decisions/` | Superseded/split decisions |

**Principle:** Session files kept current/active only for token efficiency. Detailed content in subdirectories loaded on demand. Historical content pruned (git preserves all history).

## Development Workflow

| Activity | Practice |
|----------|----------|
| Testing | TDD for complex concurrency logic |
| Commits | Frequent commits, regular pushes |
| State tracking | ai/ files (STATUS, TODO, DECISIONS) |
| Documentation | Update ai/STATUS.md every session with learnings |

## Performance Targets

**Initial (Phase 0-1):**
- Establish baseline concurrent insert/lookup throughput
- Validate SIMD gains (2-4x for key comparison)

**Later phases:**
- Compare vs RocksDB, seerdb on point operations
- Measure write amplification vs traditional B-tree

## Commands

### Build and Test

```bash
# Using pixi tasks (recommended)
pixi run test-all       # Run all tests
pixi run test-atomic    # Run specific test
pixi run bench          # Run benchmarks

# Or run directly
pixi run mojo run tests/test_atomic.mojo
pixi run mojo run tests/test_bwtree.mojo
pixi run mojo run benchmarks/bench_basic_ops.mojo
```

### Development

```bash
# Install pixi (first time only)
curl -fsSL https://pixi.sh/install.sh | bash

# Configure Modular channels
echo 'default-channels = ["https://conda.modular.com/max-nightly", "conda-forge"]' \
  >> $HOME/.pixi/config.toml

# Install project dependencies
pixi install

# Check Mojo version
pixi run mojo --version  # Requires 0.25.6+

# Run in pixi environment
pixi shell  # Activate shell
mojo --version
exit

# Or use pixi run directly
pixi run mojo run tests/test_atomic.mojo
```

## Code Standards

**For detailed Mojo patterns, memory ordering, and v0.25.6+ semantics, see [ai/MOJO_REFERENCE.md](ai/MOJO_REFERENCE.md)**

### Mojo-Specific

| Standard | Rule | Example |
|----------|------|---------|
| **Atomics** | Use explicit memory ordering | `atom.load[ordering=Consistency.ACQUIRE]()` |
| **SIMD** | Explicit width for clarity | `SIMD[DType.int64, 4]` not magic numbers |
| **Pointers** | Prefer `UnsafePointer[T]` | Type-safe over raw addresses |
| **Ownership** | Use `mut`, `borrowed`, `owned` | Explicit lifetime semantics (prefer `mut` over `inout`) |
| **Inlining** | `@always_inline` for hot paths | Key comparison, CAS loops |
| **Copyability** | Do NOT use `ImplicitlyCopyable` | Prevent accidental copies of atomic structs |

### Naming

| Type | Convention | Example |
|------|------------|---------|
| Structs | PascalCase | `PageTable`, `NodeHeader` |
| Functions | snake_case | `compare_and_swap()` |
| Constants | UPPER_SNAKE | `NODE_BASE`, `MAX_CHAIN_LENGTH` |
| Type aliases | PascalCase | `alias NodeType = Int8` |

### Comments

- Only WHY, never WHAT
- No change tracking, no TODOs
- Document non-obvious concurrency decisions

```mojo
# Good: Explains rationale
# Use RELEASE ordering to ensure delta chain visible before CAS
atom.store[ordering=Consistency.RELEASE](new_ptr)

# Bad: Narrates code
# Store new pointer to atom
atom.store(new_ptr)
```

## Current Status

**Phase:** Foundation (0.0.1)

See [ai/STATUS.md](ai/STATUS.md) for current state, blockers, and recent learnings.

## References

### Papers
- "The Bw-Tree: A B-tree for New Hardware Platforms" (Levandoski et al., 2013)
- "Building a Bw-Tree Takes More Than Just Buzz Words" (Wang et al., 2018)

### Mojo Documentation
- **[ai/MOJO_REFERENCE.md](ai/MOJO_REFERENCE.md)** - Project-specific patterns and v0.25.6+ gotchas
- Mojo atomic stdlib: `modular/mojo/stdlib/stdlib/os/atomic.mojo`
- Mojo Manual: https://docs.modular.com/mojo/manual/
- Changelog: https://github.com/modular/modular/blob/main/mojo/docs/changelog-released.md

## License

Elastic License 2.0 - Source-available, free to use/modify, cannot resell as managed service.
