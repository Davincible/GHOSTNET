// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IArcadeGame } from "../interfaces/IArcadeGame.sol";
import { IArcadeTypes } from "../interfaces/IArcadeTypes.sol";
import { IArcadeCore } from "../interfaces/IArcadeCore.sol";

/// @title DuelEscrow
/// @notice 1v1 competitive typing battles with wager escrow for GHOSTNET Arcade
/// @dev Players are matched by the off-chain matchmaking service, then join matches
///      on-chain by locking their wagers. Results are submitted by an authorized oracle.
///
///      GAME FLOW:
///      1. CREATED: Match created by matchmaker (backend), players invited
///      2. WAITING: Player 1 joins, locks wager
///      3. ACTIVE: Player 2 joins, match starts (typing battle happens off-chain)
///      4. RESOLVED: Oracle submits winner, payouts credited
///
///      SECURITY MODEL:
///      - All tokens held by ArcadeCore, not this contract
///      - Oracle must be trusted (backend service with signing key)
///      - Match expiry prevents griefing (locked funds auto-refund)
///      - Players can only join matches they were invited to
///
///      ECONOMICS:
///      - 10% rake on entry (configured in ArcadeCore)
///      - Winner takes 90% of pot (both net entries after rake)
///      - Tie: Each player gets 45% (10% burned)
///      - Forfeit: Non-forfeiter gets 100% of opponent's stake
///
/// @custom:security-contact security@ghostnet.game
contract DuelEscrow is IArcadeGame, Ownable2Step, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Stake tiers in DATA tokens (with 18 decimals)
    uint256 public constant BRONZE_STAKE = 50 ether;
    uint256 public constant SILVER_STAKE = 150 ether;
    uint256 public constant GOLD_STAKE = 300 ether;
    uint256 public constant DIAMOND_STAKE = 500 ether;

    /// @notice Time before unstarted match expires and can be refunded
    uint256 public constant MATCH_EXPIRY = 5 minutes;

    /// @notice Time before active match times out (no result submitted)
    uint256 public constant MATCH_TIMEOUT = 3 minutes;

    /// @notice Basis points denominator
    uint256 private constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Match doesn't exist
    error MatchNotFound();

    /// @notice Match is not in expected state
    error InvalidMatchState();

    /// @notice Caller is not authorized for this action
    error Unauthorized();

    /// @notice Player not invited to this match
    error NotInvited();

    /// @notice Player already joined this match
    error AlreadyJoined();

    /// @notice Invalid stake tier
    error InvalidStakeTier();

    /// @notice Match not expired (cannot refund yet)
    error MatchNotExpired();

    /// @notice Invalid oracle signature
    error InvalidSignature();

    /// @notice Invalid winner (not a participant)
    error InvalidWinner();

    /// @notice Match still in progress (not timed out)
    error MatchNotTimedOut();

    /// @notice Invalid address (zero address)
    error InvalidAddress();

    /// @notice Nonce already used
    error NonceAlreadyUsed();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a match is created by the matchmaker
    event MatchCreated(
        uint256 indexed matchId,
        address indexed player1,
        address indexed player2,
        uint256 stakeTier,
        uint64 expiresAt
    );

    /// @notice Emitted when a player joins a match
    event PlayerJoined(uint256 indexed matchId, address indexed player, uint256 netAmount);

    /// @notice Emitted when a match becomes active (both players joined)
    event MatchStarted(uint256 indexed matchId, uint256 prizePool, uint64 timeoutAt);

    /// @notice Emitted when a match is resolved
    event MatchResolved(
        uint256 indexed matchId,
        address indexed winner,
        uint256 winnerPayout,
        MatchOutcome outcome
    );

    /// @notice Emitted when a match is cancelled/refunded
    event MatchCancelled(uint256 indexed matchId, string reason);

    /// @notice Emitted when oracle address is updated
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Match states
    enum MatchState {
        NONE,       // 0 - Match doesn't exist
        CREATED,    // 1 - Created, waiting for players
        WAITING,    // 2 - One player joined
        ACTIVE,     // 3 - Both players joined, game in progress
        RESOLVED,   // 4 - Winner determined, payouts done
        CANCELLED   // 5 - Cancelled/expired, refunds issued
    }

    /// @notice Match outcome types
    enum MatchOutcome {
        NONE,       // 0 - Not resolved
        WIN,        // 1 - Clear winner
        TIE,        // 2 - Both players tied
        FORFEIT,    // 3 - One player forfeited/disconnected
        TIMEOUT     // 4 - Match timed out (no result)
    }

    /// @notice Stake tier enum for validation
    enum StakeTier {
        BRONZE,     // 50 DATA
        SILVER,     // 150 DATA
        GOLD,       // 300 DATA
        DIAMOND     // 500 DATA
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Match data
    struct Match {
        address player1;            // First invited player
        address player2;            // Second invited player
        uint128 stake;              // Stake per player (gross, before rake)
        uint128 prizePool;          // Total prize pool (net, after rake)
        uint128 player1Net;         // Player 1's net contribution (for refunds)
        uint128 player2Net;         // Player 2's net contribution (for refunds)
        MatchState state;           // Current state
        StakeTier tier;             // Stake tier
        uint64 createdAt;           // Creation timestamp
        uint64 expiresAt;           // Expiry for joining (if not active)
        uint64 timeoutAt;           // Timeout for result submission (if active)
        address winner;             // Winner address (address(0) if tie/cancelled)
        MatchOutcome outcome;       // How match ended
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Reference to ArcadeCore
    IArcadeCore public immutable arcadeCore;

    /// @notice Oracle address for result submission
    address public oracle;

    /// @notice Game metadata
    GameInfo private _gameInfo;

    /// @notice Current match counter (also serves as match ID)
    uint256 private _matchCounter;

    /// @notice Match data by ID
    mapping(uint256 matchId => Match) private _matches;

    /// @notice Used nonces for oracle signatures (prevent replay)
    mapping(bytes32 => bool) private _usedNonces;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Initialize DuelEscrow game
    /// @param _arcadeCore Address of ArcadeCore contract
    /// @param _oracle Address of the oracle (backend signer)
    /// @param _owner Initial owner (admin)
    constructor(
        address _arcadeCore,
        address _oracle,
        address _owner
    ) Ownable(_owner) {
        if (_arcadeCore == address(0)) revert InvalidAddress();
        if (_oracle == address(0)) revert InvalidAddress();
        if (_owner == address(0)) revert InvalidAddress();

        arcadeCore = IArcadeCore(_arcadeCore);
        oracle = _oracle;

        _gameInfo = GameInfo({
            gameId: keccak256("CODE_DUEL"),
            name: "Code Duel",
            description: "1v1 typing battles - race to type code faster than your opponent",
            category: GameCategory.COMPETITIVE,
            minPlayers: 2,
            maxPlayers: 2,
            isActive: true,
            launchedAt: uint64(block.timestamp)
        });
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // MATCHMAKER FUNCTIONS (Oracle/Backend)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Create a match between two players
    /// @dev Called by the matchmaking backend when players are paired.
    ///      Players must then call joinMatch() to lock their wagers.
    /// @param player1 First player address
    /// @param player2 Second player address
    /// @param tier Stake tier for this match
    /// @param signature Oracle signature authorizing match creation
    /// @param nonce Unique nonce for this creation (prevents replay)
    /// @return matchId The created match ID
    function createMatch(
        address player1,
        address player2,
        StakeTier tier,
        bytes calldata signature,
        bytes32 nonce
    ) external nonReentrant whenNotPaused returns (uint256 matchId) {
        if (player1 == address(0) || player2 == address(0)) revert InvalidAddress();
        if (player1 == player2) revert InvalidAddress();

        // Verify nonce not used
        if (_usedNonces[nonce]) revert NonceAlreadyUsed();
        _usedNonces[nonce] = true;

        // Verify oracle signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            "CREATE_MATCH",
            player1,
            player2,
            uint8(tier),
            nonce,
            block.chainid,
            address(this)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);
        if (signer != oracle) revert InvalidSignature();

        // Get stake amount for tier
        uint256 stake = _getStakeAmount(tier);

        // Create match
        unchecked {
            matchId = ++_matchCounter;
        }

        uint64 expiresAt = uint64(block.timestamp + MATCH_EXPIRY);

        _matches[matchId] = Match({
            player1: player1,
            player2: player2,
            stake: uint128(stake),
            prizePool: 0,
            player1Net: 0,
            player2Net: 0,
            state: MatchState.CREATED,
            tier: tier,
            createdAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            timeoutAt: 0,
            winner: address(0),
            outcome: MatchOutcome.NONE
        });

        emit MatchCreated(matchId, player1, player2, stake, expiresAt);
        emit RoundStarted(matchId, 0, uint64(block.timestamp));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Join a match and lock wager
    /// @dev Player must be invited to this match. Wager is transferred to ArcadeCore.
    /// @param matchId Match to join
    function joinMatch(uint256 matchId) external nonReentrant whenNotPaused {
        Match storage m = _matches[matchId];

        // Validate match exists and is joinable
        if (m.state == MatchState.NONE) revert MatchNotFound();
        if (m.state != MatchState.CREATED && m.state != MatchState.WAITING) {
            revert InvalidMatchState();
        }
        if (block.timestamp >= m.expiresAt) revert MatchNotExpired();

        // Validate caller is invited
        bool isPlayer1 = msg.sender == m.player1;
        bool isPlayer2 = msg.sender == m.player2;
        if (!isPlayer1 && !isPlayer2) revert NotInvited();

        // Check not already joined
        if (isPlayer1 && m.player1Net > 0) revert AlreadyJoined();
        if (isPlayer2 && m.player2Net > 0) revert AlreadyJoined();

        // Process entry through ArcadeCore
        uint256 netAmount = arcadeCore.processEntry(msg.sender, m.stake, matchId);

        // Record contribution
        if (isPlayer1) {
            m.player1Net = uint128(netAmount);
        } else {
            m.player2Net = uint128(netAmount);
        }
        m.prizePool += uint128(netAmount);

        emit PlayerJoined(matchId, msg.sender, netAmount);
        emit BetPlaced(matchId, msg.sender, m.stake, netAmount);

        // Check if match should start
        if (m.state == MatchState.CREATED) {
            // First player joined
            m.state = MatchState.WAITING;
        } else if (m.state == MatchState.WAITING) {
            // Second player joined - match starts
            m.state = MatchState.ACTIVE;
            m.timeoutAt = uint64(block.timestamp + MATCH_TIMEOUT);

            emit MatchStarted(matchId, m.prizePool, m.timeoutAt);
        }
    }

    /// @notice Submit match result (oracle only)
    /// @dev Called by backend after the typing battle concludes.
    /// @param matchId Match to resolve
    /// @param winner Winner address (address(0) for tie)
    /// @param outcome How the match ended
    /// @param signature Oracle signature
    /// @param nonce Unique nonce
    function submitResult(
        uint256 matchId,
        address winner,
        MatchOutcome outcome,
        bytes calldata signature,
        bytes32 nonce
    ) external nonReentrant {
        Match storage m = _matches[matchId];

        // Validate match state
        if (m.state != MatchState.ACTIVE) revert InvalidMatchState();

        // Verify nonce
        if (_usedNonces[nonce]) revert NonceAlreadyUsed();
        _usedNonces[nonce] = true;

        // Verify oracle signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            "SUBMIT_RESULT",
            matchId,
            winner,
            uint8(outcome),
            nonce,
            block.chainid,
            address(this)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);
        if (signer != oracle) revert InvalidSignature();

        // Validate winner
        if (outcome == MatchOutcome.WIN || outcome == MatchOutcome.FORFEIT) {
            if (winner != m.player1 && winner != m.player2) revert InvalidWinner();
        }

        // Process result
        _resolveMatch(matchId, m, winner, outcome);
    }

    /// @notice Claim refund for expired/cancelled match
    /// @param matchId Match to refund from
    function claimRefund(uint256 matchId) external nonReentrant {
        Match storage m = _matches[matchId];

        // Check if match can be refunded
        if (m.state == MatchState.NONE) revert MatchNotFound();
        
        // Can refund if:
        // 1. Match expired before both joined
        // 2. Active match timed out without result
        // 3. Match already cancelled
        
        bool canRefund = false;
        
        if (m.state == MatchState.CANCELLED) {
            canRefund = true;
        } else if (m.state == MatchState.CREATED || m.state == MatchState.WAITING) {
            if (block.timestamp >= m.expiresAt) {
                canRefund = true;
                m.state = MatchState.CANCELLED;
                arcadeCore.cancelSession(matchId);
                emit MatchCancelled(matchId, "Match expired");
                emit RoundCancelled(matchId, "Match expired");
            }
        } else if (m.state == MatchState.ACTIVE) {
            if (block.timestamp >= m.timeoutAt) {
                canRefund = true;
                m.state = MatchState.CANCELLED;
                arcadeCore.cancelSession(matchId);
                emit MatchCancelled(matchId, "Match timed out");
                emit RoundCancelled(matchId, "Match timed out");
            }
        }

        if (!canRefund) revert MatchNotExpired();

        // Issue refund to caller if they have a stake
        bool isPlayer1 = msg.sender == m.player1;
        bool isPlayer2 = msg.sender == m.player2;
        
        if (isPlayer1 && m.player1Net > 0) {
            uint256 refundAmount = m.player1Net;
            m.player1Net = 0;
            arcadeCore.claimExpiredRefund(matchId, msg.sender);
            emit PlayerPaidOut(matchId, msg.sender, refundAmount, false);
        } else if (isPlayer2 && m.player2Net > 0) {
            uint256 refundAmount = m.player2Net;
            m.player2Net = 0;
            arcadeCore.claimExpiredRefund(matchId, msg.sender);
            emit PlayerPaidOut(matchId, msg.sender, refundAmount, false);
        } else {
            revert Unauthorized();
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Resolve match and distribute payouts
    function _resolveMatch(
        uint256 matchId,
        Match storage m,
        address winner,
        MatchOutcome outcome
    ) internal {
        m.state = MatchState.RESOLVED;
        m.winner = winner;
        m.outcome = outcome;

        uint256 prizePool = m.prizePool;

        if (outcome == MatchOutcome.TIE) {
            // Split ~45/45, 10% additional burn on tie
            uint256 burnAmount = prizePool / 10; // 10%
            uint256 remaining = prizePool - burnAmount;
            uint256 payout1 = remaining / 2;
            uint256 payout2 = remaining - payout1; // handles rounding
            uint256 burn1 = burnAmount / 2;
            uint256 burn2 = burnAmount - burn1;

            // Credit both players (total payout + burn must equal prizePool)
            arcadeCore.creditPayout(matchId, m.player1, payout1, burn1, false);
            arcadeCore.creditPayout(matchId, m.player2, payout2, burn2, false);

            emit PlayerPaidOut(matchId, m.player1, payout1, false);
            emit PlayerPaidOut(matchId, m.player2, payout2, false);
            emit MatchResolved(matchId, address(0), payout1, outcome);

        } else if (outcome == MatchOutcome.WIN || outcome == MatchOutcome.FORFEIT) {
            // Winner takes all
            address loser = winner == m.player1 ? m.player2 : m.player1;

            // Winner gets entire prize pool (which includes loser's contribution)
            // Loser gets nothing - their tokens are now the winner's winnings
            arcadeCore.creditPayout(matchId, winner, prizePool, 0, true);
            // Record loss for loser (0 payout, 0 burn - just for stats tracking)
            arcadeCore.creditPayout(matchId, loser, 0, 0, false);

            emit PlayerPaidOut(matchId, winner, prizePool, true);
            emit PlayerPaidOut(matchId, loser, 0, false);
            emit MatchResolved(matchId, winner, prizePool, outcome);

        } else if (outcome == MatchOutcome.TIMEOUT) {
            // Match timed out - treat as cancelled, refund both
            m.state = MatchState.CANCELLED;
            arcadeCore.cancelSession(matchId);
            emit MatchCancelled(matchId, "Result timeout");
            emit RoundCancelled(matchId, "Result timeout");
            // Players can claim refunds via claimRefund()
        }

        // Settle the session (unless cancelled)
        if (m.state == MatchState.RESOLVED) {
            arcadeCore.settleSession(matchId);
            emit RoundResolved(matchId, uint256(uint160(winner)), uint256(outcome));
        }
    }

    /// @notice Get stake amount for tier
    function _getStakeAmount(StakeTier tier) internal pure returns (uint256) {
        if (tier == StakeTier.BRONZE) return BRONZE_STAKE;
        if (tier == StakeTier.SILVER) return SILVER_STAKE;
        if (tier == StakeTier.GOLD) return GOLD_STAKE;
        if (tier == StakeTier.DIAMOND) return DIAMOND_STAKE;
        revert InvalidStakeTier();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - IArcadeGame
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IArcadeGame
    function getGameInfo() external view override returns (GameInfo memory) {
        return _gameInfo;
    }

    /// @inheritdoc IArcadeGame
    function gameId() external view override returns (bytes32) {
        return _gameInfo.gameId;
    }

    /// @inheritdoc IArcadeGame
    function currentSessionId() external view override returns (uint256) {
        return _matchCounter;
    }

    /// @inheritdoc IArcadeGame
    function getSessionState(uint256 sessionId) external view override returns (SessionState) {
        Match storage m = _matches[sessionId];
        
        // Map internal state to IArcadeTypes.SessionState
        if (m.state == MatchState.NONE) return SessionState.NONE;
        if (m.state == MatchState.CREATED) return SessionState.BETTING;
        if (m.state == MatchState.WAITING) return SessionState.BETTING;
        if (m.state == MatchState.ACTIVE) return SessionState.ACTIVE;
        if (m.state == MatchState.RESOLVED) return SessionState.SETTLED;
        if (m.state == MatchState.CANCELLED) return SessionState.CANCELLED;
        
        return SessionState.NONE;
    }

    /// @inheritdoc IArcadeGame
    function isPlayerInSession(
        uint256 sessionId,
        address player
    ) external view override returns (bool) {
        Match storage m = _matches[sessionId];
        if (player == m.player1 && m.player1Net > 0) return true;
        if (player == m.player2 && m.player2Net > 0) return true;
        return false;
    }

    /// @inheritdoc IArcadeGame
    function getSessionPrizePool(uint256 sessionId) external view override returns (uint256) {
        return _matches[sessionId].prizePool;
    }

    /// @inheritdoc IArcadeGame
    function isPaused() external view override returns (bool) {
        return paused();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS - GAME SPECIFIC
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get match information
    /// @param matchId Match to query
    /// @return match_ The match data
    function getMatch(uint256 matchId) external view returns (Match memory match_) {
        return _matches[matchId];
    }

    /// @notice Get stake amount for a tier
    /// @param tier Stake tier
    /// @return amount Stake amount in DATA
    function getStakeAmount(StakeTier tier) external pure returns (uint256 amount) {
        return _getStakeAmount(tier);
    }

    /// @notice Check if a nonce has been used
    /// @param nonce Nonce to check
    /// @return used True if nonce was used
    function isNonceUsed(bytes32 nonce) external view returns (bool used) {
        return _usedNonces[nonce];
    }

    /// @notice Get current match counter
    /// @return count Total matches created
    function matchCount() external view returns (uint256 count) {
        return _matchCounter;
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

    /// @notice Update oracle address
    /// @param newOracle New oracle address
    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert InvalidAddress();
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }

    /// @notice Update game active status
    /// @param active Whether game should be active
    function setActive(bool active) external onlyOwner {
        _gameInfo.isActive = active;
    }

    /// @inheritdoc IArcadeGame
    function emergencyCancel(
        uint256 sessionId,
        string calldata reason
    ) external override onlyOwner {
        Match storage m = _matches[sessionId];

        if (m.state == MatchState.NONE) revert MatchNotFound();
        if (m.state == MatchState.RESOLVED || m.state == MatchState.CANCELLED) {
            revert InvalidMatchState();
        }

        m.state = MatchState.CANCELLED;
        arcadeCore.cancelSession(sessionId);

        emit MatchCancelled(sessionId, reason);
        emit RoundCancelled(sessionId, reason);
    }
}
