// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
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
        bytes memory initData = abi.encodeCall(
            GhostCore.initialize, (address(token), treasury, boostSigner, owner)
        );

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

    function testFuzz_JackIn_ValidAmounts(uint256 amount) public {
        // Bound to valid range (min stake for VAULT to alice's balance)
        amount = bound(amount, 10 * 1e18, ALICE_BALANCE);

        vm.prank(alice);
        ghostCore.jackIn(amount, IGhostCore.Level.VAULT);

        IGhostCore.Position memory pos = ghostCore.getPosition(alice);
        assertEq(pos.amount, amount);
    }
}
