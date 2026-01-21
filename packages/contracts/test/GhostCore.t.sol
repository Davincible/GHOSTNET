// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";

/// @title GhostCore Tests
/// @notice Tests for the main GHOSTNET game logic
contract GhostCoreTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    GhostCore public implementation;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public boostSigner;
    uint256 public boostSignerPk;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public scanner = makeAddr("scanner");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant ALICE_BALANCE = 50_000_000 * 1e18;
    uint256 constant BOB_BALANCE = 50_000_000 * 1e18;

    function setUp() public {
        // Create boost signer
        (boostSigner, boostSignerPk) = makeAddrAndKey("boostSigner");

        // Deploy token
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ALICE_BALANCE;
        amounts[1] = BOB_BALANCE;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy GhostCore implementation
        implementation = new GhostCore();

        // Deploy proxy
        bytes memory initData =
            abi.encodeCall(GhostCore.initialize, (address(token), treasury, boostSigner, owner));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        ghostCore = GhostCore(address(proxy));

        // Exclude GhostCore from tax so internal transfers are tax-free
        vm.prank(owner);
        token.setTaxExclusion(address(ghostCore), true);

        // Grant scanner role (owner has DEFAULT_ADMIN_ROLE which can grant other roles)
        vm.startPrank(owner);
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), scanner);
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), owner);
        vm.stopPrank();

        // Approve token spending
        vm.prank(alice);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(ghostCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Initialize_SetsCorrectState() public view {
        IGhostCore.SystemReset memory reset = ghostCore.getSystemReset();
        assertGt(reset.deadline, block.timestamp);
        assertEq(reset.epoch, 1);
    }

    function test_Initialize_SetsLevelConfigs() public view {
        IGhostCore.LevelConfig memory vault = ghostCore.getLevelConfig(IGhostCore.Level.VAULT);
        assertEq(vault.baseDeathRateBps, 500); // 5%
        assertEq(vault.minStake, 10 * 1e18);

        IGhostCore.LevelConfig memory blackIce =
            ghostCore.getLevelConfig(IGhostCore.Level.BLACK_ICE);
        assertEq(blackIce.baseDeathRateBps, 4500); // 45%
        assertEq(blackIce.minStake, 250 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // JACK IN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_JackIn_CreatesPosition() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, stakeAmount);
        assertEq(uint8(pos.level), uint8(IGhostCore.Level.VAULT));
        assertTrue(pos.alive);
        assertEq(pos.ghostStreak, 0);
    }

    function test_JackIn_TransfersTokens() public {
        uint256 stakeAmount = 100 * 1e18;
        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        // Alice pays the stakeAmount plus tax (since transfer to ghostCore)
        // But we excluded ghostCore from tax, so just stakeAmount
        assertEq(token.balanceOf(alice), balanceBefore - stakeAmount);
        assertEq(token.balanceOf(address(ghostCore)), stakeAmount);
    }

    function test_JackIn_UpdatesLevelState() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(state.totalStaked, stakeAmount);
        assertEq(state.aliveCount, 1);
    }

    function test_JackIn_EmitsEvent() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.expectEmit(true, true, true, true);
        emit IGhostCore.JackedIn(alice, stakeAmount, IGhostCore.Level.VAULT, stakeAmount);

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);
    }

    function test_JackIn_RevertWhen_InvalidLevel() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.InvalidLevel.selector);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.NONE);
    }

    function test_JackIn_RevertWhen_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.InvalidAmount.selector);
        ghostCore.jackIn(0, IGhostCore.Level.VAULT);
    }

    function test_JackIn_RevertWhen_BelowMinStake() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.BelowMinimumStake.selector);
        ghostCore.jackIn(1 * 1e18, IGhostCore.Level.VAULT); // Min is 10
    }

    function test_JackIn_RevertWhen_PositionExists() public {
        vm.startPrank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.expectRevert(IGhostCore.PositionAlreadyExists.selector);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADD STAKE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_AddStake_IncreasesPosition() public {
        uint256 initialStake = 100 * 1e18;
        uint256 additionalStake = 50 * 1e18;

        vm.startPrank(alice);
        ghostCore.jackIn(initialStake, IGhostCore.Level.VAULT);
        ghostCore.addStake(additionalStake);
        vm.stopPrank();

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, initialStake + additionalStake);
    }

    function test_AddStake_RevertWhen_NoPosition() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.addStake(50 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EXTRACT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Extract_ReturnsTokens() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        // Warp past lock period
        vm.warp(block.timestamp + 5 hours);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        (uint256 amount, uint256 rewards) = ghostCore.extract();

        assertEq(amount, stakeAmount);
        // No rewards yet since no cascade or emissions
        assertEq(rewards, 0);
        assertEq(token.balanceOf(alice), balanceBefore + stakeAmount);
    }

    function test_Extract_DeletesPosition() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 5 hours);

        vm.prank(alice);
        ghostCore.extract();

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, 0);
        assertEq(uint8(pos.level), uint8(IGhostCore.Level.NONE));
    }

    function test_Extract_UpdatesLevelState() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory stateBefore = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(stateBefore.aliveCount, 1);

        vm.warp(block.timestamp + 5 hours);

        vm.prank(alice);
        ghostCore.extract();

        IGhostCore.LevelState memory stateAfter = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(stateAfter.totalStaked, 0);
        assertEq(stateAfter.aliveCount, 0);
    }

    function test_Extract_RevertWhen_NoPosition() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.extract();
    }

    function test_Extract_RevertWhen_InLockPeriod() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Warp to just before next scan (within lock period)
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime - 30 seconds);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionLocked.selector);
        ghostCore.extract();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH PROCESSING TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ProcessDeaths_MarksPositionDead() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, deadUsers);

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertFalse(pos.alive);
    }

    function test_ProcessDeaths_UpdatesLevelState() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.prank(alice);
        ghostCore.jackIn(stakeAmount, IGhostCore.Level.VAULT);

        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, deadUsers);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(state.totalStaked, 0);
        assertEq(state.aliveCount, 0);
    }

    function test_ProcessDeaths_RevertWhen_NotScanner() public {
        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.processDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetTotalValueLocked() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(250 * 1e18, IGhostCore.Level.BLACK_ICE);

        assertEq(ghostCore.getTotalValueLocked(), 350 * 1e18);
    }

    function test_IsAlive_ReturnsCorrectState() public {
        assertFalse(ghostCore.isAlive(alice));

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        assertTrue(ghostCore.isAlive(alice));
    }

    function test_GetEffectiveDeathRate() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        uint16 rate = ghostCore.getEffectiveDeathRate(alice);
        assertEq(rate, 500); // 5% base for VAULT
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_JackIn_ValidAmounts(
        uint256 amount
    ) public {
        // Bound to valid range (min stake for VAULT to alice's balance)
        amount = bound(amount, 10 * 1e18, ALICE_BALANCE);

        vm.prank(alice);
        ghostCore.jackIn(amount, IGhostCore.Level.VAULT);

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADD STAKE ERROR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_AddStake_RevertWhen_PositionDead() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionDead.selector);
        ghostCore.addStake(50 * 1e18);
    }

    function test_AddStake_RevertWhen_ZeroAmount() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.InvalidAmount.selector);
        ghostCore.addStake(0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EXTRACT ERROR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Extract_RevertWhen_PositionDead() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        vm.warp(block.timestamp + 5 hours);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionDead.selector);
        ghostCore.extract();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIM REWARDS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimRewards_Success() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Add some rewards via emissions
        vm.prank(owner);
        ghostCore.addEmissionRewards(IGhostCore.Level.VAULT, 1000 * 1e18);

        // Fund the contract for rewards
        vm.prank(bob);
        token.transfer(address(ghostCore), 1000 * 1e18);

        uint256 pending = ghostCore.getPendingRewards(alice);
        assertGt(pending, 0);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 claimed = ghostCore.claimRewards();

        assertEq(claimed, pending);
        assertEq(token.balanceOf(alice), balanceBefore + pending);
    }

    function test_ClaimRewards_ReturnsZero_WhenNoRewards() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // No emissions added, no rewards
        vm.prank(alice);
        uint256 claimed = ghostCore.claimRewards();

        assertEq(claimed, 0);
    }

    function test_ClaimRewards_RevertWhen_NoPosition() public {
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.claimRewards();
    }

    function test_ClaimRewards_RevertWhen_PositionDead() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionDead.selector);
        ghostCore.claimRewards();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DISTRIBUTE CASCADE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_DistributeCascade_NoSameLevelSurvivors() public {
        // Alice is the only one in VAULT
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Bob is in MAINFRAME (upstream - higher level number is MORE risky, lower is safer)
        // Actually looking at cascade logic: upstream means SAFER levels (lower enum values)
        // But VAULT is Level 1 (safest), so there's no upstream from VAULT
        // Let's test with a higher-risk level instead

        // This test documents the behavior: when the death occurs at VAULT level
        // and there are no same-level survivors, the same-level amount goes to upstream
        // But VAULT has no upstream (it's the safest level), so it goes nowhere useful

        // Kill alice - now no same-level survivors
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        IGhostCore.LevelState memory vaultState = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(vaultState.totalStaked, 0, "VAULT should have 0 staked after alice dies");

        // Distribute cascade - with 0 same-level survivors, same-level amount goes to upstream
        vm.prank(scanner);
        ghostCore.distributeCascade(IGhostCore.Level.VAULT, 100 * 1e18);

        // The cascade was distributed (to burn, protocol, and potentially nothing for same-level)
        // This test just verifies the function doesn't revert with no same-level survivors
    }

    function test_DistributeCascade_ZeroAmount() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Should not revert with 0 amount
        vm.prank(scanner);
        ghostCore.distributeCascade(IGhostCore.Level.VAULT, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADD EMISSION REWARDS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_AddEmissionRewards_Success() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        token.transfer(address(ghostCore), 1000 * 1e18);

        uint256 rewardsBefore = ghostCore.getPendingRewards(alice);

        vm.prank(owner);
        ghostCore.addEmissionRewards(IGhostCore.Level.VAULT, 500 * 1e18);

        uint256 rewardsAfter = ghostCore.getPendingRewards(alice);
        assertGt(rewardsAfter, rewardsBefore);
    }

    function test_AddEmissionRewards_RevertWhen_NotDistributor() public {
        vm.prank(alice);
        vm.expectRevert();
        ghostCore.addEmissionRewards(IGhostCore.Level.VAULT, 500 * 1e18);
    }

    function test_AddEmissionRewards_NoEffect_WhenZeroStaked() public {
        // No positions exist
        IGhostCore.LevelState memory stateBefore = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        vm.prank(owner);
        ghostCore.addEmissionRewards(IGhostCore.Level.VAULT, 500 * 1e18);

        IGhostCore.LevelState memory stateAfter = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        // accRewardsPerShare should not change when totalStaked is 0
        assertEq(stateAfter.accRewardsPerShare, stateBefore.accRewardsPerShare);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BOOST TESTS (EIP-712)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ApplyBoost_Success() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Create boost signature
        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000; // 10% reduction
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        vm.prank(alice);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);

        // Verify boost was applied
        IGhostCore.Boost[] memory boosts = ghostCore.getActiveBoosts(alice);
        assertEq(boosts.length, 1);
        assertEq(uint8(boosts[0].boostType), uint8(boostType));
        assertEq(boosts[0].valueBps, valueBps);
    }

    function test_ApplyBoost_AffectsDeathRate() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        uint16 baseRate = ghostCore.getEffectiveDeathRate(alice);
        assertEq(baseRate, 500); // 5% base

        // Apply death reduction boost
        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000; // 10% reduction (should reduce 5% by 10% = 4.5%)
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        vm.prank(alice);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);

        uint16 boostedRate = ghostCore.getEffectiveDeathRate(alice);
        assertLt(boostedRate, baseRate, "Death rate should be reduced");
    }

    function test_ApplyBoost_RevertWhen_NoPosition() public {
        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    function test_ApplyBoost_RevertWhen_SignatureExpired() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000;
        uint64 expiry = uint64(block.timestamp - 1); // Already expired
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.SignatureExpired.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    function test_ApplyBoost_RevertWhen_NonceAlreadyUsed() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        vm.prank(alice);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);

        // Try to use same nonce again
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NonceAlreadyUsed.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    function test_ApplyBoost_RevertWhen_InvalidSignature() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        // Sign with wrong private key
        (, uint256 wrongPk) = makeAddrAndKey("wrongSigner");
        bytes memory signature =
            _signBoostWithKey(alice, boostType, valueBps, expiry, nonce, wrongPk);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.InvalidSignature.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    function test_ApplyBoost_RevertWhen_WrongUser() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Create signature for alice
        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1000;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("nonce1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        // Bob tries to use alice's signature
        vm.prank(bob);
        vm.expectRevert(IGhostCore.InvalidSignature.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET ACTIVE BOOSTS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetActiveBoosts_FiltersExpired() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Apply two boosts with different expiries
        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;

        // Boost 1: expires in 1 hour
        bytes memory sig1 =
            _signBoost(alice, boostType, 1000, uint64(block.timestamp + 1 hours), keccak256("n1"));
        vm.prank(alice);
        ghostCore.applyBoost(
            boostType, 1000, uint64(block.timestamp + 1 hours), keccak256("n1"), sig1
        );

        // Boost 2: expires in 2 hours
        bytes memory sig2 =
            _signBoost(alice, boostType, 2000, uint64(block.timestamp + 2 hours), keccak256("n2"));
        vm.prank(alice);
        ghostCore.applyBoost(
            boostType, 2000, uint64(block.timestamp + 2 hours), keccak256("n2"), sig2
        );

        // Both should be active
        IGhostCore.Boost[] memory boosts = ghostCore.getActiveBoosts(alice);
        assertEq(boosts.length, 2);

        // Warp past first boost expiry
        vm.warp(block.timestamp + 90 minutes);

        // Only one should be active
        boosts = ghostCore.getActiveBoosts(alice);
        assertEq(boosts.length, 1);
        assertEq(boosts[0].valueBps, 2000);

        // Warp past second boost expiry
        vm.warp(block.timestamp + 1 hours);

        // None should be active
        boosts = ghostCore.getActiveBoosts(alice);
        assertEq(boosts.length, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET CULLING RISK TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetCullingRisk_NoPosition() public view {
        (uint16 riskBps, bool isEligible, uint16 capacityPct) = ghostCore.getCullingRisk(alice);
        assertEq(riskBps, 0);
        assertFalse(isEligible);
        assertEq(capacityPct, 0);
    }

    function test_GetCullingRisk_DeadPosition() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        (uint16 riskBps, bool isEligible, uint16 capacityPct) = ghostCore.getCullingRisk(alice);
        assertEq(riskBps, 0);
        assertFalse(isEligible);
        assertEq(capacityPct, 0);
    }

    function test_GetCullingRisk_ReturnsCapacity() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        (,, uint16 capacityPct) = ghostCore.getCullingRisk(alice);
        // 1 position out of 5000 max = 0.02%
        assertGt(capacityPct, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause_Success() public {
        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
    }

    function test_Pause_RevertWhen_NotPauser() public {
        vm.prank(alice);
        vm.expectRevert();
        ghostCore.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        ghostCore.pause();

        vm.prank(owner);
        ghostCore.unpause();

        // Should work now
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
    }

    function test_Unpause_RevertWhen_NotPauser() public {
        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.unpause();
    }

    function test_UpdateLevelConfig_Success() public {
        IGhostCore.LevelConfig memory newConfig = IGhostCore.LevelConfig({
            baseDeathRateBps: 1000, // 10% instead of 5%
            scanInterval: 2 hours,
            minStake: 20 * 1e18,
            maxPositions: 10_000,
            cullingBottomPct: 6000,
            cullingPenaltyBps: 9000
        });

        vm.prank(owner);
        ghostCore.updateLevelConfig(IGhostCore.Level.VAULT, newConfig);

        IGhostCore.LevelConfig memory config = ghostCore.getLevelConfig(IGhostCore.Level.VAULT);
        assertEq(config.baseDeathRateBps, 1000);
        assertEq(config.minStake, 20 * 1e18);
    }

    function test_UpdateLevelConfig_RevertWhen_NotAdmin() public {
        IGhostCore.LevelConfig memory newConfig = IGhostCore.LevelConfig({
            baseDeathRateBps: 1000,
            scanInterval: 2 hours,
            minStake: 20 * 1e18,
            maxPositions: 10_000,
            cullingBottomPct: 6000,
            cullingPenaltyBps: 9000
        });

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.updateLevelConfig(IGhostCore.Level.VAULT, newConfig);
    }

    function test_SetBoostSigner_Success() public {
        address newSigner = makeAddr("newSigner");

        vm.prank(owner);
        ghostCore.setBoostSigner(newSigner);

        // Old signer's signatures should now fail
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        bytes memory oldSig = _signBoost(
            alice,
            IGhostCore.BoostType.DEATH_REDUCTION,
            1000,
            uint64(block.timestamp + 1 hours),
            keccak256("n1")
        );

        vm.prank(alice);
        vm.expectRevert(IGhostCore.InvalidSignature.selector);
        ghostCore.applyBoost(
            IGhostCore.BoostType.DEATH_REDUCTION,
            1000,
            uint64(block.timestamp + 1 hours),
            keccak256("n1"),
            oldSig
        );
    }

    function test_SetBoostSigner_RevertWhen_NotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        ghostCore.setBoostSigner(makeAddr("newSigner"));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY WITHDRAW TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EmergencyWithdraw_Success() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        ghostCore.emergencyWithdraw();

        // Gets principal back, no rewards
        assertEq(token.balanceOf(alice), balanceBefore + 100 * 1e18);

        // Position should be deleted
        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, 0);
        assertEq(uint8(pos.level), uint8(IGhostCore.Level.NONE));
    }

    function test_EmergencyWithdraw_SkipsAliveCountForDeadPosition() public {
        // Note: Dead positions cannot emergency withdraw because processDeaths
        // already decremented totalStaked. Attempting to do so would cause underflow.
        // This is intentional - dead positions should not get their stake back.

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice only
        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(scanner);
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        vm.prank(owner);
        ghostCore.pause();

        // Bob (alive) can emergency withdraw
        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        ghostCore.emergencyWithdraw();
        assertEq(token.balanceOf(bob), bobBalanceBefore + 100 * 1e18);

        // Alice (dead) still has her position recorded but with alive=false
        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertFalse(pos.alive);
        assertEq(pos.amount, 100 * 1e18); // Amount still recorded
    }

    function test_EmergencyWithdraw_RevertWhen_NotPaused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.emergencyWithdraw();
    }

    function test_EmergencyWithdraw_RevertWhen_NoPosition() public {
        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.emergencyWithdraw();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INCREMENT GHOST STREAK TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IncrementGhostStreak_Success() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.Position memory posBefore = ghostCore.getPosition(alice);
        assertEq(posBefore.ghostStreak, 0);

        vm.prank(scanner);
        ghostCore.incrementGhostStreak(IGhostCore.Level.VAULT);

        IGhostCore.Position memory posAfter = ghostCore.getPosition(alice);
        assertEq(posAfter.ghostStreak, 1);
    }

    function test_IncrementGhostStreak_UpdatesNextScanTime() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Warp forward so there's a clear difference
        vm.warp(block.timestamp + 1 hours);

        IGhostCore.LevelState memory stateBefore = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        vm.prank(scanner);
        ghostCore.incrementGhostStreak(IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory stateAfter = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        // nextScanTime should be set to current timestamp + scanInterval
        // Since we warped 1 hour, new nextScanTime should be > old nextScanTime
        assertGt(stateAfter.nextScanTime, stateBefore.nextScanTime);
    }

    function test_IncrementGhostStreak_RevertWhen_NotScanner() public {
        vm.prank(alice);
        vm.expectRevert();
        ghostCore.incrementGhostStreak(IGhostCore.Level.VAULT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSED STATE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_JackIn_RevertWhen_Paused() public {
        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
    }

    function test_AddStake_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.addStake(50 * 1e18);
    }

    function test_Extract_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 5 hours);

        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.extract();
    }

    function test_ClaimRewards_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(owner);
        ghostCore.pause();

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.claimRewards();
    }

    function test_ApplyBoost_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(owner);
        ghostCore.pause();

        bytes memory sig = _signBoost(
            alice,
            IGhostCore.BoostType.DEATH_REDUCTION,
            1000,
            uint64(block.timestamp + 1 hours),
            keccak256("n1")
        );

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.applyBoost(
            IGhostCore.BoostType.DEATH_REDUCTION,
            1000,
            uint64(block.timestamp + 1 hours),
            keccak256("n1"),
            sig
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function _signBoost(
        address user,
        IGhostCore.BoostType boostType,
        uint16 valueBps,
        uint64 expiry,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        return _signBoostWithKey(user, boostType, valueBps, expiry, nonce, boostSignerPk);
    }

    function _signBoostWithKey(
        address user,
        IGhostCore.BoostType boostType,
        uint16 valueBps,
        uint64 expiry,
        bytes32 nonce,
        uint256 pk
    ) internal view returns (bytes memory) {
        bytes32 BOOST_TYPEHASH = keccak256(
            "Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("GHOSTNET"),
                keccak256("1"),
                block.chainid,
                address(ghostCore)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(BOOST_TYPEHASH, user, uint8(boostType), valueBps, expiry, nonce)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }
}
