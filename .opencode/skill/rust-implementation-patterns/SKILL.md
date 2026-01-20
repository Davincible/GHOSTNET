---
name: rust-implementation-patterns
description: Core Rust patterns for daily implementation work. Use when designing types, handling errors, working with ownership/borrowing, writing async code, choosing data structures, or managing concurrency.
---

# Rust Implementation Patterns

## 1. Ownership, Borrowing & Lifetimes

### Core Rules (Memorize These 5)

1. **Each value has exactly one owner**
2. **Ownership transfers on move** (unless the type implements `Copy`)
3. **References: many `&T` OR one `&mut T`** (never both simultaneously)
4. **References cannot outlive their referent**
5. **`'static` means "can live forever," not "will live forever"**

### Lifetime Elision Rules

The compiler infers lifetimes automatically using three rules (in order):

1. **Each input reference gets its own lifetime**
2. **If exactly one input lifetime, output gets that lifetime**
3. **If `&self` or `&mut self`, output gets that lifetime**

**When elision fails, annotate explicitly:**

```rust
// Compiler can't infer: multiple input lifetimes, no self
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

// Same lifetime constraint: returned reference is valid as long
// as BOTH inputs are valid
```

**Common lifetime annotation scenarios:**

```rust
// Struct holding a reference must declare lifetime
struct Parser<'a> {
    input: &'a str,
}

// Multiple lifetimes when they can differ
struct Pair<'a, 'b> {
    first: &'a str,
    second: &'b str,
}

// 'static for data that lives for entire program
fn get_description() -> &'static str {
    "This string literal lives forever"
}
```

### Borrow Checker Escape Hatches (Order of Preference)

```
Can't satisfy the borrow checker?
|
+-> 1. Restructure code
|      Often the borrow checker reveals design issues.
|      Split structs, change function signatures, use indices.
|
+-> 2. Clone strategically
|      Acceptable for small data or rare paths.
|      Profile first - it's often not the bottleneck.
|
+-> 3. Rc<T> / Arc<T>
|      Shared ownership when structure demands it.
|      Use when multiple owners need the same data.
|
+-> 4. RefCell<T> / Mutex<T>
|      Interior mutability with runtime borrow checks.
|      Use when you need mutation through shared reference.
|
+-> 5. unsafe
       Last resort. Requires proof of correctness.
       Document invariants extensively.
```

### Smart Pointer Decision Tree

```
Need shared ownership?
|
+-- No --> Use regular ownership or references
|
+-- Yes --> Single thread or multi-thread?
            |
            +-- Single thread --> Rc<T>
            |                     |
            |                     +-- Need mutation? --> Rc<RefCell<T>>
            |
            +-- Multi-thread --> Arc<T>
                                 |
                                 +-- Need mutation?
                                     |
                                     +-- Read-heavy? --> Arc<RwLock<T>>
                                     |
                                     +-- Write-heavy or simple? --> Arc<Mutex<T>>
```

**Interior Mutability Quick Reference:**

| Scenario | Use | Overhead |
|----------|-----|----------|
| Copy type, single thread | `Cell<T>` | Zero |
| Non-Copy, single thread | `RefCell<T>` | Runtime borrow check |
| Counter, multi-thread | `AtomicUsize` | Lock-free |
| Flag, multi-thread | `AtomicBool` | Lock-free |
| Complex type, write-heavy | `Mutex<T>` | Lock acquisition |
| Complex type, read-heavy | `RwLock<T>` | Lock acquisition |
| Can redesign? | Regular `&mut` | Zero |

```rust
// Cell for Copy types (no runtime check)
use std::cell::Cell;

struct Counter {
    count: Cell<u32>,
}

impl Counter {
    fn increment(&self) {
        self.count.set(self.count.get() + 1);
    }
}

// RefCell for non-Copy (runtime borrow check)
use std::cell::RefCell;

let data = RefCell::new(vec![1, 2, 3]);
data.borrow_mut().push(4);

// Atomics for multi-thread counters
use std::sync::atomic::{AtomicU64, Ordering};

static COUNTER: AtomicU64 = AtomicU64::new(0);
COUNTER.fetch_add(1, Ordering::Relaxed);
```

### Clone Decision Framework

```
Can you borrow instead?
|
+-- Yes --> Borrow (&T)
|
+-- No --> Is it Copy?
           |
           +-- Yes --> Copy (free for small types)
           |
           +-- No --> Do you need shared ownership?
                      |
                      +-- Yes --> Rc<T> (single-thread) / Arc<T> (multi-thread)
                      |
                      +-- No --> Might you need to modify?
                                 |
                                 +-- Sometimes --> Cow<T>
                                 |
                                 +-- Always --> Clone (last resort)
```

**Cow: Clone-on-Write Pattern**

```rust
use std::borrow::Cow;

fn process(input: Cow<str>) -> Cow<str> {
    if input.contains("bad") {
        Cow::Owned(input.replace("bad", "good"))
    } else {
        input  // No allocation if unchanged
    }
}

// Zero-cost if no modification needed
process(Cow::Borrowed("hello"));
process(Cow::Owned(String::from("hello bad")));

// Great for APIs that usually return input unchanged
fn normalize(s: &str) -> Cow<str> {
    if s.chars().all(|c| c.is_lowercase()) {
        Cow::Borrowed(s)
    } else {
        Cow::Owned(s.to_lowercase())
    }
}
```

---

## 2. Type System Patterns

### Newtype Pattern

