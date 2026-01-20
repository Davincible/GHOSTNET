// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IGhostCore } from "./interfaces/IGhostCore.sol";
import { GhostCoreStorage } from "./GhostCoreStorage.sol";
import { IDataToken } from "../token/interfaces/IDataToken.sol";

/// @title GhostCore
/// @notice Main game logic for GHOSTNET - position management, cascade distribution, boosts
/// @dev UUPS upgradeable with 48-hour timelock governance
///
/// Game Flow:
/// 1. Users jackIn() to create positions at a chosen risk level
/// 2. TraceScan executes periodic scans, calling processDeaths()
/// 3. Dead capital is distributed via distributeCascade()
/// 4. Survivors can extract() their position + accumulated rewards
///
/// @custom:security-contact security@ghostnet.game
contract GhostCore is
    IGhostCore,
    GhostCoreStorage,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ══════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant SCANNER_ROLE = keccak256("SCANNER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ══════════════════════════════════════════════════════════════════════════════
    // EIP-712 DOMAIN
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant BOOST_TYPEHASH =
        keccak256("Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)");

    bytes32 private _domainSeparator;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _dataToken Address of the DATA token
    /// @param _treasury Address to receive protocol fees
    /// @param _boostSigner Address that signs boost authorizations
    /// @param _admin Address with DEFAULT_ADMIN_ROLE (should be timelock)
    function initialize(
        address _dataToken,
        address _treasury,
        address _boostSigner,
        address _admin
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();

        $.dataToken = IDataToken(_dataToken);
        $.treasury = _treasury;
        $.boostSigner = _boostSigner;

        // Initialize system reset
        $.systemReset = SystemReset({
            deadline: uint64(block.timestamp + DEFAULT_RESET_DEADLINE),
            lastDepositor: address(0),
            lastDepositTime: uint64(block.timestamp),
            epoch: 1,
            penaltyBps: 0
        });

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);

        // Initialize EIP-712 domain separator
        _domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("GHOSTNET"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );

        // Initialize level configurations
        _initializeLevels($);
    }

    /// @dev Initialize default level configurations
    function _initializeLevels(GhostCoreStorageLayout storage $) private {
        // VAULT - Safest level
        $.levelConfigs[Level.VAULT] = LevelConfig({
            baseDeathRateBps: 500, // 5%
            scanInterval: 4 hours,
            minStake: 10 * 1e18, // 10 DATA minimum
            maxPositions: 5000,
            cullingBottomPct: 5000, // Bottom 50%
            cullingPenaltyBps: 8000 // 80% loss
        });

        // MAINFRAME - Conservative
        $.levelConfigs[Level.MAINFRAME] = LevelConfig({
            baseDeathRateBps: 1500, // 15%
            scanInterval: 3 hours,
            minStake: 25 * 1e18,
            maxPositions: 3000,
            cullingBottomPct: 5000,
            cullingPenaltyBps: 8000
        });

        // SUBNET - Balanced
        $.levelConfigs[Level.SUBNET] = LevelConfig({
            baseDeathRateBps: 2500, // 25%
            scanInterval: 2 hours,
            minStake: 50 * 1e18,
            maxPositions: 1500,
            cullingBottomPct: 5000,
            cullingPenaltyBps: 8000
        });

        // DARKNET - High risk
        $.levelConfigs[Level.DARKNET] = LevelConfig({
            baseDeathRateBps: 3500, // 35%
            scanInterval: 1 hours,
            minStake: 100 * 1e18,
            maxPositions: 500,
            cullingBottomPct: 5000,
            cullingPenaltyBps: 8000
        });

        // BLACK_ICE - Maximum risk
        $.levelConfigs[Level.BLACK_ICE] = LevelConfig({
            baseDeathRateBps: 4500, // 45%
            scanInterval: 30 minutes,
            minStake: 250 * 1e18,
            maxPositions: 100,
            cullingBottomPct: 5000,
            cullingPenaltyBps: 8000
        });

        // Initialize next scan times
        uint64 now_ = uint64(block.timestamp);
        $.levelStates[Level.VAULT].nextScanTime = now_ + 4 hours;
        $.levelStates[Level.MAINFRAME].nextScanTime = now_ + 3 hours;
        $.levelStates[Level.SUBNET].nextScanTime = now_ + 2 hours;
        $.levelStates[Level.DARKNET].nextScanTime = now_ + 1 hours;
        $.levelStates[Level.BLACK_ICE].nextScanTime = now_ + 30 minutes;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CORE FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function jackIn(uint256 amount, Level level) external nonReentrant whenNotPaused {
        if (level == Level.NONE || level > Level.BLACK_ICE) revert InvalidLevel();
        if (amount == 0) revert InvalidAmount();

        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[msg.sender];

        // Settle any pending reset penalty
        _settleResetPenalty($, msg.sender);

        LevelConfig storage config = $.levelConfigs[level];
        LevelState storage state = $.levelStates[level];

        if (pos.level == Level.NONE) {
            // New position
            if (amount < config.minStake) revert BelowMinimumStake();

            // Check capacity - handle culling if needed
            if (config.maxPositions > 0 && state.aliveCount >= config.maxPositions) {
                _handleCulling($, level, msg.sender, amount);
            }

            pos.amount = amount;
            pos.level = level;
            pos.entryTimestamp = uint64(block.timestamp);
            pos.lastAddTimestamp = uint64(block.timestamp);
            pos.rewardDebt = (amount * state.accRewardsPerShare) / REWARD_PRECISION;
            pos.alive = true;
            pos.ghostStreak = 0;

            state.totalStaked += amount;
            state.aliveCount += 1;

            // Add to position tracking
            $.levelPositions[level].push(msg.sender);
            $.positionIndex[level][msg.sender] = $.levelPositions[level].length - 1;

            emit JackedIn(msg.sender, amount, level, amount);
        } else {
            // Existing position - must use addStake
            revert PositionAlreadyExists();
        }

        // Transfer tokens
        IERC20(address($.dataToken)).safeTransferFrom(msg.sender, address(this), amount);

        // Extend system reset timer
        _extendResetTimer($, amount);
    }

    /// @inheritdoc IGhostCore
    function addStake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[msg.sender];

        if (pos.level == Level.NONE) revert NoPositionExists();
        if (!pos.alive) revert PositionDead();

        // Settle pending rewards before modifying stake
        _settleResetPenalty($, msg.sender);
        uint256 pending = _calculatePendingRewards($, msg.sender);
        if (pending > 0) {
            pos.rewardDebt += pending;
            // Rewards are added to position for compound effect
        }

        LevelState storage state = $.levelStates[pos.level];

        pos.amount += amount;
        pos.lastAddTimestamp = uint64(block.timestamp);
        pos.rewardDebt = (pos.amount * state.accRewardsPerShare) / REWARD_PRECISION;

        state.totalStaked += amount;

        IERC20(address($.dataToken)).safeTransferFrom(msg.sender, address(this), amount);

        _extendResetTimer($, amount);

        emit StakeAdded(msg.sender, amount, pos.amount);
    }

    /// @inheritdoc IGhostCore
    function extract() external nonReentrant whenNotPaused returns (uint256 amount, uint256 rewards) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[msg.sender];

        if (pos.level == Level.NONE) revert NoPositionExists();
        if (!pos.alive) revert PositionDead();
        if (_isInLockPeriod($, msg.sender)) revert PositionLocked();

        _settleResetPenalty($, msg.sender);

        Level level = pos.level;
        LevelState storage state = $.levelStates[level];

        // Calculate rewards
        rewards = _calculatePendingRewards($, msg.sender);
        amount = pos.amount;

        // Update state
        state.totalStaked -= amount;
        state.aliveCount -= 1;

        // Remove from position tracking
        _removeFromLevelPositions($, level, msg.sender);

        // Clear position
        delete $.positions[msg.sender];
        delete $.userBoosts[msg.sender];

        // Transfer tokens
        uint256 totalOut = amount + rewards;
        IERC20(address($.dataToken)).safeTransfer(msg.sender, totalOut);

        emit Extracted(msg.sender, amount, rewards);
    }

    /// @inheritdoc IGhostCore
    function claimRewards() external nonReentrant whenNotPaused returns (uint256 rewards) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[msg.sender];

        if (pos.level == Level.NONE) revert NoPositionExists();
        if (!pos.alive) revert PositionDead();

        _settleResetPenalty($, msg.sender);

        rewards = _calculatePendingRewards($, msg.sender);
        if (rewards == 0) return 0;

        LevelState storage state = $.levelStates[pos.level];
        pos.rewardDebt = (pos.amount * state.accRewardsPerShare) / REWARD_PRECISION;

        IERC20(address($.dataToken)).safeTransfer(msg.sender, rewards);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCANNER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function processDeaths(Level level, address[] calldata deadUsers)
        external
        onlyRole(SCANNER_ROLE)
        returns (uint256 totalDead)
    {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        LevelState storage state = $.levelStates[level];

        for (uint256 i; i < deadUsers.length; ++i) {
            address user = deadUsers[i];
            Position storage pos = $.positions[user];

            if (pos.level != level || !pos.alive) continue;

            totalDead += pos.amount;
            pos.alive = false;
            pos.ghostStreak = 0;

            state.totalStaked -= pos.amount;
            state.aliveCount -= 1;

            _removeFromLevelPositions($, level, user);
        }

        emit DeathsProcessed(level, deadUsers.length, totalDead, 0, 0);
    }

    /// @inheritdoc IGhostCore
    function distributeCascade(Level level, uint256 totalDead) external onlyRole(SCANNER_ROLE) {
        if (totalDead == 0) return;

        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();

        // Calculate splits (30/30/30/10)
        uint256 sameLevelAmount = (totalDead * CASCADE_SAME_LEVEL_BPS) / BPS;
        uint256 upstreamAmount = (totalDead * CASCADE_UPSTREAM_BPS) / BPS;
        uint256 burnAmount = (totalDead * CASCADE_BURN_BPS) / BPS;
        uint256 protocolAmount = totalDead - sameLevelAmount - upstreamAmount - burnAmount;

        // Distribute to same-level survivors
        LevelState storage sourceState = $.levelStates[level];
        if (sourceState.totalStaked > 0) {
            sourceState.accRewardsPerShare +=
                (sameLevelAmount * REWARD_PRECISION) / sourceState.totalStaked;
        } else {
            // No same-level survivors - add to upstream
            upstreamAmount += sameLevelAmount;
            sameLevelAmount = 0;
        }

        // Distribute to upstream levels (safer levels)
        _distributeUpstream($, level, upstreamAmount);

        // Burn
        IERC20(address($.dataToken)).safeTransfer($.dataToken.DEAD_ADDRESS(), burnAmount);

        // Protocol treasury
        IERC20(address($.dataToken)).safeTransfer($.treasury, protocolAmount);

        emit CascadeDistributed(level, sameLevelAmount, upstreamAmount, burnAmount, protocolAmount);
    }

    /// @inheritdoc IGhostCore
    function incrementGhostStreak(Level level) external onlyRole(SCANNER_ROLE) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        address[] storage users = $.levelPositions[level];

        uint256 survivorCount;
        for (uint256 i; i < users.length; ++i) {
            Position storage pos = $.positions[users[i]];
            if (pos.alive && pos.level == level) {
                pos.ghostStreak += 1;
                survivorCount++;
            }
        }

        // Update next scan time
        $.levelStates[level].nextScanTime =
            uint64(block.timestamp) + $.levelConfigs[level].scanInterval;

        emit SurvivorsUpdated(level, survivorCount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DISTRIBUTOR FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function addEmissionRewards(Level level, uint256 amount) external onlyRole(DISTRIBUTOR_ROLE) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        LevelState storage state = $.levelStates[level];

        if (state.totalStaked > 0) {
            state.accRewardsPerShare += (amount * REWARD_PRECISION) / state.totalStaked;
        }

        emit EmissionsAdded(level, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BOOST FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function applyBoost(
        BoostType boostType,
        uint16 valueBps,
        uint64 expiry,
        bytes32 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();

        if ($.positions[msg.sender].level == Level.NONE) revert NoPositionExists();
        if (expiry <= block.timestamp) revert SignatureExpired();
        if ($.usedNonces[nonce]) revert NonceAlreadyUsed();

        // Verify signature
        bytes32 structHash = keccak256(
            abi.encode(BOOST_TYPEHASH, msg.sender, uint8(boostType), valueBps, expiry, nonce)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, structHash));

        address signer = digest.recover(signature);
        if (signer != $.boostSigner) revert InvalidSignature();

        $.usedNonces[nonce] = true;

        // Add boost
        $.userBoosts[msg.sender].push(Boost({ boostType: boostType, valueBps: valueBps, expiry: expiry }));

        emit BoostApplied(msg.sender, boostType, valueBps, expiry);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SYSTEM RESET FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function triggerSystemReset() external nonReentrant {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        SystemReset storage reset = $.systemReset;

        if (block.timestamp < reset.deadline) revert SystemResetNotReady();

        // Calculate total value locked
        uint256 totalStaked;
        for (uint8 i = 1; i <= 5; ++i) {
            totalStaked += $.levelStates[Level(i)].totalStaked;
        }

        uint256 penaltyPool = (totalStaked * SYSTEM_RESET_PENALTY_BPS) / BPS;

        // Calculate distributions
        uint256 jackpotAmount = (penaltyPool * JACKPOT_SHARE_BPS) / BPS;
        uint256 burnAmount = (penaltyPool * RESET_BURN_SHARE_BPS) / BPS;
        uint256 protocolAmount = penaltyPool - jackpotAmount - burnAmount;

        // Store penalty for lazy settlement
        reset.epoch += 1;
        reset.penaltyBps = SYSTEM_RESET_PENALTY_BPS;

        // Send jackpot to last depositor
        if (reset.lastDepositor != address(0) && jackpotAmount > 0) {
            IERC20(address($.dataToken)).safeTransfer(reset.lastDepositor, jackpotAmount);
        }

        // Burn
        IERC20(address($.dataToken)).safeTransfer($.dataToken.DEAD_ADDRESS(), burnAmount);

        // Protocol
        IERC20(address($.dataToken)).safeTransfer($.treasury, protocolAmount);

        // Reset timer
        reset.deadline = uint64(block.timestamp + DEFAULT_RESET_DEADLINE);
        reset.lastDepositor = address(0);
        reset.lastDepositTime = uint64(block.timestamp);

        emit SystemResetTriggered(penaltyPool, reset.lastDepositor, jackpotAmount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGhostCore
    function getPosition(address user) external view returns (Position memory) {
        return _getGhostCoreStorage().positions[user];
    }

    /// @inheritdoc IGhostCore
    function getPendingRewards(address user) external view returns (uint256) {
        return _calculatePendingRewards(_getGhostCoreStorage(), user);
    }

    /// @inheritdoc IGhostCore
    function getEffectiveDeathRate(address user) external view returns (uint16) {
        return _getEffectiveDeathRate(_getGhostCoreStorage(), user);
    }

    /// @inheritdoc IGhostCore
    function getLevelConfig(Level level) external view returns (LevelConfig memory) {
        return _getGhostCoreStorage().levelConfigs[level];
    }

    /// @inheritdoc IGhostCore
    function getLevelState(Level level) external view returns (LevelState memory) {
        return _getGhostCoreStorage().levelStates[level];
    }

    /// @inheritdoc IGhostCore
    function getSystemReset() external view returns (SystemReset memory) {
        return _getGhostCoreStorage().systemReset;
    }

    /// @inheritdoc IGhostCore
    function isInLockPeriod(address user) external view returns (bool) {
        return _isInLockPeriod(_getGhostCoreStorage(), user);
    }

    /// @inheritdoc IGhostCore
    function isAlive(address user) external view returns (bool) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        return $.positions[user].level != Level.NONE && $.positions[user].alive;
    }

    /// @inheritdoc IGhostCore
    function getTotalValueLocked() external view returns (uint256 total) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        for (uint8 i = 1; i <= 5; ++i) {
            total += $.levelStates[Level(i)].totalStaked;
        }
    }

    /// @inheritdoc IGhostCore
    function getActiveBoosts(address user) external view returns (Boost[] memory) {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Boost[] storage boosts = $.userBoosts[user];

        // Count active boosts
        uint256 activeCount;
        for (uint256 i; i < boosts.length; ++i) {
            if (boosts[i].expiry > block.timestamp) activeCount++;
        }

        // Build result array
        Boost[] memory result = new Boost[](activeCount);
        uint256 j;
        for (uint256 i; i < boosts.length; ++i) {
            if (boosts[i].expiry > block.timestamp) {
                result[j++] = boosts[i];
            }
        }

        return result;
    }

    /// @inheritdoc IGhostCore
    function getCullingRisk(address user)
        external
        view
        returns (uint16 riskBps, bool isEligible, uint16 capacityPct)
    {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[user];

        if (pos.level == Level.NONE || !pos.alive) {
            return (0, false, 0);
        }

        LevelConfig storage config = $.levelConfigs[pos.level];
        LevelState storage state = $.levelStates[pos.level];

        if (config.maxPositions == 0) {
            return (0, false, 0);
        }

        capacityPct = uint16((state.aliveCount * BPS) / config.maxPositions);

        // Simplified culling risk calculation
        // Would need full position sorting for accurate calculation
        isEligible = false; // Placeholder - full implementation would check position ranking
        riskBps = 0;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pause the contract
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Update level configuration
    function updateLevelConfig(Level level, LevelConfig calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _getGhostCoreStorage().levelConfigs[level] = config;
    }

    /// @notice Update boost signer address
    function setBoostSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getGhostCoreStorage().boostSigner = newSigner;
    }

    /// @notice Emergency withdrawal when paused
    function emergencyWithdraw() external nonReentrant whenPaused {
        GhostCoreStorageLayout storage $ = _getGhostCoreStorage();
        Position storage pos = $.positions[msg.sender];

        if (pos.level == Level.NONE) revert NoPositionExists();

        uint256 amount = pos.amount;
        Level level = pos.level;

        $.levelStates[level].totalStaked -= amount;
        if (pos.alive) {
            $.levelStates[level].aliveCount -= 1;
        }

        _removeFromLevelPositions($, level, msg.sender);
        delete $.positions[msg.sender];
        delete $.userBoosts[msg.sender];

        // No rewards in emergency - just principal
        IERC20(address($.dataToken)).safeTransfer(msg.sender, amount);

        emit Extracted(msg.sender, amount, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function _calculatePendingRewards(GhostCoreStorageLayout storage $, address user)
        internal
        view
        returns (uint256)
    {
        Position storage pos = $.positions[user];
        if (pos.level == Level.NONE || !pos.alive) return 0;

        LevelState storage state = $.levelStates[pos.level];
        uint256 accRewards = (pos.amount * state.accRewardsPerShare) / REWARD_PRECISION;

        if (accRewards <= pos.rewardDebt) return 0;
        return accRewards - pos.rewardDebt;
    }

    function _getEffectiveDeathRate(GhostCoreStorageLayout storage $, address user)
        internal
        view
        returns (uint16)
    {
        Position storage pos = $.positions[user];
        if (pos.level == Level.NONE) return 0;

        uint16 baseRate = $.levelConfigs[pos.level].baseDeathRateBps;

        // Apply death reduction boosts
        Boost[] storage boosts = $.userBoosts[user];
        uint256 totalReduction;

        for (uint256 i; i < boosts.length; ++i) {
            if (
                boosts[i].boostType == BoostType.DEATH_REDUCTION
                    && boosts[i].expiry > block.timestamp
            ) {
                totalReduction += boosts[i].valueBps;
            }
        }

        if (totalReduction >= baseRate) return 0;
        return baseRate - uint16(totalReduction);
    }

    function _isInLockPeriod(GhostCoreStorageLayout storage $, address user)
        internal
        view
        returns (bool)
    {
        Position storage pos = $.positions[user];
        if (pos.level == Level.NONE) return false;

        uint64 nextScan = $.levelStates[pos.level].nextScanTime;

        // Locked if within LOCK_PERIOD of next scan
        return block.timestamp >= nextScan - LOCK_PERIOD && block.timestamp < nextScan;
    }

    function _distributeUpstream(
        GhostCoreStorageLayout storage $,
        Level sourceLevel,
        uint256 amount
    ) internal {
        if (amount == 0) return;

        // Calculate total upstream TVL
        uint256 totalUpstreamTVL;
        for (uint8 i = 1; i < uint8(sourceLevel); ++i) {
            totalUpstreamTVL += $.levelStates[Level(i)].totalStaked;
        }

        if (totalUpstreamTVL == 0) {
            // No upstream positions - burn instead
            IERC20(address($.dataToken)).safeTransfer($.dataToken.DEAD_ADDRESS(), amount);
            return;
        }

        // Distribute proportionally
        for (uint8 i = 1; i < uint8(sourceLevel); ++i) {
            Level upstreamLevel = Level(i);
            LevelState storage state = $.levelStates[upstreamLevel];

            if (state.totalStaked > 0) {
                uint256 share = (amount * state.totalStaked) / totalUpstreamTVL;
                state.accRewardsPerShare += (share * REWARD_PRECISION) / state.totalStaked;
            }
        }
    }

    function _extendResetTimer(GhostCoreStorageLayout storage $, uint256 amount) internal {
        SystemReset storage reset = $.systemReset;

        uint256 extension;
        if (amount >= TIER4_THRESHOLD) {
            // Full reset
            reset.deadline = uint64(block.timestamp + MAX_RESET_DEADLINE);
        } else {
            if (amount < TIER1_THRESHOLD) {
                extension = TIER1_EXTENSION;
            } else if (amount < TIER2_THRESHOLD) {
                extension = TIER2_EXTENSION;
            } else if (amount < TIER3_THRESHOLD) {
                extension = TIER3_EXTENSION;
            } else {
                extension = TIER4_EXTENSION;
            }

            uint64 newDeadline = uint64(block.timestamp + extension);
            if (newDeadline > reset.deadline) {
                reset.deadline = newDeadline;
            }

            // Cap at max
            if (reset.deadline > block.timestamp + MAX_RESET_DEADLINE) {
                reset.deadline = uint64(block.timestamp + MAX_RESET_DEADLINE);
            }
        }

        reset.lastDepositor = msg.sender;
        reset.lastDepositTime = uint64(block.timestamp);
    }

    function _settleResetPenalty(GhostCoreStorageLayout storage $, address user) internal {
        uint256 lastEpoch = $.lastSettledEpoch[user];
        uint256 currentEpoch = $.systemReset.epoch;

        if (lastEpoch >= currentEpoch) return;

        Position storage pos = $.positions[user];
        if (pos.level == Level.NONE || pos.amount == 0) {
            $.lastSettledEpoch[user] = currentEpoch;
            return;
        }

        // Apply penalty from previous resets
        uint16 penaltyBps = $.systemReset.penaltyBps;
        if (penaltyBps > 0 && lastEpoch < currentEpoch) {
            uint256 penalty = (pos.amount * penaltyBps) / BPS;
            pos.amount -= penalty;

            // Update level state
            $.levelStates[pos.level].totalStaked -= penalty;
        }

        $.lastSettledEpoch[user] = currentEpoch;
    }

    function _handleCulling(
        GhostCoreStorageLayout storage $,
        Level level,
        address newEntrant,
        uint256 newAmount
    ) internal {
        // Simplified culling - select random victim from bottom positions
        // Full implementation would use weighted random selection
        address[] storage positions = $.levelPositions[level];
        if (positions.length == 0) revert LevelAtCapacity();

        // For now, select the first (oldest) position as victim
        // TODO: Implement weighted random selection based on stake amounts
        address victim = positions[0];
        Position storage victimPos = $.positions[victim];

        LevelConfig storage config = $.levelConfigs[level];
        uint256 penaltyAmount = (victimPos.amount * config.cullingPenaltyBps) / BPS;
        uint256 returnAmount = victimPos.amount - penaltyAmount;

        // Update victim
        victimPos.alive = false;
        $.levelStates[level].totalStaked -= victimPos.amount;
        $.levelStates[level].aliveCount -= 1;

        _removeFromLevelPositions($, level, victim);

        // Return remaining to victim
        if (returnAmount > 0) {
            IERC20(address($.dataToken)).safeTransfer(victim, returnAmount);
        }

        // Cascade the penalty amount (like death)
        if (penaltyAmount > 0) {
            // Mini-cascade for culling penalty
            uint256 burnAmount = (penaltyAmount * CASCADE_BURN_BPS) / BPS;
            uint256 remaining = penaltyAmount - burnAmount;

            IERC20(address($.dataToken)).safeTransfer($.dataToken.DEAD_ADDRESS(), burnAmount);

            // Distribute remaining to same level
            if ($.levelStates[level].totalStaked > 0) {
                $.levelStates[level].accRewardsPerShare +=
                    (remaining * REWARD_PRECISION) / $.levelStates[level].totalStaked;
            }
        }

        emit PositionCulled(victim, penaltyAmount, returnAmount, newEntrant);
    }

    function _removeFromLevelPositions(
        GhostCoreStorageLayout storage $,
        Level level,
        address user
    ) internal {
        address[] storage positions = $.levelPositions[level];
        uint256 index = $.positionIndex[level][user];

        if (positions.length > 0 && index < positions.length) {
            // Swap with last and pop
            address lastUser = positions[positions.length - 1];
            positions[index] = lastUser;
            $.positionIndex[level][lastUser] = index;
            positions.pop();
        }

        delete $.positionIndex[level][user];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UPGRADE AUTHORIZATION
    // ══════════════════════════════════════════════════════════════════════════════

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
