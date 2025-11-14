"""Tests for atomic operations in BW-Tree nodes."""

from os.atomic import Atomic, Consistency
from testing import assert_equal, assert_true, assert_false
from memory import UnsafePointer, alloc

from src.node import Node, NodeHeader, NODE_BASE
from src.page_table import PageTable


fn test_atomic_cas() raises:
    """Test atomic compare-and-swap operations."""
    var atom = Atomic[DType.uint64](42)

    # Successful CAS
    var expected = UInt64(42)
    var success = atom.compare_exchange(expected, UInt64(100))
    assert_true(success, "CAS should succeed with correct expected value")
    assert_equal(atom.load(), UInt64(100))

    # Failed CAS
    expected = UInt64(42)  # Wrong expected value
    success = atom.compare_exchange(expected, UInt64(200))
    assert_false(success, "CAS should fail with wrong expected value")
    assert_equal(atom.load(), UInt64(100))  # Value unchanged
    assert_equal(expected, UInt64(100))  # Expected updated to current value


fn test_memory_ordering() raises:
    """Test different memory ordering semantics."""
    var atom = Atomic[DType.uint64](0)

    # Test ACQUIRE load
    var val = atom.load[ordering=Consistency.ACQUIRE]()
    assert_equal(val, UInt64(0))

    # Test RELEASE store
    var atom_ptr = UnsafePointer(to=atom.value)
    Atomic[DType.uint64].store[ordering=Consistency.RELEASE](atom_ptr, UInt64(42))
    assert_equal(atom.load[ordering=Consistency.ACQUIRE](), UInt64(42))

    # Test sequential consistency (default)
    atom += UInt64(10)
    assert_equal(atom.load(), UInt64(52))


fn test_node_cas() raises:
    """Test CAS operations on Node structure."""
    var node = Node()

    # Initial value should be 0 (null pointer)
    var current = node.get_header()
    assert_equal(current, UInt64(0), "Initial header should be null")

    # Allocate a NodeHeader
    var header_ptr = alloc[NodeHeader](1)
    header_ptr.init_pointee_move(NodeHeader(NODE_BASE))
    var header_addr = UInt64(Int(header_ptr))

    # CAS to install header
    var success = node.compare_and_swap(UInt64(0), header_addr)
    assert_true(success, "CAS should succeed installing header")
    assert_equal(node.get_header(), header_addr, "Header should be installed")

    # CAS with wrong expected value should fail
    success = node.compare_and_swap(UInt64(0), UInt64(999))
    assert_false(success, "CAS should fail with wrong expected value")
    assert_equal(node.get_header(), header_addr, "Header should be unchanged")

    # Cleanup
    header_ptr.free()


fn test_page_table() raises:
    """Test PageTable atomic operations."""
    var table = PageTable(10)

    # Initial values should be 0 (unmapped)
    assert_equal(table.get(0), UInt64(0), "Unmapped page should be 0")
    assert_equal(table.get(5), UInt64(0), "Unmapped page should be 0")

    # Set a mapping with RELEASE ordering
    table.set(0, UInt64(0x1000))
    assert_equal(table.get(0), UInt64(0x1000), "Page 0 should be mapped")

    # CAS update should succeed with correct expected value
    var success = table.update(0, UInt64(0x1000), UInt64(0x2000))
    assert_true(success, "CAS update should succeed")
    assert_equal(table.get(0), UInt64(0x2000), "Page 0 should be updated")

    # CAS update should fail with wrong expected value
    success = table.update(0, UInt64(0x1000), UInt64(0x3000))
    assert_false(success, "CAS update should fail with wrong expected")
    assert_equal(table.get(0), UInt64(0x2000), "Page 0 should be unchanged")


fn test_acquire_release_ordering() raises:
    """Test ACQUIRE/RELEASE ordering for delta chain publication.

    Simulates the pattern used for publishing delta nodes:
    1. Prepare delta node (all writes complete)
    2. Publish with RELEASE (makes writes visible)
    3. Read with ACQUIRE (sees all prior writes)
    """
    var atom = Atomic[DType.uint64](0)

    # Simulate preparing a delta node
    var delta_ptr = alloc[NodeHeader](1)
    delta_ptr.init_pointee_move(NodeHeader(NODE_BASE))
    var delta_addr = UInt64(Int(delta_ptr))

    # Publish delta with RELEASE ordering
    var atom_ptr2 = UnsafePointer(to=atom.value)
    Atomic[DType.uint64].store[ordering=Consistency.RELEASE](atom_ptr2, delta_addr)

    # Read delta with ACQUIRE ordering
    var read_addr = atom.load[ordering=Consistency.ACQUIRE]()
    assert_equal(read_addr, delta_addr, "ACQUIRE should see RELEASE store")

    # Verify we can dereference and see initialized data
    # TODO: Fix pointer conversion from UInt64
    # var retrieved_ptr = UnsafePointer[NodeHeader](...)
    # assert_equal(retrieved_ptr[].node_type, NODE_BASE, "Should see initialized node_type")

    # Cleanup
    delta_ptr.free()


fn main() raises:
    print("Running BW-Tree atomic operation tests...")

    test_atomic_cas()
    print("✓ Basic CAS operations")

    test_memory_ordering()
    print("✓ Memory ordering semantics")

    test_node_cas()
    print("✓ Node CAS operations")

    test_page_table()
    print("✓ PageTable atomic operations")

    test_acquire_release_ordering()
    print("✓ ACQUIRE/RELEASE ordering")

    print("\nAll atomic tests passed!")