Create distinct types from existing types for type safety without runtime overhead:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ProductId(u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct OrderId(u64);

// Now these are compile-time errors:
fn get_user(id: UserId) -> Option<User> { /* ... */ }
fn get_product(id: ProductId) -> Option<Product> { /* ... */ }

// get_user(product_id);  // Compile error!
// get_product(user_id);  // Compile error!
```

**With Validation Constructors:**

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Email(String);

impl Email {
    pub fn new(value: impl Into<String>) -> Result<Self, ValidationError> {
        let value = value.into();
        if Self::is_valid(&value) {
            Ok(Email(value))
        } else {
            Err(ValidationError::InvalidEmail(value))
        }
    }
    
    fn is_valid(value: &str) -> bool {
        value.contains('@') && value.len() >= 3
    }
    
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

// Now Email is guaranteed valid wherever it appears
pub struct User {
    pub id: UserId,
    pub email: Email,  // Always valid
    pub name: String,
}
```

**Common Derives for Newtypes:**

```rust
// For IDs (hashable, comparable)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(u64);

// For values that need ordering
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Priority(u32);

// For serializable types
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ApiKey(String);
```

### Typestate Pattern

Encode state transitions in the type system to make invalid state transitions impossible:

```rust
use std::marker::PhantomData;

// States (zero-sized types - no runtime cost)
pub struct Draft;
pub struct UnderReview;
pub struct Published;

pub struct Article<State> {
    id: ArticleId,
    title: String,
    content: String,
    _state: PhantomData<State>,
}

impl Article<Draft> {
    pub fn new(title: String, content: String) -> Self {
        Self {
            id: ArticleId::new(),
            title,
            content,
            _state: PhantomData,
        }
    }
    
    // Can only be called on Draft articles
    pub fn submit_for_review(self) -> Article<UnderReview> {
        Article {
            id: self.id,
            title: self.title,
            content: self.content,
            _state: PhantomData,
        }
    }
}

impl Article<UnderReview> {
    pub fn approve(self) -> Article<Published> {
        Article {
            id: self.id,
            title: self.title,
            content: self.content,
            _state: PhantomData,
        }
    }
    
    pub fn reject(self) -> Article<Draft> {
        Article {
            id: self.id,
            title: self.title,
            content: self.content,
            _state: PhantomData,
        }
    }
}

impl Article<Published> {
    // Only published articles can be viewed
    pub fn view(&self) -> ArticleView {
        ArticleView {
            title: &self.title,
            content: &self.content,
        }
    }
}

// Usage - compiler enforces valid transitions:
let article = Article::new("Title".into(), "Content".into());
// article.view();                    // Compile error - not published
let reviewed = article.submit_for_review();
// reviewed.submit_for_review();     // Compile error - already submitted
let published = reviewed.approve();
let view = published.view();          // Works
```

### Typestate Builder Pattern

Ensure required fields are set at compile-time:

```rust
use std::marker::PhantomData;
use std::time::Duration;

// Marker types
pub struct Missing;
pub struct Present;

pub struct RequestBuilder<Url, Method> {
    url: Option<String>,
    method: Option<HttpMethod>,
    headers: Vec<(String, String)>,
    timeout: Option<Duration>,
    _markers: PhantomData<(Url, Method)>,
}

impl RequestBuilder<Missing, Missing> {
    pub fn new() -> Self {
        Self {
            url: None,
            method: None,
            headers: Vec::new(),
            timeout: None,
            _markers: PhantomData,
        }
    }
}

impl<M> RequestBuilder<Missing, M> {
    pub fn url(self, url: impl Into<String>) -> RequestBuilder<Present, M> {
        RequestBuilder {
            url: Some(url.into()),
            method: self.method,
            headers: self.headers,
            timeout: self.timeout,
            _markers: PhantomData,
        }
    }
}

impl<U> RequestBuilder<U, Missing> {
    pub fn method(self, method: HttpMethod) -> RequestBuilder<U, Present> {
        RequestBuilder {
            url: self.url,
            method: Some(method),
            headers: self.headers,
            timeout: self.timeout,
            _markers: PhantomData,
        }
    }
}

// Optional methods available in any state
impl<U, M> RequestBuilder<U, M> {
    pub fn header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.headers.push((key.into(), value.into()));
        self
    }
    
    pub fn timeout(mut self, timeout: Duration) -> Self {
        self.timeout = Some(timeout);
        self
    }
}

// build() only available when both URL and Method are set
impl RequestBuilder<Present, Present> {
    pub fn build(self) -> Request {
        Request {
            url: self.url.unwrap(),       // Safe: typestate guarantees Some
            method: self.method.unwrap(), // Safe: typestate guarantees Some
            headers: self.headers,
            timeout: self.timeout.unwrap_or(Duration::from_secs(30)),
        }
    }
}

// Usage:
let request = RequestBuilder::new()
    .url("https://api.example.com")
    .method(HttpMethod::Get)
    .header("Authorization", "Bearer token")
    .build();  // Compiles

// let bad = RequestBuilder::new()
//     .url("https://api.example.com")
//     .build();  // Compile error - method not set
```

### Algebraic Data Types with Enums

Use enums to express domain concepts precisely, preventing invalid states:

```rust
// Instead of scattered booleans and optional fields:
// BAD: struct User { is_verified: bool, verified_at: Option<DateTime>, ... }

// GOOD: All possible states are explicit
pub enum UserStatus {
    Pending {
        verification_token: String,
        token_expires_at: DateTime<Utc>,
    },
    Active {
        verified_at: DateTime<Utc>,
    },
    Suspended {
        reason: String,
        suspended_at: DateTime<Utc>,
        suspended_by: UserId,
    },
    Deleted {
        deleted_at: DateTime<Utc>,
        retention_until: DateTime<Utc>,
    },
}

pub struct User {
    pub id: UserId,
    pub email: Email,
    pub status: UserStatus,
}

// Pattern matching ensures all cases are handled
impl User {
    pub fn can_login(&self) -> bool {
        matches!(self.status, UserStatus::Active { .. })
    }
    
    pub fn days_until_deletion(&self) -> Option<i64> {
        match &self.status {
            UserStatus::Deleted { retention_until, .. } => {
                Some((*retention_until - Utc::now()).num_days())
            }
            _ => None,
        }
    }
}
```

**Avoiding Boolean Blindness:**

```rust
// BAD: What do these booleans mean?
fn process_order(order: &Order, is_priority: bool, is_gift: bool, needs_signature: bool) {
    // ...
}

// GOOD: Self-documenting types
pub enum Priority { Standard, Express, Overnight }
pub enum GiftWrap { None, Standard, Premium }
pub enum Signature { NotRequired, Required, AdultRequired }

fn process_order(order: &Order, priority: Priority, gift: GiftWrap, signature: Signature) {
    // ...
}
```

### Sealed Traits

Prevent external implementations while exposing the trait publicly:

```rust
mod private {
    pub trait Sealed {}
}

/// This trait cannot be implemented outside this crate.
/// External code can use it but not implement it.
pub trait DatabaseDriver: private::Sealed {
    fn connect(&self, url: &str) -> Result<Connection>;
    fn execute(&self, query: &str) -> Result<()>;
}

// Internal types can implement
pub struct PostgresDriver;
impl private::Sealed for PostgresDriver {}
impl DatabaseDriver for PostgresDriver {
    fn connect(&self, url: &str) -> Result<Connection> { /* ... */ }
    fn execute(&self, query: &str) -> Result<()> { /* ... */ }
}

pub struct SqliteDriver;
impl private::Sealed for SqliteDriver {}
impl DatabaseDriver for SqliteDriver {
    fn connect(&self, url: &str) -> Result<Connection> { /* ... */ }
    fn execute(&self, query: &str) -> Result<()> { /* ... */ }
}
```

**When to Seal:**
- When adding methods to a trait would be a breaking change
- When you want exhaustive matching on trait implementors
- When the trait is part of your internal architecture

### Marker Traits

Use marker traits for type-level constraints:

```rust
/// Marker for types that are safe to cache
pub trait Cacheable: Clone + Send + Sync + 'static {}

/// Marker for validated/sanitized input
pub trait Validated {}

/// Marker for types that can be serialized to the wire format
pub trait WireFormat: Serialize + DeserializeOwned {}

// Blanket implementation
impl<T> WireFormat for T where T: Serialize + DeserializeOwned {}

// Use in bounds
fn cache_item<T: Cacheable>(key: &str, item: T) -> Result<()> {
    // Only cacheable items can be stored
}

fn send_message<T: WireFormat>(msg: T) -> Result<()> {
    // Only wire-format types can be sent
}
```

**Zero-Sized Type Markers:**

```rust
// Marker types for compile-time guarantees
struct Authenticated;
struct Anonymous;

struct Request<Auth> {
    // ...
    _auth: PhantomData<Auth>,
}

impl Request<Authenticated> {
    fn admin_action(&self) { /* ... */ }  // Only authenticated requests
}
```

### Extension Traits

Add methods to foreign types without violating orphan rules:

```rust
/// Extension methods for string slices
pub trait StrExt {
    fn truncate_ellipsis(&self, max_len: usize) -> String;
    fn is_blank(&self) -> bool;
}

impl StrExt for str {
    fn truncate_ellipsis(&self, max_len: usize) -> String {
        if self.len() <= max_len {
            self.to_string()
        } else {
            format!("{}...", &self[..max_len.saturating_sub(3)])
        }
    }
    
    fn is_blank(&self) -> bool {
        self.trim().is_empty()
    }
}

/// Extension methods for Results
pub trait ResultExt<T, E> {
    fn log_err(self) -> Self;
}

impl<T, E: std::fmt::Debug> ResultExt<T, E> for Result<T, E> {
    fn log_err(self) -> Self {
        if let Err(ref e) = self {
            tracing::error!(error = ?e, "Operation failed");
        }
        self
    }
}

// Usage:
// "hello world".truncate_ellipsis(8)  // "hello..."
// "   ".is_blank()                     // true
// fallible_operation().log_err()?;     // Logs on error
```

---

## 3. Error Handling

### Error Type Strategy Decision Tree

```
Is this a library or application?
|
+-- Library --> Use thiserror, define specific error enums
|               Callers can match on variants.
|
+-- Application
    |
    +-- Do you need to match on errors programmatically?
        |
        +-- Yes --> Use thiserror with domain-specific enums
        |
        +-- No --> Use anyhow for convenience
        |
        +-- Hybrid --> thiserror at boundaries, anyhow internally
```

| Context | Approach | Crate |
|---------|----------|-------|
| Library (public API) | Custom enum | `thiserror` |
| Application | Boxed errors | `anyhow` |
| Performance-critical | Custom enum | Manual impl |
| FFI boundary | Error codes | Manual |

### thiserror Patterns (Libraries)

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DbError {
    // #[from] enables automatic conversion with ?
    #[error("connection failed: {0}")]
    Connection(#[from] std::io::Error),
    
    // Structured error data with #[source] for chaining
    #[error("query failed: {query}")]
    Query {
        query: String,
        #[source]
        source: sqlx::Error,
    },
    
    // Simple error with data
    #[error("record not found: {0}")]
    NotFound(u64),
    
    // Named fields for complex errors
    #[error("permission denied: {action} on {resource}")]
    PermissionDenied {
        action: &'static str,
        resource: String,
    },
    
    // Transparent wrapping (delegates Display/source)
    #[error(transparent)]
    Database(#[from] sqlx::Error),
}

// Define a type alias for convenience
pub type Result<T> = std::result::Result<T, DbError>;
```

**Structured Error Data:**

```rust
#[derive(Debug, Error)]
pub enum ApiError {
    #[error("validation failed")]
    Validation {
        field: &'static str,
        message: String,
        #[source]
        source: Option<Box<dyn std::error::Error + Send + Sync>>,
    },
    
    #[error("rate limited: retry after {retry_after_secs}s")]
    RateLimited {
        retry_after_secs: u64,
        limit: u32,
    },
}
```

### anyhow Patterns (Applications)

```rust
use anyhow::{Context, Result, bail, ensure};

fn load_config(path: &Path) -> Result<Config> {
    // with_context adds context to errors
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("failed to read config from {}", path.display()))?;
    
    // ensure! returns error if condition is false
    ensure!(!content.is_empty(), "config file is empty");
    
    let config: Config = toml::from_str(&content)
        .context("failed to parse TOML")?;
    
    // bail! returns an error immediately
    if config.workers == 0 {
        bail!("workers must be > 0");
    }
    
    Ok(config)
}

// Error output:
// Error: failed to read config from /etc/app/config.toml
//
// Caused by:
//     No such file or directory (os error 2)
```

**When to Downcast:**

```rust
use anyhow::Result;

fn handle_error(err: anyhow::Error) {
    // Downcast to check for specific error types
    if let Some(io_err) = err.downcast_ref::<std::io::Error>() {
        match io_err.kind() {
            std::io::ErrorKind::NotFound => {
                // Handle file not found specifically
            }
            _ => {
                // Handle other IO errors
            }
        }
    }
}
```

### Result Combinators Reference

```rust
let result: Result<i32, Error> = Ok(5);

// Transform success value
result.map(|x| x * 2)               // Ok(10)

// Transform error value
result.map_err(|e| wrap(e))         // Change error type

// Chain fallible operations
result.and_then(|x| validate(x))    // Returns Result

// Provide fallback on error
result.or_else(|e| recover(e))      // Returns Result

// Get value or default
result.unwrap_or(0)                 // 0 if Err
result.unwrap_or_else(|e| compute_default(e))  // Lazy default

// Get value or default for the type
result.unwrap_or_default()          // T::default() if Err

// Convert to Option
result.ok()                         // Some(5), discards error
result.err()                        // None, discards success

// Propagate error, unwrap success
result?                             // Early return on Err
```

### Option Combinators Reference

```rust
let opt: Option<i32> = Some(5);

// Transform inner value
opt.map(|x| x * 2)                  // Some(10)

// Chain operations that return Option
opt.and_then(|x| checked_div(x, 2)) // Flattens Option<Option<T>>

// Provide fallback
opt.unwrap_or(0)                    // 0 if None
opt.unwrap_or_else(|| compute())    // Lazy default
opt.unwrap_or_default()             // T::default() if None

// Convert to Result
opt.ok_or(Error::NotFound)          // Err(Error::NotFound) if None
opt.ok_or_else(|| Error::new())     // Lazy error

// Filter values
opt.filter(|x| *x > 0)              // None if predicate fails

// Flatten nested Options
let nested: Option<Option<i32>> = Some(Some(5));
nested.flatten()                    // Some(5)

// Take value, leaving None
let mut opt = Some(5);
opt.take()                          // Returns Some(5), opt is now None

// Replace value
opt.replace(10)                     // Returns old value, sets new
```

### The Zero .unwrap() Rule

In production code, avoid `unwrap()`, `expect()`, and `panic!()` for error handling.

**Enable Clippy Lints:**

```rust
// lib.rs or main.rs
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::panic)]
```

**Acceptable Exceptions (use `expect()` with clear message):**

1. **Initialization of global state that truly cannot fail:**
```rust
use std::sync::LazyLock;

static REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\d{4}-\d{2}-\d{2}$")
        .expect("date regex is valid")
});
```

2. **Test code:**
```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_parse() {
        let result = parse("valid input").unwrap();
        assert_eq!(result, expected);
    }
}
```

3. **When the type system cannot encode the invariant:**
```rust
// After checking vec is non-empty
if !items.is_empty() {
    let first = items.first().expect("checked non-empty above");
}

// Better: use pattern matching
if let Some(first) = items.first() {
    // ...
}
```

---

## 4. Async & Concurrency

### Async Mental Model

1. **`async fn` returns a `Future`** - does nothing until `.await`ed
2. **`Future` is a state machine** - generated at compile time, zero-cost
3. **`.await` yields control** - allows other tasks to run on the same thread
4. **Runtime polls futures** - drives them to completion

```rust
// This compiles to a state machine
async fn fetch_data() -> Data {
    let response = client.get(url).await;  // Yield point
    let body = response.body().await;       // Yield point
    parse(body)
}
```

### Tokio Runtime Setup

**Using the macro (most common):**

```rust
#[tokio::main]
async fn main() {
    // Full runtime with work-stealing scheduler
}

// Single-threaded runtime
#[tokio::main(flavor = "current_thread")]
async fn main() {
    // All tasks on one thread
}

