// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IArcadeGame } from "../interfaces/IArcadeGame.sol";
import { IArcadeTypes } from "../interfaces/IArcadeTypes.sol";
import { IArcadeCore } from "../interfaces/IArcadeCore.sol";
import { FutureBlockRandomness } from "../../randomness/FutureBlockRandomness.sol";

/// @title HashCrash
/// @notice A "crash" style multiplier game for GHOSTNET Arcade
/// @dev Players bet before a round starts. A multiplier grows from 1.00x and "crashes"
///      at a random point determined by the block hash. Players must cash out before
///      the crash to win their bet multiplied by their cashout multiplier.
///
///      GAME FLOW:
///      1. BETTING: Players place bets (60 second window or max players)
///      2. LOCKED: Betting closed, seed block committed (~1 sec wait on MegaETH)
///      3. ACTIVE: Seed revealed, crash point known, players can cash out
///      4. SETTLED: All players resolved (cashed out or crashed)
///
///      SECURITY MODEL:
///      - All tokens held by ArcadeCore, not this contract
///      - Payouts bounded by session prize pool
///      - Future block randomness prevents manipulation
///      - Emergency refunds for expired seeds
///
///      HOUSE EDGE:
///      - Expected value is ~96% (4% house edge built into crash curve)
///      - Additional rake handled by ArcadeCore on entry
///
/// @custom:security-contact security@ghostnet.game
contract HashCrash is IArcadeGame, FutureBlockRandomness, Ownable2Step, Pausable, ReentrancyGuard {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Multiplier precision (2 decimals, e.g., 150 = 1.50x)
    uint256 public constant MULTIPLIER_PRECISION = 100;

    /// @notice Minimum crash point (1.00x = instant crash)
    uint256 public constant MIN_CRASH_MULTIPLIER = 100;

    /// @notice Maximum crash point (100.00x)
    uint256 public constant MAX_CRASH_MULTIPLIER = 10_000;

    /// @notice Duration of betting phase
    uint256 public constant BETTING_DURATION = 60 seconds;

    /// @notice Maximum players per round
    uint256 public constant MAX_PLAYERS_PER_ROUND = 50;

    /// @notice Blocks to wait for seed (overrides FutureBlockRandomness default)
    /// @dev 10 blocks = ~1 second on MegaETH. Good balance of security and UX for crash games.
    uint256 public constant HASH_CRASH_SEED_DELAY = 10;

    /// @notice House edge in basis points (400 = 4%)
    /// @dev This creates ~96% expected value for players
    uint256 public constant HOUSE_EDGE_BPS = 400;

    /// @notice Basis points denominator
    uint256 private constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Round is not accepting bets
    error BettingClosed();

    /// @notice Player has not placed a bet in this round
    error NoBetPlaced();

    /// @notice Player already cashed out
    error AlreadyCashedOut();

    /// @notice Crash point has already been reached
    error AlreadyCrashed();

    /// @notice Invalid cashout multiplier
    error InvalidCashoutMultiplier();

    /// @notice Round is full (max players reached)
    error RoundFull();

    /// @notice Round not ready for resolution
    error RoundNotReady();

    /// @notice Cannot start new round while one is active
    error RoundInProgress();

    /// @notice Betting phase not yet ended
    error BettingNotEnded();

    /// @notice Invalid ArcadeCore address
    error InvalidArcadeCore();

    /// @notice Invalid address (zero address)
    error InvalidAddress();

    /// @notice Player bet amount is zero
    error ZeroBetAmount();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a player cashes out
    event CashOut(
        uint256 indexed roundId,
        address indexed player,
        uint256 betAmount,
        uint256 cashoutMultiplier,
        uint256 payout
    );

    /// @notice Emitted when the crash point is revealed
    event CrashPoint(uint256 indexed roundId, uint256 crashMultiplier, uint256 seed);

    /// @notice Emitted when a player crashes (didn't cash out in time)
    event PlayerCrashed(
        uint256 indexed roundId, address indexed player, uint256 betAmount, uint256 crashMultiplier
    );

    /// @notice Emitted when game active status changes
    event GameActiveStatusChanged(bool isActive);

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Reference to ArcadeCore
    IArcadeCore public immutable arcadeCore;

    /// @notice Game metadata
    GameInfo private _gameInfo;

    /// @notice Current round ID (increments each round)
    uint256 private _currentRoundId;

    /// @notice Round state
    struct Round {
        SessionState state;
        uint64 bettingEndTime;
        uint256 prizePool;
        uint256 crashMultiplier; // 0 until revealed
        uint256 totalPaidOut;
        uint256 playerCount;
    }

    /// @notice Round data by ID
    mapping(uint256 roundId => Round) private _rounds;

    /// @notice Player bet in a round
    struct PlayerBet {
        uint128 amount; // Bet amount (net after rake)
        uint128 grossAmount; // Original bet (before rake, for refunds)
        uint64 cashedOutAt; // Multiplier at cashout (0 = not cashed out)
        bool resolved; // True if payout/crash has been processed
    }

    /// @notice Player bets by round
    mapping(uint256 roundId => mapping(address player => PlayerBet)) private _playerBets;

    /// @notice List of players in a round (for iteration)
    mapping(uint256 roundId => address[]) private _roundPlayers;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Initialize HashCrash game
    /// @param _arcadeCore Address of ArcadeCore contract
    /// @param _owner Initial owner (admin)
    constructor(
        address _arcadeCore,
        address _owner
    ) Ownable(_owner) {
        if (_arcadeCore == address(0)) revert InvalidArcadeCore();
        if (_owner == address(0)) revert InvalidAddress();

        arcadeCore = IArcadeCore(_arcadeCore);

        _gameInfo = GameInfo({
            gameId: keccak256("HASH_CRASH"),
            name: "Hash Crash",
            description: "Multiplier crash game - cash out before the crash!",
            category: GameCategory.CASINO,
            minPlayers: 1,
            maxPlayers: uint8(MAX_PLAYERS_PER_ROUND),
            isActive: true,
            launchedAt: uint64(block.timestamp)
        });

        // NOTE: This contract doesn't hold tokens. ArcadeCore pulls directly from players.
        // Players must approve ArcadeCore, not this game contract.
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Place a bet in the current round
    /// @dev Transfers DATA from player to ArcadeCore via processEntry
    /// @param amount Bet amount in DATA tokens
    function placeBet(
        uint256 amount
    ) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroBetAmount();

        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        // Must be in betting phase
        if (round.state != SessionState.BETTING) revert BettingClosed();
        if (block.timestamp >= round.bettingEndTime) revert BettingClosed();
        if (round.playerCount >= MAX_PLAYERS_PER_ROUND) revert RoundFull();

        // Check if player already bet
        if (_playerBets[roundId][msg.sender].amount > 0) revert PlayerAlreadyInSession();

        // NOTE: Player must have approved ArcadeCore (not this game contract)
        // ArcadeCore.processEntry handles:
        // - Rake collection
        // - Session tracking
        // - Player statistics
        uint256 netAmount = arcadeCore.processEntry(msg.sender, amount, roundId);

        // Record player bet
        _playerBets[roundId][msg.sender] = PlayerBet({
            amount: uint128(netAmount),
            grossAmount: uint128(amount),
            cashedOutAt: 0,
            resolved: false
        });
        _roundPlayers[roundId].push(msg.sender);

        round.prizePool += netAmount;
        round.playerCount++;

        emit BetPlaced(roundId, msg.sender, amount, netAmount);

        // Auto-lock if max players reached
        if (round.playerCount >= MAX_PLAYERS_PER_ROUND) {
            _lockRound(roundId);
        }
    }

    /// @notice Cash out at current multiplier
    /// @dev Only callable when round is ACTIVE (crash point known)
    /// @param multiplier The multiplier to cash out at (must be < crash point)
    function cashOut(
        uint256 multiplier
    ) external nonReentrant whenNotPaused {
        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        // Must be in active phase
        if (round.state != SessionState.ACTIVE) revert InvalidSessionState();

        // Check player has a bet first (more informative error)
        PlayerBet storage bet = _playerBets[roundId][msg.sender];
        if (bet.amount == 0) revert NoBetPlaced();
        if (bet.cashedOutAt > 0) revert AlreadyCashedOut();
        if (bet.resolved) revert AlreadyCashedOut();

        // Validate multiplier
        if (multiplier < MIN_CRASH_MULTIPLIER) revert InvalidCashoutMultiplier();
        if (multiplier >= round.crashMultiplier) revert AlreadyCrashed();

        // Calculate payout
        uint256 payout = (uint256(bet.amount) * multiplier) / MULTIPLIER_PRECISION;

        // Record cashout
        bet.cashedOutAt = uint64(multiplier);
        bet.resolved = true;
        round.totalPaidOut += payout;

        // Credit payout via ArcadeCore
        arcadeCore.creditPayout(roundId, msg.sender, payout, 0, true);

        emit CashOut(roundId, msg.sender, bet.amount, multiplier, payout);
        emit PlayerPaidOut(roundId, msg.sender, payout, true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Start a new betting round
    /// @dev Anyone can call this when no round is active
    function startRound() external nonReentrant whenNotPaused {
        // Check no active round
        Round storage currentRound = _rounds[_currentRoundId];
        if (
            currentRound.state != SessionState.NONE && currentRound.state != SessionState.SETTLED
                && currentRound.state != SessionState.CANCELLED
                && currentRound.state != SessionState.EXPIRED
        ) {
            revert RoundInProgress();
        }

        // Increment round ID
        uint256 roundId;
        unchecked {
            roundId = ++_currentRoundId;
        }

        // Initialize round
        _rounds[roundId] = Round({
            state: SessionState.BETTING,
            bettingEndTime: uint64(block.timestamp + BETTING_DURATION),
            prizePool: 0,
            crashMultiplier: 0,
            totalPaidOut: 0,
            playerCount: 0
        });

        emit RoundStarted(roundId, 0, uint64(block.timestamp));
    }

    /// @notice Lock betting and commit to seed block
    /// @dev Called when betting ends (timeout or max players)
    function lockRound() external nonReentrant whenNotPaused {
        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        if (round.state != SessionState.BETTING) revert InvalidSessionState();
        if (block.timestamp < round.bettingEndTime && round.playerCount < MAX_PLAYERS_PER_ROUND) {
            revert BettingNotEnded();
        }

        _lockRound(roundId);
    }

    /// @notice Reveal the crash point and enter active phase
    /// @dev Anyone can call once seed block is mined
    function revealCrash() external nonReentrant whenNotPaused {
        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        if (round.state != SessionState.LOCKED) revert InvalidSessionState();

        // Try to reveal seed
        uint256 seed = _revealSeed(roundId);

        // Calculate crash multiplier using house edge
        uint256 crashMultiplier = _calculateCrashPoint(seed);
        round.crashMultiplier = crashMultiplier;
        round.state = SessionState.ACTIVE;

        emit CrashPoint(roundId, crashMultiplier, seed);
        emit RoundResolved(roundId, seed, crashMultiplier);
    }

    /// @notice Resolve all players who didn't cash out (they crashed)
    /// @dev Marks losing players and settles the round
    function resolveRound() external nonReentrant {
        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        if (round.state != SessionState.ACTIVE) revert InvalidSessionState();

        address[] storage players = _roundPlayers[roundId];
        uint256 len = players.length;

        for (uint256 i; i < len;) {
            address player = players[i];
            PlayerBet storage bet = _playerBets[roundId][player];

            if (!bet.resolved) {
                // Player didn't cash out - they crashed
                bet.resolved = true;

                // Record loss via ArcadeCore (0 payout, burn the bet)
                arcadeCore.creditPayout(roundId, player, 0, bet.amount, false);

                emit PlayerCrashed(roundId, player, bet.amount, round.crashMultiplier);
                emit PlayerPaidOut(roundId, player, 0, false);
            }

            unchecked {
                ++i;
            }
        }

        // Settle the session
        round.state = SessionState.SETTLED;
        arcadeCore.settleSession(roundId);
    }

    /// @notice Handle expired seed by cancelling and refunding
    /// @dev Called when seed block expires without reveal
    function handleExpiredRound() external nonReentrant {
        uint256 roundId = _currentRoundId;
        Round storage round = _rounds[roundId];

        if (round.state != SessionState.LOCKED) revert InvalidSessionState();
        if (!_isSeedExpired(roundId)) revert RoundNotReady();

        // Mark as expired
        round.state = SessionState.EXPIRED;

        // Cancel session via ArcadeCore
        arcadeCore.cancelSession(roundId);

        emit RoundCancelled(roundId, "Seed expired");
    }

    /// @notice Claim refund for an expired round
    /// @dev Anyone can call for any player with a bet in an expired round.
    ///      Delegates to ArcadeCore's permissionless claimExpiredRefund which
    ///      refunds the NET deposit amount (after rake).
    ///
    ///      NOTE: Players can also call arcadeCore.claimExpiredRefund directly
    ///      once the session is CANCELLED. This function is a convenience wrapper.
    ///
    /// @param roundId The expired round
    /// @param player The player to refund
    function claimExpiredRefund(
        uint256 roundId,
        address player
    ) external nonReentrant {
        Round storage round = _rounds[roundId];

        // Must be expired or cancelled
        if (round.state != SessionState.EXPIRED && round.state != SessionState.CANCELLED) {
            revert InvalidSessionState();
        }

        PlayerBet storage bet = _playerBets[roundId][player];
        if (bet.grossAmount == 0) revert NoBetPlaced();
        if (bet.resolved) revert AlreadyCashedOut();

        // Mark as resolved in game state
        bet.resolved = true;

        // Use ArcadeCore's permissionless refund (refunds NET deposit)
        // This handles all the accounting and prevents double-refunds
        arcadeCore.claimExpiredRefund(roundId, player);

        // Note: ArcadeCore emits ExpiredRefundClaimed with the net amount
        emit PlayerPaidOut(roundId, player, bet.amount, false);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Lock the round and commit seed
    /// @param roundId Round to lock
    function _lockRound(
        uint256 roundId
    ) internal {
        Round storage round = _rounds[roundId];

        // No bets = cancel the round
        if (round.playerCount == 0) {
            round.state = SessionState.CANCELLED;
            emit RoundCancelled(roundId, "No bets placed");
            return;
        }

        round.state = SessionState.LOCKED;
        _commitSeed(roundId);

        // Get seed info for event
        FutureBlockRandomness.RoundSeed memory seedInfo = _getRoundSeedInfo(roundId);
        emit RoundStarted(roundId, seedInfo.seedBlock, uint64(block.timestamp));
    }

    /// @notice Get seed block delay for HashCrash
    /// @dev 10 blocks = ~1 second on MegaETH for fast game flow
    function _seedBlockDelay() internal pure override returns (uint256) {
        return HASH_CRASH_SEED_DELAY;
    }

    /// @notice Calculate crash point from seed
    /// @dev Uses standard crash game formula with house edge.
    ///
    ///      MATHEMATICAL BASIS:
    ///      The standard crash game formula is: multiplier = 1 / (1 - r)
    ///      where r is uniformly distributed in [0, 1).
    ///      This gives P(crash > x) = 1/x for x >= 1 (inverse distribution).
    ///
    ///      With house edge applied:
    ///      - 4% of rounds crash instantly at 1.00x (guaranteed house win)
    ///      - Remaining 96% follow the inverse distribution
    ///
    ///      EXPECTED DISTRIBUTION:
    ///      - ~4% instant crash (1.00x) - house edge
    ///      - ~50% crash below 2.00x
    ///      - ~10% reach 10.00x
    ///      - ~1% reach 100.00x
    ///
    ///      PRECISION:
    ///      - We use 52 bits of the seed for ~4.5 quadrillion distinct values
    ///      - Output scaled by MULTIPLIER_PRECISION (100 = 1.00x)
    ///
    /// @param seed The random seed
    /// @return crashMultiplier The crash point (100 = 1.00x, 200 = 2.00x, etc.)
    function _calculateCrashPoint(
        uint256 seed
    ) internal pure returns (uint256 crashMultiplier) {
        // Use lower 52 bits for uniform distribution in [0, 2^52)
        uint256 h = seed & ((1 << 52) - 1);

        // House edge: 4% of rounds crash at 1.00x (instant loss)
        // Check if h falls in the bottom 4% of the range
        uint256 houseEdgeThreshold = ((1 << 52) * HOUSE_EDGE_BPS) / BPS;
        if (h < houseEdgeThreshold) {
            return MIN_CRASH_MULTIPLIER; // 1.00x
        }

        // Standard crash formula: multiplier = 1 / (1 - r)
        // where r = h / 2^52 (normalized to [0, 1))
        //
        // Rearranged for integer math:
        // multiplier = 2^52 / (2^52 - h)
        //
        // To get the expected distribution with house edge already applied above,
        // we use: multiplier = (2^52 - houseEdgeThreshold) / (2^52 - h)
        //
        // This ensures that after the house edge check:
        // - h = houseEdgeThreshold maps to multiplier ~= 1.00x
        // - h approaching 2^52 maps to very high multipliers

        uint256 maxH = (1 << 52);
        uint256 effectiveRange = maxH - houseEdgeThreshold; // Range after house edge
        uint256 divisor = maxH - h; // Distance from max

        // Prevent division by zero (h can equal maxH - 1 at most due to mask)
        if (divisor == 0) {
            return MAX_CRASH_MULTIPLIER;
        }

        // Calculate multiplier: (effectiveRange / divisor) * MULTIPLIER_PRECISION
        // We multiply first to preserve precision, then divide
        // Safe from overflow: effectiveRange < 2^52, MULTIPLIER_PRECISION = 100
        crashMultiplier = (effectiveRange * MULTIPLIER_PRECISION) / divisor;

        // Clamp to valid range
        if (crashMultiplier < MIN_CRASH_MULTIPLIER) {
            crashMultiplier = MIN_CRASH_MULTIPLIER;
        } else if (crashMultiplier > MAX_CRASH_MULTIPLIER) {
            crashMultiplier = MAX_CRASH_MULTIPLIER;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - IArcadeGame
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeGame
    function getGameInfo() external view override returns (GameInfo memory info) {
        return _gameInfo;
    }

    /// @inheritdoc IArcadeGame
    function gameId() external view override returns (bytes32 id) {
        return _gameInfo.gameId;
    }

    /// @inheritdoc IArcadeGame
    function currentSessionId() external view override returns (uint256 id) {
        return _currentRoundId;
    }

    /// @inheritdoc IArcadeGame
    function getSessionState(
        uint256 sessionId
    ) external view override returns (SessionState state) {
        return _rounds[sessionId].state;
    }

    /// @inheritdoc IArcadeGame
    function isPlayerInSession(
        uint256 sessionId,
        address player
    ) external view override returns (bool inSession) {
        return _playerBets[sessionId][player].amount > 0;
    }

    /// @inheritdoc IArcadeGame
    function getSessionPrizePool(
        uint256 sessionId
    ) external view override returns (uint256 prizePool) {
        return _rounds[sessionId].prizePool;
    }

    /// @inheritdoc IArcadeGame
    function isPaused() external view override returns (bool) {
        return paused();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - GAME SPECIFIC
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get round information
    /// @param roundId Round to query
    /// @return round The round data
    function getRound(
        uint256 roundId
    ) external view returns (Round memory round) {
        return _rounds[roundId];
    }

    /// @notice Get player bet in a round
    /// @param roundId Round to query
    /// @param player Player address
    /// @return bet The player's bet data
    function getPlayerBet(
        uint256 roundId,
        address player
    ) external view returns (PlayerBet memory bet) {
        return _playerBets[roundId][player];
    }

    /// @notice Get all players in a round
    /// @param roundId Round to query
    /// @return players Array of player addresses
    function getRoundPlayers(
        uint256 roundId
    ) external view returns (address[] memory players) {
        return _roundPlayers[roundId];
    }

    /// @notice Get seed information for a round
    /// @param roundId Round to query
    /// @return seedInfo The seed data
    function getSeedInfo(
        uint256 roundId
    ) external view returns (FutureBlockRandomness.RoundSeed memory seedInfo) {
        return _getRoundSeedInfo(roundId);
    }

    /// @notice Check if seed is ready for reveal
    /// @param roundId Round to check
    /// @return ready True if seed can be revealed
    function isSeedReady(
        uint256 roundId
    ) external view returns (bool ready) {
        return _isSeedReady(roundId);
    }

    /// @notice Check if seed has expired
    /// @param roundId Round to check
    /// @return expired True if seed is expired
    function isSeedExpired(
        uint256 roundId
    ) external view returns (bool expired) {
        return _isSeedExpired(roundId);
    }

    /// @notice Get remaining blocks before seed expires
    /// @param roundId Round to check
    /// @return remaining Blocks remaining
    function getRemainingRevealWindow(
        uint256 roundId
    ) external view returns (uint256 remaining) {
        return _getRemainingRevealWindow(roundId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeGame
    function pause() external override onlyOwner {
        _pause();
    }

    /// @inheritdoc IArcadeGame
    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @inheritdoc IArcadeGame
    function emergencyCancel(
        uint256 sessionId,
        string calldata reason
    ) external override onlyOwner {
        Round storage round = _rounds[sessionId];

        // Cannot cancel non-existent or already terminal rounds
        if (round.state == SessionState.NONE) {
            revert SessionDoesNotExist();
        }
        if (
            round.state == SessionState.SETTLED || round.state == SessionState.CANCELLED
                || round.state == SessionState.EXPIRED
        ) {
            revert InvalidSessionState();
        }

        // Mark as cancelled
        round.state = SessionState.CANCELLED;

        // Cancel session in ArcadeCore
        arcadeCore.cancelSession(sessionId);

        emit RoundCancelled(sessionId, reason);
    }

    /// @notice Update game active status
    /// @param active Whether game should be active
    function setActive(
        bool active
    ) external onlyOwner {
        _gameInfo.isActive = active;
        emit GameActiveStatusChanged(active);
    }
}
