---
name: rust-testing-quality
description: Testing strategies, code quality, security auditing, and production readiness for Rust. Use when writing tests, setting up test infrastructure, creating mocks, auditing dependencies, reviewing code, or preparing for production deployment.
---

# Rust Testing, Quality, and Production Readiness

This document covers testing strategies, code quality practices, security auditing, and production readiness for Rust applications.

## 1. Test Organization

### Directory Structure

Rust has a standard test organization pattern that separates unit tests (inline) from integration tests (external):

```
my-crate/
├── src/
│   ├── lib.rs              # Unit tests inline with #[cfg(test)]
│   ├── module.rs           # Unit tests inline
│   └── submodule/
│       └── mod.rs          # Unit tests inline
├── tests/                  # Integration tests (separate compilation)
│   ├── common/             # Shared test utilities
│   │   └── mod.rs
│   ├── api_tests.rs        # Integration test file
│   └── db_tests.rs         # Integration test file
└── benches/                # Benchmarks (see rust-performance-optimization.md)
    └── performance.rs
```

### Unit vs Integration Test Decisions

| Choose Unit Tests When | Choose Integration Tests When |
|------------------------|------------------------------|
| Testing internal implementation details | Testing public API surface |
| Testing private functions | Testing cross-module interactions |
| Fast feedback during development | Testing database/network integration |
| Testing edge cases of single function | Testing full request/response cycles |
| No external dependencies needed | Require test database or fixtures |

### Test Module Conventions

Unit tests live alongside the code they test:

```rust
// src/discount.rs
pub fn calculate_discount(amount: f64, tier: CustomerTier) -> f64 {
    match tier {
        CustomerTier::Bronze => amount * 0.05,
        CustomerTier::Silver => amount * 0.10,
        CustomerTier::Gold => amount * 0.15,
        CustomerTier::Platinum => amount * 0.20,
    }
}

// Test module is conditionally compiled only during testing
#[cfg(test)]
mod tests {
    use super::*;  // Access parent module's items including private ones
    
    #[test]
    fn bronze_gets_5_percent() {
        assert_eq!(calculate_discount(100.0, CustomerTier::Bronze), 5.0);
    }
    
    #[test]
    fn platinum_gets_20_percent() {
        assert_eq!(calculate_discount(100.0, CustomerTier::Platinum), 20.0);
    }
    
    #[test]
    fn zero_amount_returns_zero() {
        assert_eq!(calculate_discount(0.0, CustomerTier::Gold), 0.0);
    }
}
```

Integration tests go in the `tests/` directory and compile as separate crates:

```rust
// tests/api_tests.rs
use my_crate::public_api;  // Can only access public items

mod common;  // Import shared utilities

#[test]
fn test_full_workflow() {
    let ctx = common::TestContext::new();
    // Test public API
}
```

## 2. Unit Testing

### Basic Assertions

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_equality() {
        let result = add(2, 2);
        assert_eq!(result, 4);  // Equality check
        assert_ne!(result, 5);  // Inequality check
    }
    
    #[test]
    fn test_boolean() {
        let is_valid = validate("input");
        assert!(is_valid);      // True check
        assert!(!is_invalid()); // False check
    }
    
    #[test]
    fn test_with_message() {
        let result = compute(42);
        assert_eq!(
            result, 
            expected,
            "compute(42) should return {}, got {}", 
            expected, 
            result
        );
    }
    
    #[test]
    fn test_floating_point() {
        let result = calculate_pi();
        // Use approximate comparison for floats
        assert!((result - 3.14159).abs() < 0.0001);
    }
}
```

### Testing Results

Tests can return `Result<(), E>` to use the `?` operator:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_with_result() -> Result<(), Error> {
        let result = fallible_function()?;
        assert!(result > 0);
        Ok(())
    }
    
    #[test]
    fn test_expected_error() {
        let result = parse_invalid_input("bad");
        assert!(result.is_err());
        
        // Assert specific error type/message
        let err = result.unwrap_err();
        assert!(matches!(err, ParseError::InvalidFormat(_)));
    }
    
    #[test]
    fn test_error_message() {
        let result = validate("");
        let err = result.unwrap_err();
        assert_eq!(err.to_string(), "input cannot be empty");
    }
}
```

### Testing Panics

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    #[should_panic]
    fn test_panics() {
        divide(1, 0);  // Should panic
    }
    
    #[test]
    #[should_panic(expected = "divide by zero")]
    fn test_panic_message() {
        divide(1, 0);  // Should panic with specific message
    }
    
    #[test]
    #[should_panic(expected = "index out of bounds")]
    fn test_bounds_check() {
        let v = vec![1, 2, 3];
        let _ = v[10];  // Should panic with bounds message
    }
}
```

### Testing Private Functions

The `#[cfg(test)]` module has access to private items in the parent module:

```rust
// src/parser.rs

// Private function - not accessible from outside this module
fn normalize_input(s: &str) -> String {
    s.trim().to_lowercase()
}

pub fn parse(input: &str) -> Result<Value, ParseError> {
    let normalized = normalize_input(input);
    // ... parsing logic
}

#[cfg(test)]
mod tests {
    use super::*;
    
    // Can test private functions directly
    #[test]
    fn test_normalize_input() {
        assert_eq!(normalize_input("  HELLO  "), "hello");
        assert_eq!(normalize_input("World"), "world");
    }
}
```

## 3. Async Testing

### #[tokio::test]

For async tests, use `#[tokio::test]` from the tokio crate:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_async_operation() {
        let result = async_function().await;
        assert!(result.is_ok());
    }
    
    // With specific runtime configuration
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn test_concurrent_operations() {
        let (a, b) = tokio::join!(
            task_one(),
            task_two()
        );
        assert!(a.is_ok());
        assert!(b.is_ok());
    }
    
    // Current thread runtime (default, faster for simple tests)
    #[tokio::test(flavor = "current_thread")]
    async fn test_simple_async() {
        let result = simple_async_fn().await;
        assert_eq!(result, 42);
    }
    
    // Control start_paused for time-sensitive tests
    #[tokio::test(start_paused = true)]
    async fn test_with_time_control() {
        let start = tokio::time::Instant::now();
        tokio::time::advance(Duration::from_secs(60)).await;
        assert!(start.elapsed() >= Duration::from_secs(60));
    }
}
```

### Timeouts in Tests

Prevent tests from hanging indefinitely:

```rust
#[cfg(test)]
mod tests {
    use tokio::time::{timeout, Duration};
    
