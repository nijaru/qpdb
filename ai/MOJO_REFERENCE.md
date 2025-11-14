# Mojo Reference for BW-Tree Development

**Last updated:** 2025-11-14 (Mojo v0.25.6+ / nightly 0.25.7)

Quick reference for Mojo-specific patterns, gotchas, and best practices for lock-free concurrent data structures.

## Pixi & Mojo Setup

### Installing Pixi and Mojo

```bash
# Install pixi (first time only)
curl -fsSL https://pixi.sh/install.sh | bash
exec $SHELL  # Reload shell

# Install project dependencies (from project root with pixi.toml)
pixi install

# Verify installation
pixi run mojo --version
```

### Running Mojo Code

```bash
# Run with module imports (required for multi-file projects)
pixi run mojo run -I . tests/test_atomic.mojo

# Run from pixi tasks (defined in pixi.toml)
pixi run test-atomic
pixi run test-all

# Enter pixi shell for interactive work
pixi shell
mojo --version
exit
```

### Pixi Configuration (pixi.toml)

```toml
[workspace]
name = "bw-tree"
channels = ["conda-forge", "https://conda.modular.com/max"]
platforms = ["osx-arm64", "linux-64", "linux-aarch64"]

[dependencies]
mojo = "==0.25.6"  # Stable version
# mojo = "*"       # Nightly version
python = ">=3.11,<3.14"

[tasks]
# Add -I . for module imports from src/ directory
test-atomic = "mojo run -I . tests/test_atomic.mojo"
```

**Key points:**
- Use `-I .` flag to add current directory to module search path
- Stable channel: `https://conda.modular.com/max`
- Nightly channel: `https://conda.modular.com/max-nightly/`
- Platform names: `osx-arm64` (macOS), `linux-64`, `linux-aarch64`

## Common Mistakes & Fixes

### Type Constructor Capitalization

```mojo
# WRONG: lowercase type constructors
var addr = UInt64(int(ptr))

# RIGHT: Capitalized type constructors
var addr = UInt64(Int(ptr))
```

### Atomic Store API (v0.25.7+)

```mojo
# OLD (v0.25.6 and earlier):
atom.store[ordering=Consistency.RELEASE](value)

# NEW (v0.25.7+ nightly):
var ptr = UnsafePointer(to=atom.value)
Atomic[DType.uint64].store[ordering=Consistency.RELEASE](ptr, value)
```

### Borrowed Self Parameter

```mojo
# WRONG: Can cause parse errors in some versions
fn get_header(borrowed self) -> UInt64:
    return self.value

# RIGHT: Use proper spacing and check Mojo version
fn get_header(self) -> UInt64:  # 'borrowed' is default
    return self.value
```

### Module Imports Without Package Path

```mojo
# WRONG: Trying to manipulate sys.path
import sys
sys.path.append("..")  # Not supported in Mojo
from src.node import Node

# RIGHT: Use -I flag and direct imports
# Run with: mojo run -I . tests/test.mojo
from src.node import Node
```

### String Types

```mojo
# Use String (capitalized) not str
var msg: String = "Hello"
# StaticString for compile-time strings
alias CONST_MSG: StaticString = "Error"
```

### Trait Conformance

```mojo
# WRONG: Type doesn't conform to required traits
var ptr = UnsafePointer[T].alloc(1)
ptr.init_pointee_move(value)  # Error if T not Movable

# RIGHT: Add trait conformance
@value
struct MyType(Movable):
    # Implementation
```

### Global Variables in Packages

```mojo
# WRONG: Global mutable state not allowed in packages
var _global_epoch = Atomic[DType.uint64](0)

# RIGHT: Use struct static fields or pass as parameters
struct EpochManager:
    var _epoch: Atomic[DType.uint64]

    fn __init__(out self):
        self._epoch = Atomic[DType.uint64](0)
```

## Critical Breaking Changes (v0.25.6+)

### Copyability Model

**BREAKING:** Types are now "only explicitly copyable" by default.

```mojo
# Old (pre-0.25.6) - implicit copy
var list1 = List[Int](1, 2, 3)
var list2 = list1  # Used to work

# New (v0.25.6+) - explicit copy required
var list1 = List[Int](1, 2, 3)
var list2 = list1  # ERROR: List not implicitly copyable
var list2 = list1.copy()  # Must use explicit copy

# For our types to be implicitly copyable
@value
struct MyNode(ImplicitlyCopyable):
    # Type definition
```

**Impact for BW-Tree:**
- Our `Node`, `PageTable` types should NOT be `ImplicitlyCopyable` (prevent accidental copies)
- Use `borrowed` and `owned` argument conventions explicitly
- Atomic operations work with non-copyable types (pointers stored as uint64)

### SIMD Comparison Semantics

**Changed:** SIMD now has dual comparison behavior:

```mojo
var v1 = SIMD[DType.int64, 4](1, 2, 3, 4)
var v2 = SIMD[DType.int64, 4](1, 2, 5, 4)

# Aggregate comparison (returns Bool)
var all_equal: Bool = v1 == v2  # False (checks all elements equal)
var any_less: Bool = v1 <= v2   # True (aggregate comparison)

# Element-wise comparison (returns boolean mask)
var mask = v1.eq(v2)  # SIMD[DType.bool, 4](True, True, False, True)
var less_mask = v1.le(v2)  # Element-wise less-or-equal
```

