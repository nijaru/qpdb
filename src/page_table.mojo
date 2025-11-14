"""Page table mapping logical page IDs to physical locations.

Enables atomic pointer updates for latch-free concurrency.
"""

from os.atomic import Atomic, Consistency
from memory import UnsafePointer, alloc
from memory.unsafe_pointer import _default_invariant


struct PageTable:
    """Maps logical page IDs to physical node pointers.

    Each entry is an atomic pointer allowing lock-free updates.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var entries: UnsafePointer[Atomic[DType.uint64], mut=True, origin=_default_invariant[True]()]
    var capacity: Int

    fn __init__(out self, capacity: Int):
        """Initialize page table with given capacity.

        Args:
            capacity: Number of logical page IDs to support.
        """
        self.capacity = capacity
        self.entries = alloc[Atomic[DType.uint64]](capacity)

        # Initialize all entries to null (0)
        for i in range(capacity):
            self.entries[i] = Atomic[DType.uint64](0)

    fn deinit(self):
        """Free allocated page table entries."""
        if self.entries:
            self.entries.free()

    fn get(self, page_id: Int) -> UInt64:
        """Read physical pointer for logical page ID with ACQUIRE ordering.

        ACQUIRE ensures we see all writes that happened-before the store
        that published this mapping.

        Args:
            page_id: Logical page ID to look up.

        Returns:
            Physical pointer (as UInt64) or 0 if unmapped.
        """
        return self.entries[page_id].load[ordering=Consistency.ACQUIRE]()

    fn update(
        mut self,
        page_id: Int,
        expected: UInt64,
        desired: UInt64
    ) -> Bool:
        """Atomic CAS update of page mapping.

        Uses ACQUIRE_RELEASE ordering (default for compare_exchange):
        - ACQUIRE: see all writes before the successful store
        - RELEASE: make our writes visible to subsequent readers

        Args:
            page_id: Logical page ID to update.
            expected: Expected current value (updated on failure).
            desired: New value to install if current equals expected.

        Returns:
            True if CAS succeeded, False otherwise.
        """
        var expected_val = expected
        return self.entries[page_id].compare_exchange(expected_val, desired)

    fn set(mut self, page_id: Int, value: UInt64):
        """Unconditionally set page mapping with RELEASE ordering.

        RELEASE ensures all prior writes are visible before this mapping
        becomes visible to readers.

        Args:
            page_id: Logical page ID to update.
            value: Physical pointer to install.
        """
        var entry_ptr = UnsafePointer(to=self.entries[page_id].value)
        Atomic[DType.uint64].store[ordering=Consistency.RELEASE](entry_ptr, value)
