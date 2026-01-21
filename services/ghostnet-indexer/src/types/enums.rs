//! Game enumerations for GHOSTNET.
//!
//! These enums map directly to Solidity enum definitions in the smart contracts.
//! Each enum provides:
//! - Safe conversion from/to numeric values
//! - Database serialization via `sqlx::Type`
//! - JSON serialization via `serde`
//! - Domain-specific helper methods

use serde::{Deserialize, Serialize};
use sqlx::Type;
use thiserror::Error;

// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL - Risk tiers from safest to most dangerous
// ═══════════════════════════════════════════════════════════════════════════════

/// Risk levels from safest (1) to most dangerous (5).
///
/// # Solidity Mapping
/// ```solidity
/// enum Level {
///     NONE,       // 0 - Invalid/No position
///     VAULT,      // 1 - Safest (0% death rate)
///     MAINFRAME,  // 2 - Conservative (2% death rate)
///     SUBNET,     // 3 - Balanced (15% death rate)
///     DARKNET,    // 4 - High risk (40% death rate)
///     BLACK_ICE   // 5 - Maximum risk (90% death rate)
/// }
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive] // Allow future level additions without breaking changes
pub enum Level {
    /// Invalid/No position (value 0)
    None = 0,
    /// Safest tier - 0% death rate, no scans
    Vault = 1,
    /// Conservative tier - 2% death rate, 24h scan interval
    Mainframe = 2,
    /// Balanced tier - 15% death rate, 8h scan interval
    Subnet = 3,
    /// High risk tier - 40% death rate, 2h scan interval
    Darknet = 4,
    /// Maximum risk tier - 90% death rate, 30m scan interval
    BlackIce = 5,
}

impl Level {
    /// Human-readable name for display.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::None => "None",
            Self::Vault => "Vault",
            Self::Mainframe => "Mainframe",
            Self::Subnet => "Subnet",
            Self::Darknet => "Darknet",
            Self::BlackIce => "Black Ice",
        }
    }

    /// Base death rate in basis points (100 = 1%).
    ///
    /// This is the probability of being "traced" during a scan.
    #[must_use]
    pub const fn death_rate_bps(&self) -> u16 {
        match self {
            Self::None | Self::Vault => 0, // 0%
            Self::Mainframe => 200,        // 2%
            Self::Subnet => 1500,          // 15%
            Self::Darknet => 4000,         // 40%
            Self::BlackIce => 9000,        // 90%
        }
    }

    /// Scan frequency in seconds.
    ///
    /// Returns 0 for levels that don't have scans.
    #[must_use]
    pub const fn scan_interval_secs(&self) -> u64 {
        match self {
            Self::None | Self::Vault => 0, // Never (safe)
            Self::Mainframe => 86400,      // 24 hours
            Self::Subnet => 28800,         // 8 hours
            Self::Darknet => 7200,         // 2 hours
            Self::BlackIce => 1800,        // 30 minutes
        }
    }

    /// Returns whether this level has scans (can result in deaths).
    #[must_use]
    pub const fn has_scans(&self) -> bool {
        !matches!(self, Self::None | Self::Vault)
    }

    /// Returns all valid levels (excluding None).
    #[must_use]
    pub const fn all_valid() -> [Self; 5] {
        [
            Self::Vault,
            Self::Mainframe,
            Self::Subnet,
            Self::Darknet,
            Self::BlackIce,
        ]
    }
}

/// Error returned when an invalid level value is provided.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("invalid level value: {0}")]
pub struct InvalidLevel(pub u8);

impl TryFrom<u8> for Level {
    type Error = InvalidLevel;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::None),
            1 => Ok(Self::Vault),
            2 => Ok(Self::Mainframe),
            3 => Ok(Self::Subnet),
            4 => Ok(Self::Darknet),
            5 => Ok(Self::BlackIce),
            _ => Err(InvalidLevel(value)),
        }
    }
}

impl From<Level> for u8 {
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    fn from(level: Level) -> Self {
        level as i16 as Self
    }
}

impl From<Level> for i16 {
    fn from(level: Level) -> Self {
        level as Self
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOOST TYPE - Types of boosts that can be applied to positions
// ═══════════════════════════════════════════════════════════════════════════════

/// Types of boosts that can be applied to positions.
///
/// Boosts are earned through mini-games (Trace Evasion, Hack Runs) and
/// modify position parameters for a limited time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive] // Allow future boost types
pub enum BoostType {
    /// Reduces effective death rate during scans
    DeathReduction = 0,
    /// Multiplies reward earnings
    YieldMultiplier = 1,
}

impl BoostType {
    /// Human-readable name for display.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::DeathReduction => "Death Reduction",
            Self::YieldMultiplier => "Yield Multiplier",
        }
    }