    #[tokio::test]
    async fn test_with_timeout() {
        let result = timeout(
            Duration::from_secs(5),
            potentially_slow_operation()
        ).await;
        
        // Result is Ok(inner_result) if completed, Err(_) if timed out
        let inner = result.expect("operation timed out");
        assert!(inner.is_ok());
    }
    
    #[tokio::test]
    async fn test_expects_timeout() {
        let result = timeout(
            Duration::from_millis(100),
            never_completes()
        ).await;
        
        assert!(result.is_err(), "should have timed out");
    }
}
```

## 4. Integration Testing

### Test Utilities Module

Create shared utilities in `tests/common/mod.rs`:

```rust
// tests/common/mod.rs
use my_crate::*;
use sqlx::PgPool;

/// Test context providing access to all test resources
pub struct TestContext {
    pub db: TestDatabase,
    pub app: App,
}

impl TestContext {
    pub async fn new() -> Self {
        let db = TestDatabase::new().await;
        let app = App::new_for_testing(db.pool()).await;
        Self { db, app }
    }
    
    /// Builder method to add a user to the context
    pub async fn with_user(mut self, user: User) -> Self {
        self.app.user_repo().save(&user).await.unwrap();
        self
    }
    
    /// Builder method to configure test state
    pub async fn with_config(mut self, config: TestConfig) -> Self {
        self.app.apply_config(config).await;
        self
    }
}

// Optional: impl Drop for cleanup if needed
```

### Test Database Pattern

Isolated databases ensure tests don't interfere with each other:

```rust
// tests/common/mod.rs
pub struct TestDatabase {
    pool: PgPool,
    db_name: String,
}

impl TestDatabase {
    pub async fn new() -> Self {
        // Generate unique database name
        let db_name = format!(
            "test_{}", 
            uuid::Uuid::new_v4().to_string().replace("-", "")
        );
        
        // Connect to postgres to create test database
        let admin_pool = PgPool::connect("postgres://localhost/postgres")
            .await
            .expect("Failed to connect to postgres");
        
        sqlx::query(&format!("CREATE DATABASE {}", db_name))
            .execute(&admin_pool)
            .await
            .expect("Failed to create test database");
        
        // Connect to test database
        let pool = PgPool::connect(&format!("postgres://localhost/{}", db_name))
            .await
            .expect("Failed to connect to test database");
        
        // Run migrations
        sqlx::migrate!("./migrations")
            .run(&pool)
            .await
            .expect("Failed to run migrations");
        
        Self { pool, db_name }
    }
    
    pub fn pool(&self) -> PgPool {
        self.pool.clone()
    }
    
    /// Seed test data
    pub async fn seed(&self, data: &TestData) -> &Self {
        for user in &data.users {
            sqlx::query("INSERT INTO users (id, email, name) VALUES ($1, $2, $3)")
                .bind(&user.id)
                .bind(&user.email)
                .bind(&user.name)
                .execute(&self.pool)
                .await
                .unwrap();
        }
        self
    }
}

impl Drop for TestDatabase {
    fn drop(&mut self) {
        // Note: Async drop is tricky. Options:
        // 1. Use a blocking runtime handle
        // 2. Leave databases (clean up periodically)
        // 3. Use a test database pool manager
        
        // Simple approach: spawn blocking cleanup
        let db_name = self.db_name.clone();
        std::thread::spawn(move || {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let pool = PgPool::connect("postgres://localhost/postgres")
                    .await
                    .ok();
                if let Some(pool) = pool {
                    let _ = sqlx::query(&format!(
                        "DROP DATABASE IF EXISTS {} WITH (FORCE)", 
                        db_name
                    ))
                    .execute(&pool)
                    .await;
                }
            });
        });
    }
}
```

### Test Fixtures with Builder Pattern

Create test data using builder patterns:

```rust
// tests/common/fixtures.rs
pub struct UserBuilder {
    id: Option<UserId>,
    email: String,
    name: String,
    role: Role,
    active: bool,
}

impl UserBuilder {
    pub fn new() -> Self {
        Self {
            id: None,
            email: format!("user_{}@test.com", uuid::Uuid::new_v4()),
            name: "Test User".to_string(),
            role: Role::User,
            active: true,
        }
    }
    
    pub fn id(mut self, id: UserId) -> Self {
        self.id = Some(id);
        self
    }
    
    pub fn email(mut self, email: impl Into<String>) -> Self {
        self.email = email.into();
        self
    }
    
    pub fn name(mut self, name: impl Into<String>) -> Self {
        self.name = name.into();
        self
    }
    
    pub fn admin(mut self) -> Self {
        self.role = Role::Admin;
        self
    }
    
    pub fn inactive(mut self) -> Self {
        self.active = false;
        self
    }
    
    pub fn build(self) -> User {
        User {
            id: self.id.unwrap_or_else(UserId::new),
            email: Email::new(&self.email).unwrap(),
            name: self.name,
            role: self.role,
            active: self.active,
        }
    }
}

impl Default for UserBuilder {
    fn default() -> Self {
        Self::new()
    }
}

// Usage in tests
#[tokio::test]
async fn test_user_creation() {
    let admin = UserBuilder::new()
        .email("admin@example.com")
        .name("Admin User")
        .admin()
        .build();
    
    let inactive_user = UserBuilder::new()
        .inactive()
        .build();
    
    // ... test logic
}
```

## 5. Mocking Strategies

### Manual Mock Implementations

Create mock implementations that implement the same traits as production code:

```rust
// In production code or tests/common/mocks.rs
#[cfg(test)]
pub mod mocks {
    use super::*;
    use std::sync::Mutex;
    use std::collections::HashMap;
    
    /// Mock repository that stores data in memory
    #[derive(Default)]
    pub struct MockUserRepository {
        users: Mutex<HashMap<UserId, User>>,
        save_calls: Mutex<Vec<User>>,
        should_fail: Mutex<bool>,
    }
    
    #[async_trait]
    impl UserRepository for MockUserRepository {
        async fn find_by_id(&self, id: UserId) -> Result<Option<User>> {
            if *self.should_fail.lock().unwrap() {
                return Err(Error::Database("mock failure".into()));
            }
            Ok(self.users.lock().unwrap().get(&id).cloned())
        }
        
        async fn save(&self, user: &User) -> Result<()> {
            if *self.should_fail.lock().unwrap() {
                return Err(Error::Database("mock failure".into()));
            }
            self.users.lock().unwrap().insert(user.id, user.clone());
            self.save_calls.lock().unwrap().push(user.clone());
            Ok(())
        }
        
        async fn delete(&self, id: UserId) -> Result<()> {
            self.users.lock().unwrap().remove(&id);
            Ok(())
        }
        
