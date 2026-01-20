---
name: rust-performance-optimization
description: Performance measurement, profiling, and optimization techniques for Rust. Use when code is slow, benchmarking changes, profiling CPU or memory usage, optimizing hot paths, or preparing for production load.
---

# Rust Performance Optimization

This guide covers performance measurement, profiling, and optimization techniques for Rust applications. It provides practical tools and frameworks for identifying bottlenecks, benchmarking changes, and optimizing critical code paths.

## 1. When to Optimize

### Premature Optimization Warning

Performance optimization should follow measurement, not intuition. Donald Knuth's famous quote applies directly to Rust:

> "Premature optimization is the root of all evil (or at least most of it) in programming."

**Do not optimize until:**
1. You have working, correct code
2. You have measured actual performance
3. You have identified specific bottlenecks
4. The bottleneck matters for your use case

### Measure First, Optimize Second

```
                         ┌─────────────────────────────┐
                         │     "My code is slow"       │
                         └──────────────┬──────────────┘
                                        │
                                        v
                         ┌─────────────────────────────┐
                         │   Profile to find hotspot   │
                         └──────────────┬──────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    v                   v                   v
            ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
            │  CPU bound    │   │ Memory bound  │   │   I/O bound   │
            │  (flamegraph) │   │    (DHAT)     │   │  (async/par)  │
            └───────────────┘   └───────────────┘   └───────────────┘
```

### Hot Path Identification

Hot paths are code sections executed frequently or in performance-critical contexts:

- Request handlers in web servers
- Inner loops in data processing
- Serialization/deserialization
- Database query construction
- Cryptographic operations

**Identify hot paths by:**
1. CPU profiling (flamegraph/samply) - shows where time is spent
2. Execution counters - shows what runs most often
3. User-facing latency requirements - shows what must be fast

```rust
// Example: Identifying hot path candidates
fn process_request(req: Request) -> Response {
    let parsed = parse_json(&req.body);      // Called every request - HOT
    let validated = validate(&parsed);        // Called every request - HOT
    let result = business_logic(&validated);  // Called every request - HOT
    serialize_response(&result)               // Called every request - HOT
}

fn initialize_config() -> Config {
    // Called once at startup - NOT hot, don't optimize prematurely
    load_from_file("config.toml")
}
```

## 2. Benchmarking with Criterion

Criterion is the de facto standard for Rust benchmarking. It provides statistical analysis, regression detection, and HTML reports.

### Setup

**Cargo.toml:**
```toml
[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }

[[bench]]
name = "my_benchmark"
harness = false
```

**Benchmark file structure** (`benches/my_benchmark.rs`):
```rust
use criterion::{criterion_group, criterion_main, Criterion};

fn my_benchmarks(c: &mut Criterion) {
    // Benchmarks go here
}

criterion_group!(benches, my_benchmarks);
criterion_main!(benches);
```

### Basic Benchmarks

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 | 1 => n,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

fn bench_fibonacci(c: &mut Criterion) {
    // Simple benchmark with black_box
    c.bench_function("fib 20", |b| {
        b.iter(|| fibonacci(black_box(20)))
    });
}

criterion_group!(benches, bench_fibonacci);
criterion_main!(benches);
```

**Why `black_box` is essential:**

`black_box()` prevents the compiler from optimizing away computations. Without it, the compiler might:
- Precompute constant expressions at compile time
- Eliminate dead code if results aren't used
- Inline and simplify expressions

```rust
// BAD: Compiler may precompute result
b.iter(|| fibonacci(20));

// GOOD: Input hidden from optimizer
b.iter(|| fibonacci(black_box(20)));

// GOOD: Output hidden from optimizer
b.iter(|| black_box(fibonacci(20)));
```

### Parameterized Benchmarks

Use `BenchmarkGroup` and `BenchmarkId` for parameterized benchmarks:

```rust
use criterion::{
    black_box, criterion_group, criterion_main,
    BenchmarkId, Criterion, Throughput,
};

fn bench_fibonacci_sizes(c: &mut Criterion) {
    let mut group = c.benchmark_group("Fibonacci");
    
    for n in [10, 15, 20, 25] {
        group.bench_with_input(
            BenchmarkId::from_parameter(n),
            &n,
            |b, &n| {
                b.iter(|| fibonacci(black_box(n)))
            },
        );
    }
    group.finish();
}

