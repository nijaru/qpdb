"""Exponential backoff for CAS retry loops.

Reduces contention and prevents livelock in heavily contended scenarios.
"""

from time import sleep
from random import random_ui64


struct ExponentialBackoff:
    """Exponential backoff strategy for CAS retries.

    Progressively increases wait time between retries to reduce
    contention on the atomic variable.

    Not ImplicitlyCopyable to prevent accidental copies.
    """

    var attempt: Int
    var min_delay_ns: Int  # Minimum delay in nanoseconds
    var max_delay_ns: Int  # Maximum delay in nanoseconds

    fn __init__(out self, min_delay_ns: Int = 1, max_delay_ns: Int = 1000000):
        """Initialize backoff strategy.

        Args:
            min_delay_ns: Minimum delay in nanoseconds (default: 1ns).
            max_delay_ns: Maximum delay in nanoseconds (default: 1ms).
        """
        self.attempt = 0
        self.min_delay_ns = min_delay_ns
        self.max_delay_ns = max_delay_ns

    fn reset(mut self):
        """Reset backoff to initial state."""
        self.attempt = 0

    fn backoff(mut self):
        """Perform exponential backoff delay.

        Sleeps for progressively longer durations on each call.
        Uses random jitter to avoid synchronized retries.
        """
        if self.attempt == 0:
            # First attempt - no delay
            self.attempt += 1
            return

        # Calculate delay: min_delay * 2^attempt, capped at max_delay
        var delay = self.min_delay_ns
        for _ in range(self.attempt):
            delay *= 2
            if delay >= self.max_delay_ns:
                delay = self.max_delay_ns
                break

        # Add random jitter (0-50% of delay)
        var jitter = Int(random_ui64(0, UInt64(delay // 2)))
        delay = delay + jitter

        # Sleep for calculated delay
        # Note: Mojo's sleep might be in microseconds, adjust accordingly
        if delay > 1000:  # If delay > 1us
            var delay_us = delay // 1000
            sleep(delay_us / 1_000_000.0)  # Convert to seconds

        self.attempt += 1

    fn should_retry(self, max_attempts: Int = 100) -> Bool:
        """Check if should continue retrying.

        Args:
            max_attempts: Maximum number of retry attempts.

        Returns:
            True if should retry, False if max attempts reached.
        """
        return self.attempt < max_attempts


@always_inline
fn spin_loop_hint():
    """Hint to CPU that we're in a spin loop.

    On x86, this emits a PAUSE instruction to reduce power
    consumption and improve performance during busy-wait.

    On ARM, this is a YIELD hint.
    """
    # In actual implementation, would use LLVM intrinsic or inline asm
    # For now, this is a no-op placeholder
    pass


fn cas_with_backoff[T: DType](
    atom: Atomic[T],
    mut expected: SIMD[T, 1],
    desired: SIMD[T, 1],
    max_retries: Int = 100
) -> Bool:
    """CAS with exponential backoff.

    Attempts compare-and-swap with exponential backoff on failure.

    Args:
        atom: Atomic variable to update.
        expected: Expected value (updated on failure).
        desired: Desired new value.
        max_retries: Maximum retry attempts.

    Returns:
        True if CAS succeeded, False if max retries exceeded.
    """
    var backoff = ExponentialBackoff()

    while backoff.should_retry(max_retries):
        if atom.compare_exchange(expected, desired):
            return True

        # CAS failed, backoff before retry
        backoff.backoff()

        # Reload expected value for next attempt
        expected = atom.load()

    return False


fn cas_with_spin[T: DType](
    atom: Atomic[T],
    mut expected: SIMD[T, 1],
    desired: SIMD[T, 1],
    max_spins: Int = 10,
    max_retries: Int = 100
) -> Bool:
    """CAS with spin loop then exponential backoff.

    First tries a tight spin loop (fast for low contention),
    then switches to exponential backoff (better for high contention).

    Args:
        atom: Atomic variable to update.
        expected: Expected value (updated on failure).
        desired: Desired new value.
        max_spins: Number of spin attempts before backoff.
        max_retries: Maximum total retry attempts.

    Returns:
        True if CAS succeeded, False if max retries exceeded.
    """
    # Phase 1: Tight spin loop (optimistic - low contention)
    for _ in range(max_spins):
        if atom.compare_exchange(expected, desired):
            return True

        spin_loop_hint()  # CPU hint for spin loop
        expected = atom.load()

    # Phase 2: Exponential backoff (pessimistic - high contention)
    var backoff = ExponentialBackoff()
    var remaining = max_retries - max_spins

    while backoff.should_retry(remaining):
        if atom.compare_exchange(expected, desired):
            return True

        backoff.backoff()
        expected = atom.load()

    return False


# Usage example:
#
# var atom = Atomic[DType.uint64](42)
# var expected = UInt64(42)
# var success = cas_with_backoff(atom, expected, UInt64(100))
#
# Or manually:
#
# var backoff = ExponentialBackoff()
# while backoff.should_retry():
#     var expected = atom.load()
#     if atom.compare_exchange(expected, new_value):
#         break
#     backoff.backoff()
