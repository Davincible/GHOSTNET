// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { GameRegistry } from "../../src/arcade/GameRegistry.sol";
import { IGameRegistry } from "../../src/arcade/interfaces/IGameRegistry.sol";
import { IArcadeTypes } from "../../src/arcade/interfaces/IArcadeTypes.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { IArcadeGame } from "../../src/arcade/interfaces/IArcadeGame.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { DataToken } from "../../src/token/DataToken.sol";

/// @title GameRegistryTest
/// @notice Comprehensive tests for the GameRegistry contract
contract GameRegistryTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    GameRegistry public registry;
    ArcadeCore public arcadeCore;
    DataToken public dataToken;

    address public owner = makeAddr("owner");
    address public notOwner = makeAddr("notOwner");
    address public treasury = makeAddr("treasury");

    // Mock game contracts
    MockGame public mockGame1;
    MockGame public mockGame2;

    // Default entry config
    IArcadeTypes.EntryConfig public defaultConfig;

    function setUp() public {
        // Deploy DataToken with proper constructor args
        address[] memory recipients = new address[](1);
        recipients[0] = owner;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100_000_000 ether; // Total supply = 100M DATA
        dataToken = new DataToken(treasury, owner, recipients, amounts);

        // Deploy ArcadeCore implementation
        ArcadeCore arcadeCoreImpl = new ArcadeCore();

        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, owner)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(arcadeCoreImpl), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Deploy GameRegistry (owner is passed as constructor arg)
        registry = new GameRegistry(owner, address(arcadeCore));

        // Grant GAME_ADMIN_ROLE to registry so it can register games in ArcadeCore
        // Must prank as owner who has DEFAULT_ADMIN_ROLE
        // NOTE: Cache the role before pranking since GAME_ADMIN_ROLE() is an external call
        bytes32 gameAdminRole = arcadeCore.GAME_ADMIN_ROLE();
        vm.prank(owner);
        arcadeCore.grantRole(gameAdminRole, address(registry));

        // Deploy mock games
        mockGame1 = new MockGame("TestGame1", "A test game", IArcadeTypes.GameCategory.CASINO);
        mockGame2 = new MockGame("TestGame2", "Another test", IArcadeTypes.GameCategory.SKILL);

        // Default config
        defaultConfig = IArcadeTypes.EntryConfig({
            minEntry: 10 ether,
            maxEntry: 1000 ether,
            rakeBps: 300, // 3%
            burnBps: 5000, // 50% of rake
            requiresPosition: false,
            boostEligible: true
        });
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REGISTRATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RegisterGame_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        assertTrue(registry.isGameRegistered(address(mockGame1)));
        assertEq(registry.getGameCount(), 1);

        // Check game info
        IArcadeTypes.GameInfo memory info = registry.getGameInfo(address(mockGame1));
        assertEq(info.name, "TestGame1");
        assertEq(info.description, "A test game");
        assertEq(uint8(info.category), uint8(IArcadeTypes.GameCategory.CASINO));

        // Check entry config
        IArcadeTypes.EntryConfig memory config = registry.getEntryConfig(address(mockGame1));
        assertEq(config.minEntry, 10 ether);
        assertEq(config.maxEntry, 1000 ether);
        assertEq(config.rakeBps, 300);

        // Verify registered in ArcadeCore too
        assertTrue(arcadeCore.isGameRegistered(address(mockGame1)));
    }

    function test_RegisterGame_EmitsEvent() public {
        bytes32 expectedGameId = keccak256(abi.encodePacked("TestGame1"));

        vm.expectEmit(true, true, false, true);
        emit IGameRegistry.GameRegistered(address(mockGame1), expectedGameId, "TestGame1");

        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);
    }

    function test_RegisterGame_MultipleGames() public {
        vm.startPrank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);
        registry.registerGame(address(mockGame2), defaultConfig);
        vm.stopPrank();

        assertEq(registry.getGameCount(), 2);

        address[] memory games = registry.getAllGames();
        assertEq(games.length, 2);
    }

    function test_RegisterGame_RevertWhen_NotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner)
        );
        registry.registerGame(address(mockGame1), defaultConfig);
    }

    function test_RegisterGame_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IGameRegistry.ZeroAddress.selector);
        registry.registerGame(address(0), defaultConfig);
    }

    function test_RegisterGame_RevertWhen_AlreadyRegistered() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.GameAlreadyRegistered.selector);
        registry.registerGame(address(mockGame1), defaultConfig);
    }

    function test_RegisterGame_RevertWhen_RakeTooHigh() public {
        IArcadeTypes.EntryConfig memory badConfig = defaultConfig;
        badConfig.rakeBps = 1001; // > 10%

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.InvalidConfig.selector);
        registry.registerGame(address(mockGame1), badConfig);
    }

    function test_RegisterGame_RevertWhen_BurnTooHigh() public {
        IArcadeTypes.EntryConfig memory badConfig = defaultConfig;
        badConfig.burnBps = 10_001; // > 100%

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.InvalidConfig.selector);
        registry.registerGame(address(mockGame1), badConfig);
    }

    function test_RegisterGame_RevertWhen_MinGreaterThanMax() public {
        IArcadeTypes.EntryConfig memory badConfig = defaultConfig;
        badConfig.minEntry = 1000 ether;
        badConfig.maxEntry = 10 ether;

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.InvalidConfig.selector);
        registry.registerGame(address(mockGame1), badConfig);
    }

    function test_RegisterGame_NoMaxEntry() public {
        IArcadeTypes.EntryConfig memory noMaxConfig = defaultConfig;
        noMaxConfig.maxEntry = 0; // Unlimited

        vm.prank(owner);
        registry.registerGame(address(mockGame1), noMaxConfig);

        IArcadeTypes.EntryConfig memory config = registry.getEntryConfig(address(mockGame1));
        assertEq(config.maxEntry, 0);
    }

    function test_RegisterGame_NonCompliantContract() public {
        // Register a contract that doesn't implement IArcadeGame
        address nonCompliant = address(new NonCompliantGame());

        vm.prank(owner);
        registry.registerGame(nonCompliant, defaultConfig);

        // Should still register with minimal info
        assertTrue(registry.isGameRegistered(nonCompliant));

        IArcadeTypes.GameInfo memory info = registry.getGameInfo(nonCompliant);
        assertEq(info.gameId, keccak256(abi.encodePacked(nonCompliant)));
        assertEq(info.name, "");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PauseGame_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        assertFalse(registry.isGamePaused(address(mockGame1)));

        vm.prank(owner);
        registry.pauseGame(address(mockGame1));

        assertTrue(registry.isGamePaused(address(mockGame1)));

        // Check ArcadeCore config is also paused
        IArcadeCore.GameConfig memory coreConfig = arcadeCore.getGameConfig(address(mockGame1));
        assertTrue(coreConfig.paused);
    }

    function test_PauseGame_EmitsEvent() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.expectEmit(true, false, false, false);
        emit IGameRegistry.GamePaused(address(mockGame1));

        vm.prank(owner);
        registry.pauseGame(address(mockGame1));
    }

    function test_UnpauseGame_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.pauseGame(address(mockGame1));

        vm.prank(owner);
        registry.unpauseGame(address(mockGame1));

        assertFalse(registry.isGamePaused(address(mockGame1)));
    }

    function test_PauseGame_RevertWhen_NotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.pauseGame(address(mockGame1));
    }

    function test_UnpauseGame_RevertWhen_NotOwner() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner)
        );
        registry.unpauseGame(address(mockGame1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONFIG UPDATE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_UpdateEntryConfig_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        IArcadeTypes.EntryConfig memory newConfig = IArcadeTypes.EntryConfig({
            minEntry: 50 ether,
            maxEntry: 500 ether,
            rakeBps: 500,
            burnBps: 3000,
            requiresPosition: true,
            boostEligible: false
        });

        vm.prank(owner);
        registry.updateEntryConfig(address(mockGame1), newConfig);

        IArcadeTypes.EntryConfig memory config = registry.getEntryConfig(address(mockGame1));
        assertEq(config.minEntry, 50 ether);
        assertEq(config.maxEntry, 500 ether);
        assertEq(config.rakeBps, 500);
        assertTrue(config.requiresPosition);
    }

    function test_UpdateEntryConfig_PreservesPauseState() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.pauseGame(address(mockGame1));

        IArcadeTypes.EntryConfig memory newConfig = defaultConfig;
        newConfig.rakeBps = 500;

        vm.prank(owner);
        registry.updateEntryConfig(address(mockGame1), newConfig);

        // Game should still be paused
        assertTrue(registry.isGamePaused(address(mockGame1)));

        IArcadeCore.GameConfig memory coreConfig = arcadeCore.getGameConfig(address(mockGame1));
        assertTrue(coreConfig.paused);
    }

    function test_UpdateEntryConfig_EmitsEvent() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.expectEmit(true, false, false, false);
        emit IGameRegistry.GameConfigUpdated(address(mockGame1));

        vm.prank(owner);
        registry.updateEntryConfig(address(mockGame1), defaultConfig);
    }

    function test_UpdateEntryConfig_RevertWhen_NotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.updateEntryConfig(address(mockGame1), defaultConfig);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REMOVAL GRACE PERIOD TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_MarkGameForRemoval_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        uint256 expectedRemovalTime = block.timestamp + registry.REMOVAL_GRACE_PERIOD();

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        assertEq(registry.getPendingRemoval(address(mockGame1)), expectedRemovalTime);

        // Game should be paused automatically
        assertTrue(registry.isGamePaused(address(mockGame1)));
    }

    function test_MarkGameForRemoval_EmitsEvent() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        uint256 expectedRemovalTime = block.timestamp + registry.REMOVAL_GRACE_PERIOD();

        vm.expectEmit(true, false, false, true);
        emit IGameRegistry.GameMarkedForRemoval(address(mockGame1), expectedRemovalTime);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));
    }

    function test_CancelGameRemoval_Success() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.prank(owner);
        registry.cancelGameRemoval(address(mockGame1));

        assertEq(registry.getPendingRemoval(address(mockGame1)), 0);
        assertFalse(registry.canRemoveGame(address(mockGame1)));

        // Game is still registered
        assertTrue(registry.isGameRegistered(address(mockGame1)));
    }

    function test_CancelGameRemoval_EmitsEvent() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.expectEmit(true, false, false, false);
        emit IGameRegistry.GameRemovalCancelled(address(mockGame1));

        vm.prank(owner);
        registry.cancelGameRemoval(address(mockGame1));
    }

    function test_RemoveGame_AfterGracePeriod() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        // Warp past grace period
        vm.warp(block.timestamp + registry.REMOVAL_GRACE_PERIOD() + 1);

        assertTrue(registry.canRemoveGame(address(mockGame1)));

        vm.prank(owner);
        registry.removeGame(address(mockGame1));

        assertFalse(registry.isGameRegistered(address(mockGame1)));
        assertEq(registry.getGameCount(), 0);

        // Also removed from ArcadeCore
        assertFalse(arcadeCore.isGameRegistered(address(mockGame1)));
    }

    function test_RemoveGame_EmitsEvent() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.warp(block.timestamp + registry.REMOVAL_GRACE_PERIOD() + 1);

        vm.expectEmit(true, false, false, false);
        emit IGameRegistry.GameRemoved(address(mockGame1));

        vm.prank(owner);
        registry.removeGame(address(mockGame1));
    }

    function test_RemoveGame_RevertWhen_GracePeriodNotPassed() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        // Try to remove before grace period ends
        uint256 timeBeforeRemoval = block.timestamp + registry.REMOVAL_GRACE_PERIOD() - 1;
        vm.warp(timeBeforeRemoval);

        assertFalse(registry.canRemoveGame(address(mockGame1)));

        uint256 removalTime = registry.getPendingRemoval(address(mockGame1));
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                GameRegistry.GracePeriodNotElapsed.selector, timeBeforeRemoval, removalTime
            )
        );
        registry.removeGame(address(mockGame1));
    }

    function test_RemoveGame_RevertWhen_NotMarkedForRemoval() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.removeGame(address(mockGame1));
    }

    function test_MarkGameForRemoval_RevertWhen_AlreadyMarked() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.prank(owner);
        vm.expectRevert(GameRegistry.GameAlreadyMarkedForRemoval.selector);
        registry.markGameForRemoval(address(mockGame1));
    }

    function test_CancelGameRemoval_DoesNotUnpauseGame() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        // Game should be paused after marking for removal
        assertTrue(registry.isGamePaused(address(mockGame1)));

        vm.prank(owner);
        registry.cancelGameRemoval(address(mockGame1));

        // Game should STILL be paused after cancellation (intentional behavior)
        assertTrue(registry.isGamePaused(address(mockGame1)));
    }

    function test_RegisterGame_AfterRemoval() public {
        // Register, mark for removal, wait, remove
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.warp(block.timestamp + registry.REMOVAL_GRACE_PERIOD() + 1);

        vm.prank(owner);
        registry.removeGame(address(mockGame1));

        // Should be able to re-register
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        assertTrue(registry.isGameRegistered(address(mockGame1)));
        assertFalse(registry.isGamePaused(address(mockGame1)));
    }

    function test_IsGamePendingRemoval() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        // Not pending initially
        assertFalse(registry.isGamePendingRemoval(address(mockGame1)));

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        // Now pending
        assertTrue(registry.isGamePendingRemoval(address(mockGame1)));

        vm.prank(owner);
        registry.cancelGameRemoval(address(mockGame1));

        // No longer pending after cancellation
        assertFalse(registry.isGamePendingRemoval(address(mockGame1)));
    }

    function test_CancelGameRemoval_RevertWhen_NotPending() public {
        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.cancelGameRemoval(address(mockGame1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetAllGames() public {
        vm.startPrank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);
        registry.registerGame(address(mockGame2), defaultConfig);
        vm.stopPrank();

        address[] memory games = registry.getAllGames();

        assertEq(games.length, 2);
        assertTrue(games[0] == address(mockGame1) || games[1] == address(mockGame1));
        assertTrue(games[0] == address(mockGame2) || games[1] == address(mockGame2));
    }

    function test_GetEntryConfig_RevertWhen_NotRegistered() public {
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.getEntryConfig(address(mockGame1));
    }

    function test_GetGameInfo_RevertWhen_NotRegistered() public {
        vm.expectRevert(IGameRegistry.GameNotRegistered.selector);
        registry.getGameInfo(address(mockGame1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN CONFIG TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SetArcadeCore_Success() public {
        address newCore = makeAddr("newCore");
        address oldCore = address(registry.arcadeCore());

        vm.expectEmit(true, true, false, false);
        emit GameRegistry.ArcadeCoreUpdated(oldCore, newCore);

        vm.prank(owner);
        registry.setArcadeCore(newCore);

        assertEq(address(registry.arcadeCore()), newCore);
    }

    function test_SetArcadeCore_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IGameRegistry.ZeroAddress.selector);
        registry.setArcadeCore(address(0));
    }

    function test_SetArcadeCore_RevertWhen_NotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner)
        );
        registry.setArcadeCore(makeAddr("newCore"));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_RevertWhen_ZeroArcadeCore() public {
        vm.expectRevert(IGameRegistry.ZeroAddress.selector);
        new GameRegistry(owner, address(0));
    }

    function test_Constructor_SetsOwner() public {
        GameRegistry newRegistry = new GameRegistry(owner, address(arcadeCore));
        assertEq(newRegistry.owner(), owner);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_RegisterGame_ValidConfig(
        uint128 minEntry,
        uint128 maxEntry,
        uint16 rakeBps,
        uint16 burnBps
    ) public {
        vm.assume(rakeBps <= 1000);
        vm.assume(burnBps <= 10_000);
        vm.assume(minEntry <= maxEntry || maxEntry == 0);

        IArcadeTypes.EntryConfig memory config = IArcadeTypes.EntryConfig({
            minEntry: minEntry,
            maxEntry: maxEntry,
            rakeBps: rakeBps,
            burnBps: burnBps,
            requiresPosition: false,
            boostEligible: false
        });

        vm.prank(owner);
        registry.registerGame(address(mockGame1), config);

        assertTrue(registry.isGameRegistered(address(mockGame1)));
    }

    function testFuzz_GracePeriodTiming(
        uint256 timeOffset
    ) public {
        vm.assume(timeOffset < 365 days);

        vm.prank(owner);
        registry.registerGame(address(mockGame1), defaultConfig);

        vm.prank(owner);
        registry.markGameForRemoval(address(mockGame1));

        vm.warp(block.timestamp + timeOffset);

        bool canRemove = registry.canRemoveGame(address(mockGame1));
        bool shouldBeAbleToRemove = timeOffset >= registry.REMOVAL_GRACE_PERIOD();

        assertEq(canRemove, shouldBeAbleToRemove);
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOCK CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════

/// @notice Mock game contract that implements IArcadeGame.getGameInfo
contract MockGame {
    string public name;
    string public description;
    IArcadeTypes.GameCategory public category;

    constructor(
        string memory _name,
        string memory _desc,
        IArcadeTypes.GameCategory _cat
    ) {
        name = _name;
        description = _desc;
        category = _cat;
    }

    function getGameInfo() external view returns (IArcadeTypes.GameInfo memory) {
        return IArcadeTypes.GameInfo({
            gameId: keccak256(abi.encodePacked(name)),
            name: name,
            description: description,
            category: category,
            minPlayers: 1,
            maxPlayers: 100,
            isActive: true,
            launchedAt: uint64(block.timestamp)
        });
    }

    function gameId() external view returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }
}

/// @notice Contract that doesn't implement IArcadeGame
contract NonCompliantGame {
    // Empty - doesn't implement getGameInfo

    }