fn bench_sorting_throughput(c: &mut Criterion) {
    let mut group = c.benchmark_group("Sorting");
    
    for size in [100, 1000, 10000] {
        // Set throughput for bytes/sec calculation
        group.throughput(Throughput::Elements(size as u64));
        
        group.bench_with_input(
            BenchmarkId::new("vec_sort", size),
            &size,
            |b, &size| {
                b.iter_batched(
                    || (0..size).rev().collect::<Vec<_>>(),
                    |mut v| v.sort(),
                    criterion::BatchSize::SmallInput,
                );
            },
        );
    }
    group.finish();
}

criterion_group!(benches, bench_fibonacci_sizes, bench_sorting_throughput);
criterion_main!(benches);
```

### Comparing Implementations

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn linear_search(haystack: &[i32], needle: i32) -> Option<usize> {
    haystack.iter().position(|&x| x == needle)
}

fn binary_search(haystack: &[i32], needle: i32) -> Option<usize> {
    haystack.binary_search(&needle).ok()
}

fn bench_search_comparison(c: &mut Criterion) {
    let data: Vec<i32> = (0..10000).collect();
    let needle = 5000;
    
    let mut group = c.benchmark_group("Search");
    
    group.bench_function("linear", |b| {
        b.iter(|| linear_search(black_box(&data), black_box(needle)))
    });
    
    group.bench_function("binary", |b| {
        b.iter(|| binary_search(black_box(&data), black_box(needle)))
    });
    
    group.finish();
}

criterion_group!(benches, bench_search_comparison);
criterion_main!(benches);
```

**Save and compare baselines:**
```bash
# Save baseline on main branch
cargo bench -- --save-baseline main

# Switch to feature branch and compare
git checkout feature-branch
cargo bench -- --baseline main
```

### Statistical Analysis

Criterion output explained:

```
Fibonacci/20            time:   [24.112 us 24.234 us 24.369 us]
                        change: [-1.2345% +0.1234% +1.5678%] (p = 0.12 > 0.05)
                        No change in performance detected.
Found 2 outliers among 100 measurements (2.00%)
  1 (1.00%) high mild
  1 (1.00%) high severe
```

- **time:** [lower bound, estimate, upper bound] - 95% confidence interval
- **change:** Percentage change from baseline with confidence interval
- **p value:** Statistical significance (< 0.05 means significant change)
- **outliers:** Measurements outside normal distribution

### HTML Reports

After running `cargo bench`, find reports at:
```
target/criterion/report/index.html
```

Reports include:
- Performance over time graphs
- Statistical distribution plots
- Comparison charts between baseline and current
- Detailed per-benchmark analysis

## 3. Benchmarking with Divan

Divan offers simpler ergonomics with attribute-based benchmarks and better module organization.

### Setup

**Cargo.toml:**
```toml
[dev-dependencies]
divan = "0.1"

[[bench]]
name = "my_benchmark"
harness = false
```

### Attribute-Based Benchmarks

**Basic benchmark** (`benches/my_benchmark.rs`):
```rust
fn main() {
    divan::main();
}

fn fibonacci(n: u64) -> u64 {
    match n {
        0 | 1 => n,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

// Simple benchmark - returning value prevents dead code elimination
#[divan::bench]
fn fibonacci_20() -> u64 {
    fibonacci(20)
}

// Divan automatically handles black_box for return values
#[divan::bench]
fn fibonacci_25() -> u64 {
    fibonacci(25)
}
```

### Parameterized Benchmarks

```rust
fn main() {
    divan::main();
}

fn fibonacci(n: u64) -> u64 {
    match n {
        0 | 1 => n,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

// Parameterized with args attribute
#[divan::bench(args = [10, 15, 20, 25])]
fn fibonacci_n(n: u64) -> u64 {
    fibonacci(n)
}

// Multiple parameters
#[divan::bench(args = [100, 1000, 10000])]
fn sort_vec(len: usize) {
    let mut v: Vec<i32> = (0..len as i32).rev().collect();
    v.sort();
}
```

### Setup with Bencher

For benchmarks requiring setup that shouldn't be measured:

```rust
fn main() {
    divan::main();
}

// Using Bencher for setup
#[divan::bench]
fn sort_vec(bencher: divan::Bencher) {
    bencher
        .with_inputs(|| (0..1000).rev().collect::<Vec<i32>>())
        .bench_local_values(|mut v| v.sort());
}

// bench_local_values consumes input, creates fresh each iteration
// bench_local_refs borrows input, reuses across iterations
#[divan::bench]
fn search_vec(bencher: divan::Bencher) {
    bencher
        .with_inputs(|| {
            let v: Vec<i32> = (0..10000).collect();
            (v, 5000)
        })
        .bench_local_refs(|(v, needle)| v.binary_search(needle));
}
```

### Module Organization

Divan reflects module structure in output:

```rust
fn main() {
    divan::main();
}

mod sorting {
    #[divan::bench(args = [100, 1000, 10000])]
    fn quicksort(len: usize) {
        let mut v: Vec<i32> = (0..len as i32).rev().collect();
        v.sort_unstable();
    }
    
    #[divan::bench(args = [100, 1000, 10000])]
    fn stable_sort(len: usize) {
        let mut v: Vec<i32> = (0..len as i32).rev().collect();
        v.sort();
    }
}

mod searching {
    #[divan::bench]
    fn binary_search() -> Result<usize, usize> {
        let v: Vec<i32> = (0..10000).collect();
        v.binary_search(&5000)
    }
    
    #[divan::bench]
    fn linear_search() -> Option<usize> {
        let v: Vec<i32> = (0..10000).collect();
        v.iter().position(|&x| x == 5000)
    }
}
```

Output groups benchmarks by module:
```
sorting::quicksort
sorting::stable_sort
searching::binary_search
searching::linear_search
```

### Criterion vs Divan Comparison

| Feature | Criterion | Divan |
|---------|-----------|-------|
| API Style | Builder pattern | Attribute macros |
| Statistical Analysis | Comprehensive | Basic |
| HTML Reports | Yes | No |
| Regression Detection | Yes | Manual |
| Async Support | Yes | Limited |
| Allocation Counting | Via iai-callgrind | Built-in |
| CI Suitability | Good | Excellent |
| Learning Curve | Moderate | Low |
| Measurement Overhead | Higher | Lower |
| Module Organization | Manual | Automatic |

**When to use Criterion:**
- Detailed statistical analysis needed
- Historical tracking and regression detection
- HTML reports for stakeholders
- Async benchmark support required

**When to use Divan:**
- Quick iteration during development
- Simpler benchmarks with less boilerplate
- CI pipelines (lower timing noise)
- Module-organized benchmark suites

## 4. Benchmark Anti-Patterns

### Constant Folding Trap

**Problem:** Compiler precomputes results at compile time.

```rust
// BAD: Compiler may compute result at compile time
fn bench_bad(c: &mut Criterion) {
    c.bench_function("fib", |b| {
        b.iter(|| fibonacci(20))  // Result might be precomputed!
    });
}
```

**Fix:** Use `black_box` to hide values from the optimizer.

```rust
// GOOD: Input hidden from optimizer
fn bench_good(c: &mut Criterion) {
    c.bench_function("fib", |b| {
        b.iter(|| fibonacci(black_box(20)))
    });
}
```

### Unrealistic Cache Behavior

**Problem:** Same key every iteration gives 100% cache hit rate.

```rust
// BAD: Same key every iteration (always cached)
fn bench_bad(c: &mut Criterion) {
    let map: HashMap<u64, String> = (0..1000)
        .map(|i| (i, format!("value_{}", i)))
        .collect();
    
    c.bench_function("lookup", |b| {
        b.iter(|| map.get(&500))  // 100% cache hit rate
    });
}
```

**Fix:** Use realistic access patterns.

```rust
// GOOD: Realistic access pattern
fn bench_good(c: &mut Criterion) {
    let map: HashMap<u64, String> = (0..1000)
        .map(|i| (i, format!("value_{}", i)))
        .collect();
    let keys: Vec<u64> = (0..1000).collect();
    
    c.bench_function("lookup", |b| {
        let mut i = 0;
        b.iter(|| {
            let key = keys[i % keys.len()];
            i += 1;
            map.get(&black_box(key))
        })
    });
}
```

### Predictable Branches

**Problem:** Branch predictor achieves 100% accuracy with uniform data.

```rust
// BAD: Branch predictor has 100% accuracy
fn bench_bad(c: &mut Criterion) {
    let data: Vec<bool> = vec![true; 10000];  // All same!
    
    c.bench_function("filter", |b| {
        b.iter(|| data.iter().filter(|&&x| x).count())
    });
}
```

**Fix:** Use realistic branch distribution.

```rust
// GOOD: Realistic branch distribution
use rand::Rng;

fn bench_good(c: &mut Criterion) {
    let data: Vec<bool> = (0..10000)
        .map(|_| rand::thread_rng().gen())
        .collect();
    
    c.bench_function("filter", |b| {
        b.iter(|| black_box(&data).iter().filter(|&&x| x).count())
    });
}
```

### Measuring Setup, Not Work

**Problem:** Allocation cost included in benchmark.

```rust
// BAD: Measures allocation + sort
fn bench_bad(c: &mut Criterion) {
    c.bench_function("sort", |b| {
        b.iter(|| {
            let mut data: Vec<i32> = (0..10000).rev().collect();  // Setup
            data.sort();  // Actual work
        })
    });
}
```

