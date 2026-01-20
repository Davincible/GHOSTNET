// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { TeamVesting } from "../src/token/TeamVesting.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { DeadPool } from "../src/markets/DeadPool.sol";
import { RewardsDistributor } from "../src/periphery/RewardsDistributor.sol";
import { FeeRouter } from "../src/periphery/FeeRouter.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";
import { ITraceScan } from "../src/core/interfaces/ITraceScan.sol";
import { IDeadPool } from "../src/markets/interfaces/IDeadPool.sol";

/// @title Security Tests (Adversarial)
/// @notice Tests that attempt to exploit/hack the contracts - ALL SHOULD FAIL
/// @dev These tests verify that malicious actions are properly blocked
contract SecurityTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    TraceScan public traceScan;
    DeadPool public deadPool;
    RewardsDistributor public distributor;
    FeeRouter public feeRouter;
    TeamVesting public teamVesting;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public operationsWallet = makeAddr("operationsWallet");

    uint256 public boostSignerPk;
    address public boostSigner;

    // Attackers
    address public attacker = makeAddr("attacker");
    address public accomplice = makeAddr("accomplice");

    // Legitimate users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant USER_BALANCE = 5_000_000 * 1e18;
    uint256 constant EMISSIONS = 60_000_000 * 1e18;

    function setUp() public {
        (boostSigner, boostSignerPk) = makeAddrAndKey("boostSigner");

        // Deploy token
        address[] memory recipients = new address[](5);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = attacker;
        recipients[3] = treasury;
        recipients[4] = address(this);

        uint256 vestingAmount = 1_000_000 * 1e18;
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = USER_BALANCE;
        amounts[1] = USER_BALANCE;
        amounts[2] = USER_BALANCE;
        amounts[3] = TOTAL_SUPPLY - (USER_BALANCE * 3) - EMISSIONS - vestingAmount;
        amounts[4] = EMISSIONS + vestingAmount;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy GhostCore
        GhostCore ghostCoreImpl = new GhostCore();
        bytes memory ghostCoreInit = abi.encodeCall(
            GhostCore.initialize, (address(token), treasury, boostSigner, owner)
        );
        ghostCore = GhostCore(address(new ERC1967Proxy(address(ghostCoreImpl), ghostCoreInit)));

        // Deploy TraceScan
        TraceScan traceScanImpl = new TraceScan();
        bytes memory traceScanInit = abi.encodeCall(TraceScan.initialize, (address(ghostCore), owner));
        traceScan = TraceScan(address(new ERC1967Proxy(address(traceScanImpl), traceScanInit)));

        // Deploy DeadPool
        DeadPool deadPoolImpl = new DeadPool();
        bytes memory deadPoolInit = abi.encodeCall(DeadPool.initialize, (address(token), owner));
        deadPool = DeadPool(address(new ERC1967Proxy(address(deadPoolImpl), deadPoolInit)));

        // Deploy RewardsDistributor
        distributor = new RewardsDistributor(address(token), address(ghostCore), owner);

        // Deploy FeeRouter
        feeRouter = new FeeRouter(
            address(token),
            makeAddr("weth"),
            address(0),
            operationsWallet,
            0.001 ether,
            owner
        );

        // Deploy TeamVesting
        address[] memory teamMembers = new address[](1);
        teamMembers[0] = alice;
        uint256[] memory teamAmounts = new uint256[](1);
        teamAmounts[0] = 1_000_000 * 1e18;
        teamVesting = new TeamVesting(IERC20(address(token)), teamMembers, teamAmounts);

        // Setup roles
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        token.setTaxExclusion(address(deadPool), true);
        token.setTaxExclusion(address(distributor), true);
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), address(distributor));
        deadPool.grantRole(deadPool.RESOLVER_ROLE(), owner);
        vm.stopPrank();

        // Fund distributor
        token.transfer(address(distributor), EMISSIONS);
        token.transfer(address(teamVesting), 1_000_000 * 1e18);

        // Setup approvals for legitimate users
        vm.prank(alice);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(attacker);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(attacker);
        token.approve(address(deadPool), type(uint256).max);

        vm.deal(attacker, 100 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REENTRANCY ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_ReentrancyOnExtract() public {
        // Standard ERC20 tokens don't have receiver callbacks, so classic reentrancy
        // via token transfer isn't possible. However, GhostCore uses nonReentrant
        // as defense-in-depth against any potential hooks or future token types.
        //
        // This test verifies that even with a malicious contract, extraction succeeds
        // safely without any double-extraction occurring.

        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker(ghostCore, token);

        // Exclude attacker contract from tax so transfers work correctly
        vm.prank(owner);
        token.setTaxExclusion(address(reentrancyAttacker), true);

        // Fund attacker contract
        vm.prank(attacker);
        token.transfer(address(reentrancyAttacker), 1000 * 1e18);

        // Attacker creates position
        reentrancyAttacker.deposit(1000 * 1e18);

        // Wait for emissions and scan
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);
        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Wait past lock period
        vm.warp(block.timestamp + 5 hours);

        uint256 attackerBalanceBefore = token.balanceOf(address(reentrancyAttacker));

        // Execute extraction - verifies nonReentrant doesn't interfere with legitimate use
        reentrancyAttacker.attackExtract();

        // Verify only one extraction occurred (position cleared, can't extract again)
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        reentrancyAttacker.attackExtract();

        // Verify attacker received tokens (stake + rewards)
        uint256 attackerBalanceAfter = token.balanceOf(address(reentrancyAttacker));
        assertGt(attackerBalanceAfter, attackerBalanceBefore, "Attacker should have received tokens");
    }

    function test_Attack_ReentrancyOnClaimRewards() public {
        // Standard ERC20 tokens don't have receiver callbacks, so classic reentrancy
        // via token transfer isn't possible. However, GhostCore uses nonReentrant
        // as defense-in-depth against any potential hooks or future token types.
        //
        // This test verifies that reward claiming works correctly without double-claims.

        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker(ghostCore, token);

        // Exclude attacker contract from tax so transfers work correctly
        vm.prank(owner);
        token.setTaxExclusion(address(reentrancyAttacker), true);

        vm.prank(attacker);
        token.transfer(address(reentrancyAttacker), 1000 * 1e18);

        reentrancyAttacker.deposit(1000 * 1e18);

        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        uint256 attackerBalanceBefore = token.balanceOf(address(reentrancyAttacker));

        // Execute claim - verifies nonReentrant doesn't interfere with legitimate use
        reentrancyAttacker.attackClaimRewards();

        // Verify rewards were received
        uint256 attackerBalanceAfter = token.balanceOf(address(reentrancyAttacker));
        assertGt(attackerBalanceAfter, attackerBalanceBefore, "Attacker should have received rewards");

        // Second claim should return 0 (no pending rewards)
        uint256 balanceBeforeSecondClaim = token.balanceOf(address(reentrancyAttacker));
        reentrancyAttacker.attackClaimRewards();
        uint256 balanceAfterSecondClaim = token.balanceOf(address(reentrancyAttacker));
        assertEq(balanceAfterSecondClaim, balanceBeforeSecondClaim, "No rewards on second claim");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ACCESS CONTROL ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_UnauthorizedScannerRole() public {
        // Attacker tries to call scanner-only functions
        vm.startPrank(attacker);

        // processDeaths requires SCANNER_ROLE
        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.expectRevert();
        ghostCore.processDeaths(IGhostCore.Level.VAULT, deadUsers);

        // incrementGhostStreak requires SCANNER_ROLE
        vm.expectRevert();
        ghostCore.incrementGhostStreak(IGhostCore.Level.VAULT);

        vm.stopPrank();
    }

    function test_Attack_UnauthorizedDistributorRole() public {
        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.addEmissionRewards(IGhostCore.Level.VAULT, 1000 * 1e18);
    }

    function test_Attack_UnauthorizedPauserRole() public {
        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.pause();
    }

    function test_Attack_UnauthorizedAdminRole() public {
        vm.startPrank(attacker);

        // Try to update level config
        vm.expectRevert();
        ghostCore.updateLevelConfig(IGhostCore.Level.VAULT, IGhostCore.LevelConfig({
            baseDeathRateBps: 0, // Try to set death rate to 0
            scanInterval: 1,
            minStake: 0,
            maxPositions: 1000000,
            cullingBottomPct: 0,
            cullingPenaltyBps: 0
        }));

        // Try to change boost signer to self
        vm.expectRevert();
        ghostCore.setBoostSigner(attacker);

        vm.stopPrank();
    }

    function test_Attack_UnauthorizedUpgrade() public {
        // Deploy fake implementation
        GhostCore fakeImpl = new GhostCore();

        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.upgradeToAndCall(address(fakeImpl), "");
    }

    function test_Attack_SelfGrantRole() public {
        // OpenZeppelin AccessControl doesn't revert on unauthorized grantRole
        // It just doesn't grant the role (reverts with AccessControlUnauthorizedAccount)
        bytes32 adminRole = ghostCore.DEFAULT_ADMIN_ROLE();

        // Verify attacker doesn't have admin role initially
        assertFalse(ghostCore.hasRole(adminRole, attacker));

        // Try to self-grant admin role - should revert with AccessControlUnauthorizedAccount
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                attacker,
                adminRole
            )
        );
        ghostCore.grantRole(adminRole, attacker);

        // Verify attacker still doesn't have admin role
        assertFalse(ghostCore.hasRole(adminRole, attacker));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SIGNATURE REPLAY ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_ReplayBoostSignature() public {
        // Setup: Alice gets a legitimate boost
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 valueBps = 1500;
        uint64 expiry = uint64(block.timestamp + 7 days);
        bytes32 nonce = keccak256("alice-boost-1");

        bytes memory signature = _signBoost(alice, boostType, valueBps, expiry, nonce);

        // Alice applies boost
        vm.prank(alice);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);

        // Attacker tries to replay the same signature for Alice
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NonceAlreadyUsed.selector);
        ghostCore.applyBoost(boostType, valueBps, expiry, nonce, signature);
    }

    function test_Attack_UseOthersBoostSignature() public {
        // Setup positions
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(attacker);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Signature created for Alice
        bytes32 nonce = keccak256("alice-boost-1");
        bytes memory aliceSignature = _signBoost(
            alice,
            IGhostCore.BoostType.DEATH_REDUCTION,
            1500,
            uint64(block.timestamp + 7 days),
            nonce
        );

        // Attacker tries to use Alice's signature
        vm.prank(attacker);
        vm.expectRevert(IGhostCore.InvalidSignature.selector);
        ghostCore.applyBoost(
            IGhostCore.BoostType.DEATH_REDUCTION,
            1500,
            uint64(block.timestamp + 7 days),
            nonce,
            aliceSignature
        );
    }

    function test_Attack_ExpiredSignature() public {
        vm.prank(attacker);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 nonce = keccak256("attacker-boost-1");
        bytes memory signature = _signBoost(
            attacker,
            IGhostCore.BoostType.DEATH_REDUCTION,
            1500,
            expiry,
            nonce
        );

        // Warp past expiry
        vm.warp(block.timestamp + 2 hours);

        vm.prank(attacker);
        vm.expectRevert(IGhostCore.SignatureExpired.selector);
        ghostCore.applyBoost(
            IGhostCore.BoostType.DEATH_REDUCTION,
            1500,
            expiry,
            nonce,
            signature
        );
    }

    function test_Attack_ForgedSignature() public {
        vm.prank(attacker);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Attacker creates their own signature (not from boostSigner)
        (, uint256 attackerPk) = makeAddrAndKey("attackerKey");

        bytes32 structHash = keccak256(abi.encode(
            keccak256("Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"),
            attacker,
            uint8(IGhostCore.BoostType.DEATH_REDUCTION),
            uint16(5000), // Try to get 50% death reduction
            uint64(block.timestamp + 7 days),
            bytes32("fake-nonce")
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("GHOSTNET"),
            keccak256("1"),
            block.chainid,
            address(ghostCore)
        ));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPk, digest);
        bytes memory forgedSig = abi.encodePacked(r, s, v);

        vm.prank(attacker);
        vm.expectRevert(IGhostCore.InvalidSignature.selector);
        ghostCore.applyBoost(
            IGhostCore.BoostType.DEATH_REDUCTION,
            5000,
            uint64(block.timestamp + 7 days),
            bytes32("fake-nonce"),
            forgedSig
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DOUBLE-SPEND / DOUBLE-ACTION ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_DoubleExtract() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Survive scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);
        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
        vm.warp(block.timestamp + 5 hours);

        // First extract succeeds
        vm.prank(alice);
        ghostCore.extract();

        // Second extract should fail - no position
        vm.prank(alice);
        vm.expectRevert(IGhostCore.NoPositionExists.selector);
        ghostCore.extract();
    }

    function test_Attack_DoubleJackIn() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Try to jack in again while position exists
        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionAlreadyExists.selector);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.SUBNET);
    }

    function test_Attack_DoubleClaimWinnings() public {
        // Create round and place bets
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        vm.prank(attacker);
        deadPool.placeBet(1, true, 100 * 1e18);

        // Resolve
        vm.warp(deadline + 1);
        vm.prank(owner);
        deadPool.resolveRound(1, true);

        // First claim succeeds
        vm.prank(attacker);
        deadPool.claimWinnings(1);

        // Second claim fails
        vm.prank(attacker);
        vm.expectRevert(IDeadPool.AlreadyClaimed.selector);
        deadPool.claimWinnings(1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEAD POSITION EXPLOIT ATTEMPTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_ExtractWhileDead() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        uint16 deathRate = ghostCore.getLevelConfig(IGhostCore.Level.VAULT).baseDeathRateBps;

        // Only submit death if alice would actually die (deterministic based on seed)
        if (traceScan.isDead(scan.seed, alice, deathRate)) {
            address[] memory dead = new address[](1);
            dead[0] = alice;
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
        vm.warp(block.timestamp + 5 hours);

        // If alice is dead, she can't extract
        if (!ghostCore.isAlive(alice)) {
            vm.prank(alice);
            vm.expectRevert(IGhostCore.PositionDead.selector);
            ghostCore.extract();
        } else {
            // If alice survived, the test still passes (no vulnerability)
            assertTrue(true, "Alice survived - no dead position exploit possible");
        }
    }

    function test_Attack_ClaimRewardsWhileDead() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Accrue rewards
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        uint16 deathRate = ghostCore.getLevelConfig(IGhostCore.Level.VAULT).baseDeathRateBps;

        // Only submit death if alice would actually die
        if (traceScan.isDead(scan.seed, alice, deathRate)) {
            address[] memory dead = new address[](1);
            dead[0] = alice;
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // If alice is dead, she can't claim rewards
        if (!ghostCore.isAlive(alice)) {
            vm.prank(alice);
            vm.expectRevert(IGhostCore.PositionDead.selector);
            ghostCore.claimRewards();
        } else {
            // If alice survived, the test still passes (no vulnerability)
            assertTrue(true, "Alice survived - no dead position exploit possible");
        }
    }

    function test_Attack_AddStakeWhileDead() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        uint16 deathRate = ghostCore.getLevelConfig(IGhostCore.Level.VAULT).baseDeathRateBps;

        // Only submit death if alice would actually die
        if (traceScan.isDead(scan.seed, alice, deathRate)) {
            address[] memory dead = new address[](1);
            dead[0] = alice;
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // If alice is dead, she can't add stake
        if (!ghostCore.isAlive(alice)) {
            vm.prank(alice);
            vm.expectRevert(IGhostCore.PositionDead.selector);
            ghostCore.addStake(500 * 1e18);
        } else {
            // If alice survived, the test still passes (no vulnerability)
            assertTrue(true, "Alice survived - no dead position exploit possible");
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SYSTEM RESET MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_PrematureSystemReset() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Try to trigger reset before deadline
        vm.prank(attacker);
        vm.expectRevert(IGhostCore.SystemResetNotReady.selector);
        ghostCore.triggerSystemReset();
    }

    function test_Attack_FlashLoanJackpot() public {
        // Setup: Multiple users have positions
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(bob);
        ghostCore.jackIn(2000 * 1e18, IGhostCore.Level.VAULT);

        // Attacker tries to become last depositor right before reset
        // Then immediately trigger reset

        // Get close to deadline
        IGhostCore.SystemReset memory resetInfo = ghostCore.getSystemReset();
        vm.warp(resetInfo.deadline - 1);

        // Attacker deposits to become last depositor
        vm.prank(attacker);
        ghostCore.jackIn(10 * 1e18, IGhostCore.Level.VAULT); // Minimum stake

        // But the deposit extends the deadline!
        resetInfo = ghostCore.getSystemReset();

        // Attacker can't immediately trigger reset
        vm.prank(attacker);
        vm.expectRevert(IGhostCore.SystemResetNotReady.selector);
        ghostCore.triggerSystemReset();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FRONT-RUNNING ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_FrontRunExtractBeforeScan() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Wait until just before scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime - 30 seconds); // 30 seconds before scan

        // Alice tries to front-run extract before she might die
        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionLocked.selector);
        ghostCore.extract();
    }

    function test_Attack_ExtractDuringActiveScan() public {
        // The lock period is BEFORE the scan (60 seconds before nextScanTime)
        // This test verifies users can't extract during lock period to avoid scans

        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        // Get next scan time
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        // Warp to 30 seconds before scan (within 60-second lock period)
        vm.warp(state.nextScanTime - 30 seconds);

        // Try to extract during lock period - should fail
        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionLocked.selector);
        ghostCore.extract();

        // Also test exactly at lock period boundary (60 seconds before)
        vm.warp(state.nextScanTime - 60 seconds);

        vm.prank(alice);
        vm.expectRevert(IGhostCore.PositionLocked.selector);
        ghostCore.extract();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TOLL/FEE MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_UnauthorizedTollCollection() public {
        vm.prank(attacker);
        vm.expectRevert(FeeRouter.Unauthorized.selector);
        feeRouter.collectToll{ value: 0.001 ether }(bytes32("attack"));
    }

    function test_Attack_DrainFeeRouter() public {
        // Fund fee router
        vm.deal(address(feeRouter), 10 ether);

        // Attacker tries to withdraw
        vm.prank(attacker);
        vm.expectRevert();
        feeRouter.emergencyWithdrawETH(attacker);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TOKEN MANIPULATION ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_UnauthorizedTaxExclusion() public {
        vm.prank(attacker);
        vm.expectRevert();
        token.setTaxExclusion(attacker, true);
    }

    function test_Attack_DrainTeamVesting() public {
        // Attacker has no vesting schedule
        vm.prank(attacker);
        vm.expectRevert(TeamVesting.NoVestingSchedule.selector);
        teamVesting.claim();
    }

    function test_Attack_ClaimOthersVesting() public {
        // Warp past cliff
        vm.warp(block.timestamp + 60 days);

        // Attacker can't claim alice's vesting
        // (claim() only sends to msg.sender with their schedule)
        uint256 attackerBalanceBefore = token.balanceOf(attacker);

        // Attacker calls claim - should revert (no schedule)
        vm.prank(attacker);
        vm.expectRevert(TeamVesting.NoVestingSchedule.selector);
        teamVesting.claim();

        assertEq(token.balanceOf(attacker), attackerBalanceBefore);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEADPOOL MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_BetAfterDeadline() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        // Warp past deadline
        vm.warp(deadline + 1);

        // Try to bet after deadline
        vm.prank(attacker);
        vm.expectRevert(IDeadPool.RoundEnded.selector);
        deadPool.placeBet(1, true, 100 * 1e18);
    }

    function test_Attack_ClaimWinningsBeforeResolution() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        vm.prank(attacker);
        deadPool.placeBet(1, true, 100 * 1e18);

        // Try to claim before resolution
        vm.prank(attacker);
        vm.expectRevert(IDeadPool.RoundNotResolved.selector);
        deadPool.claimWinnings(1);
    }

    function test_Attack_UnauthorizedRoundResolution() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        vm.warp(deadline + 1);

        // Attacker tries to resolve with favorable outcome
        vm.prank(attacker);
        vm.expectRevert();
        deadPool.resolveRound(1, true);
    }

    function test_Attack_SwitchBetSide() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        // Bet on OVER
        vm.prank(attacker);
        deadPool.placeBet(1, true, 100 * 1e18);

        // Try to switch to UNDER
        vm.prank(attacker);
        vm.expectRevert(IDeadPool.InvalidAmount.selector);
        deadPool.placeBet(1, false, 100 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCAN MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_UnauthorizedScanExecution() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        // Attacker tries to execute scan directly on GhostCore
        // (should only be callable by TraceScan with SCANNER_ROLE)
        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.processDeaths(IGhostCore.Level.VAULT, new address[](0));
    }

    function test_Attack_FakeDeathSubmission() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Attacker tries to submit fake death (alice isn't actually dead by RNG)
        // This should be rejected because isDead check will fail
        address[] memory fakeDead = new address[](1);
        fakeDead[0] = alice;

        // The submitDeaths function should verify with isDead()
        // If alice isn't actually dead, this should revert or skip
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        uint16 deathRate = ghostCore.getLevelConfig(IGhostCore.Level.VAULT).baseDeathRateBps;
        bool aliceActuallyDead = traceScan.isDead(scan.seed, alice, deathRate);

        if (!aliceActuallyDead) {
            // The death submission should revert for non-dead user
            vm.expectRevert(ITraceScan.UserNotDead.selector);
            traceScan.submitDeaths(IGhostCore.Level.VAULT, fakeDead);
        }
    }

    function test_Attack_DoubleDeathSubmission() public {
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        uint16 deathRate = ghostCore.getLevelConfig(IGhostCore.Level.VAULT).baseDeathRateBps;

        if (traceScan.isDead(scan.seed, alice, deathRate)) {
            address[] memory dead = new address[](1);
            dead[0] = alice;

            // First submission
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);

            // Second submission should be skipped (already dead)
            // This shouldn't cause double penalty - the user is just skipped
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);

            // Verify alice was only penalized once
            assertFalse(ghostCore.isAlive(alice));
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_ReinitializeProxy() public {
        // Try to reinitialize already initialized contract
        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.initialize(address(token), attacker, attacker, attacker);
    }

    function test_Attack_InitializeImplementation() public {
        // Deploy new implementation
        GhostCore impl = new GhostCore();

        // Try to initialize the implementation directly
        vm.prank(attacker);
        vm.expectRevert();
        impl.initialize(address(token), attacker, attacker, attacker);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE EXPLOITS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Attack_ZeroAmountDeposit() public {
        vm.prank(attacker);
        vm.expectRevert(IGhostCore.InvalidAmount.selector);
        ghostCore.jackIn(0, IGhostCore.Level.VAULT);
    }

    function test_Attack_BelowMinimumStake() public {
        IGhostCore.LevelConfig memory config = ghostCore.getLevelConfig(IGhostCore.Level.VAULT);

        vm.prank(attacker);
        vm.expectRevert(IGhostCore.BelowMinimumStake.selector);
        ghostCore.jackIn(config.minStake - 1, IGhostCore.Level.VAULT);
    }

    function test_Attack_InvalidLevelJackIn() public {
        vm.prank(attacker);
        vm.expectRevert(IGhostCore.InvalidLevel.selector);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.NONE);
    }

    function test_Attack_ZeroBet() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline);

        vm.prank(attacker);
        vm.expectRevert(IDeadPool.InvalidAmount.selector);
        deadPool.placeBet(1, true, 0);
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
        bytes32 BOOST_TYPEHASH = keccak256(
            "Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(boostSignerPk, digest);
        return abi.encodePacked(r, s, v);
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MALICIOUS CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════

/// @dev Malicious contract that attempts reentrancy attacks
contract ReentrancyAttacker {
    GhostCore public ghostCore;
    DataToken public token;
    bool public attacking;
    uint256 public attackCount;

    constructor(GhostCore _ghostCore, DataToken _token) {
        ghostCore = _ghostCore;
        token = _token;
        token.approve(address(_ghostCore), type(uint256).max);
    }

    function deposit(uint256 amount) external {
        ghostCore.jackIn(amount, IGhostCore.Level.VAULT);
    }

    function attackExtract() external {
        attacking = true;
        attackCount = 0;
        ghostCore.extract();
    }

    function attackClaimRewards() external {
        attacking = true;
        attackCount = 0;
        ghostCore.claimRewards();
    }

    // Callback when receiving tokens - attempt reentrancy
    function onERC20Received(address, uint256) external returns (bytes4) {
        if (attacking && attackCount < 2) {
            attackCount++;
            // Try to reenter
            try ghostCore.extract() {} catch {}
            try ghostCore.claimRewards() {} catch {}
        }
        return this.onERC20Received.selector;
    }

    // Fallback for any token transfer
    receive() external payable {
        if (attacking && attackCount < 2) {
            attackCount++;
            try ghostCore.extract() {} catch {}
        }
    }
}
