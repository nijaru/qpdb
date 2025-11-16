# LeanStore Implementation Guide

**Target Repository**: bw-tree (experimental Mojo/Rust storage engine)
**License**: MIT (open source, experimental)
**Purpose**: Build complete LeanStore storage engine from scratch
**Status**: Design specification for experimental implementation
**Last Updated**: November 14, 2025

**Research Foundation**: See `ai/research/general_storage_engine_sota.md` (Phase 4)

---

## Executive Summary

This guide provides a complete implementation roadmap for LeanStore-style storage engine:
- **Pointer swizzling**: 40-60% buffer manager speedup over hash tables
- **Optimistic Lock Coupling (OLC)**: Lock-free reads, minimal write locking
- **io_uring**: Saturate NVMe bandwidth (5+ GB/s)
- **Autonomous commits**: High throughput + low latency (no group commit batching)

**Why LeanStore over Bw-tree**:
- Bw-tree is outdated (2013, complex delta chains, not used outside Microsoft)
- LeanStore is SOTA (2018+, proven, simpler implementation)
- Better performance on modern hardware (NVMe, multi-core)

**Implementation Goal**: Minimal working system for learning and experimentation

---

## Implementation Phases (6-8 Weeks)

### Phase 1: Page Table & Buffer Pool (Weeks 1-2)

**Core Data Structures**:

```rust
type PageID = u64;

/// Swizzled pointer (key innovation)
enum Swip {
    Hot(*mut Page),   // Direct pointer (O(1) access)
    Cold(u64),        // Disk offset (needs I/O)
}

/// Page table
struct PageTable {
    mapping: HashMap<PageID, Swip>,
    lock: RwLock<()>,
}

/// In-memory page
#[repr(align(4096))]  // OS page alignment
struct Page {
    pid: PageID,
    latch: OptimisticLatch,
    data: [u8; 4096],
    dirty: AtomicBool,
    referenced: AtomicBool,  // For CLOCK eviction
}

/// Buffer pool with CLOCK eviction
struct BufferPool {
    pages: Vec<Option<*mut Page>>,
    clock_hand: usize,
    max_pages: usize,
}
```

**Key Operations**:

```rust
impl PageTable {
    /// Get page (swizzle if cold)
    fn get_page(&mut self, pid: PageID) -> Result<*mut Page> {
        match self.mapping.get(&pid) {
            Some(Swip::Hot(ptr)) => Ok(*ptr),
            Some(Swip::Cold(offset)) => {
                // Load from disk
                let page = self.load_from_disk(*offset)?;

                // Allocate in buffer pool (evict if needed)
                let ptr = self.buffer_pool.allocate(page)?;

                // Update mapping (cold → hot)
                self.mapping.insert(pid, Swip::Hot(ptr));

                Ok(ptr)
            }
            None => Err(PageNotFound),
        }
    }

    /// Unswizzle page (hot → cold)
    fn unswizzle(&mut self, pid: PageID) -> Result<()> {
        if let Some(Swip::Hot(ptr)) = self.mapping.get(&pid) {
            // Flush if dirty
            let page = unsafe { &*ptr };
            if page.dirty.load(Ordering::Acquire) {
                self.flush_to_disk(ptr)?;
            }

            // Update mapping (hot → cold)
            let offset = self.page_offset(pid);
            self.mapping.insert(pid, Swip::Cold(offset));

            // Free from buffer pool
            self.buffer_pool.free(ptr);
        }
        Ok(())
    }
}

impl BufferPool {
    /// Find victim using CLOCK algorithm
    fn find_victim(&mut self) -> Option<PageID> {
        loop {
            let idx = self.clock_hand;
            self.clock_hand = (self.clock_hand + 1) % self.max_pages;

            if let Some(ptr) = self.pages[idx] {
                let page = unsafe { &*ptr };

                // Check reference bit
                if page.referenced.swap(false, Ordering::AcqRel) {
                    // Recently accessed, give second chance
                    continue;
                } else {
                    // Victim found
                    return Some(page.pid);
                }
            }
        }
    }
}
```

**Deliverable**: Buffer manager with pointer swizzling, CLOCK eviction

---

### Phase 2: Optimistic Lock Coupling (Week 3)

**Optimistic Latch**:

```rust
struct OptimisticLatch {
    version_lock: AtomicU64,
}

const LOCK_BIT: u64 = 1 << 63;

impl OptimisticLatch {
    fn new() -> Self {
        Self { version_lock: AtomicU64::new(0) }
    }

    /// Read version (optimistic read start)
    fn read_version(&self) -> u64 {
        self.version_lock.load(Ordering::Acquire)
    }

    /// Validate version unchanged (optimistic read end)
    fn validate(&self, old_version: u64) -> bool {
        let current = self.version_lock.load(Ordering::Acquire);
        current == old_version && (current & LOCK_BIT) == 0
    }

    /// Try exclusive lock (for writes)
    fn try_lock(&self) -> Option<u64> {
        let version = self.read_version();

        if (version & LOCK_BIT) != 0 {
            return None;  // Already locked
        }

        let locked = version | LOCK_BIT;
        match self.version_lock.compare_exchange(
            version,
            locked,
            Ordering::Acquire,
            Ordering::Relaxed
        ) {
            Ok(_) => Some(version),
            Err(_) => None,  // CAS failed
        }
    }

    /// Release lock and increment version
    fn unlock(&self, old_version: u64) {
        let new_version = (old_version & !LOCK_BIT) + 1;
        self.version_lock.store(new_version, Ordering::Release);
    }
}
```

**Usage Pattern**:

```rust
// Optimistic read (no locking)
loop {
    let version = page.latch.read_version();
    let value = page.read_data();

    if page.latch.validate(version) {
        return value;  // Success
    }
    // Retry (concurrent modification detected)
}

// Exclusive write (with lock)
if let Some(version) = page.latch.try_lock() {
    page.write_data(new_value);
    page.latch.unlock(version);
}
```

**Deliverable**: Lock-free reads, minimal write locking

---

### Phase 3: B+-Tree Structure (Week 4)

**Node Structure**:

```rust
const FANOUT: usize = 256;  // For 4KB pages

#[repr(C)]
struct BTreeNode {
    latch: OptimisticLatch,
    num_keys: u16,
    is_leaf: bool,
    keys: [Key; FANOUT],
    payload: NodePayload,
}

enum NodePayload {
    Internal([PageID; FANOUT + 1]),  // Child pointers
    Leaf([Value; FANOUT]),           // Values
}

impl BTreeNode {
    fn find_position(&self, key: &Key) -> usize {
        self.keys[..self.num_keys as usize]
            .binary_search(key)
            .unwrap_or_else(|pos| pos)
    }

    fn search(&self, key: &Key) -> Option<Value> {
        let pos = self.find_position(key);
        if let NodePayload::Leaf(values) = &self.payload {
            if pos < self.num_keys as usize && self.keys[pos] == *key {
                return Some(values[pos]);
            }
        }
        None
    }

    fn split(&mut self) -> (Key, BTreeNode) {
        let mid = self.num_keys as usize / 2;
        let split_key = self.keys[mid];

        let mut sibling = BTreeNode::new(self.is_leaf);
        let right_count = self.num_keys as usize - mid - 1;

        // Move right half to sibling
        sibling.keys[..right_count]
            .copy_from_slice(&self.keys[mid+1..self.num_keys as usize]);
        sibling.num_keys = right_count as u16;
        self.num_keys = mid as u16;

        (split_key, sibling)
    }
}
```

**Optimistic Lookup**:

```rust
impl BPlusTree {
    fn lookup(&self, key: &Key) -> Option<Value> {
        loop {
            let (root_version) = self.read_optimistic(self.root);

            // Traverse to leaf (no locks)
            let leaf_pid = self.traverse_to_leaf(key);
            let (leaf_page, leaf_version) = self.read_optimistic(leaf_pid);

            // Search in leaf
            let value = leaf_page.search(key);

            // Validate path (no concurrent modifications)
            if self.validate(root_version, leaf_version) {
                return value;
            }
            // Retry
        }
    }

    fn insert(&mut self, key: Key, value: Value) -> Result<()> {
        loop {
            let path = self.traverse_with_path(&key);
            let leaf = path.last().unwrap();

            if let Some(version) = leaf.try_lock() {
                match leaf.insert_into_page(key, value) {
                    Ok(_) => {
                        leaf.unlock(version);
                        return Ok(());
                    }
                    Err(PageFull) => {
                        // Split leaf, lock parent
                        self.handle_split(leaf, &path)?;
                        leaf.unlock(version);
                        return Ok(());
                    }
                }
            }
            // Lock failed, retry
        }
    }
}
```

**Deliverable**: B+-Tree with OLC (insert, search, delete)

---

### Phase 4: I/O Layer (Week 5)

**io_uring (Linux)**:

```rust
#[cfg(target_os = "linux")]
struct AsyncIO {
    ring: io_uring::IoUring,
    fd: RawFd,
}

#[cfg(target_os = "linux")]
impl AsyncIO {
    fn new(path: &Path) -> Result<Self> {
        let ring = IoUring::new(256)?;  // Queue depth
        let fd = OpenOptions::new()
            .read(true)
            .write(true)
            .custom_flags(libc::O_DIRECT)  // Direct I/O
            .open(path)?
            .into_raw_fd();

        Ok(Self { ring, fd })
    }

    fn read_page(&mut self, offset: u64, buffer: &mut [u8; 4096]) -> Result<()> {
        let read_op = opcode::Read::new(
            types::Fd(self.fd),
            buffer.as_mut_ptr(),
            4096
        ).offset(offset);

        unsafe { self.ring.submission().push(&read_op.build())?; }
        self.ring.submit_and_wait(1)?;

        let cqe = self.ring.completion().next().unwrap();
        if cqe.result() < 0 {
            return Err(io::Error::from_raw_os_error(-cqe.result()));
        }

        Ok(())
    }

    fn batch_read(&mut self, requests: &[(u64, &mut [u8; 4096])]) -> Result<()> {
        // Submit all reads
        for (offset, buffer) in requests {
            let read_op = opcode::Read::new(
                types::Fd(self.fd),
                buffer.as_mut_ptr(),
                4096
            ).offset(*offset);
            unsafe { self.ring.submission().push(&read_op.build())?; }
        }

        self.ring.submit()?;

        // Wait for all completions
        for _ in 0..requests.len() {
            let cqe = self.ring.completion().next().unwrap();
            if cqe.result() < 0 {
                return Err(io::Error::from_raw_os_error(-cqe.result()));
            }
        }

        Ok(())
    }

    fn write_and_sync(&mut self, offset: u64, data: &[u8]) -> Result<()> {
        let write_op = opcode::Write::new(
            types::Fd(self.fd),
            data.as_ptr(),
            data.len() as u32
        ).offset(offset);

        let fsync_op = opcode::Fsync::new(types::Fd(self.fd));

        unsafe {
            self.ring.submission().push(&write_op.build())?;
            self.ring.submission().push(&fsync_op.build())?;
        }

        self.ring.submit_and_wait(2)?;

        for _ in 0..2 {
            let cqe = self.ring.completion().next().unwrap();
            if cqe.result() < 0 {
                return Err(io::Error::from_raw_os_error(-cqe.result()));
            }
        }

        Ok(())
    }
}
```

**macOS Fallback**:

```rust
#[cfg(target_os = "macos")]
struct AsyncIO {
    fd: RawFd,
}

#[cfg(target_os = "macos")]
impl AsyncIO {
    fn read_page(&mut self, offset: u64, buffer: &mut [u8; 4096]) -> Result<()> {
        // Synchronous fallback
        let mut file = unsafe { File::from_raw_fd(self.fd) };
        file.seek(SeekFrom::Start(offset))?;
        file.read_exact(buffer)?;
        std::mem::forget(file);  // Don't close FD
        Ok(())
    }

    fn write_and_sync(&mut self, offset: u64, data: &[u8]) -> Result<()> {
        let mut file = unsafe { File::from_raw_fd(self.fd) };
        file.seek(SeekFrom::Start(offset))?;
        file.write_all(data)?;
        file.sync_data()?;
        std::mem::forget(file);
        Ok(())
    }
}
```

**Deliverable**: Async I/O with io_uring (Linux), sync fallback (macOS)

---

### Phase 5: WAL & Recovery (Week 6)

**WAL Structure**:

```rust
enum WALRecord {
    Begin { txn_id: u64 },
    Insert { txn_id: u64, pid: PageID, key: Key, value: Value },
    Update { txn_id: u64, pid: PageID, key: Key, old: Value, new: Value },
    Delete { txn_id: u64, pid: PageID, key: Key },
    Commit { txn_id: u64 },
    Abort { txn_id: u64 },
    Checkpoint { lsn: u64 },
}

struct WAL {
    file: File,
    lsn: AtomicU64,  // Log Sequence Number
}

impl WAL {
    /// Append record (autonomous commit - immediate flush)
    fn append(&mut self, record: WALRecord) -> Result<u64> {
        let lsn = self.lsn.fetch_add(1, Ordering::SeqCst);

        let bytes = bincode::serialize(&record)?;
        self.file.write_all(&bytes)?;
        self.file.sync_data()?;  // fsync (immediate durability)

        Ok(lsn)
    }

    /// Recover from WAL
    fn recover(&mut self, buffer_manager: &mut BufferManager) -> Result<()> {
        let checkpoint_lsn = self.find_last_checkpoint()?;
        self.file.seek(SeekFrom::Start(checkpoint_lsn))?;

        let mut active_txns = HashSet::new();

        for record in self.read_records() {
            match record {
                WALRecord::Begin { txn_id } => {
                    active_txns.insert(txn_id);
                }
                WALRecord::Insert { pid, key, value, .. } => {
                    let page = buffer_manager.get_page(pid)?;
                    unsafe { (*page).insert(key, value); }
                }
                WALRecord::Commit { txn_id } => {
                    active_txns.remove(&txn_id);
                }
                WALRecord::Abort { txn_id } => {
                    self.undo_transaction(txn_id)?;
                    active_txns.remove(&txn_id);
                }
                _ => {}
            }
        }

        // Abort incomplete transactions
        for txn_id in active_txns {
            self.undo_transaction(txn_id)?;
        }

        Ok(())
    }
}
```