        async fn find_all(&self) -> Result<Vec<User>> {
            Ok(self.users.lock().unwrap().values().cloned().collect())
        }
    }
    
    impl MockUserRepository {
        pub fn new() -> Self {
            Self::default()
        }
        
        /// Pre-populate with a user
        pub fn with_user(self, user: User) -> Self {
            self.users.lock().unwrap().insert(user.id, user);
            self
        }
        
        /// Configure to fail on next operation
        pub fn fail_next(&self) {
            *self.should_fail.lock().unwrap() = true;
        }
        
        /// Check if save was called with specific user
        pub fn save_was_called_with(&self, user_id: UserId) -> bool {
            self.save_calls.lock().unwrap()
                .iter()
                .any(|u| u.id == user_id)
        }
        
        /// Get number of save calls
        pub fn save_call_count(&self) -> usize {
            self.save_calls.lock().unwrap().len()
        }
        
        /// Get all saved users
        pub fn get_saved_users(&self) -> Vec<User> {
            self.save_calls.lock().unwrap().clone()
        }
    }
}

// Usage in tests
#[tokio::test]
async fn test_user_service_creates_user() {
    let mock_repo = MockUserRepository::new();
    let service = UserService::new(Arc::new(mock_repo.clone()));
    
    let user = UserBuilder::new().build();
    service.create(user.clone()).await.unwrap();
    
    assert!(mock_repo.save_was_called_with(user.id));
    assert_eq!(mock_repo.save_call_count(), 1);
}

#[tokio::test]
async fn test_handles_repository_failure() {
    let mock_repo = MockUserRepository::new();
    mock_repo.fail_next();
    
    let service = UserService::new(Arc::new(mock_repo));
    let result = service.create(UserBuilder::new().build()).await;
    
    assert!(result.is_err());
}
```

### Mock Clock Pattern

Test time-dependent code deterministically:

```rust
// Define a Clock trait in production code
pub trait Clock: Send + Sync {
    fn now(&self) -> DateTime<Utc>;
}

// Production implementation
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }
}

// Mock implementation for tests
#[cfg(test)]
pub mod mocks {
    use super::*;
    use std::sync::Mutex;
    
    pub struct MockClock {
        now: Mutex<DateTime<Utc>>,
    }
    
    impl MockClock {
        pub fn fixed(time: DateTime<Utc>) -> Self {
            Self { now: Mutex::new(time) }
        }
        
        pub fn advance(&self, duration: chrono::Duration) {
            let mut now = self.now.lock().unwrap();
            *now = *now + duration;
        }
        
        pub fn set(&self, time: DateTime<Utc>) {
            *self.now.lock().unwrap() = time;
        }
    }
    
    impl Clock for MockClock {
        fn now(&self) -> DateTime<Utc> {
            *self.now.lock().unwrap()
        }
    }
}

// Usage in production code
pub struct TokenService<C: Clock> {
    clock: C,
    ttl: Duration,
}

impl<C: Clock> TokenService<C> {
    pub fn is_token_valid(&self, token: &Token) -> bool {
        token.expires_at > self.clock.now()
    }
}

// Usage in tests
#[test]
fn test_token_expiration() {
    let fixed_time = Utc.with_ymd_and_hms(2024, 1, 1, 12, 0, 0).unwrap();
    let clock = MockClock::fixed(fixed_time);
    let service = TokenService { 
        clock: clock.clone(), 
        ttl: Duration::hours(1) 
    };
    
    let token = Token {
        expires_at: fixed_time + Duration::minutes(30),
        // ...
    };
    
    assert!(service.is_token_valid(&token));
    
    // Advance time past expiration
    clock.advance(Duration::hours(1));
    assert!(!service.is_token_valid(&token));
}
```

### When to Mock vs Use Real Implementations

| Use Mocks | Use Real Implementations |
|-----------|--------------------------|
| External HTTP APIs | In-memory databases (SQLite) |
| Third-party services | File system operations (tempdir) |
| Time-dependent operations | Pure business logic |
| Non-deterministic behavior | Fast, deterministic dependencies |
| Expensive operations | Stable internal components |
| Testing error conditions | End-to-end integration tests |

**Rule of thumb**: Mock at boundaries (network, time, external services), use real implementations for internal components.

## 6. Test Fixtures with rstest

The `rstest` crate provides powerful fixture and parameterization support.

```toml
# Cargo.toml
[dev-dependencies]
rstest = "0.18"
```

### #[fixture] Attribute

Create reusable test fixtures:

```rust
use rstest::{fixture, rstest};

#[fixture]
fn valid_user() -> User {
    User {
        id: UserId::new(),
        email: Email::new("test@example.com").unwrap(),
        name: "Test User".into(),
    }
}

#[fixture]
fn admin_user() -> User {
    User {
        id: UserId::new(),
        email: Email::new("admin@example.com").unwrap(),
        name: "Admin User".into(),
    }
}

// Fixtures can depend on other fixtures
#[fixture]
fn user_with_orders(valid_user: User) -> (User, Vec<Order>) {
    let orders = vec![
        Order::new(valid_user.id, 100.0),
        Order::new(valid_user.id, 200.0),
    ];
    (valid_user, orders)
}

#[rstest]
fn test_user_can_place_order(valid_user: User) {
    // valid_user is automatically injected
    assert!(valid_user.can_place_order());
}

#[rstest]
fn test_admin_has_elevated_privileges(admin_user: User) {
    // Uses the admin_user fixture
    assert!(admin_user.email.as_str().contains("admin"));
}
```

### Parameterized Tests

Test multiple cases with a single test function:

```rust
use rstest::rstest;

#[rstest]
#[case("valid@email.com", true)]
#[case("also.valid@domain.org", true)]
#[case("with+plus@email.com", true)]
#[case("invalid", false)]
#[case("@no-local.com", false)]
#[case("no-domain@", false)]
#[case("", false)]
fn test_email_validation(#[case] input: &str, #[case] expected_valid: bool) {
    assert_eq!(Email::new(input).is_ok(), expected_valid);
}

// Matrix testing - all combinations
#[rstest]
fn test_discount_calculation(
    #[values(100.0, 500.0, 1000.0)] amount: f64,
    #[values(
        CustomerTier::Bronze, 
        CustomerTier::Silver, 
        CustomerTier::Gold
    )] tier: CustomerTier,
) {
    let discount = calculate_discount(amount, tier);
    assert!(discount >= 0.0);
    assert!(discount <= amount);
}
```

### Async Fixtures

Use `#[future]` for async fixtures:

```rust
use rstest::{fixture, rstest};

#[fixture]
async fn app_context() -> TestContext {
    TestContext::new().await
}

#[fixture]
async fn seeded_context(#[future] app_context: TestContext) -> TestContext {
    let ctx = app_context.await;
    ctx.db.seed(&default_test_data()).await;
    ctx
}

#[rstest]
#[tokio::test]
async fn test_user_registration(
    #[future] app_context: TestContext,
    valid_user: User,
) {
    let ctx = app_context.await;
    let result = ctx.app.user_service().register(valid_user.clone()).await;
    assert!(result.is_ok());
}

#[rstest]
#[tokio::test]
async fn test_with_seeded_data(#[future] seeded_context: TestContext) {
    let ctx = seeded_context.await;
    let users = ctx.app.user_service().list_all().await.unwrap();
    assert!(!users.is_empty());
}
```

## 7. Property-Based Testing

Property-based testing generates random inputs to find edge cases you might not think of.

```toml
# Cargo.toml
[dev-dependencies]
proptest = "1.4"
```

### proptest Setup and Macro

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_roundtrip(s in "\\PC*") {
        // Any printable string
        let encoded = encode(&s);
        let decoded = decode(&encoded)?;
        prop_assert_eq!(s, decoded);
    }
    
    #[test]
    fn test_sort_is_idempotent(mut v: Vec<i32>) {
        v.sort();
        let sorted = v.clone();
        v.sort();
        prop_assert_eq!(v, sorted);
    }
    
    #[test]
    fn test_reverse_reverse_is_identity(v: Vec<i32>) {
        let mut reversed = v.clone();
        reversed.reverse();
        reversed.reverse();
        prop_assert_eq!(v, reversed);
    }
}
```

### Custom Strategies

Generate complex test data:

```rust
use proptest::prelude::*;

fn any_user() -> impl Strategy<Value = User> {
    (
        any::<u64>(),                              // ID
        "[a-z]{1,20}@[a-z]{1,10}\\.[a-z]{2,4}",   // Email regex
        "[A-Za-z ]{1,50}",                         // Name
    ).prop_map(|(id, email, name)| User {
        id: UserId(id),
        email: Email::new(&email).unwrap(),
        name,
    })
}

fn any_customer_tier() -> impl Strategy<Value = CustomerTier> {
    prop_oneof![
        Just(CustomerTier::Bronze),
        Just(CustomerTier::Silver),
        Just(CustomerTier::Gold),
        Just(CustomerTier::Platinum),
    ]
}

fn any_order(user_id: UserId) -> impl Strategy<Value = Order> {
    (
        0.01f64..1_000_000.0,  // Amount range
        any_customer_tier(),
    ).prop_map(move |(amount, tier)| Order {
        id: OrderId::new(),
        user_id,
        amount,
        tier,
    })
}

proptest! {
    #[test]
    fn test_serialization_roundtrip(user in any_user()) {
        let json = serde_json::to_string(&user).unwrap();
        let restored: User = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(user, restored);
    }
    
    #[test]
    fn test_discount_never_exceeds_amount(
        amount in 0.0f64..1_000_000.0,
        tier in any_customer_tier()
    ) {
        let discount = calculate_discount(amount, tier);
        prop_assert!(discount <= amount);
        prop_assert!(discount >= 0.0);
    }
}
```

### Common Property Patterns

**Roundtrip (encode/decode, serialize/deserialize):**

```rust
proptest! {
    #[test]
    fn json_roundtrip(user in any_user()) {
        let json = serde_json::to_string(&user)?;
        let restored: User = serde_json::from_str(&json)?;
        prop_assert_eq!(user, restored);
    }
    
    #[test]
    fn base64_roundtrip(data: Vec<u8>) {
        let encoded = base64::encode(&data);
        let decoded = base64::decode(&encoded)?;
        prop_assert_eq!(data, decoded);
    }
}
```

**Idempotence (same result when applied twice):**

```rust
proptest! {
    #[test]
    fn normalize_is_idempotent(s in ".*") {
        let once = normalize(&s);
        let twice = normalize(&once);
        prop_assert_eq!(once, twice);
    }
    
    #[test]
    fn sort_is_idempotent(mut v: Vec<i32>) {
        v.sort();
        let sorted = v.clone();
        v.sort();
        prop_assert_eq!(v, sorted);
    }
}
```

**Invariant preservation:**

```rust
proptest! {
    #[test]
    fn balance_never_negative(
        initial in 0u64..1_000_000,
        operations in prop::collection::vec(any_operation(), 0..100)
    ) {
        let mut account = Account::new(initial);
        for op in operations {
            let _ = account.apply(op);  // Ignore errors
        }
        prop_assert!(account.balance() >= 0);
    }
    
    #[test]
    fn set_operations_maintain_uniqueness(
        ops in prop::collection::vec(
            prop_oneof![
                any::<i32>().prop_map(SetOp::Insert),
                any::<i32>().prop_map(SetOp::Remove),
            ],
            0..100
        )
    ) {
        let mut set = HashSet::new();
        for op in ops {
            match op {
                SetOp::Insert(v) => { set.insert(v); }
                SetOp::Remove(v) => { set.remove(&v); }
            }
        }
        // Set should have no duplicates (invariant of HashSet)
        let vec: Vec<_> = set.iter().collect();
        let deduped: HashSet<_> = vec.iter().collect();
        prop_assert_eq!(vec.len(), deduped.len());
    }
}
```

## 8. cargo-nextest

cargo-nextest is a modern test runner that's faster and more feature-rich than `cargo test`.

### Why nextest Over cargo test

| Feature | cargo test | cargo-nextest |
|---------|------------|---------------|
| Parallelism | Thread-based | Process-based (better isolation) |
| Speed | Baseline | Up to 3x faster |
| Flaky test detection | No | Yes (automatic) |
| Retry support | No | Yes |
| Per-test timeouts | No | Yes |
| Output formatting | Basic | Enhanced |
| JUnit XML output | No | Yes (for CI) |
| Test filtering | Basic | Powerful expressions |

### Installation and Usage

```bash
# Install
cargo install cargo-nextest

# Run all tests
cargo nextest run

# Run with retries for flaky tests
cargo nextest run --retries 2

# Run specific tests
cargo nextest run -E 'test(/integration/)'
cargo nextest run -E 'test(user) & !test(slow)'

# Run tests from specific package
cargo nextest run -p my-crate

# Show slow tests
cargo nextest run --slow-timeout 5s

