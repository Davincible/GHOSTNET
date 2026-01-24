//! Behavior profiles for wallet personality simulation.
//!
//! Profiles define how a wallet behaves: how often it acts, what risks it takes,
//! when it's active, and how patient it is. This creates natural variation in
//! wallet behavior to avoid detection patterns.
//!
//! # Built-in Profiles
//!
//! | Profile | Risk | Activity | Description |
//! |---------|------|----------|-------------|
//! | `whale` | Low | Low | Large, patient positions |
//! | `grinder` | Medium | High | Active, methodical |
//! | `degen` | High | Very High | Risk-seeking, always active |
//! | `casual` | Medium | Low | Occasional, relaxed |
//! | `sniper` | Very High | High | Quick entries/exits |
//!
//! # Example
//!
//! ```
//! use fleet_core::profiles::BehaviorProfile;
//!
//! let profile = BehaviorProfile::degen();
//! assert!(profile.risk_tolerance > 0.8);
//! assert!(profile.activity_level > 10.0);
//! ```

use std::ops::RangeInclusive;

use chrono::Duration;
use rand::Rng;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR PROFILE
// ═══════════════════════════════════════════════════════════════════════════════

/// Defines behavioral characteristics for a wallet.
///
/// Profiles are generic and don't know about specific protocols. They define
/// general behavioral parameters that plugins interpret for their specific context.
///
/// # Parameters
///
/// - **risk_tolerance**: How much risk the wallet accepts (0.0 = none, 1.0 = maximum)
/// - **activity_level**: Approximate actions per hour
/// - **patience**: How long to hold positions (0.0 = impatient, 1.0 = very patient)
/// - **action_interval**: Time between actions with jitter
/// - **active_hours**: UTC hours when the wallet is most active
/// - **afk_behavior**: Probability and duration of going AFK
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BehaviorProfile {
    /// Profile name (e.g., "whale", "degen").
    pub name: String,

    /// Risk tolerance from 0.0 (risk-averse) to 1.0 (risk-seeking).
    ///
    /// Plugins use this to decide which risk levels to enter, bet sizes, etc.
    pub risk_tolerance: f64,

    /// Target actions per hour (approximate).
    ///
    /// Higher values mean more frequent actions. The scheduler uses this
    /// along with `action_interval_base` to determine timing.
    pub activity_level: f64,

    /// Patience factor from 0.0 (impatient) to 1.0 (very patient).
    ///
    /// Plugins use this to decide when to exit positions, how long to wait
    /// for better conditions, etc.
    pub patience: f64,

    /// Base interval between actions in seconds.
    ///
    /// Combined with `action_interval_jitter_pct` to create varied timing.
    pub action_interval_secs: u64,

    /// Jitter percentage applied to action interval (0-100).
    ///
    /// An interval of 3600s with 50% jitter produces intervals from 1800-5400s.
    pub action_interval_jitter_pct: u8,

    /// UTC hours when the wallet is most active (inclusive range).
    ///
    /// Outside these hours, activity is reduced by `off_hours_factor`.
    pub active_hours_start: u8,

    /// End of active hours (inclusive, wraps around midnight).
    pub active_hours_end: u8,

    /// Activity multiplier outside active hours (0.0-1.0).
    ///
    /// A value of 0.3 means 30% chance of acting outside active hours.
    pub off_hours_factor: f64,

    /// Probability of going AFK on each action decision (0.0-1.0).
    pub afk_probability: f64,

    /// Minimum AFK duration in hours.
    pub afk_min_hours: u64,

    /// Maximum AFK duration in hours.
    pub afk_max_hours: u64,
}

