"""Delta record structures for BW-Tree delta chains.

Delta records represent incremental updates to base nodes without
requiring in-place modification (latch-free).
"""

from memory import UnsafePointer


struct InsertDelta:
    """Delta record for key-value insertion.

    Represents a logical insert operation applied to the delta chain.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var key: Int64
    var value: UInt64  # Could be inline value or pointer to value log
    var next: UnsafePointer[InsertDelta]  # Next delta in chain (may be different type)

    fn __init__(out self, key: Int64, value: UInt64):
        """Create new insert delta.

        Args:
            key: Key being inserted.
            value: Value or pointer to value log entry.
        """
        self.key = key
        self.value = value
        self.next = UnsafePointer[InsertDelta]()

    fn __init__(out self, key: Int64, value: UInt64, next: UnsafePointer[InsertDelta]):
        """Create new insert delta linked to existing chain.

        Args:
            key: Key being inserted.
            value: Value or pointer to value log entry.
            next: Pointer to next delta/node in chain.
        """
        self.key = key
        self.value = value
        self.next = next


struct DeleteDelta:
    """Delta record for key deletion.

    Represents a logical delete operation applied to the delta chain.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var key: Int64
    var next: UnsafePointer[DeleteDelta]

    fn __init__(out self, key: Int64):
        """Create new delete delta.

        Args:
            key: Key being deleted.
        """
        self.key = key
        self.next = UnsafePointer[DeleteDelta]()

    fn __init__(out self, key: Int64, next: UnsafePointer[DeleteDelta]):
        """Create new delete delta linked to existing chain.

        Args:
            key: Key being deleted.
            next: Pointer to next delta/node in chain.
        """
        self.key = key
        self.next = next


struct SplitDelta:
    """Delta record for node split operation.

    When a node becomes too large, a split delta indicates the split point
    and points to the new sibling node.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var split_key: Int64  # Keys >= split_key go to sibling
    var sibling_page_id: UInt64  # Logical page ID of new sibling
    var next: UnsafePointer[SplitDelta]

    fn __init__(out self, split_key: Int64, sibling_page_id: UInt64):
        """Create new split delta.

        Args:
            split_key: Separator key (keys >= this go to sibling).
            sibling_page_id: Logical page ID of new sibling node.
        """
        self.split_key = split_key
        self.sibling_page_id = sibling_page_id
        self.next = UnsafePointer[SplitDelta]()

    fn __init__(out self, split_key: Int64, sibling_page_id: UInt64, next: UnsafePointer[SplitDelta]):
        """Create new split delta linked to existing chain.

        Args:
            split_key: Separator key.
            sibling_page_id: Logical page ID of sibling.
            next: Pointer to next delta/node in chain.
        """
        self.split_key = split_key
        self.sibling_page_id = sibling_page_id
        self.next = next


struct MergeDelta:
    """Delta record for node merge operation.

    When a node becomes too sparse, a merge delta indicates it has been
    merged with a sibling. Subsequent operations should redirect to the
    merged node.
    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var merged_into_page_id: UInt64  # Logical page ID of merged target
    var next: UnsafePointer[MergeDelta]

    fn __init__(out self, merged_into_page_id: UInt64):
        """Create new merge delta.

        Args:
            merged_into_page_id: Logical page ID of node this merged into.
        """
        self.merged_into_page_id = merged_into_page_id
        self.next = UnsafePointer[MergeDelta]()

    fn __init__(out self, merged_into_page_id: UInt64, next: UnsafePointer[MergeDelta]):
        """Create new merge delta linked to existing chain.

        Args:
            merged_into_page_id: Target of merge.
            next: Pointer to next delta/node in chain.
        """
        self.merged_into_page_id = merged_into_page_id
        self.next = next


struct DeltaChain:
    """Helper for working with heterogeneous delta chains.

    Delta chains contain mixed types (InsertDelta, DeleteDelta, etc.)
    stored as type-erased pointers with a type tag.
    """

    alias INSERT = 1
    alias DELETE = 2
    alias SPLIT = 3
    alias MERGE = 4

    var delta_type: Int8
    var delta_ptr: UInt64  # Type-erased pointer to delta record

    fn __init__(out self, delta_type: Int8, delta_ptr: UInt64):
        """Create delta chain node with type tag.

        Args:
            delta_type: Type of delta (INSERT, DELETE, SPLIT, MERGE).
            delta_ptr: Pointer to delta record (type-erased to UInt64).
        """
        self.delta_type = delta_type
        self.delta_ptr = delta_ptr

    @staticmethod
    fn from_insert(delta: UnsafePointer[InsertDelta]) -> DeltaChain:
        """Create chain node from InsertDelta.

        Args:
            delta: Pointer to InsertDelta.

        Returns:
            Tagged delta chain node.
        """
        return DeltaChain(DeltaChain.INSERT, UInt64(int(delta)))

    @staticmethod
    fn from_delete(delta: UnsafePointer[DeleteDelta]) -> DeltaChain:
        """Create chain node from DeleteDelta.

        Args:
            delta: Pointer to DeleteDelta.

        Returns:
            Tagged delta chain node.
        """
        return DeltaChain(DeltaChain.DELETE, UInt64(int(delta)))

    @staticmethod
    fn from_split(delta: UnsafePointer[SplitDelta]) -> DeltaChain:
        """Create chain node from SplitDelta.

        Args:
            delta: Pointer to SplitDelta.

        Returns:
            Tagged delta chain node.
        """
        return DeltaChain(DeltaChain.SPLIT, UInt64(int(delta)))

    @staticmethod
    fn from_merge(delta: UnsafePointer[MergeDelta]) -> DeltaChain:
        """Create chain node from MergeDelta.

        Args:
            delta: Pointer to MergeDelta.

        Returns:
            Tagged delta chain node.
        """
        return DeltaChain(DeltaChain.MERGE, UInt64(int(delta)))

    fn as_insert(self) -> UnsafePointer[InsertDelta]:
        """Cast to InsertDelta pointer.

        Returns:
            Pointer to InsertDelta (caller must ensure type is correct).
        """
        return UnsafePointer[InsertDelta](Int(self.delta_ptr))

    fn as_delete(self) -> UnsafePointer[DeleteDelta]:
        """Cast to DeleteDelta pointer.

        Returns:
            Pointer to DeleteDelta (caller must ensure type is correct).
        """
        return UnsafePointer[DeleteDelta](Int(self.delta_ptr))

    fn as_split(self) -> UnsafePointer[SplitDelta]:
        """Cast to SplitDelta pointer.

        Returns:
            Pointer to SplitDelta (caller must ensure type is correct).
        """
        return UnsafePointer[SplitDelta](Int(self.delta_ptr))

    fn as_merge(self) -> UnsafePointer[MergeDelta]:
        """Cast to MergeDelta pointer.

        Returns:
            Pointer to MergeDelta (caller must ensure type is correct).
        """
        return UnsafePointer[MergeDelta](Int(self.delta_ptr))
