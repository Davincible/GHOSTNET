// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {DailyOps} from "../../src/arcade/games/DailyOps.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

/// @title DailyOpsTest
/// @notice Comprehensive tests for the DailyOps daily mission and streak system
contract DailyOpsTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    DailyOps public dailyOps;
    ERC20Mock public dataToken;

    // Signer keypair for testing
    uint256 public constant SIGNER_PRIVATE_KEY = 0xA11CE;
    address public signer;

    address public admin = makeAddr("admin");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    uint256 public constant INITIAL_BALANCE = 10_000 ether;
    uint256 public constant TREASURY_BALANCE = 1_000_000 ether;
    uint256 public constant DEFAULT_REWARD = 50 ether;

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Derive signer address from private key
        signer = vm.addr(SIGNER_PRIVATE_KEY);

        // Deploy token
        dataToken = new ERC20Mock("DATA", "DATA", 18);

        // Deploy DailyOps
        vm.prank(admin);
        dailyOps = new DailyOps(address(dataToken), admin, signer);

        // Fund treasury
        dataToken.mint(address(dailyOps), TREASURY_BALANCE);

        // Fund players for shield purchases
        _fundPlayer(player1, INITIAL_BALANCE);
        _fundPlayer(player2, INITIAL_BALANCE);
        _fundPlayer(player3, INITIAL_BALANCE);

        // Start at a reasonable timestamp (day 1000)
        vm.warp(1000 days);
    }

    function _fundPlayer(address player, uint256 amount) internal {
        dataToken.mint(player, amount);
        vm.prank(player);
        dataToken.approve(address(dailyOps), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _signClaim(
        address player,
        uint64 day,
        bytes32 missionId,
        uint256 rewardAmount,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(player, day, missionId, rewardAmount, nonce, block.chainid, address(dailyOps))
        );
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _getCurrentDay() internal view returns (uint64) {
        return uint64(block.timestamp / 1 days);
    }

    function _claimForPlayer(address player, uint64 day, uint256 reward) internal {
        bytes32 missionId = keccak256(abi.encodePacked("mission", day));
        bytes32 nonce = keccak256(abi.encodePacked(player, day, block.timestamp));
        bytes memory sig = _signClaim(player, day, missionId, reward, nonce);

        vm.prank(player);
        dailyOps.claimDailyReward(day, missionId, reward, nonce, sig);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Initialization() public view {
        assertEq(address(dailyOps.dataToken()), address(dataToken));
        assertTrue(dailyOps.hasRole(dailyOps.MISSION_SIGNER_ROLE(), signer));
        assertTrue(dailyOps.hasRole(dailyOps.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_InitialState() public view {
        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.currentStreak, 0);
        assertEq(streak.longestStreak, 0);
        assertEq(streak.lastClaimDay, 0);
        assertEq(streak.totalClaimed, 0);
    }

    function test_GetCurrentDay() public view {
        uint64 expectedDay = uint64(block.timestamp / 1 days);
        assertEq(dailyOps.getCurrentDay(), expectedDay);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIM TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimDailyReward_FirstClaim() public {
        uint64 currentDay = _getCurrentDay();
        uint256 balanceBefore = dataToken.balanceOf(player1);

        _claimForPlayer(player1, currentDay, DEFAULT_REWARD);

        uint256 balanceAfter = dataToken.balanceOf(player1);
        assertEq(balanceAfter - balanceBefore, DEFAULT_REWARD);

        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.currentStreak, 1);
        assertEq(streak.longestStreak, 1);
        assertEq(streak.lastClaimDay, currentDay);
        assertEq(streak.totalMissionsCompleted, 1);
    }

    function test_ClaimDailyReward_ConsecutiveDays() public {
        uint64 day1 = _getCurrentDay();

        // Day 1
        _claimForPlayer(player1, day1, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 1);

        // Day 2
        vm.warp(block.timestamp + 1 days);
        uint64 day2 = _getCurrentDay();
        _claimForPlayer(player1, day2, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 2);

        // Day 3
        vm.warp(block.timestamp + 1 days);
        uint64 day3 = _getCurrentDay();
        _claimForPlayer(player1, day3, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 3);
    }

    function test_ClaimDailyReward_StreakBroken() public {
        uint64 day1 = _getCurrentDay();

        // Day 1
        _claimForPlayer(player1, day1, DEFAULT_REWARD);

        // Day 2
        vm.warp(block.timestamp + 1 days);
        uint64 day2 = _getCurrentDay();
        _claimForPlayer(player1, day2, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 2);

        // Skip day 3, claim on day 4 - streak should break
        vm.warp(block.timestamp + 2 days);
        uint64 day4 = _getCurrentDay();

        vm.expectEmit(true, false, false, true);
        emit DailyOps.StreakBroken(player1, 2);

        _claimForPlayer(player1, day4, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 1);
        assertEq(dailyOps.getStreak(player1).longestStreak, 2);
    }

    function test_ClaimDailyReward_EmitEvent() public {
        uint64 currentDay = _getCurrentDay();
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("test_nonce");
        bytes memory sig = _signClaim(player1, currentDay, missionId, DEFAULT_REWARD, nonce);

        vm.expectEmit(true, true, true, true);
        emit DailyOps.DailyRewardClaimed(player1, currentDay, missionId, DEFAULT_REWARD, 1);

        vm.prank(player1);
        dailyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, sig);
    }

    function test_ClaimDailyReward_RevertWhen_InvalidSignature() public {
        uint64 currentDay = _getCurrentDay();
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("test_nonce");

        // Use wrong signer
        uint256 wrongKey = 0xBAD;
        bytes32 messageHash = keccak256(
            abi.encodePacked(player1, currentDay, missionId, DEFAULT_REWARD, nonce, block.chainid, address(dailyOps))
        );
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, ethSignedHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.prank(player1);
        vm.expectRevert(DailyOps.InvalidSignature.selector);
        dailyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, badSig);
    }

    function test_ClaimDailyReward_RevertWhen_NonceReused() public {
        uint64 currentDay = _getCurrentDay();
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("reused_nonce");
        bytes memory sig = _signClaim(player1, currentDay, missionId, DEFAULT_REWARD, nonce);

        vm.prank(player1);
        dailyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, sig);

        // Try to reuse nonce
        vm.prank(player1);
        vm.expectRevert(DailyOps.NonceAlreadyUsed.selector);
        dailyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, sig);
    }

    function test_ClaimDailyReward_RevertWhen_FutureDay() public {
        uint64 futureDay = _getCurrentDay() + 1;
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("test_nonce");
        bytes memory sig = _signClaim(player1, futureDay, missionId, DEFAULT_REWARD, nonce);

        vm.prank(player1);
        vm.expectRevert(DailyOps.InvalidClaimDay.selector);
        dailyOps.claimDailyReward(futureDay, missionId, DEFAULT_REWARD, nonce, sig);
    }

    function test_ClaimDailyReward_RevertWhen_AlreadyClaimed() public {
        uint64 currentDay = _getCurrentDay();
        _claimForPlayer(player1, currentDay, DEFAULT_REWARD);

        // Try to claim again for same day
        bytes32 missionId = keccak256("another_mission");
        bytes32 nonce = keccak256("another_nonce");
        bytes memory sig = _signClaim(player1, currentDay, missionId, DEFAULT_REWARD, nonce);

        vm.prank(player1);
        vm.expectRevert(DailyOps.InvalidClaimDay.selector);
        dailyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, sig);
    }

    function test_ClaimDailyReward_RevertWhen_RewardTooLarge() public {
        uint64 currentDay = _getCurrentDay();
        uint256 hugeReward = dailyOps.MAX_REWARD_PER_CLAIM() + 1;
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("test_nonce");
        bytes memory sig = _signClaim(player1, currentDay, missionId, hugeReward, nonce);

        vm.prank(player1);
        vm.expectRevert(DailyOps.RewardTooLarge.selector);
        dailyOps.claimDailyReward(currentDay, missionId, hugeReward, nonce, sig);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // MILESTONE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Milestone_7Days() public {
        uint64 startDay = _getCurrentDay();

        // Build 6-day streak
        for (uint256 i = 0; i < 6; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            vm.warp(block.timestamp + 1 days);
        }

        uint256 balanceBefore = dataToken.balanceOf(player1);

        // Day 7 should trigger milestone
        // Event order: BadgeEarned (from _awardBadge), DailyRewardClaimed, MilestoneReached
        vm.expectEmit(true, true, false, false);
        emit DailyOps.BadgeEarned(player1, keccak256("WEEK_WARRIOR"));

        _claimForPlayer(player1, startDay + 6, DEFAULT_REWARD);

        uint256 balanceAfter = dataToken.balanceOf(player1);
        // Should receive daily reward + milestone bonus
        assertEq(balanceAfter - balanceBefore, DEFAULT_REWARD + dailyOps.MILESTONE_7_BONUS());

        // Check badge
        DailyOps.Badge[] memory badges = dailyOps.getBadges(player1);
        assertEq(badges.length, 1);
        assertEq(badges[0].badgeId, keccak256("WEEK_WARRIOR"));

        // Verify streak
        assertEq(dailyOps.getStreak(player1).currentStreak, 7);
    }

    function test_Milestone_30Days_Badge() public {
        uint64 startDay = _getCurrentDay();

        // Build 30-day streak
        for (uint256 i = 0; i < 30; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < 29) vm.warp(block.timestamp + 1 days);
        }

        DailyOps.Badge[] memory badges = dailyOps.getBadges(player1);
        // Should have WEEK_WARRIOR (day 7) and DEDICATED_OPERATOR (day 30)
        assertEq(badges.length, 2);

        // Verify DEDICATED_OPERATOR badge
        bool hasDedicatedBadge = false;
        for (uint256 i = 0; i < badges.length; i++) {
            if (badges[i].badgeId == keccak256("DEDICATED_OPERATOR")) {
                hasDedicatedBadge = true;
                break;
            }
        }
        assertTrue(hasDedicatedBadge);
    }

    function test_Milestone_OnlyClaimOnce() public {
        uint64 startDay = _getCurrentDay();

        // Build 7-day streak
        for (uint256 i = 0; i < 7; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            vm.warp(block.timestamp + 1 days);
        }

        assertTrue(dailyOps.milestonesClaimed(player1, 7));

        // Break streak and rebuild to 7 again
        vm.warp(block.timestamp + 2 days); // Skip a day
        uint64 newStartDay = _getCurrentDay();

        for (uint256 i = 0; i < 7; i++) {
            _claimForPlayer(player1, newStartDay + uint64(i), DEFAULT_REWARD);
            if (i < 6) vm.warp(block.timestamp + 1 days);
        }

        // Should not get milestone bonus again
        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.currentStreak, 7);

        // Count badges - should still only have one WEEK_WARRIOR
        DailyOps.Badge[] memory badges = dailyOps.getBadges(player1);
        uint256 weekWarriorCount = 0;
        for (uint256 i = 0; i < badges.length; i++) {
            if (badges[i].badgeId == keccak256("WEEK_WARRIOR")) {
                weekWarriorCount++;
            }
        }
        assertEq(weekWarriorCount, 1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SHIELD TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PurchaseShield_1Day() public {
        uint64 currentDay = _getCurrentDay();
        uint256 balanceBefore = dataToken.balanceOf(player1);

        vm.prank(player1);
        dailyOps.purchaseShield(1);

        uint256 balanceAfter = dataToken.balanceOf(player1);
        assertEq(balanceBefore - balanceAfter, dailyOps.SHIELD_COST_1_DAY());

        assertTrue(dailyOps.isShieldActive(player1));

        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.shieldExpiryDay, currentDay + 1);
    }

    function test_PurchaseShield_7Days() public {
        uint64 currentDay = _getCurrentDay();

        vm.prank(player1);
        dailyOps.purchaseShield(7);

        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.shieldExpiryDay, currentDay + 7);

        // Check burn
        assertEq(dailyOps.totalBurned(), dailyOps.SHIELD_COST_7_DAY());
    }

    function test_PurchaseShield_ProtectsStreak() public {
        uint64 startDay = _getCurrentDay();

        // Build 3-day streak
        for (uint256 i = 0; i < 3; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            vm.warp(block.timestamp + 1 days);
        }
        assertEq(dailyOps.getStreak(player1).currentStreak, 3);

        // Purchase 1-day shield
        vm.prank(player1);
        dailyOps.purchaseShield(1);

        // Skip a day (would normally break streak)
        vm.warp(block.timestamp + 1 days);

        // Claim - streak should be protected
        uint64 claimDay = _getCurrentDay();
        _claimForPlayer(player1, claimDay, DEFAULT_REWARD);

        // Streak should continue, not reset
        assertEq(dailyOps.getStreak(player1).currentStreak, 4);
    }

    function test_PurchaseShield_RevertWhen_AlreadyActive() public {
        vm.prank(player1);
        dailyOps.purchaseShield(1);

        vm.prank(player1);
        vm.expectRevert(DailyOps.ShieldAlreadyActive.selector);
        dailyOps.purchaseShield(1);
    }

    function test_PurchaseShield_RevertWhen_InvalidDuration() public {
        vm.prank(player1);
        vm.expectRevert(DailyOps.InvalidShieldDuration.selector);
        dailyOps.purchaseShield(3); // Only 1 and 7 allowed
    }

    function test_PurchaseShield_CanRepurchaseAfterExpiry() public {
        vm.prank(player1);
        dailyOps.purchaseShield(1);

        // Wait for shield to expire
        vm.warp(block.timestamp + 2 days);
        assertFalse(dailyOps.isShieldActive(player1));

        // Should be able to purchase again
        vm.prank(player1);
        dailyOps.purchaseShield(1);
        assertTrue(dailyOps.isShieldActive(player1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH RATE REDUCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_DeathRateReduction_NoStreak() public view {
        assertEq(dailyOps.getDeathRateReduction(player1), 0);
    }

    function test_DeathRateReduction_3DayStreak() public {
        uint64 startDay = _getCurrentDay();

        for (uint256 i = 0; i < 3; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < 2) vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getDeathRateReduction(player1), 300); // 3%
    }

    function test_DeathRateReduction_14DayStreak() public {
        uint64 startDay = _getCurrentDay();

        for (uint256 i = 0; i < 14; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < 13) vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getDeathRateReduction(player1), 500); // 5%
    }

    function test_DeathRateReduction_60DayStreak() public {
        uint64 startDay = _getCurrentDay();

        for (uint256 i = 0; i < 60; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < 59) vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getDeathRateReduction(player1), 800); // 8%
    }

    function test_DeathRateReduction_180DayStreak() public {
        uint64 startDay = _getCurrentDay();

        for (uint256 i = 0; i < 180; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < 179) vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getDeathRateReduction(player1), 1000); // 10%
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TREASURY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FundTreasury() public {
        uint256 fundAmount = 100_000 ether;
        dataToken.mint(player1, fundAmount);

        vm.prank(player1);
        dataToken.approve(address(dailyOps), fundAmount);

        vm.expectEmit(true, false, false, true);
        emit DailyOps.TreasuryFunded(player1, fundAmount);

        vm.prank(player1);
        dailyOps.fundTreasury(fundAmount);

        assertEq(dailyOps.getTreasuryBalance(), TREASURY_BALANCE + fundAmount);
    }

    function test_ClaimDailyReward_RevertWhen_InsufficientTreasury() public {
        // Deploy new DailyOps with empty treasury
        vm.prank(admin);
        DailyOps emptyOps = new DailyOps(address(dataToken), admin, signer);

        uint64 currentDay = _getCurrentDay();
        bytes32 missionId = keccak256("test_mission");
        bytes32 nonce = keccak256("test_nonce");

        bytes32 messageHash = keccak256(
            abi.encodePacked(player1, currentDay, missionId, DEFAULT_REWARD, nonce, block.chainid, address(emptyOps))
        );
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, ethSignedHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(player1);
        vm.expectRevert(DailyOps.InsufficientTreasuryBalance.selector);
        emptyOps.claimDailyReward(currentDay, missionId, DEFAULT_REWARD, nonce, sig);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TRACKING TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_TotalDistributed() public {
        uint64 startDay = _getCurrentDay();

        _claimForPlayer(player1, startDay, DEFAULT_REWARD);
        assertEq(dailyOps.totalDistributed(), DEFAULT_REWARD);

        vm.warp(block.timestamp + 1 days);
        _claimForPlayer(player1, startDay + 1, DEFAULT_REWARD);
        assertEq(dailyOps.totalDistributed(), DEFAULT_REWARD * 2);
    }

    function test_TotalClaimed_PerPlayer() public {
        uint64 startDay = _getCurrentDay();

        _claimForPlayer(player1, startDay, DEFAULT_REWARD);
        _claimForPlayer(player2, startDay, DEFAULT_REWARD * 2);

        assertEq(dailyOps.getStreak(player1).totalClaimed, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player2).totalClaimed, DEFAULT_REWARD * 2);
    }

    function test_HasClaimedDay() public {
        uint64 currentDay = _getCurrentDay();

        assertFalse(dailyOps.hasClaimedDay(player1, currentDay));

        _claimForPlayer(player1, currentDay, DEFAULT_REWARD);

        assertTrue(dailyOps.hasClaimedDay(player1, currentDay));
        assertFalse(dailyOps.hasClaimedDay(player1, currentDay + 1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_ClaimReward(uint256 reward) public {
        reward = bound(reward, 1, dailyOps.MAX_REWARD_PER_CLAIM());
        uint64 currentDay = _getCurrentDay();

        uint256 balanceBefore = dataToken.balanceOf(player1);
        _claimForPlayer(player1, currentDay, reward);
        uint256 balanceAfter = dataToken.balanceOf(player1);

        assertEq(balanceAfter - balanceBefore, reward);
    }

    function testFuzz_StreakContinuity(uint8 streakLength) public {
        streakLength = uint8(bound(streakLength, 1, 30));
        uint64 startDay = _getCurrentDay();

        for (uint256 i = 0; i < streakLength; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            if (i < streakLength - 1) vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getStreak(player1).currentStreak, streakLength);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    function test_MultiplePlayers_IndependentStreaks() public {
        uint64 startDay = _getCurrentDay();

        // Player 1: 3-day streak
        for (uint256 i = 0; i < 3; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            vm.warp(block.timestamp + 1 days);
        }

        // Player 2: 1-day streak starting later
        _claimForPlayer(player2, _getCurrentDay(), DEFAULT_REWARD);

        assertEq(dailyOps.getStreak(player1).currentStreak, 3);
        assertEq(dailyOps.getStreak(player2).currentStreak, 1);
    }

    function test_LongestStreak_PreservedAfterBreak() public {
        uint64 startDay = _getCurrentDay();

        // Build 5-day streak
        for (uint256 i = 0; i < 5; i++) {
            _claimForPlayer(player1, startDay + uint64(i), DEFAULT_REWARD);
            vm.warp(block.timestamp + 1 days);
        }

        assertEq(dailyOps.getStreak(player1).longestStreak, 5);

        // Skip a day, breaking streak
        vm.warp(block.timestamp + 1 days);
        _claimForPlayer(player1, _getCurrentDay(), DEFAULT_REWARD);

        // Current streak reset, but longest preserved
        assertEq(dailyOps.getStreak(player1).currentStreak, 1);
        assertEq(dailyOps.getStreak(player1).longestStreak, 5);
    }

    function test_ClaimPastDay_WithinWindow() public {
        uint64 currentDay = _getCurrentDay();

        // Advance time but claim for yesterday
        vm.warp(block.timestamp + 1 days);
        uint64 newCurrentDay = _getCurrentDay();

        // Should be able to claim for the past day
        _claimForPlayer(player1, currentDay, DEFAULT_REWARD);

        DailyOps.PlayerStreak memory streak = dailyOps.getStreak(player1);
        assertEq(streak.lastClaimDay, currentDay);
        assertEq(streak.currentStreak, 1);

        // Now claim for today - should continue streak
        _claimForPlayer(player1, newCurrentDay, DEFAULT_REWARD);
        assertEq(dailyOps.getStreak(player1).currentStreak, 2);
    }
}
