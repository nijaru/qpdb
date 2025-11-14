# Active Tasks

**Last updated:** 2025-11-14

## Immediate Next Steps

### 1. Decide on Mojo Version ✅
**Status:** Environment ready, decision needed

**Options:**
- **A) Stable 0.25.6** - Currently configured
  - Pros: Released version, more stable
  - Cons: Still has API differences, older
- **B) Nightly 0.25.7** - Recommended ⭐
  - Pros: Latest features, matches Modular examples, future-proof
  - Cons: May have occasional instability
  - Used by Modular's own examples

**Recommendation:** Switch to nightly 0.25.7 for research/experimental project

### 2. Update pixi.toml for Nightly (if choosing 0.25.7)
```bash
# Edit pixi.toml:
# channels = ["conda-forge", "https://conda.modular.com/max-nightly/"]
# dependencies: mojo = "*"  # Latest nightly

# Reinstall
rm -rf .pixi && pixi install
pixi run mojo --version  # Should show 0.25.7.x
```

### 3. Fix Core API Incompatibilities
**Priority order (most critical first):**

1. **Remove borrowed from self parameters** (affects all files)
   - Change `fn foo(borrowed self)` → `fn foo(self)`
   - Files: node.mojo, page_table.mojo, bwtree.mojo, etc.

2. **Fix Atomic.store() API** (if using 0.25.7)
   - Old: `atom.store[ordering=...](value)`
   - New: `Atomic[T].store[ordering=...](ptr, value)`
   - Files: node.mojo, page_table.mojo, epoch.mojo

3. **Fix global epoch variable**
   - Move from global to struct member
   - Files: epoch.mojo

4. **Add Movable trait to structs**
   - Files: node.mojo (NodeHeader), delta.mojo

5. **Fix UnsafePointer constructors**
   - Update Int to pointer conversions
   - Files: Multiple test files

### 4. Run Tests After Each Major Fix
```bash
# Test incrementally as fixes are applied
pixi run test-atomic
pixi run test-bwtree
pixi run test-epoch
pixi run test-backoff
pixi run test-integrated
```

### 5. Full Validation
```bash
# After all fixes complete
pixi run test-all
pixi run bench
```

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