**Fix:** Use `iter_batched` to separate setup.

```rust
// GOOD: Setup not measured
use criterion::BatchSize;

fn bench_good(c: &mut Criterion) {
    c.bench_function("sort", |b| {
        b.iter_batched(
            || (0i32..10000).rev().collect::<Vec<_>>(),  // Setup (not measured)
            |mut data| data.sort(),                       // Only this measured
            BatchSize::SmallInput,
        )
    });
}
```

### Best Practices Checklist

**Preventing dead code elimination:**
```rust
// Use black_box for inputs
b.iter(|| process(black_box(&input)));

// Use black_box for outputs
b.iter(|| black_box(compute()));

// Divan: return value (handled automatically)
#[divan::bench]
fn bench() -> u64 {
    compute()
}
```

**Warm up caches:**
```rust
// Criterion warms up automatically (default: 3 seconds)

// For manual benchmarks:
for _ in 0..100 {
    let _ = my_function();
}
let start = Instant::now();
// ... measure ...
```

**Isolate what you're measuring:**
```rust
// BAD: Measures allocation + computation
b.iter(|| {
    let data = generate_data();  // Allocation noise
    process(data)
});

// GOOD: Setup outside iteration
let data = generate_data();
b.iter(|| process(black_box(&data)));

// GOOD: Use iter_batched for consumed inputs
b.iter_batched(
    || generate_data(),
    |data| process(data),
    BatchSize::SmallInput,
);
```

**Use realistic data:**
```rust
// Generate representative test data
let test_cases: Vec<_> = (0..1000)
    .map(|_| generate_realistic_input())
    .collect();

b.iter(|| {
    for case in &test_cases {
        process(black_box(case));
    }
});
```

**Benchmark both hot and cold paths:**
```rust
// Cache-hot benchmark
let data = load_data();
for _ in 0..10 {
    process(&data);
}  // Warm cache
b.iter(|| process(&data));

// Cache-cold benchmark
b.iter(|| {
    std::hint::black_box(&data);  // Invalidate predictions
    process(&data)
});
```

## 5. CPU Profiling

### Flamegraph

Flamegraphs visualize where CPU time is spent.

**Installation:**
```bash
cargo install flamegraph
```

**Enable debug symbols for release builds** (Cargo.toml):
```toml
[profile.release]
debug = true  # Enable symbols for profiling
```

**Generate flamegraph:**
```bash
# Profile binary
cargo flamegraph --bin myapp -- --my-args

# Profile specific benchmark
cargo flamegraph --bench my_benchmark -- --bench "fib 20"

# Output: flamegraph.svg
```

**Reading flamegraphs:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                        main (100%)                                   │
├───────────────────────────────────┬─────────────────────────────────┤
│       process_data (60%)          │       send_response (40%)       │
├─────────────────┬─────────────────┼─────────────────┬───────────────┤
│ parse_json (30%)│ validate (30%)  │ serialize (25%) │ network (15%) │
├─────────────────┴─────────────────┴─────────────────┴───────────────┤
```

- **Width** = time spent (wider = more time)
- **Y-axis** = call stack depth (bottom = entry point, top = leaf functions)
- **Click** to zoom into specific functions
- **Look for** wide plateaus - these are optimization targets
- **Colors** are random, don't indicate anything

**Optimization targets:**
- Wide boxes at the top (leaf functions taking lots of time)
- Wide plateaus (functions that dominate execution)
- Unexpected functions (why is `malloc` so wide?)

### samply (Modern Alternative)

samply provides excellent profiling with Firefox Profiler integration.

```bash
cargo install samply

# Profile your application
samply record ./target/release/myapp

# Opens Firefox Profiler UI automatically
# Features:
# - Full symbol resolution
# - Call tree view
# - Timeline view
# - Stack chart
```

**Advantages over flamegraph:**
- Interactive web UI
- Timeline visualization
- Better symbol resolution on macOS
- Memory profiling integration

### Linux perf

Native Linux profiling with excellent accuracy:

```bash
# Record profile
perf record --call-graph dwarf ./target/release/myapp

# View report
perf report

# Generate flamegraph from perf data
perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg
```

### Release with Debug Symbols

**Profile configuration** for profiling release builds (Cargo.toml):

```toml
# Release with debug info for profiling
[profile.release]
debug = true

# Or create a dedicated profile
[profile.profiling]
inherits = "release"
debug = true
```

```bash
# Use profiling profile
cargo build --profile profiling
```

## 6. Memory Profiling

### DHAT Heap Profiling

DHAT tracks every allocation to find memory hotspots.

**Setup** (Cargo.toml):
```toml
[dependencies]
dhat = { version = "0.3", optional = true }

