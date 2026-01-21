//! In-memory cache implementation using moka and dashmap.
//!
//! Provides fast access to hot data without database round-trips.
//! Follows EVM guide patterns for caching:
//! - Immutable data (block hashes) with longer TTLs
//! - Active data (positions, stats) with shorter TTLs
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────────┐
//! │                         MemoryCache                                  │
//! │                                                                     │
//! │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
//! │   │  Position Cache │  │   Stats Cache   │  │ Leaderboard     │    │
//! │   │  (moka, 5min)   │  │   (moka, 1min)  │  │ Cache (5min)    │    │
//! │   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
//! │                                                                     │
//! │   ┌─────────────────┐  ┌─────────────────┐                         │
//! │   │ Block Hash      │  │  Rate Limiter   │                         │
//! │   │ Cache (5min)    │  │  (dashmap)      │                         │
//! │   └─────────────────┘  └─────────────────┘                         │
//! └─────────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # TTL Strategy
//!
//! | Cache | TTL | Max Size | Rationale |
//! |-------|-----|----------|-----------|
//! | Positions | 5 min | 10,000 | Frequent API queries, changes on events |
//! | Global Stats | 1 min | 1 | Dashboard updates, aggregated data |
//! | Level Stats | 1 min | 5 | Per-level metrics, one per level |
//! | Leaderboards | 5 min | 20 | Expensive queries, different types |
//! | Block Hashes | 5 min | 128 | Reorg detection, recent blocks only |
//!
//! # Rate Limiting
//!
//! Uses dashmap for high-concurrency rate limiting with sliding window:
//! - Key format: `{identifier}:{window_start}`
//! - Automatic cleanup of expired windows
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::store::MemoryCache;
//! use ghostnet_indexer::ports::Cache;
//!
//! let cache = MemoryCache::new();
//!
//! // Cache a position
//! cache.set_position(&address, Some(position));
//!
//! // Check rate limit (100 req/min per IP)
//! if cache.check_rate_limit("ip:192.168.1.1", 100, 60) {
//!     // Process request
//! } else {
//!     // Return 429
//! }
//! ```

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use alloy::primitives::B256;
use dashmap::DashMap;
use moka::sync::Cache as MokaCache;
use tracing::debug;

use crate::ports::{Cache, CacheStats};
use crate::types::entities::{GlobalStats, LeaderboardEntry, LevelStats, Position};
use crate::types::enums::Level;
use crate::types::primitives::EthAddress;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Position cache TTL (5 minutes).
const POSITION_TTL: Duration = Duration::from_secs(300);
/// Position cache max capacity.
const POSITION_MAX_CAPACITY: u64 = 10_000;

/// Global stats cache TTL (1 minute).
const GLOBAL_STATS_TTL: Duration = Duration::from_secs(60);

/// Level stats cache TTL (1 minute).
const LEVEL_STATS_TTL: Duration = Duration::from_secs(60);
/// Level stats max capacity (one per level).
const LEVEL_STATS_MAX_CAPACITY: u64 = 5;

/// Leaderboard cache TTL (5 minutes).
const LEADERBOARD_TTL: Duration = Duration::from_secs(300);
/// Leaderboard cache max capacity (different leaderboard types).
const LEADERBOARD_MAX_CAPACITY: u64 = 20;

/// Block hash cache TTL (5 minutes).
const BLOCK_HASH_TTL: Duration = Duration::from_secs(300);
/// Block hash max capacity (~15 minutes of blocks at 7s/block).
const BLOCK_HASH_MAX_CAPACITY: u64 = 128;

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY CACHE
// ═══════════════════════════════════════════════════════════════════════════════