**Deliverable**: Durable storage with crash recovery

---

### Phase 6: Testing & Benchmarking (Weeks 7-8)

**Test Cases**:
1. Buffer manager eviction under memory pressure
2. OLC correctness under concurrent access
3. B+-Tree operations (insert, search, delete, split)
4. Crash recovery (inject failures, verify recovery)
5. Performance comparison vs RocksDB/SQLite

**Benchmarks**:
- Sequential inserts (throughput)
- Random lookups (latency)
- Range scans (I/O efficiency)
- Mixed workloads (YCSB-like)

**Targets**:
- Beat SQLite on random lookups (buffer manager advantage)
- Approach RocksDB on writes (OLC advantage)
- Validate io_uring saturates NVMe (5+ GB/s)

---

## Memory Reclamation (Epoch-Based)

**Safe Deallocation** (prevents use-after-free):

```rust
struct EpochManager {
    global_epoch: AtomicU64,
    thread_epochs: Vec<AtomicU64>,
    garbage: Vec<Vec<*mut Page>>,
}

impl EpochManager {
    fn enter(&self, thread_id: usize) {
        let current = self.global_epoch.load(Ordering::Acquire);
        self.thread_epochs[thread_id].store(current, Ordering::Release);
    }

    fn exit(&self, thread_id: usize) {
        self.thread_epochs[thread_id].store(u64::MAX, Ordering::Release);
        self.try_reclaim();
    }

    fn retire(&mut self, ptr: *mut Page) {
        let current = self.global_epoch.load(Ordering::Acquire);
        self.garbage[current as usize % 3].push(ptr);
    }

    fn try_reclaim(&mut self) {
        let current = self.global_epoch.load(Ordering::Acquire);
        let min_epoch = self.thread_epochs.iter()
            .map(|e| e.load(Ordering::Acquire))
            .min()
            .unwrap_or(current);

        for epoch in 0..min_epoch {
            for ptr in self.garbage[epoch as usize % 3].drain(..) {
                unsafe { drop(Box::from_raw(ptr)); }
            }
        }
    }
}
```

---

## Mojo vs Rust Comparison

**Goal**: Determine if Mojo is viable for systems programming

**Hypothesis**: Mojo may offer performance advantages for certain patterns

**Evaluation Criteria**:
1. **Performance**: Memory layout control, SIMD primitives
2. **Safety**: Memory management without GC
3. **Interop**: C FFI (for io_uring)
4. **Ecosystem**: Libraries for storage (bincode, etc.)

**Approach**:
1. Build core components in both Rust and Mojo
2. Compare: LOC, performance, safety guarantees
3. Timeline: 2 months max, fallback to Rust if blocked

**Risks**:
- Mojo immaturity (may lack critical features)
- C FFI complexity (io_uring integration)
- Ecosystem gaps (serialization, async I/O)

---

## Open Questions

1. **Variable-size pages**:
   - Start with fixed 4KB or implement size classes immediately?
   - **Lean towards**: Fixed 4KB first, add variable sizes if needed

2. **Eviction policy**:
   - CLOCK (simple) vs 2Q (better) vs LRU-K (best)?
   - **Lean towards**: CLOCK first, upgrade to 2Q if benchmarks justify

3. **Transaction support**:
   - Full ACID or just durability (crash recovery)?
   - **Lean towards**: Crash recovery only (simpler, sufficient for learning)

4. **Mojo viability**:
   - Proceed with Mojo or pivot to Rust-only?
   - **Decision point**: After Phase 1 (buffer manager) - is Mojo blocking progress?

---

## References

**Primary Research**: `ai/research/general_storage_engine_sota.md` (Phase 4)

**LeanStore Papers**:
- Leis et al., "LeanStore: In-Memory Data Management Beyond Main Memory", ICDE 2018
- Alhomssi & Leis, "Scalable and Robust Snapshot Isolation", VLDB 2023
- Nguyen et al., "Autonomous Commits for High Throughput", PACMMOD 2025

**Source Code**:
- LeanStore: https://github.com/leanstore/leanstore (MIT)

**Additional Resources**:
- Leis et al., "The ART of Practical Synchronization", DaMoN 2016 (OLC)
- Axboe, "Efficient I/O with io_uring", 2019
- Graefe, "Modern B-Tree Techniques", Foundations and Trends in Databases 2011

---

**Last Updated**: November 14, 2025
**Status**: Design complete, ready for experimental implementation in bw-tree repo