[features]
dhat-heap = ["dhat"]
```

**Integration** (src/main.rs):
```rust
#[cfg(feature = "dhat-heap")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

fn main() {
    #[cfg(feature = "dhat-heap")]
    let _profiler = dhat::Profiler::new_heap();
    
    // Your code here
    actual_main();
    
}  // Prints allocation stats on drop
```

**Run with profiling:**
```bash
cargo run --features dhat-heap
```

**Output shows:**
```
dhat: Total:     1,000 bytes in 100 blocks
dhat: At t-gmax: 500 bytes in 50 blocks
dhat: At t-end:  0 bytes in 0 blocks
dhat: The data has been written to dhat-heap.json
```

**Key metrics:**
- **Total bytes/blocks:** All allocations over program lifetime
- **At t-gmax:** Memory at peak heap usage
- **At t-end:** Memory still allocated at exit (potential leaks)

**Analyze with DHAT viewer:**
```bash
# Open in Firefox
firefox https://nnethercote.github.io/dh_view/dh_view.html
# Load dhat-heap.json
```

### Valgrind (massif)

Track heap usage over time:

```bash
valgrind --tool=massif ./target/release/myapp
ms_print massif.out.*

# Output shows heap usage timeline:
#     KB
# 1024^                                            #
#     |                                         @@@#
#     |                                      @@@   #
#     |                                  @@@@      #
#     |                              @@@           #
#     |                          @@@@              #
#     |                      @@@@                  #
#     |                  @@@@                      #
#     |              @@@@                          #
#     |         @@@@@                              #
#     |     @@@@                                   #
#     | @@@@                                       #
#   0 +----------------------------------------------->time
```

### heaptrack (Linux)

Excellent visualization for heap profiling:

```bash
# Record
heaptrack ./target/release/myapp

# Analyze with GUI
heaptrack_gui heaptrack.myapp.*.gz

# Features:
# - Flame graph of allocations
# - Timeline of memory usage
# - Allocation hotspots
# - Temporary vs persistent allocations
```

### Allocation Counting

Quick allocation site identification:

```bash
# Using DHAT
cargo run --features dhat-heap 2>&1 | grep "total:"

# Using custom allocator for counting
```

```rust
// Simple allocation counter
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};

static ALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);

struct CountingAllocator;

unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        ALLOC_COUNT.fetch_add(1, Ordering::Relaxed);
        System.alloc(layout)
    }
    
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        System.dealloc(ptr, layout)
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

fn main() {
    // Your code
    println!("Total allocations: {}", ALLOC_COUNT.load(Ordering::Relaxed));
}
```

## 7. Instruction-Level Profiling

### iai-callgrind

For reproducible benchmarks unaffected by system load:

**Setup** (Cargo.toml):
```toml
[dev-dependencies]
iai-callgrind = "0.14"

[[bench]]
name = "iai_bench"
harness = false
```

**Benchmark** (benches/iai_bench.rs):
```rust
use iai_callgrind::{library_benchmark, library_benchmark_group, main};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 | 1 => n,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

#[library_benchmark]
fn bench_fibonacci() -> u64 {
    fibonacci(20)
}

#[library_benchmark]
#[bench::small(10)]
#[bench::medium(20)]
#[bench::large(30)]
fn bench_fib_sizes(n: u64) -> u64 {
    fibonacci(n)
}

library_benchmark_group!(
    name = fibonacci_group;
    benchmarks = bench_fibonacci, bench_fib_sizes
);

main!(library_benchmark_groups = fibonacci_group);
```

**Run:**
```bash
cargo bench --bench iai_bench
```

**Output:**
```
bench_fibonacci
  Instructions:     12,345 (+0.00%)
  L1 Hits:          10,000 (+0.00%)
  L2 Hits:             500 (+0.00%)
  RAM Hits:            100 (+0.00%)
  Estimated Cycles: 15,000 (+0.00%)
```

**Advantages:**
- Deterministic results (instruction counts don't vary)
- CI-friendly (no timing noise)
- Cache behavior analysis included

### Cachegrind

Detailed cache behavior analysis:

```bash
valgrind --tool=cachegrind ./target/release/myapp

# Output summary:
# I   refs:      1,234,567
# I1  misses:        1,234
# LLi misses:          123
# D   refs:        567,890
# D1  misses:       12,345
# LLd misses:        1,234

