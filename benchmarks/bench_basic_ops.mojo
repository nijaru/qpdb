"""Benchmarks for BW-Tree basic operations.

Measures throughput and performance characteristics of insert, lookup, and delete.
"""

from time import now
from memory import UnsafePointer
from random import random_ui64
import sys

sys.path.append("..")
from src.bwtree import BWTree
from src.search import binary_search_scalar, binary_search_simd


fn benchmark_inserts(num_ops: Int) -> Float64:
    """Benchmark insert throughput.

    Args:
        num_ops: Number of insert operations to perform.

    Returns:
        Operations per second.
    """
    var tree = BWTree(1024)

    var start = now()

    for i in range(num_ops):
        _ = tree.insert(Int64(i), UInt64(i * 100))

    var end = now()
    var elapsed_ns = Float64(end - start)
    var elapsed_s = elapsed_ns / 1_000_000_000.0

    return Float64(num_ops) / elapsed_s


fn benchmark_lookups(num_ops: Int, num_keys: Int) -> Float64:
    """Benchmark lookup throughput.

    Args:
        num_ops: Number of lookup operations to perform.
        num_keys: Number of keys to insert before lookups.

    Returns:
        Operations per second.
    """
    var tree = BWTree(1024)

    # Insert keys
    for i in range(num_keys):
        _ = tree.insert(Int64(i), UInt64(i * 100))

    # Benchmark lookups
    var start = now()

    for i in range(num_ops):
        var key = Int64(i % num_keys)
        _ = tree.lookup(key)

    var end = now()
    var elapsed_ns = Float64(end - start)
    var elapsed_s = elapsed_ns / 1_000_000_000.0

    return Float64(num_ops) / elapsed_s


fn benchmark_mixed_workload(num_ops: Int) -> Float64:
    """Benchmark mixed read/write workload (50/50).

    Args:
        num_ops: Number of operations to perform.

    Returns:
        Operations per second.
    """
    var tree = BWTree(1024)

    var start = now()

    for i in range(num_ops):
        if i % 2 == 0:
            # Insert
            _ = tree.insert(Int64(i), UInt64(i * 100))
        else:
            # Lookup
            var key = Int64(i // 2)
            _ = tree.lookup(key)

    var end = now()
    var elapsed_ns = Float64(end - start)
    var elapsed_s = elapsed_ns / 1_000_000_000.0

    return Float64(num_ops) / elapsed_s


fn benchmark_simd_vs_scalar(array_size: Int, num_searches: Int) -> (Float64, Float64):
    """Benchmark SIMD vs scalar binary search.

    Args:
        array_size: Size of sorted key array.
        num_searches: Number of search operations.

    Returns:
        Tuple of (scalar_ops_per_sec, simd_ops_per_sec).
    """
    # Create sorted array
    var keys = UnsafePointer[Int64].alloc(array_size)
    for i in range(array_size):
        keys[i] = Int64(i * 2)  # Even numbers

    # Benchmark scalar search
    var start = now()
    for i in range(num_searches):
        var search_key = Int64((i % array_size) * 2)
        _ = binary_search_scalar(keys, array_size, search_key)
    var end = now()
    var scalar_elapsed_ns = Float64(end - start)
    var scalar_elapsed_s = scalar_elapsed_ns / 1_000_000_000.0
    var scalar_ops_per_sec = Float64(num_searches) / scalar_elapsed_s

    # Benchmark SIMD search
    start = now()
    for i in range(num_searches):
        var search_key = Int64((i % array_size) * 2)
        _ = binary_search_simd(keys, array_size, search_key)
    end = now()
    var simd_elapsed_ns = Float64(end - start)
    var simd_elapsed_s = simd_elapsed_ns / 1_000_000_000.0
    var simd_ops_per_sec = Float64(num_searches) / simd_elapsed_s

    keys.free()

    return (scalar_ops_per_sec, simd_ops_per_sec)


fn format_ops_per_sec(ops: Float64) -> String:
    """Format operations per second with appropriate unit.

    Args:
        ops: Operations per second.

    Returns:
        Formatted string (e.g., "1.2M ops/sec").
    """
    if ops >= 1_000_000_000.0:
        return str(ops / 1_000_000_000.0) + "B ops/sec"
    elif ops >= 1_000_000.0:
        return str(ops / 1_000_000.0) + "M ops/sec"
    elif ops >= 1_000.0:
        return str(ops / 1_000.0) + "K ops/sec"
    else:
        return str(ops) + " ops/sec"


fn main() raises:
    print("=" * 60)
    print("BW-Tree Performance Benchmarks")
    print("=" * 60)

    # Benchmark insert throughput
    print("\n[1/4] Insert Throughput")
    var insert_ops = benchmark_inserts(10_000)
    print("  10K inserts: " + format_ops_per_sec(insert_ops))

    # Benchmark lookup throughput
    print("\n[2/4] Lookup Throughput")
    var lookup_ops = benchmark_lookups(100_000, 10_000)
    print("  100K lookups (10K keys): " + format_ops_per_sec(lookup_ops))

    # Benchmark mixed workload
    print("\n[3/4] Mixed Workload (50% read, 50% write)")
    var mixed_ops = benchmark_mixed_workload(10_000)
    print("  10K operations: " + format_ops_per_sec(mixed_ops))

    # Benchmark SIMD vs scalar search
    print("\n[4/4] SIMD Binary Search Speedup")
    var search_result = benchmark_simd_vs_scalar(1000, 100_000)
    var scalar_ops = search_result[0]
    var simd_ops = search_result[1]
    var speedup = simd_ops / scalar_ops

    print("  Scalar: " + format_ops_per_sec(scalar_ops))
    print("  SIMD:   " + format_ops_per_sec(simd_ops))
    print("  Speedup: " + str(speedup) + "x")

    print("\n" + "=" * 60)
    print("Benchmarks complete!")
    print("=" * 60)
