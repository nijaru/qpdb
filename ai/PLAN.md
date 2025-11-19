# Implementation Plan

**Objective**: Build SOTA single-file storage engine incrementally

## Strategy

Start simple (CoW B-tree), add complexity incrementally (pointer swizzling, OLC)

## Phases

### Phase 1: Copy-on-Write B-tree (Weeks 1-2)
**Goal**: Working B-tree with MVCC

**Reference**: redb (`github.com/cberner/redb`)

**Tasks**:
- [ ] Page structure with slots (4KB aligned)
- [ ] B-tree node split/merge
- [ ] In-memory buffer pool (simple HashMap)
- [ ] Basic insert/get/delete
- [ ] Property-based testing

**Deliverable**: Functional B-tree, no persistence yet

### Phase 2: Durability (Week 3)
**Goal**: Crash recovery

**Tasks**:
- [ ] WAL (write-ahead log)
- [ ] Tokio file I/O
- [ ] Recovery on startup
- [ ] Crash recovery tests (inject failures)

**Deliverable**: Durable storage with crash safety

### Phase 3: MVCC (Week 4)
**Goal**: Concurrent reads

**Tasks**:
- [ ] Multi-version pages
- [ ] Read transactions (snapshot isolation)
- [ ] Copy-on-write for writes
- [ ] GC for old versions

**Deliverable**: Multiple concurrent readers + single writer

### Phase 4: Buffer Pool + Pointer Swizzling (Weeks 5-6)
**Goal**: 40-60% speedup (LeanStore innovation)

**Reference**: LeanStore papers

**Tasks**:
- [ ] `Swip` enum (Hot/Cold pointers)
- [ ] Page table (PageID → Swip mapping)
- [ ] CLOCK eviction
- [ ] Swizzle/unswizzle on page access

**Deliverable**: Fast in-memory access, graceful out-of-memory

### Phase 5: Optimistic Lock Coupling (Week 7)
**Goal**: Better concurrency

**Tasks**:
- [ ] `OptimisticLatch` (version + lock bit)
- [ ] Lock-free reads
- [ ] Minimal write locking

**Deliverable**: High concurrent read throughput

### Phase 6: Optimizations (Week 8+)
**Goal**: Production-grade performance

**Tasks**:
- [ ] SIMD key comparison
- [ ] Variable-size pages
- [ ] Compression
- [ ] Benchmarks vs SQLite/redb/RocksDB

**Deliverable**: Validated performance claims

## Success Criteria

**Phase 1-3**: Correctness (property tests, crash recovery)

**Phase 4-6**: Performance
- In-memory workload: Near in-memory B-tree speed
- Out-of-memory: Graceful degradation
- Pointer swizzling: 40-60% speedup vs Phase 1-3 baseline

## Reference Implementations

**Study**:
- **redb** - Clean Rust B-tree (focus on Phase 1-3)
- **LeanStore** - Pointer swizzling mechanics (Phase 4-5)

**Compare**:
- **SQLite** - Baseline embedded DB
- **RocksDB** - LSM comparison
- **LMDB** - Memory-mapped B-tree
