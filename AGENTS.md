# qpdb - High-Performance Embedded Storage Engine

## Vision

SOTA single-file storage engine implementing LeanStore's pointer swizzling and modern B+-tree techniques in Rust.

## Objectives

| Goal | Approach |
|------|----------|
| **Correctness first** | CoW B-tree foundation, property-based testing |
| **Pointer swizzling** | 40-60% buffer pool speedup (LeanStore innovation) |
| **Incremental complexity** | Start simple (redb-style), add optimizations later |
| **Single-file storage** | B+-tree for read-optimized workloads |
| **Production-ready** | Rust safety, mature ecosystem |

## Non-Goals

| What | Why |
|------|-----|
| SQL layer (now) | Key-value interface first |
| Distributed features | Single-node embedded DB |
| LSM-tree workloads | Optimized for single-file B+-tree |

## Technology Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Rust (edition 2024) | Memory safety, mature ecosystem |
| Async I/O | Tokio | Cross-platform (macOS + Linux) |
| Concurrency | parking_lot, crossbeam-epoch | Proven Rust primitives |
| Testing | proptest, criterion | Property tests + benchmarks |

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `src/` | Core implementation |
| `src/buffer/` | Buffer pool, pointer swizzling |
| `src/btree/` | B+-tree (future) |
| `tests/` | Unit tests |
| `benches/` | Benchmarks |
| `ai/` | AI session context |

### AI Context Organization

**Purpose**: Maintain continuity between AI sessions

**Session files** (ai/ root - read every session):

| File | Purpose | Guidelines |
|------|---------|------------|
| `STATUS.md` | Current state, blockers | Read FIRST |
| `TODO.md` | Active tasks | Current work only |
| `PLAN.md` | Implementation phases | High-level roadmap |
| `RESEARCH.md` | Research index | Points to ai/research/ |

**Reference files** (subdirectories - loaded on demand):

| Directory | Purpose |
|-----------|---------|
| `ai/research/` | Detailed SOTA findings |
| `ai/design/` | Design specifications |
| `ai/tmp/` | Temporary artifacts (gitignored) |

**Principle**: Session files stay current/active. Detailed content in subdirectories. Git preserves history.

## Development Workflow

| Activity | Practice |
|----------|----------|
| Testing | TDD for complex logic, property tests for correctness |
| Commits | Frequent commits, no AI attribution |
| State tracking | Update ai/STATUS.md each session |
| Code quality | Fix root cause, no workarounds |

## Implementation Strategy

### Phase 1: CoW B-tree (Weeks 1-2)
**Reference**: redb
- Page structure, node split/merge
- In-memory buffer pool
- Property-based testing

### Phase 2: Durability (Week 3)
- WAL, crash recovery
- Tokio file I/O

### Phase 3: MVCC (Week 4)
- Multi-version pages
- Concurrent readers

### Phase 4+: Optimizations
- Pointer swizzling (40-60% speedup)
- OLC, SIMD, variable pages

See [ai/PLAN.md](ai/PLAN.md) for details.

## Code Standards

### Rust-Specific

| Standard | Rule | Example |
|----------|------|---------|
| **Safety** | Minimize `unsafe`, document when needed | Pointer swizzling only |
| **Errors** | Use `anyhow` (app), `thiserror` (lib) | Defined in `error.rs` |
| **Async** | Tokio for I/O | File operations |
| **Ownership** | Clear lifetimes, no `.clone()` shortcuts | Pass references |
| **Testing** | Property tests for invariants | `proptest` |

### Naming

| Type | Convention | Example |
|------|------------|---------|
| Structs | PascalCase | `PageTable`, `Database` |
| Functions | snake_case | `get_page()` |
| Constants | UPPER_SNAKE | `PAGE_SIZE` |
| Modules | snake_case | `buffer`, `btree` |

### Comments

- Only WHY, never WHAT
- No change tracking, no TODOs
- Document non-obvious design decisions

```rust
// Good: Explains rationale
// Use Hot pointer for in-memory pages (avoids hash lookup)
Swip::Hot(ptr)

// Bad: Narrates code
// Create hot swip
Swip::Hot(ptr)
```

## Current Status

**Phase**: Foundation (0.0.0)

See [ai/STATUS.md](ai/STATUS.md) for current state.

## References

### Primary Research
- LeanStore (VLDB 2024) - Pointer swizzling architecture
- ScaleCache (VLDB 2025) - Production buffer management
- redb - Clean Rust B-tree reference

### Key Papers
See [ai/research/SOTA_2024_2025.md](ai/research/SOTA_2024_2025.md)

## License

Elastic License 2.0 - Source-available, free to use/modify, cannot resell as managed service.
