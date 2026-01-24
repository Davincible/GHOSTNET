//! Contract bindings for GHOSTNET.
//!
//! This module provides type-safe interfaces to the GHOSTNET smart contracts
//! using Alloy's sol! macro for ABI generation.

use alloy::primitives::{Address, Bytes, U256};
use alloy::sol;
use alloy::sol_types::SolCall;

use crate::config::GhostnetConfig;
use crate::state::Level;

// ═══════════════════════════════════════════════════════════════════════════════
// CONTRACT ABI DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

// GhostCore - Main staking contract
sol! {
    #[sol(rpc)]
    interface IGhostCore {
        // === Core Functions ===
        function jackIn(uint256 amount, uint8 level) external;
        function addStake(uint256 amount) external;
        function extract() external returns (uint256 amount, uint256 rewards);
        function claimRewards() external returns (uint256 rewards);

        // === View Functions ===
        function getPosition(address user) external view returns (
            uint256 amount,
            uint8 level,
            uint64 entryTimestamp,
            uint64 lastAddTimestamp,
            uint256 rewardDebt,
            bool alive,
            uint16 ghostStreak
        );
        function getPendingRewards(address user) external view returns (uint256);
        function getEffectiveDeathRate(address user) external view returns (uint16);
        function isInLockPeriod(address user) external view returns (bool);
        function isAlive(address user) external view returns (bool);
    }
}

// HashCrash - Arcade crash game
sol! {
    #[sol(rpc)]
    interface IHashCrash {
        // === Core Functions ===
        function placeBet(uint256 amount, uint256 targetMultiplier) external;

        // === View Functions ===
        function getCurrentRound() external view returns (
            uint256 roundId,
            uint8 state,
            uint64 bettingEndsAt,
            uint256 seedBlock,
            uint256 crashMultiplier,
            uint256 totalPrizePool,
            uint256 playerCount
        );
        function getPlayerBet(uint256 roundId, address player) external view returns (
            uint256 amount,
            uint256 netAmount,
            uint256 targetMultiplier,
            bool settled
        );
    }
}

// ArcadeCore - Game management
sol! {
    #[sol(rpc)]
    interface IArcadeCore {
        function getPendingPayout(address player) external view returns (uint256);
        function withdrawPayout() external returns (uint256 amount);
    }
}

// ERC20 - DATA token
sol! {
    #[sol(rpc)]
    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function allowance(address owner, address spender) external view returns (uint256);
        function approve(address spender, uint256 amount) external returns (bool);
        function transfer(address to, uint256 amount) external returns (bool);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTRACT WRAPPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Contract addresses and calldata builders.
#[derive(Debug, Clone)]
pub struct GhostnetContracts {
    /// GhostCore contract address.
    pub ghost_core: Address,

    /// HashCrash contract address.
    pub hash_crash: Address,

    /// ArcadeCore contract address.
    pub arcade_core: Address,

    /// DATA token contract address.
    pub data_token: Address,
}

impl GhostnetContracts {
    /// Create from config.
    #[must_use]
    pub const fn from_config(config: &GhostnetConfig) -> Self {
        Self {
            ghost_core: config.ghost_core,
            hash_crash: config.hash_crash,
            arcade_core: config.arcade_core,
            data_token: config.data_token,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALLDATA BUILDERS
// ═══════════════════════════════════════════════════════════════════════════════

impl GhostnetContracts {
    // ─────────────────────────────────────────────────────────────────────────
    // GhostCore calldata
    // ─────────────────────────────────────────────────────────────────────────

    /// Build calldata for `jackIn(amount, level)`.
    #[must_use]
    pub fn encode_jack_in(&self, amount: U256, level: Level) -> Bytes {
        let call = IGhostCore::jackInCall {
            amount,
            level: level.as_u8(),
        };
        Bytes::from(call.abi_encode())
    }

    /// Build calldata for `addStake(amount)`.
    #[must_use]
    pub fn encode_add_stake(&self, amount: U256) -> Bytes {
        let call = IGhostCore::addStakeCall { amount };
        Bytes::from(call.abi_encode())
    }

    /// Build calldata for `extract()`.
    #[must_use]
    pub fn encode_extract(&self) -> Bytes {
        let call = IGhostCore::extractCall {};
        Bytes::from(call.abi_encode())
    }

    /// Build calldata for `claimRewards()`.
    #[must_use]
    pub fn encode_claim_rewards(&self) -> Bytes {
        let call = IGhostCore::claimRewardsCall {};
        Bytes::from(call.abi_encode())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HashCrash calldata
    // ─────────────────────────────────────────────────────────────────────────

    /// Build calldata for `placeBet(amount, targetMultiplier)`.
    #[must_use]
    pub fn encode_hashcrash_bet(&self, amount: U256, target_multiplier: u16) -> Bytes {
        let call = IHashCrash::placeBetCall {
            amount,
            targetMultiplier: U256::from(target_multiplier),
        };
        Bytes::from(call.abi_encode())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ArcadeCore calldata
    // ─────────────────────────────────────────────────────────────────────────

    /// Build calldata for `withdrawPayout()`.
    #[must_use]
    pub fn encode_withdraw_payout(&self) -> Bytes {
        let call = IArcadeCore::withdrawPayoutCall {};
        Bytes::from(call.abi_encode())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERC20 calldata
    // ─────────────────────────────────────────────────────────────────────────

    /// Build calldata for `approve(spender, amount)`.
    #[must_use]
    pub fn encode_approve(&self, spender: Address, amount: U256) -> Bytes {
        let call = IERC20::approveCall { spender, amount };
        Bytes::from(call.abi_encode())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    fn test_contracts() -> GhostnetContracts {
        GhostnetContracts {
            ghost_core: Address::repeat_byte(0x01),
            hash_crash: Address::repeat_byte(0x02),
            arcade_core: Address::repeat_byte(0x03),
            data_token: Address::repeat_byte(0x04),
        }
    }

    #[test]
    fn encode_jack_in() {
        let contracts = test_contracts();
        let calldata = contracts.encode_jack_in(U256::from(1000), Level::Subnet);

        // Should start with function selector
        assert!(!calldata.is_empty());
        assert!(calldata.len() >= 4); // At least selector
    }

    #[test]
    fn encode_add_stake() {
        let contracts = test_contracts();
        let calldata = contracts.encode_add_stake(U256::from(500));

        assert!(!calldata.is_empty());
    }

    #[test]
    fn encode_extract() {
        let contracts = test_contracts();
        let calldata = contracts.encode_extract();

        // extract() has no args, just selector
        assert_eq!(calldata.len(), 4);
    }

    #[test]
    fn encode_hashcrash_bet() {
        let contracts = test_contracts();
        let calldata = contracts.encode_hashcrash_bet(U256::from(100), 200); // 2.00x target

        assert!(!calldata.is_empty());
    }

    #[test]
    fn encode_approve() {
        let contracts = test_contracts();
        let spender = Address::repeat_byte(0x05);
        let calldata = contracts.encode_approve(spender, U256::MAX);

        assert!(!calldata.is_empty());
    }
}
