# Rust 1.70 → 1.92: Complete Developer Guide

> **Covering:** June 2023 (1.70.0) through December 2025 (1.92.0)  
> **Major Milestone:** Rust 2024 Edition (stabilized in 1.85.0)

This guide covers everything you need to know about changes to the Rust language, standard library, and tooling over the past ~2.5 years. It's organized to help you understand what's changed, what you should start doing differently, and what to watch out for.

---

## Table of Contents

1. [The Rust 2024 Edition](#the-rust-2024-edition)
2. [Language Features](#language-features)
3. [Standard Library](#standard-library)
4. [Compiler & Tooling](#compiler--tooling)
5. [Breaking Changes](#breaking-changes)
6. [Do's and Don'ts](#dos-and-donts)
7. [Migration Checklist](#migration-checklist)
8. [Quick Reference](#quick-reference)

---

## The Rust 2024 Edition

**Released:** February 2025 with Rust 1.85.0

The 2024 Edition is the largest Rust edition ever released. Editions allow opt-in breaking changes while maintaining backwards compatibility for existing code.

### How to Migrate

```bash
# Update your toolchain
rustup update stable

# Run the automatic migration
cargo fix --edition

# Update Cargo.toml
# Change: edition = "2021"
# To:     edition = "2024"
```

### Key 2024 Edition Changes

| Change | Impact | Action Required |
|--------|--------|-----------------|
| RPIT lifetime capture | `impl Trait` captures all in-scope lifetimes by default | Use `use<'a, T>` to be explicit |
| `unsafe extern` blocks | `extern` blocks now require `unsafe` keyword | Add `unsafe` to extern blocks |
| `if let` temporary scope | Temporaries in `if let` drop earlier | Review code relying on extended lifetimes |
| `let` chains | `if let ... && let ...` syntax now available | Can simplify nested conditionals |
| Unsafe attributes | Attributes like `#[no_mangle]` require `unsafe(...)` | Wrap in `#[unsafe(no_mangle)]` |
| Reserved syntax | `gen` keyword reserved for future generators | Rename any `gen` identifiers |
| Match ergonomics | Stricter rules for `&` in patterns | May need to adjust some patterns |
| Macro fragment changes | `expr` fragment excludes `const {}` blocks | Use `expr_2021` for old behavior |

### RPIT Lifetime Changes (Important!)

```rust
// 2021 Edition - captures only mentioned lifetimes
fn foo<'a>(x: &'a str, y: &str) -> impl Sized { x }
// Only captures 'a, not the lifetime of y

// 2024 Edition - captures ALL in-scope lifetimes
fn foo<'a>(x: &'a str, y: &str) -> impl Sized { x }
// Captures both lifetimes!

// To opt out in 2024, use explicit capture syntax:
fn foo<'a>(x: &'a str, y: &str) -> impl Sized + use<'a> { x }
```

### Temporary Lifetime Changes

```rust
// This pattern may behave differently in 2024:
if let Some(mutex_guard) = map.get(&key) {
    // In 2021: mutex_guard lives until end of if block
    // In 2024: may drop earlier in some cases
    use_guard(&mutex_guard);
}

// If you need extended lifetime, bind explicitly:
let guard = map.get(&key);
if let Some(g) = guard {
    use_guard(&g);
}
```

---

## Language Features

### Async Closures (1.85)

The long-awaited async closure syntax is here, filling a major gap in async Rust.

```rust
// NEW: Native async closures
let fetch_data = async |url: &str| {
    let response = client.get(url).await?;
    response.json().await
};

// They implement AsyncFn traits
async fn process<F>(f: F) 
where 
    F: AsyncFn(&str) -> Result<Data, Error>
{
    let data = f("https://api.example.com").await?;
}

// Can capture from environment
let client = reqwest::Client::new();
let fetcher = async |url| {
    client.get(url).send().await  // captures client
};
```

**Old workaround you can stop using:**
```rust
// OLD: Returning boxed futures from closures
let fetch: Box<dyn Fn(&str) -> Pin<Box<dyn Future<Output = Result<Data>>>>> = 
    Box::new(|url| Box::pin(async move { /* ... */ }));
```

### Let Chains (1.88 / 2024 Edition)

Flatten nested `if let` and boolean conditions:

```rust
// OLD: Deeply nested
if let Some(user) = get_user() {
    if user.is_active {
        if let Some(email) = user.email {
            if email.contains("@company.com") {
                send_internal_notification(&email);
            }
        }
    }
}

// NEW: Flat and readable
if let Some(user) = get_user()
    && user.is_active
    && let Some(email) = user.email
    && email.contains("@company.com")
{
    send_internal_notification(&email);
}

// Works in while loops too
while let Some(item) = iter.next()
    && item.is_valid()
    && let Ok(processed) = process(item)
{
    results.push(processed);
}
```

### C-String Literals (1.77)

Native syntax for null-terminated C strings:

```rust
use std::ffi::CStr;

// NEW: C-string literal syntax
let greeting: &'static CStr = c"Hello, World!";
let path: &CStr = c"/usr/local/bin";

// Raw C-strings (no escape processing)
let windows_path: &CStr = cr"C:\Users\name";
let regex: &CStr = cr"\d+\.\d+";

// Compile-time validation
// let bad = c"contains\0null";  // ERROR: interior null byte

// OLD: Manual and error-prone
let old_way = CStr::from_bytes_with_nul(b"Hello, World!\0").unwrap();
```

### Raw Pointer Creation with `&raw` (1.82)

Create raw pointers without creating intermediate references:

```rust
// NEW: Direct raw pointer creation
let value = 42;
let ptr: *const i32 = &raw const value;
let mut_ptr: *mut i32 = &raw mut value;

// Especially important for statics
static mut COUNTER: i32 = 0;

// OLD: Created a reference first (potential UB!)
let ptr = unsafe { &mut COUNTER as *mut i32 };

// NEW: No intermediate reference, actually safe!
let ptr = &raw mut COUNTER;  // Safe in 1.82+

// For union fields (safe in 1.92+)
union MyUnion {
    int: i32,
    float: f32,
}
let u = MyUnion { int: 42 };
let ptr = &raw const u.int;  // No unsafe needed!
```

### Trait Object Upcasting (1.86)

Coerce trait objects to their supertraits:

```rust
trait Animal {
    fn name(&self) -> &str;
}

trait Dog: Animal {
    fn bark(&self);
}

struct Labrador;
impl Animal for Labrador {
    fn name(&self) -> &str { "Buddy" }
}
impl Dog for Labrador {
    fn bark(&self) { println!("Woof!"); }
}

// NEW: Upcasting just works
fn use_as_animal(dog: &dyn Dog) {
    let animal: &dyn Animal = dog;  // Implicit coercion
    println!("Name: {}", animal.name());
}

fn boxed_upcast(dog: Box<dyn Dog>) -> Box<dyn Animal> {
    dog  // Just works!
}
```

### Naked Functions (1.88)

Full control over generated assembly:

```rust
use std::arch::naked_asm;

#[naked]
pub unsafe extern "C" fn custom_entry() -> ! {
    naked_asm!(
        "mov rdi, rsp",
        "call {main}",
        main = sym actual_main,
    )
}

// Useful for:
// - Custom calling conventions
// - Interrupt handlers
// - Boot code
// - Precise stack manipulation
```

### Inline Const Blocks (1.79)

Evaluate const expressions inline:

```rust
// NEW: Inline const for compile-time computation
fn process<T>() {
    let size = const { std::mem::size_of::<T>() };
    let buffer = [0u8; const { 1024 * std::mem::size_of::<T>() }];
    
    // Const assertions inline
    const { assert!(std::mem::size_of::<T>() <= 128) };
}

// Useful for generic contexts where you need const values
fn needs_const_generic<const N: usize>() { /* ... */ }

fn call_it<T>() {
    needs_const_generic::<{ std::mem::size_of::<T>() }>();
}
```

### Exclusive Range Patterns (1.80)

Use `..` (exclusive) in addition to `..=` (inclusive) in patterns:

```rust
fn categorize(n: i32) -> &'static str {
    match n {
        ..0 => "negative",           // Exclusive: n < 0
        0 => "zero",
        1..10 => "single digit",     // Exclusive: 1 <= n < 10
        10..=99 => "two digits",     // Inclusive: 10 <= n <= 99
        100.. => "three or more",    // Open end
    }
}
```

### Safe `#[target_feature]` Functions (1.86)

Mark safe functions with target feature requirements:

```rust
// NEW: Can be safe functions (not just unsafe)
#[target_feature(enable = "avx2")]
fn fast_sum(data: &[f32]) -> f32 {
    // Use AVX2 intrinsics safely
    // Caller must ensure AVX2 is available
    data.iter().sum()
}

// Calling still requires the feature to be enabled
fn main() {
    if is_x86_feature_detected!("avx2") {
        // Safe to call
        let result = fast_sum(&data);
    }
}
```

### `#[expect]` Lint Attribute (1.81)

Better alternative to `#[allow]` that notifies you when it's no longer needed:

```rust
// OLD: Silent suppression, easy to forget
#[allow(dead_code)]
fn might_be_used_later() { }
// No warning if the function IS used - attribute becomes stale

// NEW: Warns when expectation isn't met
#[expect(dead_code)]
fn might_be_used_later() { }
// If the function becomes used, you get a warning to remove the attribute

// With reason (also 1.81+)
#[expect(unused_variables, reason = "WIP: will use in next commit")]
let config = load_config();
```

### `#[diagnostic::do_not_recommend]` (1.85)

Help library authors provide better error messages:

```rust
// Library code
pub trait IntoString {
    fn into_string(self) -> String;
}

// This impl would normally show up in error messages,
// but it's just a fallback and confuses users
#[diagnostic::do_not_recommend]
impl<T: std::fmt::Display> IntoString for T {
    fn into_string(self) -> String {
        self.to_string()
    }
}

// Now when users see "doesn't implement IntoString",
// they won't be told to "implement Display" as the solution
```

### Const Generic Argument Inference (1.89)

Use `_` to infer const generic arguments:

```rust
// NEW: Infer const generics from context
let arr: [i32; _] = [1, 2, 3, 4, 5];  // Infers 5

fn repeat<T: Copy, const N: usize>(val: T) -> [T; N] {
    [val; N]
}

let fives: [i32; _] = repeat(5);  // Context determines N

// Works in turbofish too
let zeros = <[i32; _]>::default();  // Inferred from usage
```

### Assembly Improvements

**Const in asm! (1.82):**
```rust
use std::arch::asm;

const SYSCALL_WRITE: usize = 1;

unsafe {
    asm!(
        "mov rax, {num}",
        num = const SYSCALL_WRITE,  // Compile-time constant
    );
}
```

**asm_goto - Jump to Rust labels (1.87):**
```rust
use std::arch::asm;

unsafe {
    asm!(
        "test {0}, {0}",
        "jz {label}",
        in(reg) value,
        label = label {
            // Jump target is Rust code
            handle_zero();
        }
    );
}
```

### 128-bit Enum Representations (1.89)

```rust
#[repr(u128)]
enum LargeEnum {
    Small = 1,
    Large = 1 << 100,
    Max = u128::MAX,
}

#[repr(i128)]
enum SignedLarge {
    Min = i128::MIN,
    Zero = 0,
    Max = i128::MAX,
}
```

---

## Standard Library

### LazyCell and LazyLock (1.80)

Replace `lazy_static` and `once_cell` crates:

```rust
use std::sync::LazyLock;
use std::cell::LazyCell;

// Thread-safe lazy initialization (replaces lazy_static! / once_cell::sync::Lazy)
static CONFIG: LazyLock<Config> = LazyLock::new(|| {
    Config::load_from_file("config.toml").expect("Failed to load config")
});

static REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\d{4}-\d{2}-\d{2}").unwrap()
});

fn main() {
    // Initialized on first access
    println!("Loaded: {:?}", CONFIG.name);
}

// Single-threaded lazy (replaces once_cell::unsync::Lazy)
fn single_threaded() {
    let lazy: LazyCell<Vec<i32>> = LazyCell::new(|| {
        expensive_computation()
    });
    
    // Computed on first deref
    println!("{:?}", *lazy);
}
```

### Anonymous Pipes (1.87)

Cross-platform pipe creation:

```rust
use std::io::{self, Read, Write, pipe};
use std::process::{Command, Stdio};

fn main() -> io::Result<()> {
    // Create a pipe
    let (mut reader, mut writer) = pipe()?;
    
    // Use with subprocess
    let mut child = Command::new("cat")
        .stdin(Stdio::from(writer))
        .stdout(Stdio::piped())
        .spawn()?;
    
    // Write to child's stdin via the pipe
    // (in real code, do this in a separate thread)
    writeln!(writer, "Hello from parent!")?;
    drop(writer);  // Close write end
    
    // Read child's output
    let output = child.wait_with_output()?;
    println!("Child said: {}", String::from_utf8_lossy(&output.stdout));
    
    Ok(())
}
```

### File Locking (1.89)

Native file locking support:

```rust
use std::fs::File;
use std::io;

fn with_locked_file() -> io::Result<()> {
    let file = File::open("data.db")?;
    
    // Exclusive lock (blocks until acquired)
    file.lock()?;
    
    // Do exclusive work...
    modify_database(&file)?;
    
    // Explicit unlock (also happens on drop)
    file.unlock()?;
    
    // Shared lock (multiple readers allowed)
    file.lock_shared()?;
    
    // Non-blocking variants
    match file.try_lock() {
        Ok(()) => { /* Got the lock */ }
        Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
            println!("File is locked by another process");
        }
        Err(e) => return Err(e),
    }
    
    Ok(())
}
```

### get_disjoint_mut (1.86)

Safely get multiple mutable references from collections:

```rust
use std::collections::HashMap;

fn main() {
    // For slices
    let mut arr = [1, 2, 3, 4, 5];
    
    // Get mutable references to indices 0 and 3
    if let Ok([a, b]) = arr.get_disjoint_mut([0, 3]) {
        *a += 10;
        *b += 10;
    }
    // arr is now [11, 2, 3, 14, 5]
    
    // For HashMap
    let mut scores: HashMap<&str, i32> = HashMap::from([
        ("alice", 100),
        ("bob", 200),
        ("carol", 150),
    ]);
    
    if let Ok([alice, bob]) = scores.get_disjoint_mut(["alice", "bob"]) {
        // Swap scores
        std::mem::swap(alice, bob);
    }
    
    // Error handling
    match arr.get_disjoint_mut([0, 0]) {  // Same index twice!
        Ok(_) => unreachable!(),
        Err(e) => println!("Error: {:?}", e),  // GetDisjointMutError::Overlapping
    }
}
```

### extract_if (1.87 for Vec, 1.88 for HashMap)

Filter and drain in one operation:

```rust
use std::collections::HashMap;

fn main() {
    // Vec::extract_if
    let mut numbers = vec![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    
    // Remove and collect evens, keeping odds in original
    let evens: Vec<_> = numbers.extract_if(.., |n| *n % 2 == 0).collect();
    
    assert_eq!(numbers, vec![1, 3, 5, 7, 9]);
    assert_eq!(evens, vec![2, 4, 6, 8, 10]);
    
    // With range
    let mut v = vec![1, 2, 3, 4, 5];
    let extracted: Vec<_> = v.extract_if(1..4, |n| *n % 2 == 0).collect();
    // Only examines indices 1..4, extracts 2 and 4
    
    // HashMap::extract_if (1.88+)
    let mut map: HashMap<&str, i32> = HashMap::from([
        ("a", 1), ("b", 2), ("c", 3), ("d", 4),
    ]);
    
    let high: HashMap<_, _> = map.extract_if(|_, v| *v > 2).collect();
    // map now contains {"a": 1, "b": 2}
    // high contains {"c": 3, "d": 4}
}
```

### Vec::pop_if (1.86)

Conditionally pop the last element:

```rust
let mut stack = vec![1, 2, 3, 4, 5];

// Only pop if condition is met
let popped = stack.pop_if(|x| *x > 3);
assert_eq!(popped, Some(5));
assert_eq!(stack, [1, 2, 3, 4]);

let not_popped = stack.pop_if(|x| *x > 10);
assert_eq!(not_popped, None);
assert_eq!(stack, [1, 2, 3, 4]);  // Unchanged
```

### Option Enhancements

```rust
// Option::take_if (1.80)
let mut opt = Some(42);
let taken = opt.take_if(|x| *x > 40);  // Takes if predicate is true
assert_eq!(taken, Some(42));
assert_eq!(opt, None);

// Option::is_none_or (1.82)
let opt: Option<i32> = Some(5);
assert!(opt.is_none_or(|x| *x > 0));  // true: is Some and > 0

let none: Option<i32> = None;
assert!(none.is_none_or(|x| *x > 100));  // true: is None

// Option::get_or_insert_default (1.83)
let mut opt: Option<Vec<i32>> = None;
let vec = opt.get_or_insert_default();  // Inserts Vec::default()
vec.push(1);
```

### Result::flatten (1.89)

```rust
let nested: Result<Result<i32, &str>, &str> = Ok(Ok(42));
let flat: Result<i32, &str> = nested.flatten();
assert_eq!(flat, Ok(42));

let nested_err: Result<Result<i32, &str>, &str> = Ok(Err("inner"));
assert_eq!(nested_err.flatten(), Err("inner"));

let outer_err: Result<Result<i32, &str>, &str> = Err("outer");
assert_eq!(outer_err.flatten(), Err("outer"));
```

### Integer Square Root (1.84)

```rust
// Unsigned integers
let n: u64 = 100;
assert_eq!(n.isqrt(), 10);

let big: u128 = 10_000_000_000;
assert_eq!(big.isqrt(), 100_000);  // Exact, no float conversion!

// Signed integers (checked)
let signed: i32 = 100;
assert_eq!(signed.checked_isqrt(), Some(10));
assert_eq!((-100i32).checked_isqrt(), None);  // Negative

// NonZero variants
use std::num::NonZeroU32;
let nz = NonZeroU32::new(100).unwrap();
assert_eq!(nz.isqrt().get(), 10);
```

### Strict Provenance (1.84)

New pointer APIs for more precise control over pointer provenance:

```rust
// Create pointer without provenance (can't be dereferenced)
let fake_ptr: *const i32 = std::ptr::without_provenance(0x1000);

// Create pointer with exposed provenance
let real_value = 42i32;
let addr = (&real_value as *const i32).expose_provenance();
let recovered: *const i32 = std::ptr::with_exposed_provenance(addr);

// Get address without exposing provenance
let ptr = &real_value as *const i32;
let addr: usize = ptr.addr();

// Create new pointer with same provenance but different address
let offset_ptr = ptr.with_addr(addr + 4);

// Map address while preserving provenance
let mapped = ptr.map_addr(|a| a.wrapping_add(8));
```

### sync::Once::wait (1.86)

Wait for `Once` initialization without participating:

```rust
use std::sync::Once;
use std::thread;

static INIT: Once = Once::new();
static mut VALUE: Option<String> = None;

fn get_value() -> &'static str {
    // In worker threads: wait for initialization
    INIT.wait();  // Blocks until some thread calls call_once
    unsafe { VALUE.as_ref().unwrap() }
}

fn main() {
    // Spawn workers that need the value
    let handles: Vec<_> = (0..4).map(|_| {
        thread::spawn(|| {
            let val = get_value();
            println!("Got: {}", val);
        })
    }).collect();
    
    // Main thread initializes
    INIT.call_once(|| {
        unsafe { VALUE = Some(String::from("initialized")); }
    });
    
    for h in handles {
        h.join().unwrap();
    }
}
```

### Float Improvements

```rust
// next_up / next_down (1.86)
let x: f64 = 1.0;
assert!(x.next_up() > x);    // Smallest value greater than x
assert!(x.next_down() < x);  // Largest value less than x

// Useful for exclusive ranges with floats
let just_under_one = 1.0f64.next_down();

// midpoint (1.85)
let a = 1.0f64;
let b = 3.0f64;
assert_eq!(a.midpoint(b), 2.0);

// Works correctly even with extreme values (no overflow)
let large1 = f64::MAX / 2.0;
let large2 = f64::MAX;
let mid = large1.midpoint(large2);  // Doesn't overflow!
```

### Error Trait in core (1.81)

`std::error::Error` is now available in `#![no_std]`:

```rust
#![no_std]
extern crate alloc;

use core::error::Error;
use core::fmt;
use alloc::boxed::Box;

#[derive(Debug)]
struct MyError;

impl fmt::Display for MyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "my error")
    }
}

impl Error for MyError {}  // Now works in no_std!

fn fallible() -> Result<(), Box<dyn Error>> {
    Err(Box::new(MyError))
}
```

### New ErrorKind Variants (1.83, 1.85)

```rust
use std::io::ErrorKind;

fn handle_error(e: std::io::Error) {
    match e.kind() {
        // New in 1.83
        ErrorKind::HostUnreachable => { /* ... */ }
        ErrorKind::NetworkUnreachable => { /* ... */ }
        ErrorKind::NetworkDown => { /* ... */ }
        ErrorKind::NotADirectory => { /* ... */ }
        ErrorKind::IsADirectory => { /* ... */ }
        ErrorKind::DirectoryNotEmpty => { /* ... */ }
        ErrorKind::ReadOnlyFilesystem => { /* ... */ }
        ErrorKind::StaleNetworkFileHandle => { /* ... */ }
        ErrorKind::StorageFull => { /* ... */ }
        ErrorKind::NotSeekable => { /* ... */ }
        ErrorKind::FileTooLarge => { /* ... */ }
        ErrorKind::ResourceBusy => { /* ... */ }
        ErrorKind::ExecutableFileBusy => { /* ... */ }
        ErrorKind::Deadlock => { /* ... */ }
        ErrorKind::TooManyLinks => { /* ... */ }
        ErrorKind::ArgumentListTooLong => { /* ... */ }
        ErrorKind::Unsupported => { /* ... */ }
        
        // New in 1.85
        ErrorKind::QuotaExceeded => { /* ... */ }
        ErrorKind::CrossesDevices => { /* ... */ }
        
        _ => { /* ... */ }
    }
}
```

### Cell::update (1.88)

Update cell values in place:

```rust
use std::cell::Cell;

let cell = Cell::new(5);

// OLD: Get, modify, set
let val = cell.get();
cell.set(val + 1);

// NEW: Update in place
cell.update(|x| x + 1);
assert_eq!(cell.get(), 7);

// With more complex logic
cell.update(|x| if x > 5 { x * 2 } else { x });
```

### hint::select_unpredictable (1.88)

Help the optimizer with unpredictable branches:

```rust
use std::hint::select_unpredictable;

fn process(condition: bool, a: i32, b: i32) -> i32 {
    // Tell the optimizer: don't try to predict this branch
    // Both values will be computed, then one selected
    select_unpredictable(condition, a + expensive(), b + expensive())
}

// Useful when:
// - Branch is truly random (50/50)
// - Branch misprediction is more costly than computing both
// - Values are cheap to compute
```

### DerefMut for Lazy types (1.89)

```rust
use std::sync::LazyLock;

static mut CONFIG: LazyLock<Vec<String>> = LazyLock::new(Vec::new);

fn add_config(item: String) {
    // NEW: Can mutate through LazyLock
    unsafe {
        CONFIG.push(item);
    }
}
```

### proc_macro::Span Improvements (1.88)

Better source location information for proc macros:

```rust
use proc_macro::{Span, TokenStream};

#[proc_macro]
pub fn my_macro(input: TokenStream) -> TokenStream {
    let span = Span::call_site();
    
    // NEW: Get detailed location info
    let line = span.line();
    let column = span.column();
    let start = span.start();  // LineColumn
    let end = span.end();      // LineColumn
    
    // Get source file path
    if let Some(path) = span.local_file() {
        println!("Macro invoked from: {:?}", path);
    }
    
    // ...
}
```

### RwLockWriteGuard::downgrade (1.92)

Downgrade a write lock to a read lock atomically:

```rust
use std::sync::RwLock;

let lock = RwLock::new(vec![1, 2, 3]);

// Get write access
let mut write_guard = lock.write().unwrap();
write_guard.push(4);

// Downgrade to read-only (without releasing and reacquiring)
let read_guard = write_guard.downgrade();
// Other readers can now access, but we keep our reference
println!("Length: {}", read_guard.len());
```

### Zeroed Allocation (1.92)

Create zero-initialized heap allocations:

```rust
use std::sync::Arc;
use std::rc::Rc;

// Box
let boxed: Box<[u8; 1024]> = Box::new_zeroed();
let boxed_slice: Box<[u8]> = Box::new_zeroed_slice(1024);

// Rc
let rc: Rc<[u8; 1024]> = Rc::new_zeroed();
let rc_slice: Rc<[u8]> = Rc::new_zeroed_slice(1024);

// Arc  
let arc: Arc<[u8; 1024]> = Arc::new_zeroed();
let arc_slice: Arc<[u8]> = Arc::new_zeroed_slice(1024);

// Useful for large buffers where you want guaranteed zero initialization
// without stack allocation
```

---

## Compiler & Tooling

### LLD Linker by Default (1.90)

Rust now uses LLD as the default linker on `x86_64-unknown-linux-gnu`, providing significantly faster link times.

```bash
# If you need the old behavior:
RUSTFLAGS="-C linker=cc" cargo build

# For other platforms, opt-in to lld:
RUSTFLAGS="-C link-arg=-fuse-ld=lld" cargo build
```

### Cargo MSRV-Aware Resolver (1.84, default in 2024)

Cargo now respects your `rust-version` (MSRV) when resolving dependencies:

```toml
# Cargo.toml
[package]
name = "my-crate"
rust-version = "1.70"  # Minimum supported Rust version

# Cargo will now prefer dependency versions compatible with 1.70
```

```bash
# Force MSRV-aware resolution even in older editions
cargo +nightly -Zmsrv-policy build
```

### Cargo Automatic Garbage Collection (1.88)

Cargo now automatically cleans up old cached files:

```bash
# Crates not accessed in 3 months are removed
# Local crates not accessed in 1 month are removed

# To disable:
# In ~/.cargo/config.toml
[cache]
auto-clean-frequency = "never"

# Or with environment variable
CARGO_CACHE_AUTO_CLEAN_FREQUENCY=never cargo build
```

### cargo info (1.82)

Display information about a crate:

```bash
$ cargo info serde

serde
    A generic serialization/deserialization framework
    
    version: 1.0.193
    license: MIT OR Apache-2.0
    documentation: https://docs.rs/serde
    repository: https://github.com/serde-rs/serde
    
    features:
      - default: std
      - std
      - derive
      - alloc
      - rc
      - unstable
```

### cargo publish --workspace (1.90)

Publish multiple crates at once:

```bash
# Publish all crates in workspace
cargo publish --workspace

# With specific order for dependencies
cargo publish -p core-crate && cargo publish -p lib-crate && cargo publish -p app-crate
```

### build.build-dir Configuration (1.91)

Configure where build artifacts go:

```toml
# .cargo/config.toml
[build]
build-dir = "/tmp/my-project-build"

# Or per-profile
[profile.dev]
build-dir = "target/dev"
[profile.release]  
build-dir = "target/release"
```

### cfg Checking (1.80)

Validate `#[cfg]` attributes at compile time:

```bash
# Cargo now checks cfg names and values by default
# Unknown cfgs produce warnings

# To register custom cfgs:
# In build.rs:
println!("cargo::rustc-check-cfg=cfg(my_feature)");

# Or in Cargo.toml (nightly):
[lints.rust]
unexpected_cfgs = { level = "warn", check-cfg = ["cfg(my_feature)"] }
```

### --print host-tuple (1.84)

Get the host target tuple:

```bash
$ rustc --print host-tuple
x86_64-unknown-linux-gnu

# Useful in build scripts and CI
HOST=$(rustc --print host-tuple)
```

### Platform Support Changes

| Version | Change |
|---------|--------|
| 1.82 | `aarch64-apple-darwin` (Apple Silicon) promoted to **Tier 1** |
| 1.90 | `x86_64-apple-darwin` (Intel Mac) demoted to Tier 2 |
| 1.91 | `aarch64-pc-windows-msvc` promoted to **Tier 1** |
| 1.88 | `i686-pc-windows-gnu` demoted to Tier 2 |
| 1.84 | `wasm32-wasi` renamed to `wasm32-wasip1` |

### LLVM Version Updates

| Rust Version | LLVM Version | Notes |
|--------------|--------------|-------|
| 1.87 | LLVM 20 | Major update |
| 1.88 | LLVM 19 minimum | For external LLVM |
| 1.91 | LLVM 21 | |
| 1.92 | LLVM 20 minimum | For external LLVM |

---

## Breaking Changes

### Hard Errors (Things That Now Fail to Compile)

#### wasm32 C ABI (1.86)
```rust
// If using wasm-bindgen < 0.2.89, compilation fails
// Update wasm-bindgen:
// Cargo.toml: wasm-bindgen = "0.2.89" or higher
```

#### `#[bench]` Attribute (1.88)
```rust
// This is now a hard error without the feature flag:
#[bench]
fn my_benchmark(b: &mut Bencher) { }

// Fix: Use criterion or divan crate instead
// Or enable: #![feature(custom_test_frameworks)]
```

#### Enum with Drop Cast (1.86)
```rust
// ERROR: Can't cast fieldless enum with Drop to integer
#[derive(Drop)]
enum MyEnum { A, B, C }

impl Drop for MyEnum {
    fn drop(&mut self) { }
}

let x = MyEnum::A as i32;  // ERROR in 1.86+

// Fix: Remove Drop impl, or don't cast
```

#### Unsupported ABI Declarations (1.84+)
```rust
// ERROR: Can't declare functions with unsupported ABI
extern "stdcall" fn windows_only() { }  // Error on non-x86 Windows

// Fix: Use cfg to conditionally compile
#[cfg(all(windows, target_arch = "x86"))]
extern "stdcall" fn windows_only() { }
```

### Warnings That Will Become Errors

#### Static Mut References (1.78+)
```rust
static mut COUNTER: i32 = 0;

// WARNING: Creating reference to mutable static
let r = unsafe { &mut COUNTER };  // Deprecated

// Fix: Use raw pointers
let ptr = &raw mut COUNTER;  // Or std::ptr::addr_of_mut!(COUNTER)
unsafe { *ptr += 1; }

// Or better: Use atomic/sync types
use std::sync::atomic::{AtomicI32, Ordering};
static COUNTER: AtomicI32 = AtomicI32::new(0);
COUNTER.fetch_add(1, Ordering::SeqCst);
```

#### Dangerous Implicit Autorefs (1.88 warn, 1.89 deny)
```rust
// WARNING/ERROR: Implicit autoref of raw pointer dereference
let ptr: *mut i32 = /* ... */;

// Problematic: implicitly creates reference from raw pointer
let slice = unsafe { (*ptr).as_slice() };

// Fix: Be explicit about the reference
let slice = unsafe { (&*ptr).as_slice() };
// Or use raw pointer methods where available
```

#### Never Type Fallback (1.92 deny)
```rust
// DENY: Type inference falling back to () for !
fn diverges() -> ! { panic!() }

// Problematic when ! would be inferred as ()
let x = match true {
    true => diverges(),
    false => Default::default(),  // What type?
};

// Fix: Be explicit about types
let x: i32 = match true {
    true => diverges(),
    false => Default::default(),
};
```

### Behavior Changes

#### Null Pointer Dereference (1.86)
```rust
// Now panics in debug mode instead of UB
let ptr: *const i32 = std::ptr::null();
unsafe { *ptr };  // PANIC in debug, UB in release

// Always check for null:
if !ptr.is_null() {
    unsafe { *ptr }
}
```

#### extern "C" Unwinding (1.81)
```rust
// Unwinding through extern "C" now aborts
extern "C" fn called_from_c() {
    panic!("oops");  // Will abort the process, not unwind
}

// Fix: Use extern "C-unwind" if you need unwinding
extern "C-unwind" fn can_unwind() {
    panic!("this will unwind through C frames");
}
```

#### Home Directory on Windows (1.85)
```rust
// std::env::home_dir() now ignores $HOME on Windows
// Previously would use non-standard $HOME if set

// If you need $HOME:
std::env::var("HOME").ok()

// For actual home directory:
dirs::home_dir()  // dirs crate
```

#### i128/u128 Alignment (1.77)
```rust
// Now 16-byte aligned on x86
// May affect FFI and repr(C) structs

#[repr(C)]
struct MyStruct {
    a: u64,
    b: u128,  // Now at offset 16, not 8!
}
```

---

## Do's and Don'ts

### Async Code

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Awkward closure workarounds
let f: Box<dyn Fn() -> Pin<Box<
    dyn Future<Output = i32>
>>> = Box::new(|| {
    Box::pin(async { 42 })
});
```

</td>
<td>

```rust
// Native async closures (1.85+)
let f = async || {
    do_async_work().await
};
```

</td>
</tr>
</table>

### Lazy Initialization

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// External crate dependency
lazy_static::lazy_static! {
    static ref CONFIG: Config = 
        Config::load();
}

// or
static CONFIG: once_cell::sync::Lazy<Config> = 
    once_cell::sync::Lazy::new(Config::load);
```

</td>
<td>

```rust
// Standard library (1.80+)
use std::sync::LazyLock;

static CONFIG: LazyLock<Config> = 
    LazyLock::new(Config::load);
```

</td>
</tr>
</table>

### C Strings

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Manual null termination
let s = CStr::from_bytes_with_nul(
    b"hello\0"
).unwrap();

// Easy to forget the \0!
```

</td>
<td>

```rust
// C-string literal (1.77+)
let s: &CStr = c"hello";

// Compile-time checked!
```

</td>
</tr>
</table>

### Lint Suppression

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Silent, can become stale
#[allow(dead_code)]
fn maybe_used() { }
```

</td>
<td>

```rust
// Warns if lint no longer applies (1.81+)
#[expect(dead_code)]
fn maybe_used() { }
```

</td>
</tr>
</table>

### Conditional Patterns

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Deeply nested
if let Some(x) = opt {
    if x > 0 {
        if let Some(y) = x.child {
            process(y);
        }
    }
}
```

</td>
<td>

```rust
// Flat let chains (1.88+ / 2024)
if let Some(x) = opt
    && x > 0
    && let Some(y) = x.child
{
    process(y);
}
```

</td>
</tr>
</table>

### Raw Pointers from References

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Creates intermediate reference
static mut X: i32 = 0;
let ptr = unsafe { 
    &mut X as *mut i32 
};
```

</td>
<td>

```rust
// Direct raw pointer (1.82+)
static mut X: i32 = 0;
let ptr = &raw mut X;
// No reference created!
```

</td>
</tr>
</table>

### Integer Square Root

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Precision loss for large numbers
let n: u64 = 10_000_000_000;
let sqrt = (n as f64).sqrt() as u64;
```

</td>
<td>

```rust
// Exact computation (1.84+)
let n: u64 = 10_000_000_000;
let sqrt = n.isqrt();
```

</td>
</tr>
</table>

### Multiple Mutable References

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Manual splitting
let mut arr = [1, 2, 3, 4, 5];
let (left, right) = arr.split_at_mut(2);
let a = &mut left[0];
let b = &mut right[1];  // index 3
```

</td>
<td>

```rust
// Direct access (1.86+)
let mut arr = [1, 2, 3, 4, 5];
if let Ok([a, b]) = arr.get_disjoint_mut([0, 3]) {
    *a = 10;
    *b = 40;
}
```

</td>
</tr>
</table>

### File Locking

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// External crate
use fs2::FileExt;
file.lock_exclusive()?;
```

</td>
<td>

```rust
// Standard library (1.89+)
file.lock()?;        // exclusive
file.lock_shared()?; // shared
file.try_lock()?;    // non-blocking
```

</td>
</tr>
</table>

### Pipes

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// External crate or platform-specific
#[cfg(unix)]
use std::os::unix::io::*;
// Platform-specific pipe creation
```

</td>
<td>

```rust
// Cross-platform (1.87+)
use std::io::pipe;
let (reader, writer) = pipe()?;
```

</td>
</tr>
</table>

### Filter and Remove from Collections

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
// Two passes or awkward drain
let mut vec = vec![1, 2, 3, 4];
let evens: Vec<_> = vec.iter()
    .filter(|x| *x % 2 == 0)
    .copied()
    .collect();
vec.retain(|x| x % 2 != 0);
```

</td>
<td>

```rust
// Single pass (1.87+)
let mut vec = vec![1, 2, 3, 4];
let evens: Vec<_> = vec
    .extract_if(.., |x| *x % 2 == 0)
    .collect();
// vec now [1, 3], evens [2, 4]
```

</td>
</tr>
</table>

### Static Mutable Data

<table>
<tr><th>❌ Don't</th><th>✅ Do</th></tr>
<tr>
<td>

```rust
static mut COUNTER: i32 = 0;

unsafe {
    COUNTER += 1;  // Data race!
}
```

</td>
<td>

```rust
use std::sync::atomic::{AtomicI32, Ordering};

static COUNTER: AtomicI32 = AtomicI32::new(0);

COUNTER.fetch_add(1, Ordering::SeqCst);
// Thread-safe, no unsafe needed
```

</td>
</tr>
</table>

---

## Migration Checklist

### Before Upgrading to 2024 Edition

- [ ] Update to latest stable Rust: `rustup update stable`
- [ ] Run `cargo fix --edition` to apply automatic migrations
- [ ] Review `RPIT` (return position impl Trait) functions for lifetime changes
- [ ] Add `unsafe` to `extern` blocks
- [ ] Wrap unsafe attributes: `#[no_mangle]` → `#[unsafe(no_mangle)]`
- [ ] Check for `gen` identifier conflicts (reserved keyword)
- [ ] Review `if let` expressions for temporary lifetime dependencies
- [ ] Update `edition = "2024"` in Cargo.toml

### Dependency Updates

- [ ] Update `wasm-bindgen` to ≥0.2.89 if using WebAssembly
- [ ] Replace `lazy_static` with `std::sync::LazyLock`
- [ ] Replace `once_cell` with `std::sync::LazyLock` / `std::cell::LazyCell`
- [ ] Remove `cstr` crate, use `c"..."` literals
- [ ] Remove `fs2` crate if only using file locking
- [ ] Remove `os_pipe` crate, use `std::io::pipe`

### Code Modernization

- [ ] Replace `#[allow(...)]` with `#[expect(...)]` where appropriate
- [ ] Convert nested `if let` to let chains where cleaner
- [ ] Use `&raw` syntax for raw pointer creation
- [ ] Use `.isqrt()` instead of float conversion for integer sqrt
- [ ] Use `get_disjoint_mut` instead of manual `split_at_mut`
- [ ] Use `extract_if` instead of drain + filter patterns
- [ ] Use async closures instead of workarounds

### Safety Review

- [ ] Audit `static mut` usage - convert to atomics or sync primitives
- [ ] Check for raw pointer autorefs (new lint)
- [ ] Review never type inference in match expressions
- [ ] Check extern "C" functions for panic safety

---

## Quick Reference

### New Syntax Summary

```rust
// C-string literals (1.77)
let cstr: &CStr = c"hello";
let raw_cstr: &CStr = cr"no\escape";

// Raw pointer creation (1.82)
let ptr = &raw const value;
let ptr = &raw mut value;

// Async closures (1.85)
let f = async || { fut.await };
let f = async move || { captures.await };

// Let chains (1.88 / 2024)
if let Some(x) = opt && x > 0 && let Ok(y) = fallible(x) { }
while let Some(x) = iter.next() && predicate(x) { }

// Inline const (1.79)
const { assert!(size_of::<T>() < 100) };
let arr = [0; const { N * 2 }];

// Exclusive range patterns (1.80)
match n { ..0 => {}, 0..10 => {}, 10.. => {} }

// Const generic inference (1.89)
let arr: [i32; _] = [1, 2, 3];

// Unsafe attributes (2024)
#[unsafe(no_mangle)]
pub fn exported() { }
```

### New Standard Library APIs

```rust
// Lazy initialization (1.80)
use std::sync::LazyLock;
use std::cell::LazyCell;
static X: LazyLock<T> = LazyLock::new(|| init());

// Pipes (1.87)
let (reader, writer) = std::io::pipe()?;

// File locking (1.89)
file.lock()?;
file.lock_shared()?;
file.try_lock()?;
file.unlock()?;

// Multiple mutable refs (1.86)
slice.get_disjoint_mut([i, j])?;
hashmap.get_disjoint_mut([&k1, &k2])?;

// Extract while filtering (1.87+)
vec.extract_if(range, |x| predicate(x));
hashmap.extract_if(|k, v| predicate(k, v));

// Conditional operations
option.take_if(|x| predicate(x));  // 1.80
option.is_none_or(|x| predicate(x));  // 1.82
vec.pop_if(|x| predicate(x));  // 1.86
result.flatten();  // 1.89

// Integer operations
n.isqrt();  // 1.84
n.midpoint(m);  // 1.85 (float), 1.87 (signed int)
n.cast_signed();  // 1.87
n.cast_unsigned();  // 1.87

// Pointer operations (1.84)
ptr.addr();
ptr.with_addr(addr);
ptr::without_provenance(addr);
ptr::with_exposed_provenance(addr);

// Sync primitives
Once::wait();  // 1.86
OnceLock::wait();  // 1.86
Cell::update(|x| f(x));  // 1.88
RwLockWriteGuard::downgrade();  // 1.92

// Allocation
Box::new_zeroed();  // 1.92
Arc::new_zeroed_slice(len);  // 1.92
```

### Cargo Commands

```bash
# New commands
cargo info <crate>                    # 1.82: Show crate info
cargo publish --workspace             # 1.90: Publish all workspace crates

# Edition migration
cargo fix --edition                   # Apply automatic fixes
cargo fix --edition --allow-dirty     # Even with uncommitted changes

# Build configuration
cargo build --config 'build.build-dir="/tmp/build"'  # 1.91
```

### Compiler Flags

```bash
# Target information
rustc --print host-tuple              # 1.84: Print host target

# Debug info
rustc -C dwarf-version=5              # 1.88: Select DWARF version

# Linking
rustc -C link-arg=-fuse-ld=lld        # Use LLD linker
```

### Platform Tiers (Current)

| Target | Tier |
|--------|------|
| `x86_64-unknown-linux-gnu` | 1 |
| `aarch64-unknown-linux-gnu` | 1 |
| `x86_64-pc-windows-msvc` | 1 |
| `aarch64-apple-darwin` | 1 |
| `aarch64-pc-windows-msvc` | 1 |
| `x86_64-apple-darwin` | 2 (demoted from 1) |
| `i686-pc-windows-gnu` | 2 (demoted from 1) |
| `wasm32-wasip1` | 2 (renamed from wasm32-wasi) |

---

## Version Timeline

| Version | Date | Highlights |
|---------|------|------------|
| 1.70.0 | Jun 2023 | Starting point |
| 1.71.0 | Jul 2023 | C-unwind ABI |
| 1.72.0 | Aug 2023 | cfg visibility, unlimited const eval |
| 1.73.0 | Oct 2023 | Cleaner panic messages, thread local improvements |
| 1.74.0 | Nov 2023 | Saturating type, Apple platform requirements |
| 1.75.0 | Dec 2023 | async fn in traits (partial) |
| 1.76.0 | Feb 2024 | ABI compatibility docs, type_name_of_val |
| 1.77.0 | Mar 2024 | **C-string literals**, async recursion, offset_of! |
| 1.78.0 | May 2024 | static_mut_refs lint, wasm32-wasip1 |
| 1.79.0 | Jun 2024 | **Inline const**, associated type bounds |
| 1.80.0 | Jul 2024 | **LazyCell/LazyLock**, exclusive ranges, cfg checking |
| 1.81.0 | Sep 2024 | **#[expect]**, Error in core, extern "C" abort |
| 1.82.0 | Oct 2024 | **&raw syntax**, safe target_feature, cargo info |
| 1.83.0 | Nov 2024 | Entry::insert_entry, ControlFlow API |
| 1.84.0 | Jan 2025 | **Strict provenance**, isqrt, MSRV resolver |
| 1.85.0 | Feb 2025 | **🎉 2024 EDITION**, async closures, do_not_recommend |
| 1.86.0 | Apr 2025 | **Trait upcasting**, get_disjoint_mut, null deref panic |
| 1.87.0 | May 2025 | **Pipes API**, extract_if, asm_goto |
| 1.88.0 | Jun 2025 | **Let chains**, naked functions, Cell::update |
| 1.89.0 | Aug 2025 | **File locking**, const generic inference, repr128 |
| 1.90.0 | Sep 2025 | **LLD default on Linux**, cargo publish --workspace |
| 1.91.0 | Oct 2025 | build.build-dir, aarch64-windows Tier 1 |
| 1.92.0 | Dec 2025 | RwLock::downgrade, zeroed allocations |

---

*Document generated for Rust versions 1.70.0 through 1.92.0*
*Last updated: January 2026*
