"""Tests for atomic operations in BW-Tree nodes."""

from os.atomic import Atomic, Consistency
from testing import assert_equal, assert_true


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
    assert_true(not success, "CAS should fail with wrong expected value")
    assert_equal(atom.load(), UInt64(100))  # Value unchanged
    assert_equal(expected, UInt64(100))  # Expected updated to current value


fn test_memory_ordering() raises:
    """Test different memory ordering semantics."""
    var atom = Atomic[DType.uint64](0)

    # Test load with different orderings
    var val = atom.load[ordering=Consistency.ACQUIRE]()
    assert_equal(val, UInt64(0))

    # Test sequential consistency (default)
    atom += UInt64(42)
    assert_equal(atom.load(), UInt64(42))


fn main() raises:
    test_atomic_cas()
    test_memory_ordering()
    print("All atomic tests passed!")
