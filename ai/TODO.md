# Active Tasks

## Phase 0: Foundation

- [ ] Define core atomic node structure
- [ ] Implement page table with CAS operations
- [ ] Create delta chain data structures
- [ ] Write basic atomic tests
- [ ] Set up testing framework

## Future Phases

### Phase 1: Core Index
- [ ] Implement BW-Tree node operations (insert/delete/search)
- [ ] Add delta chain consolidation
- [ ] Support range scans

### Phase 2: MVCC & Transactions
- [ ] Add MVCC versioning
- [ ] Implement snapshot isolation
- [ ] Create transaction manager

### Phase 3: Value Separation
- [ ] Implement value log (vLog)
- [ ] Add value pointers to index
- [ ] Support inline vs external value routing

### Phase 4: Durability
- [ ] Write-ahead logging
- [ ] Group commit
- [ ] Recovery logic

### Phase 5: Background Services
- [ ] Delta consolidation worker
- [ ] Value log GC
- [ ] Checkpointing