// Customize worker threads
#[tokio::main(worker_threads = 4)]
async fn main() {
    // Exactly 4 worker threads
}
```

**Manual runtime builder (for more control):**

```rust
fn main() {
    let rt = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(4)
        .enable_all()
        .build()
        .expect("failed to build runtime");
    
    rt.block_on(async {
        // Your async code here
    });
}
```

**Cargo.toml:**

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }

# Or minimal features
tokio = { version = "1", features = ["rt", "macros"] }
```

### Task Spawning Patterns

```rust
// Fire-and-forget task
tokio::spawn(async move {
    process_in_background().await;
});

// Task with result (returns JoinHandle)
let handle = tokio::spawn(async move {
    compute_something().await
});
let result = handle.await?;  // JoinError if task panicked

// CPU-bound work (don't block async runtime!)
let result = tokio::task::spawn_blocking(move || {
    expensive_computation()  // Runs on dedicated thread pool
}).await?;

// Spawn on specific runtime
let handle = tokio::runtime::Handle::current();
handle.spawn(async move {
    // ...
});
```

### Synchronization Primitives Table

| Primitive | Use Case | Notes |
|-----------|----------|-------|
| `tokio::sync::Mutex` | Async-safe mutual exclusion | Doesn't block thread, holds across `.await` |
| `tokio::sync::RwLock` | Read-heavy shared state | Multiple readers OR one writer |
| `tokio::sync::mpsc` | Multi-producer, single-consumer | Backpressure via bounded capacity |
| `tokio::sync::broadcast` | Multi-consumer broadcast | All receivers get all messages |
| `tokio::sync::oneshot` | Single value, single use | Request-response pattern |
| `tokio::sync::watch` | Latest value broadcast | Config updates, only latest value kept |
| `tokio::sync::Semaphore` | Limit concurrency | Connection pools, rate limiting |
| `tokio::sync::Notify` | Wake waiters | Event signaling |

### Channel Patterns

**Request-Response with oneshot:**

```rust
use tokio::sync::{mpsc, oneshot};

enum Command {
    Get { key: String, reply: oneshot::Sender<Option<Value>> },
    Set { key: String, value: Value, reply: oneshot::Sender<()> },
}

// Actor that owns state
async fn cache_actor(mut rx: mpsc::Receiver<Command>) {
    let mut cache = HashMap::new();
    
    while let Some(cmd) = rx.recv().await {
        match cmd {
            Command::Get { key, reply } => {
                let _ = reply.send(cache.get(&key).cloned());
            }
            Command::Set { key, value, reply } => {
                cache.insert(key, value);
                let _ = reply.send(());
            }
        }
    }
}

// Client sends commands and awaits responses
async fn get_value(tx: &mpsc::Sender<Command>, key: String) -> Option<Value> {
    let (reply_tx, reply_rx) = oneshot::channel();
    tx.send(Command::Get { key, reply: reply_tx }).await.ok()?;
    reply_rx.await.ok()?
}
```

