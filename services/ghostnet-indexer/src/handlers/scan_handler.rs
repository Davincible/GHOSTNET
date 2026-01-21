//! Scan event handler implementation.
//! Scan event handler implementation.
//!
//! Handles all scan lifecycle events from the `TraceScan` contract:
//! - `ScanExecuted` - Scan initiated with random seed (Phase 1)
//! - `DeathsSubmitted` - Deaths submitted in batches by keepers
//! - `ScanFinalized` - Scan completed with final death counts (Phase 2)
//!
//! # Scan Lifecycle
//!
//! ```text
//! ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
//! │  ScanExecuted   │────▶│ DeathsSubmitted  │────▶│  ScanFinalized  │
//! │   (Phase 1)     │     │  (0..N batches)  │     │    (Phase 2)    │
//! └─────────────────┘     └──────────────────┘     └─────────────────┘
//! ```
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `ScanStore` port for persistence
//! - Uses `Cache` port for cache invalidation
//! - Uses `EventPublisher` port for streaming events

use std::sync::Arc;

use async_trait::async_trait;
use chrono::{TimeZone, Utc};
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

use crate::abi::trace_scan;
use crate::error::Result;
use crate::handlers::ScanPort;
use crate::ports::{Cache, ScanStore};
use crate::types::entities::{Scan, ScanFinalizationData};
use crate::types::enums::Level;
use crate::types::events::EventMetadata;
use crate::types::primitives::TokenAmount;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for scan lifecycle events.
///
/// Processes events from the `TraceScan` contract and maintains
/// scan records in the database.
#[derive(Debug)]
pub struct ScanHandler<S, C> {
    /// Scan store for persistence.
    store: Arc<S>,
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<S, C> ScanHandler<S, C>
where
    S: ScanStore,
    C: Cache,
{
    /// Create a new scan handler.
    pub const fn new(store: Arc<S>, cache: Arc<C>) -> Self {
        Self { store, cache }
    }

    /// Convert a u8 level to our Level enum.
    fn to_level(level: u8) -> Result<Level> {
        Ok(Level::try_from(level)?)
    }

    /// Convert an Alloy U256 to our `TokenAmount` type.
    fn to_token_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Convert a unix timestamp to `DateTime`.
    #[allow(clippy::cast_possible_wrap)]
    fn to_datetime(timestamp: u64) -> chrono::DateTime<Utc> {
        // Note: cast is safe for reasonable timestamps (before year 2262)
        Utc.timestamp_opt(timestamp as i64, 0)
            .single()
            .unwrap_or_else(Utc::now)
    }
}

#[async_trait]
impl<S, C> ScanPort for ScanHandler<S, C>
where
    S: ScanStore + Send + Sync,
    C: Cache + Send + Sync,
{
    /// Handle scan execution (Phase 1).
    ///
    /// Creates a new scan record when a scan is initiated.
    /// The scan uses `prevrandao` as a deterministic seed to determine deaths.
    #[instrument(skip(self, event, meta), fields(level = event.level, scan_id = %event.scanId))]
    async fn handle_scan_executed(
        &self,
        event: trace_scan::ScanExecuted,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let scan_id = event.scanId.to_string();
        let seed = event.seed.to_string();
        let executed_at = Self::to_datetime(event.executedAt);

        // Check if scan already exists (idempotency)
        if let Some(existing) = self.store.get_scan_by_id(&scan_id).await? {
            warn!(
                existing_id = %existing.id,
                "Scan already exists, skipping"
            );
            return Ok(());
        }

        // Create new scan record (Phase 1 - not yet finalized)
        let scan = Scan {
            id: Uuid::new_v4(),
            scan_id: scan_id.clone(),
            level,
            seed,
            executed_at,
            finalized_at: None,
            death_count: None,
            total_dead: None,
            burned: None,
            distributed_same_level: None,
            distributed_upstream: None,
            protocol_fee: None,
            survivor_count: None,
        };

        // Save to database
        self.store.save_scan(&scan).await?;

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        info!(
            scan_uuid = %scan.id,
            level = ?level,
            block = meta.block_number,
            "Scan executed (Phase 1)"
        );

        Ok(())
    }

    /// Handle deaths submission batch.
    ///
    /// Keepers submit death lists in batches to avoid gas limits.
    /// This event is informational - actual death processing happens
    /// in the `DeathHandler` when `DeathsProcessed` is emitted.
    #[instrument(skip(self, event, meta), fields(
        level = event.level,
        scan_id = %event.scanId,
        count = %event.count,
        submitter = %event.submitter
    ))]
    async fn handle_deaths_submitted(
        &self,
        event: trace_scan::DeathsSubmitted,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let scan_id = event.scanId.to_string();
        let count = event.count;
        let total_dead = Self::to_token_amount(&event.totalDead);

        // This event is primarily for tracking keeper submissions
        // The actual death records are created when DeathsProcessed fires
        debug!(
            level = ?level,
            scan_id = %scan_id,
            batch_count = %count,
            batch_total = %total_dead,
            submitter = %event.submitter,
            block = meta.block_number,
            "Deaths batch submitted"
        );

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        Ok(())
    }

    /// Handle scan finalization (Phase 2).
    ///
    /// Completes the scan record with final death counts and distributions.
    #[instrument(skip(self, event, meta), fields(level = event.level, scan_id = %event.scanId))]
    async fn handle_scan_finalized(
        &self,
        event: trace_scan::ScanFinalized,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let scan_id = event.scanId.to_string();
        let finalized_at = Self::to_datetime(event.finalizedAt);

        // Get existing scan, or create incomplete record if missing
        let Some(existing) = self.store.get_scan_by_id(&scan_id).await? else {
            // Scan not found - this could happen if we missed the ScanExecuted event
            // Create a new scan record with what we know
            warn!(
                scan_id = %scan_id,
                "ScanFinalized received but no ScanExecuted found, creating incomplete record"
            );

            let scan = Scan {
                id: Uuid::new_v4(),
                scan_id: scan_id.clone(),
                level,
                seed: "unknown".to_string(), // We don't have the seed
                executed_at: finalized_at,   // Use finalized time as executed
                finalized_at: Some(finalized_at),
                death_count: Some(event.deathCount.try_into().unwrap_or(u32::MAX)),
                total_dead: Some(Self::to_token_amount(&event.totalDead)),
                burned: None,
                distributed_same_level: None,
                distributed_upstream: None,
                protocol_fee: None,
                survivor_count: None,
            };

            self.store.save_scan(&scan).await?;

            info!(
                scan_uuid = %scan.id,
                level = ?level,
                death_count = ?scan.death_count,
                "Incomplete scan created from finalization"
            );

            return Ok(());
        };

        // Check if already finalized (idempotency)
        if existing.is_finalized() {
            warn!(
                scan_id = %scan_id,
                "Scan already finalized, skipping"
            );
            return Ok(());
        }

        // Prepare finalization data
        // Note: We don't have distribution details in ScanFinalized event,
        // those come from CascadeDistributed in GhostCore
        let finalization = ScanFinalizationData {
            finalized_at,
            death_count: event.deathCount.try_into().unwrap_or(u32::MAX),
            total_dead: Self::to_token_amount(&event.totalDead),
            burned: TokenAmount::zero(), // Will be updated by CascadeDistributed
            distributed_same_level: TokenAmount::zero(), // Will be updated by CascadeDistributed
            distributed_upstream: TokenAmount::zero(), // Will be updated by CascadeDistributed
            protocol_fee: TokenAmount::zero(), // Will be updated by CascadeDistributed
            survivor_count: 0,           // Will be updated by SurvivorsUpdated
        };

        // Update scan with finalization data
        self.store.finalize_scan(&scan_id, finalization).await?;

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        info!(
            scan_id = %scan_id,
            level = ?level,
            death_count = %event.deathCount,
            total_dead = %Self::to_token_amount(&event.totalDead),
            block = meta.block_number,
            "Scan finalized (Phase 2)"
        );

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use std::collections::HashMap;
    use std::sync::RwLock;

    use alloy::primitives::U256;
    use chrono::Utc;

    use super::*;
    use crate::ports::MockCache;
    use crate::types::enums::Level;

    // ═══════════════════════════════════════════════════════════════════════════
    // MOCK SCAN STORE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Stateful mock store for testing.
    #[derive(Debug, Default)]
    struct MockScanStore {
        scans: RwLock<HashMap<String, Scan>>,
    }

    impl MockScanStore {
        fn new() -> Self {
            Self::default()
        }

        fn scan_count(&self) -> usize {
            self.scans.read().unwrap().len()
        }

        fn get_scan(&self, scan_id: &str) -> Option<Scan> {
            self.scans.read().unwrap().get(scan_id).cloned()
        }
    }

    #[async_trait]
    impl ScanStore for MockScanStore {
        async fn save_scan(&self, scan: &Scan) -> Result<()> {
            let mut scans = self.scans.write().unwrap();
            scans.insert(scan.scan_id.clone(), scan.clone());
            Ok(())
        }

        async fn finalize_scan(&self, scan_id: &str, data: ScanFinalizationData) -> Result<()> {
            let mut scans = self.scans.write().unwrap();
            if let Some(scan) = scans.get_mut(scan_id) {
                scan.finalized_at = Some(data.finalized_at);
                scan.death_count = Some(data.death_count);
                scan.total_dead = Some(data.total_dead);
                scan.burned = Some(data.burned);
                scan.distributed_same_level = Some(data.distributed_same_level);
                scan.distributed_upstream = Some(data.distributed_upstream);
                scan.protocol_fee = Some(data.protocol_fee);
                scan.survivor_count = Some(data.survivor_count);
                Ok(())
            } else {
                Err(crate::error::InfraError::NotFound.into())
            }
        }

        async fn get_recent_scans(&self, level: Level, limit: u32) -> Result<Vec<Scan>> {
            let scans = self.scans.read().unwrap();
            let mut result: Vec<_> = scans
                .values()
                .filter(|s| s.level == level)
                .cloned()
                .collect();
            result.sort_by(|a, b| b.executed_at.cmp(&a.executed_at));
            result.truncate(limit as usize);
            Ok(result)
        }

        async fn get_scan_by_id(&self, scan_id: &str) -> Result<Option<Scan>> {
            Ok(self.scans.read().unwrap().get(scan_id).cloned())
        }

        async fn get_pending_scans(&self) -> Result<Vec<Scan>> {
            let scans = self.scans.read().unwrap();
            Ok(scans
                .values()
                .filter(|s| s.finalized_at.is_none())
                .cloned()
                .collect())
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn test_address() -> alloy::primitives::Address {
        "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap()
    }

    fn test_metadata() -> EventMetadata {
        EventMetadata {
            block_number: 1000,
            block_hash: [1u8; 32].into(),
            tx_hash: [2u8; 32].into(),
            tx_index: 0,
            log_index: 0,
            timestamp: Utc::now(),
            contract: test_address(),
        }
    }

    fn create_handler() -> (
        ScanHandler<MockScanStore, MockCache>,
        Arc<MockScanStore>,
        Arc<MockCache>,
    ) {
        let store = Arc::new(MockScanStore::new());
        let cache = Arc::new(MockCache::new());
        let handler = ScanHandler::new(Arc::clone(&store), Arc::clone(&cache));
        (handler, store, cache)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<ScanHandler<MockScanStore, MockCache>>();
    }

    #[tokio::test]
    async fn handle_scan_executed_creates_scan() {
        let (handler, store, _cache) = create_handler();

        let event = trace_scan::ScanExecuted {
            level: 3, // Subnet
            scanId: U256::from(1),
            seed: U256::from(123_456_789),
            executedAt: 1_700_000_000,
        };

        let result = handler.handle_scan_executed(event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify scan was created
        assert_eq!(store.scan_count(), 1);

        let scan = store.get_scan("1").unwrap();
        assert_eq!(scan.level, Level::Subnet);
        assert_eq!(scan.seed, "123456789");
        assert!(!scan.is_finalized());
    }

    #[tokio::test]
    async fn handle_scan_executed_is_idempotent() {
        let (handler, store, _cache) = create_handler();

        let event = trace_scan::ScanExecuted {
            level: 3,
            scanId: U256::from(1),
            seed: U256::from(123_456_789),
            executedAt: 1_700_000_000,
        };

        // First call
        handler
            .handle_scan_executed(event.clone(), test_metadata())
            .await
            .unwrap();
        assert_eq!(store.scan_count(), 1);

        // Second call should not create duplicate
        handler
            .handle_scan_executed(event, test_metadata())
            .await
            .unwrap();
        assert_eq!(store.scan_count(), 1);
    }

    #[tokio::test]
    async fn handle_deaths_submitted_logs_batch() {
        let (handler, _store, _cache) = create_handler();

        let event = trace_scan::DeathsSubmitted {
            level: 4,
            scanId: U256::from(1),
            count: U256::from(10),
            totalDead: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            submitter: test_address(),
        };

        // Should succeed without error (just logs)
        let result = handler
            .handle_deaths_submitted(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_scan_finalized_updates_scan() {
        let (handler, store, _cache) = create_handler();

        // First create a scan
        let executed = trace_scan::ScanExecuted {
            level: 3,
            scanId: U256::from(1),
            seed: U256::from(123_456_789),
            executedAt: 1_700_000_000,
        };
        handler
            .handle_scan_executed(executed, test_metadata())
            .await
            .unwrap();

        // Then finalize it
        let finalized = trace_scan::ScanFinalized {
            level: 3,
            scanId: U256::from(1),
            deathCount: U256::from(5),
            totalDead: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            finalizedAt: 1_700_001_000,
        };
        let result = handler
            .handle_scan_finalized(finalized, test_metadata())
            .await;
        assert!(result.is_ok());

        // Verify scan was finalized
        let scan = store.get_scan("1").unwrap();
        assert!(scan.is_finalized());
        assert_eq!(scan.death_count, Some(5));
        assert_eq!(scan.total_dead.as_ref().unwrap().to_string(), "500");
    }

    #[tokio::test]
    async fn handle_scan_finalized_creates_incomplete_if_missing() {
        let (handler, store, _cache) = create_handler();

        // Finalize without prior ScanExecuted
        let finalized = trace_scan::ScanFinalized {
            level: 4,
            scanId: U256::from(99),
            deathCount: U256::from(3),
            totalDead: U256::from(300_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            finalizedAt: 1_700_001_000,
        };
        let result = handler
            .handle_scan_finalized(finalized, test_metadata())
            .await;
        assert!(result.is_ok());

        // Verify incomplete scan was created
        let scan = store.get_scan("99").unwrap();
        assert_eq!(scan.seed, "unknown");
        assert_eq!(scan.level, Level::Darknet);
    }

    #[tokio::test]
    async fn handle_scan_finalized_is_idempotent() {
        let (handler, store, _cache) = create_handler();

        // Create and finalize
        let executed = trace_scan::ScanExecuted {
            level: 3,
            scanId: U256::from(1),
            seed: U256::from(123),
            executedAt: 1_700_000_000,
        };
        handler
            .handle_scan_executed(executed, test_metadata())
            .await
            .unwrap();

        let finalized = trace_scan::ScanFinalized {
            level: 3,
            scanId: U256::from(1),
            deathCount: U256::from(5),
            totalDead: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            finalizedAt: 1_700_001_000,
        };
        handler
            .handle_scan_finalized(finalized.clone(), test_metadata())
            .await
            .unwrap();

        let scan_after_first = store.get_scan("1").unwrap();

        // Second finalize should not error
        let result = handler
            .handle_scan_finalized(finalized, test_metadata())
            .await;
        assert!(result.is_ok());

        // Scan should be unchanged
        let scan_after_second = store.get_scan("1").unwrap();
        assert_eq!(
            scan_after_first.finalized_at,
            scan_after_second.finalized_at
        );
    }

    #[test]
    fn to_level_valid_values() {
        assert!(ScanHandler::<MockScanStore, MockCache>::to_level(0).is_ok());
        assert!(ScanHandler::<MockScanStore, MockCache>::to_level(1).is_ok());
        assert!(ScanHandler::<MockScanStore, MockCache>::to_level(5).is_ok());
    }

    #[test]
    fn to_level_invalid_value() {
        assert!(ScanHandler::<MockScanStore, MockCache>::to_level(6).is_err());
        assert!(ScanHandler::<MockScanStore, MockCache>::to_level(255).is_err());
    }
}
