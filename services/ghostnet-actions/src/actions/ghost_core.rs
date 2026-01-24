//! GhostCore action decision logic.
//!
//! This module handles decisions for:
//! - `jackIn`: Enter a new position
//! - `addStake`: Add to existing position
//! - `extract`: Exit position and claim rewards
//! - `claimRewards`: Claim rewards without exiting

// Allow precision loss for financial calculations that don't need exact precision
#![allow(clippy::cast_precision_loss)]
// Allow suboptimal flops since readability is preferred
#![allow(clippy::suboptimal_flops)]

use alloy::primitives::U256;
use fleet_core::plugins::{Action, PluginContext};
use fleet_core::profiles::BehaviorProfile;
use rand::Rng;
use tracing::debug;

use crate::config::{BehaviorSettings, LevelSettings};
use crate::state::{GhostnetState, Level};

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION IDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Action ID for jacking into GhostCore.
pub const ACTION_JACK_IN: &str = "ghostnet.jack_in";

/// Action ID for adding stake.
pub const ACTION_ADD_STAKE: &str = "ghostnet.add_stake";

/// Action ID for extracting.
pub const ACTION_EXTRACT: &str = "ghostnet.extract";

/// Action ID for claiming rewards.
pub const ACTION_CLAIM_REWARDS: &str = "ghostnet.claim_rewards";

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

/// Decision logic for GhostCore actions.
pub struct GhostCoreDecider;