# List tests without running
cargo nextest list
```

### Configuration

Create `.config/nextest.toml` in your project root:

```toml
[profile.default]
# Don't retry by default
retries = 0
# Stop on first failure
fail-fast = true
# Default timeout per test
slow-timeout = { period = "60s", terminate-after = 2 }

[profile.ci]
# Retry flaky tests in CI
retries = 2
# Don't stop on first failure in CI
fail-fast = false
# Generate JUnit report
junit.path = "target/nextest/ci/junit.xml"

[profile.default.overrides]
# Give integration tests more time
"kind(test) & test(/integration/)" = { slow-timeout = "120s" }

# Mark known flaky tests
"test(flaky_network_test)" = { retries = 3 }
```

### CI Integration

```yaml
# GitHub Actions
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: dtolnay/rust-action@stable
      
      - name: Install nextest
        uses: taiki-e/install-action@nextest
      
      - name: Run tests
        run: cargo nextest run --profile ci
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: target/nextest/ci/junit.xml
```

### Limitations

**Doctests still require cargo test:**

```bash
# nextest doesn't support doctests
cargo nextest run  # Runs unit and integration tests

# Run doctests separately
cargo test --doc
```

**Typical CI workflow:**

```bash
# Run both
cargo nextest run && cargo test --doc
```

## 9. Supply Chain Security

### cargo-audit

Scan for known vulnerabilities in the RustSec Advisory Database:

```bash
# Install
cargo install cargo-audit

# Check for vulnerabilities
cargo audit

# Output JSON for programmatic use
cargo audit --json

# Ignore specific advisories (with reason)
cargo audit --ignore RUSTSEC-2020-0071
```

**CI Integration:**

```yaml
- name: Security audit
  run: cargo audit
```

### cargo-deny

Comprehensive dependency policy enforcement:

```bash
# Install
cargo install cargo-deny

# Initialize configuration
cargo deny init

# Run all checks
cargo deny check

# Run specific checks
cargo deny check licenses
cargo deny check advisories
cargo deny check bans
cargo deny check sources
```

**Configuration (`deny.toml`):**

```toml
# deny.toml - Comprehensive policy configuration

[advisories]
# Deny any crate with known vulnerabilities
vulnerability = "deny"
# Warn about unmaintained crates
unmaintained = "warn"
# Deny yanked crates
yanked = "deny"
# Warn about security notices
notice = "warn"

[licenses]
# Don't allow unlicensed crates
unlicensed = "deny"
# Copyleft crates need explicit approval
copyleft = "warn"
# Allowed licenses
allow = [
    "MIT",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Zlib",
    "MPL-2.0",
    "Unicode-DFS-2016",
]
# Confidence threshold for license detection
confidence-threshold = 0.8

[bans]
# Warn about multiple versions of same crate
multiple-versions = "warn"
# Deny wildcard dependencies
wildcards = "deny"
# Highlight specific crates to avoid
deny = [
    # Prefer rustls over OpenSSL
    { name = "openssl" },
    { name = "openssl-sys" },
]
# Skip duplicate checking for specific crates
skip = [
    # Allow multiple versions of these (common in dep trees)
    { name = "syn", version = "1" },
]

[sources]
# Don't allow crates from unknown registries
unknown-registry = "deny"
# Don't allow crates from unknown git repos
unknown-git = "deny"
# Only allow crates.io
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
# Specific git repos can be allowed
# allow-git = []
```

### cargo-auditable

Embed dependency information in compiled binaries for production auditing:

```bash
# Install
cargo install cargo-auditable

# Build with embedded dependency info (~4KB overhead)
cargo auditable build --release

# The binary now contains dependency metadata
rust-audit-info target/release/myapp

# Audit the compiled binary
cargo audit bin target/release/myapp

# Audit deployed binaries without source access
cargo audit bin /path/to/deployed/binary
```

**Why this matters:** You can audit production binaries without needing access to source code or Cargo.lock, enabling security scanning of deployed applications.

### Security Audit Pipeline

Complete CI workflow for supply chain security:

```yaml
# .github/workflows/security.yml
name: Security Audit

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    # Run daily to catch new vulnerabilities
    - cron: '0 0 * * *'

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: dtolnay/rust-action@stable
      
      - name: Install security tools
        run: cargo install cargo-audit cargo-deny
      
      - name: Vulnerability scan
        run: cargo audit
      
      - name: Policy check
        run: cargo deny check licenses advisories sources bans
      
      - name: Build auditable binary
        run: |
          cargo install cargo-auditable
          cargo auditable build --release
      
      - name: Audit binary
        run: cargo audit bin target/release/myapp
```

## 10. Unsafe Code Guidelines

### When Unsafe is Appropriate

Unsafe Rust is necessary for:

| Use Case | Example | Justification |
|----------|---------|---------------|
| FFI | Calling C libraries | No safe alternative |
| Performance | Custom allocators | Verified performance benefit |
| Hardware access | Memory-mapped I/O | No safe abstraction available |
| Self-referential structs | Pin-based types | Compiler can't verify safety |
| Implementing safe abstractions | `Vec<T>` internals | Building blocks for safe code |

**Never use unsafe for:**
- "Just to make it compile"
- Convenience when safe alternatives exist
- Avoiding borrow checker without understanding why

### Safety Documentation

Every unsafe function must document safety requirements:

```rust
/// Reads a slice from a raw pointer.
///
/// # Safety
///
/// - `ptr` must be valid for reads of `len * size_of::<T>()` bytes
/// - `ptr` must be properly aligned for type `T`
/// - `ptr` must point to `len` consecutive properly initialized values of type `T`
/// - The memory must not be mutated for the duration of the returned lifetime
/// - The total size `len * size_of::<T>()` must be no larger than `isize::MAX`
pub unsafe fn read_slice<'a, T>(ptr: *const T, len: usize) -> &'a [T] {
    // SAFETY: Caller guarantees all requirements above
    std::slice::from_raw_parts(ptr, len)
}
```

Within unsafe blocks, use `SAFETY` comments:

```rust
pub fn get_unchecked(&self, index: usize) -> &T {
    debug_assert!(index < self.len, "index out of bounds");
    
    // SAFETY: 
    // - Caller must ensure index < self.len (checked in debug mode)
    // - self.ptr is valid for self.len elements (invariant of this type)
    // - The element at index is initialized (invariant of this type)
    unsafe { &*self.ptr.add(index) }
}
```

### Minimizing Unsafe Surface

Wrap unsafe code in safe abstractions:

```rust
// Internal unsafe implementation
mod internal {
    pub struct RawBuffer {
        ptr: *mut u8,
        len: usize,
        capacity: usize,
    }
    
