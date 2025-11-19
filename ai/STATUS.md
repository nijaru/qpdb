# Project Status

**Last Updated**: 2025-11-19
**Version**: 0.0.0
**Phase**: Foundation

## Current State

**Just initialized**: Fresh Rust project with minimal structure
- ✅ Rust project initialized (qpdb)
- ✅ Dependencies added via `cargo add`
- ✅ Basic buffer module structure (Page, Swip placeholders)
- ✅ Error handling skeleton
- ✅ Project builds successfully

**Next**: Begin Phase 1 implementation (Copy-on-write B-tree)

## Recent Activity

### Session 1: Project Conversion (Nov 19, 2025)
- **Decided**: Rust over Mojo for production readiness
- **Research**: SOTA survey (LeanStore VLDB 2024, ScaleCache VLDB 2025, redb)
- **Naming**: Changed from swizzstore → qpdb
- **Cleanup**: Removed all Mojo code, initialized Rust project
- **Architecture**: Incremental approach (CoW B-tree → pointer swizzling → OLC)

## Blockers

None - ready to begin implementation

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Rust over Mojo | Stability, ecosystem, production readiness |
| Start with CoW B-tree | Simpler than pointer swizzling, proven in redb |
| Tokio over io_uring | Cross-platform (macOS + Linux) |
| Incremental complexity | Ship working system, optimize later |
| Study redb closely | Best Rust B-tree reference (~18K SLOC) |

## Performance Targets

**Phase 1 (CoW B-tree)**:
- Baseline: Working insert/get/delete
- Correctness: Property-based testing
- Crash safety: WAL-based recovery

**Phase 2+ (Pointer swizzling)**:
- Target: 40-60% speedup over Phase 1 baseline
- Validate: LeanStore claims from VLDB 2024 paper

## Next Immediate Steps

1. Study redb B-tree implementation (`src/tree/btree.rs`)
2. Implement basic Page structure with slots
3. Implement B-tree node split/merge logic
4. Add simple in-memory buffer pool
5. Property-based testing for correctness

See [TODO.md](TODO.md) for detailed task breakdown.
