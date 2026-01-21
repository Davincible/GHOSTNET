//! Time port for testable time operations.
//!
//! Provides a `Clock` trait that abstracts time access, enabling:
//! - Deterministic testing with fake time
//! - Time travel in tests
//! - Consistent timestamps across operations

use chrono::{DateTime, Utc};

// ═══════════════════════════════════════════════════════════════════════════════
// CLOCK
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for time operations.
///
/// Allows injecting fake time in tests while using real time in production.
///
/// # Example
///
/// ```ignore
/// use ghostnet_indexer::ports::{Clock, SystemClock};
///
/// fn record_event<C: Clock>(clock: &C) {
///     let timestamp = clock.now();
///     println!("Event at: {}", timestamp);
/// }
///
/// // Production: use real time
/// record_event(&SystemClock);
///
/// // Test: use fake time
/// let fake = FakeClock::new(fixed_time);
/// record_event(&fake);
/// ```
pub trait Clock: Send + Sync {
    /// Get current UTC time.
    fn now(&self) -> DateTime<Utc>;

    /// Get current Unix timestamp (seconds since epoch).
    fn timestamp(&self) -> i64 {
        self.now().timestamp()
    }

    /// Get current Unix timestamp in milliseconds.
    fn timestamp_millis(&self) -> i64 {
        self.now().timestamp_millis()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTEM CLOCK (Production)
// ═══════════════════════════════════════════════════════════════════════════════

/// Production clock that returns real system time.
#[derive(Debug, Clone, Copy, Default)]
pub struct SystemClock;

impl SystemClock {
    /// Create a new system clock.
    #[must_use]
    pub const fn new() -> Self {
        Self
    }
}

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAKE CLOCK (Testing)
// ═══════════════════════════════════════════════════════════════════════════════

/// Fake clock for testing with controllable time.
///
/// Allows:
/// - Setting a fixed time
/// - Advancing time by a duration
/// - Time travel (setting arbitrary times)
///
/// # Thread Safety
///
/// Uses atomic operations for thread-safe time manipulation.
///
/// # Example
///
/// ```
/// use chrono::{Duration, TimeZone, Utc};
/// use ghostnet_indexer::ports::{Clock, FakeClock};
///
/// let clock = FakeClock::new(Utc.with_ymd_and_hms(2024, 1, 1, 12, 0, 0).unwrap());
/// assert_eq!(clock.now().hour(), 12);
///
/// clock.advance(Duration::hours(2));
/// assert_eq!(clock.now().hour(), 14);
/// ```
#[cfg(any(test, feature = "test-utils"))]
#[derive(Debug)]
pub struct FakeClock {
    /// Current time as Unix timestamp (atomic for thread safety).
    time: std::sync::atomic::AtomicI64,
}

#[cfg(any(test, feature = "test-utils"))]
impl FakeClock {
    /// Create a fake clock at the specified time.
    #[must_use]
    pub fn new(time: DateTime<Utc>) -> Self {
        Self {
            time: std::sync::atomic::AtomicI64::new(time.timestamp()),
        }
    }

    /// Create a fake clock at the current time.
    #[must_use]
    pub fn now_fake() -> Self {
        Self::new(Utc::now())
    }

    /// Create a fake clock at Unix epoch (1970-01-01 00:00:00 UTC).
    #[must_use]
    pub fn epoch() -> Self {
        Self {
            time: std::sync::atomic::AtomicI64::new(0),
        }
    }

    /// Advance time by the given duration.
    pub fn advance(&self, duration: chrono::Duration) {
        self.time
            .fetch_add(duration.num_seconds(), std::sync::atomic::Ordering::SeqCst);
    }

    /// Set time to a specific value.
    pub fn set(&self, time: DateTime<Utc>) {
        self.time
            .store(time.timestamp(), std::sync::atomic::Ordering::SeqCst);
    }

    /// Get the raw timestamp value.
    #[must_use]
    pub fn get_timestamp(&self) -> i64 {
        self.time.load(std::sync::atomic::Ordering::SeqCst)
    }
}

#[cfg(any(test, feature = "test-utils"))]
impl Clock for FakeClock {
    fn now(&self) -> DateTime<Utc> {
        DateTime::from_timestamp(self.time.load(std::sync::atomic::Ordering::SeqCst), 0)
            .unwrap_or_default()
    }
}

#[cfg(any(test, feature = "test-utils"))]
impl Default for FakeClock {
    fn default() -> Self {
        Self::now_fake()
    }
}

#[cfg(any(test, feature = "test-utils"))]
impl Clone for FakeClock {
    fn clone(&self) -> Self {
        Self {
            time: std::sync::atomic::AtomicI64::new(
                self.time.load(std::sync::atomic::Ordering::SeqCst),
            ),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use chrono::{Datelike, Duration, TimeZone, Timelike};

    use super::*;

    #[test]
    fn system_clock_returns_current_time() {
        let clock = SystemClock::new();
        let before = Utc::now();
        let clock_time = clock.now();
        let after = Utc::now();

        assert!(clock_time >= before);
        assert!(clock_time <= after);
    }

    #[test]
    fn system_clock_timestamp() {
        let clock = SystemClock::new();
        let ts = clock.timestamp();
        assert!(ts > 0);
    }

    #[test]
    fn fake_clock_fixed_time() {
        let fixed = Utc.with_ymd_and_hms(2024, 6, 15, 10, 30, 0).unwrap();
        let clock = FakeClock::new(fixed);

        assert_eq!(clock.now().year(), 2024);
        assert_eq!(clock.now().month(), 6);
        assert_eq!(clock.now().day(), 15);
        assert_eq!(clock.now().hour(), 10);
        assert_eq!(clock.now().minute(), 30);
    }

    #[test]
    fn fake_clock_advance() {
        let start = Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap();
        let clock = FakeClock::new(start);

        clock.advance(Duration::hours(5));
        assert_eq!(clock.now().hour(), 5);

        clock.advance(Duration::days(1));
        assert_eq!(clock.now().day(), 2);
        assert_eq!(clock.now().hour(), 5);
    }

    #[test]
    fn fake_clock_set() {
        let clock = FakeClock::epoch();
        assert_eq!(clock.timestamp(), 0);

        let new_time = Utc.with_ymd_and_hms(2025, 12, 31, 23, 59, 59).unwrap();
        clock.set(new_time);

        assert_eq!(clock.now().year(), 2025);
        assert_eq!(clock.now().month(), 12);
    }

    #[test]
    fn fake_clock_is_thread_safe() {
        use std::sync::Arc;
        use std::thread;

        let clock = Arc::new(FakeClock::epoch());

        let handles: Vec<_> = (0..10)
            .map(|_| {
                let c = Arc::clone(&clock);
                thread::spawn(move || {
                    for _ in 0..100 {
                        c.advance(Duration::seconds(1));
                    }
                })
            })
            .collect();

        for h in handles {
            h.join().expect("thread panicked");
        }

        // 10 threads * 100 advances * 1 second = 1000 seconds
        assert_eq!(clock.timestamp(), 1000);
    }

    #[test]
    fn fake_clock_clone() {
        let clock1 = FakeClock::new(Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap());
        let clock2 = clock1.clone();

        // Clones start at same time
        assert_eq!(clock1.timestamp(), clock2.timestamp());

        // But are independent
        clock1.advance(Duration::hours(1));
        assert_ne!(clock1.timestamp(), clock2.timestamp());
    }
}
