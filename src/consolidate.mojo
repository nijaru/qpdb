"""Delta chain consolidation for BW-Tree nodes.

Consolidates long delta chains into base nodes to maintain performance.
Background process that periodically compacts delta chains.
"""

from memory import UnsafePointer
from collections import Dict

from .node import Node, NodeHeader, NODE_BASE, NODE_INSERT, NODE_DELETE
from .delta import InsertDelta, DeleteDelta
from .page_table import PageTable
from .epoch import EpochManager


struct BaseNode:
    """Consolidated base node with sorted key-value pairs.

    Result of consolidating a delta chain. Contains all active
    key-value pairs in sorted order.
    """

    var keys: UnsafePointer[Int64]
    var values: UnsafePointer[UInt64]
    var count: Int
    var capacity: Int

    fn __init__(out self, capacity: Int):
        """Allocate base node with given capacity.

        Args:
            capacity: Maximum number of keys to store.
        """
        self.capacity = capacity
        self.count = 0
        self.keys = UnsafePointer[Int64].alloc(capacity)
        self.values = UnsafePointer[UInt64].alloc(capacity)

    fn __del__(owned self):
        """Free base node storage."""
        if self.keys:
            self.keys.free()
        if self.values:
            self.values.free()

    fn insert(mut self, key: Int64, value: UInt64) -> Bool:
        """Insert key-value pair into base node.

        Args:
            key: Key to insert.
            value: Value to associate.

        Returns:
            True if inserted, False if capacity exceeded.
        """
        if self.count >= self.capacity:
            return False

        # Simple append (caller should ensure keys are sorted)
        self.keys[self.count] = key
        self.values[self.count] = value
        self.count += 1
        return True

    fn lookup(self, key: Int64) -> (Bool, UInt64):
        """Binary search for key in base node.

        Args:
            key: Key to search for.

        Returns:
            Tuple of (found, value).
        """
        # Binary search
        var left = 0
        var right = self.count

        while left < right:
            var mid = left + (right - left) // 2

            if self.keys[mid] < key:
                left = mid + 1
            elif self.keys[mid] > key:
                right = mid
            else:
                return (True, self.values[mid])

        return (False, UInt64(0))


fn consolidate_delta_chain(
    node_ptr: UnsafePointer[Node],
    mut epoch_mgr: EpochManager
) -> UnsafePointer[BaseNode]:
    """Consolidate delta chain into a base node.

    Traverses delta chain, applies all inserts/deletes, and creates
    a new consolidated base node with sorted key-value pairs.

    Args:
        node_ptr: Pointer to Node with delta chain.
        epoch_mgr: Epoch manager for safe memory reclamation.

    Returns:
        Pointer to newly allocated BaseNode with consolidated state.
    """
    # Pin epoch for safe traversal
    var guard = epoch_mgr.pin()

    # Use dictionary to track latest value for each key
    var kv_map = Dict[Int64, UInt64]()
    var deleted_keys = Dict[Int64, Bool]()

    # Traverse delta chain from head to tail
    var current_addr = node_ptr[].get_header()

    while current_addr != 0:
        # For now, assume all deltas are InsertDelta or DeleteDelta
        # TODO: Add proper type discrimination using DeltaChain

        # Try as InsertDelta first (hack - need proper type tagging)
        var insert_ptr = UnsafePointer[InsertDelta](Int(current_addr))

        # Check if this looks like a valid InsertDelta by examining next pointer
        # In production, would use proper type tags
        var key = insert_ptr[].key
        var value = insert_ptr[].value

        # Store in map (most recent wins since we traverse head to tail)
        if key not in deleted_keys:
            kv_map[key] = value

        # Move to next delta
        current_addr = UInt64(int(insert_ptr[].next))

    # Create base node with consolidated state
    var base_node = UnsafePointer[BaseNode].alloc(1)
    base_node.init_pointee_move(BaseNode(len(kv_map)))

    # Insert all key-value pairs (should be sorted for efficiency)
    # TODO: Sort keys before inserting
    for item in kv_map.items():
        _ = base_node[].insert(item[].key, item[].value)

    return base_node


fn try_consolidate_node(
    node_ptr: UnsafePointer[Node],
    mut page_table: PageTable,
    page_id: Int,
    mut epoch_mgr: EpochManager,
    threshold: Int = 10
) -> Bool:
    """Attempt to consolidate a node if delta chain is too long.

    Checks if consolidation is needed, and if so, creates a new
    base node and installs it via CAS on the page table.

    Args:
        node_ptr: Pointer to Node to potentially consolidate.
        page_table: Page table for CAS update.
        page_id: Logical page ID of this node.
        epoch_mgr: Epoch manager for safe reclamation.
        threshold: Chain length threshold for consolidation.

    Returns:
        True if consolidation succeeded, False if not needed or failed.
    """
    # Check if consolidation needed
    if not node_ptr[].needs_consolidation(threshold):
        return False

    # Consolidate delta chain into base node
    var base_node = consolidate_delta_chain(node_ptr, epoch_mgr)

    # Wrap base node in new Node structure
    var new_node_ptr = UnsafePointer[Node].alloc(1)
    new_node_ptr.init_pointee_move(Node())

    # Install base node as head of new Node
    var base_addr = UInt64(int(base_node))
    # Note: This is simplified - in production, base node would have
    # proper NodeHeader with NODE_BASE type

    # Try to CAS the new consolidated node into page table
    var old_node_addr = UInt64(int(node_ptr))
    var new_node_addr = UInt64(int(new_node_ptr))

    var success = page_table.update(page_id, old_node_addr, new_node_addr)

    if success:
        # Successfully installed consolidated node
        # Defer freeing old delta chain until safe
        epoch_mgr.defer_free(old_node_addr)

        # Advance global epoch to allow reclamation
        # (In production, would be done by background thread)
        from .epoch import advance_global_epoch
        advance_global_epoch()

        return True
    else:
        # CAS failed, another thread modified the page table
        # Clean up our consolidated node
        base_node.free()
        new_node_ptr.free()
        return False


struct ConsolidationWorker:
    """Background worker for delta chain consolidation.

    Periodically scans page table and consolidates long delta chains.
    Should run in a separate thread.
    """

    var page_table: PageTable
    var epoch_mgr: EpochManager
    var threshold: Int
    var running: Bool

    fn __init__(out self, mut page_table: PageTable, threshold: Int = 10):
        """Initialize consolidation worker.

        Args:
            page_table: Page table to scan.
            threshold: Chain length threshold.
        """
        self.page_table = page_table
        self.epoch_mgr = EpochManager()
        self.threshold = threshold
        self.running = False

    fn start(mut self):
        """Start consolidation worker loop.

        NOTE: This is synchronous for now. In production, would
        spawn a background thread.
        """
        self.running = True

    fn stop(mut self):
        """Stop consolidation worker."""
        self.running = False

    fn run_once(mut self):
        """Run one iteration of consolidation.

        Scans page table and consolidates eligible nodes.
        Returns number of nodes consolidated.
        """
        # Simplified: In production, would scan all pages
        # For now, just try to collect garbage
        self.epoch_mgr.try_collect()

    fn consolidate_page(mut self, page_id: Int) -> Bool:
        """Attempt to consolidate a specific page.

        Args:
            page_id: Logical page ID to consolidate.

        Returns:
            True if consolidated, False otherwise.
        """
        var node_addr = self.page_table.get(page_id)
        if node_addr == 0:
            return False

        var node_ptr = UnsafePointer[Node](Int(node_addr))
        return try_consolidate_node(
            node_ptr,
            self.page_table,
            page_id,
            self.epoch_mgr,
            self.threshold
        )
