//! Safety mechanisms for wallet protection.
//!
//! This module provides safety mechanisms to protect wallets from
//! cascading failures and runaway behavior.
//!
//! # Circuit Breaker
//!
//! The [`CircuitBreaker`] stops a wallet after too many consecutive errors,
//! preventing wasted gas and potential losses from malfunctioning logic.
//!
//! ```
//! use fleet_core::safety::CircuitBreaker;
//! use std::time::Duration;
//!
//! let mut breaker = CircuitBreaker::new(5, Duration::from_secs(3600));
//!
//! // Record errors
//! breaker.record_error("wallet_1");
//! assert!(!breaker.is_tripped("wallet_1"));
//!
//! // After 5 errors, circuit trips
//! for _ in 0..4 {
//!     breaker.record_error("wallet_1");
//! }
//! assert!(breaker.is_tripped("wallet_1"));
//!
//! // Success resets the counter
//! breaker.record_success("wallet_2");
//! assert!(!breaker.is_tripped("wallet_2"));
//! ```

use std::collections::{HashMap, HashSet};
use std::time::Duration;

use chrono::{DateTime, Utc};
use tracing::{info, warn};

// ═══════════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER
// ═══════════════════════════════════════════════════════════════════════════════

/// Circuit breaker for wallet operations.
///
/// Tracks consecutive errors per wallet and "trips" (disables) wallets that
/// exceed the error threshold. Tripped wallets can auto-reset after a cooldown
/// period or be manually reset.
///
/// # States
///
/// ```text
/// ┌──────────┐   error count   ┌──────────┐   cooldown   ┌──────────┐
/// │  Closed  │ ───────────────▶│  Tripped │ ────────────▶│  Closed  │
/// │ (normal) │   >= threshold  │(disabled)│   expires    │ (normal) │
/// └──────────┘                 └──────────┘              └──────────┘
///       │                            │
///       │ success                    │ manual reset
///       ▼                            ▼
/// error count = 0              error count = 0
/// ```
///
/// # Thread Safety
///
/// This struct is NOT thread-safe. Wrap in a `Mutex` or `RwLock` if
/// concurrent access is needed.
#[derive(Debug)]
pub struct CircuitBreaker {
    /// Maximum consecutive errors before tripping.
    max_errors: u32,

    /// How long a tripped wallet stays disabled before auto-reset.
    cooldown: Duration,

    /// Consecutive error counts per wallet.
    error_counts: HashMap<String, u32>,

    /// Set of currently tripped wallet IDs.
    tripped: HashSet<String>,

    /// When each wallet was tripped (for auto-reset calculation).
    trip_times: HashMap<String, DateTime<Utc>>,
}

impl CircuitBreaker {
    /// Create a new circuit breaker.
    ///
    /// # Arguments
    ///
    /// * `max_errors` - Number of consecutive errors before tripping
    /// * `cooldown` - Duration before auto-reset after tripping
    #[must_use]
    pub fn new(max_errors: u32, cooldown: Duration) -> Self {
        Self {
            max_errors,
            cooldown,
            error_counts: HashMap::new(),
            tripped: HashSet::new(),
            trip_times: HashMap::new(),
        }
    }

    /// Record a successful operation for a wallet.
    ///
    /// Resets the error count for this wallet to zero.
    pub fn record_success(&mut self, wallet_id: &str) {
        self.error_counts.remove(wallet_id);
    }

    /// Record a failed operation for a wallet.
    ///
    /// Increments the error count. If the threshold is reached, trips the
    /// circuit breaker for this wallet.
    ///
    /// # Returns
    ///
    /// `true` if this error caused the circuit to trip, `false` otherwise.
    pub fn record_error(&mut self, wallet_id: &str) -> bool {
        // Already tripped - don't count more errors
        if self.tripped.contains(wallet_id) {
            return false;
        }

        let count = self
            .error_counts
            .entry(wallet_id.to_string())
            .or_insert(0);
        *count = count.saturating_add(1);

        if *count >= self.max_errors {
            warn!(
                wallet = wallet_id,
                errors = *count,
                threshold = self.max_errors,
                "Circuit breaker tripped"
            );
            self.tripped.insert(wallet_id.to_string());
            self.trip_times.insert(wallet_id.to_string(), Utc::now());
            return true;
        }

        false
    }

    /// Check if a wallet's circuit breaker is tripped.
    #[must_use]
    pub fn is_tripped(&self, wallet_id: &str) -> bool {
        self.tripped.contains(wallet_id)
    }

    /// Get the number of consecutive errors for a wallet.
    #[must_use]
    pub fn error_count(&self, wallet_id: &str) -> u32 {
        self.error_counts.get(wallet_id).copied().unwrap_or(0)
    }

    /// Get the total number of tripped wallets.
    #[must_use]
    pub fn tripped_count(&self) -> usize {
        self.tripped.len()
    }

    /// Get all tripped wallet IDs.
    pub fn tripped_wallets(&self) -> impl Iterator<Item = &str> {
        self.tripped.iter().map(String::as_str)
    }