    impl RawBuffer {
        /// # Safety
        /// Caller must ensure capacity > 0
        pub unsafe fn new(capacity: usize) -> Self {
            let layout = std::alloc::Layout::array::<u8>(capacity).unwrap();
            let ptr = std::alloc::alloc(layout);
            if ptr.is_null() {
                std::alloc::handle_alloc_error(layout);
            }
            Self { ptr, len: 0, capacity }
        }
        
        // Other unsafe methods...
    }
}

// Safe public API
pub struct Buffer {
    inner: internal::RawBuffer,
}

impl Buffer {
    pub fn new(capacity: usize) -> Self {
        assert!(capacity > 0, "capacity must be positive");
        // SAFETY: We verified capacity > 0
        Self { inner: unsafe { internal::RawBuffer::new(capacity) } }
    }
    
    pub fn push(&mut self, byte: u8) {
        // Safe implementation that maintains invariants
    }
    
    pub fn as_slice(&self) -> &[u8] {
        // Safe accessor
    }
}
```

### Verification Tools

**Miri - Undefined behavior detector:**

```bash
# Install Miri
rustup +nightly component add miri

# Run tests under Miri
cargo +nightly miri test

# Run specific test
cargo +nightly miri test test_unsafe_code

# With more checks
MIRIFLAGS="-Zmiri-strict-provenance" cargo +nightly miri test
```

Miri detects:
- Use of uninitialized memory
- Use after free
- Double free
- Memory leaks (with flag)
- Invalid pointer arithmetic
- Data races (in some cases)

**Address Sanitizer:**

```bash
# Requires nightly
RUSTFLAGS="-Z sanitizer=address" cargo +nightly test
```

**Fuzzing with cargo-fuzz:**

```bash
# Install
cargo install cargo-fuzz

# Initialize fuzzing
cargo fuzz init

# Write a fuzz target
# fuzz/fuzz_targets/my_target.rs
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // Call your unsafe code with arbitrary input
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = my_crate::parse(s);
    }
});

# Run fuzzer
cargo +nightly fuzz run my_target
```

### Clippy Lints for Unsafe

Enable strict unsafe lints in `Cargo.toml`:

```toml
[lints.rust]
unsafe_code = "warn"  # or "forbid" for no unsafe at all
# unsafe_op_in_unsafe_fn = "warn"  # Requires explicit unsafe blocks

[lints.clippy]
# Unsafe-related lints
undocumented_unsafe_blocks = "deny"
multiple_unsafe_ops_per_block = "warn"
ptr_as_ptr = "warn"
ptr_cast_constness = "warn"
```

For crates that must use unsafe, document why at the crate level:

```rust
// lib.rs
#![deny(unsafe_op_in_unsafe_fn)]  // Require unsafe blocks even in unsafe fns
#![warn(clippy::undocumented_unsafe_blocks)]

//! # Safety
//! 
//! This crate uses unsafe code for FFI bindings to libfoo.
//! All unsafe code is encapsulated in the `ffi` module with safe wrappers
//! exposed in the public API.
```

See `rust-cli-desktop-systems.md` for detailed FFI patterns and safety considerations.

## 11. Anti-Patterns Reference

### Structural Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| **God Objects** | Single struct/module handles too many responsibilities | Split by single responsibility principle |
| **Circular Dependencies** | Module A depends on B, B depends on A | Extract shared code to third module C |
| **Leaky Abstractions** | Internal types exposed in public API | Use facade pattern, re-exports |
| **Premature Abstraction** | Creating traits/generics before patterns emerge | Start concrete, abstract when you have 3+ similar cases |
| **Deep Nesting** | Callbacks within callbacks within callbacks | Use async/await, extract to functions |
| **Feature Creep Modules** | Module grows unboundedly with new features | Split by domain boundaries |

### Code Anti-Patterns

**Stringly-Typed APIs:**

```rust
// BAD: Stringly-typed
fn process(action: &str, target: &str) -> Result<String, Error> {
    match action {
        "create" => { /* ... */ }
        "delete" => { /* ... */ }
        _ => Err(Error::InvalidAction),  // Runtime error
    }
}

// GOOD: Type-safe
enum Action { Create, Delete }
struct Target(String);

fn process(action: Action, target: Target) -> Result<Response, Error> {
    match action {
        Action::Create => { /* ... */ }
        Action::Delete => { /* ... */ }
        // Exhaustive - compiler ensures all cases handled
    }
}
```

**Boolean Blindness:**

```rust
// BAD: What do these booleans mean at call site?
fn process(input: &str, validate: bool, cache: bool, async_mode: bool) { }

// Call site is unreadable:
process("data", true, false, true);

// GOOD: Self-documenting with enums
struct ProcessOptions {
    validation: ValidationMode,
    caching: CacheStrategy,
    execution: ExecutionMode,
}

enum ValidationMode { Strict, Lenient, Skip }
enum CacheStrategy { Always, Never, IfFresh }
enum ExecutionMode { Sync, Async }

fn process(input: &str, options: ProcessOptions) { }

// Call site is clear:
process("data", ProcessOptions {
    validation: ValidationMode::Strict,
    caching: CacheStrategy::Never,
    execution: ExecutionMode::Async,
});
```

**Panic-Happy Code:**

```rust
// BAD: Panics on invalid input
fn get_user(id: &str) -> User {
    let id: u64 = id.parse().unwrap();  // Panic if not number
    USERS.get(&id).unwrap().clone()      // Panic if not found
}

// GOOD: Return Result with descriptive errors
fn get_user(id: &str) -> Result<User, GetUserError> {
    let id: u64 = id.parse()
        .map_err(|_| GetUserError::InvalidId(id.to_string()))?;
    USERS.get(&id)
        .cloned()
        .ok_or(GetUserError::NotFound(id))
}
```

**Clone Everywhere:**

```rust
// BAD: Cloning to satisfy borrow checker indicates design issue
fn process(data: Data) {
    step1(data.clone());
    step2(data.clone());
    step3(data);
}

// GOOD: Borrow when possible
fn process(data: &Data) {
    step1(data);
    step2(data);
    step3(data);
}

// Or restructure to pass ownership through pipeline
fn process(data: Data) -> Result<Output, Error> {
    let data = step1(data)?;
    let data = step2(data)?;
    step3(data)
}
```

**Glob Imports:**

```rust
// BAD: Unclear where symbols come from, potential conflicts
use some_module::*;
use another_module::*;

// GOOD: Explicit imports
use some_module::{TypeA, TypeB, function_a};
use another_module::TypeC;

