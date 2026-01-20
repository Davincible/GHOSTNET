//! ABI bindings for `DeadPool` contract events.
//!
//! `DeadPool` is the prediction market for betting on game outcomes:
//! - Death count predictions (over/under)
//! - Whale death predictions
//! - Streak record predictions
//! - System reset predictions
//!
//! # Round Lifecycle
//!
//! ```text
//! ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
//! │  RoundCreated   │────▶│    BetPlaced     │────▶│  RoundResolved  │
//! │                 │     │   (0..N bets)    │     │                 │
//! └─────────────────┘     └──────────────────┘     └────────┬────────┘
//!                                                           │
//!                                                           ▼
//!                                                  ┌─────────────────┐
//!                                                  │ WinningsClaimed │
//!                                                  │   (per winner)  │
//!                                                  └─────────────────┘
//! ```
//!
//! # Round Types
//!
//! | Type | Description |
//! |------|-------------|
//! | `DeathCount` (0) | Over/under on deaths in next scan |
//! | `WhaleDeath` (1) | Will a 1000+ DATA position die? |
//! | `StreakRecord` (2) | Will anyone hit 20 survival streak? |
//! | `SystemReset` (3) | Will the reset timer hit <1 hour? |

use alloy::sol;

sol! {
    /// Emitted when a new betting round is created.
    ///
    /// # Indexed Fields
    /// - `roundId`: Unique round identifier
    /// - `targetLevel`: Which level (if applicable, 0 for global rounds)
    ///
    /// # Data Fields
    /// - `roundType`: Type (0=DeathCount, 1=WhaleDeath, 2=StreakRecord, 3=SystemReset)
    /// - `line`: Over/under line (interpretation depends on round type)
    /// - `deadline`: Betting closes at this Unix timestamp
    #[derive(Debug, PartialEq, Eq)]
    event RoundCreated(
        uint256 indexed roundId,
        uint8 roundType,
        uint8 indexed targetLevel,
        uint256 line,
        uint64 deadline
    );

    /// Emitted when a bet is placed.
    ///
    /// # Indexed Fields
    /// - `roundId`: Which round
    /// - `user`: Bettor's address
    ///
    /// # Data Fields
    /// - `isOver`: true = betting OVER, false = betting UNDER
    /// - `amount`: Amount wagered in DATA tokens
    #[derive(Debug, PartialEq, Eq)]
    event BetPlaced(
        uint256 indexed roundId,
        address indexed user,
        bool isOver,
        uint256 amount
    );

    /// Emitted when a round is resolved.
    ///
    /// # Indexed Fields
    /// - `roundId`: Which round
    ///
    /// # Data Fields
    /// - `outcome`: true = OVER won, false = UNDER won
    /// - `totalPot`: Total pot size
    /// - `burned`: Rake burned (5% of pot)
    #[derive(Debug, PartialEq, Eq)]
    event RoundResolved(
        uint256 indexed roundId,
        bool outcome,
        uint256 totalPot,
        uint256 burned
    );

    /// Emitted when winnings are claimed.
    ///
    /// # Indexed Fields
    /// - `roundId`: Which round
    /// - `user`: Winner's address
    ///
    /// # Data Fields
    /// - `amount`: Payout amount
    #[derive(Debug, PartialEq, Eq)]
    event WinningsClaimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn round_created_signature() {
        assert_eq!(
            RoundCreated::SIGNATURE,
            "RoundCreated(uint256,uint8,uint8,uint256,uint64)"
        );
    }

    #[test]
    fn bet_placed_signature() {
        assert_eq!(
            BetPlaced::SIGNATURE,
            "BetPlaced(uint256,address,bool,uint256)"
        );
    }

    #[test]
    fn round_resolved_signature() {
        assert_eq!(
            RoundResolved::SIGNATURE,
            "RoundResolved(uint256,bool,uint256,uint256)"
        );
    }

    #[test]
    fn winnings_claimed_signature() {
        assert_eq!(
            WinningsClaimed::SIGNATURE,
            "WinningsClaimed(uint256,address,uint256)"
        );
    }

    #[test]
    fn all_dead_pool_events_have_unique_signatures() {
        let signatures = [
            RoundCreated::SIGNATURE_HASH,
            BetPlaced::SIGNATURE_HASH,
            RoundResolved::SIGNATURE_HASH,
            WinningsClaimed::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            4,
            "All DeadPool events should have unique signatures"
        );
    }
}
