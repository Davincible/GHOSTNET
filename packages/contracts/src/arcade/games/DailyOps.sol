// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DailyOps
/// @notice Daily mission and streak tracking system for GHOSTNET
/// @dev Missions are verified off-chain; streaks and rewards managed on-chain
///
/// Architecture:
/// - Server monitors game events to detect mission completion
/// - Server signs claim authorization (player, day, reward, nonce)
/// - Player submits claim to contract
/// - Contract validates, updates streak, distributes rewards
/// - Death rate reduction handled via separate GhostCore boost (server-signed)
contract DailyOps is AccessControlDefaultAdminRules, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ══════════════════════════════════════════════════════════════════════════════
    // ROLES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Role for the signer that authorizes mission claims
    bytes32 public constant MISSION_SIGNER_ROLE = keccak256("MISSION_SIGNER_ROLE");

    /// @notice Role for treasury management
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Duration of one day in seconds (UTC-based)
    uint256 public constant DAY_DURATION = 1 days;

    /// @notice Cost to purchase a 1-day streak shield (burned)
    uint256 public constant SHIELD_COST_1_DAY = 50 ether; // 50 $DATA

    /// @notice Cost to purchase a 7-day streak shield (burned)
    uint256 public constant SHIELD_COST_7_DAY = 200 ether; // 200 $DATA

    /// @notice Maximum shield duration (7 days)
    uint256 public constant MAX_SHIELD_DAYS = 7;

    /// @notice Maximum reward per claim (safety cap)
    uint256 public constant MAX_REWARD_PER_CLAIM = 10_000 ether; // 10,000 $DATA

    // ══════════════════════════════════════════════════════════════════════════════
    // STREAK MILESTONE THRESHOLDS
    // ══════════════════════════════════════════════════════════════════════════════

    uint32 public constant MILESTONE_3_DAYS = 3;
    uint32 public constant MILESTONE_7_DAYS = 7;
    uint32 public constant MILESTONE_14_DAYS = 14;
    uint32 public constant MILESTONE_21_DAYS = 21;
    uint32 public constant MILESTONE_30_DAYS = 30;
    uint32 public constant MILESTONE_60_DAYS = 60;
    uint32 public constant MILESTONE_90_DAYS = 90;
    uint32 public constant MILESTONE_180_DAYS = 180;

    /// @notice Bonus rewards for reaching milestones (in wei)
    uint256 public constant MILESTONE_7_BONUS = 500 ether;
    uint256 public constant MILESTONE_21_BONUS = 1000 ether;
    uint256 public constant MILESTONE_30_BONUS = 5000 ether;
    uint256 public constant MILESTONE_90_BONUS = 15_000 ether;

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Player's streak and claim state
    struct PlayerStreak {
        uint32 currentStreak; // Current consecutive day streak
        uint32 longestStreak; // Highest streak ever achieved
        uint64 lastClaimDay; // UTC day number of last claim
        uint64 shieldExpiryDay; // UTC day number when shield expires (0 = no shield)
        uint256 totalClaimed; // Cumulative rewards claimed
        uint64 totalMissionsCompleted; // Total missions ever completed
    }

    /// @notice Badge earned for achievements
    struct Badge {
        bytes32 badgeId; // Unique badge identifier
        uint64 earnedAt; // Timestamp when earned
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Claim signature is invalid
    error InvalidSignature();

    /// @notice Nonce has already been used
    error NonceAlreadyUsed();

    /// @notice Cannot claim for this day yet (future) or already claimed
    error InvalidClaimDay();

    /// @notice Reward amount exceeds safety cap
    error RewardTooLarge();

    /// @notice Shield already active
    error ShieldAlreadyActive();

    /// @notice Invalid shield duration
    error InvalidShieldDuration();

    /// @notice Treasury has insufficient balance
    error InsufficientTreasuryBalance();

    /// @notice Zero address provided
    error ZeroAddress();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a player claims their daily reward
    event DailyRewardClaimed(
        address indexed player,
        uint64 indexed day,
        bytes32 indexed missionId,
        uint256 reward,
        uint32 newStreak
    );

    /// @notice Emitted when a streak milestone is reached
    event MilestoneReached(address indexed player, uint32 streak, uint256 bonusReward);

    /// @notice Emitted when a badge is earned
    event BadgeEarned(address indexed player, bytes32 indexed badgeId);

    /// @notice Emitted when a streak is broken
    event StreakBroken(address indexed player, uint32 previousStreak);

    /// @notice Emitted when a shield is purchased
    event ShieldPurchased(address indexed player, uint8 days_, uint64 expiryDay, uint256 cost);

    /// @notice Emitted when a shield protects a streak
    event ShieldUsed(address indexed player, uint64 day);

    /// @notice Emitted when treasury is funded
    event TreasuryFunded(address indexed funder, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice The DATA token
    IERC20 public immutable dataToken;

    /// @notice Player streak data
    mapping(address player => PlayerStreak streak) public streaks;

    /// @notice Used nonces (prevents replay attacks)
    mapping(bytes32 nonce => bool used) public usedNonces;

    /// @notice Player badges
    mapping(address player => Badge[] badges) internal _playerBadges;

    /// @notice Track which milestones have been claimed (player => milestone => claimed)
    mapping(address player => mapping(uint32 milestone => bool claimed)) public milestonesClaimed;

    /// @notice Total rewards distributed
    uint256 public totalDistributed;

    /// @notice Total tokens burned (shield purchases)
    uint256 public totalBurned;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @param _dataToken Address of the DATA token
    /// @param _admin Initial admin address
    /// @param _missionSigner Address authorized to sign mission claims
    constructor(
        address _dataToken,
        address _admin,
        address _missionSigner
    ) AccessControlDefaultAdminRules(3 days, _admin) {
        if (_dataToken == address(0)) revert ZeroAddress();
        if (_missionSigner == address(0)) revert ZeroAddress();

        dataToken = IERC20(_dataToken);

        _grantRole(MISSION_SIGNER_ROLE, _missionSigner);
        _grantRole(TREASURY_ROLE, _admin);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EXTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Claim daily mission reward
    /// @param day UTC day number (block.timestamp / DAY_DURATION)
    /// @param missionId Identifier of the completed mission
    /// @param rewardAmount Reward amount in DATA tokens
    /// @param nonce Unique nonce for this claim
    /// @param signature Server signature authorizing the claim
    function claimDailyReward(
        uint64 day,
        bytes32 missionId,
        uint256 rewardAmount,
        bytes32 nonce,
        bytes calldata signature
    ) external nonReentrant {
        // Validate claim
        _validateClaim(msg.sender, day, missionId, rewardAmount, nonce, signature);

        // Mark nonce as used
        usedNonces[nonce] = true;

        // Get current day and player state
        uint64 currentDay = uint64(block.timestamp / DAY_DURATION);
        PlayerStreak storage streak = streaks[msg.sender];

        // Update streak
        _updateStreak(msg.sender, streak, day, currentDay);

        // Record claim
        streak.lastClaimDay = day;
        streak.totalMissionsCompleted++;

        // Check and distribute milestone bonuses
        uint256 milestoneBonus = _checkMilestones(msg.sender, streak.currentStreak);
        uint256 totalReward = rewardAmount + milestoneBonus;

        // Update totals
        streak.totalClaimed += totalReward;
        totalDistributed += totalReward;

        // Transfer reward
        if (dataToken.balanceOf(address(this)) < totalReward) {
            revert InsufficientTreasuryBalance();
        }
        dataToken.safeTransfer(msg.sender, totalReward);

        emit DailyRewardClaimed(msg.sender, day, missionId, rewardAmount, streak.currentStreak);

        if (milestoneBonus > 0) {
            emit MilestoneReached(msg.sender, streak.currentStreak, milestoneBonus);
        }
    }

    /// @notice Purchase a streak shield
    /// @param days_ Number of days to protect (1 or 7)
    function purchaseShield(uint8 days_) external nonReentrant {
        if (days_ != 1 && days_ != 7) revert InvalidShieldDuration();

        PlayerStreak storage streak = streaks[msg.sender];
        uint64 currentDay = uint64(block.timestamp / DAY_DURATION);

        // Check if shield already active
        if (streak.shieldExpiryDay > currentDay) revert ShieldAlreadyActive();

        // Calculate cost
        uint256 cost = days_ == 1 ? SHIELD_COST_1_DAY : SHIELD_COST_7_DAY;

        // Transfer and burn tokens
        dataToken.safeTransferFrom(msg.sender, address(this), cost);
        _burnTokens(cost);

        // Set shield expiry
        uint64 expiryDay = currentDay + days_;
        streak.shieldExpiryDay = expiryDay;

        emit ShieldPurchased(msg.sender, days_, expiryDay, cost);
    }

    /// @notice Fund the treasury for reward distribution
    /// @param amount Amount of DATA to deposit
    function fundTreasury(uint256 amount) external {
        dataToken.safeTransferFrom(msg.sender, address(this), amount);
        emit TreasuryFunded(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get player's streak data
    function getStreak(address player) external view returns (PlayerStreak memory) {
        return streaks[player];
    }

    /// @notice Get player's badges
    function getBadges(address player) external view returns (Badge[] memory) {
        return _playerBadges[player];
    }

    /// @notice Get current UTC day number
    function getCurrentDay() external view returns (uint64) {
        return uint64(block.timestamp / DAY_DURATION);
    }

    /// @notice Check if player has claimed for a specific day
    function hasClaimedDay(address player, uint64 day) external view returns (bool) {
        return streaks[player].lastClaimDay == day;
    }

    /// @notice Check if player's streak is protected by shield
    function isShieldActive(address player) external view returns (bool) {
        uint64 currentDay = uint64(block.timestamp / DAY_DURATION);
        return streaks[player].shieldExpiryDay > currentDay;
    }

    /// @notice Get death rate reduction for a player based on streak
    /// @dev Returns basis points reduction (e.g., 300 = 3% reduction)
    ///      This is informational; actual reduction applied via GhostCore boost
    function getDeathRateReduction(address player) external view returns (uint16) {
        uint32 streak = streaks[player].currentStreak;

        if (streak >= MILESTONE_180_DAYS) return 1000; // -10%
        if (streak >= MILESTONE_60_DAYS) return 800; // -8%
        if (streak >= MILESTONE_14_DAYS) return 500; // -5%
        if (streak >= MILESTONE_3_DAYS) return 300; // -3%
        return 0;
    }

    /// @notice Get treasury balance available for rewards
    function getTreasuryBalance() external view returns (uint256) {
        return dataToken.balanceOf(address(this));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Validate claim parameters and signature
    function _validateClaim(
        address player,
        uint64 day,
        bytes32 missionId,
        uint256 rewardAmount,
        bytes32 nonce,
        bytes calldata signature
    ) internal view {
        // Check nonce not used
        if (usedNonces[nonce]) revert NonceAlreadyUsed();

        // Check reward amount
        if (rewardAmount > MAX_REWARD_PER_CLAIM) revert RewardTooLarge();

        // Check day is valid (not in future, not already claimed)
        uint64 currentDay = uint64(block.timestamp / DAY_DURATION);
        if (day > currentDay) revert InvalidClaimDay();

        PlayerStreak storage streak = streaks[player];
        if (streak.lastClaimDay == day) revert InvalidClaimDay();

        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                player,
                day,
                missionId,
                rewardAmount,
                nonce,
                block.chainid,
                address(this)
            )
        );
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);

        if (!hasRole(MISSION_SIGNER_ROLE, signer)) revert InvalidSignature();
    }

    /// @notice Update player's streak based on claim
    function _updateStreak(
        address player,
        PlayerStreak storage streak,
        uint64 claimDay,
        uint64 /* currentDay */
    ) internal {
        uint64 lastClaim = streak.lastClaimDay;

        // First claim ever
        if (lastClaim == 0) {
            streak.currentStreak = 1;
            if (streak.longestStreak < 1) {
                streak.longestStreak = 1;
            }
            return;
        }

        // Check if consecutive day
        bool isConsecutive = (claimDay == lastClaim + 1);

        // Check if shield protects a gap
        bool shieldProtects = false;
        if (!isConsecutive && streak.shieldExpiryDay > 0) {
            // Shield protects if the gap days are within shield period
            // and we're claiming within a reasonable window
            uint64 gapDays = claimDay - lastClaim - 1;
            if (gapDays > 0 && lastClaim + gapDays < streak.shieldExpiryDay) {
                shieldProtects = true;
                emit ShieldUsed(player, claimDay);
            }
        }

        if (isConsecutive || shieldProtects) {
            // Continue streak
            streak.currentStreak++;
            if (streak.currentStreak > streak.longestStreak) {
                streak.longestStreak = streak.currentStreak;
            }
        } else {
            // Streak broken - emit event before resetting
            if (streak.currentStreak > 0) {
                emit StreakBroken(player, streak.currentStreak);
            }
            streak.currentStreak = 1;
        }
    }

    /// @notice Check and distribute milestone bonuses
    /// @return bonus Total bonus amount to distribute
    function _checkMilestones(address player, uint32 streak) internal returns (uint256 bonus) {
        // Check each milestone (only if not already claimed)
        if (streak >= MILESTONE_7_DAYS && !milestonesClaimed[player][MILESTONE_7_DAYS]) {
            milestonesClaimed[player][MILESTONE_7_DAYS] = true;
            bonus += MILESTONE_7_BONUS;
            _awardBadge(player, keccak256("WEEK_WARRIOR"));
        }

        if (streak >= MILESTONE_21_DAYS && !milestonesClaimed[player][MILESTONE_21_DAYS]) {
            milestonesClaimed[player][MILESTONE_21_DAYS] = true;
            bonus += MILESTONE_21_BONUS;
        }

        if (streak >= MILESTONE_30_DAYS && !milestonesClaimed[player][MILESTONE_30_DAYS]) {
            milestonesClaimed[player][MILESTONE_30_DAYS] = true;
            bonus += MILESTONE_30_BONUS;
            _awardBadge(player, keccak256("DEDICATED_OPERATOR"));
        }

        if (streak >= MILESTONE_90_DAYS && !milestonesClaimed[player][MILESTONE_90_DAYS]) {
            milestonesClaimed[player][MILESTONE_90_DAYS] = true;
            bonus += MILESTONE_90_BONUS;
            _awardBadge(player, keccak256("LEGEND"));
        }
    }

    /// @notice Award a badge to a player
    function _awardBadge(address player, bytes32 badgeId) internal {
        _playerBadges[player].push(Badge({badgeId: badgeId, earnedAt: uint64(block.timestamp)}));
        emit BadgeEarned(player, badgeId);
    }

    /// @notice Burn tokens (send to dead address)
    function _burnTokens(uint256 amount) internal {
        // Send to dead address (0x...dead) for permanent burn
        dataToken.safeTransfer(address(0xdead), amount);
        totalBurned += amount;
    }
}