impl BehaviorProfile {
    /// Create a new profile with custom parameters.
    #[must_use]
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            risk_tolerance: 0.5,
            activity_level: 5.0,
            patience: 0.5,
            action_interval_secs: 3600,
            action_interval_jitter_pct: 50,
            active_hours_start: 8,
            active_hours_end: 22,
            off_hours_factor: 0.3,
            afk_probability: 0.1,
            afk_min_hours: 4,
            afk_max_hours: 24,
        }
    }

    /// Calculate the next action interval with jitter.
    ///
    /// Returns a duration that should be added to the current time to get
    /// the next scheduled action time.
    #[must_use]
    #[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation)]
    pub fn next_interval(&self, rng: &mut impl Rng) -> Duration {
        let base = self.action_interval_secs as f64;
        let jitter_range = base * (f64::from(self.action_interval_jitter_pct) / 100.0);

        // Random jitter from -jitter_range to +jitter_range
        let jitter = rng.random_range(-jitter_range..=jitter_range);
        let interval_secs = (base + jitter).max(60.0); // Minimum 1 minute

        Duration::seconds(interval_secs as i64)
    }

    /// Check if the current hour is within active hours.
    #[must_use]
    pub const fn is_active_hour(&self, hour: u8) -> bool {
        if self.active_hours_start <= self.active_hours_end {
            // Normal range (e.g., 8-22)
            hour >= self.active_hours_start && hour <= self.active_hours_end
        } else {
            // Wraps around midnight (e.g., 22-6)
            hour >= self.active_hours_start || hour <= self.active_hours_end
        }
    }

    /// Decide whether to act based on current hour and RNG.
    ///
    /// Returns `true` if the wallet should consider acting now, accounting
    /// for active hours and off-hours factor.
    #[must_use]
    pub fn should_act_now(&self, hour: u8, rng: &mut impl Rng) -> bool {
        if self.is_active_hour(hour) {
            true
        } else {
            rng.random_bool(self.off_hours_factor)
        }
    }

    /// Decide whether to go AFK based on probability.
    ///
    /// Returns `Some(duration)` if the wallet should go AFK, `None` otherwise.
    #[must_use]
    #[allow(clippy::cast_possible_wrap)] // hours will not exceed i64::MAX
    pub fn maybe_go_afk(&self, rng: &mut impl Rng) -> Option<Duration> {
        if rng.random_bool(self.afk_probability) {
            let hours = rng.random_range(self.afk_min_hours..=self.afk_max_hours);
            Some(Duration::hours(hours as i64))
        } else {
            None
        }
    }

    /// Get the active hours as a range (for display/serialization).
    #[must_use]
    pub const fn active_hours(&self) -> RangeInclusive<u8> {
        self.active_hours_start..=self.active_hours_end
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRESET PROFILES
    // ─────────────────────────────────────────────────────────────────────────

    /// Whale profile: large positions, low risk, patient, infrequent actions.
    ///
    /// Characteristics:
    /// - Low risk tolerance (0.2)
    /// - ~2 actions per hour
    /// - Very patient (0.9)
    /// - Long intervals with high jitter
    /// - Sometimes goes AFK for days
    #[must_use]
    pub fn whale() -> Self {
        Self {
            name: "whale".into(),
            risk_tolerance: 0.2,
            activity_level: 2.0,
            patience: 0.9,
            action_interval_secs: 7200, // 2 hours
            action_interval_jitter_pct: 40,
            active_hours_start: 14,
            active_hours_end: 22,
            off_hours_factor: 0.3,
            afk_probability: 0.1,
            afk_min_hours: 12,
            afk_max_hours: 48,
        }
    }

    /// Grinder profile: methodical, medium risk, high activity.
    ///
    /// Characteristics:
    /// - Medium risk tolerance (0.5)
    /// - ~7 actions per hour
    /// - Medium patience (0.5)
    /// - 30-minute base interval
    /// - Rarely goes AFK
    #[must_use]
    pub fn grinder() -> Self {
        Self {
            name: "grinder".into(),
            risk_tolerance: 0.5,
            activity_level: 7.0,
            patience: 0.5,
            action_interval_secs: 1800, // 30 minutes
            action_interval_jitter_pct: 50,
            active_hours_start: 8,
            active_hours_end: 23,
            off_hours_factor: 0.5,
            afk_probability: 0.05,
            afk_min_hours: 4,
            afk_max_hours: 12,
        }
    }

    /// Degen profile: high risk, very active, impatient.
    ///
    /// Characteristics:
    /// - High risk tolerance (0.85)
    /// - ~15 actions per hour
    /// - Impatient (0.3)
    /// - 15-minute base interval with high jitter
    /// - Almost never goes AFK
    #[must_use]
    pub fn degen() -> Self {
        Self {
            name: "degen".into(),
            risk_tolerance: 0.85,
            activity_level: 15.0,
            patience: 0.3,
            action_interval_secs: 900, // 15 minutes
            action_interval_jitter_pct: 60,
            active_hours_start: 0,  // Always active
            active_hours_end: 23,
            off_hours_factor: 0.8,
            afk_probability: 0.02,
            afk_min_hours: 1,
            afk_max_hours: 4,
        }
    }

    /// Casual profile: relaxed, medium risk, irregular activity.
    ///
    /// Characteristics:
    /// - Medium risk tolerance (0.4)
    /// - ~3 actions per hour
    /// - Medium-high patience (0.6)
    /// - 1-hour base interval with very high jitter
    /// - Often goes AFK for long periods
    #[must_use]
    pub fn casual() -> Self {
        Self {
            name: "casual".into(),
            risk_tolerance: 0.4,
            activity_level: 3.0,
            patience: 0.6,
            action_interval_secs: 3600, // 1 hour
            action_interval_jitter_pct: 80,
            active_hours_start: 10,
            active_hours_end: 20,
            off_hours_factor: 0.2,
            afk_probability: 0.2,
            afk_min_hours: 6,
            afk_max_hours: 72,
        }
    }

    /// Sniper profile: very high risk, quick entries/exits, focused bursts.
    ///
    /// Characteristics:
    /// - Very high risk tolerance (0.95)
    /// - ~12 actions per hour
    /// - Very impatient (0.1)
    /// - 10-minute base interval
    /// - Moderate AFK (recharging between hunts)
    #[must_use]
    pub fn sniper() -> Self {
        Self {
            name: "sniper".into(),
            risk_tolerance: 0.95,
            activity_level: 12.0,
            patience: 0.1,
            action_interval_secs: 600, // 10 minutes
            action_interval_jitter_pct: 40,
            active_hours_start: 0,
            active_hours_end: 23,
            off_hours_factor: 1.0, // Always ready
            afk_probability: 0.3,  // But takes breaks
            afk_min_hours: 2,
            afk_max_hours: 24,
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VALIDATION
    // ─────────────────────────────────────────────────────────────────────────

    /// Validate that all fields are within acceptable ranges.
    ///
    /// Returns a list of validation errors, or an empty vector if valid.
    ///
    /// # Validated Fields
    ///
    /// | Field | Valid Range | Description |
    /// |-------|-------------|-------------|
    /// | `risk_tolerance` | 0.0-1.0 | Probability value |
    /// | `patience` | 0.0-1.0 | Probability value |
    /// | `off_hours_factor` | 0.0-1.0 | Probability value |
    /// | `afk_probability` | 0.0-1.0 | Probability value |
    /// | `active_hours_*` | 0-23 | Valid UTC hours |
    /// | `activity_level` | > 0 | Must be positive |
    /// | `action_interval_secs` | > 0 | Must be positive |
    /// | `afk_min_hours` | <= afk_max_hours | Logical ordering |
    ///
    /// # Example
    ///
    /// ```
    /// use fleet_core::profiles::BehaviorProfile;
    ///
    /// let profile = BehaviorProfile::degen();
    /// let errors = profile.validate();
    /// assert!(errors.is_empty());
    ///
    /// let mut bad = BehaviorProfile::new("bad");
    /// bad.risk_tolerance = 1.5; // Invalid!
    /// let errors = bad.validate();
    /// assert!(!errors.is_empty());
    /// ```
    #[must_use]
    pub fn validate(&self) -> Vec<ProfileValidationError> {
        let mut errors = Vec::new();

        // Probability fields must be 0.0-1.0
        if !(0.0..=1.0).contains(&self.risk_tolerance) {
            errors.push(ProfileValidationError::InvalidProbability {
                field: "risk_tolerance",
                value: self.risk_tolerance,
            });
        }
        if !(0.0..=1.0).contains(&self.patience) {
            errors.push(ProfileValidationError::InvalidProbability {
                field: "patience",
                value: self.patience,
            });
        }
        if !(0.0..=1.0).contains(&self.off_hours_factor) {
            errors.push(ProfileValidationError::InvalidProbability {
                field: "off_hours_factor",
                value: self.off_hours_factor,
            });
        }
        if !(0.0..=1.0).contains(&self.afk_probability) {
            errors.push(ProfileValidationError::InvalidProbability {
                field: "afk_probability",
                value: self.afk_probability,
            });
        }

        // Hours must be 0-23
        if self.active_hours_start > 23 {
            errors.push(ProfileValidationError::InvalidHour {
                field: "active_hours_start",
                value: self.active_hours_start,
            });
        }
        if self.active_hours_end > 23 {
            errors.push(ProfileValidationError::InvalidHour {
                field: "active_hours_end",
                value: self.active_hours_end,
            });
        }

        // Positive values
        if self.activity_level <= 0.0 {
            errors.push(ProfileValidationError::NonPositive {
                field: "activity_level",
            });
        }
        if self.action_interval_secs == 0 {
            errors.push(ProfileValidationError::NonPositive {
                field: "action_interval_secs",
            });
        }

        // Logical ordering
        if self.afk_min_hours > self.afk_max_hours {
            errors.push(ProfileValidationError::InvalidRange {
                field: "afk_hours",
                min: self.afk_min_hours,
                max: self.afk_max_hours,
            });
        }

        errors
    }

    /// Check if the profile is valid.
    ///
    /// Shorthand for `self.validate().is_empty()`.
    #[must_use]
    pub fn is_valid(&self) -> bool {
        self.validate().is_empty()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION ERROR
// ═══════════════════════════════════════════════════════════════════════════════

/// Error returned when a profile field has an invalid value.
#[derive(Debug, Clone, PartialEq)]
pub enum ProfileValidationError {
    /// A probability field is outside 0.0-1.0.
    InvalidProbability {
        /// Field name.
        field: &'static str,
        /// Invalid value.
        value: f64,
    },
    /// An hour field is outside 0-23.
    InvalidHour {
        /// Field name.
        field: &'static str,
        /// Invalid value.
        value: u8,
    },
    /// A field that must be positive is zero or negative.
    NonPositive {
        /// Field name.
        field: &'static str,
    },
    /// A min/max range is inverted (min > max).
    InvalidRange {
        /// Field name (describes the range).
        field: &'static str,
        /// Minimum value.
        min: u64,
        /// Maximum value.
        max: u64,
    },
}

impl std::fmt::Display for ProfileValidationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidProbability { field, value } => {
                write!(f, "{field} must be 0.0-1.0, got {value}")
            }
            Self::InvalidHour { field, value } => {
                write!(f, "{field} must be 0-23, got {value}")
            }
            Self::NonPositive { field } => {
                write!(f, "{field} must be positive")
            }
            Self::InvalidRange { field, min, max } => {
                write!(f, "{field} range is invalid: min ({min}) > max ({max})")
            }
        }
    }
}

impl std::error::Error for ProfileValidationError {}

impl Default for BehaviorProfile {
    fn default() -> Self {
        Self::grinder()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use rand::SeedableRng;
    use rand::rngs::StdRng;

    fn test_rng() -> StdRng {
        StdRng::seed_from_u64(42)
    }

    #[test]
    fn preset_profiles_have_correct_names() {
        assert_eq!(BehaviorProfile::whale().name, "whale");
        assert_eq!(BehaviorProfile::grinder().name, "grinder");
        assert_eq!(BehaviorProfile::degen().name, "degen");
        assert_eq!(BehaviorProfile::casual().name, "casual");
        assert_eq!(BehaviorProfile::sniper().name, "sniper");
    }

    #[test]
    fn risk_tolerance_ordering() {
        // Whale < Casual < Grinder < Degen < Sniper
        assert!(BehaviorProfile::whale().risk_tolerance < BehaviorProfile::casual().risk_tolerance);
        assert!(BehaviorProfile::casual().risk_tolerance < BehaviorProfile::grinder().risk_tolerance);
        assert!(BehaviorProfile::grinder().risk_tolerance < BehaviorProfile::degen().risk_tolerance);
        assert!(BehaviorProfile::degen().risk_tolerance < BehaviorProfile::sniper().risk_tolerance);
    }

    #[test]
    fn active_hours_normal_range() {
        let profile = BehaviorProfile::whale(); // 14-22
        assert!(!profile.is_active_hour(10));
        assert!(profile.is_active_hour(14));
        assert!(profile.is_active_hour(18));
        assert!(profile.is_active_hour(22));
        assert!(!profile.is_active_hour(23));
    }

    #[test]
    fn active_hours_wrapping() {
        let mut profile = BehaviorProfile::new("night_owl");
        profile.active_hours_start = 22;
        profile.active_hours_end = 6;

        assert!(profile.is_active_hour(22));
        assert!(profile.is_active_hour(0));
        assert!(profile.is_active_hour(3));
        assert!(profile.is_active_hour(6));
        assert!(!profile.is_active_hour(12));
        assert!(!profile.is_active_hour(18));
    }

    #[test]
    fn next_interval_has_jitter() {
        let profile = BehaviorProfile::grinder();
        let mut rng = test_rng();

        // Generate several intervals
        let intervals: Vec<_> = (0..10)
            .map(|_| profile.next_interval(&mut rng).num_seconds())
            .collect();

        // They should not all be the same
        let first = intervals[0];
        assert!(intervals.iter().any(|&i| i != first), "intervals should vary");

        // All should be positive and reasonable
        for interval in &intervals {
            assert!(*interval >= 60, "minimum 1 minute");
            assert!(*interval < 10000, "should be reasonable");
        }
    }

    #[test]
    fn afk_probability() {
        let profile = BehaviorProfile::degen(); // Low AFK probability
        let mut rng = test_rng();

        // With 2% probability, most checks should return None
        let afk_count = (0..100)
            .filter(|_| profile.maybe_go_afk(&mut rng).is_some())
            .count();

        assert!(afk_count < 20, "degen should rarely go AFK, got {afk_count}");

        // Casual has 20% probability
        let casual = BehaviorProfile::casual();
        let afk_count = (0..100)
            .filter(|_| casual.maybe_go_afk(&mut rng).is_some())
            .count();

        assert!(afk_count > 5, "casual should sometimes go AFK, got {afk_count}");
    }

    #[test]
    fn should_act_respects_active_hours() {
        let profile = BehaviorProfile::whale(); // 14-22, 0.3 off-hours
        let mut rng = test_rng();

        // During active hours, always act
        assert!(profile.should_act_now(18, &mut rng));

        // Outside active hours, sometimes act (stochastic)
        let act_count = (0..100)
            .filter(|_| profile.should_act_now(6, &mut rng))
            .count();

        // Should be roughly 30% (with some variance)
        assert!(act_count > 10 && act_count < 60, "off-hours factor ~30%, got {act_count}");
    }

    #[test]
    fn preset_profiles_are_valid() {
        assert!(BehaviorProfile::whale().is_valid());
        assert!(BehaviorProfile::grinder().is_valid());
        assert!(BehaviorProfile::degen().is_valid());
        assert!(BehaviorProfile::casual().is_valid());
        assert!(BehaviorProfile::sniper().is_valid());
    }

    #[test]
    fn validation_catches_invalid_probabilities() {
        let mut profile = BehaviorProfile::new("bad");
        
        profile.risk_tolerance = 1.5;
        let errors = profile.validate();
        assert!(errors.iter().any(|e| matches!(e, 
            ProfileValidationError::InvalidProbability { field: "risk_tolerance", .. }
        )));

        profile.risk_tolerance = 0.5;
        profile.patience = -0.1;
        let errors = profile.validate();
        assert!(errors.iter().any(|e| matches!(e,
            ProfileValidationError::InvalidProbability { field: "patience", .. }
        )));

        profile.patience = 0.5;
        profile.off_hours_factor = 2.0;
        let errors = profile.validate();
        assert!(errors.iter().any(|e| matches!(e,
            ProfileValidationError::InvalidProbability { field: "off_hours_factor", .. }
        )));
    }

    #[test]
    fn validation_catches_invalid_hours() {
        let mut profile = BehaviorProfile::new("bad");
        profile.active_hours_start = 25;
        
        let errors = profile.validate();
        assert!(errors.iter().any(|e| matches!(e,
            ProfileValidationError::InvalidHour { field: "active_hours_start", value: 25 }
        )));
    }

    #[test]
    fn validation_catches_invalid_range() {
        let mut profile = BehaviorProfile::new("bad");
        profile.afk_min_hours = 48;
        profile.afk_max_hours = 12;
        
        let errors = profile.validate();
        assert!(errors.iter().any(|e| matches!(e,
            ProfileValidationError::InvalidRange { field: "afk_hours", min: 48, max: 12 }
        )));
    }

    #[test]
    fn validation_error_display() {
        let err = ProfileValidationError::InvalidProbability {
            field: "risk_tolerance",
            value: 1.5,
        };
        assert_eq!(err.to_string(), "risk_tolerance must be 0.0-1.0, got 1.5");
    }
}
