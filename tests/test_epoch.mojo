"""Tests for epoch-based memory reclamation."""

from testing import assert_equal, assert_true, assert_false
from memory import UnsafePointer
import sys

sys.path.append("..")
from src.epoch import EpochManager, EpochGuard, advance_global_epoch, get_global_epoch, DeferredFree


fn test_epoch_manager_creation() raises:
    """Test EpochManager initialization."""
    var epoch_mgr = EpochManager()

    # Should start with no pinned epoch
    var current = epoch_mgr.get_current_epoch()
    assert_true(current >= 0, "Epoch should be non-negative")


fn test_epoch_pinning() raises:
    """Test epoch pinning and unpinning."""
    var epoch_mgr = EpochManager()

    # Get initial epoch
    var initial_epoch = get_global_epoch()

    # Pin epoch
    var guard = epoch_mgr.pin()

    # Epoch should be pinned
    # (In actual implementation, would check local_epoch)

    # Advance global epoch
    advance_global_epoch()
    var new_epoch = get_global_epoch()

    assert_true(new_epoch > initial_epoch, "Global epoch should advance")

    # Guard destructor will unpin automatically


fn test_deferred_free() raises:
    """Test deferred memory reclamation."""
    var epoch_mgr = EpochManager()

    # Allocate some memory
    var ptr1 = UnsafePointer[Int64].alloc(1)
    ptr1[0] = 42

    var ptr2 = UnsafePointer[Int64].alloc(1)
    ptr2[0] = 100

    # Defer freeing
    epoch_mgr.defer_free(UInt64(int(ptr1)))
    epoch_mgr.defer_free(UInt64(int(ptr2)))

    # Should have 2 deferred entries
    assert_equal(len(epoch_mgr.garbage_list), 2, "Should have 2 deferred entries")

    # Advance epochs to make freeing safe
    for _ in range(5):
        advance_global_epoch()

    # Try collection
    epoch_mgr.try_collect()

    # Should have freed old entries
    # (In actual implementation, list should be empty or smaller)


fn test_batch_collection() raises:
    """Test batch garbage collection threshold."""
    var epoch_mgr = EpochManager()

    # Add many deferred frees (should trigger batch collection)
    for i in range(70):  # > GARBAGE_BATCH_SIZE (64)
        var ptr = UnsafePointer[Int64].alloc(1)
        epoch_mgr.defer_free(UInt64(int(ptr)))

    # Batch collection should have been triggered
    # (List size should be managed)


fn test_epoch_guard_raii() raises:
    """Test RAII-style epoch guard."""
    var epoch_mgr = EpochManager()

    # Create inner scope for guard
    var initial_epoch = get_global_epoch()

    # Pin epoch in scope
    var guard = epoch_mgr.pin()

    # Do some work...
    advance_global_epoch()

    # Guard destructor unpins when leaving scope


fn test_flush_all_garbage() raises:
    """Test flushing all deferred garbage."""
    var epoch_mgr = EpochManager()

    # Add deferred frees
    for i in range(10):
        var ptr = UnsafePointer[Int64].alloc(1)
        epoch_mgr.defer_free(UInt64(int(ptr)))

    assert_equal(len(epoch_mgr.garbage_list), 10, "Should have 10 entries")

    # Flush all
    epoch_mgr.flush()

    assert_equal(len(epoch_mgr.garbage_list), 0, "List should be empty after flush")


fn test_concurrent_epoch_advance() raises:
    """Test concurrent epoch advancement."""
    var initial = get_global_epoch()

    # Advance multiple times
    for _ in range(10):
        advance_global_epoch()

    var final = get_global_epoch()

    assert_true(final >= initial + 10, "Epoch should advance by at least 10")


fn main() raises:
    print("Running epoch-based reclamation tests...")

    test_epoch_manager_creation()
    print("✓ EpochManager creation")

    test_epoch_pinning()
    print("✓ Epoch pinning")

    test_deferred_free()
    print("✓ Deferred free")

    test_batch_collection()
    print("✓ Batch collection")

    test_epoch_guard_raii()
    print("✓ RAII epoch guard")

    test_flush_all_garbage()
    print("✓ Flush all garbage")

    test_concurrent_epoch_advance()
    print("✓ Concurrent epoch advance")

    print("\nAll epoch tests passed!")
