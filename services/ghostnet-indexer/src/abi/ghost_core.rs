//! ABI bindings for `GhostCore` contract events.
//!
//! `GhostCore` is the main game contract that handles:
//! - Position entry (`JackedIn`) and exit (`Extracted`)
//! - Stake additions (`StakeAdded`)
//! - Death processing after scans
//! - Survivor updates and cascade distributions
//! - Boost applications from mini-games
//! - System reset (doomsday clock)
//! - Position culling (capacity management)
//!
//! # Solidity Contract
//!
//! ```solidity
//! contract GhostCore {
//!     event JackedIn(address indexed user, uint256 amount, uint8 indexed level, uint256 newTotal);
//!     event StakeAdded(address indexed user, uint256 amount, uint256 newTotal);
//!     event Extracted(address indexed user, uint256 amount, uint256 rewards);
//!     // ... etc
//! }
//! ```

use alloy::sol;

sol! {
    /// Emitted when a user enters a new position.
    ///
    /// # Indexed Fields
    /// - `user`: User's wallet address
    /// - `level`: Risk level (1-5, where 1=Vault, 5=BlackIce)
    ///
    /// # Data Fields
    /// - `amount`: Amount of DATA tokens staked
    /// - `newTotal`: Total staked after this action
    #[derive(Debug, PartialEq, Eq)]
    event JackedIn(
        address indexed user,
        uint256 amount,
        uint8 indexed level,
        uint256 newTotal
    );

    /// Emitted when a user adds to an existing position.
    ///
    /// # Indexed Fields
    /// - `user`: User's wallet address
    ///
    /// # Data Fields
    /// - `amount`: Amount added
    /// - `newTotal`: New total stake
    #[derive(Debug, PartialEq, Eq)]
    event StakeAdded(
        address indexed user,
        uint256 amount,
        uint256 newTotal
    );

    /// Emitted when a user extracts their position.
    ///
    /// # Indexed Fields
    /// - `user`: User's wallet address
    ///
    /// # Data Fields
    /// - `amount`: Principal returned
    /// - `rewards`: Rewards earned
    #[derive(Debug, PartialEq, Eq)]
    event Extracted(
        address indexed user,
        uint256 amount,
        uint256 rewards
    );

    /// Emitted when positions are marked dead from a scan.
    ///
    /// # Indexed Fields
    /// - `level`: Which level was scanned
    ///
    /// # Data Fields
    /// - `count`: Number of deaths in this batch
    /// - `totalDead`: Total DATA from dead positions
    /// - `burned`: Amount burned (30%)
    /// - `distributed`: Amount distributed to survivors
    #[derive(Debug, PartialEq, Eq)]
    event DeathsProcessed(
        uint8 indexed level,
        uint256 count,
        uint256 totalDead,
        uint256 burned,
        uint256 distributed
    );

    /// Emitted when ghost streaks are incremented for survivors.
    ///
    /// # Indexed Fields
    /// - `level`: Which level
    ///
    /// # Data Fields
    /// - `count`: Number of survivors
    #[derive(Debug, PartialEq, Eq)]
    event SurvivorsUpdated(
        uint8 indexed level,
        uint256 count
    );

    /// Emitted when cascade rewards are distributed.
    ///
    /// When deaths occur, rewards cascade:
    /// - 30% to same-level survivors
    /// - 30% to upstream (safer) levels
    /// - 30% burned
    /// - 10% to protocol treasury
    ///
    /// # Indexed Fields
    /// - `sourceLevel`: Level where deaths occurred
    ///
    /// # Data Fields
    /// - `sameLevelAmount`: Distributed to same-level survivors
    /// - `upstreamAmount`: Distributed to safer levels
    /// - `burnAmount`: Burned
    /// - `protocolAmount`: To treasury
    #[derive(Debug, PartialEq, Eq)]
    event CascadeDistributed(
        uint8 indexed sourceLevel,
        uint256 sameLevelAmount,
        uint256 upstreamAmount,
        uint256 burnAmount,
        uint256 protocolAmount
    );

    /// Emitted when emissions are added to a level.
    ///
    /// # Indexed Fields
    /// - `level`: Target level
    ///
    /// # Data Fields
    /// - `amount`: Amount of emissions
    #[derive(Debug, PartialEq, Eq)]
    event EmissionsAdded(
        uint8 indexed level,
        uint256 amount
    );

    /// Emitted when a boost is applied to a user.
    ///
    /// Boosts are earned through mini-games:
    /// - Trace Evasion (typing game) → Death reduction
    /// - Hack Runs → Yield multiplier
    ///
    /// # Indexed Fields
    /// - `user`: User receiving boost
    ///
    /// # Data Fields
    /// - `boostType`: Type (0=DeathReduction, 1=YieldMultiplier)
    /// - `valueBps`: Boost value in basis points (e.g., 3500 = 35%)
    /// - `expiry`: Unix timestamp when boost expires
    #[derive(Debug, PartialEq, Eq)]
    event BoostApplied(
        address indexed user,
        uint8 boostType,
        uint16 valueBps,
        uint64 expiry
    );

    /// Emitted when system reset is triggered (doomsday clock hits zero).
    ///
    /// # Indexed Fields
    /// - `jackpotWinner`: Last depositor wins jackpot
    ///
    /// # Data Fields
    /// - `totalPenalty`: Total penalty extracted from all positions
    /// - `jackpotAmount`: Jackpot payout
    #[derive(Debug, PartialEq, Eq)]
    event SystemResetTriggered(
        uint256 totalPenalty,
        address indexed jackpotWinner,
        uint256 jackpotAmount
    );

    /// Emitted when a position is culled due to level capacity.
    ///
    /// When a level reaches capacity, the oldest/smallest position
    /// is culled to make room for new entrants.
    ///
    /// # Indexed Fields
    /// - `victim`: User who was culled
    /// - `newEntrant`: User who triggered culling
    ///
    /// # Data Fields
    /// - `penaltyAmount`: Penalty taken from victim
    /// - `returnedAmount`: Amount returned to victim
    #[derive(Debug, PartialEq, Eq)]
    event PositionCulled(
        address indexed victim,
        uint256 penaltyAmount,
        uint256 returnedAmount,
        address indexed newEntrant
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn jacked_in_signature() {
        assert_eq!(
            JackedIn::SIGNATURE,
            "JackedIn(address,uint256,uint8,uint256)"
        );
        // Verify signature hash is 32 bytes
        assert_eq!(JackedIn::SIGNATURE_HASH.len(), 32);
    }

    #[test]
    fn extracted_signature() {
        assert_eq!(Extracted::SIGNATURE, "Extracted(address,uint256,uint256)");
    }

    #[test]
    fn deaths_processed_signature() {
        assert_eq!(
            DeathsProcessed::SIGNATURE,
            "DeathsProcessed(uint8,uint256,uint256,uint256,uint256)"
        );
    }

    #[test]
    fn boost_applied_signature() {
        assert_eq!(
            BoostApplied::SIGNATURE,
            "BoostApplied(address,uint8,uint16,uint64)"
        );
    }

    #[test]
    fn system_reset_signature() {
        assert_eq!(
            SystemResetTriggered::SIGNATURE,
            "SystemResetTriggered(uint256,address,uint256)"
        );
    }

    #[test]
    fn cascade_distributed_signature() {
        assert_eq!(
            CascadeDistributed::SIGNATURE,
            "CascadeDistributed(uint8,uint256,uint256,uint256,uint256)"
        );
    }

    #[test]
    fn all_ghost_core_events_have_unique_signatures() {
        let signatures = [
            JackedIn::SIGNATURE_HASH,
            StakeAdded::SIGNATURE_HASH,
            Extracted::SIGNATURE_HASH,
            DeathsProcessed::SIGNATURE_HASH,
            SurvivorsUpdated::SIGNATURE_HASH,
            CascadeDistributed::SIGNATURE_HASH,
            EmissionsAdded::SIGNATURE_HASH,
            BoostApplied::SIGNATURE_HASH,
            SystemResetTriggered::SIGNATURE_HASH,
            PositionCulled::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            10,
            "All GhostCore events should have unique signatures"
        );
    }
}
