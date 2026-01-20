// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IGhostCore } from "./interfaces/IGhostCore.sol";
import { IDataToken } from "../token/interfaces/IDataToken.sol";

/// @title GhostCoreStorage
/// @notice Storage layout for GhostCore upgradeable contract
/// @dev Uses namespaced storage pattern (ERC-7201) for upgrade safety
///
/// CRITICAL: When upgrading, only APPEND new variables at the end of the struct.
/// Never reorder, rename, or remove existing variables.
abstract contract GhostCoreStorage {
    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE NAMESPACE (ERC-7201)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:storage-location erc7201:ghostnet.storage.GhostCore
    struct GhostCoreStorageLayout {
        // ─── Core References ─────────────────────────────────────────────────────
        IDataToken dataToken;
        address treasury;
        address boostSigner;
        // ─── Position Management ─────────────────────────────────────────────────
        mapping(address user => IGhostCore.Position position) positions;
        mapping(address user => IGhostCore.Boost[] boosts) userBoosts;
        mapping(address user => uint256 lastResetEpoch) lastSettledEpoch;
        // ─── Level Configuration & State ─────────────────────────────────────────
        mapping(IGhostCore.Level level => IGhostCore.LevelConfig config) levelConfigs;
        mapping(IGhostCore.Level level => IGhostCore.LevelState state) levelStates;
        // ─── System Reset ────────────────────────────────────────────────────────
        IGhostCore.SystemReset systemReset;
        // ─── Nonces for Signatures ───────────────────────────────────────────────
        mapping(bytes32 nonce => bool used) usedNonces;
        // ─── Position Ordering (for culling) ─────────────────────────────────────
        // Maps level => array of addresses sorted by stake amount
        mapping(IGhostCore.Level level => address[] users) levelPositions;
        mapping(IGhostCore.Level level => mapping(address user => uint256 index)) positionIndex;
        // ─── Reserved for Future Upgrades ────────────────────────────────────────
        uint256[40] __gap;
    }

    // keccak256(abi.encode(uint256(keccak256("ghostnet.storage.GhostCore")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GHOST_CORE_STORAGE_LOCATION =
        0x3b48c81e5a3b9c2a7f6d4e8f1c2a3b4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00;

    function _getGhostCoreStorage() internal pure returns (GhostCoreStorageLayout storage $) {
        assembly {
            $.slot := GHOST_CORE_STORAGE_LOCATION
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Lock period before scans (prevents last-second extraction)
    uint256 internal constant LOCK_PERIOD = 60 seconds;

    /// @notice Basis points denominator
    uint16 internal constant BPS = 10_000;

    /// @notice Precision for reward calculations
    uint256 internal constant REWARD_PRECISION = 1e18;

    // ─── Cascade Split Constants ─────────────────────────────────────────────────
    // 30/30/30/10 absolute split

    /// @notice Cascade: 30% to same-level survivors
    uint16 internal constant CASCADE_SAME_LEVEL_BPS = 3000;

    /// @notice Cascade: 30% to upstream levels
    uint16 internal constant CASCADE_UPSTREAM_BPS = 3000;

    /// @notice Cascade: 30% burned
    uint16 internal constant CASCADE_BURN_BPS = 3000;

    /// @notice Cascade: 10% to protocol treasury
    uint16 internal constant CASCADE_PROTOCOL_BPS = 1000;

    // ─── System Reset Constants ──────────────────────────────────────────────────

    /// @notice Default reset deadline (24 hours from start)
    uint256 internal constant DEFAULT_RESET_DEADLINE = 24 hours;

    /// @notice Maximum reset deadline
    uint256 internal constant MAX_RESET_DEADLINE = 24 hours;

    /// @notice Penalty percentage when system resets
    uint16 internal constant SYSTEM_RESET_PENALTY_BPS = 2500; // 25%

    /// @notice Jackpot share of penalty
    uint16 internal constant JACKPOT_SHARE_BPS = 5000; // 50% of penalty

    /// @notice Burn share of penalty
    uint16 internal constant RESET_BURN_SHARE_BPS = 3000; // 30% of penalty

    /// @notice Protocol share of penalty (remainder: 20%)
    uint16 internal constant RESET_PROTOCOL_SHARE_BPS = 2000; // 20% of penalty

    // ─── Timer Extension Thresholds ──────────────────────────────────────────────

    uint256 internal constant TIER1_THRESHOLD = 50 * 1e18; // < 50 DATA: +1 hour
    uint256 internal constant TIER2_THRESHOLD = 200 * 1e18; // 50-200: +4 hours
    uint256 internal constant TIER3_THRESHOLD = 500 * 1e18; // 200-500: +8 hours
    uint256 internal constant TIER4_THRESHOLD = 1000 * 1e18; // 500-1000: +16 hours
    // > 1000 DATA: Full reset (24 hours)

    uint256 internal constant TIER1_EXTENSION = 1 hours;
    uint256 internal constant TIER2_EXTENSION = 4 hours;
    uint256 internal constant TIER3_EXTENSION = 8 hours;
    uint256 internal constant TIER4_EXTENSION = 16 hours;
}