**Work Distribution with mpsc:**

```rust
use tokio::sync::mpsc;

async fn worker(mut rx: mpsc::Receiver<Task>) {
    while let Some(task) = rx.recv().await {
        process_task(task).await;
    }
}

async fn distribute_work(tasks: Vec<Task>) {
    let (tx, rx) = mpsc::channel(100);  // Bounded channel
    
    // Spawn worker
    tokio::spawn(worker(rx));
    
    // Send work
    for task in tasks {
        tx.send(task).await.expect("worker alive");
    }
}
```

**Config Broadcast with watch:**

```rust
use tokio::sync::watch;

async fn config_reloader(tx: watch::Sender<Config>) {
    loop {
        tokio::time::sleep(Duration::from_secs(60)).await;
        if let Ok(new_config) = load_config().await {
            let _ = tx.send(new_config);  // All receivers see latest
        }
    }
}

async fn worker(mut rx: watch::Receiver<Config>) {
    loop {
        // Wait for config change
        rx.changed().await.expect("sender alive");
        let config = rx.borrow().clone();
        // Use new config...
    }
}
```

### Select and Racing

**Basic select! usage:**

```rust
use tokio::select;

async fn with_timeout() -> Result<Data, Error> {
    select! {
        result = fetch_data() => result,
        _ = tokio::time::sleep(Duration::from_secs(5)) => {
            Err(Error::Timeout)
        }
    }
}
```

**Biased select (check in order):**

```rust
select! {
    biased;  // Check branches in order, don't randomize
    
    _ = shutdown.recv() => {
        // Always check shutdown first
        break;
    }
    msg = rx.recv() => {
        handle(msg);
    }
}
```

**Timeout pattern:**

```rust
use tokio::time::timeout;

async fn fetch_with_timeout() -> Result<Data, Error> {
    timeout(Duration::from_secs(5), fetch_data())
        .await
        .map_err(|_| Error::Timeout)?
}
```

**Loop with select:**

```rust
loop {
    select! {
        Some(msg) = rx.recv() => {
            process(msg).await;
        }
        _ = shutdown.recv() => {
            break;
        }
        _ = tokio::time::sleep(Duration::from_secs(60)) => {
            do_periodic_work().await;
        }
    }
}
```

### Cancellation Safety

**What it means:** When a future is dropped (cancelled), what state is left behind?

**Documentation pattern:**

```rust
impl Connection {
    /// Reads data from the connection.
    /// 
    /// # Cancellation Safety
    /// 
    /// This method is cancellation-safe. If cancelled, no data is lost
    /// and the connection remains in a valid state. Partial reads are
    /// buffered internally.
    pub async fn read(&mut self) -> Result<Data> {
        // ...
    }
    
    /// Writes data to the connection.
    /// 
    /// # Cancellation Safety
    /// 
    /// This method is NOT cancellation-safe. If cancelled mid-write,
    /// the connection may be left in an inconsistent state and should
    /// be closed.
    pub async fn write(&mut self, data: &[u8]) -> Result<()> {
        // ...
    }
}
```

**spawn-based safety:**

```rust
// If you need to ensure a future completes even if we stop waiting:
let handle = tokio::spawn(fetch_data());

select! {
    result = &mut handle => {
        // Task completed
        return result?;
    }
    _ = timeout => {
        // Task continues in background
        handle.abort();  // Or let it continue
        return Err(Error::Timeout);
    }
}
```

### Async Anti-Patterns

**1. std::sync::Mutex across .await:**

```rust
// WRONG: Deadlock risk - std Mutex blocks the thread
let guard = std_mutex.lock().unwrap();
do_async_thing().await;  // Other tasks can't run!
drop(guard);

// CORRECT: Use tokio::sync::Mutex
let guard = tokio_mutex.lock().await;
do_async_thing().await;  // Other tasks can run
drop(guard);
```

**2. Blocking in async context:**

```rust
// WRONG: Blocks entire thread, starves runtime
async fn bad() {
    std::thread::sleep(Duration::from_secs(1));  // Blocks!
    std::fs::read_to_string("file.txt");         // Blocks!
}

// CORRECT: Use async equivalents or spawn_blocking
async fn good() {
    tokio::time::sleep(Duration::from_secs(1)).await;
    tokio::fs::read_to_string("file.txt").await;
}

// CORRECT: For CPU-bound or unavoidable blocking
async fn compute() {
    let result = tokio::task::spawn_blocking(|| {
        expensive_sync_computation()
    }).await?;
}
```

**3. Unbounded spawning:**

```rust
// WRONG: Can spawn millions of tasks, exhaust memory
for item in items {
    tokio::spawn(process(item));
}

// CORRECT: Bounded concurrency
use futures::stream::{self, StreamExt};

stream::iter(items)
    .for_each_concurrent(100, |item| async move {
        process(item).await;
    })
    .await;

// CORRECT: Using semaphore
let semaphore = Arc::new(Semaphore::new(100));
for item in items {
    let permit = semaphore.clone().acquire_owned().await?;
    tokio::spawn(async move {
        process(item).await;
        drop(permit);  // Release when done
    });
}
```

**4. Holding locks longer than necessary:**

```rust
// WRONG: Lock held during I/O
let mut data = mutex.lock().await;
let result = fetch_external_data().await;  // Lock held during network call!
data.update(result);

// CORRECT: Release lock before I/O
let current = {
    let data = mutex.lock().await;
    data.current_value()
};
let result = fetch_external_data(current).await;
{
    let mut data = mutex.lock().await;
    data.update(result);
}
```

---

## 5. Data Structures

### Standard Collections Overview Table