    /// Returns all boost types.
    #[must_use]
    pub const fn all() -> [Self; 2] {
        [Self::DeathReduction, Self::YieldMultiplier]
    }
}

/// Error returned when an invalid boost type value is provided.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("invalid boost type value: {0}")]
pub struct InvalidBoostType(pub u8);

impl TryFrom<u8> for BoostType {
    type Error = InvalidBoostType;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::DeathReduction),
            1 => Ok(Self::YieldMultiplier),
            _ => Err(InvalidBoostType(value)),
        }
    }
}

impl From<BoostType> for u8 {
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    fn from(boost_type: BoostType) -> Self {
        boost_type as i16 as Self
    }
}

impl From<BoostType> for i16 {
    fn from(boost_type: BoostType) -> Self {
        boost_type as Self
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROUND TYPE - Types of prediction market rounds
// ═══════════════════════════════════════════════════════════════════════════════

/// Types of prediction rounds in the `DeadPool` market.
///
/// Each round type has different resolution criteria and betting dynamics.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive] // Allow future round types
pub enum RoundType {
    /// Over/under on deaths in next scan
    DeathCount = 0,
    /// Will a whale (1000+ DATA) position die?
    WhaleDeath = 1,
    /// Will anyone hit 20 survival streak?
    StreakRecord = 2,
    /// Will the reset timer hit <1 hour?
    SystemReset = 3,
}

impl RoundType {
    /// Human-readable name for display.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::DeathCount => "Death Count",
            Self::WhaleDeath => "Whale Death",
            Self::StreakRecord => "Streak Record",
            Self::SystemReset => "System Reset",
        }
    }

    /// Returns all round types.
    #[must_use]
    pub const fn all() -> [Self; 4] {
        [
            Self::DeathCount,
            Self::WhaleDeath,
            Self::StreakRecord,
            Self::SystemReset,
        ]
    }
}

/// Error returned when an invalid round type value is provided.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("invalid round type value: {0}")]
pub struct InvalidRoundType(pub u8);

impl TryFrom<u8> for RoundType {
    type Error = InvalidRoundType;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::DeathCount),
            1 => Ok(Self::WhaleDeath),
            2 => Ok(Self::StreakRecord),
            3 => Ok(Self::SystemReset),
            _ => Err(InvalidRoundType(value)),
        }
    }
}

impl From<RoundType> for u8 {
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    fn from(round_type: RoundType) -> Self {
        round_type as i16 as Self
    }
}

impl From<RoundType> for i16 {
    fn from(round_type: RoundType) -> Self {
        round_type as Self
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXIT REASON - Why a position was closed
// ═══════════════════════════════════════════════════════════════════════════════

/// Reasons why a position was closed.
///
/// Used for analytics and position history tracking.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[sqlx(type_name = "varchar")]
#[non_exhaustive] // Allow future exit reasons
pub enum ExitReason {
    /// User voluntarily extracted their position
    Extracted,
    /// Position was traced (died) in a scan
    Traced,
    /// Position was culled due to level capacity
    Culled,
    /// Position was closed during system reset
    SystemReset,
    /// Position was superseded by a new `JackedIn` event.
    ///
    /// This should rarely happen - it indicates the contract allowed
    /// a user to jack in while already having an active position.
    /// The old position is closed to maintain data consistency.
    Superseded,
}

impl ExitReason {
    /// Human-readable name for display.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::Extracted => "Extracted",
            Self::Traced => "Traced",
            Self::Culled => "Culled",
            Self::SystemReset => "System Reset",
            Self::Superseded => "Superseded",
        }
    }

    /// Whether this exit reason involves losing funds (vs voluntary exit).
    #[must_use]
    pub const fn is_loss(&self) -> bool {
        // Superseded is not a loss - the funds moved to the new position
        matches!(self, Self::Traced | Self::Culled | Self::SystemReset)
    }
}

impl std::fmt::Display for ExitReason {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.name())
    }
}

