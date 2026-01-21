// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title ArcadeCore Integration Tests
/// @notice Comprehensive integration tests covering complete business flows and multi-step scenarios
/// @dev Tests verify:
///      - Complete game lifecycles (entry -> play -> settle -> withdraw)
///      - Multi-player session dynamics
///      - Multi-session player journeys
///      - Concurrent game isolation
///      - Emergency shutdown procedures
///      - High-volume stress scenarios
///      - Rate limiting and flash loan protection
///      - Pause/unpause flows
///      - Configuration changes mid-operation
///      - Statistical accuracy and invariants
contract ArcadeCoreIntegrationTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONTRACTS
    // ══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    DataToken public dataToken;
    MockGhostCore public mockGhostCore;

    // ══════════════════════════════════════════════════════════════════════════════
    // ADDRESSES
    // ══════════════════════════════════════════════════════════════════════════════

    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public treasuryB = makeAddr("treasuryB");

    // Games
    address public game1 = makeAddr("game1");
    address public game2 = makeAddr("game2");
    address public game3 = makeAddr("game3");

    // Players - dynamic array for tests that need many
    address[] public players;
    uint256 constant NUM_PLAYERS = 10;

    // Named players for readability
    address public alice;
    address public bob;
    address public charlie;
    address public diana;
    address public eve;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    uint256 constant TOTAL_SUPPLY = 100_000_000 ether;
    uint256 constant PLAYER_BALANCE = 10_000 ether;
    uint256 constant ENTRY_AMOUNT = 100 ether;
    uint256 constant RAKE_BPS = 500; // 5%
    uint256 constant BURN_BPS = 2000; // 20% of rake
    uint256 constant BPS = 10_000;
    uint256 constant MIN_PLAY_INTERVAL = 1 seconds;

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    event GameRegistered(address indexed game, IArcadeCore.GameConfig config);
    event GameUnregistered(address indexed game);
    event GameConfigUpdated(address indexed game, IArcadeCore.GameConfig config);
    event SessionCreated(address indexed game, uint256 indexed sessionId, uint64 timestamp);
    event SessionSettled(
        address indexed game, uint256 indexed sessionId, uint256 totalPaid, uint256 remaining
    );
    event SessionCancelled(address indexed game, uint256 indexed sessionId, uint256 prizePool);
    event EntryProcessed(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 amount,
        uint256 netAmount,
        uint256 rakeAmount
    );
    event PayoutCredited(address indexed player, uint256 amount, uint256 totalPending);
    event GameSettled(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 payout,
        uint256 burned,
        bool won
    );
    event PayoutWithdrawn(address indexed player, uint256 amount);
    event GameQuarantined(address indexed game, uint256 sessionsAffected);
    event EmergencyRefund(
        address indexed game, address indexed player, uint256 indexed sessionId, uint256 amount
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Create named players
        _createPlayers(NUM_PLAYERS);
        alice = players[0];
        bob = players[1];
        charlie = players[2];
        diana = players[3];
        eve = players[4];

        // Deploy MockGhostCore
        mockGhostCore = new MockGhostCore();

        // Calculate initial distribution
        uint256 totalForPlayers = PLAYER_BALANCE * NUM_PLAYERS;
        uint256 adminBalance = TOTAL_SUPPLY - totalForPlayers;

        // Build distribution arrays
        address[] memory recipients = new address[](NUM_PLAYERS + 1);
        uint256[] memory amounts = new uint256[](NUM_PLAYERS + 1);

        for (uint256 i; i < NUM_PLAYERS; i++) {
            recipients[i] = players[i];
            amounts[i] = PLAYER_BALANCE;
        }
        recipients[NUM_PLAYERS] = admin;
        amounts[NUM_PLAYERS] = adminBalance;

        // Deploy DataToken
        vm.startPrank(admin);
        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore via proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(mockGhostCore), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude arcade from tax for cleaner math
        dataToken.setTaxExclusion(address(arcadeCore), true);

        // Register games with standard config
        IArcadeCore.GameConfig memory config = _standardConfig();
        arcadeCore.registerGame(game1, config);
        arcadeCore.registerGame(game2, config);
        arcadeCore.registerGame(game3, config);

        vm.stopPrank();

        // All players approve arcade
        for (uint256 i; i < NUM_PLAYERS; i++) {
            vm.prank(players[i]);
            dataToken.approve(address(arcadeCore), type(uint256).max);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Create player addresses and add to array
    function _createPlayers(
        uint256 count
    ) internal {
        for (uint256 i; i < count; i++) {
            players.push(makeAddr(string.concat("player", vm.toString(i))));
        }
    }

    /// @notice Standard game config
    function _standardConfig() internal pure returns (IArcadeCore.GameConfig memory) {
        return IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: uint16(RAKE_BPS),
            burnBps: uint16(BURN_BPS),
            requiresPosition: false,
            paused: false
        });
    }

    /// @notice Config requiring position
    function _positionRequiredConfig() internal pure returns (IArcadeCore.GameConfig memory) {
        return IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: uint16(RAKE_BPS),
            burnBps: uint16(BURN_BPS),
            requiresPosition: true,
            paused: false
        });
    }

    /// @notice Calculate net amount after rake
    function _netAmount(
        uint256 gross
    ) internal pure returns (uint256) {
        return gross - (gross * RAKE_BPS / BPS);
    }

    /// @notice Calculate rake amount
    function _rakeAmount(
        uint256 gross
    ) internal pure returns (uint256) {
        return gross * RAKE_BPS / BPS;
    }

    /// @notice Calculate burn amount from rake
    function _burnFromRake(
        uint256 rake
    ) internal pure returns (uint256) {
        return rake * BURN_BPS / BPS;
    }

    /// @notice Calculate treasury amount from rake
    function _treasuryFromRake(
        uint256 rake
    ) internal pure returns (uint256) {
        return rake - _burnFromRake(rake);
    }

    /// @notice Process entry and return net amount
    function _playerEnters(
        address game,
        address player,
        uint256 amount,
        uint256 sessionId
    ) internal returns (uint256 netAmount) {
        vm.prank(game);
        netAmount = arcadeCore.processEntry(player, amount, sessionId);
    }

    /// @notice Credit payout to player
    function _creditPayout(
        address game,
        uint256 sessionId,
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) internal {
        vm.prank(game);
        arcadeCore.creditPayout(sessionId, player, amount, burnAmount, won);
    }

    /// @notice Settle session
    function _settleSession(
        address game,
        uint256 sessionId
    ) internal {
        vm.prank(game);
        arcadeCore.settleSession(sessionId);
    }

    /// @notice Cancel session
    function _cancelSession(
        address game,
        uint256 sessionId
    ) internal {
        vm.prank(game);
        arcadeCore.cancelSession(sessionId);
    }

    /// @notice Withdraw payout for player
    function _withdraw(
        address player
    ) internal returns (uint256) {
        vm.prank(player);
        return arcadeCore.withdrawPayout();
    }

    /// @notice Advance time to pass rate limit
    function _passRateLimit() internal {
        vm.warp(block.timestamp + MIN_PLAY_INTERVAL + 1);
    }

    /// @notice Sum of player balances
    function _sumPlayerBalances() internal view returns (uint256 total) {
        for (uint256 i; i < players.length; i++) {
            total += dataToken.balanceOf(players[i]);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 1: COMPLETE GAME LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Helper struct for lifecycle test to avoid stack too deep
    struct LifecycleTestData {
        uint256 sessionId;
        uint256 aliceInitial;
        uint256 bobInitial;
        uint256 charlieInitial;
        uint256 treasuryInitial;
        uint256 aliceNet;
        uint256 bobNet;
        uint256 charlieNet;
        uint256 totalRake;
        uint256 prizePool;
    }

    /// @notice Full lifecycle: register game -> players enter -> play -> settle -> withdraw
    function test_Integration_CompleteGameLifecycle() public {
        LifecycleTestData memory d;
        d.sessionId = 1;

        // ─── STEP 1: Record initial balances ───────────────────────────────────────
        d.aliceInitial = dataToken.balanceOf(alice);
        d.bobInitial = dataToken.balanceOf(bob);
        d.charlieInitial = dataToken.balanceOf(charlie);
        d.treasuryInitial = dataToken.balanceOf(treasury);

        // ─── STEP 2: Players enter session ─────────────────────────────────────────
        vm.expectEmit(true, true, true, true);
        emit SessionCreated(game1, d.sessionId, uint64(block.timestamp));
        d.aliceNet = _playerEnters(game1, alice, 100 ether, d.sessionId);
        _passRateLimit();

        d.bobNet = _playerEnters(game1, bob, 200 ether, d.sessionId);
        _passRateLimit();

        d.charlieNet = _playerEnters(game1, charlie, 300 ether, d.sessionId);

        // Verify session state
        {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(d.sessionId);
            assertEq(session.game, game1, "Session game mismatch");
            assertEq(session.prizePool, d.aliceNet + d.bobNet + d.charlieNet, "Prize pool mismatch");
            assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.ACTIVE), "Session not active");
            d.prizePool = session.prizePool;
        }

        // Verify rake distribution
        d.totalRake = _rakeAmount(600 ether);
        assertEq(
            dataToken.balanceOf(treasury),
            d.treasuryInitial + _treasuryFromRake(d.totalRake),
            "Treasury rake mismatch"
        );

        // ─── STEP 3: Credit payouts ────────────────────────────────────────────────
        _creditPayout(game1, d.sessionId, alice, 200 ether, 0, true);
        _creditPayout(game1, d.sessionId, bob, 150 ether, 0, true);
        _creditPayout(game1, d.sessionId, charlie, 0, 50 ether, false);

        // Verify pending payouts
        assertEq(arcadeCore.getPendingPayout(alice), 200 ether, "Alice pending mismatch");
        assertEq(arcadeCore.getPendingPayout(bob), 150 ether, "Bob pending mismatch");
        assertEq(arcadeCore.getPendingPayout(charlie), 0, "Charlie pending mismatch");

        // ─── STEP 4: Settle session ────────────────────────────────────────────────
        _verifyLifecycleSettle(d);

        // ─── STEP 5: Players withdraw ──────────────────────────────────────────────
        assertEq(_withdraw(alice), 200 ether, "Alice withdrawal");
        assertEq(_withdraw(bob), 150 ether, "Bob withdrawal");
        assertEq(_withdraw(charlie), 0, "Charlie withdrawal");

        // ─── STEP 6: Verify final accounting ───────────────────────────────────────
        _verifyLifecycleFinalAccounting(d);
    }

    /// @notice Helper to verify settlement in lifecycle test
    function _verifyLifecycleSettle(
        LifecycleTestData memory d
    ) internal {
        uint256 totalPaid = 200 ether + 150 ether + 50 ether; // payouts + burn
        uint256 remaining = d.prizePool - totalPaid;
        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        _settleSession(game1, d.sessionId);

        assertEq(
            dataToken.balanceOf(treasury),
            treasuryBefore + remaining,
            "Treasury didn't receive remaining"
        );

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(d.sessionId);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED), "Session not settled");
    }

    /// @notice Helper to verify final accounting in lifecycle test
    function _verifyLifecycleFinalAccounting(
        LifecycleTestData memory d
    ) internal view {
        // Players' net position
        assertEq(
            int256(dataToken.balanceOf(alice)) - int256(d.aliceInitial),
            int256(100 ether),
            "Alice should have profited"
        );
        assertEq(
            int256(dataToken.balanceOf(bob)) - int256(d.bobInitial),
            int256(-50 ether),
            "Bob should have lost"
        );
        assertEq(
            int256(dataToken.balanceOf(charlie)) - int256(d.charlieInitial),
            int256(-300 ether),
            "Charlie should have lost everything"
        );

        // Verify global stats
        (uint256 totalGamesPlayed, uint256 totalVolume, uint256 totalRakeCollected,) =
            arcadeCore.getGlobalStats();
        assertEq(totalGamesPlayed, 3, "Total games played mismatch");
        assertEq(totalVolume, 600 ether, "Total volume mismatch");
        assertEq(totalRakeCollected, d.totalRake, "Total rake collected mismatch");

        // Verify player stats
        IArcadeCore.PlayerStats memory aliceStats = arcadeCore.getPlayerStats(alice);
        assertEq(aliceStats.totalGamesPlayed, 1, "Alice games played");
        assertEq(aliceStats.totalWins, 1, "Alice wins");

        IArcadeCore.PlayerStats memory charlieStats = arcadeCore.getPlayerStats(charlie);
        assertEq(charlieStats.totalGamesPlayed, 1, "Charlie games played");
        assertEq(charlieStats.totalLosses, 1, "Charlie losses");

        // Verify no orphaned funds
        assertEq(arcadeCore.getTotalPendingPayouts(), 0, "Should have no pending payouts");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 2: MULTI-PLAYER SESSION SCENARIOS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice All players win - total payouts equal prize pool
    function test_Integration_MultiPlayerSession_AllWin() public {
        uint256 sessionId = 100;

        // 5 players enter with 100 DATA each
        uint256[] memory netAmounts = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            netAmounts[i] = _playerEnters(game1, players[i], ENTRY_AMOUNT, sessionId);
            _passRateLimit();
        }

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        uint256 prizePool = session.prizePool;

        // Distribute entire prize pool as winnings (no burn in this scenario)
        // Each player gets back their net amount
        for (uint256 i; i < 5; i++) {
            _creditPayout(game1, sessionId, players[i], netAmounts[i], 0, true);
        }

        // Settle - remaining should be 0
        _settleSession(game1, sessionId);

        session = arcadeCore.getSession(sessionId);
        assertEq(session.totalPaid, prizePool, "Total paid should equal prize pool");

        // All players can withdraw their winnings
        for (uint256 i; i < 5; i++) {
            uint256 withdrawn = _withdraw(players[i]);
            assertEq(withdrawn, netAmounts[i], string.concat("Player ", vm.toString(i), " withdrawal"));
        }

        // Verify all got wins recorded
        for (uint256 i; i < 5; i++) {
            IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(players[i]);
            assertEq(stats.totalWins, 1, "Should have 1 win");
            assertEq(stats.totalLosses, 0, "Should have 0 losses");
        }
    }

    /// @notice All players lose - everything burns or goes to treasury
    function test_Integration_MultiPlayerSession_AllLose() public {
        uint256 sessionId = 101;

        // 5 players enter
        uint256 totalNet;
        for (uint256 i; i < 5; i++) {
            totalNet += _playerEnters(game1, players[i], ENTRY_AMOUNT, sessionId);
            _passRateLimit();
        }

        // All lose - half burned, half to treasury (via settle remaining)
        uint256 burnAmount = totalNet / 2;
        for (uint256 i; i < 5; i++) {
            // Record loss but no payout
            _creditPayout(game1, sessionId, players[i], 0, burnAmount / 5, false);
        }

        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        // Settle - remaining goes to treasury
        _settleSession(game1, sessionId);

        uint256 remaining = totalNet - burnAmount;
        assertEq(
            dataToken.balanceOf(treasury), treasuryBefore + remaining, "Treasury should get remaining"
        );

        // All players have nothing to withdraw
        for (uint256 i; i < 5; i++) {
            assertEq(arcadeCore.getPendingPayout(players[i]), 0, "Should have no payout");
            IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(players[i]);
            assertEq(stats.totalLosses, 1, "Should have 1 loss");
        }
    }

    /// @notice Mixed outcomes - some win, some lose
    function test_Integration_MultiPlayerSession_MixedOutcomes() public {
        uint256 sessionId = 102;

        // Players enter with varying amounts
        uint256[] memory entries = new uint256[](5);
        entries[0] = 50 ether; // Alice - will win 2x
        entries[1] = 100 ether; // Bob - will win 1.5x
        entries[2] = 150 ether; // Charlie - will break even (minus rake)
        entries[3] = 200 ether; // Diana - will lose half
        entries[4] = 500 ether; // Eve - will lose everything

        uint256[] memory netAmounts = new uint256[](5);
        uint256 totalNet;
        for (uint256 i; i < 5; i++) {
            netAmounts[i] = _playerEnters(game1, players[i], entries[i], sessionId);
            totalNet += netAmounts[i];
            _passRateLimit();
        }

        // Determine payouts
        uint256[] memory payouts = new uint256[](5);
        payouts[0] = netAmounts[0] * 2; // Alice doubles
        payouts[1] = netAmounts[1] * 150 / 100; // Bob +50%
        payouts[2] = netAmounts[2]; // Charlie breaks even
        payouts[3] = netAmounts[3] / 2; // Diana loses half
        payouts[4] = 0; // Eve loses all

        bool[] memory won = new bool[](5);
        won[0] = true;
        won[1] = true;
        won[2] = true; // Technically won (got money back)
        won[3] = false;
        won[4] = false;

        // Credit payouts
        uint256 totalPayout;
        for (uint256 i; i < 5; i++) {
            _creditPayout(game1, sessionId, players[i], payouts[i], 0, won[i]);
            totalPayout += payouts[i];
        }

        // Verify payouts don't exceed prize pool
        assertLe(totalPayout, totalNet, "Payouts cannot exceed prize pool");

        // Settle
        _settleSession(game1, sessionId);

        // Withdraw and verify
        for (uint256 i; i < 5; i++) {
            uint256 withdrawn = _withdraw(players[i]);
            assertEq(withdrawn, payouts[i], string.concat("Player ", vm.toString(i), " payout"));
        }
    }

    /// @notice Partial payouts across multiple transactions
    function test_Integration_MultiPlayerSession_PartialPayouts() public {
        uint256 sessionId = 103;

        // Alice enters
        uint256 aliceNet = _playerEnters(game1, alice, 1000 ether, sessionId);

        // Game credits partial payouts over time (must stay within prize pool)
        uint256 payout1 = aliceNet / 10; // 10% of net
        uint256 payout2 = aliceNet / 5; // 20% of net
        uint256 payout3 = aliceNet / 6; // ~16% of net

        _creditPayout(game1, sessionId, alice, payout1, 0, true);
        assertEq(arcadeCore.getPendingPayout(alice), payout1);

        _creditPayout(game1, sessionId, alice, payout2, 0, true);
        assertEq(arcadeCore.getPendingPayout(alice), payout1 + payout2);

        _creditPayout(game1, sessionId, alice, payout3, 0, true);
        assertEq(arcadeCore.getPendingPayout(alice), payout1 + payout2 + payout3);

        // Stats should show multiple wins
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(alice);
        assertEq(stats.totalWins, 3, "Should have 3 wins recorded");

        // Single withdrawal gets all
        uint256 withdrawn = _withdraw(alice);
        assertEq(withdrawn, payout1 + payout2 + payout3);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 3: MULTI-SESSION PLAYER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Player participates across 5 sessions with varied outcomes
    function test_Integration_PlayerAcrossMultipleSessions() public {
        // Alice plays 5 sessions: wins 3, loses 2
        // Payouts are bounded by what's in the prize pool (net after rake)

        uint256 aliceInitial = dataToken.balanceOf(alice);
        uint256 totalPayout;

        // Session 1: Win - gets back net amount
        {
            uint256 net = _playerEnters(game1, alice, 100 ether, 200);
            _creditPayout(game1, 200, alice, net, 0, true);
            _settleSession(game1, 200);
            totalPayout += net;
            _passRateLimit();
        }

        // Session 2: Lose - gets nothing
        {
            _playerEnters(game1, alice, 100 ether, 201);
            _creditPayout(game1, 201, alice, 0, 0, false);
            _settleSession(game1, 201);
            _passRateLimit();
        }

        // Session 3: Win - gets back net amount
        {
            uint256 net = _playerEnters(game1, alice, 200 ether, 202);
            _creditPayout(game1, 202, alice, net, 0, true);
            _settleSession(game1, 202);
            totalPayout += net;
            _passRateLimit();
        }

        // Session 4: Lose - gets nothing
        {
            _playerEnters(game1, alice, 150 ether, 203);
            _creditPayout(game1, 203, alice, 0, 0, false);
            _settleSession(game1, 203);
            _passRateLimit();
        }

        // Session 5: Win - gets back net amount
        {
            uint256 net = _playerEnters(game1, alice, 50 ether, 204);
            _creditPayout(game1, 204, alice, net, 0, true);
            _settleSession(game1, 204);
            totalPayout += net;
        }

        // Verify accumulated stats
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(alice);
        assertEq(stats.totalGamesPlayed, 5, "Should have played 5 games");
        assertEq(stats.totalWins, 3, "Should have 3 wins");
        assertEq(stats.totalLosses, 2, "Should have 2 losses");

        // Single withdrawal covers all pending
        assertEq(arcadeCore.getPendingPayout(alice), totalPayout);
        uint256 withdrawn = _withdraw(alice);
        assertEq(withdrawn, totalPayout);

        // Verify net position (lost to rake on losing sessions)
        uint256 totalEntered = 100 ether + 100 ether + 200 ether + 150 ether + 50 ether; // 600
        int256 netGain = int256(totalPayout) - int256(totalEntered);

        assertEq(
            int256(dataToken.balanceOf(alice)) - int256(aliceInitial),
            netGain,
            "Net position mismatch"
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 4: MULTI-GAME CONCURRENT
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice 3 games running simultaneously with shared players
    function test_Integration_MultipleGamesConcurrent() public {
        // Session IDs per game
        uint256 game1Session = 300;
        uint256 game2Session = 301;
        uint256 game3Session = 302;

        // Alice plays all 3 games
        uint256 aliceNet1 = _playerEnters(game1, alice, 100 ether, game1Session);
        _passRateLimit();
        uint256 aliceNet2 = _playerEnters(game2, alice, 200 ether, game2Session);
        _passRateLimit();
        uint256 aliceNet3 = _playerEnters(game3, alice, 300 ether, game3Session);
        _passRateLimit();

        // Bob plays game1 and game2
        uint256 bobNet1 = _playerEnters(game1, bob, 150 ether, game1Session);
        _passRateLimit();
        uint256 bobNet2 = _playerEnters(game2, bob, 250 ether, game2Session);
        _passRateLimit();

        // Charlie only plays game3
        uint256 charlieNet3 = _playerEnters(game3, charlie, 400 ether, game3Session);

        // Verify sessions are isolated
        IArcadeCore.SessionRecord memory session1 = arcadeCore.getSession(game1Session);
        IArcadeCore.SessionRecord memory session2 = arcadeCore.getSession(game2Session);
        IArcadeCore.SessionRecord memory session3 = arcadeCore.getSession(game3Session);

        assertEq(session1.game, game1);
        assertEq(session2.game, game2);
        assertEq(session3.game, game3);

        assertEq(session1.prizePool, aliceNet1 + bobNet1);
        assertEq(session2.prizePool, aliceNet2 + bobNet2);
        assertEq(session3.prizePool, aliceNet3 + charlieNet3);

        // Game2 tries to credit payout on game1's session - should fail
        vm.prank(game2);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.creditPayout(game1Session, alice, 50 ether, 0, true);

        // Each game settles its own session
        // Game1: Alice and Bob break even
        _creditPayout(game1, game1Session, alice, aliceNet1, 0, true);
        _creditPayout(game1, game1Session, bob, bobNet1, 0, true);
        _settleSession(game1, game1Session);

        // Game2: Alice wins big (takes Bob's stake), Bob loses
        // Prize pool = aliceNet2 + bobNet2
        // Alice gets the whole pool
        uint256 game2Pool = aliceNet2 + bobNet2;
        _creditPayout(game2, game2Session, alice, game2Pool, 0, true);
        _creditPayout(game2, game2Session, bob, 0, 0, false);
        _settleSession(game2, game2Session);

        // Game3: Alice loses, Charlie wins (takes Alice's stake)
        // Prize pool = aliceNet3 + charlieNet3
        uint256 game3Pool = aliceNet3 + charlieNet3;
        _creditPayout(game3, game3Session, alice, 0, 0, false);
        _creditPayout(game3, game3Session, charlie, game3Pool, 0, true);
        _settleSession(game3, game3Session);

        // Verify final payouts
        uint256 aliceExpected = aliceNet1 + game2Pool; // game1 break even + game2 big win + game3 lose
        assertEq(arcadeCore.getPendingPayout(alice), aliceExpected);

        uint256 bobExpected = bobNet1; // game1 break even + game2 lose
        assertEq(arcadeCore.getPendingPayout(bob), bobExpected);

        uint256 charlieExpected = game3Pool; // game3 big win
        assertEq(arcadeCore.getPendingPayout(charlie), charlieExpected);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 5: GAME SHUTDOWN FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Game with active sessions is quarantined and all players refunded
    function test_Integration_GameShutdownFlow() public {
        // Create 3 active sessions with multiple players
        uint256[] memory sessionIds = new uint256[](3);
        sessionIds[0] = 400;
        sessionIds[1] = 401;
        sessionIds[2] = 402;

        // Session 0: Alice and Bob
        uint256 aliceNet0 = _playerEnters(game1, alice, 100 ether, sessionIds[0]);
        _passRateLimit();
        uint256 bobNet0 = _playerEnters(game1, bob, 100 ether, sessionIds[0]);
        _passRateLimit();

        // Session 1: Charlie and Diana
        uint256 charlieNet1 = _playerEnters(game1, charlie, 200 ether, sessionIds[1]);
        _passRateLimit();
        uint256 dianaNet1 = _playerEnters(game1, diana, 200 ether, sessionIds[1]);
        _passRateLimit();

        // Session 2: Eve alone
        uint256 eveNet2 = _playerEnters(game1, eve, 500 ether, sessionIds[2]);

        // Verify all sessions active
        for (uint256 i; i < 3; i++) {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionIds[i]);
            assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.ACTIVE));
        }

        // ─── VULNERABILITY DISCOVERED - QUARANTINE GAME ────────────────────────────
        vm.expectEmit(true, true, true, true);
        emit GameQuarantined(game1, 3);
        vm.prank(admin);
        arcadeCore.emergencyQuarantineGame(game1);

        // Verify game is paused
        IArcadeCore.GameConfig memory config = arcadeCore.getGameConfig(game1);
        assertTrue(config.paused, "Game should be paused");

        // Verify all sessions are cancelled
        for (uint256 i; i < 3; i++) {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionIds[i]);
            assertEq(
                uint8(session.state),
                uint8(IArcadeCore.SessionState.CANCELLED),
                "Session should be cancelled"
            );
        }

        // ─── REFUND ALL PLAYERS ────────────────────────────────────────────────────
        // Anyone can trigger refunds for cancelled sessions
        arcadeCore.claimExpiredRefund(sessionIds[0], alice);
        arcadeCore.claimExpiredRefund(sessionIds[0], bob);
        arcadeCore.claimExpiredRefund(sessionIds[1], charlie);
        arcadeCore.claimExpiredRefund(sessionIds[1], diana);
        arcadeCore.claimExpiredRefund(sessionIds[2], eve);

        // Verify pending payouts
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet0);
        assertEq(arcadeCore.getPendingPayout(bob), bobNet0);
        assertEq(arcadeCore.getPendingPayout(charlie), charlieNet1);
        assertEq(arcadeCore.getPendingPayout(diana), dianaNet1);
        assertEq(arcadeCore.getPendingPayout(eve), eveNet2);

        // ─── PLAYERS WITHDRAW ──────────────────────────────────────────────────────
        _withdraw(alice);
        _withdraw(bob);
        _withdraw(charlie);
        _withdraw(diana);
        _withdraw(eve);

        // ─── UNREGISTER GAME ───────────────────────────────────────────────────────
        vm.prank(admin);
        arcadeCore.unregisterGame(game1);

        assertFalse(arcadeCore.isGameRegistered(game1));

        // ─── VERIFY NO ORPHANED FUNDS ──────────────────────────────────────────────
        assertEq(arcadeCore.getTotalPendingPayouts(), 0, "No pending payouts");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 6: HIGH-VOLUME STRESS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice 100 players enter same session
    function test_Integration_HighVolume_100Players() public {
        uint256 sessionId = 500;

        // Create 100 players
        address[] memory manyPlayers = new address[](100);
        for (uint256 i; i < 100; i++) {
            manyPlayers[i] = makeAddr(string.concat("manyPlayer", vm.toString(i)));
            // Fund and approve
            vm.prank(admin);
            dataToken.transfer(manyPlayers[i], 1000 ether);
            vm.prank(manyPlayers[i]);
            dataToken.approve(address(arcadeCore), type(uint256).max);
        }

        // All enter the session
        uint256 totalNet;
        for (uint256 i; i < 100; i++) {
            uint256 net = _playerEnters(game1, manyPlayers[i], 10 ether, sessionId);
            totalNet += net;
            _passRateLimit();
        }

        // Verify session state
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        assertEq(session.prizePool, totalNet);

        // Credit payouts to all (break even)
        for (uint256 i; i < 100; i++) {
            uint256 playerNet = arcadeCore.getSessionDeposit(sessionId, manyPlayers[i]);
            _creditPayout(game1, sessionId, manyPlayers[i], playerNet, 0, true);
        }

        // Settle
        _settleSession(game1, sessionId);

        // All withdraw
        for (uint256 i; i < 100; i++) {
            _withdraw(manyPlayers[i]);
        }

        // Verify stats
        (uint256 totalGamesPlayed,,,) = arcadeCore.getGlobalStats();
        assertEq(totalGamesPlayed, 100);
    }

    /// @notice 100 separate sessions
    function test_Integration_HighVolume_100Sessions() public {
        // Use first 5 players, 20 sessions each
        for (uint256 s; s < 100; s++) {
            uint256 sessionId = 600 + s;
            address player = players[s % 5];

            uint256 net = _playerEnters(game1, player, 10 ether, sessionId);
            _creditPayout(game1, sessionId, player, net, 0, true);
            _settleSession(game1, sessionId);
            _passRateLimit();
        }

        // Verify 100 sessions processed
        (uint256 totalGamesPlayed,,,) = arcadeCore.getGlobalStats();
        assertEq(totalGamesPlayed, 100);

        // Each player has 20 wins
        for (uint256 i; i < 5; i++) {
            IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(players[i]);
            assertEq(stats.totalGamesPlayed, 20);
            assertEq(stats.totalWins, 20);
        }
    }

    /// @notice Batch operations at max size
    function test_Integration_HighVolume_BatchOperations() public {
        uint256 maxBatch = arcadeCore.MAX_BATCH_SIZE();
        uint256 sessionId = 700;

        // Create players for batch
        address[] memory batchPlayers = new address[](maxBatch);
        for (uint256 i; i < maxBatch; i++) {
            batchPlayers[i] = makeAddr(string.concat("batchPlayer", vm.toString(i)));
            vm.prank(admin);
            dataToken.transfer(batchPlayers[i], 100 ether);
            vm.prank(batchPlayers[i]);
            dataToken.approve(address(arcadeCore), type(uint256).max);
        }

        // All enter session
        uint256[] memory netAmounts = new uint256[](maxBatch);
        for (uint256 i; i < maxBatch; i++) {
            netAmounts[i] = _playerEnters(game1, batchPlayers[i], 10 ether, sessionId);
            _passRateLimit();
        }

        // Batch credit payouts
        uint256[] memory sessionIds = new uint256[](maxBatch);
        uint256[] memory amounts = new uint256[](maxBatch);
        uint256[] memory burnAmounts = new uint256[](maxBatch);
        bool[] memory results = new bool[](maxBatch);

        for (uint256 i; i < maxBatch; i++) {
            sessionIds[i] = sessionId;
            amounts[i] = netAmounts[i];
            burnAmounts[i] = 0;
            results[i] = true;
        }

        vm.prank(game1);
        arcadeCore.batchCreditPayouts(sessionIds, batchPlayers, amounts, burnAmounts, results);

        // Verify all payouts credited
        for (uint256 i; i < maxBatch; i++) {
            assertEq(arcadeCore.getPendingPayout(batchPlayers[i]), netAmounts[i]);
        }

        // Cancel session
        _cancelSession(game1, sessionId);

        // SECURITY: Batch refund should be blocked because payouts were already made
        // This prevents solvency attacks (payout + refund > balance)
        vm.prank(game1);
        vm.expectRevert(IArcadeCore.RefundsBlockedAfterPayouts.selector);
        arcadeCore.batchEmergencyRefund(sessionId, batchPlayers);

        // Verify players still have their payouts (not refunds on top)
        for (uint256 i; i < maxBatch; i++) {
            assertEq(arcadeCore.getPendingPayout(batchPlayers[i]), netAmounts[i]);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 7: RATE LIMITING
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Rate limiting enforced between plays
    function test_Integration_RateLimitingEnforced() public {
        uint256 sessionId = 800;

        // First entry succeeds
        _playerEnters(game1, alice, 100 ether, sessionId);

        // Immediate second entry fails (same timestamp)
        vm.prank(game1);
        vm.expectRevert(IArcadeCore.RateLimited.selector);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        // Wait MIN_PLAY_INTERVAL - now succeeds
        // Rate limit check is: block.timestamp < lastPlayTime + MIN_PLAY_INTERVAL
        // So at timestamp = lastPlayTime + MIN_PLAY_INTERVAL, it's NOT less than, so it passes
        vm.warp(block.timestamp + MIN_PLAY_INTERVAL);

        // Second entry succeeds
        vm.prank(game1);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        // Immediate third entry fails
        vm.prank(game1);
        vm.expectRevert(IArcadeCore.RateLimited.selector);
        arcadeCore.processEntry(alice, 100 ether, sessionId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 8: FLASH LOAN PROTECTION (Same block limits)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Multiple entries in same block blocked by rate limit
    function test_Integration_FlashLoanProtectionFlow() public {
        uint256 sessionId = 900;

        // First entry works
        _playerEnters(game1, alice, 100 ether, sessionId);

        // Same block, same player fails
        vm.prank(game1);
        vm.expectRevert(IArcadeCore.RateLimited.selector);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        // Different player in same block works
        _playerEnters(game1, bob, 100 ether, sessionId);

        // Move to new block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + MIN_PLAY_INTERVAL + 1);

        // Alice can enter again
        _playerEnters(game1, alice, 100 ether, sessionId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 9: PAUSE/UNPAUSE FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Global pause affects new entries but allows existing operations
    function test_Integration_PauseUnpauseFlow() public {
        uint256 sessionId = 1000;

        // Active session with deposits
        uint256 aliceNet = _playerEnters(game1, alice, 100 ether, sessionId);
        _passRateLimit();
        uint256 bobNet = _playerEnters(game1, bob, 100 ether, sessionId);

        // ─── GLOBAL PAUSE ──────────────────────────────────────────────────────────
        vm.prank(admin);
        arcadeCore.pause();

        // New entries blocked
        _passRateLimit();
        vm.prank(game1);
        vm.expectRevert(); // Pausable: paused
        arcadeCore.processEntry(charlie, 100 ether, sessionId);

        // Existing settlements still work (game can finish)
        _creditPayout(game1, sessionId, alice, aliceNet, 0, true);
        _creditPayout(game1, sessionId, bob, bobNet, 0, true);

        // Settle works
        _settleSession(game1, sessionId);

        // Withdrawals work during pause (players can get their money)
        uint256 aliceWithdrawn = _withdraw(alice);
        assertEq(aliceWithdrawn, aliceNet);

        // ─── UNPAUSE ───────────────────────────────────────────────────────────────
        vm.prank(admin);
        arcadeCore.unpause();

        // New entries work again
        uint256 sessionId2 = 1001;
        _passRateLimit();
        _playerEnters(game1, charlie, 100 ether, sessionId2);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 10: CONFIG CHANGE MID-SESSION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Config changes don't affect existing sessions
    function test_Integration_ConfigChangeMidSession() public {
        uint256 sessionId = 1100;

        // Original config: 5% rake
        uint256 aliceNet = _playerEnters(game1, alice, 100 ether, sessionId);
        uint256 rakeApplied = 100 ether - aliceNet;
        assertEq(rakeApplied, 5 ether, "Should be 5% rake");

        _passRateLimit();

        // ─── ADMIN CHANGES RAKE TO 10% ─────────────────────────────────────────────
        IArcadeCore.GameConfig memory newConfig = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: 1000, // 10% rake now
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.updateGameConfig(game1, newConfig);

        // New entry in SAME session uses NEW config
        uint256 bobNet = _playerEnters(game1, bob, 100 ether, sessionId);
        uint256 bobRake = 100 ether - bobNet;
        assertEq(bobRake, 10 ether, "Bob should pay 10% rake");

        // NEW session also uses new config
        uint256 sessionId2 = 1101;
        _passRateLimit();
        uint256 charlieNet = _playerEnters(game1, charlie, 100 ether, sessionId2);
        uint256 charlieRake = 100 ether - charlieNet;
        assertEq(charlieRake, 10 ether, "Charlie should pay 10% rake");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 11: TREASURY CHANGE FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Treasury change affects future settlements
    function test_Integration_TreasuryChangeFlow() public {
        uint256 sessionId1 = 1200;
        uint256 sessionId2 = 1201;

        // Record treasury balance BEFORE entry
        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        // Session 1 with original treasury
        uint256 aliceNet = _playerEnters(game1, alice, 100 ether, sessionId1);

        // Verify rake went to treasury A
        uint256 rake = 100 ether - aliceNet;
        uint256 treasuryShare = _treasuryFromRake(rake);
        assertEq(
            dataToken.balanceOf(treasury) - treasuryBefore,
            treasuryShare,
            "Treasury A should receive rake"
        );

        // ─── CHANGE TREASURY ───────────────────────────────────────────────────────
        vm.prank(admin);
        arcadeCore.setTreasury(treasuryB);

        // Session 2 with new treasury
        _passRateLimit();
        uint256 bobNet = _playerEnters(game1, bob, 100 ether, sessionId2);

        // Verify rake went to treasury B
        uint256 bobRake = 100 ether - bobNet;
        uint256 bobTreasuryShare = _treasuryFromRake(bobRake);
        assertEq(dataToken.balanceOf(treasuryB), bobTreasuryShare, "Treasury B should receive rake");

        // Settle session 1 - remaining to treasury B (current treasury)
        _creditPayout(game1, sessionId1, alice, aliceNet / 2, 0, true);
        uint256 treasuryBBefore = dataToken.balanceOf(treasuryB);
        _settleSession(game1, sessionId1);

        // Remaining from session 1 goes to new treasury
        assertGt(
            dataToken.balanceOf(treasuryB), treasuryBBefore, "Treasury B should get settlement remaining"
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 12: POSITION REQUIREMENT FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Games can require GhostCore position
    function test_Integration_PositionRequirementFlow() public {
        // Register a game that requires position
        address positionGame = makeAddr("positionGame");
        vm.prank(admin);
        arcadeCore.registerGame(positionGame, _positionRequiredConfig());

        uint256 sessionId = 1300;

        // Alice has no position - entry fails
        mockGhostCore.setAlive(alice, false);

        vm.prank(positionGame);
        vm.expectRevert(IArcadeCore.PositionRequired.selector);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        // Alice gets a position
        mockGhostCore.setAlive(alice, true);

        // Entry succeeds now
        vm.prank(positionGame);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        // Alice's position dies
        mockGhostCore.setAlive(alice, false);

        // Future entries fail
        _passRateLimit();
        vm.prank(positionGame);
        vm.expectRevert(IArcadeCore.PositionRequired.selector);
        arcadeCore.processEntry(alice, 100 ether, sessionId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 13: EMERGENCY REFUND FULL FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Complete emergency refund flow with no double refunds
    function test_Integration_EmergencyRefundFullFlow() public {
        uint256 sessionId = 1400;

        // Multiple players deposit
        uint256 aliceNet = _playerEnters(game1, alice, 100 ether, sessionId);
        _passRateLimit();
        uint256 bobNet = _playerEnters(game1, bob, 200 ether, sessionId);
        _passRateLimit();
        uint256 charlieNet = _playerEnters(game1, charlie, 300 ether, sessionId);

        // Game malfunctions - cancel session
        _cancelSession(game1, sessionId);

        // Emergency refunds issued
        vm.prank(game1);
        arcadeCore.emergencyRefund(sessionId, alice, aliceNet);

        vm.prank(game1);
        arcadeCore.emergencyRefund(sessionId, bob, bobNet);

        // Charlie uses self-service refund
        arcadeCore.claimExpiredRefund(sessionId, charlie);

        // Verify all got refunded
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet);
        assertEq(arcadeCore.getPendingPayout(bob), bobNet);
        assertEq(arcadeCore.getPendingPayout(charlie), charlieNet);

        // Try double refund - should fail
        vm.prank(game1);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(sessionId, alice, 1);

        // Players withdraw
        _withdraw(alice);
        _withdraw(bob);
        _withdraw(charlie);

        // Verify no pending
        assertEq(arcadeCore.getTotalPendingPayouts(), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST 14: UPGRADE WITH ACTIVE SESSIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Helper struct to reduce stack depth in upgrade test
    struct UpgradeTestState {
        uint256 sessionId;
        uint256 aliceNet;
        uint256 bobNet;
        uint256 gamesPlayed;
        uint256 volume;
        uint256 rake;
        uint256 burned;
        address sessionGame;
        uint256 prizePool;
        uint256 totalPaid;
        uint8 state;
        uint256 alicePending;
    }

    /// @notice Contract upgrade preserves session state and pending payouts
    function test_Integration_UpgradeWithActiveSessions() public {
        UpgradeTestState memory s;
        s.sessionId = 1500;

        // Create session with deposits and partial payouts
        s.aliceNet = _playerEnters(game1, alice, 100 ether, s.sessionId);
        _passRateLimit();
        s.bobNet = _playerEnters(game1, bob, 200 ether, s.sessionId);

        // Credit partial payout to alice
        _creditPayout(game1, s.sessionId, alice, s.aliceNet / 2, 0, true);

        // Record state before upgrade
        {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(s.sessionId);
            s.sessionGame = session.game;
            s.prizePool = session.prizePool;
            s.totalPaid = session.totalPaid;
            s.state = uint8(session.state);
        }
        s.alicePending = arcadeCore.getPendingPayout(alice);
        (s.gamesPlayed, s.volume, s.rake, s.burned) = arcadeCore.getGlobalStats();

        // ─── UPGRADE CONTRACT ──────────────────────────────────────────────────────
        ArcadeCoreV2 newImplementation = new ArcadeCoreV2();

        vm.prank(admin);
        arcadeCore.upgradeToAndCall(address(newImplementation), "");

        // ─── VERIFY STATE PRESERVED ────────────────────────────────────────────────
        _verifyUpgradeState(s);

        // ─── CONTINUE NORMAL OPERATIONS ────────────────────────────────────────────
        // Credit remaining payout
        _creditPayout(game1, s.sessionId, alice, s.aliceNet / 2, 0, true);
        _creditPayout(game1, s.sessionId, bob, s.bobNet, 0, true);

        // Settle
        _settleSession(game1, s.sessionId);

        // Withdraw
        uint256 aliceWithdrawn = _withdraw(alice);
        assertEq(aliceWithdrawn, s.aliceNet);

        uint256 bobWithdrawn = _withdraw(bob);
        assertEq(bobWithdrawn, s.bobNet);
    }

    /// @notice Helper to verify state after upgrade
    function _verifyUpgradeState(
        UpgradeTestState memory s
    ) internal view {
        IArcadeCore.SessionRecord memory sessionAfter = arcadeCore.getSession(s.sessionId);
        assertEq(sessionAfter.game, s.sessionGame, "Session game preserved");
        assertEq(sessionAfter.prizePool, s.prizePool, "Prize pool preserved");
        assertEq(sessionAfter.totalPaid, s.totalPaid, "Total paid preserved");
        assertEq(uint8(sessionAfter.state), s.state, "State preserved");

        assertEq(arcadeCore.getPendingPayout(alice), s.alicePending, "Pending payout preserved");

        (uint256 gp, uint256 v, uint256 r, uint256 b) = arcadeCore.getGlobalStats();
        assertEq(gp, s.gamesPlayed, "Games played preserved");
        assertEq(v, s.volume, "Volume preserved");
        assertEq(r, s.rake, "Rake preserved");
        assertEq(b, s.burned, "Burned preserved");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATISTICAL VERIFICATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify totalVolume equals sum of all entries
    function test_Stats_TotalVolumeAccuracy() public {
        uint256 expectedVolume;

        // 20 random entries
        for (uint256 i; i < 20; i++) {
            uint256 amount = 10 ether + (i * 5 ether);
            _playerEnters(game1, players[i % NUM_PLAYERS], amount, 1600 + i);
            expectedVolume += amount;
            _passRateLimit();
        }

        (, uint256 totalVolume,,) = arcadeCore.getGlobalStats();
        assertEq(totalVolume, expectedVolume, "Total volume should match sum of entries");
    }

    /// @notice Verify totalBurned accuracy
    function test_Stats_TotalBurnedAccuracy() public {
        uint256 sessionId = 1700;

        // Entry with known rake
        uint256 grossEntry = 1000 ether;
        uint256 rake = _rakeAmount(grossEntry);
        uint256 burnFromRake = _burnFromRake(rake);

        _playerEnters(game1, alice, grossEntry, sessionId);

        // Add game burn
        uint256 gameBurn = 50 ether;
        _creditPayout(game1, sessionId, alice, 0, gameBurn, false);

        (,,, uint256 totalBurned) = arcadeCore.getGlobalStats();
        assertEq(totalBurned, burnFromRake + gameBurn, "Total burned should match");
    }

    /// @notice Verify player stats accuracy over many games
    function test_Stats_PlayerStatsAccuracy() public {
        uint256 numGames = 50;
        uint256 expectedWins;
        uint256 expectedLosses;
        uint256 expectedWagered;

        for (uint256 i; i < numGames; i++) {
            uint256 sessionId = 1800 + i;
            uint256 amount = 10 ether + (i % 10) * 1 ether;

            _playerEnters(game1, alice, amount, sessionId);
            expectedWagered += amount;

            bool won = i % 3 != 0; // Win 2/3 of games
            if (won) {
                _creditPayout(game1, sessionId, alice, 5 ether, 0, true);
                expectedWins++;
            } else {
                _creditPayout(game1, sessionId, alice, 0, 0, false);
                expectedLosses++;
            }

            _settleSession(game1, sessionId);
            _passRateLimit();
        }

        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(alice);
        assertEq(stats.totalGamesPlayed, numGames, "Games played mismatch");
        assertEq(stats.totalWins, expectedWins, "Wins mismatch");
        assertEq(stats.totalLosses, expectedLosses, "Losses mismatch");

        // Note: totalWagered is scaled by 1e6, so we compare with tolerance
        uint256 scaledWagered = expectedWagered / 1e6;
        assertEq(stats.totalWagered, uint128(scaledWagered), "Wagered mismatch (scaled)");
    }

    /// @notice Verify global stats consistency
    function test_Stats_GlobalStatsConsistency() public {
        // Run complex operations
        for (uint256 i; i < 10; i++) {
            uint256 sessionId = 1900 + i;

            // Multiple entries
            for (uint256 j; j < 3; j++) {
                _playerEnters(game1, players[j], 100 ether, sessionId);
                _passRateLimit();
            }

            // Payouts with burns
            _creditPayout(game1, sessionId, players[0], 50 ether, 10 ether, true);
            _creditPayout(game1, sessionId, players[1], 30 ether, 5 ether, true);
            _creditPayout(game1, sessionId, players[2], 0, 20 ether, false);

            _settleSession(game1, sessionId);
        }

        // Verify consistency
        (
            uint256 totalGamesPlayed,
            uint256 totalVolume,
            uint256 totalRakeCollected,
            uint256 totalBurned
        ) = arcadeCore.getGlobalStats();

        // 10 sessions * 3 players = 30 games
        assertEq(totalGamesPlayed, 30, "Total games");

        // 10 sessions * 3 entries * 100 = 3000
        assertEq(totalVolume, 3000 ether, "Total volume");

        // Each 100 entry pays 5% = 5 ether rake
        // 30 entries * 5 = 150 ether total rake
        assertEq(totalRakeCollected, 150 ether, "Total rake");

        // Rake burn: 150 * 20% = 30 ether
        // Game burns: 10 sessions * (10+5+20) = 350 ether
        // Total: 380 ether
        assertEq(totalBurned, 30 ether + 350 ether, "Total burned");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENT VERIFICATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify complete event trail for full session lifecycle
    function test_Events_FullSessionEmitsAllEvents() public {
        uint256 sessionId = 2000;
        uint256 entryAmount = 100 ether;
        uint256 netAmount = _netAmount(entryAmount);
        uint256 rakeAmount = _rakeAmount(entryAmount);

        // Entry event
        vm.expectEmit(true, true, true, true);
        emit SessionCreated(game1, sessionId, uint64(block.timestamp));
        vm.expectEmit(true, true, true, true);
        emit EntryProcessed(game1, alice, sessionId, entryAmount, netAmount, rakeAmount);

        _playerEnters(game1, alice, entryAmount, sessionId);

        // Payout event
        uint256 payout = 50 ether;
        vm.expectEmit(true, true, true, true);
        emit PayoutCredited(alice, payout, payout);
        vm.expectEmit(true, true, true, true);
        emit GameSettled(game1, alice, sessionId, payout, 0, true);

        _creditPayout(game1, sessionId, alice, payout, 0, true);

        // Settle event
        uint256 remaining = netAmount - payout;
        vm.expectEmit(true, true, true, true);
        emit SessionSettled(game1, sessionId, payout, remaining);

        _settleSession(game1, sessionId);

        // Withdraw event
        vm.expectEmit(true, true, true, true);
        emit PayoutWithdrawn(alice, payout);

        _withdraw(alice);
    }
}

// ══════════════════════════════════════════════════════════════════════════════════
// MOCK CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════════

/// @notice Mock GhostCore for testing position requirements
contract MockGhostCore {
    mapping(address => bool) private _alive;

    function setAlive(
        address user,
        bool alive
    ) external {
        _alive[user] = alive;
    }

    function isAlive(
        address user
    ) external view returns (bool) {
        return _alive[user];
    }
}

/// @notice Mock V2 implementation for upgrade testing
contract ArcadeCoreV2 is ArcadeCore {
    // Same as V1, just proves upgrade works
    function version() external pure returns (uint256) {
        return 2;
    }
}
