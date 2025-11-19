# Active Tasks

## Immediate (This Session)
- [x] Convert from Mojo to Rust
- [x] Research SOTA (2024-2025)
- [x] Initialize project structure
- [x] Create ai/ documentation
- [x] Update AGENTS.md/CLAUDE.md

## Next Session
- [ ] Study redb B-tree implementation [github.com/cberner/redb]
- [ ] Design Page structure (slots, keys, values) [src/buffer/page.rs]
- [ ] Implement basic B-tree node [src/btree/]
- [ ] Write property-based tests [tests/]

## Phase 1 (CoW B-tree)
- [ ] Page allocation/deallocation [src/buffer/]
- [ ] B-tree insert (with splits) [src/btree/]
- [ ] B-tree search [src/btree/]
- [ ] B-tree delete (with merges) [src/btree/]
- [ ] In-memory buffer pool (HashMap) [src/buffer/]
- [ ] Property tests (insert/delete sequences) [tests/]
- [ ] Unit tests for split/merge logic [tests/]

## Phase 2 (Durability)
- [ ] WAL record format [src/wal/]
- [ ] WAL append (tokio::fs) [src/wal/]
- [ ] Recovery on open [src/wal/]
- [ ] Crash tests (proptest with failures) [tests/]

## Phase 3 (MVCC)
- [ ] Version tracking [src/buffer/]
- [ ] Snapshot isolation [src/]
- [ ] Multi-reader transactions [src/]
- [ ] Version GC [src/buffer/]

## Backlog
- [ ] Benchmarking harness [benches/]
- [ ] Comparison vs SQLite/redb [benches/]
- [ ] Variable-size pages [src/buffer/]
- [ ] Compression [src/buffer/]
- [ ] SIMD optimizations [src/btree/]

## Research/Investigation
- [x] LeanStore VLDB 2024 paper
- [x] ScaleCache VLDB 2025 paper
- [x] redb architecture
- [ ] Study redb src/tree/btree.rs in detail [github.com/cberner/redb/blob/master/src/tree/btree.rs]
- [ ] Study LeanStore pointer swizzling code [github.com/leanstore/leanstore]
