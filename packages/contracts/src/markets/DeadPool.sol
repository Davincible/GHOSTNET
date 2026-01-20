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
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDeadPool } from "./interfaces/IDeadPool.sol";
import { IGhostCore } from "../core/interfaces/IGhostCore.sol";
import { IDataToken } from "../token/interfaces/IDataToken.sol";

/// @title DeadPool
/// @notice Parimutuel prediction market for GHOSTNET scan outcomes
/// @dev 5% rake burned on resolution
///
/// How It Works:
/// 1. Round creator sets up a prediction (e.g., "Over/Under 50 deaths in next DARKNET scan")
/// 2. Users bet DATA on OVER or UNDER
/// 3. After scan, resolver submits the outcome
/// 4. Winners split the pot (minus 5% rake which is burned)
///
/// @custom:security-contact security@ghostnet.game
contract DeadPool is
    IDeadPool,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant ROUND_CREATOR_ROLE = keccak256("ROUND_CREATOR_ROLE");
    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Rake percentage in basis points (500 = 5%)
    uint16 public constant RAKE_BPS = 500;

    /// @notice Basis points denominator
    uint16 private constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice DATA token
    IDataToken public dataToken;

    /// @notice Dead address for burns
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @notice Total rounds created
    uint256 public roundCount;

    /// @notice Round data
    mapping(uint256 roundId => Round round) private _rounds;

    /// @notice User bets
    mapping(uint256 roundId => mapping(address user => Bet bet)) private _bets;

    /// @notice Storage gap for upgrades
    uint256[46] private __gap;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _dataToken Address of the DATA token
    /// @param _admin Address with DEFAULT_ADMIN_ROLE
    function initialize(address _dataToken, address _admin) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        dataToken = IDataToken(_dataToken);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ROUND_CREATOR_ROLE, _admin);
        _grantRole(RESOLVER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Create a new prediction round
    /// @param roundType Type of prediction
    /// @param targetLevel Which level (for DEATH_COUNT rounds)
    /// @param line Over/under line
    /// @param deadline When betting closes
    /// @return roundId The new round ID
    function createRound(
        RoundType roundType,
        IGhostCore.Level targetLevel,
        uint256 line,
        uint64 deadline
    ) external onlyRole(ROUND_CREATOR_ROLE) returns (uint256 roundId) {
        roundId = ++roundCount;

        _rounds[roundId] = Round({
            roundType: roundType,
            targetLevel: targetLevel,
            line: line,
            overPool: 0,
            underPool: 0,
            deadline: deadline,
            resolveTime: 0,
            resolved: false,
            outcome: false
        });

        emit RoundCreated(roundId, roundType, targetLevel, line, deadline);
    }

    /// @notice Resolve a round with the outcome
    /// @param roundId Round to resolve
    /// @param outcome True = OVER won, False = UNDER won
    function resolveRound(uint256 roundId, bool outcome) external onlyRole(RESOLVER_ROLE) {
        Round storage round = _rounds[roundId];

        if (round.deadline == 0) revert RoundNotFound();
        if (round.resolved) revert RoundAlreadyResolved();
        if (block.timestamp < round.deadline) revert RoundNotEnded();

        round.resolved = true;
        round.outcome = outcome;
        round.resolveTime = uint64(block.timestamp);

        // Calculate and burn rake
        uint256 totalPot = round.overPool + round.underPool;
        uint256 rake = (totalPot * RAKE_BPS) / BPS;

        if (rake > 0) {
            IERC20(address(dataToken)).safeTransfer(DEAD_ADDRESS, rake);
        }

        emit RoundResolved(roundId, outcome, totalPot, rake);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BETTING FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDeadPool
    function placeBet(uint256 roundId, bool isOver, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert InvalidAmount();

        Round storage round = _rounds[roundId];
        if (round.deadline == 0) revert RoundNotFound();
        if (block.timestamp >= round.deadline) revert RoundEnded();

        Bet storage bet = _bets[roundId][msg.sender];

        // Allow adding to existing bet on same side only
        if (bet.amount > 0 && bet.isOver != isOver) revert InvalidAmount();

        bet.amount += amount;
        bet.isOver = isOver;

        if (isOver) {
            round.overPool += amount;
        } else {
            round.underPool += amount;
        }

        IERC20(address(dataToken)).safeTransferFrom(msg.sender, address(this), amount);

        emit BetPlaced(roundId, msg.sender, isOver, amount);
    }

    /// @inheritdoc IDeadPool
    function claimWinnings(uint256 roundId)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 winnings)
    {
        Round storage round = _rounds[roundId];
        if (!round.resolved) revert RoundNotResolved();

        Bet storage bet = _bets[roundId][msg.sender];
        if (bet.amount == 0) revert NoBetExists();
        if (bet.claimed) revert AlreadyClaimed();
        if (bet.isOver != round.outcome) revert NotWinner();

        bet.claimed = true;

        winnings = _calculateWinnings(round, bet);
        if (winnings > 0) {
            IERC20(address(dataToken)).safeTransfer(msg.sender, winnings);
        }

        emit WinningsClaimed(roundId, msg.sender, winnings);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDeadPool
    function getRound(uint256 roundId) external view returns (Round memory) {
        return _rounds[roundId];
    }

    /// @inheritdoc IDeadPool
    function getBet(uint256 roundId, address user) external view returns (Bet memory) {
        return _bets[roundId][user];
    }

    /// @inheritdoc IDeadPool
    function calculateWinnings(uint256 roundId, address user) external view returns (uint256) {
        Round storage round = _rounds[roundId];
        Bet storage bet = _bets[roundId][user];

        if (!round.resolved || bet.amount == 0 || bet.isOver != round.outcome) {
            return 0;
        }

        return _calculateWinnings(round, bet);
    }

    /// @inheritdoc IDeadPool
    function getOverOdds(uint256 roundId) external view returns (uint16) {
        Round storage round = _rounds[roundId];
        if (round.overPool == 0) return 0;

        uint256 totalPool = round.overPool + round.underPool;
        uint256 netPool = totalPool - (totalPool * RAKE_BPS) / BPS;

        return uint16((netPool * BPS) / round.overPool);
    }

    /// @inheritdoc IDeadPool
    function getUnderOdds(uint256 roundId) external view returns (uint16) {
        Round storage round = _rounds[roundId];
        if (round.underPool == 0) return 0;

        uint256 totalPool = round.overPool + round.underPool;
        uint256 netPool = totalPool - (totalPool * RAKE_BPS) / BPS;

        return uint16((netPool * BPS) / round.underPool);
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

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @dev Calculate winnings for a bet
    function _calculateWinnings(Round storage round, Bet storage bet)
        internal
        view
        returns (uint256)
    {
        uint256 totalPool = round.overPool + round.underPool;
        uint256 netPool = totalPool - (totalPool * RAKE_BPS) / BPS;

        uint256 winningPool = round.outcome ? round.overPool : round.underPool;
        if (winningPool == 0) return 0;

        return (bet.amount * netPool) / winningPool;
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
