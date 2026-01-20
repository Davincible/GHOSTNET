// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { ITraceScan } from "./interfaces/ITraceScan.sol";
import { IGhostCore } from "./interfaces/IGhostCore.sol";
import { TraceScanStorage } from "./TraceScanStorage.sol";

/// @title TraceScan
/// @notice Randomness and trustless death verification for GHOSTNET
/// @dev Uses prevrandao-based randomness with 60s lock period
///
/// Three-Phase Scan Process:
/// 1. executeScan() - Generate deterministic seed (anyone can call when timer expires)
/// 2. submitDeaths() - Batch submit death proofs (anyone can call, contract verifies)
/// 3. finalizeScan() - Distribute cascade rewards (anyone can call after submission window)
///
/// Trustless Properties:
/// - Deaths are deterministic from (seed, address, deathRate)
/// - Anyone can verify and submit death proofs
/// - No centralized keeper required (permissionless)
///
/// @custom:security-contact security@ghostnet.game
contract TraceScan is
    ITraceScan,
    TraceScanStorage,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    // ══════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _ghostCore Address of the GhostCore contract
    /// @param _admin Address with DEFAULT_ADMIN_ROLE (should be timelock)
    function initialize(address _ghostCore, address _admin) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        TraceScanStorageLayout storage $ = _getTraceScanStorage();

        $.ghostCore = IGhostCore(_ghostCore);
        $.submissionWindow = DEFAULT_SUBMISSION_WINDOW;
        $.maxBatchSize = DEFAULT_MAX_BATCH_SIZE;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(KEEPER_ROLE, _admin);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PHASE 1: SCAN EXECUTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function executeScan(IGhostCore.Level level) external whenNotPaused {
        if (level == IGhostCore.Level.NONE || level > IGhostCore.Level.BLACK_ICE) {
            revert InvalidLevel();
        }

        TraceScanStorageLayout storage $ = _getTraceScanStorage();

        // Check if scan can be executed
        IGhostCore.LevelState memory state = $.ghostCore.getLevelState(level);
        if (block.timestamp < state.nextScanTime) revert ScanNotReady();

        Scan storage scan = $.currentScans[level];
        if (scan.executedAt > 0 && !scan.finalized) revert ScanAlreadyActive();

        // Generate seed
        uint256 seed = _generateSeed($, level);
        uint256 scanId = $.scanNonce; // Already incremented in _generateSeed

        // Initialize scan
        $.currentScans[level] = Scan({
            scanId: scanId,
            seed: seed,
            executedAt: uint64(block.timestamp),
            finalizedAt: 0,
            level: level,
            totalDead: 0,
            deathCount: 0,
            finalized: false
        });

        emit ScanExecuted(level, scanId, seed, uint64(block.timestamp));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PHASE 2: DEATH PROOF SUBMISSION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function submitDeaths(IGhostCore.Level level, address[] calldata deadUsers)
        external
        whenNotPaused
    {
        TraceScanStorageLayout storage $ = _getTraceScanStorage();
        Scan storage scan = $.currentScans[level];

        // Validate scan state
        if (scan.executedAt == 0) revert ScanNotActive();
        if (scan.finalized) revert ScanAlreadyFinalized();
        if (block.timestamp > scan.executedAt + $.submissionWindow) {
            revert SubmissionWindowClosed();
        }
        if (deadUsers.length > $.maxBatchSize) revert BatchTooLarge();

        // Build verified dead list
        address[] memory verifiedDead = new address[](deadUsers.length);
        uint256 verifiedCount;
        uint256 batchTotalDead;

        for (uint256 i; i < deadUsers.length; ++i) {
            address user = deadUsers[i];

            // Skip if already processed in this scan (epoch-based check)
            if ($.processedInScan[level][scan.scanId][user]) continue;

            // Check if user has alive position at this level
            if (!$.ghostCore.isAlive(user)) continue;

            IGhostCore.Position memory pos = $.ghostCore.getPosition(user);
            if (pos.level != level) continue;

            // Get effective death rate and verify death
            uint16 deathRate = $.ghostCore.getEffectiveDeathRate(user);
            if (!_isDead(scan.seed, user, deathRate)) revert UserNotDead();

            // Mark as processed (epoch-based)
            $.processedInScan[level][scan.scanId][user] = true;

            verifiedDead[verifiedCount++] = user;
            batchTotalDead += pos.amount;
        }

        if (verifiedCount == 0) return;

        // Resize array to actual count
        assembly {
            mstore(verifiedDead, verifiedCount)
        }

        // Update scan state
        scan.deathCount += verifiedCount;
        scan.totalDead += batchTotalDead;

        // Process deaths in GhostCore
        $.ghostCore.processDeaths(level, verifiedDead);

        emit DeathsSubmitted(level, scan.scanId, verifiedCount, batchTotalDead, msg.sender);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PHASE 3: SCAN FINALIZATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function finalizeScan(IGhostCore.Level level) external whenNotPaused {
        TraceScanStorageLayout storage $ = _getTraceScanStorage();
        Scan storage scan = $.currentScans[level];

        // Validate scan state
        if (scan.executedAt == 0) revert ScanNotActive();
        if (scan.finalized) revert ScanAlreadyFinalized();
        if (block.timestamp < scan.executedAt + $.submissionWindow) {
            revert SubmissionWindowNotClosed();
        }

        // Mark finalized
        scan.finalized = true;
        scan.finalizedAt = uint64(block.timestamp);

        // Distribute cascade if there were deaths
        if (scan.totalDead > 0) {
            $.ghostCore.distributeCascade(level, scan.totalDead);
        }

        // Increment ghost streaks for survivors
        $.ghostCore.incrementGhostStreak(level);

        // Note: No cleanup of processedInScan needed!
        // The epoch-based design means old scan entries are simply never accessed again.
        // This is O(1) "logical cleanup" vs O(n) explicit deletion.

        emit ScanFinalized(level, scan.scanId, scan.deathCount, scan.totalDead, scan.finalizedAt);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH VERIFICATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function isDead(uint256 seed, address user, uint16 deathRateBps)
        external
        pure
        returns (bool)
    {
        return _isDead(seed, user, deathRateBps);
    }

    /// @inheritdoc ITraceScan
    function wouldDie(IGhostCore.Level level, address user) external view returns (bool) {
        TraceScanStorageLayout storage $ = _getTraceScanStorage();
        Scan storage scan = $.currentScans[level];

        // No pending scan
        if (scan.executedAt == 0 || scan.finalized) return false;

        // Check if user is alive at this level
        if (!$.ghostCore.isAlive(user)) return false;

        IGhostCore.Position memory pos = $.ghostCore.getPosition(user);
        if (pos.level != level) return false;

        uint16 deathRate = $.ghostCore.getEffectiveDeathRate(user);
        return _isDead(scan.seed, user, deathRate);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function canExecuteScan(IGhostCore.Level level) public view returns (bool) {
        TraceScanStorageLayout storage $ = _getTraceScanStorage();

        // Check timer
        IGhostCore.LevelState memory state = $.ghostCore.getLevelState(level);
        if (block.timestamp < state.nextScanTime) return false;

        // Check no active unfinalized scan
        Scan storage scan = $.currentScans[level];
        if (scan.executedAt > 0 && !scan.finalized) return false;

        return true;
    }

    /// @inheritdoc ITraceScan
    function canFinalizeScan(IGhostCore.Level level) public view returns (bool) {
        TraceScanStorageLayout storage $ = _getTraceScanStorage();
        Scan storage scan = $.currentScans[level];

        // Must have active scan
        if (scan.executedAt == 0) return false;

        // Must not be finalized
        if (scan.finalized) return false;

        // Submission window must have closed
        if (block.timestamp < scan.executedAt + $.submissionWindow) return false;

        return true;
    }

    /// @inheritdoc ITraceScan
    function getCurrentScan(IGhostCore.Level level) external view returns (Scan memory) {
        return _getTraceScanStorage().currentScans[level];
    }

    /// @inheritdoc ITraceScan
    function submissionWindow() external view returns (uint256) {
        return _getTraceScanStorage().submissionWindow;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // KEEPER INTERFACE (Gelato Automate compatible)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc ITraceScan
    function checker() external view returns (bool canExec, bytes memory execPayload) {
        // Check all levels for actionable items
        for (uint8 i = 1; i <= 5; ++i) {
            IGhostCore.Level level = IGhostCore.Level(i);

            // Check if scan can be executed
            if (canExecuteScan(level)) {
                return (true, abi.encodeCall(this.executeScan, (level)));
            }

            // Check if scan can be finalized
            if (canFinalizeScan(level)) {
                return (true, abi.encodeCall(this.finalizeScan, (level)));
            }
        }

        return (false, bytes(""));
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

    /// @notice Update submission window duration
    function setSubmissionWindow(uint256 newWindow) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getTraceScanStorage().submissionWindow = newWindow;
    }

    /// @notice Update max batch size
    function setMaxBatchSize(uint256 newSize) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getTraceScanStorage().maxBatchSize = newSize;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @dev Generate deterministic seed for scan
    /// Uses multiple components for entropy:
    /// - prevrandao: RANDAO accumulator (constant ~60s on MegaETH)
    /// - timestamp: Changes every second
    /// - block.number: Changes every block
    /// - level: Which level is being scanned
    /// - nonce: Incrementing counter (prevents replay)
    function _generateSeed(TraceScanStorageLayout storage $, IGhostCore.Level level)
        internal
        returns (uint256)
    {
        return uint256(
            keccak256(
                abi.encode(block.prevrandao, block.timestamp, block.number, level, $.scanNonce++)
            )
        );
    }

    /// @dev Pure function to determine if a user dies given seed and death rate
    /// Death is deterministic: same inputs always produce same output
    function _isDead(uint256 seed, address user, uint16 deathRateBps) internal pure returns (bool) {
        uint256 roll = uint256(keccak256(abi.encode(seed, user))) % BPS;
        return roll < deathRateBps;
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
