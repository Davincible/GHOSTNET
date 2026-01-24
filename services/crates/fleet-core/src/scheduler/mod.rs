//! Scheduling for wallet actions.
//!
//! This module provides utilities for scheduling wallet actions with jitter
//! to create natural timing variation.
//!
//! # Overview
//!
//! The scheduler helps determine when wallets should act, incorporating:
//! - Profile-based intervals (whale = slow, degen = fast)
//! - Random jitter to avoid patterns
//! - Active hours consideration
//! - AFK periods
//!
//! # Example
//!
//! ```
//! use fleet_core::scheduler::Scheduler;
//! use fleet_core::profiles::BehaviorProfile;
//!
//! let mut scheduler = Scheduler::new();
//! let profile = BehaviorProfile::grinder();
//!
//! // Calculate next action time
//! let next = scheduler.calculate_next_action(&profile);
//! println!("Next action at: {}", next);
//! ```

use chrono::{DateTime, Utc};
use rand::rngs::StdRng;
use rand::SeedableRng;

use crate::profiles::BehaviorProfile;

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULER
// ═══════════════════════════════════════════════════════════════════════════════

/// Scheduler for calculating action timing.
///
/// Uses profile-based intervals with random jitter to create varied,
/// natural-looking timing patterns.
#[derive(Debug)]
pub struct Scheduler {
    /// Random number generator for jitter.
    rng: StdRng,
}

impl Scheduler {
    /// Create a new scheduler with a random seed.
    #[must_use]
    pub fn new() -> Self {
        Self {
            rng: StdRng::from_os_rng(),
        }
    }

    /// Create a scheduler with a specific seed (for reproducible testing).
    #[must_use]
    pub fn with_seed(seed: u64) -> Self {
        Self {
            rng: StdRng::seed_from_u64(seed),
        }
    }

    /// Calculate the next action time based on a profile.
    ///
    /// Returns a timestamp that is the current time plus a profile-based
    /// interval with random jitter applied.
    #[must_use]
    pub fn calculate_next_action(&mut self, profile: &BehaviorProfile) -> DateTime<Utc> {
        let interval = profile.next_interval(&mut self.rng);
        Utc::now() + interval
    }

    /// Decide whether to go AFK based on profile probability.
    ///
    /// Returns `Some(until)` if the wallet should go AFK, where `until`
    /// is when the AFK period ends.
    #[must_use]
    pub fn maybe_go_afk(&mut self, profile: &BehaviorProfile) -> Option<DateTime<Utc>> {
        profile.maybe_go_afk(&mut self.rng).map(|duration| Utc::now() + duration)
    }

    /// Check if the current time is within active hours for a profile.
    ///
    /// Returns `true` if acting is appropriate based on active hours
    /// and off-hours probability.
    #[must_use]
    pub fn should_act_now(&mut self, profile: &BehaviorProfile) -> bool {
        let hour = Utc::now().format("%H").to_string().parse::<u8>().unwrap_or(12);
        profile.should_act_now(hour, &mut self.rng)
    }

    /// Get the current hour in UTC.
    #[must_use]
    pub fn current_hour() -> u8 {
        Utc::now().format("%H").to_string().parse::<u8>().unwrap_or(12)
    }
}

impl Default for Scheduler {
    fn default() -> Self {
        Self::new()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn next_action_is_in_future() {
        let mut scheduler = Scheduler::with_seed(42);
        let profile = BehaviorProfile::grinder();

        let now = Utc::now();
        let next = scheduler.calculate_next_action(&profile);

        assert!(next > now, "next action should be in the future");
    }

    #[test]
    fn different_profiles_different_intervals() {
        let mut scheduler = Scheduler::with_seed(42);

        let whale_intervals: Vec<_> = (0..10)
            .map(|_| {
                scheduler.calculate_next_action(&BehaviorProfile::whale())
                    .signed_duration_since(Utc::now())
                    .num_seconds()
            })
            .collect();

        let degen_intervals: Vec<_> = (0..10)
            .map(|_| {
                scheduler.calculate_next_action(&BehaviorProfile::degen())
                    .signed_duration_since(Utc::now())
                    .num_seconds()
            })
            .collect();

        let whale_avg: i64 = whale_intervals.iter().sum::<i64>() / 10;
        let degen_avg: i64 = degen_intervals.iter().sum::<i64>() / 10;

        // Whale should have longer intervals than degen
        assert!(
            whale_avg > degen_avg,
            "whale ({whale_avg}s) should have longer intervals than degen ({degen_avg}s)"
        );
    }

    #[test]
    fn seeded_scheduler_is_reproducible() {
        let profile = BehaviorProfile::grinder();

        let mut sched1 = Scheduler::with_seed(42);
        let mut sched2 = Scheduler::with_seed(42);

        for _ in 0..5 {
            let t1 = sched1.calculate_next_action(&profile);
            let t2 = sched2.calculate_next_action(&profile);

            // Times should be very close (within 1 second of each other
            // accounting for execution time)
            let diff = (t1 - t2).num_seconds().abs();
            assert!(diff <= 1, "seeded schedulers should produce same results");
        }
    }
}
