// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IGhostCore
/// @notice Interface for the main GHOSTNET game logic contract
/// @dev This contract manages positions, death processing, and cascade distribution
interface IGhostCore {
    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Risk levels from safest (1) to most dangerous (5)
    /// @dev Level affects death rate and reward multipliers
    enum Level {
        NONE, // 0 - Invalid/No position
        VAULT, // 1 - Safest (5% death rate)
        MAINFRAME, // 2 - Conservative (15% death rate)
        SUBNET, // 3 - Balanced (25% death rate)
        DARKNET, // 4 - High risk (35% death rate)
        BLACK_ICE // 5 - Maximum risk (45% death rate)
    }

    /// @notice Types of boosts that can be applied to positions
    enum BoostType {
        DEATH_REDUCTION, // Reduces effective death rate
        YIELD_MULTIPLIER // Multiplies reward earnings
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice A user's staking position in the game
    struct Position {
        uint256 amount; // Total staked DATA (can increase via addStake)
        Level level; // Risk level (locked once chosen)
        uint64 entryTimestamp; // When first jacked in
        uint64 lastAddTimestamp; // When last added stake (for lock period)
        uint256 rewardDebt; // For share-based accounting
        bool alive; // false = traced (dead)
        uint16 ghostStreak; // Consecutive scan survivals
    }

    /// @notice Configuration for a risk level
    struct LevelConfig {
        uint16 baseDeathRateBps; // Base death rate in basis points (e.g., 4500 = 45%)
        uint32 scanInterval; // Seconds between scans
        uint256 minStake; // Minimum DATA required to enter
        uint32 maxPositions; // Maximum positions allowed (0 = unlimited)
        uint16 cullingBottomPct; // Bottom X% eligible for culling (in bps)
        uint16 cullingPenaltyBps; // Penalty when culled (in bps)
    }

    /// @notice Runtime state for a risk level
    struct LevelState {
        uint256 totalStaked; // Sum of all alive positions
        uint256 aliveCount; // Number of alive positions
        uint256 accRewardsPerShare; // Accumulated rewards per share (scaled by 1e18)
        uint64 nextScanTime; // Timestamp of next scan
    }

    /// @notice Active boost on a position
    struct Boost {
        BoostType boostType; // Type of boost
        uint16 valueBps; // Boost value in basis points
        uint64 expiry; // When boost expires
    }

    /// @notice System reset timer state
    struct SystemReset {
        uint64 deadline; // When system resets if no deposits
        address lastDepositor; // Eligible for jackpot
        uint64 lastDepositTime; // When last deposit occurred
        uint256 epoch; // Current reset epoch (for lazy settlement)
        uint16 penaltyBps; // Pending penalty in basis points
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error InvalidLevel();
    error InvalidAmount();
    error PositionAlreadyExists();
    error NoPositionExists();
    error PositionDead();
    error PositionLocked();
    error LevelMismatch();
    error BelowMinimumStake();
    error InvalidSignature();
    error SignatureExpired();
    error NonceAlreadyUsed();
    error LevelAtCapacity();
    error NotAuthorized();
    error SystemResetNotReady();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a user enters a position
    event JackedIn(address indexed user, uint256 amount, Level indexed level, uint256 newTotal);

    /// @notice Emitted when a user adds to existing position
    event StakeAdded(address indexed user, uint256 amount, uint256 newTotal);

    /// @notice Emitted when a user extracts their position
    event Extracted(address indexed user, uint256 amount, uint256 rewards);

    /// @notice Emitted when positions are marked dead from a scan
    event DeathsProcessed(
        Level indexed level, uint256 count, uint256 totalDead, uint256 burned, uint256 distributed
    );

    /// @notice Emitted when ghost streaks are incremented for survivors
    event SurvivorsUpdated(Level indexed level, uint256 count);

    /// @notice Emitted when cascade rewards are distributed
    event CascadeDistributed(
        Level indexed sourceLevel,
        uint256 sameLevelAmount,
        uint256 upstreamAmount,
        uint256 burnAmount,
        uint256 protocolAmount
    );

    /// @notice Emitted when emissions are added to a level
    event EmissionsAdded(Level indexed level, uint256 amount);

    /// @notice Emitted when a boost is applied
    event BoostApplied(address indexed user, BoostType boostType, uint16 valueBps, uint64 expiry);

