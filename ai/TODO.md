# Active Tasks

**Last updated:** 2025-11-14

## Immediate Next Steps

### 1. Fix UnsafePointer Parameter Syntax (BLOCKER)
**Status:** 95% of API migration complete, single blocker remains

**Problem:** UnsafePointer parameter specification causes compilation error
```
error: inferred parameter passed out of order: 'mut'
```

**Affected locations:**
- `src/node.mojo:27` - `var next: UnsafePointer[NodeHeader, mut=True, origin=_default_invariant[True]()]`
- `src/page_table.mojo:18` - `var entries: UnsafePointer[Atomic[DType.uint64], mut=True, origin=_default_invariant[True]()]`

**Attempted fixes:**
- ❌ Not specifying mut - "failed to infer parameter 'mut'"
- ❌ `mut=True` - "inferred parameter passed out of order"
- ❌ Using `origin=_default_invariant()` - "failed to infer mut"
- ❌ Using `origin=_default_invariant[True]()` - "inferred parameter passed out of order"

**Next approaches to try:**
- Check Modular stdlib source for correct parameter order/specification
- Look for examples in Modular codebase where UnsafePointer is used as struct field
- Try positional instead of keyword parameters
- Use type aliases to simplify specification
- Store Int instead and convert when needed

### 2. Run First Test After Pointer Fix
```bash
pixi run test-atomic  # Should compile and run once pointer syntax fixed
```

### 3. Fix Any Additional Issues & Run Full Test Suite
```bash
# Run all tests to validate implementation
pixi run test-all
pixi run bench
```

## Completed in Session 7 (2025-11-14)

✅ **Environment Setup**
- Configured pixi.toml for macOS (osx-arm64 platform)
- Switched to nightly channel (Mojo 0.25.7.0.dev2025111305)
- Added -I . flag to all test tasks for module imports

✅ **API Migration (95% complete)**
- Removed all `borrowed` from self and function parameters
- Updated `Atomic.store()` to new 0.25.7 API (requires pointer arg)
- Changed `UnsafePointer[T].alloc(n)` → `alloc[T](n)`
- Added `Movable` trait to `NodeHeader`
- Replaced `__del__(owned self)` → `fn deinit(self)`
- Fixed type capitalization (int→Int)
- Fixed imports (added `alloc`, `_default_invariant`)

✅ **Documentation**
- Updated ai/MOJO_REFERENCE.md with Pixi setup section
- Added "Common Mistakes & Fixes" with 7 common errors
- Documented all API changes between 0.25.6 and 0.25.7
- Updated ai/STATUS.md with session progress

## Future Work (After Validation)

### Phase 1: Bug Fixes & Refinement
- [ ] Fix any compilation errors found during validation
- [ ] Fix any test failures
- [ ] Add error handling (allocation failures, bounds checking)
- [ ] Improve delta type discrimination (proper tagging vs heuristic casting)
- [ ] Optimize consolidation triggering logic

### Phase 2: Tree Structure
- [ ] Implement node splits (when node exceeds size threshold)
- [ ] Implement node merges (when node falls below threshold)
- [ ] Add SplitDelta and MergeDelta handling
- [ ] Build proper tree structure (not just single root node)
- [ ] Add parent-child page ID tracking

### Phase 3: Multi-Threading
- [ ] Create multi-threaded stress tests
- [ ] Test concurrent inserts from multiple threads
- [ ] Test concurrent reads and writes
- [ ] Validate ACQUIRE/RELEASE memory ordering
- [ ] Measure scalability vs thread count

### Phase 4: Performance Optimization
- [ ] Profile hot paths with Mojo profiler
- [ ] Optimize SIMD binary search (validate 2-4x target)
- [ ] Tune consolidation thresholds
- [ ] Tune epoch collection batch size
- [ ] Add SIMD optimization to consolidation path

### Phase 5: Advanced Features
- [ ] Implement background consolidation worker thread
- [ ] Add MVCC versioning with snapshot isolation
- [ ] Implement value log (vLog) for value separation
- [ ] Add range scan optimizations
- [ ] Implement accurate size() tracking

### Phase 6: Durability
- [ ] Write-ahead log (WAL) implementation
- [ ] Group commit optimization
- [ ] Crash recovery logic
- [ ] Checkpointing

### Phase 7: Benchmarking & Comparison
- [ ] Compare vs RocksDB on point operations
- [ ] Compare vs seerdb on point operations
- [ ] Measure write amplification vs B-tree
- [ ] Measure SIMD speedup on real workloads
- [ ] Test with YCSB benchmarks

## Known Issues (To Address After Validation)

1. **No error handling** - Allocation failures, invalid page IDs not checked
2. **Delta type discrimination** - Uses heuristic casting, needs proper tagging
3. **No tree structure** - Single root node only, no splits/merges
4. **size() is O(n)** - Approximation, not accurate count
5. **No background consolidation** - Runs inline, should be separate thread
6. **No multi-threaded tests** - Need Mojo threading primitives

## Completed (Sessions 1-6)

✅ **Core Implementation**
- node.mojo, page_table.mojo with CAS operations
- delta.mojo with all 4 delta types
- search.mojo with SIMD binary search
- bwtree.mojo with insert/lookup/delete
- epoch.mojo for memory reclamation
- consolidate.mojo for delta chain merging
- backoff.mojo for CAS retry optimization
- lookup.mojo with DeleteDelta handling
- bwtree_integrated.mojo with all features

✅ **Testing**
- 38 test cases across 5 test files
- benchmarks/bench_basic_ops.mojo

✅ **Documentation**
- ai/MOJO_REFERENCE.md - Mojo patterns & gotchas
- ai/RESEARCH.md - Research findings index
- ai/SESSION_5_IMPROVEMENTS.md - Integration details
- SETUP.md - Pixi installation guide
- pixi.toml - Project configuration

✅ **Infrastructure**
- Pixi configuration with convenient tasks
- Git repository with proper branching
- AI context files for continuity
