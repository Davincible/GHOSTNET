//! Safe integer math utilities for financial calculations.
//!
//! This module provides basis-point arithmetic to avoid precision loss
//! when calculating percentages of token amounts. Using integer math
//! ensures deterministic results regardless of amount size.
//!
//! # Basis Points
//!
//! Basis points (bps) represent percentages in hundredths of a percent:
//! - 10000 bps = 100%
//! - 5000 bps = 50%
//! - 100 bps = 1%
//! - 1 bp = 0.01%
//!
//! # Why Not Floating Point?
//!
//! With 18-decimal tokens, `u128` can represent values up to ~340 undecillion.
//! When cast to `f64` (53-bit mantissa), values above ~9 quadrillion
//! (~9 million tokens with 18 decimals) lose precision. Basis point
//! arithmetic avoids this entirely.

use alloy::primitives::U256;

/// Basis points representing 100%.
pub const BPS_100_PERCENT: u64 = 10_000;

/// Calculate percentage of an amount using basis points.
///
/// Uses integer arithmetic: `(amount * bps) / 10000`
///
/// This is safe for any U256 value and avoids floating point precision loss.
///
/// # Arguments
///
/// * `amount` - The amount to take a percentage of
/// * `bps` - Basis points (10000 = 100%, 5000 = 50%, 100 = 1%)
///
/// # Returns
///
/// The calculated percentage, or `U256::ZERO` if bps is 0.
///
/// # Example
///
/// ```ignore
/// use ghostnet_actions::math::percentage_of;
/// use alloy::primitives::U256;
///
/// let balance = U256::from(1_000_000_000_000_000_000_u128); // 1 token
/// let half = percentage_of(balance, 5000); // 50%
/// assert_eq!(half, U256::from(500_000_000_000_000_000_u128));
/// ```
#[must_use]
pub fn percentage_of(amount: U256, bps: u64) -> U256 {
    if bps == 0 {
        return U256::ZERO;
    }
    // Multiply first, then divide to maintain precision
    // This is safe because U256 can handle the intermediate result
    amount * U256::from(bps) / U256::from(BPS_100_PERCENT)
}

/// Calculate basis points from a floating-point percentage.
///
/// Converts a 0.0-1.0 range to 0-10000 basis points.
/// Values are clamped to the valid range.
///
/// # Arguments
///
/// * `pct` - Percentage as float (0.0 = 0%, 1.0 = 100%)
///
/// # Returns
///
/// Basis points (0-10000)
#[must_use]
#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
pub fn pct_to_bps(pct: f64) -> u64 {
    let clamped = pct.clamp(0.0, 1.0);
    (clamped * 10_000.0) as u64
}

/// Generate a random basis points value in a range.
///
/// # Arguments
///
/// * `min_pct` - Minimum percentage (0.0-1.0)
/// * `max_pct` - Maximum percentage (0.0-1.0)
/// * `rng` - Random number generator
///
/// # Returns
///
/// Random basis points between min and max (as bps)
#[must_use]
pub fn random_bps(min_pct: f64, max_pct: f64, rng: &mut (impl rand::Rng + ?Sized)) -> u64 {
    let min_bps = pct_to_bps(min_pct);
    let max_bps = pct_to_bps(max_pct);
    if min_bps >= max_bps {
        return min_bps;
    }
    rng.random_range(min_bps..=max_bps)
}

/// Apply jitter to a basis points value.
///
/// Multiplies the base value by a random factor in the given range.
///
/// # Arguments
///
/// * `base_bps` - Base basis points value
/// * `jitter_min` - Minimum multiplier (e.g., 0.8 for -20%)
/// * `jitter_max` - Maximum multiplier (e.g., 1.2 for +20%)
/// * `rng` - Random number generator
///
/// # Returns
///
/// Jittered basis points, clamped to 0-10000
#[must_use]
#[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss, clippy::cast_precision_loss)]
pub fn apply_jitter(base_bps: u64, jitter_min: f64, jitter_max: f64, rng: &mut (impl rand::Rng + ?Sized)) -> u64 {
    // Precision loss acceptable: base_bps is max 10000, fits in f64 mantissa
    let jitter: f64 = rng.random_range(jitter_min..=jitter_max);
    let result = (base_bps as f64 * jitter) as u64;
    result.min(BPS_100_PERCENT)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percentage_of_basic() {
        let amount = U256::from(1_000_000_000_000_000_000_u128); // 1 token (18 decimals)
        
        // 50%
        assert_eq!(
            percentage_of(amount, 5000),
            U256::from(500_000_000_000_000_000_u128)
        );
        
        // 10%
        assert_eq!(
            percentage_of(amount, 1000),
            U256::from(100_000_000_000_000_000_u128)
        );
        
        // 1%
        assert_eq!(
            percentage_of(amount, 100),
            U256::from(10_000_000_000_000_000_u128)
        );
        
        // 100%
        assert_eq!(percentage_of(amount, 10000), amount);
        
        // 0%
        assert_eq!(percentage_of(amount, 0), U256::ZERO);
    }

    #[test]
    fn percentage_of_large_amounts() {
        // 10 million tokens - where f64 would start losing precision
        let large = U256::from(10_000_000_u128) * U256::from(10u128.pow(18));
        
        // 50% should be exactly 5 million tokens
        let half = percentage_of(large, 5000);
        let expected = U256::from(5_000_000_u128) * U256::from(10u128.pow(18));
        assert_eq!(half, expected);
    }

    #[test]
    fn pct_to_bps_conversion() {
        assert_eq!(pct_to_bps(0.0), 0);
        assert_eq!(pct_to_bps(0.5), 5000);
        assert_eq!(pct_to_bps(1.0), 10000);
        assert_eq!(pct_to_bps(0.01), 100);
        
        // Clamping
        assert_eq!(pct_to_bps(-0.5), 0);
        assert_eq!(pct_to_bps(1.5), 10000);
    }

    #[test]
    fn random_bps_in_range() {
        use rand::SeedableRng;
        let mut rng = rand::rngs::StdRng::seed_from_u64(42);
        
        for _ in 0..100 {
            let bps = random_bps(0.1, 0.5, &mut rng);
            assert!(bps >= 1000, "bps {bps} should be >= 1000 (10%)");
            assert!(bps <= 5000, "bps {bps} should be <= 5000 (50%)");
        }
    }

    #[test]
    fn apply_jitter_stays_bounded() {
        use rand::SeedableRng;
        let mut rng = rand::rngs::StdRng::seed_from_u64(42);
        
        // Even with high jitter, should never exceed 100%
        for _ in 0..100 {
            let jittered = apply_jitter(8000, 0.8, 1.5, &mut rng);
            assert!(jittered <= 10000, "jittered {jittered} should be <= 10000");
        }
    }
}
