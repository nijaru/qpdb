"""Integrated BW-Tree with all advanced features.

Wires up epoch-based reclamation, exponential backoff, improved lookup,
and consolidation for a production-ready implementation.
"""

from memory import UnsafePointer
from os.atomic import Atomic, Consistency

from .node import Node, NodeHeader, NODE_BASE
from .page_table import PageTable
from .delta import InsertDelta, DeleteDelta
from .epoch import EpochManager, advance_global_epoch
from .consolidate import ConsolidationWorker, try_consolidate_node
from .lookup import lookup_with_delete_handling, scan_range
from .backoff import ExponentialBackoff


# Configuration constants
alias DEFAULT_PAGE_TABLE_SIZE = 1024
alias MAX_DELTA_CHAIN_LENGTH = 10
alias CAS_MAX_RETRIES = 100


struct BWTreeIntegrated:
    """Production-ready BW-Tree with all advanced features integrated.

    Includes:
    - Epoch-based memory reclamation for safe concurrent access
    - Exponential backoff for CAS retry under contention
    - Proper DeleteDelta handling in lookups
    - Background consolidation worker

    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var page_table: PageTable
    var root_page_id: Int
    var next_page_id: Atomic[DType.uint64]
    var epoch_mgr: EpochManager
    var consolidation_worker: ConsolidationWorker

    fn __init__(out self, capacity: Int = DEFAULT_PAGE_TABLE_SIZE):
        """Initialize integrated BW-Tree with all features.

        Args:
            capacity: Number of logical page IDs to support.
        """
        self.page_table = PageTable(capacity)
        self.root_page_id = 0
        self.next_page_id = Atomic[DType.uint64](1)
        self.epoch_mgr = EpochManager()
        self.consolidation_worker = ConsolidationWorker(self.page_table, MAX_DELTA_CHAIN_LENGTH)

        # Initialize root node
        var root_node_ptr = UnsafePointer[Node].alloc(1)
        root_node_ptr.init_pointee_move(Node())

        # Map root page ID to root node
        var root_addr = UInt64(int(root_node_ptr))
        self.page_table.set(self.root_page_id, root_addr)

    fn __del__(owned self):
        """Cleanup BW-Tree resources with epoch-based reclamation.

        Flushes all deferred garbage to ensure proper cleanup.
        """
        # Flush any remaining deferred garbage
        self.epoch_mgr.flush()

        # Free root node
        var root_addr = self.page_table.get(self.root_page_id)
        if root_addr != 0:
            var root_ptr = UnsafePointer[Node](Int(root_addr))
            root_ptr.free()

    fn allocate_page_id(mut self) -> UInt64:
        """Allocate a new logical page ID.

        Returns:
            Newly allocated page ID.
        """
        return self.next_page_id.fetch_add(1)

    fn get_node(borrowed self, page_id: Int) -> UInt64:
        """Get physical node pointer for logical page ID.

        Args:
            page_id: Logical page ID.

        Returns:
            Physical pointer to Node (as UInt64) or 0 if unmapped.
        """
        return self.page_table.get(page_id)

    fn insert(mut self, key: Int64, value: UInt64) -> Bool:
        """Insert key-value pair with epoch protection and backoff.

        Uses:
        - Epoch pinning for safe concurrent access
        - Exponential backoff for CAS retry
        - Automatic consolidation triggering

        Args:
            key: Key to insert.
            value: Value to associate with key.

        Returns:
            True if insert succeeded, False otherwise.
        """
        # Pin epoch for safe access
        var guard = self.epoch_mgr.pin()

        # Get root node
        var node_addr = self.get_node(self.root_page_id)
        if node_addr == 0:
            return False

        var node_ptr = UnsafePointer[Node](Int(node_addr))

        # Create InsertDelta
        var delta_ptr = UnsafePointer[InsertDelta].alloc(1)
        delta_ptr.init_pointee_move(InsertDelta(key, value))

        # Use exponential backoff for CAS retry
        var backoff = ExponentialBackoff()
        var success = False

        while backoff.should_retry(CAS_MAX_RETRIES):
            # Read current head
            var current_head = node_ptr[].get_header()

            # Link delta to current chain
            delta_ptr[].next = UnsafePointer[InsertDelta](Int(current_head))

            # Try CAS
            var delta_addr = UInt64(int(delta_ptr))
            if node_ptr[].compare_and_swap(current_head, delta_addr):
                success = True
                break

            # Backoff before retry
            backoff.backoff()

        if not success:
            # Failed to append, cleanup
            delta_ptr.free()
            return False

        # Check if consolidation needed
        if node_ptr[].needs_consolidation(MAX_DELTA_CHAIN_LENGTH):
            # Trigger consolidation (async in production)
            _ = self.consolidation_worker.consolidate_page(self.root_page_id)

        # Periodically advance global epoch for garbage collection
        advance_global_epoch()
        self.epoch_mgr.try_collect()

        return True

    fn lookup(borrowed self, key: Int64) -> (Bool, UInt64):
        """Lookup value with proper DeleteDelta handling.

        Uses improved lookup that respects delete semantics.

        Args:
            key: Key to search for.

        Returns:
            Tuple of (found, value). found is False if key deleted or not found.
        """
        # Pin epoch for safe traversal
        var guard = self.epoch_mgr.pin()

        # Get root node
        var node_addr = self.get_node(self.root_page_id)
        if node_addr == 0:
            return (False, UInt64(0))

        var node_ptr = UnsafePointer[Node](Int(node_addr))

        # Use improved lookup with DeleteDelta handling
        return lookup_with_delete_handling(node_ptr, key)

    fn delete(mut self, key: Int64) -> Bool:
        """Delete key with epoch protection and backoff.

        Args:
            key: Key to delete.

        Returns:
            True if delete succeeded, False otherwise.
        """
        # Pin epoch for safe access
        var guard = self.epoch_mgr.pin()

        # Get root node
        var node_addr = self.get_node(self.root_page_id)
        if node_addr == 0:
            return False

        var node_ptr = UnsafePointer[Node](Int(node_addr))

        # Create DeleteDelta
        var delta_ptr = UnsafePointer[DeleteDelta].alloc(1)
        delta_ptr.init_pointee_move(DeleteDelta(key))

        # Use exponential backoff for CAS retry
        var backoff = ExponentialBackoff()
        var success = False

        while backoff.should_retry(CAS_MAX_RETRIES):
            # Read current head
            var current_head = node_ptr[].get_header()

            # Link delta to current chain
            delta_ptr[].next = UnsafePointer[DeleteDelta](Int(current_head))

            # Try CAS
            var delta_addr = UInt64(int(delta_ptr))
            if node_ptr[].compare_and_swap(current_head, delta_addr):
                success = True
                break

            # Backoff before retry
            backoff.backoff()

        if not success:
            # Failed to append, cleanup
            delta_ptr.free()
            return False

        # Check if consolidation needed
        if node_ptr[].needs_consolidation(MAX_DELTA_CHAIN_LENGTH):
            _ = self.consolidation_worker.consolidate_page(self.root_page_id)

        # Periodically advance epoch and collect garbage
        advance_global_epoch()
        self.epoch_mgr.try_collect()

        return True

    fn scan(borrowed self, start_key: Int64, end_key: Int64) -> List[(Int64, UInt64)]:
        """Scan range of keys with DeleteDelta support.

        Args:
            start_key: Start of range (inclusive).
            end_key: End of range (exclusive).

        Returns:
            List of (key, value) pairs in range, excluding deleted keys.
        """
        # Pin epoch for safe traversal
        var guard = self.epoch_mgr.pin()

        # Get root node
        var node_addr = self.get_node(self.root_page_id)
        if node_addr == 0:
            return List[(Int64, UInt64)]()

        var node_ptr = UnsafePointer[Node](Int(node_addr))

        # Use improved range scan
        return scan_range(node_ptr, start_key, end_key)

    fn size(borrowed self) -> Int:
        """Get approximate number of keys in the index.

        NOTE: This is still an approximation. Accurate counting would require
        consolidation or full delta chain traversal with deduplication.

        Returns:
            Approximate key count.
        """
        var node_addr = self.get_node(self.root_page_id)
        if node_addr == 0:
            return 0

        var node_ptr = UnsafePointer[Node](Int(node_addr))
        return node_ptr[].get_chain_length()

    fn trigger_consolidation(mut self) -> Bool:
        """Manually trigger consolidation of root node.

        Returns:
            True if consolidation succeeded.
        """
        return self.consolidation_worker.consolidate_page(self.root_page_id)

    fn collect_garbage(mut self):
        """Manually trigger garbage collection.

        Useful for testing or explicit memory management.
        """
        self.epoch_mgr.try_collect()