# Annotate source with cache info
cg_annotate cachegrind.out.*
```

## 8. Optimization Techniques

### Algorithmic Improvements

The highest-impact optimizations are usually algorithmic:

| Before | After | Improvement |
|--------|-------|-------------|
| O(n^2) | O(n log n) | 100x for n=1000 |
| O(n) | O(log n) | 10x for n=1000 |
| O(n) | O(1) | 1000x for n=1000 |

```rust
// O(n^2) - nested loop lookup
fn find_pairs_slow(data: &[i32], target: i32) -> Vec<(i32, i32)> {
    let mut result = Vec::new();
    for &a in data {
        for &b in data {
            if a + b == target {
                result.push((a, b));
            }
        }
    }
    result
}

// O(n) - hash set lookup
use std::collections::HashSet;

fn find_pairs_fast(data: &[i32], target: i32) -> Vec<(i32, i32)> {
    let set: HashSet<_> = data.iter().copied().collect();
    let mut result = Vec::new();
    for &a in data {
        let b = target - a;
        if set.contains(&b) {
            result.push((a, b));
        }
    }
    result
}
```

### Data Structure Selection

See [rust-implementation-patterns.md](rust-implementation-patterns.md) for detailed data structure guidance.

Quick reference:
- **Vec** - Default choice, cache-friendly
- **HashMap** - O(1) lookup for > 100 elements
- **BTreeMap** - Sorted keys, cache-friendly for medium sizes
- **Vec<(K, V)>** - Best for < 20 elements

### Memory Layout

See [rust-implementation-patterns.md](rust-implementation-patterns.md) for memory layout optimization.

Quick wins:
- Order struct fields largest-to-smallest
- Box large enum variants
- Use `#[repr(C)]` only when needed for FFI

### Allocation Reduction

**Pre-allocation:**
```rust
// BAD: Multiple reallocations
let mut v = Vec::new();
for i in 0..10000 {
    v.push(i);
}

// GOOD: Single allocation
let mut v = Vec::with_capacity(10000);
for i in 0..10000 {
    v.push(i);
}
```

**Buffer reuse:**
```rust
// BAD: New allocation each iteration
for item in &items {
    let mut buffer = Vec::new();
    process_into(item, &mut buffer);
    send(buffer);
}

// GOOD: Reuse allocation
let mut buffer = Vec::new();
for item in &items {
    buffer.clear();  // Keeps capacity
    process_into(item, &mut buffer);
    send(&buffer);
}
```

**String building:**
```rust
// BAD: Multiple allocations
let s = format!("{} {} {}", a, b, c);

// GOOD: Pre-sized when building large strings
let mut s = String::with_capacity(estimated_size);
write!(s, "{} {} {}", a, b, c).unwrap();
```

### SIMD and Vectorization

Help the compiler auto-vectorize:

```rust
// Likely to vectorize
fn sum_slice(data: &[f32]) -> f32 {
    data.iter().sum()
}

// Explicit SIMD (nightly or with packed_simd)
#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

// Iterator patterns vectorize well
let squared: Vec<_> = data.iter().map(|x| x * x).collect();
```

### Inlining Hints

```rust
// Suggest inlining (compiler may ignore)
#[inline]
fn small_hot_function(x: i32) -> i32 {
    x + 1
}

// Force inlining (use sparingly)
#[inline(always)]
fn critical_hot_path(x: i32) -> i32 {
    x + 1
}

// Prevent inlining (for code size or debugging)
#[inline(never)]
fn cold_error_path() {
    panic!("error");
}
```

**When to use `#[inline]`:**
- Small functions called in hot loops
- Generic functions (helps cross-crate inlining)
- Functions in public library APIs (lets consumers inline)

**When to use `#[inline(always)]`:**
- Critical hot paths verified by profiling
- Functions that must be inlined for correctness (rare)

## 9. Profile-Guided Optimization (PGO)

PGO uses runtime profiling data to optimize hot paths. Typically provides 10-20% improvement.

### Three-Step Process

**Step 1: Build instrumented binary**
```bash
RUSTFLAGS="-Cprofile-generate=/tmp/pgo-data" cargo build --release
```

**Step 2: Run representative workload**
```bash
# Run with typical inputs - multiple runs build better profiles
./target/release/my_binary --typical-args
./target/release/my_binary --other-typical-args
./target/release/my_binary --edge-case-args

# For servers: run typical request patterns
# For CLI tools: run typical commands
```

**Step 3: Merge and build optimized binary**
```bash
# Merge profile data
llvm-profdata merge -o /tmp/pgo-data/merged.profdata /tmp/pgo-data

# Build optimized binary
RUSTFLAGS="-Cprofile-use=/tmp/pgo-data/merged.profdata" cargo build --release
```