impl GhostCoreDecider {
    /// Decide what GhostCore action to take (if any).
    ///
    /// Decision priority:
    /// 1. If dead position exists, maybe re-enter
    /// 2. If alive position exists, maybe extract or compound
    /// 3. If no position, maybe create one
    pub fn decide(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> Option<Action> {
        // Check if we have a position
        if let Some(ref position) = state.position {
            if position.alive {
                // Has active position - decide what to do with it
                return Self::decide_with_active_position(state, profile, settings, context);
            }
            // Dead position - decide if we want to re-enter
            return Self::decide_after_death(state, profile, settings, context);
        }

        // No position at all - decide if we want to enter
        Self::decide_new_position(state, profile, settings, context)
    }

    /// Decide what to do with an active position.
    fn decide_with_active_position(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> Option<Action> {
        let position = state.position.as_ref()?;

        // First check if we should extract
        if position.can_extract() && position.ghost_streak >= settings.min_streak_before_extract {
            // Adjust extract probability based on profile patience
            // Higher patience = lower extract probability
            let extract_prob = settings.base_extract_probability * (1.0 - profile.patience * 0.5);

            if context.rng.random_bool(extract_prob) {
                debug!(
                    streak = position.ghost_streak,
                    probability = extract_prob,
                    "Deciding to extract"
                );

                return Some(Action::new(ACTION_EXTRACT, "Extract"));
            }
        }

        // Check if we should add stake (compound)
        if position.can_add_stake() {
            let min_balance = U256::from(settings.min_entry_balance);

            if state.data_balance >= min_balance {
                // Adjust compound probability based on risk tolerance
                // Higher risk tolerance = more likely to compound
                let compound_prob = settings.base_compound_probability * profile.risk_tolerance;

                if context.rng.random_bool(compound_prob) {
                    let amount = Self::calculate_add_stake_amount(state, profile, context);

                    if amount > U256::ZERO {
                        debug!(
                            amount = %amount,
                            probability = compound_prob,
                            "Deciding to add stake"
                        );

                        return Some(Action::with_data(
                            ACTION_ADD_STAKE,
                            "Add Stake",
                            serde_json::json!({
                                "amount": amount.to_string(),
                            }),
                        ));
                    }
                }
            }
        }

        // Check if we should claim rewards (without exiting)
        if position.pending_rewards > U256::ZERO {
            // Only claim if rewards are significant
            let min_claim = U256::from(1_000_000_000_000_000_000_u128); // 1 DATA

            if position.pending_rewards >= min_claim && context.rng.random_bool(0.1) {
                debug!(rewards = %position.pending_rewards, "Deciding to claim rewards");
                return Some(Action::new(ACTION_CLAIM_REWARDS, "Claim Rewards"));
            }
        }

        None
    }

    /// Decide what to do after position died.
    fn decide_after_death(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> Option<Action> {
        // After death, we might want to re-enter
        // The decision depends on profile risk tolerance and available balance

        let min_balance = U256::from(settings.min_entry_balance);
        if state.data_balance < min_balance {
            return None;
        }

        // Re-entry probability based on risk tolerance
        // Higher risk = more likely to jump back in
        let reentry_prob = 0.3 + (profile.risk_tolerance * 0.5);

        if context.rng.random_bool(reentry_prob) {
            let level = Self::select_level(profile, context);
            let amount = Self::calculate_entry_amount(state, profile, level, context);

            if amount > U256::ZERO {
                debug!(
                    level = %level,
                    amount = %amount,
                    probability = reentry_prob,
                    "Deciding to re-enter after death"
                );

                return Some(Action::with_data(
                    ACTION_JACK_IN,
                    "Jack In",
                    serde_json::json!({
                        "amount": amount.to_string(),
                        "level": level.as_u8(),
                    }),
                ));
            }
        }

        None
    }

    /// Decide whether to create a new position.
    fn decide_new_position(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> Option<Action> {
        let min_balance = U256::from(settings.min_entry_balance);
        if state.data_balance < min_balance {
            return None;
        }

        // Entry probability - higher activity level = more likely to enter
        let entry_prob = 0.5 + (profile.activity_level / 20.0);

        if context.rng.random_bool(entry_prob.min(0.9)) {
            let level = Self::select_level(profile, context);
            let amount = Self::calculate_entry_amount(state, profile, level, context);

            if amount > U256::ZERO {
                debug!(
                    level = %level,
                    amount = %amount,
                    probability = entry_prob,
                    "Deciding to create new position"
                );

                return Some(Action::with_data(
                    ACTION_JACK_IN,
                    "Jack In",
                    serde_json::json!({
                        "amount": amount.to_string(),
                        "level": level.as_u8(),
                    }),
                ));
            }
        }

        None
    }

    /// Select a level based on profile risk tolerance.
    fn select_level(profile: &BehaviorProfile, context: &mut PluginContext<'_>) -> Level {
        // Build weighted distribution based on risk tolerance
        let levels = [
            (Level::Vault, 0.2),
            (Level::Mainframe, 0.3),
            (Level::Subnet, 0.5),
            (Level::Darknet, 0.7),
            (Level::BlackIce, 0.9),
        ];

        // Filter to levels the profile's risk tolerance allows
        let eligible: Vec<_> = levels
            .iter()
            .filter(|(level, min_risk)| {
                profile.risk_tolerance >= *min_risk
                    && LevelSettings::for_level(level.as_u8()).is_some()
            })
            .map(|(level, _)| *level)
            .collect();

        if eligible.is_empty() {
            return Level::Vault;
        }

        // Random selection weighted toward higher levels for higher risk tolerance
        let idx = context.rng.random_range(0..eligible.len());
        eligible[idx]
    }

    /// Calculate entry amount based on balance and profile.
    fn calculate_entry_amount(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        level: Level,
        context: &mut PluginContext<'_>,
    ) -> U256 {
        let Some(settings) = LevelSettings::for_level(level.as_u8()) else {
            return U256::ZERO;
        };

        let min_stake = U256::from(settings.min_stake);
        if state.data_balance < min_stake {
            return U256::ZERO;
        }

        // Calculate percentage of balance to stake
        // Higher risk tolerance = higher percentage
        let base_pct = 0.1 + (profile.risk_tolerance * 0.4); // 10% to 50%

        // Add some randomness
        let jitter = context.rng.random_range(0.8..1.2);
        let pct = (base_pct * jitter).min(0.8); // Cap at 80%

        // Calculate amount
        let balance_f64 = state.data_balance.to::<u128>() as f64;
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let amount = U256::from((balance_f64 * pct) as u128);

        // Clamp to min/max
        amount.max(min_stake).min(state.data_balance)
    }

    /// Calculate add stake amount.
    fn calculate_add_stake_amount(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        context: &mut PluginContext<'_>,
    ) -> U256 {
        // Add 10-30% of current balance, adjusted by risk tolerance
        let base_pct = 0.1 + (profile.risk_tolerance * 0.2);
        let jitter = context.rng.random_range(0.8..1.2);
        let pct = (base_pct * jitter).min(0.5);

        let balance_f64 = state.data_balance.to::<u128>() as f64;
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let amount = U256::from((balance_f64 * pct) as u128);

        // Don't add less than 1 DATA
        let min = U256::from(1_000_000_000_000_000_000_u128);
        if amount < min {
            return U256::ZERO;
        }

        amount.min(state.data_balance)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use rand::rngs::StdRng;
    use rand::SeedableRng;

    fn test_context<'a>(rng: &'a mut StdRng) -> PluginContext<'a> {
        PluginContext::new(Utc::now(), rng, &serde_json::Value::Null)
    }

    #[test]
    fn no_action_when_insufficient_balance() {
        let state = GhostnetState::default();
        let profile = BehaviorProfile::grinder();
        let settings = BehaviorSettings::default();
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        let result = GhostCoreDecider::decide(&state, &profile, &settings, &mut context);
        assert!(result.is_none());
    }

    #[test]
    fn level_selection_respects_risk_tolerance() {
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        // Low risk tolerance should select lower levels
        let low_risk = BehaviorProfile::whale();
        let levels_low: Vec<_> = (0..100)
            .map(|_| GhostCoreDecider::select_level(&low_risk, &mut context))
            .collect();

        // High risk tolerance should select higher levels
        let high_risk = BehaviorProfile::degen();
        let levels_high: Vec<_> = (0..100)
            .map(|_| GhostCoreDecider::select_level(&high_risk, &mut context))
            .collect();

        // Calculate average level
        let avg_low: f64 = levels_low.iter().map(|l| f64::from(l.as_u8())).sum::<f64>() / 100.0;
        let avg_high: f64 = levels_high.iter().map(|l| f64::from(l.as_u8())).sum::<f64>() / 100.0;

        // Degen should have higher average level than whale
        assert!(
            avg_high > avg_low,
            "degen avg {avg_high} should be > whale avg {avg_low}"
        );
    }
}
