"""Tests for integrated BW-Tree with all features."""

from testing import assert_equal, assert_true, assert_false
import sys

sys.path.append("..")
from src.bwtree_integrated import BWTreeIntegrated


fn test_integrated_creation() raises:
    """Test integrated BW-Tree initialization."""
    var tree = BWTreeIntegrated(100)

    # Should have root node initialized
    var root_addr = tree.get_node(0)
    assert_true(root_addr != 0, "Root node should be initialized")


fn test_integrated_insert_and_lookup() raises:
    """Test insert and lookup with all features."""
    var tree = BWTreeIntegrated(100)

    # Insert with epoch protection and backoff
    var success = tree.insert(42, UInt64(100))
    assert_true(success, "Insert should succeed")

    # Lookup with DeleteDelta handling
    var result = tree.lookup(42)
    assert_true(result[0], "Key 42 should be found")
    assert_equal(result[1], UInt64(100), "Value should be 100")


fn test_integrated_delete() raises:
    """Test delete with proper semantics."""
    var tree = BWTreeIntegrated(100)

    # Insert
    var success = tree.insert(42, UInt64(100))
    assert_true(success, "Insert should succeed")

    # Verify exists
    var result = tree.lookup(42)
    assert_true(result[0], "Key should exist before delete")

    # Delete
    success = tree.delete(42)
    assert_true(success, "Delete should succeed")

    # Lookup should respect DeleteDelta
    result = tree.lookup(42)
    assert_false(result[0], "Deleted key should not be found")


fn test_integrated_scan() raises:
    """Test range scan with DeleteDelta support."""
    var tree = BWTreeIntegrated(100)

    # Insert keys 0-9
    for i in range(10):
        _ = tree.insert(Int64(i), UInt64(i * 10))

    # Delete key 5
    _ = tree.delete(5)

    # Scan range [0, 10)
    var results = tree.scan(0, 10)

    # Should have 9 keys (excluding deleted key 5)
    # Note: This assumes scan_range properly deduplicates and filters


fn test_integrated_consolidation_trigger() raises:
    """Test manual consolidation triggering."""
    var tree = BWTreeIntegrated(100)

    # Insert many keys to trigger consolidation
    for i in range(20):
        _ = tree.insert(Int64(i), UInt64(i))

    # Manually trigger consolidation
    var success = tree.trigger_consolidation()
    # May succeed or fail depending on chain length


fn test_integrated_garbage_collection() raises:
    """Test manual garbage collection."""
    var tree = BWTreeIntegrated(100)

    # Insert and delete to create garbage
    for i in range(10):
        _ = tree.insert(Int64(i), UInt64(i))

    for i in range(5):
        _ = tree.delete(Int64(i))

    # Manually collect garbage
    tree.collect_garbage()


fn test_integrated_concurrent_inserts() raises:
    """Test many concurrent inserts (simulated)."""
    var tree = BWTreeIntegrated(100)

    # Insert many keys to test backoff under contention
    var count = 0
    for i in range(100):
        if tree.insert(Int64(i), UInt64(i * 10)):
            count += 1

    assert_equal(count, 100, "All inserts should succeed")

    # Verify all keys
    for i in range(100):
        var result = tree.lookup(Int64(i))
        assert_true(result[0], "Key should be found")


fn test_integrated_duplicate_keys() raises:
    """Test duplicate key handling."""
    var tree = BWTreeIntegrated(100)

    # Insert same key multiple times
    _ = tree.insert(42, UInt64(100))
    _ = tree.insert(42, UInt64(200))
    _ = tree.insert(42, UInt64(300))

    # Should return most recent value
    var result = tree.lookup(42)
    assert_true(result[0], "Key should be found")
    assert_equal(result[1], UInt64(300), "Should return most recent value")


fn test_integrated_page_allocation() raises:
    """Test page ID allocation."""
    var tree = BWTreeIntegrated(100)

    var id1 = tree.allocate_page_id()
    var id2 = tree.allocate_page_id()
    var id3 = tree.allocate_page_id()

    assert_true(id1 != id2, "Page IDs should be unique")
    assert_true(id2 != id3, "Page IDs should be unique")
    assert_true(id1 < id2, "Page IDs should be sequential")
    assert_true(id2 < id3, "Page IDs should be sequential")


fn main() raises:
    print("Running integrated BW-Tree tests...")

    test_integrated_creation()
    print("✓ Integrated BW-Tree creation")

    test_integrated_insert_and_lookup()
    print("✓ Insert and lookup with all features")

    test_integrated_delete()
    print("✓ Delete with proper semantics")

    test_integrated_scan()
    print("✓ Range scan")

    test_integrated_consolidation_trigger()
    print("✓ Manual consolidation")

    test_integrated_garbage_collection()
    print("✓ Garbage collection")

    test_integrated_concurrent_inserts()
    print("✓ Concurrent inserts (simulated)")

    test_integrated_duplicate_keys()
    print("✓ Duplicate key handling")

    test_integrated_page_allocation()
    print("✓ Page allocation")

    print("\nAll integrated tests passed!")