### When PGO Helps

**Good candidates:**
- Complex control flow with hard-to-predict branches
- Large codebases where inlining decisions matter
- Long-running services with consistent workloads
- Compilers, interpreters, and similar tools

**Less benefit:**
- Simple, predictable code paths
- I/O-bound applications
- Applications with highly variable workloads

### BOLT Post-Link Optimization

BOLT (Binary Optimization and Layout Tool) can provide additional gains after PGO:

```bash
# Requires LLVM BOLT
llvm-bolt ./target/release/myapp \
  -o ./target/release/myapp.bolt \
  -data=perf.fdata \
  -reorder-blocks=cache+ \
  -reorder-functions=hfsort
```

## 10. Target-Specific Optimization

### target-cpu=native

Use all CPU features available on the build machine:

```bash
# Build optimized for current CPU
RUSTFLAGS="-C target-cpu=native" cargo build --release

# Check what features are enabled
rustc --print cfg -C target-cpu=native | grep target_feature
```

### Feature Detection

Runtime feature detection for portable binaries:

```rust
#[cfg(target_arch = "x86_64")]
fn process_data(data: &[f32]) -> f32 {
    if is_x86_feature_detected!("avx2") {
        unsafe { process_avx2(data) }
    } else if is_x86_feature_detected!("sse4.1") {
        unsafe { process_sse41(data) }
    } else {
        process_fallback(data)
    }
}
```

### Distribution Baselines

For distributing binaries, target reasonable baselines:

```bash
# x86-64-v2: ~2008 CPUs (SSE4.2, POPCNT)
RUSTFLAGS="-C target-cpu=x86-64-v2" cargo build --release

# x86-64-v3: ~2015 CPUs (AVX, AVX2, BMI1/2)
RUSTFLAGS="-C target-cpu=x86-64-v3" cargo build --release

# x86-64-v4: ~2017 CPUs (AVX-512)
RUSTFLAGS="-C target-cpu=x86-64-v4" cargo build --release
```

**Recommendation:** x86-64-v2 for broad compatibility, x86-64-v3 for performance-focused deployments.

## 11. CI Benchmarking

### GitHub Actions Workflow

```yaml
# .github/workflows/bench.yml
name: Benchmarks
on:
  push:
    branches: [main]
  pull_request:

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Run benchmarks
        run: cargo bench -- --noplot
        
      - name: Compare with main
        if: github.event_name == 'pull_request'
        run: |
          git fetch origin main
          git checkout origin/main
          cargo bench -- --save-baseline main --noplot
          git checkout -
          cargo bench -- --baseline main --noplot
```

### Continuous Benchmarking Services

**Bencher.dev:**
```yaml
# .github/workflows/bench.yml
name: Continuous Benchmarking
on: push

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      
      - uses: bencherdev/bencher@main
        with:
          bencher-api-token: ${{ secrets.BENCHER_API_TOKEN }}
          project: my-project
          testbed: ubuntu-latest
          adapter: rust_criterion
```

**Benefits:**
- Historical tracking over time
- Regression detection with statistical analysis
- Visual dashboards
- PR comments with comparison

## 12. Performance Decision Frameworks

### "Should I Use HashMap?"

```
Need key-value lookup?
│
├── No ──> Vec, array, or struct
│
└── Yes ──> How many entries?
    │
    ├── < 20 ──> Vec<(K, V)> with linear search
    │            - Better cache locality
    │            - Lower overhead
    │
    ├── 20-100 ──> Consider BTreeMap
    │              - Cache friendly
    │              - No hash computation
    │              - Sorted iteration
    │
    └── > 100 ──> HashMap
        │
        ├── Need sorted keys? ──> BTreeMap
        │
        ├── Untrusted input? ──> HashMap (SipHash default)
        │                        - DoS resistant
        │
        └── Trusted input? ──> FxHashMap / AHashMap
                               - 5-10x faster hashing
```

### "Should I Box This?"

```
Is it a recursive type?
│
├── Yes ──> Box required
│           enum List { Cons(T, Box<List<T>>), Nil }
│
└── No ──> Is it a trait object (dyn Trait)?
    │
    ├── Yes ──> Box<dyn Trait> required
    │           fn process(handler: Box<dyn Handler>)
    │
    └── No ──> Is it > 1KB and moved frequently?
        │
        ├── Yes ──> Consider Box
        │           - Reduces stack usage
        │           - Makes moves cheap (pointer copy)
        │
        └── No ──> Don't Box
                   - Unnecessary indirection
                   - Extra allocation
                   - Worse cache behavior
```