    /// @notice Emitted when system reset is triggered
    event SystemResetTriggered(
        uint256 totalPenalty, address indexed jackpotWinner, uint256 jackpotAmount
    );

    /// @notice Emitted when a position is culled
    event PositionCulled(
        address indexed victim,
        uint256 penaltyAmount,
        uint256 returnedAmount,
        address indexed newEntrant
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // CORE FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Enter a new position or add to existing position at same level
    /// @param amount Amount of DATA to stake
    /// @param level Risk level to enter (ignored if position exists)
    function jackIn(
        uint256 amount,
        Level level
    ) external;

    /// @notice Add stake to existing position
    /// @param amount Amount of DATA to add
    function addStake(
        uint256 amount
    ) external;

    /// @notice Exit position and claim rewards
    /// @return amount Principal returned
    /// @return rewards Rewards claimed
    function extract() external returns (uint256 amount, uint256 rewards);

    /// @notice Claim pending rewards without exiting position
    /// @return rewards Amount of rewards claimed
    function claimRewards() external returns (uint256 rewards);

    // ══════════════════════════════════════════════════════════════════════════════
    // SCANNER FUNCTIONS (Called by TraceScan contract)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Mark positions as dead and accumulate dead capital
    /// @dev Only callable by SCANNER_ROLE
    /// @param level The level being scanned
    /// @param deadUsers Array of users who died in the scan
    /// @return totalDead Total dead capital accumulated
    function processDeaths(
        Level level,
        address[] calldata deadUsers
    ) external returns (uint256 totalDead);

    /// @notice Distribute cascade rewards after scan finalization
    /// @dev Only callable by SCANNER_ROLE
    /// @param level Source level of deaths
    /// @param totalDead Total dead capital to distribute
    function distributeCascade(
        Level level,
        uint256 totalDead
    ) external;

    /// @notice Increment ghost streak for survivors
    /// @dev Only callable by SCANNER_ROLE
    /// @param level The level that was scanned
    function incrementGhostStreak(
        Level level
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // DISTRIBUTOR FUNCTIONS (Called by RewardsDistributor)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Add emission rewards to a level
    /// @dev Only callable by DISTRIBUTOR_ROLE
    /// @param level Level to receive emissions
    /// @param amount Amount of DATA emissions
    function addEmissionRewards(
        Level level,
        uint256 amount
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // BOOST FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Apply a boost from mini-game completion
    /// @param boostType Type of boost (death reduction or yield)
    /// @param valueBps Boost value in basis points
    /// @param expiry When boost expires
    /// @param nonce Unique nonce to prevent replay
    /// @param signature Server signature authorizing the boost
    function applyBoost(
        BoostType boostType,
        uint16 valueBps,
        uint64 expiry,
        bytes32 nonce,
        bytes calldata signature
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // SYSTEM RESET FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Trigger system reset if deadline has passed
    function triggerSystemReset() external;

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get a user's position
    function getPosition(
        address user
    ) external view returns (Position memory);

    /// @notice Get pending rewards for a user
    function getPendingRewards(
        address user
    ) external view returns (uint256);

    /// @notice Get effective death rate for a user (after boosts)
    function getEffectiveDeathRate(
        address user
    ) external view returns (uint16);

    /// @notice Get level configuration
    function getLevelConfig(
        Level level
    ) external view returns (LevelConfig memory);

    /// @notice Get level runtime state
    function getLevelState(
        Level level
    ) external view returns (LevelState memory);

    /// @notice Get system reset state
    function getSystemReset() external view returns (SystemReset memory);

    /// @notice Check if user is in lock period (cannot extract)
    function isInLockPeriod(
        address user
    ) external view returns (bool);

    /// @notice Check if a user's position is alive
    function isAlive(
        address user
    ) external view returns (bool);

    /// @notice Get total value locked across all levels
    function getTotalValueLocked() external view returns (uint256);

    /// @notice Get active boosts for a user
    function getActiveBoosts(
        address user
    ) external view returns (Boost[] memory);

    /// @notice Get culling risk for a user
    /// @return riskBps Probability of being culled if selection occurs
    /// @return isEligible Whether user is in bottom X%
    /// @return capacityPct Current level capacity percentage
    function getCullingRisk(
        address user
    ) external view returns (uint16 riskBps, bool isEligible, uint16 capacityPct);
}
