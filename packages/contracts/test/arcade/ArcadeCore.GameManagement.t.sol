// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";

/// @title ArcadeCore Game Management Tests
/// @notice Comprehensive tests for game registration, configuration, and pause functionality
/// @dev These tests verify:
///      1. registerGame - Registration of new games with validation
///      2. unregisterGame - Removal of games from the registry
///      3. updateGameConfig - Configuration updates for registered games
///      4. pauseGame/unpauseGame - Per-game pause functionality
///
/// Coverage targets:
///      - Happy path: Normal operation succeeds
///      - Events: Correct events emitted with expected parameters
///      - Access control: Only GAME_ADMIN_ROLE can execute
///      - Edge cases: Boundary values, invalid inputs
///      - State transitions: Config changes, pause states
contract ArcadeCoreGameManagementTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    DataToken public token;
    ArcadeCore public arcadeCore;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");
    address public gameAdmin = makeAddr("gameAdmin");
    address public pauser = makeAddr("pauser");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    address public gameA = makeAddr("gameA");
    address public gameB = makeAddr("gameB");
    address public gameC = makeAddr("gameC");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant GAME_ADMIN_ROLE = keccak256("GAME_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 constant ALICE_BALANCE = 50_000_000 * 1e18;
    uint256 constant BOB_BALANCE = 50_000_000 * 1e18;
    uint256 constant SESSION_1 = 1;

    /// @notice Standard game configuration for tests
    function _standardConfig() internal pure returns (IArcadeCore.GameConfig memory) {
        return IArcadeCore.GameConfig({
            minEntry: 1 * 1e18,
            maxEntry: 10_000 * 1e18,
            rakeBps: 500, // 5% rake
            burnBps: 2000, // 20% of rake burned
            requiresPosition: false,
            paused: false
        });
    }

    function setUp() public {
        // Deploy token with initial distribution (must sum to 100M - DataToken's TOTAL_SUPPLY)
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ALICE_BALANCE;
        amounts[1] = BOB_BALANCE;

        token = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore implementation and proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData =
            abi.encodeCall(ArcadeCore.initialize, (address(token), address(0), treasury, admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude ArcadeCore from tax for cleaner math in tests
        vm.prank(admin);
        token.setTaxExclusion(address(arcadeCore), true);

        // Grant GAME_ADMIN_ROLE to gameAdmin (admin already has it from initialize)
        vm.prank(admin);
        arcadeCore.grantRole(GAME_ADMIN_ROLE, gameAdmin);

        // Grant PAUSER_ROLE to pauser
        vm.prank(admin);
        arcadeCore.grantRole(PAUSER_ROLE, pauser);

        // Approve token spending for players
        vm.prank(alice);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REGISTER GAME TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify basic game registration succeeds
    function test_RegisterGame_Success() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        // Verify game is registered
        assertTrue(arcadeCore.isGameRegistered(gameA), "Game should be registered");
    }

    /// @notice Verify GameRegistered event is emitted with correct parameters
    function test_RegisterGame_EmitsGameRegisteredEvent() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        vm.expectEmit(true, false, false, true);
        emit IArcadeCore.GameRegistered(gameA, config);

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);
    }

    /// @notice Verify all config fields are stored correctly
    function test_RegisterGame_SetsCorrectConfig() public {
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 5 * 1e18,
            maxEntry: 500 * 1e18,
            rakeBps: 300,
            burnBps: 5000,
            requiresPosition: true,
            paused: false
        });

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);

        assertEq(storedConfig.minEntry, 5 * 1e18, "minEntry mismatch");
        assertEq(storedConfig.maxEntry, 500 * 1e18, "maxEntry mismatch");
        assertEq(storedConfig.rakeBps, 300, "rakeBps mismatch");
        assertEq(storedConfig.burnBps, 5000, "burnBps mismatch");
        assertTrue(storedConfig.requiresPosition, "requiresPosition mismatch");
        assertFalse(storedConfig.paused, "paused mismatch");
    }

    /// @notice Verify registration fails with zero address
    function test_RegisterGame_RevertWhen_ZeroAddress() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        vm.prank(gameAdmin);
        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        arcadeCore.registerGame(address(0), config);
    }

    /// @notice Verify registration fails for already registered game
    function test_RegisterGame_RevertWhen_AlreadyRegistered() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        vm.expectRevert(IArcadeCore.GameAlreadyRegistered.selector);
        arcadeCore.registerGame(gameA, config);
        vm.stopPrank();
    }

    /// @notice Verify registration fails without GAME_ADMIN_ROLE
    function test_RegisterGame_RevertWhen_NotGameAdmin() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, GAME_ADMIN_ROLE
            )
        );
        arcadeCore.registerGame(gameA, config);
    }

    /// @notice Verify registration works when contract is paused
    /// @dev Game management functions don't have whenNotPaused modifier
    function test_RegisterGame_SucceedsWhen_ContractPaused() public {
        IArcadeCore.GameConfig memory config = _standardConfig();

        // Pause the contract
        vm.prank(pauser);
        arcadeCore.pause();

        // Registration should still work (admin functions not blocked by pause)
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        assertTrue(arcadeCore.isGameRegistered(gameA), "Game should be registered while paused");
    }

    /// @notice Verify registration with minEntry = 0 (allows free games)
    function test_RegisterGame_WithMinEntry_Zero() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.minEntry = 0;

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.minEntry, 0, "minEntry should be 0");
    }

    /// @notice Verify registration with maxEntry = 0 (no maximum limit)
    function test_RegisterGame_WithMaxEntry_Zero() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.maxEntry = 0; // No max limit

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.maxEntry, 0, "maxEntry should be 0 (no limit)");
    }

    /// @notice Verify registration with maxEntry < minEntry (invalid but stored as-is)
    /// @dev Contract doesn't validate this - enforcement happens at processEntry time
    function test_RegisterGame_WithMaxEntry_LessThan_MinEntry() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.minEntry = 100 * 1e18;
        config.maxEntry = 50 * 1e18; // Less than minEntry

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        // Config is stored as-is (validation at entry time)
        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.minEntry, 100 * 1e18);
        assertEq(storedConfig.maxEntry, 50 * 1e18);

        // But entries will fail because no valid amount exists
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, 75 * 1e18, SESSION_1); // Between min and max but exceeds max
    }

    /// @notice Verify registration with rakeBps = 0 (no rake)
    function test_RegisterGame_WithRakeBps_Zero() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 0; // No rake

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.rakeBps, 0, "rakeBps should be 0");

        // Verify no rake is taken on entry
        uint256 entryAmount = 100 * 1e18;
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);
        assertEq(netAmount, entryAmount, "Net amount should equal entry with 0% rake");
    }

    /// @notice Verify registration with rakeBps = 10000 (100% rake - all to protocol)
    function test_RegisterGame_WithRakeBps_Max() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 10_000; // 100% rake

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.rakeBps, 10_000, "rakeBps should be 10000");

        // Verify 100% rake (net amount = 0)
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        assertEq(netAmount, 0, "Net amount should be 0 with 100% rake");
    }

    /// @notice Verify registration with rakeBps > 10000 (invalid but stored)
    /// @dev Contract doesn't validate - could cause overflow issues at processEntry
    function test_RegisterGame_WithRakeBps_OverMax() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 15_000; // 150% rake (invalid)

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        // Config is stored (no validation)
        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.rakeBps, 15_000);

        // Entry will underflow (rake > amount) - Solidity 0.8+ reverts on underflow
        vm.prank(gameA);
        vm.expectRevert(); // Arithmetic underflow
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
    }

    /// @notice Verify registration with burnBps = 0 (no burn, all rake to treasury)
    function test_RegisterGame_WithBurnBps_Zero() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.burnBps = 0; // No burn

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.burnBps, 0, "burnBps should be 0");
    }

    /// @notice Verify registration with burnBps = 10000 (100% of rake burned)
    function test_RegisterGame_WithBurnBps_Max() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 500; // 5% rake
        config.burnBps = 10_000; // 100% of rake burned

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.burnBps, 10_000, "burnBps should be 10000");

        // Process entry and verify burn
        uint256 entryAmount = 100 * 1e18;
        uint256 expectedRake = (entryAmount * 500) / 10_000; // 5 DATA
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(gameA);
        arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Treasury should not receive rake (all burned)
        uint256 treasuryAfter = token.balanceOf(treasury);
        assertEq(treasuryAfter, treasuryBefore, "Treasury should not receive rake when 100% burned");

        // Verify burn occurred (check dead address)
        address deadAddress = 0x000000000000000000000000000000000000dEaD;
        assertEq(token.balanceOf(deadAddress), expectedRake, "Dead address should have burned tokens");
    }

    /// @notice Verify registration with requiresPosition = true
    function test_RegisterGame_WithRequiresPosition_True() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.requiresPosition = true;

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertTrue(storedConfig.requiresPosition, "requiresPosition should be true");

        // Note: With ghostCore = address(0), position check is skipped
        // Full test would require mock GhostCore
    }

    /// @notice Verify multiple games can be registered
    function test_RegisterGame_MultipleGames() public {
        IArcadeCore.GameConfig memory configA = _standardConfig();
        configA.rakeBps = 300;

        IArcadeCore.GameConfig memory configB = _standardConfig();
        configB.rakeBps = 500;

        IArcadeCore.GameConfig memory configC = _standardConfig();
        configC.rakeBps = 700;

        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, configA);
        arcadeCore.registerGame(gameB, configB);
        arcadeCore.registerGame(gameC, configC);
        vm.stopPrank();

        // Verify all games registered with unique configs
        assertTrue(arcadeCore.isGameRegistered(gameA));
        assertTrue(arcadeCore.isGameRegistered(gameB));
        assertTrue(arcadeCore.isGameRegistered(gameC));

        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 300);
        assertEq(arcadeCore.getGameConfig(gameB).rakeBps, 500);
        assertEq(arcadeCore.getGameConfig(gameC).rakeBps, 700);
    }

    /// @notice Fuzz test for registerGame with valid configurations
    function testFuzz_RegisterGame_ValidConfig(
        uint256 minEntry,
        uint256 maxEntry,
        uint16 rakeBps,
        uint16 burnBps
    ) public {
        // Bound to reasonable values
        minEntry = bound(minEntry, 0, 1_000_000 * 1e18);
        maxEntry = bound(maxEntry, 0, 10_000_000 * 1e18);
        rakeBps = uint16(bound(rakeBps, 0, 10_000)); // Keep within valid range
        burnBps = uint16(bound(burnBps, 0, 10_000));

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: minEntry,
            maxEntry: maxEntry,
            rakeBps: rakeBps,
            burnBps: burnBps,
            requiresPosition: false,
            paused: false
        });

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        IArcadeCore.GameConfig memory stored = arcadeCore.getGameConfig(gameA);
        assertEq(stored.minEntry, minEntry);
        assertEq(stored.maxEntry, maxEntry);
        assertEq(stored.rakeBps, rakeBps);
        assertEq(stored.burnBps, burnBps);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UNREGISTER GAME TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify basic game unregistration succeeds
    function test_UnregisterGame_Success() public {
        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());
        assertTrue(arcadeCore.isGameRegistered(gameA), "Game should be registered");

        arcadeCore.unregisterGame(gameA);
        assertFalse(arcadeCore.isGameRegistered(gameA), "Game should be unregistered");
        vm.stopPrank();
    }

    /// @notice Verify GameUnregistered event is emitted
    function test_UnregisterGame_EmitsGameUnregisteredEvent() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.expectEmit(true, false, false, false);
        emit IArcadeCore.GameUnregistered(gameA);

        vm.prank(gameAdmin);
        arcadeCore.unregisterGame(gameA);
    }

    /// @notice Verify config is deleted after unregistration
    function test_UnregisterGame_RemovesConfig() public {
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 100 * 1e18,
            maxEntry: 1000 * 1e18,
            rakeBps: 500,
            burnBps: 2000,
            requiresPosition: true,
            paused: true
        });

        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, config);
        arcadeCore.unregisterGame(gameA);
        vm.stopPrank();

        // Config should be zeroed out
        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.minEntry, 0);
        assertEq(storedConfig.maxEntry, 0);
        assertEq(storedConfig.rakeBps, 0);
        assertEq(storedConfig.burnBps, 0);
        assertFalse(storedConfig.requiresPosition);
        assertFalse(storedConfig.paused);
    }

    /// @notice Verify unregistration fails for non-registered game
    function test_UnregisterGame_RevertWhen_NotRegistered() public {
        vm.prank(gameAdmin);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.unregisterGame(gameA);
    }

    /// @notice Verify unregistration fails without GAME_ADMIN_ROLE
    function test_UnregisterGame_RevertWhen_NotGameAdmin() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, GAME_ADMIN_ROLE
            )
        );
        arcadeCore.unregisterGame(gameA);
    }

    /// @notice Verify unregistration works when contract is paused
    function test_UnregisterGame_SucceedsWhen_ContractPaused() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(pauser);
        arcadeCore.pause();

        vm.prank(gameAdmin);
        arcadeCore.unregisterGame(gameA);

        assertFalse(arcadeCore.isGameRegistered(gameA));
    }

    /// @notice Test behavior when unregistering game with active sessions
    /// @dev Active sessions remain accessible for settlement/refunds
    function test_UnregisterGame_WithActiveSessions() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        // Create an active session
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Verify session exists
        IArcadeCore.SessionRecord memory sessionBefore = arcadeCore.getSession(SESSION_1);
        assertEq(sessionBefore.game, gameA);
        assertTrue(sessionBefore.state == IArcadeCore.SessionState.ACTIVE);

        // Unregister game
        vm.prank(gameAdmin);
        arcadeCore.unregisterGame(gameA);

        // Session still exists (data not deleted)
        IArcadeCore.SessionRecord memory sessionAfter = arcadeCore.getSession(SESSION_1);
        assertEq(sessionAfter.game, gameA);

        // But game can no longer operate on it (not registered)
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);

        // Also cannot settle
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.settleSession(SESSION_1);
    }

    /// @notice Verify game can be re-registered after unregistration
    function test_UnregisterGame_ThenReregister() public {
        IArcadeCore.GameConfig memory config1 = _standardConfig();
        config1.rakeBps = 300;

        IArcadeCore.GameConfig memory config2 = _standardConfig();
        config2.rakeBps = 700;

        vm.startPrank(gameAdmin);

        // Register with first config
        arcadeCore.registerGame(gameA, config1);
        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 300);

        // Unregister
        arcadeCore.unregisterGame(gameA);
        assertFalse(arcadeCore.isGameRegistered(gameA));

        // Re-register with different config
        arcadeCore.registerGame(gameA, config2);
        assertTrue(arcadeCore.isGameRegistered(gameA));
        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 700);

        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UPDATE GAME CONFIG TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify basic config update succeeds
    function test_UpdateGameConfig_Success() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        IArcadeCore.GameConfig memory newConfig = IArcadeCore.GameConfig({
            minEntry: 10 * 1e18,
            maxEntry: 5000 * 1e18,
            rakeBps: 800,
            burnBps: 3000,
            requiresPosition: true,
            paused: false
        });

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        IArcadeCore.GameConfig memory storedConfig = arcadeCore.getGameConfig(gameA);
        assertEq(storedConfig.minEntry, 10 * 1e18);
        assertEq(storedConfig.maxEntry, 5000 * 1e18);
        assertEq(storedConfig.rakeBps, 800);
        assertEq(storedConfig.burnBps, 3000);
        assertTrue(storedConfig.requiresPosition);
    }

    /// @notice Verify GameConfigUpdated event is emitted
    function test_UpdateGameConfig_EmitsEvent() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        IArcadeCore.GameConfig memory newConfig = _standardConfig();
        newConfig.rakeBps = 1000;

        vm.expectEmit(true, false, false, true);
        emit IArcadeCore.GameConfigUpdated(gameA, newConfig);

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);
    }

    /// @notice Verify all config fields can be updated
    function test_UpdateGameConfig_UpdatesAllFields() public {
        IArcadeCore.GameConfig memory initialConfig = IArcadeCore.GameConfig({
            minEntry: 1 * 1e18,
            maxEntry: 100 * 1e18,
            rakeBps: 100,
            burnBps: 1000,
            requiresPosition: false,
            paused: false
        });

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, initialConfig);

        // Update to completely different values
        IArcadeCore.GameConfig memory newConfig = IArcadeCore.GameConfig({
            minEntry: 50 * 1e18,
            maxEntry: 5000 * 1e18,
            rakeBps: 900,
            burnBps: 5000,
            requiresPosition: true,
            paused: true
        });

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        IArcadeCore.GameConfig memory stored = arcadeCore.getGameConfig(gameA);
        assertEq(stored.minEntry, 50 * 1e18, "minEntry not updated");
        assertEq(stored.maxEntry, 5000 * 1e18, "maxEntry not updated");
        assertEq(stored.rakeBps, 900, "rakeBps not updated");
        assertEq(stored.burnBps, 5000, "burnBps not updated");
        assertTrue(stored.requiresPosition, "requiresPosition not updated");
        assertTrue(stored.paused, "paused not updated");
    }

    /// @notice Verify update fails for non-registered game
    function test_UpdateGameConfig_RevertWhen_NotRegistered() public {
        vm.prank(gameAdmin);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.updateGameConfig(gameA, _standardConfig());
    }

    /// @notice Verify update fails without GAME_ADMIN_ROLE
    function test_UpdateGameConfig_RevertWhen_NotGameAdmin() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, GAME_ADMIN_ROLE
            )
        );
        arcadeCore.updateGameConfig(gameA, _standardConfig());
    }

    /// @notice Verify update works when contract is paused
    function test_UpdateGameConfig_SucceedsWhen_ContractPaused() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(pauser);
        arcadeCore.pause();

        IArcadeCore.GameConfig memory newConfig = _standardConfig();
        newConfig.rakeBps = 1000;

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 1000);
    }

    /// @notice Verify config update doesn't affect existing active sessions
    /// @dev Sessions use config at entry time; mid-session updates apply to new entries only
    function test_UpdateGameConfig_MidSession() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 500; // 5%

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        // Create session with 5% rake
        vm.prank(gameA);
        uint256 netAmount1 = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Net should be 95% of 100 = 95 DATA
        assertApproxEqRel(netAmount1, 95 * 1e18, 0.01e18, "First entry rake incorrect");

        // Update rake to 10%
        IArcadeCore.GameConfig memory newConfig = config;
        newConfig.rakeBps = 1000;

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        // New entry in same session uses new rake
        vm.prank(gameA);
        uint256 netAmount2 = arcadeCore.processEntry(bob, 100 * 1e18, SESSION_1);

        // Net should be 90% of 100 = 90 DATA
        assertApproxEqRel(netAmount2, 90 * 1e18, 0.01e18, "Second entry rake incorrect");

        // Session prize pool should reflect both net amounts
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertApproxEqRel(session.prizePool, 185 * 1e18, 0.01e18, "Prize pool incorrect");
    }

    /// @notice Verify rake can be updated
    function test_UpdateGameConfig_NewRakeBps() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        IArcadeCore.GameConfig memory newConfig = _standardConfig();
        newConfig.rakeBps = 1500; // 15%

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 1500);

        // Verify new rake applies
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        assertApproxEqRel(netAmount, 85 * 1e18, 0.01e18, "15% rake should leave 85%");
    }

    /// @notice Verify min/max entry can be updated
    function test_UpdateGameConfig_NewMinMax() public {
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.minEntry = 10 * 1e18;
        config.maxEntry = 1000 * 1e18;

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);

        // Update to more restrictive
        IArcadeCore.GameConfig memory newConfig = config;
        newConfig.minEntry = 50 * 1e18;
        newConfig.maxEntry = 500 * 1e18;

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        // Old minimum should now fail
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, 25 * 1e18, SESSION_1);

        // New minimum should work
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 50 * 1e18, SESSION_1);

        // Old maximum should now fail
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, 600 * 1e18, 2);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSE GAME TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify game can be paused
    function test_PauseGame_Success() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        assertFalse(arcadeCore.getGameConfig(gameA).paused, "Game should not be paused initially");

        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        assertTrue(arcadeCore.getGameConfig(gameA).paused, "Game should be paused");
    }

    /// @notice Verify GameConfigUpdated event is emitted on pause
    function test_PauseGame_EmitsEvent() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        IArcadeCore.GameConfig memory expectedConfig = _standardConfig();
        expectedConfig.paused = true;

        vm.expectEmit(true, false, false, true);
        emit IArcadeCore.GameConfigUpdated(gameA, expectedConfig);

        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);
    }

    /// @notice Verify paused game blocks processEntry
    function test_PauseGame_BlocksProcessEntry() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
    }

    /// @notice Verify paused game still allows creditPayout for existing sessions
    function test_PauseGame_AllowsCreditPayout() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        // Create session before pause
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Pause game
        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        // creditPayout should still work (doesn't check game.paused)
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount / 2);
    }

    /// @notice Verify paused game still allows player withdrawal
    function test_PauseGame_AllowsWithdraw() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        // Create session and credit payout
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);

        // Pause game
        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        // Withdraw should work (player function, independent of game pause)
        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, netAmount / 2);
        assertEq(token.balanceOf(alice), balanceBefore + withdrawn);
    }

    /// @notice Verify pauseGame fails for non-registered game
    function test_PauseGame_RevertWhen_NotRegistered() public {
        vm.prank(gameAdmin);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.pauseGame(gameA);
    }

    /// @notice Verify pauseGame fails without GAME_ADMIN_ROLE
    function test_PauseGame_RevertWhen_NotGameAdmin() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, GAME_ADMIN_ROLE
            )
        );
        arcadeCore.pauseGame(gameA);
    }

    /// @notice Verify pausing already paused game still succeeds (idempotent)
    function test_PauseGame_WhenAlreadyPaused() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        vm.startPrank(gameAdmin);
        arcadeCore.pauseGame(gameA);
        assertTrue(arcadeCore.getGameConfig(gameA).paused);

        // Pause again - should succeed (idempotent)
        arcadeCore.pauseGame(gameA);
        assertTrue(arcadeCore.getGameConfig(gameA).paused);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UNPAUSE GAME TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify game can be unpaused
    function test_UnpauseGame_Success() public {
        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());
        arcadeCore.pauseGame(gameA);
        assertTrue(arcadeCore.getGameConfig(gameA).paused);

        arcadeCore.unpauseGame(gameA);
        assertFalse(arcadeCore.getGameConfig(gameA).paused);
        vm.stopPrank();
    }

    /// @notice Verify GameConfigUpdated event is emitted on unpause
    function test_UnpauseGame_EmitsEvent() public {
        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());
        arcadeCore.pauseGame(gameA);
        vm.stopPrank();

        IArcadeCore.GameConfig memory expectedConfig = _standardConfig();
        expectedConfig.paused = false;

        vm.expectEmit(true, false, false, true);
        emit IArcadeCore.GameConfigUpdated(gameA, expectedConfig);

        vm.prank(gameAdmin);
        arcadeCore.unpauseGame(gameA);
    }

    /// @notice Verify unpaused game allows processEntry
    function test_UnpauseGame_AllowsProcessEntry() public {
        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());
        arcadeCore.pauseGame(gameA);
        vm.stopPrank();

        // Entry blocked while paused
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Unpause
        vm.prank(gameAdmin);
        arcadeCore.unpauseGame(gameA);

        // Entry works after unpause
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        assertTrue(netAmount > 0);
    }

    /// @notice Verify unpausing non-paused game still succeeds (idempotent)
    function test_UnpauseGame_WhenNotPaused() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        assertFalse(arcadeCore.getGameConfig(gameA).paused);

        // Unpause when not paused - should succeed (idempotent)
        vm.prank(gameAdmin);
        arcadeCore.unpauseGame(gameA);
        assertFalse(arcadeCore.getGameConfig(gameA).paused);
    }

    /// @notice Verify unpauseGame fails for non-registered game
    function test_UnpauseGame_RevertWhen_NotRegistered() public {
        vm.prank(gameAdmin);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.unpauseGame(gameA);
    }

    /// @notice Verify unpauseGame fails without GAME_ADMIN_ROLE
    function test_UnpauseGame_RevertWhen_NotGameAdmin() public {
        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());
        arcadeCore.pauseGame(gameA);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, GAME_ADMIN_ROLE
            )
        );
        arcadeCore.unpauseGame(gameA);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSE/UNPAUSE CYCLE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify pause/unpause cycle works correctly multiple times
    function test_PauseUnpause_MultipleCycles() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        for (uint256 i = 0; i < 3; i++) {
            // Advance time to avoid rate limiting (MIN_PLAY_INTERVAL = 1 second)
            vm.warp(block.timestamp + 2);

            // Pause
            vm.prank(gameAdmin);
            arcadeCore.pauseGame(gameA);
            assertTrue(arcadeCore.getGameConfig(gameA).paused);

            // Entry blocked
            vm.prank(gameA);
            vm.expectRevert(IArcadeCore.GamePaused.selector);
            arcadeCore.processEntry(alice, 100 * 1e18, i + 10);

            // Unpause
            vm.prank(gameAdmin);
            arcadeCore.unpauseGame(gameA);
            assertFalse(arcadeCore.getGameConfig(gameA).paused);

            // Entry works
            vm.prank(gameA);
            arcadeCore.processEntry(alice, 100 * 1e18, i + 10);
        }
    }

    /// @notice Verify game pause is independent of contract pause
    function test_PauseGame_IndependentOfContractPause() public {
        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, _standardConfig());

        // Pause game (not contract)
        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        // Game-specific pause blocks entry
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Unpause game
        vm.prank(gameAdmin);
        arcadeCore.unpauseGame(gameA);

        // Now pause contract
        vm.prank(pauser);
        arcadeCore.pause();

        // Contract pause also blocks entry (different modifier)
        vm.prank(gameA);
        vm.expectRevert(); // EnforcedPause from PausableUpgradeable
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTEGRATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice End-to-end test of game lifecycle
    function test_Integration_FullGameLifecycle() public {
        // 1. Register game
        IArcadeCore.GameConfig memory config = _standardConfig();
        config.rakeBps = 500;

        vm.prank(gameAdmin);
        arcadeCore.registerGame(gameA, config);
        assertTrue(arcadeCore.isGameRegistered(gameA));

        // 2. Process entries
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        assertApproxEqRel(netAmount, 95 * 1e18, 0.01e18);

        // 3. Update config (higher rake)
        IArcadeCore.GameConfig memory newConfig = config;
        newConfig.rakeBps = 1000;

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameA, newConfig);

        // 4. Pause game
        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        // 5. New entries blocked
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(bob, 100 * 1e18, 2);

        // 6. Existing session can still be settled
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // 7. Unpause and verify new entries work with new config
        vm.prank(gameAdmin);
        arcadeCore.unpauseGame(gameA);

        vm.prank(gameA);
        uint256 netAmount2 = arcadeCore.processEntry(bob, 100 * 1e18, 2);
        assertApproxEqRel(netAmount2, 90 * 1e18, 0.01e18); // 10% rake now

        // 8. Unregister game
        vm.prank(gameAdmin);
        arcadeCore.unregisterGame(gameA);
        assertFalse(arcadeCore.isGameRegistered(gameA));

        // 9. Game cannot operate anymore
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.processEntry(alice, 100 * 1e18, 3);
    }

    /// @notice Verify multiple games can be managed independently
    function test_Integration_MultipleGamesIndependent() public {
        // Register multiple games with different configs
        IArcadeCore.GameConfig memory configA = _standardConfig();
        configA.rakeBps = 300;

        IArcadeCore.GameConfig memory configB = _standardConfig();
        configB.rakeBps = 500;

        vm.startPrank(gameAdmin);
        arcadeCore.registerGame(gameA, configA);
        arcadeCore.registerGame(gameB, configB);
        vm.stopPrank();

        // Pause only gameA
        vm.prank(gameAdmin);
        arcadeCore.pauseGame(gameA);

        // gameA blocked
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, 100 * 1e18, 1);

        // gameB still works
        vm.prank(gameB);
        uint256 netB = arcadeCore.processEntry(alice, 100 * 1e18, 2);
        assertApproxEqRel(netB, 95 * 1e18, 0.01e18); // 5% rake

        // Update gameB config
        IArcadeCore.GameConfig memory newConfigB = configB;
        newConfigB.rakeBps = 800;

        vm.prank(gameAdmin);
        arcadeCore.updateGameConfig(gameB, newConfigB);

        // gameA config unchanged
        assertEq(arcadeCore.getGameConfig(gameA).rakeBps, 300);
        // gameB config updated
        assertEq(arcadeCore.getGameConfig(gameB).rakeBps, 800);

        // Unregister gameA
        vm.prank(gameAdmin);
        arcadeCore.unregisterGame(gameA);

        // gameB unaffected
        assertTrue(arcadeCore.isGameRegistered(gameB));

        vm.prank(gameB);
        arcadeCore.processEntry(bob, 100 * 1e18, 3);
    }
}