| Collection | Structure | Access | Insert | Remove | Memory | Use Case |
|------------|-----------|--------|--------|--------|--------|----------|
| `Vec<T>` | Contiguous array | O(1) index | O(1) push | O(n) arbitrary | Compact | Default sequence |
| `VecDeque<T>` | Ring buffer | O(1) index | O(1) both ends | O(n) middle | Compact | Queue/deque |
| `LinkedList<T>` | Doubly-linked | O(n) | O(1) at cursor | O(1) at cursor | High overhead | Rarely useful |
| `HashMap<K,V>` | Hash table | O(1) avg | O(1) avg | O(1) avg | ~2x overhead | Key-value store |
| `BTreeMap<K,V>` | B-tree | O(log n) | O(log n) | O(log n) | ~1.5x overhead | Sorted keys |
| `HashSet<T>` | Hash table | O(1) avg | O(1) avg | O(1) avg | ~2x overhead | Unique items |
| `BTreeSet<T>` | B-tree | O(log n) | O(log n) | O(log n) | ~1.5x overhead | Sorted unique |
| `BinaryHeap<T>` | Binary heap | O(1) max | O(log n) | O(log n) | Compact | Priority queue |

### Trait Requirements

```rust
// HashMap/HashSet require Hash + Eq
use std::collections::HashMap;

#[derive(Hash, Eq, PartialEq)]  // Required traits
struct UserId(u64);

let mut users: HashMap<UserId, String> = HashMap::new();

// BTreeMap/BTreeSet require Ord
use std::collections::BTreeMap;

#[derive(Ord, PartialOrd, Eq, PartialEq)]  // Required traits
struct Priority(u32);

let mut tasks: BTreeMap<Priority, String> = BTreeMap::new();
```

### HashMap Deep Dive

**Default hasher (SipHash) tradeoffs:**

Rust's default `HashMap` uses SipHash-1-3 for DoS protection. This is slower than alternatives but safe for untrusted input.

**Alternative hashers for trusted data:**

```rust
// FxHash - Fastest for integer keys, used by rustc
use rustc_hash::FxHashMap;
let mut map: FxHashMap<u64, String> = FxHashMap::default();

// AHash - Fast with AES hardware acceleration
use ahash::AHashMap;
let mut map: AHashMap<String, i32> = AHashMap::new();

// Drop-in replacement pattern
use rustc_hash::{FxHashMap as HashMap, FxHashSet as HashSet};
```

**Performance comparison (integer keys):**

| Hasher | Relative Speed | DoS Resistant | Best For |
|--------|---------------|---------------|----------|
| SipHash (default) | 1.0x | Yes | Untrusted input |
| FxHash | 2-6x faster | No | Compiler internals, trusted data |
| AHash | 1.5-3x faster | Partial | General high-performance |
| foldhash | 2x faster | No | hashbrown default |

### Vec vs HashMap Crossover

For small collections, linear search in `Vec` beats `HashMap` lookup:

```rust
// Vec is faster for ~15 or fewer items
let small: Vec<(u32, String)> = vec![(1, "a".into()), (2, "b".into())];
let found = small.iter().find(|(k, _)| *k == target);

// HashMap wins at ~15+ items
let large: HashMap<u32, String> = (0..100).map(|i| (i, i.to_string())).collect();
let found = large.get(&target);
```

**Rule of thumb:** If N < 15 and lookups aren't in a hot loop, `Vec` with linear search is simpler and often faster.

### SmallVec, ArrayVec, TinyVec

Stack-allocated vectors for small collections:

```rust
// SmallVec - spills to heap if exceeded
use smallvec::{SmallVec, smallvec};

let mut v: SmallVec<[i32; 8]> = smallvec![1, 2, 3];
v.push(4);  // Still on stack
assert!(!v.spilled());

// Use in collections for cache locality
struct Node {
    children: SmallVec<[NodeId; 4]>,  // Most nodes have <= 4 children
}
```

```rust
// ArrayVec - fixed capacity, never allocates
use arrayvec::ArrayVec;

let mut v: ArrayVec<u32, 16> = ArrayVec::new();
v.push(1);
v.try_push(2).unwrap();  // Returns Result for safety
// v.push() panics if full, try_push() returns Err
```

| Type | Heap Fallback | Use Case |
|------|---------------|----------|
| `SmallVec<[T; N]>` | Yes | Usually small, occasionally large |
| `ArrayVec<T, N>` | No (panics) | Known maximum size |
| `TinyVec<[T; N]>` | Yes | 100% safe, requires `Default` |

**Capacity selection:** Choose N based on the 90th-95th percentile of your actual sizes. Profile to verify benefit.

**Caveats:** SmallVec has overhead checking inline vs heap. Only use when profiling shows benefit - usually in hot paths or `Vec<SmallVec<...>>` for cache locality.

### String Optimization

**&str vs String:**

```rust
let borrowed: &str = "static string";      // No allocation, points to binary
let owned: String = "dynamic".to_string(); // Heap allocation

// Function parameters: prefer &str for maximum flexibility
fn process(s: &str) { /* ... */ }
process("literal");           // Works
process(&owned_string);       // Works
process(&cow_string);         // Works
```

**Cow<str> pattern:**

```rust
use std::borrow::Cow;

fn process(input: &str) -> Cow<str> {
    if input.contains(' ') {
        Cow::Owned(input.replace(' ', "_"))  // Allocates only if needed
    } else {
        Cow::Borrowed(input)  // Zero-cost borrow
    }
}

// Great for APIs that usually return input unchanged
fn normalize(s: &str) -> Cow<str> {
    if s.chars().all(|c| c.is_lowercase()) {
        Cow::Borrowed(s)
    } else {
        Cow::Owned(s.to_lowercase())
    }
}
```

**Inline strings (avoid heap for short strings):**

```rust
use compact_str::CompactString;  // <= 24 bytes inline
use smol_str::SmolStr;           // <= 22 bytes inline, immutable, O(1) clone
use smartstring::alias::String;  // <= 23 bytes inline

// Choose based on:
// - CompactString: mutable, good default
// - SmolStr: immutable, great for interning
// - smartstring: drop-in String replacement
```

### Arena Allocators

Allocate many objects with shared lifetime, free all at once:

```rust
// bumpalo - heterogeneous types, fast allocation
use bumpalo::Bump;

let arena = Bump::new();

// Allocate different types
let num: &mut i32 = arena.alloc(42);
let text: &mut str = arena.alloc_str("hello");
let slice: &mut [u8] = arena.alloc_slice_copy(&[1, 2, 3]);

// All freed when arena drops - no individual Drop calls by default
// Use bumpalo::boxed::Box for types that need Drop
```

```rust
// typed_arena - single type, runs Drop, supports cycles
use typed_arena::Arena;

let arena: Arena<Node> = Arena::new();

let a = arena.alloc(Node { next: None });
let b = arena.alloc(Node { next: Some(a) });
// Supports self-referential structures!
```