### "Should I Use Rc/Arc?"

```
Do multiple owners exist simultaneously?
│
├── No ──> Use ownership or borrowing
│          - Move semantics (default)
│          - References (&T, &mut T)
│
└── Yes ──> Single-threaded?
    │
    ├── Yes ──> Rc<T>
    │           - No atomic overhead
    │           - Clone increments counter
    │
    └── No ──> Arc<T>
        │
        └── Need interior mutation?
            │
            ├── No ──> Arc<T>
            │          - Immutable shared data
            │
            ├── Write-heavy ──> Arc<Mutex<T>>
            │                   - Exclusive lock
            │                   - Less reader contention
            │
            └── Read-heavy ──> Arc<RwLock<T>>
                               - Multiple readers
                               - Single writer
```

### Ultimate Performance Checklist

**Data Structures:**
- [ ] Using Vec unless something else is clearly better
- [ ] Collections pre-sized with `with_capacity()` when size known
- [ ] No unnecessary Box, Rc, Arc
- [ ] No Clone in hot loops
- [ ] Struct fields ordered largest-to-smallest
- [ ] Fast hasher (FxHash/AHash) for trusted HashMap keys
- [ ] Large enum variants boxed

**Memory:**
- [ ] No allocation in inner loops
- [ ] Buffers reused where possible
- [ ] Checked struct sizes with `size_of::<T>()`
- [ ] No `format!()` / `to_string()` in hot paths

**Iteration:**
- [ ] Using iterators, not index loops
- [ ] Operations chained before collecting
- [ ] Considered rayon for CPU-bound parallelism
- [ ] No unnecessary intermediate collections

**Strings:**
- [ ] Using `&str` in function parameters, not `&String`
- [ ] Pre-sized String with `with_capacity()` for building
- [ ] Using `Cow<str>` for conditional modification
- [ ] Using `write!` macro instead of format concatenation

**Validation:**
- [ ] Profiled with flamegraph/samply
- [ ] Benchmarked with Criterion/Divan
- [ ] Tested with realistic data sizes
- [ ] Compiled with `--release` and LTO

## 13. Quick Reference

### Profiling Commands Cheat Sheet

```bash
# === CPU Profiling ===

# Flamegraph (cross-platform)
cargo install flamegraph
cargo flamegraph --bin myapp
# Output: flamegraph.svg

# samply (macOS/Linux, modern)
cargo install samply
samply record ./target/release/myapp
# Opens Firefox Profiler

# Linux perf
perf record --call-graph dwarf ./target/release/myapp
perf report

# === Memory Profiling ===

# DHAT (Rust-native)
cargo run --features dhat-heap
# Output: dhat-heap.json

# Valgrind massif
valgrind --tool=massif ./target/release/myapp
ms_print massif.out.*

# heaptrack (Linux)
heaptrack ./target/release/myapp
heaptrack_gui heaptrack.myapp.*.gz

# === Cache Profiling ===

# Cachegrind
valgrind --tool=cachegrind ./target/release/myapp
cg_annotate cachegrind.out.*

# === Allocation Counting ===
cargo run --features dhat-heap 2>&1 | grep "total:"
```

### Optimization Checklist Summary

```
1. MEASURE FIRST
   └── Profile before optimizing
   
2. ALGORITHM
   └── O(n^2) -> O(n log n) -> O(n) -> O(1)
   
3. DATA STRUCTURES
   ├── Vec is usually right
   ├── HashMap for > 100 elements
   └── Avoid unnecessary indirection
   
4. ALLOCATIONS
   ├── Pre-allocate (with_capacity)
   ├── Reuse buffers
   └── Avoid allocations in loops
   
5. COMPILER HELP
   ├── --release
   ├── LTO
   └── target-cpu=native (if not distributing)
   
6. VALIDATE
   ├── Benchmark changes
   ├── Profile again
   └── Test with realistic data
```

### Build Profiles for Performance

**Cargo.toml:**
```toml
[profile.release]
lto = true           # Link-time optimization
codegen-units = 1    # Better optimization, slower compile
panic = "abort"      # Smaller binary, no unwinding

[profile.release-with-debug]
inherits = "release"
debug = true         # For profiling

[profile.bench]
inherits = "release"
debug = true         # Symbols in benchmarks
```

### Further Reading

- [rust-implementation-patterns.md](rust-implementation-patterns.md) - Data structures and memory layout
- [rust-project-setup.md](rust-project-setup.md) - Build configuration and profiles
- [The Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Criterion User Guide](https://bheisler.github.io/criterion.rs/book/)
- [Divan Documentation](https://docs.rs/divan/)
