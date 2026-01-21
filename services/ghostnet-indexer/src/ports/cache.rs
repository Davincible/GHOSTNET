//! Caching port for in-memory data access.
//!
//! Defines the contract for caching frequently accessed data
//! to reduce database load and improve response times.

use crate::types::entities::{GlobalStats, Position};
use crate::types::enums::Level;
use crate::types::primitives::EthAddress;

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for in-memory caching.
///
/// Provides fast access to frequently queried data:
/// - Active positions (by user address)
/// - Global statistics
/// - Rate limiting counters
///
/// # Cache Invalidation
///
/// The cache uses a write-through pattern:
/// 1. Writes go to database first
/// 2. On success, cache is updated
/// 3. On cache miss, database is queried
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use TTL-based expiration for stats
/// - Use LRU eviction for positions
/// - Be thread-safe (this trait requires `Send + Sync`)
pub trait Cache: Send + Sync {
    /// Get a cached position.
    ///
    /// Returns `None` on cache miss.
    fn get_position(&self, address: &EthAddress) -> Option<Position>;

    /// Cache a position.
    ///
    /// Pass `None` to cache a negative result (user has no position).
    fn set_position(&self, address: &EthAddress, position: Option<Position>);

    /// Invalidate a cached position.
    ///
    /// Call after position state changes.
    fn invalidate_position(&self, address: &EthAddress);

    /// Invalidate all cached positions.
    ///
    /// Call after bulk updates or reorg rollback.
    fn invalidate_all_positions(&self);

    /// Invalidate cached positions for a specific level.
    ///
    /// Call when level-wide changes occur (e.g., after scans, deaths).
    /// This is more efficient than `invalidate_all_positions` when
    /// only one level is affected.
    ///
    /// Note: Current implementations may just delegate to `invalidate_all_positions`
    /// until level-indexed caching is implemented.
    fn invalidate_level(&self, level: &Level);

    /// Get cached global stats.
    ///
    /// Returns `None` on cache miss or TTL expiration.
    fn get_global_stats(&self) -> Option<GlobalStats>;

    /// Cache global stats.
    fn set_global_stats(&self, stats: GlobalStats);

    /// Check rate limit and record attempt.
    ///
    /// Returns `true` if the request is allowed (under limit).
    /// Returns `false` if rate limited.
    ///
    /// # Arguments
    ///
    /// * `key` - Rate limit key (e.g., IP address, user ID)
    /// * `limit` - Maximum requests allowed
    /// * `window_secs` - Time window in seconds
    ///
    /// # Example
    ///
    /// ```ignore
    /// // Allow 100 requests per minute
    /// if cache.check_rate_limit("user:123", 100, 60) {
    ///     // Process request
    /// } else {
    ///     // Return 429 Too Many Requests
    /// }
    /// ```
    fn check_rate_limit(&self, key: &str, limit: u32, window_secs: u64) -> bool;

    /// Get remaining rate limit quota.
    ///
    /// Returns `None` if key hasn't been seen.
    fn get_rate_limit_remaining(&self, key: &str, limit: u32, window_secs: u64) -> Option<u32>;

    /// Clear all cached data.
    ///
    /// Use sparingly - typically after reorg rollback.
    fn clear_all(&self);

    /// Get cache statistics for monitoring.
    fn stats(&self) -> CacheStats;
}

/// Cache statistics for monitoring.
#[derive(Debug, Clone, Default)]
pub struct CacheStats {
    /// Number of cache hits.
    pub hits: u64,
    /// Number of cache misses.
    pub misses: u64,
    /// Number of cached positions.
    pub position_count: usize,
    /// Whether global stats are cached.
    pub has_global_stats: bool,
}

impl CacheStats {
    /// Calculate hit rate as a percentage.
    #[must_use]
    /// Calculate the cache hit rate as a percentage.
    ///
    /// Precision loss in f64 conversion is acceptable for statistics.
    #[allow(clippy::cast_precision_loss)]
    pub fn hit_rate(&self) -> f64 {
        let total = self.hits + self.misses;
        if total == 0 {
            0.0
        } else {
            (self.hits as f64 / total as f64) * 100.0
        }
    }
}

#[cfg(any(test, feature = "test-utils"))]
#[allow(
    clippy::expect_used,              // Test-only code; panicking on lock poison is acceptable
    clippy::significant_drop_tightening, // Lock patterns are clear in test code
    clippy::clone_on_copy             // Explicit clones are fine in tests
)]
pub mod mocks {
    //! Mock implementations for testing.

    use std::collections::HashMap;
    use std::sync::RwLock;
    use std::sync::atomic::{AtomicU64, Ordering};

    use super::{Cache, CacheStats, EthAddress, GlobalStats, Position};
    use crate::types::enums::Level;