**Arena comparison:**

| Crate | Types | Runs Drop | Cycles | Use Case |
|-------|-------|-----------|--------|----------|
| `bumpalo` | Heterogeneous | Optional | With `boxed` | Parsers, compilers |
| `typed_arena` | Single type | Yes | Yes | ASTs, graphs |
| `id_arena` | Single type | Yes | Via IDs | Entity systems |
| `slotmap` | Single type | Yes | Via keys | ECS, generational indices |

### Collection Decision Flowchart

```
What do you need?
|
+-- Sequence?
|   |
|   +-- Random access important? --> Vec
|   +-- Insert/remove both ends? --> VecDeque  
|   +-- Insert/remove middle with cursor? --> LinkedList (rare)
|
+-- Key-value mapping?
|   |
|   +-- Need sorted keys? --> BTreeMap
|   +-- Need range queries? --> BTreeMap
|   +-- Untrusted input? --> HashMap (default SipHash)
|   +-- Trusted input, max speed? --> FxHashMap
|
+-- Unique items?
|   |
|   +-- Need sorted? --> BTreeSet
|   +-- Need fast lookup? --> HashSet / FxHashSet
|
+-- Priority queue? --> BinaryHeap
|
+-- Small fixed-size collection?
|   |
|   +-- Known max size? --> ArrayVec
|   +-- Usually small, might grow? --> SmallVec
|   +-- Need heap fallback safely? --> TinyVec
|
+-- Many short-lived allocations?
    |
    +-- Different types? --> bumpalo
    +-- Single type, need Drop? --> typed_arena
```

---

## 6. Memory Optimization

### Struct Field Ordering

**Largest-first rule:** Order fields from largest to smallest alignment to minimize padding.

```rust
// BAD: Poor alignment (24 bytes with padding)
struct Wasteful {
    a: u8,   // 1 byte + 7 padding
    b: u64,  // 8 bytes
    c: u8,   // 1 byte + 7 padding
}

// GOOD: Largest first (16 bytes)
struct Efficient {
    b: u64,  // 8 bytes
    a: u8,   // 1 byte
    c: u8,   // 1 byte + 6 padding
}

// More complex example
// BAD: 40 bytes with padding
struct WastefulLarge {
    a: u8,      // 1 + 7 padding
    b: u64,     // 8
    c: u8,      // 1 + 7 padding  
    d: u64,     // 8
    e: u16,     // 2 + 6 padding
}

// GOOD: 24 bytes
struct EfficientLarge {
    b: u64,     // 8 bytes
    d: u64,     // 8 bytes
    e: u16,     // 2 bytes
    a: u8,      // 1 byte
    c: u8,      // 1 byte + 4 padding
}
```

**Verify sizes in tests:**

```rust
#[test]
fn check_struct_sizes() {
    assert_eq!(std::mem::size_of::<Efficient>(), 16);
    assert_eq!(std::mem::size_of::<EfficientLarge>(), 24);
}
```

### Enum Size Optimization

**Box large variants:**

```rust
// BAD: Huge variant bloats all variants
enum Message {
    Quit,
    Text(String),
    Data([u8; 1024]),  // Every Message is 1024+ bytes!
}

// GOOD: Box large variants
enum Message {
    Quit,
    Text(String),
    Data(Box<[u8; 1024]>),  // Message is now ~24 bytes
}
```

**Niche optimization:** Rust automatically uses "niches" (invalid bit patterns) to store discriminants:

```rust
// Option<&T> is same size as &T (null pointer optimization)
assert_eq!(
    std::mem::size_of::<Option<&u64>>(),
    std::mem::size_of::<&u64>()
);

// Option<NonZeroU64> is same size as u64
use std::num::NonZeroU64;
assert_eq!(
    std::mem::size_of::<Option<NonZeroU64>>(),
    std::mem::size_of::<u64>()
);
```

**When to Box variants:**
- Variant is > 3x size of smallest variant
- Variant is > 64 bytes
- Enum is used in large collections

### Capacity Pre-allocation

```rust
// BAD: Multiple reallocations
let mut v = Vec::new();
for i in 0..1000 {
    v.push(i);  // Reallocates at 1, 2, 4, 8, 16, 32...
}

// GOOD: Single allocation
let mut v = Vec::with_capacity(1000);
for i in 0..1000 {
    v.push(i);  // No reallocations
}

// Same patterns for other collections
let mut s = String::with_capacity(expected_len);
let mut m: HashMap<K, V> = HashMap::with_capacity(expected_entries);
let mut set: HashSet<T> = HashSet::with_capacity(expected_items);
```

### Buffer Reuse

**clear() pattern:**

```rust
// BAD: Allocation every iteration
for item in &items {
    let mut buffer = Vec::new();  // Allocates
    process_into(item, &mut buffer);
}

// GOOD: Reuse allocation
let mut buffer = Vec::new();
for item in &items {
    buffer.clear();  // Keeps capacity, resets length
    process_into(item, &mut buffer);
}
```

**Object pooling:**

```rust
use std::sync::Mutex;

struct BufferPool {
    buffers: Mutex<Vec<Vec<u8>>>,
}

impl BufferPool {
    fn acquire(&self) -> Vec<u8> {
        self.buffers.lock().unwrap().pop().unwrap_or_else(Vec::new)
    }
    
    fn release(&self, mut buffer: Vec<u8>) {
        buffer.clear();
        self.buffers.lock().unwrap().push(buffer);
    }
}
```

### Lazy Initialization

```rust
use std::sync::LazyLock;

// Initialized on first access, thread-safe
static CONFIG: LazyLock<Config> = LazyLock::new(|| {
    load_config().expect("config required")
});

static REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\d{4}-\d{2}-\d{2}$").expect("valid regex")
});

// Use directly
fn validate_date(s: &str) -> bool {
    REGEX.is_match(s)
}
```

### Allocation Audit Checklist

Before shipping hot path code, check for:

- [ ] Any `Vec::new()` / `String::new()` inside loops?
- [ ] Any `format!()` / `to_string()` inside loops?
- [ ] Any `.clone()` inside loops?
- [ ] Can buffers be reused with `.clear()`?
- [ ] Are collections pre-sized with `with_capacity()`?
- [ ] Are there unnecessary `Box<T>` wrappers?
- [ ] Could `Cow<T>` avoid allocations?

