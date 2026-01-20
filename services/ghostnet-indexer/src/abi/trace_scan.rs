//! ABI bindings for `TraceScan` contract events.
//!
//! `TraceScan` handles the scan execution lifecycle:
//! 1. `ScanExecuted` - Phase 1: Scan initiated with random seed
//! 2. `DeathsSubmitted` - Deaths are submitted in batches by keepers
//! 3. `ScanFinalized` - Phase 2: Scan completed, all deaths processed
//!
//! # Scan Flow
//!
//! ```text
//! ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
//! │  ScanExecuted   │────▶│ DeathsSubmitted  │────▶│  ScanFinalized  │
//! │   (Phase 1)     │     │  (0..N batches)  │     │    (Phase 2)    │
//! └─────────────────┘     └──────────────────┘     └─────────────────┘
//! ```
//!
//! # Solidity Contract
//!
//! ```solidity
//! contract TraceScan {
//!     event ScanExecuted(uint8 indexed level, uint256 indexed scanId, uint256 seed, uint64 executedAt);
//!     event DeathsSubmitted(uint8 indexed level, uint256 indexed scanId, uint256 count, uint256 totalDead, address indexed submitter);
//!     event ScanFinalized(uint8 indexed level, uint256 indexed scanId, uint256 deathCount, uint256 totalDead, uint64 finalizedAt);
//! }
//! ```

use alloy::sol;

sol! {
    /// Emitted when a scan is executed (Phase 1).
    ///
    /// A scan uses `prevrandao` as a deterministic seed to determine
    /// which positions will be "traced" (killed).
    ///
    /// # Indexed Fields
    /// - `level`: Which level is being scanned (1-5)
    /// - `scanId`: Unique scan identifier (incrementing counter)
    ///
    /// # Data Fields
    /// - `seed`: Deterministic seed from `prevrandao`
    /// - `executedAt`: Unix timestamp when scan was executed
    #[derive(Debug, PartialEq, Eq)]
    event ScanExecuted(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 seed,
        uint64 executedAt
    );

    /// Emitted when deaths are submitted in a batch.
    ///
    /// Keepers submit death lists in batches to avoid gas limits.
    /// Multiple `DeathsSubmitted` events may occur per scan.
    ///
    /// # Indexed Fields
    /// - `level`: Which level
    /// - `scanId`: Which scan
    /// - `submitter`: Keeper who submitted (receives rewards)
    ///
    /// # Data Fields
    /// - `count`: Deaths in this batch
    /// - `totalDead`: Total DATA from deaths in this batch
    #[derive(Debug, PartialEq, Eq)]
    event DeathsSubmitted(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 count,
        uint256 totalDead,
        address indexed submitter
    );

    /// Emitted when a scan is finalized (Phase 2).
    ///
    /// After all deaths are submitted, the scan is finalized.
    /// This triggers reward distribution and survivor streak updates.
    ///
    /// # Indexed Fields
    /// - `level`: Which level
    /// - `scanId`: Which scan
    ///
    /// # Data Fields
    /// - `deathCount`: Total deaths processed
    /// - `totalDead`: Total DATA lost
    /// - `finalizedAt`: Unix timestamp
    #[derive(Debug, PartialEq, Eq)]
    event ScanFinalized(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 deathCount,
        uint256 totalDead,
        uint64 finalizedAt
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn scan_executed_signature() {
        assert_eq!(
            ScanExecuted::SIGNATURE,
            "ScanExecuted(uint8,uint256,uint256,uint64)"
        );
    }

    #[test]
    fn deaths_submitted_signature() {
        assert_eq!(
            DeathsSubmitted::SIGNATURE,
            "DeathsSubmitted(uint8,uint256,uint256,uint256,address)"
        );
    }

    #[test]
    fn scan_finalized_signature() {
        assert_eq!(
            ScanFinalized::SIGNATURE,
            "ScanFinalized(uint8,uint256,uint256,uint256,uint64)"
        );
    }

    #[test]
    fn all_trace_scan_events_have_unique_signatures() {
        let signatures = [
            ScanExecuted::SIGNATURE_HASH,
            DeathsSubmitted::SIGNATURE_HASH,
            ScanFinalized::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            3,
            "All TraceScan events should have unique signatures"
        );
    }
}