    /// Simple in-memory cache for testing.
    #[derive(Debug, Default)]
    pub struct MockCache {
        positions: RwLock<HashMap<EthAddress, Option<Position>>>,
        global_stats: RwLock<Option<GlobalStats>>,
        rate_limits: RwLock<HashMap<String, (u32, u64)>>, // (count, window_start)
        hits: AtomicU64,
        misses: AtomicU64,
    }

    impl MockCache {
        /// Create a new mock cache.
        #[must_use]
        pub fn new() -> Self {
            Self::default()
        }
    }

    impl Cache for MockCache {
        fn get_position(&self, address: &EthAddress) -> Option<Position> {
            let positions = self.positions.read().expect("lock poisoned");
            match positions.get(address) {
                Some(Some(pos)) => {
                    self.hits.fetch_add(1, Ordering::Relaxed);
                    Some(pos.clone())
                }
                Some(None) => {
                    // Negative cache hit
                    self.hits.fetch_add(1, Ordering::Relaxed);
                    None
                }
                None => {
                    self.misses.fetch_add(1, Ordering::Relaxed);
                    None
                }
            }
        }

        fn set_position(&self, address: &EthAddress, position: Option<Position>) {
            let mut positions = self.positions.write().expect("lock poisoned");
            positions.insert(address.clone(), position);
        }

        fn invalidate_position(&self, address: &EthAddress) {
            let mut positions = self.positions.write().expect("lock poisoned");
            positions.remove(address);
        }

        fn invalidate_all_positions(&self) {
            let mut positions = self.positions.write().expect("lock poisoned");
            positions.clear();
        }

        fn invalidate_level(&self, _level: &Level) {
            // For the mock, just invalidate all positions
            // A real implementation would track positions by level
            self.invalidate_all_positions();
        }

        fn get_global_stats(&self) -> Option<GlobalStats> {
            let stats = self.global_stats.read().expect("lock poisoned");
            if stats.is_some() {
                self.hits.fetch_add(1, Ordering::Relaxed);
            } else {
                self.misses.fetch_add(1, Ordering::Relaxed);
            }
            stats.clone()
        }

        fn set_global_stats(&self, stats: GlobalStats) {
            let mut cached = self.global_stats.write().expect("lock poisoned");
            *cached = Some(stats);
        }

        fn check_rate_limit(&self, key: &str, limit: u32, window_secs: u64) -> bool {
            let mut limits = self.rate_limits.write().expect("lock poisoned");
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time went backwards")
                .as_secs();

            let (count, window_start) = limits.entry(key.to_string()).or_insert((0, now));

            // Reset if window expired
            if now - *window_start >= window_secs {
                *count = 0;
                *window_start = now;
            }

            if *count < limit {
                *count += 1;
                true
            } else {
                false
            }
        }

        fn get_rate_limit_remaining(&self, key: &str, limit: u32, window_secs: u64) -> Option<u32> {
            let limits = self.rate_limits.read().expect("lock poisoned");
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time went backwards")
                .as_secs();

            limits.get(key).map(|(count, window_start)| {
                if now - *window_start >= window_secs {
                    limit // Window expired, full quota available
                } else {
                    limit.saturating_sub(*count)
                }
            })
        }

        fn clear_all(&self) {
            self.positions.write().expect("lock poisoned").clear();
            *self.global_stats.write().expect("lock poisoned") = None;
            self.rate_limits.write().expect("lock poisoned").clear();
        }

        fn stats(&self) -> CacheStats {
            CacheStats {
                hits: self.hits.load(Ordering::Relaxed),
                misses: self.misses.load(Ordering::Relaxed),
                position_count: self.positions.read().expect("lock poisoned").len(),
                has_global_stats: self.global_stats.read().expect("lock poisoned").is_some(),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::mocks::MockCache;
    use super::*;

    #[test]
    fn cache_stats_hit_rate() {
        let stats = CacheStats {
            hits: 80,
            misses: 20,
            position_count: 10,
            has_global_stats: true,
        };
        assert!((stats.hit_rate() - 80.0).abs() < f64::EPSILON);
    }

    #[test]
    fn cache_stats_hit_rate_zero() {
        let stats = CacheStats::default();
        assert!((stats.hit_rate() - 0.0).abs() < f64::EPSILON);
    }

    #[test]
    fn mock_cache_rate_limit() {
        let cache = MockCache::new();

        // Should allow up to 3 requests
        assert!(cache.check_rate_limit("test", 3, 60));
        assert!(cache.check_rate_limit("test", 3, 60));
        assert!(cache.check_rate_limit("test", 3, 60));

        // 4th should be rate limited
        assert!(!cache.check_rate_limit("test", 3, 60));
    }
}