**Tools for finding allocations:**

```rust
// Use DHAT for allocation profiling
// cargo install dhat
// Then in your code:
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

fn main() {
    let _profiler = dhat::Profiler::new_heap();
    // Your code here
}
```

---

## 7. Common Implementation Decisions

### Index-Based Graph Pattern

Self-referential graphs are painful in Rust. Use indices instead:

```rust
// PAINFUL: Self-referential with lifetimes
struct Node<'a> {
    data: i32,
    children: Vec<&'a Node<'a>>,  // Lifetime hell
}

// SIMPLE: Index-based
struct Graph {
    nodes: Vec<NodeData>,
    edges: Vec<(usize, usize)>,  // Indices into nodes
}

struct NodeData {
    value: i32,
}

impl Graph {
    fn add_node(&mut self, value: i32) -> usize {
        let idx = self.nodes.len();
        self.nodes.push(NodeData { value });
        idx
    }
    
    fn add_edge(&mut self, from: usize, to: usize) {
        self.edges.push((from, to));
    }
}
```

**Better: Generational indices with slotmap:**

```rust
use slotmap::{SlotMap, new_key_type};

new_key_type! { struct NodeKey; }

struct Graph {
    nodes: SlotMap<NodeKey, NodeData>,
    edges: Vec<(NodeKey, NodeKey)>,
}

impl Graph {
    fn add_node(&mut self, value: i32) -> NodeKey {
        self.nodes.insert(NodeData { value })
    }
    
    fn get_node(&self, key: NodeKey) -> Option<&NodeData> {
        self.nodes.get(key)  // Returns None if key is stale
    }
}
```

Generational indices prevent use-after-free bugs when nodes are removed.

### BinaryHeap Min-Heap Pattern

`BinaryHeap` is a max-heap by default. For min-heap, use `Reverse`:

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

// Max-heap (default)
let mut max_heap: BinaryHeap<i32> = BinaryHeap::new();
max_heap.push(3);
max_heap.push(1);
max_heap.push(2);
assert_eq!(max_heap.pop(), Some(3));  // Largest first

// Min-heap with Reverse wrapper
let mut min_heap: BinaryHeap<Reverse<i32>> = BinaryHeap::new();
min_heap.push(Reverse(3));
min_heap.push(Reverse(1));
min_heap.push(Reverse(2));
assert_eq!(min_heap.pop(), Some(Reverse(1)));  // Smallest first

// For custom types, implement Ord or use Reverse
#[derive(Eq, PartialEq)]
struct Task {
    priority: u32,
    name: String,
}

impl Ord for Task {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        // Reverse ordering for min-heap behavior
        other.priority.cmp(&self.priority)
    }
}

impl PartialOrd for Task {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}
```

### Interior Mutability Decision Table

| Scenario | Use | Overhead | Thread-Safe |
|----------|-----|----------|-------------|
| Copy type, single thread | `Cell<T>` | Zero | No |
| Non-Copy, single thread | `RefCell<T>` | Runtime borrow check | No |
| Counters/flags | `AtomicUsize`/`AtomicBool` | Lock-free | Yes |
| Complex type, write-heavy | `Mutex<T>` | Lock acquisition | Yes |
| Complex type, read-heavy | `RwLock<T>` | Lock acquisition | Yes |
| Configuration updates | `ArcSwap<T>` | Read: nearly free | Yes |
| Can redesign? | Regular `&mut` | Zero | N/A |

```rust
// Cell - for Copy types, no overhead
use std::cell::Cell;

struct Config {
    retries: Cell<u32>,  // Can mutate through &self
}

impl Config {
    fn increment_retries(&self) {
        self.retries.set(self.retries.get() + 1);
    }
}

// RefCell - for non-Copy, runtime check
use std::cell::RefCell;

struct Cache {
    data: RefCell<HashMap<String, String>>,
}

impl Cache {
    fn get(&self, key: &str) -> Option<String> {
        self.data.borrow().get(key).cloned()
    }
    
    fn insert(&self, key: String, value: String) {
        self.data.borrow_mut().insert(key, value);
    }
}

// Atomics - lock-free counters
use std::sync::atomic::{AtomicU64, Ordering};

struct Metrics {
    requests: AtomicU64,
}

impl Metrics {
    fn inc(&self) {
        self.requests.fetch_add(1, Ordering::Relaxed);
    }
}
```

---

## Quick Reference: When to Use What

### Error Handling

| Situation | Use |
|-----------|-----|
| Library API | `thiserror` with specific enum |
| Application code | `anyhow` with context |
| Performance-critical | Manual `Error` impl |
| Need to match errors | `thiserror` enum variants |
| Just logging errors | `anyhow` |

### Concurrency

| Situation | Use |
|-----------|-----|
| Shared state, message-based | Channels (mpsc, oneshot) |
| Counters, flags | Atomics |
| Config that rarely changes | `Arc<RwLock<T>>` or `watch` |
| Complex state, frequent writes | Actor pattern with channels |
| Avoid at all costs | `Arc<Mutex<T>>` everywhere |

### Collections

| Situation | Use |
|-----------|-----|
| Default sequence | `Vec<T>` |
| Key-value, untrusted input | `HashMap<K, V>` |
| Key-value, trusted input | `FxHashMap<K, V>` |
| Sorted keys or ranges | `BTreeMap<K, V>` |
| Priority queue | `BinaryHeap<T>` |
| Small collection (< 15) | `Vec` with linear search |
| Short strings | `CompactString` or `SmolStr` |

### Smart Pointers

| Situation | Use |
|-----------|-----|
| Single owner | Move / borrow |
| Shared read-only | `Rc<T>` / `Arc<T>` |
| Shared + mutate, single thread | `Rc<RefCell<T>>` |
| Shared + mutate, multi-thread | `Arc<Mutex<T>>` or channels |
| Maybe mutate | `Cow<T>` |

---

## See Also

- **rust-architecture-patterns.md** - Layered error handling, project structure, dependency management
- **rust-performance-optimization.md** - Benchmarking, profiling, zero-copy patterns