// Exception: Preludes are designed for glob import
use std::io::prelude::*;
use my_crate::prelude::*;
```

**Overusing Trait Objects:**

```rust
// BAD: Dynamic dispatch when not needed
fn process(handler: &dyn Handler) {
    handler.handle();
}

// GOOD: Static dispatch when types are known at compile time
fn process<H: Handler>(handler: &H) {
    handler.handle();
}

// Trait objects are appropriate for:
// - Heterogeneous collections: Vec<Box<dyn Handler>>
// - Plugin systems where types are unknown at compile time
// - Reducing binary size (one implementation vs many monomorphized)
```

**Ignoring Pattern Matching Power:**

```rust
// BAD: Nested if/else is hard to follow
fn handle(result: Option<Result<User, Error>>) {
    if let Some(inner) = result {
        if let Ok(user) = inner {
            if user.is_active {
                println!("Active: {}", user.name);
            }
        }
    }
}

// GOOD: Pattern matching with guards
fn handle(result: Option<Result<User, Error>>) {
    match result {
        Some(Ok(user)) if user.is_active => {
            println!("Active: {}", user.name);
        }
        Some(Ok(user)) => {
            println!("Inactive: {}", user.name);
        }
        Some(Err(e)) => {
            eprintln!("Error: {}", e);
        }
        None => {
            println!("No result");
        }
    }
}
```

### Performance Anti-Patterns

**Arc<Mutex<T>> Everywhere:**

```rust
// BAD: Shared mutable state as default
struct App {
    users: Arc<Mutex<HashMap<UserId, User>>>,
    config: Arc<Mutex<Config>>,
    cache: Arc<Mutex<Cache>>,
}

// GOOD: Minimize shared state, use appropriate primitives
struct App {
    // Read-only after init - no lock needed
    config: Arc<Config>,
    // Read-heavy - use RwLock
    users: Arc<RwLock<HashMap<UserId, User>>>,
    // Concurrent map for cache
    cache: Arc<DashMap<Key, Value>>,
    // Or pass by channel instead of sharing
    commands: mpsc::Sender<Command>,
}
```

**Allocation in Hot Loops:**

```rust
// BAD: Allocates every iteration
for item in &items {
    let mut buffer = Vec::new();  // New allocation
    process_into(item, &mut buffer);
}

// GOOD: Reuse allocation
let mut buffer = Vec::new();
for item in &items {
    buffer.clear();  // Keeps capacity
    process_into(item, &mut buffer);
}

// BAD: String formatting in loop
for item in &items {
    let msg = format!("Processing: {}", item.name);  // Allocates
    log(&msg);
}

// GOOD: Use write! to reuse buffer
let mut msg = String::new();
for item in &items {
    msg.clear();
    write!(&mut msg, "Processing: {}", item.name).unwrap();
    log(&msg);
}
```

**Poor Struct Layout:**

```rust
// BAD: Poor field ordering (40 bytes with padding)
struct Wasteful {
    a: u8,      // 1 byte + 7 padding
    b: u64,     // 8 bytes
    c: u8,      // 1 byte + 7 padding
    d: u64,     // 8 bytes
    e: u16,     // 2 bytes + 6 padding
}

// GOOD: Largest-first ordering (24 bytes)
struct Efficient {
    b: u64,     // 8 bytes
    d: u64,     // 8 bytes
    e: u16,     // 2 bytes
    a: u8,      // 1 byte
    c: u8,      // 1 byte + 4 padding
}

// Verify sizes in tests
#[test]
fn check_sizes() {
    assert_eq!(std::mem::size_of::<Efficient>(), 24);
}
```

**Default HashMap for Small N:**

```rust
// BAD: HashMap overhead for tiny collections
fn find_config(key: &str) -> Option<&str> {
    let map: HashMap<&str, &str> = [
        ("debug", "false"),
        ("timeout", "30"),
        ("retries", "3"),
    ].into_iter().collect();
    map.get(key).copied()
}

// GOOD: Linear search is faster for N < ~20
fn find_config(key: &str) -> Option<&str> {
    const CONFIG: &[(&str, &str)] = &[
        ("debug", "false"),
        ("timeout", "30"),
        ("retries", "3"),
    ];
    CONFIG.iter()
        .find(|(k, _)| *k == key)
        .map(|(_, v)| *v)
}
```

### Quick Reference Table

| Anti-Pattern | Why Bad | Fix |
|--------------|---------|-----|
| `unwrap()` everywhere | Panics in production | Use `?`, `unwrap_or`, match |
| Clone to satisfy borrow checker | Performance, hides design issues | Restructure ownership |
| `use module::*` | Name collisions, unclear imports | Explicit imports |
| Mutex across `.await` | Deadlocks | Use `tokio::sync::Mutex` |
| Blocking in async | Starves runtime | Use `spawn_blocking` |
| `&String` parameters | Forces allocation | Use `&str` |
| `Box<dyn Trait>` by default | Hidden allocation, no inlining | Use generics unless needed |
| HashMap for small N | Overhead exceeds benefit | Vec + linear search for N < 20 |
| Default hasher for trusted data | SipHash is slow (~15ns) | FxHash/AHash (~2ns) |
| Allocation in hot loops | Repeated malloc overhead | Pre-allocate, reuse buffers |
| `Arc<Mutex<T>>` everywhere | Contention, complexity | Minimize shared state |
| Strings for everything | No type safety | Newtypes, enums |
| Boolean parameters | Unclear at call site | Enums or option structs |

## 12. Code Review Checklist

### Correctness

- [ ] **Error handling is complete**
  - All `Result` values handled (no ignored `let _ = ...`)
  - No `unwrap()` or `expect()` in non-test code
  - Error types are meaningful (not just `String`)
  - Error context preserved (using `.context()` or similar)

- [ ] **Edge cases covered**
  - Empty collections handled
  - Zero/negative values considered
  - Unicode strings tested
  - Maximum values won't overflow

- [ ] **Concurrency is sound**
  - No data races possible
  - Locks held for minimal time
  - No Mutex held across `.await`
  - Deadlock-free (consistent lock ordering)

- [ ] **Resource cleanup**
  - Files/connections closed (prefer RAII)
  - Temp files cleaned up
  - No resource leaks in error paths

### Design

- [ ] **Single responsibility**
  - Each function does one thing
  - Each module has clear purpose
  - Each struct has focused role

- [ ] **Appropriate visibility**
  - `pub` only for intentional API
  - Internal helpers are private
  - `pub(crate)` for crate-internal sharing

- [ ] **Idiomatic patterns**
  - Uses standard traits (`From`, `Display`, `Default`)
  - Follows naming conventions
  - Uses iterators over manual loops
  - Pattern matching over if-let chains

- [ ] **API ergonomics**
  - Takes `&str` not `&String`
  - Takes `impl Into<T>` for flexibility
  - Returns `impl Trait` when appropriate
  - Builder pattern for complex construction

### Performance

- [ ] **No obvious inefficiencies**
  - No allocation in tight loops
  - No unnecessary clones
  - Collections pre-sized when size known
  - Appropriate data structures

- [ ] **Appropriate data structures**
  - Vec for small collections
  - HashMap/BTreeMap chosen correctly
  - Consider FxHash for internal maps

- [ ] **Async correctness**
  - CPU work in `spawn_blocking`
  - Appropriate use of `select!`, `join!`
  - Cancellation handled properly

### Documentation

- [ ] **Public API documented**
  - All `pub` items have doc comments
  - Examples compile and run
  - Panics documented
  - Safety requirements for `unsafe`

- [ ] **Code is self-documenting**
  - Clear variable names
  - Complex logic has comments
  - Invariants documented

## 13. Production Checklist

### Cargo.toml Verification

```toml
[package]
name = "myapp"
version = "1.0.0"
edition = "2021"
# Set minimum supported Rust version
rust-version = "1.75"
# Complete metadata
license = "MIT OR Apache-2.0"
description = "A production application"
repository = "https://github.com/org/myapp"
readme = "README.md"
keywords = ["app", "production"]
categories = ["command-line-utilities"]