**Use for BW-Tree:**
- Binary search in nodes: use element-wise `le()`, `lt()` for masks
- Equality checks for all keys: use aggregate `==`

## Atomic Operations

### Available Operations

```mojo
from os.atomic import Atomic, Consistency

# Create atomic uint64 for pointer storage
var atom = Atomic[DType.uint64](0)

# Load with memory ordering
var val = atom.load[ordering=Consistency.ACQUIRE]()

# Store with memory ordering
atom.store[ordering=Consistency.RELEASE](new_value)

# Compare-and-swap (CAS)
var expected: UInt64 = old_ptr
var success = atom.compare_exchange(expected, new_ptr)
# If fails, 'expected' is overwritten with current value

# Fetch-and-add (returns old value)
var old_val = atom.fetch_add(increment)
```

### Memory Orderings

| Ordering | Use Case | BW-Tree Example |
|----------|----------|-----------------|
| `ACQUIRE` | Load that synchronizes with RELEASE store | Reading delta chain head |
| `RELEASE` | Store that makes prior writes visible | Publishing new delta node |
| `ACQUIRE_RELEASE` | RMW operation combining both | CAS on page table entry |
| `SEQUENTIAL` | Strongest guarantee (default) | Use when unsure; optimize later |
| `MONOTONIC` | No synchronization, just atomicity | Performance counters |

### Critical Pattern for Delta Chains

```mojo
# CORRECT: ACQUIRE when reading chain, RELEASE when publishing
fn append_delta(mut self, new_delta_ptr: UInt64) -> Bool:
    # Read current head with ACQUIRE (see all prior updates)
    var old_head = self.head_ptr.load[ordering=Consistency.ACQUIRE]()

    # Link new delta to current chain
    new_delta.next = old_head

    # CAS with RELEASE semantics (make delta visible)
    var expected = old_head
    return self.head_ptr.compare_exchange(expected, new_delta_ptr)

# WRONG: No memory ordering - races possible
fn append_delta_wrong(mut self, new_delta_ptr: UInt64) -> Bool:
    var old_head = self.head_ptr.load()  # Missing ACQUIRE
    new_delta.next = old_head
    var expected = old_head
    return self.head_ptr.compare_exchange(expected, new_delta_ptr)
```

## Pointer Management

### UnsafePointer Patterns

```mojo
from memory import UnsafePointer

# Allocation
var ptr = UnsafePointer[NodeHeader].alloc(1)

# Initialization (must initialize before use)
ptr.init_pointee_move(NodeHeader(NODE_BASE))

# Access
var node_type = ptr[].node_type

# Deallocation (careful with epoch-based reclamation!)
ptr.free()  # Only when safe - no other threads accessing

# Pointer arithmetic
var next_ptr = ptr + 1
```

### Pointer ↔ Atomic UInt64 Conversion

```mojo
# Store pointer in atomic
var node_ptr = UnsafePointer[NodeHeader].alloc(1)
var addr = int(node_ptr)  # Convert to int
var atom = Atomic[DType.uint64](UInt64(addr))

# Retrieve pointer from atomic
var stored_addr = atom.load[ordering=Consistency.ACQUIRE]()
var retrieved_ptr = UnsafePointer[NodeHeader](Int(stored_addr))

# Null pointer check
var is_null = stored_addr == 0
```

## SIMD Optimization Patterns

### Vectorized Key Comparison

```mojo
fn binary_search_simd[width: Int = 4](
    keys: UnsafePointer[Int64],
    key_count: Int,
    search_key: Int64
) -> Int:
    """Binary search using SIMD for 4-way comparison."""
    var left = 0
    var right = key_count

    while left < right:
        var mid = left + (right - left) // 2

        # Load 4 keys at once (if enough remain)
        if mid + width <= key_count:
            var key_vec = keys.load[width=width](mid)
            var search_vec = SIMD[DType.int64, width](search_key)

            # Element-wise comparison
            var less_mask = key_vec.le(search_vec)

            # Count how many are <= search_key
            var count = less_mask.cast[DType.int32]().reduce_add()

            # Adjust binary search bounds
            if count == width:
                left = mid + width
            else:
                right = mid + Int(count)
        else:
            # Fallback to scalar for tail
            if keys[mid] <= search_key:
                left = mid + 1
            else:
                right = mid

    return left
```

### Checksum Validation

```mojo
fn compute_checksum_simd(data: UnsafePointer[UInt8], length: Int) -> UInt64:
    """SIMD checksum computation."""
    alias width = 32  # Process 32 bytes at once

    var sum = SIMD[DType.uint64, 4](0)
    var chunks = length // width

    for i in range(0, chunks * 8, 8):  # 8 uint64s = 32 bytes
        var chunk = data.bitcast[DType.uint64]().load[width=4](i)
        sum += chunk

    # Reduce to single value
    return sum.reduce_add()
```

