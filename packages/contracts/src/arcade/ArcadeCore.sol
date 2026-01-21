// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IArcadeCore } from "./interfaces/IArcadeCore.sol";
import { ArcadeCoreStorage } from "./ArcadeCoreStorage.sol";
import { IDataToken } from "../token/interfaces/IDataToken.sol";
import { IGhostCore } from "../core/interfaces/IGhostCore.sol";

/// @title ArcadeCore
/// @notice Core contract for GHOSTNET Arcade - manages game sessions and payouts
/// @dev UUPS upgradeable with session-based security model
///
/// Security Model:
/// - Each game session has a bounded prize pool
/// - Payouts cannot exceed the session's prize pool
/// - Refunds cannot exceed player's recorded deposit
/// - Sessions have a state machine preventing double-settlement
///
/// @custom:security-contact security@ghostnet.game
contract ArcadeCore is
    IArcadeCore,
    ArcadeCoreStorage,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant GAME_ADMIN_ROLE = keccak256("GAME_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _dataToken Address of the DATA token
    /// @param _ghostCore Address of the GhostCore contract
    /// @param _treasury Address to receive protocol fees
    /// @param _admin Address with DEFAULT_ADMIN_ROLE (should be timelock)
    function initialize(
        address _dataToken,
        address _ghostCore,
        address _treasury,
        address _admin
    ) external initializer {
        if (_dataToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_admin == address(0)) revert InvalidAddress();

        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        $.dataToken = IDataToken(_dataToken);
        $.ghostCore = IGhostCore(_ghostCore);
        $.treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GAME_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME MANAGEMENT FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeCore
    function registerGame(
        address game,
        GameConfig calldata config
    ) external onlyRole(GAME_ADMIN_ROLE) {
        if (game == address(0)) revert InvalidAddress();

        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if ($.registeredGames[game]) revert GameAlreadyRegistered();

        $.registeredGames[game] = true;
        $.gameConfigs[game] = config;

        emit GameRegistered(game, config);
    }

    /// @inheritdoc IArcadeCore
    function unregisterGame(
        address game
    ) external onlyRole(GAME_ADMIN_ROLE) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if (!$.registeredGames[game]) revert GameNotRegistered();

        $.registeredGames[game] = false;
        delete $.gameConfigs[game];

        emit GameUnregistered(game);
    }

    /// @inheritdoc IArcadeCore
    function updateGameConfig(
        address game,
        GameConfig calldata config
    ) external onlyRole(GAME_ADMIN_ROLE) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if (!$.registeredGames[game]) revert GameNotRegistered();

        $.gameConfigs[game] = config;

        emit GameConfigUpdated(game, config);
    }

    /// @inheritdoc IArcadeCore
    function pauseGame(
        address game
    ) external onlyRole(GAME_ADMIN_ROLE) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if (!$.registeredGames[game]) revert GameNotRegistered();

        $.gameConfigs[game].paused = true;

        emit GameConfigUpdated(game, $.gameConfigs[game]);
    }

    /// @inheritdoc IArcadeCore
    function unpauseGame(
        address game
    ) external onlyRole(GAME_ADMIN_ROLE) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if (!$.registeredGames[game]) revert GameNotRegistered();

        $.gameConfigs[game].paused = false;

        emit GameConfigUpdated(game, $.gameConfigs[game]);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SESSION FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeCore
    function processEntry(
        address player,
        uint256 amount,
        uint256 sessionId
    ) external nonReentrant whenNotPaused returns (uint256 netAmount) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();
        if ($.gameConfigs[msg.sender].paused) revert GamePaused();

        // 2. Get or create session record
        SessionRecord storage session = $.sessions[sessionId];

        if (session.state == SessionState.NONE) {
            // New session - initialize
            session.game = msg.sender;
            session.state = SessionState.ACTIVE;
            session.createdAt = uint64(block.timestamp);

            // Track active session for game
            $.sessionIndex[sessionId] = $.gameActiveSessions[msg.sender].length;
            $.gameActiveSessions[msg.sender].push(sessionId);

            emit SessionCreated(msg.sender, sessionId, uint64(block.timestamp));
        } else {
            // Existing session - verify ownership and state
            if (session.game != msg.sender) revert SessionGameMismatch();
            if (session.state != SessionState.ACTIVE) revert SessionNotActive();
        }

        // 3. Validate entry amount
        GameConfig storage config = $.gameConfigs[msg.sender];
        if (amount < config.minEntry) revert InvalidEntryAmount();
        if (config.maxEntry > 0 && amount > config.maxEntry) revert InvalidEntryAmount();

        // 4. Check position requirement
        if (config.requiresPosition && address($.ghostCore) != address(0)) {
            if (!$.ghostCore.isAlive(player)) {
                revert PositionRequired();
            }
        }

        // 5. Rate limiting
        PlayerStats storage stats = $.playerStats[player];
        if (block.timestamp < stats.lastPlayTime + MIN_PLAY_INTERVAL) {
            revert RateLimited();
        }

        // 6. Transfer tokens from player
        IERC20(address($.dataToken)).safeTransferFrom(player, address(this), amount);

        // 7. Calculate and transfer rake
        uint256 rakeAmount = (amount * config.rakeBps) / BPS;
        netAmount = amount - rakeAmount;

        if (rakeAmount > 0) {
            uint256 burnAmount = (rakeAmount * config.burnBps) / BPS;
            uint256 treasuryAmount = rakeAmount - burnAmount;

            if (burnAmount > 0) {
                IERC20(address($.dataToken)).safeTransfer(DEAD_ADDRESS, burnAmount);
                $.totalBurned += burnAmount;
            }
            if (treasuryAmount > 0) {
                IERC20(address($.dataToken)).safeTransfer($.treasury, treasuryAmount);
            }
            $.totalRakeCollected += rakeAmount;
        }

        // 8. Track deposit and update prize pool
        // Net deposit goes to prize pool
        bytes32 depositKey = _depositKey(sessionId, player);
        $.sessionDeposits[depositKey] += netAmount;
        session.prizePool += netAmount;

        // Gross deposit tracked for refund bounds (Critical Issue #4)
        // Players get back what they paid, including rake portion
        $.sessionGrossDeposits[depositKey] += amount;

        // 9. Update player stats
        stats.totalGamesPlayed++;
        stats.totalWagered += uint128(amount / AMOUNT_SCALE);
        stats.lastPlayTime = uint64(block.timestamp);
        $.totalGamesPlayed++;
        $.totalVolume += amount;

        emit EntryProcessed(msg.sender, player, sessionId, amount, netAmount, rakeAmount);
    }

    /// @inheritdoc IArcadeCore
    function creditPayout(
        uint256 sessionId,
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) external nonReentrant {
        _creditSinglePayout(sessionId, player, amount, burnAmount, won);
    }

    /// @inheritdoc IArcadeCore
    /// @notice Credits payouts to multiple players with full validation
    /// @dev Security: Validates array lengths match, batch size within limits,
    ///      and each individual payout against session constraints
    ///
    /// Gas Considerations:
    /// - Each payout requires ~3 SLOADs and ~3 SSTOREs
    /// - MAX_BATCH_SIZE of 100 keeps gas under block limits
    /// - Consider smaller batches for lower gas costs
    ///
    /// @custom:security Array length validation prevents out-of-bounds reads
    /// @custom:security Batch size limit prevents DoS via gas exhaustion
    function batchCreditPayouts(
        uint256[] calldata sessionIds,
        address[] calldata players,
        uint256[] calldata amounts,
        uint256[] calldata burnAmounts,
        bool[] calldata results
    ) external nonReentrant {
        // ═══════════════════════════════════════════════════════════════════════
        // VALIDATION: Array lengths must match
        // ═══════════════════════════════════════════════════════════════════════
        uint256 batchSize = sessionIds.length;

        if (
            players.length != batchSize || amounts.length != batchSize
                || burnAmounts.length != batchSize || results.length != batchSize
        ) {
            revert ArrayLengthMismatch(
                batchSize, players.length, amounts.length, burnAmounts.length, results.length
            );
        }

        // ═══════════════════════════════════════════════════════════════════════
        // VALIDATION: Batch not empty
        // ═══════════════════════════════════════════════════════════════════════
        if (batchSize == 0) {
            revert EmptyBatch();
        }

        // ═══════════════════════════════════════════════════════════════════════
        // VALIDATION: Batch size within limits
        // ═══════════════════════════════════════════════════════════════════════
        if (batchSize > _MAX_BATCH_SIZE) {
            revert BatchTooLarge(batchSize, _MAX_BATCH_SIZE);
        }

        // ═══════════════════════════════════════════════════════════════════════
        // PROCESS: Credit each payout with full validation
        // ═══════════════════════════════════════════════════════════════════════
        uint256 totalPaid;
        uint256 totalBurned;

        for (uint256 i; i < batchSize; ++i) {
            _creditSinglePayout(sessionIds[i], players[i], amounts[i], burnAmounts[i], results[i]);

            totalPaid += amounts[i];
            totalBurned += burnAmounts[i];
        }

        emit BatchPayoutProcessed(msg.sender, batchSize, totalPaid, totalBurned);
    }

    /// @notice Internal function to credit a single payout with full validation
    /// @dev Extracted to avoid code duplication between creditPayout and batchCreditPayouts
    function _creditSinglePayout(
        uint256 sessionId,
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) internal {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();

        // 2. Validate session
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();
        if (session.game != msg.sender) revert SessionGameMismatch();
        if (session.state != SessionState.ACTIVE) revert SessionNotActive();

        // 3. Validate payout within prize pool bounds
        uint256 totalDisbursement = amount + burnAmount;
        if (session.totalPaid + totalDisbursement > session.prizePool) {
            revert PayoutExceedsPrizePool();
        }

        // 4. Update session totals
        session.totalPaid += totalDisbursement;

        // 5. Execute burn
        if (burnAmount > 0) {
            IERC20(address($.dataToken)).safeTransfer(DEAD_ADDRESS, burnAmount);
            $.totalBurned += burnAmount;
        }

        // 6. Credit payout (pull pattern)
        if (amount > 0) {
            $.pendingPayouts[player] += amount;
            $.totalPendingPayouts += amount;
            emit PayoutCredited(player, amount, $.pendingPayouts[player]);
        }

        // 7. Update player stats
        PlayerStats storage stats = $.playerStats[player];
        if (won) {
            stats.totalWins++;
            stats.totalWon += uint128(amount / AMOUNT_SCALE);
        } else {
            stats.totalLosses++;
        }

        emit GameSettled(msg.sender, player, sessionId, amount, burnAmount, won);
    }

    /// @inheritdoc IArcadeCore
    function settleSession(
        uint256 sessionId
    ) external nonReentrant {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();

        // 2. Validate session ownership
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();
        if (session.game != msg.sender) revert SessionGameMismatch();
        if (session.state != SessionState.ACTIVE) revert SessionNotActive();

        // 3. Mark as settled
        session.state = SessionState.SETTLED;
        session.settledAt = uint64(block.timestamp);

        // 4. Handle remaining prize pool (unclaimed portion goes to treasury)
        uint256 remaining = session.prizePool - session.totalPaid;
        if (remaining > 0) {
            IERC20(address($.dataToken)).safeTransfer($.treasury, remaining);
        }

        // 5. Remove from active sessions tracking
        _removeActiveSession(msg.sender, sessionId);

        emit SessionSettled(msg.sender, sessionId, session.totalPaid, remaining);
    }

    /// @inheritdoc IArcadeCore
    function cancelSession(
        uint256 sessionId
    ) external nonReentrant {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();

        // 2. Validate session ownership
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();
        if (session.game != msg.sender) revert SessionGameMismatch();
        if (session.state != SessionState.ACTIVE) revert SessionNotActive();

        // 3. Mark as cancelled (allows refunds, blocks payouts)
        session.state = SessionState.CANCELLED;
        session.settledAt = uint64(block.timestamp);

        // 4. Remove from active sessions tracking
        _removeActiveSession(msg.sender, sessionId);

        emit SessionCancelled(msg.sender, sessionId, session.prizePool);
    }

    /// @inheritdoc IArcadeCore
    /// @notice Emergency refund with session-bound security
    /// @dev Implements comprehensive validation (Critical Issue #4):
    ///      1. Game must own the session (prevents cross-game drain attacks)
    ///      2. Session must be in refundable state (CANCELLED only, or ACTIVE for partial refunds)
    ///      3. Amount bounded by player's NET deposit (what's in prize pool)
    ///      4. Double-refund prevention via explicit tracking
    ///
    /// Design Decision: Refunds use NET amount (after rake)
    /// - Rake has already been processed (burned/sent to treasury)
    /// - ArcadeCore must remain solvent at all times
    /// - Players accept rake as cost of playing - same as if they won and cashed out
    /// - Gross deposit tracked for audit trail but net is what's refundable
    function emergencyRefund(
        uint256 sessionId,
        address player,
        uint256 amount
    ) external nonReentrant {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game (Critical: prevents unregistered attacker)
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();

        // 2. Validate session ownership (Critical: prevents cross-game drain)
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();
        if (session.game != msg.sender) revert SessionGameMismatch();

        // 3. Validate session allows refunds
        // - CANCELLED: Always allows refunds (if no payouts made)
        // - ACTIVE: Only if no payouts have been made yet
        // - SETTLED: No refunds - game completed normally
        //
        // CRITICAL: Once ANY payout is made, refunds are blocked to prevent solvency attack
        // Attack vector without this check:
        //   1. Player deposits 100 (95 net after rake)
        //   2. Game credits payout of 50
        //   3. Game calls refund for 95 (original deposit)
        //   4. Player has 145 pending but contract only has 95 tokens = INSOLVENT
        if (session.state == SessionState.SETTLED) revert SessionNotRefundable();
        if (session.totalPaid > 0) revert RefundsBlockedAfterPayouts();

        // 4. Check for double-refund (Critical: prevents drain attack)
        bytes32 depositKey = _depositKey(sessionId, player);
        if ($.sessionRefunded[depositKey]) revert AlreadyRefunded();

        // 5. Validate player has deposit (use gross for existence check)
        uint256 grossDeposit = $.sessionGrossDeposits[depositKey];
        if (grossDeposit == 0) revert NoDepositFound();

        // 6. Get the NET deposit (what's actually refundable)
        uint256 netDeposit = $.sessionDeposits[depositKey];
        if (amount == 0) revert InvalidRefundAmount();
        if (amount > netDeposit) revert RefundExceedsDeposit();

        // 7. Mark as refunded (Critical: prevents double-refund)
        // Note: We mark BEFORE transfer for CEI pattern
        $.sessionRefunded[depositKey] = true;

        // 8. Update deposit tracking
        $.sessionDeposits[depositKey] = netDeposit - amount;
        session.prizePool -= amount;

        // 9. Credit refund to player's pending balance (pull pattern)
        $.pendingPayouts[player] += amount;
        $.totalPendingPayouts += amount;

        emit EmergencyRefund(msg.sender, player, sessionId, amount);
    }

    /// @inheritdoc IArcadeCore
    /// @notice Batch emergency refund for multiple players
    /// @dev Gas efficient: single caller validation, batched transfers
    ///      Refunds each player their full NET deposit (what's in prize pool)
    ///      Silently skips players with no deposit or already refunded
    function batchEmergencyRefund(
        uint256 sessionId,
        address[] calldata players
    ) external nonReentrant {
        uint256 len = players.length;
        if (len == 0) revert EmptyBatch();
        if (len > _MAX_BATCH_SIZE) revert BatchTooLarge(len, _MAX_BATCH_SIZE);

        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Verify caller is registered game
        if (!$.registeredGames[msg.sender]) revert GameNotRegistered();

        // 2. Validate session ownership
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();
        if (session.game != msg.sender) revert SessionGameMismatch();

        // 3. Validate session allows refunds
        // CRITICAL: Block refunds after any payouts to prevent solvency attack
        if (session.state == SessionState.SETTLED) revert SessionNotRefundable();
        if (session.totalPaid > 0) revert RefundsBlockedAfterPayouts();

        uint256 totalRefunded;
        uint256 playersRefunded;

        // 4. Process each player
        for (uint256 i; i < len;) {
            address player = players[i];
            bytes32 depositKey = _depositKey(sessionId, player);

            // Skip if no deposit or already refunded (batch tolerance)
            uint256 grossDeposit = $.sessionGrossDeposits[depositKey];
            if (grossDeposit > 0 && !$.sessionRefunded[depositKey]) {
                // Mark as refunded
                $.sessionRefunded[depositKey] = true;

                // Get NET deposit (what's actually refundable)
                uint256 netDeposit = $.sessionDeposits[depositKey];
                if (netDeposit > 0) {
                    $.sessionDeposits[depositKey] = 0;
                    session.prizePool -= netDeposit;

                    // Credit full NET deposit
                    $.pendingPayouts[player] += netDeposit;
                    totalRefunded += netDeposit;
                }
                playersRefunded++;

                emit EmergencyRefund(msg.sender, player, sessionId, netDeposit);
            }

            unchecked {
                ++i;
            }
        }

        $.totalPendingPayouts += totalRefunded;

        emit BatchEmergencyRefund(msg.sender, sessionId, playersRefunded, totalRefunded);
    }

    /// @inheritdoc IArcadeCore
    /// @notice Self-service refund for cancelled/expired sessions
    /// @dev Permissionless: anyone can call for any player with deposits
    ///      Useful when game contract is unresponsive or compromised
    ///      Session must be CANCELLED (game responsible for marking expired sessions)
    ///      Refunds NET amount (rake already processed)
    function claimExpiredRefund(
        uint256 sessionId,
        address player
    ) external nonReentrant {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        // 1. Session must exist
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.NONE) revert SessionNotFound();

        // 2. Session must be CANCELLED (games cancel when seed expires)
        if (session.state != SessionState.CANCELLED) revert SessionNotRefundable();

        // CRITICAL: Block refunds after any payouts to prevent solvency attack
        // Even for CANCELLED sessions, if payouts were made, refunds would cause insolvency
        if (session.totalPaid > 0) revert RefundsBlockedAfterPayouts();

        // 3. Check for double-refund
        bytes32 depositKey = _depositKey(sessionId, player);
        if ($.sessionRefunded[depositKey]) revert AlreadyRefunded();

        // 4. Verify player has deposit
        uint256 grossDeposit = $.sessionGrossDeposits[depositKey];
        if (grossDeposit == 0) revert NoDepositFound();

        // 5. Mark as refunded
        $.sessionRefunded[depositKey] = true;

        // 6. Get NET deposit and update accounting
        uint256 netDeposit = $.sessionDeposits[depositKey];
        if (netDeposit > 0) {
            $.sessionDeposits[depositKey] = 0;
            session.prizePool -= netDeposit;
        }

        // 8. Credit full NET deposit
        $.pendingPayouts[player] += netDeposit;
        $.totalPendingPayouts += netDeposit;

        emit ExpiredRefundClaimed(player, sessionId, netDeposit);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeCore
    function withdrawPayout() external nonReentrant returns (uint256 amount) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        amount = $.pendingPayouts[msg.sender];
        if (amount == 0) return 0;

        $.pendingPayouts[msg.sender] = 0;
        $.totalPendingPayouts -= amount;

        IERC20(address($.dataToken)).safeTransfer(msg.sender, amount);

        emit PayoutWithdrawn(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pause the entire arcade
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause the arcade
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Emergency quarantine of a compromised game
    /// @param game Game address to quarantine
    /// @dev Pauses game and cancels all its active sessions
    function emergencyQuarantineGame(
        address game
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        if (!$.registeredGames[game]) revert GameNotRegistered();

        // 1. Pause game
        $.gameConfigs[game].paused = true;

        // 2. Get all active sessions for this game
        uint256[] storage activeSessions = $.gameActiveSessions[game];
        uint256 sessionsAffected = activeSessions.length;

        // 3. Cancel all sessions (state only, refunds handled separately)
        for (uint256 i; i < activeSessions.length; ++i) {
            uint256 sessionId = activeSessions[i];
            SessionRecord storage session = $.sessions[sessionId];
            if (session.state == SessionState.ACTIVE) {
                session.state = SessionState.CANCELLED;
                session.settledAt = uint64(block.timestamp);
                emit SessionCancelled(game, sessionId, session.prizePool);
            }
        }

        // 4. Clear active sessions array
        delete $.gameActiveSessions[game];

        emit GameQuarantined(game, sessionsAffected);
    }

    /// @notice Update treasury address
    function setTreasury(
        address newTreasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidAddress();
        _getArcadeCoreStorage().treasury = newTreasury;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeCore
    function getSession(
        uint256 sessionId
    ) external view returns (SessionRecord memory) {
        return _getArcadeCoreStorage().sessions[sessionId];
    }

    /// @inheritdoc IArcadeCore
    function getGameConfig(
        address game
    ) external view returns (GameConfig memory) {
        return _getArcadeCoreStorage().gameConfigs[game];
    }

    /// @inheritdoc IArcadeCore
    function isGameRegistered(
        address game
    ) external view returns (bool) {
        return _getArcadeCoreStorage().registeredGames[game];
    }

    /// @inheritdoc IArcadeCore
    function getSessionDeposit(
        uint256 sessionId,
        address player
    ) external view returns (uint256) {
        return _getArcadeCoreStorage().sessionDeposits[_depositKey(sessionId, player)];
    }

    /// @inheritdoc IArcadeCore
    function getPendingPayout(
        address player
    ) external view returns (uint256) {
        return _getArcadeCoreStorage().pendingPayouts[player];
    }

    /// @inheritdoc IArcadeCore
    function getPlayerStats(
        address player
    ) external view returns (PlayerStats memory) {
        return _getArcadeCoreStorage().playerStats[player];
    }

    /// @notice Get total pending payouts (for solvency checks)
    function getTotalPendingPayouts() external view returns (uint256) {
        return _getArcadeCoreStorage().totalPendingPayouts;
    }

    /// @notice Get global statistics
    function getGlobalStats()
        external
        view
        returns (
            uint256 totalGamesPlayed_,
            uint256 totalVolume_,
            uint256 totalRakeCollected_,
            uint256 totalBurned_
        )
    {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();
        return ($.totalGamesPlayed, $.totalVolume, $.totalRakeCollected, $.totalBurned);
    }

    /// @notice Get player's gross deposit in a session (before rake, for refund bounds)
    /// @param sessionId Session ID
    /// @param player Player address
    /// @return Gross deposit amount
    function getSessionGrossDeposit(
        uint256 sessionId,
        address player
    ) external view returns (uint256) {
        return _getArcadeCoreStorage().sessionGrossDeposits[_depositKey(sessionId, player)];
    }

    /// @notice Check if player has been refunded for a session
    /// @param sessionId Session ID
    /// @param player Player address
    /// @return Whether refund was claimed
    function isRefunded(
        uint256 sessionId,
        address player
    ) external view returns (bool) {
        return _getArcadeCoreStorage().sessionRefunded[_depositKey(sessionId, player)];
    }

    /// @notice Get remaining payout capacity for a session
    /// @param sessionId Session to query
    /// @return remaining Amount still available for payouts (prizePool - totalPaid)
    function getSessionRemainingCapacity(
        uint256 sessionId
    ) external view returns (uint256 remaining) {
        SessionRecord storage session = _getArcadeCoreStorage().sessions[sessionId];
        if (session.prizePool > session.totalPaid) {
            remaining = session.prizePool - session.totalPaid;
        }
    }

    /// @notice Get maximum batch size for batch operations
    /// @return Maximum number of items in a batch operation
    // solhint-disable-next-line func-name-mixedcase
    function MAX_BATCH_SIZE() external pure returns (uint256) {
        return _MAX_BATCH_SIZE;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Remove session from active sessions tracking
    /// @dev Uses swap-and-pop for O(1) removal
    function _removeActiveSession(
        address game,
        uint256 sessionId
    ) internal {
        ArcadeCoreStorageLayout storage $ = _getArcadeCoreStorage();

        uint256[] storage activeSessions = $.gameActiveSessions[game];
        uint256 index = $.sessionIndex[sessionId];

        if (activeSessions.length > 0 && index < activeSessions.length) {
            // Swap with last and pop
            uint256 lastSessionId = activeSessions[activeSessions.length - 1];
            activeSessions[index] = lastSessionId;
            $.sessionIndex[lastSessionId] = index;
            activeSessions.pop();
        }

        delete $.sessionIndex[sessionId];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UPGRADE AUTHORIZATION
    // ══════════════════════════════════════════════════════════════════════════════

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