    /// Manually reset a wallet's circuit breaker.
    ///
    /// Clears the error count and removes from tripped set.
    pub fn manual_reset(&mut self, wallet_id: &str) {
        if self.tripped.remove(wallet_id) {
            info!(wallet = wallet_id, "Circuit breaker manually reset");
        }
        self.error_counts.remove(wallet_id);
        self.trip_times.remove(wallet_id);
    }

    /// Reset all circuit breakers.
    pub fn reset_all(&mut self) {
        let count = self.tripped.len();
        self.tripped.clear();
        self.error_counts.clear();
        self.trip_times.clear();
        if count > 0 {
            info!(count, "All circuit breakers reset");
        }
    }

    /// Check and auto-reset wallets that have exceeded their cooldown.
    ///
    /// Returns the number of wallets that were auto-reset.
    pub fn check_auto_reset(&mut self) -> usize {
        let now = Utc::now();
        let cooldown_chrono = chrono::Duration::from_std(self.cooldown)
            .unwrap_or_else(|_| chrono::Duration::hours(1));

        let to_reset: Vec<String> = self
            .trip_times
            .iter()
            .filter(|(_, time)| now - **time > cooldown_chrono)
            .map(|(id, _)| id.clone())
            .collect();

        let count = to_reset.len();
        for id in to_reset {
            info!(wallet = %id, "Circuit breaker auto-reset after cooldown");
            self.manual_reset(&id);
        }

        count
    }

    /// Get when a wallet was tripped.
    #[must_use]
    pub fn trip_time(&self, wallet_id: &str) -> Option<DateTime<Utc>> {
        self.trip_times.get(wallet_id).copied()
    }

    /// Get time remaining until auto-reset for a tripped wallet.
    #[must_use]
    pub fn time_until_reset(&self, wallet_id: &str) -> Option<Duration> {
        let trip_time = self.trip_times.get(wallet_id)?;
        let cooldown_chrono = chrono::Duration::from_std(self.cooldown)
            .unwrap_or_else(|_| chrono::Duration::hours(1));
        let reset_at = *trip_time + cooldown_chrono;
        let now = Utc::now();

        if now >= reset_at {
            Some(Duration::ZERO)
        } else {
            (reset_at - now).to_std().ok()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn success_resets_error_count() {
        let mut breaker = CircuitBreaker::new(5, Duration::from_secs(3600));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1");
        assert_eq!(breaker.error_count("wallet_1"), 2);

        breaker.record_success("wallet_1");
        assert_eq!(breaker.error_count("wallet_1"), 0);
    }

    #[test]
    fn trips_after_threshold() {
        let mut breaker = CircuitBreaker::new(3, Duration::from_secs(3600));

        assert!(!breaker.record_error("wallet_1"));
        assert!(!breaker.record_error("wallet_1"));
        assert!(breaker.record_error("wallet_1")); // Third error trips

        assert!(breaker.is_tripped("wallet_1"));
        assert_eq!(breaker.tripped_count(), 1);
    }

    #[test]
    fn manual_reset_works() {
        let mut breaker = CircuitBreaker::new(2, Duration::from_secs(3600));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1");
        assert!(breaker.is_tripped("wallet_1"));

        breaker.manual_reset("wallet_1");
        assert!(!breaker.is_tripped("wallet_1"));
        assert_eq!(breaker.error_count("wallet_1"), 0);
    }

    #[test]
    fn does_not_count_errors_when_tripped() {
        let mut breaker = CircuitBreaker::new(2, Duration::from_secs(3600));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1"); // Trips
        assert!(breaker.is_tripped("wallet_1"));

        // More errors don't increase count
        assert!(!breaker.record_error("wallet_1"));
        assert_eq!(breaker.error_count("wallet_1"), 2);
    }

    #[test]
    fn multiple_wallets_independent() {
        let mut breaker = CircuitBreaker::new(3, Duration::from_secs(3600));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1");

        breaker.record_error("wallet_2");

        assert!(breaker.is_tripped("wallet_1"));
        assert!(!breaker.is_tripped("wallet_2"));
        assert_eq!(breaker.error_count("wallet_2"), 1);
    }

    #[test]
    fn auto_reset_after_cooldown() {
        let mut breaker = CircuitBreaker::new(2, Duration::from_millis(10));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_1");
        assert!(breaker.is_tripped("wallet_1"));

        // Wait for cooldown
        std::thread::sleep(Duration::from_millis(20));

        let reset_count = breaker.check_auto_reset();
        assert_eq!(reset_count, 1);
        assert!(!breaker.is_tripped("wallet_1"));
    }

    #[test]
    fn tripped_wallets_iterator() {
        let mut breaker = CircuitBreaker::new(1, Duration::from_secs(3600));

        breaker.record_error("wallet_1");
        breaker.record_error("wallet_2");
        breaker.record_error("wallet_3");

        let tripped: HashSet<_> = breaker.tripped_wallets().collect();
        assert_eq!(tripped.len(), 3);
        assert!(tripped.contains("wallet_1"));
        assert!(tripped.contains("wallet_2"));
        assert!(tripped.contains("wallet_3"));
    }
}