[lints.rust]
# Forbid unsafe unless explicitly needed
unsafe_code = "forbid"

[lints.clippy]
all = "warn"
pedantic = "warn"
# Deny problematic patterns
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
# Additional production lints
todo = "warn"
unimplemented = "deny"

[profile.release]
# Enable LTO for smaller, faster binaries
lto = true
# Single codegen unit for better optimization
codegen-units = 1
# Strip symbols for smaller binary
strip = true
```

### CI/CD Requirements

Complete CI pipeline:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
  CARGO_TERM_COLOR: always

jobs:
  fmt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-action@stable
        with:
          components: rustfmt
      - run: cargo fmt --check

  clippy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-action@stable
        with:
          components: clippy
      - run: cargo clippy -- -D warnings

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-action@stable
      - uses: taiki-e/install-action@nextest
      - run: cargo nextest run
      - run: cargo test --doc

  msrv:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-action@1.75  # Your MSRV
      - run: cargo check

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-action@stable
      - run: cargo install cargo-audit cargo-deny
      - run: cargo audit
      - run: cargo deny check
```

### Build Verification

```bash
# Build release with locked dependencies
cargo build --release --locked

# Verify binary runs
./target/release/myapp --version
./target/release/myapp --help

# Run smoke tests against binary
./target/release/myapp self-test  # If implemented

# Check binary size
ls -lh target/release/myapp

# Verify no debug symbols in release (if stripped)
file target/release/myapp
```

### Observability

**Logging configured (see `rust-project-setup.md` for tracing setup):**

```rust
// Structured logging with tracing
use tracing::{info, warn, error, instrument};

#[instrument(skip(password))]
pub async fn login(username: &str, password: &str) -> Result<Session, Error> {
    info!(username, "Login attempt");
    
    let result = authenticate(username, password).await;
    
    match &result {
        Ok(session) => info!(session_id = %session.id, "Login successful"),
        Err(e) => warn!(error = %e, "Login failed"),
    }
    
    result
}
```

**Metrics exposed:**

```rust
// Using prometheus crate
use prometheus::{Counter, Histogram, register_counter, register_histogram};

lazy_static! {
    static ref REQUESTS_TOTAL: Counter = register_counter!(
        "requests_total",
        "Total number of requests"
    ).unwrap();
    
    static ref REQUEST_DURATION: Histogram = register_histogram!(
        "request_duration_seconds",
        "Request duration in seconds"
    ).unwrap();
}

pub async fn handle_request(req: Request) -> Response {
    REQUESTS_TOTAL.inc();
    let timer = REQUEST_DURATION.start_timer();
    
    let response = process(req).await;
    
    timer.observe_duration();
    response
}

// Expose /metrics endpoint
async fn metrics_handler() -> impl IntoResponse {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = Vec::new();
    encoder.encode(&metric_families, &mut buffer).unwrap();
    buffer
}
```

**Health endpoint:**

```rust
// Basic health check
async fn health_check() -> impl IntoResponse {
    StatusCode::OK
}

// Detailed health with dependencies
#[derive(Serialize)]
struct HealthStatus {
    status: &'static str,
    version: &'static str,
    checks: HashMap<String, ComponentHealth>,
}

#[derive(Serialize)]
struct ComponentHealth {
    status: &'static str,
    latency_ms: Option<u64>,
}

async fn health_detailed(db: &PgPool, redis: &RedisPool) -> impl IntoResponse {
    let mut checks = HashMap::new();
    
    // Check database
    let db_start = Instant::now();
    let db_status = match sqlx::query("SELECT 1").execute(db).await {
        Ok(_) => ComponentHealth {
            status: "healthy",
            latency_ms: Some(db_start.elapsed().as_millis() as u64),
        },
        Err(_) => ComponentHealth {
            status: "unhealthy",
            latency_ms: None,
        },
    };
    checks.insert("database".to_string(), db_status);
    
    // Check Redis
    let redis_status = match redis.ping().await {
        Ok(_) => ComponentHealth { status: "healthy", latency_ms: Some(1) },
        Err(_) => ComponentHealth { status: "unhealthy", latency_ms: None },
    };
    checks.insert("redis".to_string(), redis_status);
    
    let overall = if checks.values().all(|c| c.status == "healthy") {
        "healthy"
    } else {
        "degraded"
    };
    
    Json(HealthStatus {
        status: overall,
        version: env!("CARGO_PKG_VERSION"),
        checks,
    })
}
```

### Final Verification Steps

Before deployment:

1. **Dependency audit passes:**
   ```bash
   cargo audit
   cargo deny check
   ```

2. **All tests pass:**
   ```bash
   cargo nextest run
   cargo test --doc
   ```

3. **No warnings:**
   ```bash
   cargo clippy -- -D warnings
   ```

4. **Documentation complete:**
   ```bash
   cargo doc --no-deps
   # Review generated docs
   ```

5. **Changelog updated** (if applicable)

6. **Version bumped** appropriately (semver)

7. **Git tag created** for release

8. **Binary tested** in staging environment

See `rust-project-setup.md` for detailed CI/CD configuration and `rust-performance-optimization.md` for benchmarking before production deployment.
