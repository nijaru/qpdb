"""Page table mapping logical page IDs to physical locations.

Enables atomic pointer updates for latch-free concurrency.
"""

from os.atomic import Atomic
from memory import UnsafePointer


struct PageTable:
    """Maps logical page IDs to physical node pointers.

    Each entry is an atomic pointer allowing lock-free updates.
    """

    var entries: UnsafePointer[Atomic[DType.uint64]]
    var capacity: Int

    fn __init__(out self, capacity: Int):
        self.capacity = capacity
        self.entries = UnsafePointer[Atomic[DType.uint64]].alloc(capacity)

        # Initialize all entries to null
        for i in range(capacity):
            self.entries[i] = Atomic[DType.uint64](0)

    fn get(self, page_id: Int) -> UInt64:
        """Read physical pointer for logical page ID."""
        return self.entries[page_id].load()

    fn update(
        mut self,
        page_id: Int,
        expected: UInt64,
        desired: UInt64
    ) -> Bool:
        """Atomic CAS update of page mapping."""
        var expected_val = expected
        return self.entries[page_id].compare_exchange(expected_val, desired)
