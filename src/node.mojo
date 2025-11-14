"""BW-Tree node structures with delta chains.

Core data structures for latch-free BW-Tree nodes using atomic operations.
"""

from os.atomic import Atomic, Consistency
from memory import UnsafePointer
from memory.unsafe_pointer import _default_invariant

# Node types for delta chain
alias NODE_BASE = 0
alias NODE_INSERT = 1
alias NODE_DELETE = 2
alias NODE_SPLIT = 3
alias NODE_MERGE = 4


struct NodeHeader(Movable):
    """Header for BW-Tree nodes and delta records.

    Not ImplicitlyCopyable to prevent accidental copies that could
    break delta chain pointer semantics.
    """

    var node_type: Int8
    var key_count: Int32
    var next: UnsafePointer[NodeHeader, mut=True, origin=_default_invariant[True]()]  # Next delta or base node

    fn __init__(out self, node_type: Int8):
        self.node_type = node_type
        self.key_count = 0
        self.next = UnsafePointer[NodeHeader, mut=True, origin=_default_invariant[True]()]()


struct Node:
    """Base BW-Tree node with sorted keys.

    Uses atomic pointer for latch-free delta chain updates.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var header_ptr: Atomic[DType.uint64]  # Atomic pointer to NodeHeader

    fn __init__(out self):
        self.header_ptr = Atomic[DType.uint64](0)

    fn get_header(self) -> UInt64:
        """Read current header pointer with ACQUIRE ordering.

        ACQUIRE ensures we see all writes that happened-before the store
        that published this pointer value.
        """
        return self.header_ptr.load[ordering=Consistency.ACQUIRE]()

    fn compare_and_swap(
        mut self,
        expected: UInt64,
        desired: UInt64
    ) -> Bool:
        """Atomic CAS operation for delta chain updates.

        Uses default ACQUIRE_RELEASE ordering for CAS:
        - ACQUIRE on success: see all writes before the successful store
        - RELEASE on success: make our writes visible to readers
        """
        var expected_val = expected
        return self.header_ptr.compare_exchange(expected_val, desired)

    fn append_delta_with_retry(
        mut self,
        delta_ptr: UInt64,
        max_retries: Int = 100
    ) -> Bool:
        """Append delta to chain with CAS retry loop.

        Attempts to atomically prepend delta to the current chain.
        Retries on CAS failure up to max_retries times.

        Args:
            delta_ptr: Pointer to delta node to prepend.
            max_retries: Maximum CAS retry attempts.

        Returns:
            True if delta was successfully appended, False if max retries exceeded.
        """
        for attempt in range(max_retries):
            # Read current head with ACQUIRE
            var current_head = self.get_header()

            # Link new delta to current chain
            # NOTE: Caller must ensure delta.next is set to current_head before calling

            # Try to CAS new delta as the new head
            if self.compare_and_swap(current_head, delta_ptr):
                return True

            # CAS failed, another thread modified the chain
            # Retry with new head value (already loaded by failed CAS)

        # Max retries exceeded
        return False

    fn get_chain_length(self) -> Int:
        """Count the number of deltas in the chain.

        Traverses the delta chain to count nodes. Useful for determining
        when consolidation is needed.

        Returns:
            Number of delta nodes in the chain (0 if just base node).
        """
        var count = 0
        var current_addr = self.get_header()

        while current_addr != 0:
            var current_ptr = UnsafePointer[NodeHeader](Int(current_addr))
            count += 1

            # Follow the next pointer
            current_addr = UInt64(int(current_ptr[].next))

        return count

    fn needs_consolidation(self, max_chain_length: Int = 10) -> Bool:
        """Check if delta chain exceeds consolidation threshold.

        Args:
            max_chain_length: Maximum allowed chain length before consolidation.

        Returns:
            True if chain length exceeds threshold.
        """
        return self.get_chain_length() > max_chain_length