/// High-performance in-memory cache using moka and dashmap.
///
/// Implements the `Cache` port trait with production-ready features:
/// - TTL-based expiration
/// - LRU eviction when capacity is reached
/// - Thread-safe concurrent access
/// - Hit/miss statistics for monitoring
///
/// # Thread Safety
///
/// All operations are thread-safe. The cache can be shared across tasks
/// via `Arc<MemoryCache>`.
#[derive(Debug)]
pub struct MemoryCache {
    /// Position cache by user address.
    /// Stores `Option<Position>` to support negative caching (user has no position).
    positions: MokaCache<EthAddress, Option<Position>>,

    /// Global stats cache (singleton, keyed by unit type).
    global_stats: MokaCache<(), GlobalStats>,

    /// Level stats cache by level.
    level_stats: MokaCache<Level, LevelStats>,

    /// Leaderboard cache by type name.
    leaderboards: MokaCache<String, Vec<LeaderboardEntry>>,

    /// Block hash cache for reorg detection.
    /// Key: block number, Value: block hash.
    block_hashes: MokaCache<u64, B256>,

    /// Rate limiter: key -> (window_start, count).
    /// Key format: `{identifier}:{window_start}`.
    rate_limits: Arc<DashMap<String, (u64, u32)>>,

    /// Cache hit counter.
    hits: AtomicU64,

    /// Cache miss counter.
    misses: AtomicU64,
}

impl MemoryCache {
    /// Create a new memory cache with default configuration.
    #[must_use]
    pub fn new() -> Self {
        Self {
            positions: MokaCache::builder()
                .max_capacity(POSITION_MAX_CAPACITY)
                .time_to_live(POSITION_TTL)
                .build(),

            global_stats: MokaCache::builder()
                .max_capacity(1)
                .time_to_live(GLOBAL_STATS_TTL)
                .build(),

            level_stats: MokaCache::builder()
                .max_capacity(LEVEL_STATS_MAX_CAPACITY)
                .time_to_live(LEVEL_STATS_TTL)
                .build(),

            leaderboards: MokaCache::builder()
                .max_capacity(LEADERBOARD_MAX_CAPACITY)
                .time_to_live(LEADERBOARD_TTL)
                .build(),

            block_hashes: MokaCache::builder()
                .max_capacity(BLOCK_HASH_MAX_CAPACITY)
                .time_to_live(BLOCK_HASH_TTL)
                .build(),

            rate_limits: Arc::new(DashMap::new()),
            hits: AtomicU64::new(0),
            misses: AtomicU64::new(0),
        }
    }