## Ownership and Lifetime

### Argument Conventions

```mojo
# Borrowed (default) - read-only view, no ownership transfer
fn read_node(borrowed node: Node) -> Int8:
    return node.header_ptr.load()

# Mutable borrow - allows modification
fn update_node(mut node: Node, new_val: UInt64):
    node.header_ptr.store(new_val)

# Owned - takes ownership, caller loses access
fn consume_node(owned node: Node):
    # node is moved, caller cannot use afterward
    pass

# Inout - mutable reference (older style, prefer 'mut')
fn modify_node(inout node: Node):
    node.header_ptr.store(42)
```

### Named Destructors

**New in v0.25.6:** `deinit` argument convention

```mojo
struct Node:
    var header_ptr: Atomic[DType.uint64]

    fn __init__(out self):
        self.header_ptr = Atomic[DType.uint64](0)

    # Standard destructor (implicit)
    fn __del__(owned self):
        # Called automatically when Node goes out of scope
        var ptr_val = self.header_ptr.load()
        if ptr_val != 0:
            var ptr = UnsafePointer[NodeHeader](Int(ptr_val))
            ptr.free()

    # Named destructor - consumes without calling __del__
    fn manual_cleanup(deinit self):
        # Use when you want custom cleanup without implicit destructor
        # Useful for epoch-based reclamation
        pass
```

## Common Pitfalls

### 1. Forgetting Memory Ordering

```mojo
# WRONG: Can see stale data or incomplete writes
var ptr = atom.load()  # Uses default, but should be explicit

# RIGHT: Explicit ordering matching synchronization intent
var ptr = atom.load[ordering=Consistency.ACQUIRE]()
```

### 2. ABA Problem with CAS

```mojo
# PROBLEM: Pointer recycled, CAS succeeds incorrectly
# Thread 1: Reads A → swapped to B → back to A (different node!)
# Thread 2: CAS from A to C succeeds even though A changed

# SOLUTION: Use epoch-based reclamation (defer frees)
# or add version counter to pointer (use upper bits)
```

### 3. Implicit Copies (Post v0.25.6)

```mojo
# WRONG: Will not compile
var table1 = PageTable(100)
var table2 = table1  # ERROR if PageTable not ImplicitlyCopyable

# RIGHT: Don't make our structs copyable (use references)
fn use_table(borrowed table: PageTable):
    # Work with borrowed reference
```

### 4. SIMD Width Mismatch

```mojo
# WRONG: Width mismatch causes compile error
var v1 = SIMD[DType.int64, 4](1, 2, 3, 4)
var v2 = SIMD[DType.int64, 8](...)
var result = v1 + v2  # ERROR: different widths

# RIGHT: Keep widths consistent or use aliases
alias SimdWidth = 4
var v1 = SIMD[DType.int64, SimdWidth](...)
var v2 = SIMD[DType.int64, SimdWidth](...)
```

### 5. Uninitialized Pointers

```mojo
# WRONG: Using allocated but uninitialized memory
var ptr = UnsafePointer[NodeHeader].alloc(1)
var node_type = ptr[].node_type  # UNDEFINED BEHAVIOR

# RIGHT: Initialize before use
var ptr = UnsafePointer[NodeHeader].alloc(1)
ptr.init_pointee_move(NodeHeader(NODE_BASE))
var node_type = ptr[].node_type  # Safe
```

## Performance Tips

### Inlining Hot Paths

```mojo
@always_inline
fn compare_keys(k1: Int64, k2: Int64) -> Int8:
    """Always inline for tight loops."""
    if k1 < k2:
        return -1
    elif k1 > k2:
        return 1
    return 0
```

### SIMD Width Selection

| Data Type | Typical Width | Rationale |
|-----------|---------------|-----------|
| Int64 keys | 4 (256-bit AVX2) | Good balance, widely supported |
| UInt8 checksums | 32-64 | Maximize throughput |
| Masks/flags | System-dependent | Use `simdwidthof[]` |

### CAS Loop Optimization

```mojo
# Avoid excessive CAS retries with backoff
fn cas_with_backoff(mut self, new_val: UInt64, max_retries: Int = 10) -> Bool:
    for attempt in range(max_retries):
        var expected = self.load[ordering=Consistency.ACQUIRE]()
        if self.compare_exchange(expected, new_val):
            return True

        # Exponential backoff (pseudo-code - use actual sleep/pause)
        if attempt > 3:
            # spin_loop_hint() or similar
            pass

    return False
```

## Version Compatibility

| Mojo Version | Notes |
|--------------|-------|
| 0.25.6+ | Copyability model changed, SIMD comparisons updated |
| 0.24.x | Use explicit `ImplicitlyCopyable` if needed |
| Earlier | Significant API differences, not recommended |

**Recommended:** Always use latest stable Mojo (currently 0.25.6+)

## References

- Mojo atomic stdlib: `stdlib/os/atomic.mojo`
- Changelog: `mojo/docs/changelog-released.md` in modular/modular repo
- Mojo Manual: https://docs.modular.com/mojo/manual/