impl std::str::FromStr for ExitReason {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Extracted" => Ok(Self::Extracted),
            "Traced" => Ok(Self::Traced),
            "Culled" => Ok(Self::Culled),
            "System Reset" | "SystemReset" => Ok(Self::SystemReset),
            "Superseded" => Ok(Self::Superseded),
            _ => Err(format!("Unknown exit reason: {s}")),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    mod level_tests {
        use super::*;

        #[test]
        fn try_from_valid_values() {
            assert_eq!(Level::try_from(0u8), Ok(Level::None));
            assert_eq!(Level::try_from(1u8), Ok(Level::Vault));
            assert_eq!(Level::try_from(2u8), Ok(Level::Mainframe));
            assert_eq!(Level::try_from(3u8), Ok(Level::Subnet));
            assert_eq!(Level::try_from(4u8), Ok(Level::Darknet));
            assert_eq!(Level::try_from(5u8), Ok(Level::BlackIce));
        }

        #[test]
        fn try_from_invalid_values() {
            assert!(Level::try_from(6u8).is_err());
            assert!(Level::try_from(255u8).is_err());
        }

        #[test]
        fn roundtrip_conversion() {
            for level in Level::all_valid() {
                let value: u8 = level.into();
                let back = Level::try_from(value).expect("roundtrip failed");
                assert_eq!(level, back);
            }
        }

        #[test]
        fn death_rates_are_ordered() {
            // Higher levels should have higher death rates
            let levels = Level::all_valid();
            for window in levels.windows(2) {
                assert!(
                    window[0].death_rate_bps() <= window[1].death_rate_bps(),
                    "{:?} should have lower death rate than {:?}",
                    window[0],
                    window[1]
                );
            }
        }

        #[test]
        fn scan_intervals_decrease_with_risk() {
            // Higher risk levels should have more frequent scans
            let risky_levels = [
                Level::Mainframe,
                Level::Subnet,
                Level::Darknet,
                Level::BlackIce,
            ];
            for window in risky_levels.windows(2) {
                assert!(
                    window[0].scan_interval_secs() >= window[1].scan_interval_secs(),
                    "{:?} should have longer interval than {:?}",
                    window[0],
                    window[1]
                );
            }
        }

        #[test]
        fn vault_has_no_scans() {
            assert!(!Level::Vault.has_scans());
            assert_eq!(Level::Vault.scan_interval_secs(), 0);
            assert_eq!(Level::Vault.death_rate_bps(), 0);
        }
    }

    mod boost_type_tests {
        use super::*;

        #[test]
        fn try_from_valid_values() {
            assert_eq!(BoostType::try_from(0u8), Ok(BoostType::DeathReduction));
            assert_eq!(BoostType::try_from(1u8), Ok(BoostType::YieldMultiplier));
        }

        #[test]
        fn try_from_invalid_values() {
            assert!(BoostType::try_from(2u8).is_err());
        }

        #[test]
        fn roundtrip_conversion() {
            for boost in BoostType::all() {
                let value: u8 = boost.into();
                let back = BoostType::try_from(value).expect("roundtrip failed");
                assert_eq!(boost, back);
            }
        }
    }

    mod round_type_tests {
        use super::*;

        #[test]
        fn try_from_valid_values() {
            assert_eq!(RoundType::try_from(0u8), Ok(RoundType::DeathCount));
            assert_eq!(RoundType::try_from(1u8), Ok(RoundType::WhaleDeath));
            assert_eq!(RoundType::try_from(2u8), Ok(RoundType::StreakRecord));
            assert_eq!(RoundType::try_from(3u8), Ok(RoundType::SystemReset));
        }

        #[test]
        fn try_from_invalid_values() {
            assert!(RoundType::try_from(4u8).is_err());
        }

        #[test]
        fn roundtrip_conversion() {
            for round_type in RoundType::all() {
                let value: u8 = round_type.into();
                let back = RoundType::try_from(value).expect("roundtrip failed");
                assert_eq!(round_type, back);
            }
        }
    }

    mod exit_reason_tests {
        use super::*;

        #[test]
        fn extracted_is_not_loss() {
            assert!(!ExitReason::Extracted.is_loss());
        }

        #[test]
        fn traced_is_loss() {
            assert!(ExitReason::Traced.is_loss());
        }

        #[test]
        fn culled_is_loss() {
            assert!(ExitReason::Culled.is_loss());
        }

        #[test]
        fn system_reset_is_loss() {
            assert!(ExitReason::SystemReset.is_loss());
        }

        #[test]
        fn superseded_is_not_loss() {
            // Superseded means funds moved to a new position, not lost
            assert!(!ExitReason::Superseded.is_loss());
        }
    }
}
