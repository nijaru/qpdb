"""Tests for exponential backoff."""

from testing import assert_equal, assert_true, assert_false
from os.atomic import Atomic
import sys

sys.path.append("..")
from src.backoff import ExponentialBackoff, cas_with_backoff, cas_with_spin


fn test_backoff_creation() raises:
    """Test ExponentialBackoff initialization."""
    var backoff = ExponentialBackoff()

    # Should start at attempt 0
    assert_true(backoff.should_retry(100), "Should allow retry initially")


fn test_backoff_progression() raises:
    """Test backoff delays increase exponentially."""
    var backoff = ExponentialBackoff()

    # First backoff (attempt 0 -> 1)
    backoff.backoff()
    assert_equal(backoff.attempt, 1, "Should be at attempt 1")

    # Second backoff (attempt 1 -> 2)
    backoff.backoff()
    assert_equal(backoff.attempt, 2, "Should be at attempt 2")

    # Third backoff
    backoff.backoff()
    assert_equal(backoff.attempt, 3, "Should be at attempt 3")


fn test_backoff_max_attempts() raises:
    """Test backoff respects max attempts."""
    var backoff = ExponentialBackoff()

    # Exhaust retries
    for _ in range(110):
        backoff.backoff()

    # Should not allow more retries
    assert_false(backoff.should_retry(100), "Should not retry after max attempts")


fn test_backoff_reset() raises:
    """Test backoff reset."""
    var backoff = ExponentialBackoff()

    # Do some backoffs
    backoff.backoff()
    backoff.backoff()
    backoff.backoff()

    assert_equal(backoff.attempt, 3, "Should be at attempt 3")

    # Reset
    backoff.reset()

    assert_equal(backoff.attempt, 0, "Should be reset to 0")


fn test_cas_with_backoff_success() raises:
    """Test CAS with backoff succeeds."""
    var atom = Atomic[DType.uint64](42)

    # Successful CAS
    var expected = UInt64(42)
    var success = cas_with_backoff(atom, expected, UInt64(100))

    assert_true(success, "CAS should succeed")
    assert_equal(atom.load(), UInt64(100), "Value should be updated")


fn test_cas_with_backoff_failure() raises:
    """Test CAS with backoff fails correctly."""
    var atom = Atomic[DType.uint64](42)

    # CAS with wrong expected value
    var expected = UInt64(999)
    var success = cas_with_backoff(atom, expected, UInt64(100), max_retries=5)

    assert_false(success, "CAS should fail")
    assert_equal(atom.load(), UInt64(42), "Value should be unchanged")


fn test_cas_with_spin() raises:
    """Test hybrid spin + backoff CAS."""
    var atom = Atomic[DType.uint64](42)

    # Successful CAS
    var expected = UInt64(42)
    var success = cas_with_spin(atom, expected, UInt64(200))

    assert_true(success, "CAS should succeed")
    assert_equal(atom.load(), UInt64(200), "Value should be updated")


fn test_backoff_custom_delays() raises:
    """Test custom min/max delays."""
    var backoff = ExponentialBackoff(min_delay_ns=10, max_delay_ns=100000)

    assert_equal(backoff.min_delay_ns, 10, "Min delay should be 10")
    assert_equal(backoff.max_delay_ns, 100000, "Max delay should be 100000")


fn test_multiple_backoff_instances() raises:
    """Test multiple independent backoff instances."""
    var backoff1 = ExponentialBackoff()
    var backoff2 = ExponentialBackoff()

    # Progress first backoff
    backoff1.backoff()
    backoff1.backoff()

    # Second should be independent
    assert_equal(backoff1.attempt, 2, "Backoff1 should be at 2")
    assert_equal(backoff2.attempt, 0, "Backoff2 should be at 0")


fn main() raises:
    print("Running exponential backoff tests...")

    test_backoff_creation()
    print("✓ Backoff creation")

    test_backoff_progression()
    print("✓ Backoff progression")

    test_backoff_max_attempts()
    print("✓ Max attempts")

    test_backoff_reset()
    print("✓ Backoff reset")

    test_cas_with_backoff_success()
    print("✓ CAS with backoff (success)")

    test_cas_with_backoff_failure()
    print("✓ CAS with backoff (failure)")

    test_cas_with_spin()
    print("✓ CAS with spin")

    test_backoff_custom_delays()
    print("✓ Custom delays")

    test_multiple_backoff_instances()
    print("✓ Multiple backoff instances")

    print("\nAll backoff tests passed!")