    /// Create a cache with custom TTLs for testing.
    ///
    /// # Arguments
    ///
    /// * `position_ttl` - TTL for position cache
    /// * `stats_ttl` - TTL for stats caches
    #[must_use]
    pub fn with_ttls(position_ttl: Duration, stats_ttl: Duration) -> Self {
        Self {
            positions: MokaCache::builder()
                .max_capacity(POSITION_MAX_CAPACITY)
                .time_to_live(position_ttl)
                .build(),

            global_stats: MokaCache::builder()
                .max_capacity(1)
                .time_to_live(stats_ttl)
                .build(),

            level_stats: MokaCache::builder()
                .max_capacity(LEVEL_STATS_MAX_CAPACITY)
                .time_to_live(stats_ttl)
                .build(),

            leaderboards: MokaCache::builder()
                .max_capacity(LEADERBOARD_MAX_CAPACITY)
                .time_to_live(LEADERBOARD_TTL)
                .build(),

            block_hashes: MokaCache::builder()
                .max_capacity(BLOCK_HASH_MAX_CAPACITY)
                .time_to_live(BLOCK_HASH_TTL)
                .build(),

            rate_limits: Arc::new(DashMap::new()),
            hits: AtomicU64::new(0),
            misses: AtomicU64::new(0),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEVEL STATS CACHE (Extended API)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get cached level stats.
    ///
    /// Returns `None` on cache miss or TTL expiration.
    #[must_use]
    pub fn get_level_stats(&self, level: Level) -> Option<LevelStats> {
        let result = self.level_stats.get(&level);
        if result.is_some() {
            self.hits.fetch_add(1, Ordering::Relaxed);
        } else {
            self.misses.fetch_add(1, Ordering::Relaxed);
        }
        result
    }

    /// Cache level stats.
    pub fn set_level_stats(&self, stats: LevelStats) {
        let level = stats.level;
        self.level_stats.insert(level, stats);
        debug!(?level, "Cached level stats");
    }

    /// Invalidate cached level stats.
    pub fn invalidate_level_stats(&self, level: Level) {
        self.level_stats.invalidate(&level);
        debug!(?level, "Invalidated level stats cache");
    }

    /// Invalidate all level stats.
    pub fn invalidate_all_level_stats(&self) {
        self.level_stats.invalidate_all();
        debug!("Invalidated all level stats cache");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEADERBOARD CACHE (Extended API)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get cached leaderboard.
    ///
    /// # Arguments
    ///
    /// * `leaderboard_type` - Type of leaderboard (e.g., "ghost_streak", "total_extracted")
    #[must_use]
    pub fn get_leaderboard(&self, leaderboard_type: &str) -> Option<Vec<LeaderboardEntry>> {
        let result = self.leaderboards.get(leaderboard_type);
        if result.is_some() {
            self.hits.fetch_add(1, Ordering::Relaxed);
        } else {
            self.misses.fetch_add(1, Ordering::Relaxed);
        }
        result
    }

    /// Cache a leaderboard.
    pub fn set_leaderboard(&self, leaderboard_type: &str, entries: Vec<LeaderboardEntry>) {
        self.leaderboards
            .insert(leaderboard_type.to_string(), entries);
        debug!(leaderboard_type, "Cached leaderboard");
    }

    /// Invalidate a cached leaderboard.
    pub fn invalidate_leaderboard(&self, leaderboard_type: &str) {
        self.leaderboards.invalidate(leaderboard_type);
        debug!(leaderboard_type, "Invalidated leaderboard cache");
    }

    /// Invalidate all leaderboards.
    pub fn invalidate_all_leaderboards(&self) {
        self.leaderboards.invalidate_all();
        debug!("Invalidated all leaderboard cache");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BLOCK HASH CACHE (Extended API for reorg detection)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get cached block hash for reorg detection.
    #[must_use]
    pub fn get_block_hash(&self, block_number: u64) -> Option<B256> {
        self.block_hashes.get(&block_number)
    }

    /// Cache a block hash.
    pub fn set_block_hash(&self, block_number: u64, hash: B256) {
        self.block_hashes.insert(block_number, hash);
    }

    /// Verify a block hash matches the cached value.
    ///
    /// Returns `true` if:
    /// - The hash matches the cached value
    /// - There's no cached value (can't verify)
    ///
    /// Returns `false` if the hash doesn't match (reorg detected).
    #[must_use]
    pub fn verify_block_hash(&self, block_number: u64, expected: B256) -> bool {
        // Returns true if no cached value (can't verify) or if hash matches
        self.block_hashes
            .get(&block_number)
            .is_none_or(|cached| cached == expected)
    }

    /// Invalidate block hashes at or after the given block number.
    ///
    /// Used during reorg handling to clear potentially invalid block hashes.
    pub fn invalidate_blocks_from(&self, from_block: u64) {
        // Moka doesn't support range invalidation, so we iterate
        // This is acceptable because reorgs are rare and block cache is small
        let keys_to_remove: Vec<_> = self
            .block_hashes
            .iter()
            .filter(|(k, _)| **k >= from_block)
            .map(|(k, _)| *k)
            .collect();

        for key in keys_to_remove {
            self.block_hashes.invalidate(&key);
        }

        debug!(from_block, "Invalidated block hashes from block");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RATE LIMITING (Extended API)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Clean up old rate limit entries.
    ///
    /// Should be called periodically (e.g., every minute) to prevent memory growth.
    ///
    /// # Arguments
    ///
    /// * `max_age_secs` - Remove entries older than this many seconds
    ///
    /// # Returns
    ///
    /// Number of entries removed.
    pub fn cleanup_rate_limits(&self, max_age_secs: u64) -> usize {
        let now = current_timestamp();
        let cutoff = now.saturating_sub(max_age_secs);

        let before = self.rate_limits.len();
        self.rate_limits
            .retain(|_, (window_start, _)| *window_start > cutoff);
        let after = self.rate_limits.len();

        let removed = before.saturating_sub(after);
        if removed > 0 {
            debug!(removed, "Cleaned up rate limit entries");
        }
        removed
    }

    /// Get the number of rate limit entries (for monitoring).
    #[must_use]
    pub fn rate_limit_entry_count(&self) -> usize {
        self.rate_limits.len()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CACHE MAINTENANCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Run pending cache maintenance tasks.
    ///
    /// Moka performs maintenance lazily; this forces it to run immediately.
    /// Useful for tests or before taking memory measurements.
    pub fn run_pending_tasks(&self) {
        self.positions.run_pending_tasks();
        self.global_stats.run_pending_tasks();
        self.level_stats.run_pending_tasks();
        self.leaderboards.run_pending_tasks();
        self.block_hashes.run_pending_tasks();
    }
}

impl Default for MemoryCache {
    fn default() -> Self {
        Self::new()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE TRAIT IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

impl Cache for MemoryCache {
    fn get_position(&self, address: &EthAddress) -> Option<Position> {
        match self.positions.get(address) {
            Some(Some(pos)) => {
                self.hits.fetch_add(1, Ordering::Relaxed);
                Some(pos)
            }
            Some(None) => {
                // Negative cache hit (user has no position)
                self.hits.fetch_add(1, Ordering::Relaxed);
                None
            }
            None => {
                // Cache miss
                self.misses.fetch_add(1, Ordering::Relaxed);
                None
            }
        }
    }

    fn set_position(&self, address: &EthAddress, position: Option<Position>) {
        self.positions.insert(*address, position);
        debug!(%address, "Cached position");
    }

    fn invalidate_position(&self, address: &EthAddress) {
        self.positions.invalidate(address);
        debug!(%address, "Invalidated position cache");
    }

    fn invalidate_all_positions(&self) {
        self.positions.invalidate_all();
        debug!("Invalidated all position cache");
    }

    fn invalidate_level(&self, level: &Level) {
        // Invalidate positions by iterating and checking level
        // This is O(n) but acceptable because:
        // 1. Level-wide invalidations are rare (only after scans/deaths)
        // 2. The position cache is bounded (10K max)
        // 3. We also invalidate level stats which is the primary purpose
        //
        // Note: moka's iter() returns Arc<K>, so we clone the inner value
        // for use with invalidate().
        let keys_to_remove: Vec<_> = self
            .positions
            .iter()
            .filter(|(_, opt_pos)| opt_pos.as_ref().is_some_and(|p| p.level == *level))
            .map(|(k, _)| *k) // Dereference Arc; EthAddress is Copy
            .collect();

        for key in &keys_to_remove {
            self.positions.invalidate(key);
        }

        // Also invalidate level stats
        self.invalidate_level_stats(*level);

        debug!(
            ?level,
            removed = keys_to_remove.len(),
            "Invalidated level cache"
        );
    }

    fn get_global_stats(&self) -> Option<GlobalStats> {
        let result = self.global_stats.get(&());
        if result.is_some() {
            self.hits.fetch_add(1, Ordering::Relaxed);
        } else {
            self.misses.fetch_add(1, Ordering::Relaxed);
        }
        result
    }

    fn set_global_stats(&self, stats: GlobalStats) {
        self.global_stats.insert((), stats);
        debug!("Cached global stats");
    }

    fn check_rate_limit(&self, key: &str, limit: u32, window_secs: u64) -> bool {
        let now = current_timestamp();
        let window_start = now - (now % window_secs);
        let cache_key = format!("{key}:{window_start}");

        let mut entry = self
            .rate_limits
            .entry(cache_key)
            .or_insert((window_start, 0));

        if entry.0 != window_start {
            // New window started
            *entry = (window_start, 1);
            true
        } else if entry.1 < limit {
            entry.1 += 1;
            true
        } else {
            false
        }
    }

    fn get_rate_limit_remaining(&self, key: &str, limit: u32, window_secs: u64) -> Option<u32> {
        let now = current_timestamp();
        let window_start = now - (now % window_secs);
        let cache_key = format!("{key}:{window_start}");

        self.rate_limits.get(&cache_key).map(|entry| {
            if entry.0 == window_start {
                limit.saturating_sub(entry.1)
            } else {
                limit // Window expired, full quota available
            }
        })
    }

    fn clear_all(&self) {
        self.positions.invalidate_all();
        self.global_stats.invalidate_all();
        self.level_stats.invalidate_all();
        self.leaderboards.invalidate_all();
        self.block_hashes.invalidate_all();
        self.rate_limits.clear();

        // Reset counters
        self.hits.store(0, Ordering::Relaxed);
        self.misses.store(0, Ordering::Relaxed);

        debug!("Cleared all caches");
    }

    fn stats(&self) -> CacheStats {
        // entry_count() returns u64; truncation to usize is fine since
        // the cache has a max capacity of 10K entries.
        #[allow(clippy::cast_possible_truncation)]
        let position_count = self.positions.entry_count() as usize;

        CacheStats {
            hits: self.hits.load(Ordering::Relaxed),
            misses: self.misses.load(Ordering::Relaxed),
            position_count,
            has_global_stats: self.global_stats.get(&()).is_some(),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get current Unix timestamp in seconds.
fn current_timestamp() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use std::thread::sleep;

    use alloy::primitives::U256;
    use chrono::Utc;
    use uuid::Uuid;

    use super::*;
    use crate::types::primitives::{GhostStreak, TokenAmount};

    fn sample_address() -> EthAddress {
        EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap()
    }

    fn sample_position(address: EthAddress) -> Position {
        Position {
            id: Uuid::new_v4(),
            user_address: address,
            level: Level::Darknet,
            amount: TokenAmount::from_wei(U256::from(1_000_000_000_000_000_000u128), 18),
            reward_debt: TokenAmount::zero(),
            entry_timestamp: Utc::now(),
            last_add_timestamp: None,
            ghost_streak: GhostStreak::new(5).unwrap(),
            is_alive: true,
            is_extracted: false,
            exit_reason: None,
            exit_timestamp: None,
            extracted_amount: None,
            extracted_rewards: None,
            created_at_block: crate::types::primitives::BlockNumber::new(100),
            updated_at: Utc::now(),
        }
    }

    fn sample_global_stats() -> GlobalStats {
        GlobalStats {
            total_value_locked: TokenAmount::from_wei(U256::from(1_000_000u128), 18),
            total_positions: 100,
            total_deaths: 50,
            total_burned: TokenAmount::from_wei(U256::from(500_000u128), 18),
            total_emissions_distributed: TokenAmount::from_wei(U256::from(250_000u128), 18),
            total_toll_collected: TokenAmount::from_wei(U256::from(10_000u128), 18),
            total_buyback_burned: TokenAmount::from_wei(U256::from(5_000u128), 18),
            system_reset_count: 0,
            updated_at: Utc::now(),
        }
    }

    fn sample_level_stats(level: Level) -> LevelStats {
        LevelStats {
            level,
            total_staked: TokenAmount::from_wei(U256::from(500_000u128), 18),
            alive_count: 50,
            total_deaths: 25,
            total_extracted: 30,
            total_burned: TokenAmount::from_wei(U256::from(100_000u128), 18),
            total_distributed: TokenAmount::from_wei(U256::from(200_000u128), 18),
            highest_ghost_streak: GhostStreak::new(10).unwrap(),
            updated_at: Utc::now(),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POSITION CACHE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn position_cache_hit() {
        let cache = MemoryCache::new();
        let addr = sample_address();
        let pos = sample_position(addr.clone());

        cache.set_position(&addr, Some(pos.clone()));

        let result = cache.get_position(&addr);
        assert!(result.is_some());
        assert_eq!(result.unwrap().id, pos.id);

        let stats = cache.stats();
        assert_eq!(stats.hits, 1);
        assert_eq!(stats.misses, 0);
    }

    #[test]
    fn position_cache_miss() {
        let cache = MemoryCache::new();
        let addr = sample_address();

        let result = cache.get_position(&addr);
        assert!(result.is_none());

        let stats = cache.stats();
        assert_eq!(stats.hits, 0);
        assert_eq!(stats.misses, 1);
    }

    #[test]
    fn position_negative_cache() {
        let cache = MemoryCache::new();
        let addr = sample_address();

        // Cache negative result (user has no position)
        cache.set_position(&addr, None);

        // Should be a cache hit, returning None
        let result = cache.get_position(&addr);
        assert!(result.is_none());

        let stats = cache.stats();
        assert_eq!(stats.hits, 1);
        assert_eq!(stats.misses, 0);
    }

    #[test]
    fn position_invalidate() {
        let cache = MemoryCache::new();
        let addr = sample_address();
        let pos = sample_position(addr.clone());

        cache.set_position(&addr, Some(pos));
        cache.invalidate_position(&addr);

        // Should be a cache miss now
        let result = cache.get_position(&addr);
        assert!(result.is_none());

        let stats = cache.stats();
        assert_eq!(stats.misses, 1);
    }

    #[test]
    fn position_invalidate_all() {
        let cache = MemoryCache::new();
        let addr1 = sample_address();
        let addr2 = EthAddress::from_hex("0xabcdef0123456789abcdef0123456789abcdef01").unwrap();

        cache.set_position(&addr1, Some(sample_position(addr1.clone())));
        cache.set_position(&addr2, Some(sample_position(addr2.clone())));

        // Moka batches internal operations; run pending tasks to sync
        cache.run_pending_tasks();
        assert_eq!(cache.stats().position_count, 2);

        cache.invalidate_all_positions();
        cache.run_pending_tasks();

        assert_eq!(cache.stats().position_count, 0);
    }

    #[test]
    fn invalidate_level() {
        let cache = MemoryCache::new();

        let addr1 = sample_address();
        let addr2 = EthAddress::from_hex("0xabcdef0123456789abcdef0123456789abcdef01").unwrap();

        let mut pos1 = sample_position(addr1.clone());
        pos1.level = Level::Darknet;

        let mut pos2 = sample_position(addr2.clone());
        pos2.level = Level::Subnet;

        cache.set_position(&addr1, Some(pos1));
        cache.set_position(&addr2, Some(pos2));

        // Invalidate Darknet level
        cache.invalidate_level(&Level::Darknet);

        // Darknet position should be gone
        assert!(cache.get_position(&addr1).is_none());

        // Subnet position should remain (minus the miss count from get)
        assert!(cache.get_position(&addr2).is_some());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GLOBAL STATS CACHE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn global_stats_cache_hit() {
        let cache = MemoryCache::new();
        let stats = sample_global_stats();

        cache.set_global_stats(stats.clone());

        let result = cache.get_global_stats();
        assert!(result.is_some());
        assert_eq!(result.unwrap().total_positions, stats.total_positions);

        let cache_stats = cache.stats();
        assert_eq!(cache_stats.hits, 1);
        assert!(cache_stats.has_global_stats);
    }

    #[test]
    fn global_stats_cache_miss() {
        let cache = MemoryCache::new();

        let result = cache.get_global_stats();
        assert!(result.is_none());

        let stats = cache.stats();
        assert_eq!(stats.misses, 1);
        assert!(!stats.has_global_stats);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEVEL STATS CACHE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn level_stats_cache() {
        let cache = MemoryCache::new();
        let stats = sample_level_stats(Level::Darknet);

        cache.set_level_stats(stats.clone());

        let result = cache.get_level_stats(Level::Darknet);
        assert!(result.is_some());
        assert_eq!(result.unwrap().alive_count, 50);

        // Different level should miss
        let result = cache.get_level_stats(Level::Subnet);
        assert!(result.is_none());
    }

    #[test]
    fn level_stats_invalidate() {
        let cache = MemoryCache::new();

        cache.set_level_stats(sample_level_stats(Level::Darknet));
        cache.set_level_stats(sample_level_stats(Level::Subnet));

        cache.invalidate_level_stats(Level::Darknet);

        assert!(cache.get_level_stats(Level::Darknet).is_none());
        assert!(cache.get_level_stats(Level::Subnet).is_some());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEADERBOARD CACHE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn leaderboard_cache() {
        let cache = MemoryCache::new();

        let entries = vec![
            LeaderboardEntry {
                rank: 1,
                user_address: sample_address(),
                score: TokenAmount::from_wei(U256::from(1000u64), 18),
                metadata: None,
            },
            LeaderboardEntry {
                rank: 2,
                user_address: EthAddress::from_hex("0xabcdef0123456789abcdef0123456789abcdef01")
                    .unwrap(),
                score: TokenAmount::from_wei(U256::from(500u64), 18),
                metadata: None,
            },
        ];

        cache.set_leaderboard("ghost_streak", entries.clone());

        let result = cache.get_leaderboard("ghost_streak");
        assert!(result.is_some());
        assert_eq!(result.unwrap().len(), 2);

        // Different leaderboard should miss
        let result = cache.get_leaderboard("total_extracted");
        assert!(result.is_none());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BLOCK HASH CACHE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn block_hash_cache() {
        let cache = MemoryCache::new();

        let hash1 = B256::from([0xAAu8; 32]);
        let hash2 = B256::from([0xBBu8; 32]);

        cache.set_block_hash(100, hash1);
        cache.set_block_hash(101, hash2);

        assert_eq!(cache.get_block_hash(100), Some(hash1));
        assert_eq!(cache.get_block_hash(101), Some(hash2));
        assert_eq!(cache.get_block_hash(102), None);
    }

    #[test]
    fn block_hash_verify() {
        let cache = MemoryCache::new();

        let hash = B256::from([0xAAu8; 32]);
        let wrong_hash = B256::from([0xBBu8; 32]);

        cache.set_block_hash(100, hash);

        // Correct hash
        assert!(cache.verify_block_hash(100, hash));

        // Wrong hash (reorg detected)
        assert!(!cache.verify_block_hash(100, wrong_hash));

        // Unknown block (can't verify, assume ok)
        assert!(cache.verify_block_hash(999, wrong_hash));
    }

    #[test]
    fn invalidate_blocks_from() {
        let cache = MemoryCache::new();

        for i in 100..110 {
            cache.set_block_hash(i, B256::from([i as u8; 32]));
        }

        cache.invalidate_blocks_from(105);
        cache.run_pending_tasks();

        // Blocks before 105 should remain
        assert!(cache.get_block_hash(100).is_some());
        assert!(cache.get_block_hash(104).is_some());

        // Blocks at or after 105 should be gone
        assert!(cache.get_block_hash(105).is_none());
        assert!(cache.get_block_hash(109).is_none());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RATE LIMITING TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn rate_limit_basic() {
        let cache = MemoryCache::new();

        // Allow 3 requests per 60 seconds
        assert!(cache.check_rate_limit("test_key", 3, 60));
        assert!(cache.check_rate_limit("test_key", 3, 60));
        assert!(cache.check_rate_limit("test_key", 3, 60));

        // 4th should be denied
        assert!(!cache.check_rate_limit("test_key", 3, 60));
    }

    #[test]
    fn rate_limit_separate_keys() {
        let cache = MemoryCache::new();

        // Each key has its own limit
        assert!(cache.check_rate_limit("key1", 1, 60));
        assert!(!cache.check_rate_limit("key1", 1, 60)); // key1 exhausted

        assert!(cache.check_rate_limit("key2", 1, 60)); // key2 still ok
    }

    #[test]
    fn rate_limit_remaining() {
        let cache = MemoryCache::new();

        // Before any requests
        assert!(cache.get_rate_limit_remaining("new_key", 5, 60).is_none());

        // After some requests
        cache.check_rate_limit("new_key", 5, 60);
        cache.check_rate_limit("new_key", 5, 60);

        let remaining = cache.get_rate_limit_remaining("new_key", 5, 60);
        assert_eq!(remaining, Some(3));
    }

    #[test]
    fn rate_limit_cleanup() {
        let cache = MemoryCache::new();

        // Create some entries
        cache.check_rate_limit("key1", 10, 60);
        cache.check_rate_limit("key2", 10, 60);

        assert!(cache.rate_limit_entry_count() >= 2);

        // Cleanup with 0 max age should remove everything
        let removed = cache.cleanup_rate_limits(0);
        assert!(removed >= 2);
        assert_eq!(cache.rate_limit_entry_count(), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CLEAR ALL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn clear_all() {
        let cache = MemoryCache::new();

        // Populate all caches
        cache.set_position(&sample_address(), Some(sample_position(sample_address())));
        cache.set_global_stats(sample_global_stats());
        cache.set_level_stats(sample_level_stats(Level::Darknet));
        cache.set_leaderboard("test", vec![]);
        cache.set_block_hash(100, B256::from([0xAA; 32]));
        cache.check_rate_limit("test", 10, 60);

        // Record some hits
        cache.get_position(&sample_address());
        cache.get_global_stats();

        cache.clear_all();
        cache.run_pending_tasks();

        // Everything should be empty
        let stats = cache.stats();
        assert_eq!(stats.position_count, 0);
        assert!(!stats.has_global_stats);
        assert_eq!(stats.hits, 0);
        assert_eq!(stats.misses, 0);

        assert!(cache.get_level_stats(Level::Darknet).is_none());
        assert!(cache.get_leaderboard("test").is_none());
        assert!(cache.get_block_hash(100).is_none());
        assert_eq!(cache.rate_limit_entry_count(), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TTL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn position_ttl_expiration() {
        // Create cache with 100ms TTL for positions
        let cache = MemoryCache::with_ttls(Duration::from_millis(100), Duration::from_secs(60));

        let addr = sample_address();
        cache.set_position(&addr, Some(sample_position(addr.clone())));

        // Should exist immediately
        assert!(cache.get_position(&addr).is_some());

        // Wait for TTL to expire
        sleep(Duration::from_millis(150));
        cache.run_pending_tasks();

        // Should be expired now
        assert!(cache.get_position(&addr).is_none());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HIT RATE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn hit_rate_calculation() {
        let cache = MemoryCache::new();
        let addr = sample_address();

        cache.set_position(&addr, Some(sample_position(addr.clone())));

        // 3 hits
        cache.get_position(&addr);
        cache.get_position(&addr);
        cache.get_position(&addr);

        // 1 miss
        let other = EthAddress::from_hex("0xabcdef0123456789abcdef0123456789abcdef01").unwrap();
        cache.get_position(&other);

        let stats = cache.stats();
        assert_eq!(stats.hits, 3);
        assert_eq!(stats.misses, 1);
        assert!((stats.hit_rate() - 75.0).abs() < f64::EPSILON);
    }
}
