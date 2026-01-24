//! HashCrash action decision logic.
//!
//! This module handles decisions for:
//! - `hashcrash_bet`: Place a bet in the current round

// Allow precision loss for target multiplier calculations (small integers, not tokens)
#![allow(clippy::cast_precision_loss)]
// Allow suboptimal floating point ops - readability over micro-optimization
#![allow(clippy::suboptimal_flops)]

use alloy::primitives::U256;
use fleet_core::plugins::{Action, PluginContext};
use fleet_core::profiles::BehaviorProfile;
use rand::Rng;
use tracing::debug;

use crate::config::BehaviorSettings;
use crate::math::{percentage_of, pct_to_bps, random_bps};
use crate::state::GhostnetState;

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION IDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Action ID for placing a HashCrash bet.
pub const ACTION_HASHCRASH_BET: &str = "ghostnet.hashcrash_bet";

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Minimum target multiplier (1.01x = 101).
const MIN_TARGET: u16 = 101;

/// Maximum target multiplier (100.00x = 10000).
const MAX_TARGET: u16 = 10000;

/// Minimum bet amount (1 DATA).
const MIN_BET: u128 = 1_000_000_000_000_000_000;

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

/// Decision logic for HashCrash actions.
pub struct HashCrashDecider;

impl HashCrashDecider {
    /// Decide whether to place a HashCrash bet.
    pub fn decide(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> Option<Action> {
        // Check if HashCrash is enabled
        if !settings.plays_hashcrash {
            return None;
        }

        // Check if there's an open round
        let round = match &state.hashcrash_round {
            Some(r) if r.is_betting => r,
            _ => return None,
        };

        // Check current time vs betting end
        #[allow(clippy::cast_sign_loss)]
        let now_unix = context.now.timestamp() as u64;
        if !round.can_bet(now_unix) {
            return None;
        }

        // Check balance
        let min_bet = U256::from(MIN_BET);
        if state.data_balance < min_bet {
            return None;
        }

        // Calculate bet probability based on activity level
        // Higher activity = more likely to play games
        let bet_prob = 0.1 + (profile.activity_level / 30.0);

        if !context.rng.random_bool(bet_prob.min(0.5)) {
            return None;
        }

        // Calculate bet amount
        let amount = Self::calculate_bet_amount(state, profile, settings, context);
        if amount < min_bet {
            return None;
        }

        // Calculate target multiplier
        let target = Self::calculate_target_multiplier(profile, context);

        debug!(
            round_id = round.round_id,
            amount = %amount,
            target = target,
            probability = bet_prob,
            "Deciding to place HashCrash bet"
        );

        Some(Action::with_data(
            ACTION_HASHCRASH_BET,
            "HashCrash Bet",
            serde_json::json!({
                "amount": amount.to_string(),
                "target_multiplier": target,
            }),
        ))
    }

    /// Calculate bet amount based on balance and settings.
    ///
    /// Uses basis-point arithmetic for precision with large token amounts.
    fn calculate_bet_amount(
        state: &GhostnetState,
        profile: &BehaviorProfile,
        settings: &BehaviorSettings,
        context: &mut PluginContext<'_>,
    ) -> U256 {
        // Calculate max bet percentage using basis points
        let max_bps = pct_to_bps(settings.max_hashcrash_bet_pct * profile.risk_tolerance);

        // Apply jitter: 30% to 100% of max
        let jitter_bps = random_bps(0.3, 1.0, context.rng);
        // Safe: max_bps * jitter_bps / 10000 fits in u64 (max ~10000 * 10000 / 10000 = 10000)
        #[allow(clippy::cast_possible_truncation)]
        let bet_bps = (u128::from(max_bps) * u128::from(jitter_bps) / 10_000) as u64;

        // Calculate amount using integer arithmetic
        let amount = percentage_of(state.data_balance, bet_bps);

        // Ensure within bounds: min bet to 10% of balance
        let min = U256::from(MIN_BET);
        let max = percentage_of(state.data_balance, 1000); // 10% = 1000 bps
        amount.max(min).min(max)
    }

    /// Calculate target multiplier based on risk tolerance.
    ///
    /// Lower risk tolerance = lower targets (safer, lower payout)
    /// Higher risk tolerance = higher targets (riskier, higher payout)
    fn calculate_target_multiplier(profile: &BehaviorProfile, context: &mut PluginContext<'_>) -> u16 {
        // Base target depends on risk tolerance
        // Risk 0.0 -> targets around 1.2x (120)
        // Risk 1.0 -> targets around 5.0x (500)
        let base = 120.0 + (profile.risk_tolerance * 380.0);

        // Add significant jitter based on patience
        // Less patience = more volatile choices
        let jitter_range = 1.0 - (profile.patience * 0.5);
        let jitter = context.rng.random_range(1.0 - jitter_range..1.0 + jitter_range);

        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let target = (base * jitter) as u16;

        // Clamp to valid range
        target.clamp(MIN_TARGET, MAX_TARGET)
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
    fn no_bet_when_disabled() {
        let mut state = GhostnetState::default();
        state.data_balance = U256::from(100_000_000_000_000_000_000_u128); // 100 DATA
        state.hashcrash_round = Some(crate::state::HashCrashRound {
            round_id: 1,
            is_betting: true,
            betting_ends_at: u64::MAX,
            player_count: 0,
            prize_pool: U256::ZERO,
        });

        let profile = BehaviorProfile::degen();
        let settings = BehaviorSettings {
            plays_hashcrash: false,
            ..BehaviorSettings::default()
        };
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        let result = HashCrashDecider::decide(&state, &profile, &settings, &mut context);
        assert!(result.is_none());
    }

    #[test]
    fn no_bet_when_no_round() {
        let mut state = GhostnetState::default();
        state.data_balance = U256::from(100_000_000_000_000_000_000_u128);
        state.hashcrash_round = None;

        let profile = BehaviorProfile::degen();
        let settings = BehaviorSettings::default();
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        let result = HashCrashDecider::decide(&state, &profile, &settings, &mut context);
        assert!(result.is_none());
    }

    #[test]
    fn target_multiplier_respects_risk_tolerance() {
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        // Low risk should have lower targets on average
        let low_risk = BehaviorProfile::whale();
        let targets_low: Vec<u16> = (0..100)
            .map(|_| HashCrashDecider::calculate_target_multiplier(&low_risk, &mut context))
            .collect();

        // High risk should have higher targets on average
        let high_risk = BehaviorProfile::degen();
        let targets_high: Vec<u16> = (0..100)
            .map(|_| HashCrashDecider::calculate_target_multiplier(&high_risk, &mut context))
            .collect();

        let avg_low: f64 = targets_low.iter().map(|t| f64::from(*t)).sum::<f64>() / 100.0;
        let avg_high: f64 = targets_high.iter().map(|t| f64::from(*t)).sum::<f64>() / 100.0;

        assert!(
            avg_high > avg_low,
            "degen avg target {avg_high} should be > whale avg {avg_low}"
        );
    }

    #[test]
    fn target_multiplier_in_valid_range() {
        let mut rng = StdRng::seed_from_u64(42);
        let mut context = test_context(&mut rng);

        let profiles = [
            BehaviorProfile::whale(),
            BehaviorProfile::grinder(),
            BehaviorProfile::degen(),
            BehaviorProfile::casual(),
            BehaviorProfile::sniper(),
        ];

        for profile in profiles {
            for _ in 0..100 {
                let target = HashCrashDecider::calculate_target_multiplier(&profile, &mut context);
                assert!(target >= MIN_TARGET, "target {target} below min {MIN_TARGET}");
                assert!(target <= MAX_TARGET, "target {target} above max {MAX_TARGET}");
            }
        }
    }
}
