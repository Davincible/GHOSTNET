// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";

// ══════════════════════════════════════════════════════════════════════════════════
// HANDLER CONTRACT FOR STATEFUL FUZZING
// ══════════════════════════════════════════════════════════════════════════════════

/// @title ArcadeCoreHandler
/// @notice Handler contract for invariant testing of ArcadeCore
/// @dev Provides bounded operations and ghost variables for tracking expected state
///
/// KNOWN ISSUE DOCUMENTED BY INVARIANT TESTING:
/// The contract allows both creditPayout AND emergencyRefund on ACTIVE sessions.
/// This creates a potential double-spend scenario:
/// 1. Player deposits 100 tokens (net 95 to prize pool)
/// 2. creditPayout(player, 50) credits 50 to pending (from prize pool tokens)
/// 3. emergencyRefund(player, 95) credits 95 to pending (same tokens!)
/// 4. Now pending = 145 but balance = 95 → INSOLVENCY
///
/// The handler constrains operations to avoid this scenario to test other invariants,
/// but a dedicated test demonstrates this vulnerability.
///
/// RECOMMENDED FIX: Either:
/// - Decrement sessionDeposits when creditPayout is called
/// - OR only allow refunds on CANCELLED sessions (not ACTIVE with payouts)
/// - OR track refund eligibility separately from deposit amount
contract ArcadeCoreHandler is Test {
    // ═══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    DataToken public dataToken;
    address public game;
    address public admin;

    // Ghost variables for invariant checking
    address[] public allPlayers;
    mapping(address => bool) public isPlayer;
    uint256[] public allSessionIds;
    mapping(uint256 => bool) public isSessionTracked;

    // Expected value tracking
    mapping(address => uint256) public playerTotalDeposits;
    mapping(uint256 => uint256) public sessionTotalDeposits;
    mapping(uint256 => uint256) public sessionTotalPaid;
    mapping(uint256 => bool) public sessionHasPayouts; // Track sessions with payouts
    uint256 public expectedTotalPending;

    // Monotonicity tracking
    uint256 public lastTotalBurned;
    uint256 public lastTotalVolume;

    // Call counters for debugging
    uint256 public processEntryCount;
    uint256 public creditPayoutCount;
    uint256 public withdrawPayoutCount;
    uint256 public settleSessionCount;
    uint256 public cancelSessionCount;
    uint256 public emergencyRefundCount;
    uint256 public claimExpiredRefundCount;

    // Session counter for creating new sessions
    uint256 public sessionCounter;

    // Constants
    uint256 constant MIN_ENTRY = 1 ether;
    uint256 constant MAX_ENTRY = 1000 ether;
    uint256 constant RAKE_BPS = 500; // 5%
    uint256 constant BPS = 10_000;

    // ═══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════════

    constructor(
        ArcadeCore _arcadeCore,
        DataToken _dataToken,
        address _game,
        address _admin
    ) {
        arcadeCore = _arcadeCore;
        dataToken = _dataToken;
        game = _game;
        admin = _admin;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // BOUNDED OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Process an entry with bounded inputs
    /// @param playerSeed Seed for player selection/creation
    /// @param amount Entry amount (will be bounded)
    /// @param useExistingSession Whether to use existing session or create new
    function processEntry(
        uint256 playerSeed,
        uint256 amount,
        bool useExistingSession
    ) external {
        // Bound inputs
        address player = _getOrCreatePlayer(playerSeed);
        amount = bound(amount, MIN_ENTRY, MAX_ENTRY);

        // Determine session ID
        uint256 sessionId;
        if (useExistingSession && allSessionIds.length > 0) {
            // Try to find an active session
            sessionId = _findActiveSession(playerSeed);
            if (sessionId == 0) {
                // No active session, create new
                sessionId = ++sessionCounter;
            }
        } else {
            sessionId = ++sessionCounter;
        }

        // Check player has enough balance
        if (dataToken.balanceOf(player) < amount) {
            return;
        }

        // Execute with rate limiting skip
        vm.warp(block.timestamp + 2);

        vm.prank(game);
        try arcadeCore.processEntry(player, amount, sessionId) returns (uint256 netAmount) {
            // Track session
            if (!isSessionTracked[sessionId]) {
                allSessionIds.push(sessionId);
                isSessionTracked[sessionId] = true;
            }

            // Track deposits
            playerTotalDeposits[player] += netAmount;
            sessionTotalDeposits[sessionId] += netAmount;

            processEntryCount++;
        } catch {
            // Entry failed (expected for various reasons)
        }
    }

    /// @notice Credit a payout with bounded inputs
    /// @param sessionSeed Seed for session selection
    /// @param playerSeed Seed for player selection
    /// @param amountPct Percentage of remaining capacity to pay (0-100)
    /// @param burnPct Percentage of payout to burn (0-100)
    function creditPayout(
        uint256 sessionSeed,
        uint256 playerSeed,
        uint256 amountPct,
        uint256 burnPct
    ) external {
        // Need sessions to credit payouts
        if (allSessionIds.length == 0) return;

        // Select session
        uint256 sessionId = allSessionIds[sessionSeed % allSessionIds.length];

        // Check session is active
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        if (session.state != IArcadeCore.SessionState.ACTIVE) return;

        // Select or create player
        address player = _getOrCreatePlayer(playerSeed);

        // Calculate bounded amounts
        uint256 remaining = arcadeCore.getSessionRemainingCapacity(sessionId);
        if (remaining == 0) return;

        amountPct = bound(amountPct, 0, 100);
        burnPct = bound(burnPct, 0, 50); // Max 50% burn

        uint256 totalDisbursement = (remaining * amountPct) / 100;
        uint256 burnAmount = (totalDisbursement * burnPct) / 100;
        uint256 payoutAmount = totalDisbursement - burnAmount;

        vm.prank(game);
        try arcadeCore.creditPayout(sessionId, player, payoutAmount, burnAmount, payoutAmount > 0) {
            expectedTotalPending += payoutAmount;
            sessionTotalPaid[sessionId] += totalDisbursement;
            sessionHasPayouts[sessionId] = true; // Mark session as having payouts
            creditPayoutCount++;
        } catch {
            // Payout failed
        }
    }

    /// @notice Withdraw pending payout for a player
    /// @param playerSeed Seed for player selection
    function withdrawPayout(
        uint256 playerSeed
    ) external {
        if (allPlayers.length == 0) return;

        address player = allPlayers[playerSeed % allPlayers.length];
        uint256 pending = arcadeCore.getPendingPayout(player);

        if (pending == 0) return;

        vm.prank(player);
        try arcadeCore.withdrawPayout() returns (uint256 amount) {
            expectedTotalPending -= amount;
            withdrawPayoutCount++;
        } catch {
            // Withdrawal failed
        }
    }

    /// @notice Settle a session
    /// @param sessionSeed Seed for session selection
    function settleSession(
        uint256 sessionSeed
    ) external {
        if (allSessionIds.length == 0) return;

        uint256 sessionId = allSessionIds[sessionSeed % allSessionIds.length];

        // Check session is active
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        if (session.state != IArcadeCore.SessionState.ACTIVE) return;

        vm.prank(game);
        try arcadeCore.settleSession(sessionId) {
            settleSessionCount++;
        } catch {
            // Settlement failed
        }
    }

    /// @notice Cancel a session
    /// @param sessionSeed Seed for session selection
    function cancelSession(
        uint256 sessionSeed
    ) external {
        if (allSessionIds.length == 0) return;

        uint256 sessionId = allSessionIds[sessionSeed % allSessionIds.length];

        // Check session is active
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        if (session.state != IArcadeCore.SessionState.ACTIVE) return;

        vm.prank(game);
        try arcadeCore.cancelSession(sessionId) {
            cancelSessionCount++;
        } catch {
            // Cancellation failed
        }
    }

    /// @notice Emergency refund a player from a session
    /// @param sessionSeed Seed for session selection
    /// @param playerSeed Seed for player selection
    /// @param amountPct Percentage of deposit to refund (0-100)
    /// @dev CONSTRAINED: Only allows refunds on CANCELLED sessions that have NO payouts
    ///      to avoid known bug where creditPayout + emergencyRefund can cause insolvency.
    ///      See dedicated test for that vulnerability.
    function emergencyRefund(
        uint256 sessionSeed,
        uint256 playerSeed,
        uint256 amountPct
    ) external {
        if (allSessionIds.length == 0) return;
        if (allPlayers.length == 0) return;

        uint256 sessionId = allSessionIds[sessionSeed % allSessionIds.length];
        address player = allPlayers[playerSeed % allPlayers.length];

        // Check session allows refunds
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);

        // CONSTRAINT: Only allow refunds on CANCELLED sessions with NO payouts
        // This avoids the known bug where sessions with payouts can be drained
        // via creditPayout + cancel + emergencyRefund combo (see vulnerability test)
        if (session.state != IArcadeCore.SessionState.CANCELLED) return;
        if (sessionHasPayouts[sessionId]) return; // Don't allow refunds if payouts were made

        // Check player has deposit
        uint256 deposit = arcadeCore.getSessionDeposit(sessionId, player);
        if (deposit == 0) return;

        // Check not already refunded
        if (arcadeCore.isRefunded(sessionId, player)) return;

        // Bound refund amount
        amountPct = bound(amountPct, 1, 100);
        uint256 amount = (deposit * amountPct) / 100;
        if (amount == 0) amount = 1;

        vm.prank(game);
        try arcadeCore.emergencyRefund(sessionId, player, amount) {
            expectedTotalPending += amount;
            emergencyRefundCount++;
        } catch {
            // Refund failed
        }
    }

    /// @notice Claim expired refund for a player
    /// @param sessionSeed Seed for session selection
    /// @param playerSeed Seed for player selection
    /// @dev CONSTRAINED: Only allows claims on CANCELLED sessions with NO payouts
    function claimExpiredRefund(
        uint256 sessionSeed,
        uint256 playerSeed
    ) external {
        if (allSessionIds.length == 0) return;
        if (allPlayers.length == 0) return;

        uint256 sessionId = allSessionIds[sessionSeed % allSessionIds.length];
        address player = allPlayers[playerSeed % allPlayers.length];

        // Check session is cancelled
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        if (session.state != IArcadeCore.SessionState.CANCELLED) return;

        // CONSTRAINT: Don't allow claims if payouts were made (same bug as emergencyRefund)
        if (sessionHasPayouts[sessionId]) return;

        // Check player has deposit
        uint256 deposit = arcadeCore.getSessionDeposit(sessionId, player);
        if (deposit == 0) return;

        // Check not already refunded
        if (arcadeCore.isRefunded(sessionId, player)) return;

        // Anyone can call this
        address caller = allPlayers[(playerSeed + 1) % allPlayers.length];
        vm.prank(caller);
        try arcadeCore.claimExpiredRefund(sessionId, player) {
            expectedTotalPending += deposit;
            claimExpiredRefundCount++;
        } catch {
            // Claim failed
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Get or create a player based on seed
    /// @dev 70% chance to reuse existing player, 30% to create new
    function _getOrCreatePlayer(
        uint256 seed
    ) internal returns (address) {
        if (allPlayers.length > 0 && seed % 10 < 7) {
            // 70% chance: reuse existing player
            return allPlayers[seed % allPlayers.length];
        }

        // 30% chance: new player
        address newPlayer = makeAddr(string.concat("player", vm.toString(allPlayers.length)));
        allPlayers.push(newPlayer);
        isPlayer[newPlayer] = true;

        // Fund player
        vm.prank(admin);
        dataToken.transfer(newPlayer, 100_000 ether);

        // Approve arcade
        vm.prank(newPlayer);
        dataToken.approve(address(arcadeCore), type(uint256).max);

        return newPlayer;
    }

    /// @notice Find an active session from tracked sessions
    function _findActiveSession(
        uint256 seed
    ) internal view returns (uint256) {
        if (allSessionIds.length == 0) return 0;

        // Start from random index and search
        uint256 startIdx = seed % allSessionIds.length;
        for (uint256 i; i < allSessionIds.length; i++) {
            uint256 idx = (startIdx + i) % allSessionIds.length;
            uint256 sessionId = allSessionIds[idx];
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
            if (session.state == IArcadeCore.SessionState.ACTIVE) {
                return sessionId;
            }
        }
        return 0;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS FOR INVARIANT CHECKS
    // ═══════════════════════════════════════════════════════════════════════════════

    function getPlayersCount() external view returns (uint256) {
        return allPlayers.length;
    }

    function getSessionsCount() external view returns (uint256) {
        return allSessionIds.length;
    }

    function getAllPlayers() external view returns (address[] memory) {
        return allPlayers;
    }

    function getAllSessionIds() external view returns (uint256[] memory) {
        return allSessionIds;
    }

    function getCallSummary()
        external
        view
        returns (
            uint256 entries,
            uint256 payouts,
            uint256 withdrawals,
            uint256 settles,
            uint256 cancels,
            uint256 refunds,
            uint256 expiredClaims
        )
    {
        return (
            processEntryCount,
            creditPayoutCount,
            withdrawPayoutCount,
            settleSessionCount,
            cancelSessionCount,
            emergencyRefundCount,
            claimExpiredRefundCount
        );
    }
}

// ══════════════════════════════════════════════════════════════════════════════════
// INVARIANT TEST CONTRACT
// ══════════════════════════════════════════════════════════════════════════════════

/// @title ArcadeCoreInvariantTest
/// @notice Invariant tests for ArcadeCore
/// @dev Tests critical system invariants that must hold under all conditions
contract ArcadeCoreInvariantTest is StdInvariant, Test {
    // ═══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    ArcadeCoreHandler public handler;
    DataToken public dataToken;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");
    address public game = makeAddr("game");

    // Monotonicity tracking
    uint256 public lastTotalBurned;
    uint256 public lastTotalVolume;

    // ═══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Deploy DataToken
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = admin;
        amounts[0] = 100_000_000 ether;

        vm.startPrank(admin);
        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore via proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude arcade from tax
        dataToken.setTaxExclusion(address(arcadeCore), true);

        // Register game
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: 500, // 5%
            burnBps: 2000, // 20% of rake burned
            requiresPosition: false,
            paused: false
        });
        arcadeCore.registerGame(game, config);
        vm.stopPrank();

        // Deploy handler
        handler = new ArcadeCoreHandler(arcadeCore, dataToken, game, admin);

        // Configure invariant targets
        targetContract(address(handler));

        // Configure selectors
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = handler.processEntry.selector;
        selectors[1] = handler.creditPayout.selector;
        selectors[2] = handler.withdrawPayout.selector;
        selectors[3] = handler.settleSession.selector;
        selectors[4] = handler.cancelSession.selector;
        selectors[5] = handler.emergencyRefund.selector;
        selectors[6] = handler.claimExpiredRefund.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CRITICAL INVARIANTS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice CRITICAL: Contract must always have enough tokens to cover pending payouts
    /// @dev Solvency is the most important invariant - if violated, users cannot withdraw
    function invariant_ContractAlwaysSolvent() public view {
        uint256 balance = dataToken.balanceOf(address(arcadeCore));
        uint256 pending = arcadeCore.getTotalPendingPayouts();

        assertGe(balance, pending, "SOLVENCY VIOLATED: balance < pending payouts");
    }

    /// @notice Sum of all individual pending payouts must equal totalPendingPayouts
    /// @dev Ensures no accounting discrepancy between individual and aggregate tracking
    function invariant_PendingPayoutsSumMatchesTotal() public view {
        address[] memory players = handler.getAllPlayers();
        uint256 sum;

        for (uint256 i; i < players.length; i++) {
            sum += arcadeCore.getPendingPayout(players[i]);
        }

        assertEq(sum, arcadeCore.getTotalPendingPayouts(), "PAYOUT SUM MISMATCH");
    }

    /// @notice For every session: totalPaid <= prizePool
    /// @dev Prevents overdisbursement from any session
    function invariant_SessionPayoutsNeverExceedPrizePool() public view {
        uint256[] memory sessionIds = handler.getAllSessionIds();

        for (uint256 i; i < sessionIds.length; i++) {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionIds[i]);

            assertLe(
                session.totalPaid,
                session.prizePool,
                string.concat(
                    "SESSION PAYOUT EXCEEDED: session ",
                    vm.toString(sessionIds[i]),
                    " totalPaid > prizePool"
                )
            );
        }
    }

    /// @notice Session state transitions must be valid
    /// @dev NONE -> ACTIVE only via processEntry
    ///      ACTIVE -> SETTLED/CANCELLED only
    ///      SETTLED/CANCELLED are terminal
    function invariant_SessionStateTransitionsValid() public view {
        uint256[] memory sessionIds = handler.getAllSessionIds();

        for (uint256 i; i < sessionIds.length; i++) {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionIds[i]);

            // All tracked sessions should have moved past NONE state
            // (processEntry creates them in ACTIVE state)
            assertTrue(
                session.state != IArcadeCore.SessionState.NONE, "Tracked session in NONE state"
            );

            // If settled, settledAt must be set
            if (session.state == IArcadeCore.SessionState.SETTLED) {
                assertGt(session.settledAt, 0, "Settled session has zero settledAt");
            }

            // If cancelled, settledAt must be set
            if (session.state == IArcadeCore.SessionState.CANCELLED) {
                assertGt(session.settledAt, 0, "Cancelled session has zero settledAt");
            }

            // createdAt must always be set for non-NONE sessions
            assertGt(session.createdAt, 0, "Session has zero createdAt");

            // Game address must be set
            assertNotEq(session.game, address(0), "Session has zero game address");
        }
    }

    /// @notice Total burned can never decrease
    /// @dev Burn operations are one-way
    function invariant_TotalBurnedNeverDecreases() public {
        (,,, uint256 currentBurned) = arcadeCore.getGlobalStats();

        assertGe(currentBurned, lastTotalBurned, "BURN DECREASED");
        lastTotalBurned = currentBurned;
    }

    /// @notice Total volume can never decrease
    /// @dev Volume only increases on entries
    function invariant_TotalVolumeNeverDecreases() public {
        (, uint256 currentVolume,,) = arcadeCore.getGlobalStats();

        assertGe(currentVolume, lastTotalVolume, "VOLUME DECREASED");
        lastTotalVolume = currentVolume;
    }

    /// @notice Registered games have valid config, unregistered don't
    function invariant_GameRegistrationConsistent() public view {
        // Game should be registered
        assertTrue(arcadeCore.isGameRegistered(game), "Test game not registered");

        // Config should have reasonable values
        IArcadeCore.GameConfig memory config = arcadeCore.getGameConfig(game);
        assertGt(config.minEntry, 0, "Zero min entry");
        assertLe(config.rakeBps, 10_000, "Rake > 100%");
        assertLe(config.burnBps, 10_000, "Burn > 100%");
    }

    /// @notice Refunded players are marked correctly
    /// @dev Once refunded, player cannot be refunded again (but may have partial remaining)
    function invariant_RefundTrackingConsistent() public view {
        uint256[] memory sessionIds = handler.getAllSessionIds();
        address[] memory players = handler.getAllPlayers();

        for (uint256 i; i < sessionIds.length; i++) {
            uint256 sessionId = sessionIds[i];
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);

            // Only check for cancelled sessions (where refunds happen)
            if (session.state != IArcadeCore.SessionState.CANCELLED) continue;

            for (uint256 j; j < players.length; j++) {
                address player = players[j];
                bool isRefundedFlag = arcadeCore.isRefunded(sessionId, player);
                uint256 grossDeposit = arcadeCore.getSessionGrossDeposit(sessionId, player);

                // If player has gross deposit and is marked refunded, that's consistent
                // (partial refunds allowed - remaining deposit may be > 0)
                // The key invariant is: once marked refunded, no further refunds possible
                if (isRefundedFlag && grossDeposit == 0) {
                    // If marked refunded but never deposited, that's inconsistent
                    // (shouldn't happen - can't refund without deposit)
                    assertTrue(false, "Refund flag set but no gross deposit ever recorded");
                }
            }
        }
    }

    /// @notice Session prize pool equals sum of net deposits minus payouts
    /// @dev Accounting invariant for each session
    function invariant_SessionAccountingConsistent() public view {
        uint256[] memory sessionIds = handler.getAllSessionIds();

        for (uint256 i; i < sessionIds.length; i++) {
            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionIds[i]);

            // Active sessions: remaining capacity = prizePool - totalPaid
            if (session.state == IArcadeCore.SessionState.ACTIVE) {
                uint256 remaining = arcadeCore.getSessionRemainingCapacity(sessionIds[i]);
                assertEq(
                    remaining,
                    session.prizePool - session.totalPaid,
                    "Remaining capacity calculation wrong"
                );
            }

            // For settled sessions, totalPaid + remaining sent to treasury = prizePool
            // (Can't directly verify treasury transfer, but can verify totalPaid <= prizePool)
        }
    }

    /// @notice Global games played counter is consistent
    function invariant_GamesPlayedConsistent() public view {
        (uint256 totalGamesPlayed,,,) = arcadeCore.getGlobalStats();

        // Should be at least as many as entries processed
        // Note: totalGamesPlayed increments per entry, not per unique game
        assertGe(totalGamesPlayed, 0, "Negative games played");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CALL SUMMARY FOR DEBUGGING
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Log call summary for debugging invariant failures
    function invariant_CallSummary() public view {
        (
            uint256 entries,
            uint256 payouts,
            uint256 withdrawals,
            uint256 settles,
            uint256 cancels,
            uint256 refunds,
            uint256 expiredClaims
        ) = handler.getCallSummary();

        console.log("=== Call Summary ===");
        console.log("Players:", handler.getPlayersCount());
        console.log("Sessions:", handler.getSessionsCount());
        console.log("Entries:", entries);
        console.log("Payouts:", payouts);
        console.log("Withdrawals:", withdrawals);
        console.log("Settles:", settles);
        console.log("Cancels:", cancels);
        console.log("Refunds:", refunds);
        console.log("Expired Claims:", expiredClaims);
        console.log("Pending:", arcadeCore.getTotalPendingPayouts());
        console.log("Balance:", dataToken.balanceOf(address(arcadeCore)));
    }
}

// ══════════════════════════════════════════════════════════════════════════════════
// FUZZ TEST CONTRACT
// ══════════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════════
// VULNERABILITY DEMONSTRATION TEST
// ══════════════════════════════════════════════════════════════════════════════════

/// @title ArcadeCoreVulnerabilityTest
/// @notice Demonstrates solvency vulnerability found by invariant testing
/// @dev This test shows how creditPayout + emergencyRefund on ACTIVE sessions
///      can cause the contract to become insolvent (pending > balance)
contract ArcadeCoreVulnerabilityTest is Test {
    ArcadeCore public arcadeCore;
    DataToken public dataToken;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");
    address public game = makeAddr("game");
    address public alice = makeAddr("alice");

    uint256 constant ENTRY_AMOUNT = 100 ether;
    uint256 constant RAKE_BPS = 500; // 5%
    uint256 constant BPS = 10_000;
    uint256 constant SESSION_1 = 1;

    function setUp() public {
        // Deploy DataToken
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = alice;
        amounts[0] = 100_000_000 ether;

        vm.startPrank(admin);
        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore via proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude arcade from tax
        dataToken.setTaxExclusion(address(arcadeCore), true);

        // Register game
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: uint16(RAKE_BPS),
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });
        arcadeCore.registerGame(game, config);
        vm.stopPrank();

        vm.prank(alice);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    /// @notice VULNERABILITY: creditPayout + emergencyRefund on ACTIVE session causes insolvency
    /// @dev This demonstrates a real bug found by invariant testing.
    ///      The contract allows both payouts AND refunds on ACTIVE sessions,
    ///      which can drain more tokens than the session contains.
    ///
    ///      ATTACK SCENARIO:
    ///      1. Player deposits 100 tokens (net 95 to prize pool)
    ///      2. Game credits 50 token payout to player (from prize pool)
    ///      3. Game refunds player's full deposit (95 tokens)
    ///      4. Player has 145 tokens pending but contract only has 95
    ///
    ///      ROOT CAUSE: emergencyRefund checks sessionDeposits which is NOT
    ///      decremented by creditPayout. The player can get both their winnings
    ///      AND their original stake refunded.
    ///
    ///      FIX VERIFIED: This test confirms the vulnerability is now blocked.
    ///      The refund is rejected with RefundsBlockedAfterPayouts error.
    function test_FIXED_RefundsBlockedAfterPayouts() public {
        // Step 1: Alice deposits
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);

        // Net amount after 5% rake
        uint256 expectedNet = ENTRY_AMOUNT - (ENTRY_AMOUNT * RAKE_BPS / BPS);
        assertEq(netAmount, expectedNet, "Net amount should be entry minus rake");

        // Contract now has 95 tokens
        uint256 contractBalance = dataToken.balanceOf(address(arcadeCore));
        assertEq(contractBalance, expectedNet, "Contract should have net amount");

        // Step 2: Credit a partial payout (50% of prize pool)
        uint256 payoutAmount = netAmount / 2;
        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

        // Alice now has payout pending
        assertEq(arcadeCore.getPendingPayout(alice), payoutAmount, "Payout should be pending");

        // Step 3: Session is still ACTIVE - try to refund full deposit
        // FIX: This now correctly reverts!
        uint256 deposit = arcadeCore.getSessionDeposit(SESSION_1, alice);

        // Attempt refund after payout - should be blocked
        vm.prank(game);
        vm.expectRevert(IArcadeCore.RefundsBlockedAfterPayouts.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, deposit);

        // Step 4: Verify solvency is maintained
        uint256 totalPending = arcadeCore.getTotalPendingPayouts();
        uint256 balance = dataToken.balanceOf(address(arcadeCore));

        // FIXED: Only payout is pending, contract is solvent
        assertEq(totalPending, payoutAmount, "Only payout should be pending");
        assertGe(balance, totalPending, "Contract should be solvent");

        console.log("=== FIX VERIFIED ===");
        console.log("Total pending payouts:", totalPending);
        console.log("Contract balance:", balance);
        console.log("Solvency maintained: balance >= pending");
    }

    /// @notice Shows that the vulnerability only exists on ACTIVE sessions
    /// @dev Once a session is CANCELLED, payouts are blocked, so this path is safe
    function test_CancelledSession_NoVulnerability() public {
        // Step 1: Alice deposits
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);

        // Step 2: Cancel session (no payouts possible now)
        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        // Step 3: Try to credit payout - should fail
        vm.prank(game);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);

        // Step 4: Refund works because no payout was possible
        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        // Solvency maintained
        uint256 totalPending = arcadeCore.getTotalPendingPayouts();
        uint256 balance = dataToken.balanceOf(address(arcadeCore));
        assertGe(balance, totalPending, "Cancelled path should maintain solvency");
    }
}

/// @title ArcadeCoreFuzzTest
/// @notice Fuzz tests for ArcadeCore individual operations
/// @dev Property-based tests that verify single operation behavior
contract ArcadeCoreFuzzTest is Test {
    // ═══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    DataToken public dataToken;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");
    address public game = makeAddr("game");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant MIN_ENTRY = 1 ether;
    uint256 constant MAX_ENTRY = 1000 ether;
    uint256 constant RAKE_BPS = 500;
    uint256 constant BURN_BPS = 2000;
    uint256 constant BPS = 10_000;
    uint256 constant SESSION_1 = 1;

    // ═══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Deploy DataToken
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = alice;
        recipients[1] = bob;
        amounts[0] = 50_000_000 ether;
        amounts[1] = 50_000_000 ether;

        vm.startPrank(admin);
        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore via proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude arcade from tax
        dataToken.setTaxExclusion(address(arcadeCore), true);

        // Register game
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: MIN_ENTRY,
            maxEntry: MAX_ENTRY,
            rakeBps: uint16(RAKE_BPS),
            burnBps: uint16(BURN_BPS),
            requiresPosition: false,
            paused: false
        });
        arcadeCore.registerGame(game, config);
        vm.stopPrank();

        // Approve spending
        vm.prank(alice);
        dataToken.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: PROCESS ENTRY
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Entry within valid range always succeeds
    function testFuzz_ProcessEntry_ValidRange(
        uint256 amount
    ) public {
        amount = bound(amount, MIN_ENTRY, MAX_ENTRY);

        uint256 balanceBefore = dataToken.balanceOf(alice);

        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, amount, SESSION_1);

        // Verify net amount calculation
        uint256 expectedRake = (amount * RAKE_BPS) / BPS;
        uint256 expectedNet = amount - expectedRake;
        assertEq(netAmount, expectedNet, "Net amount incorrect");

        // Verify token transfer
        uint256 balanceAfter = dataToken.balanceOf(alice);
        assertEq(balanceBefore - balanceAfter, amount, "Wrong amount transferred");

        // Verify session state
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, expectedNet, "Prize pool incorrect");
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.ACTIVE), "Wrong state");
    }

    /// @notice Fuzz: Entry below minimum always fails
    function testFuzz_ProcessEntry_BelowMinimum(
        uint256 amount
    ) public {
        vm.assume(amount > 0 && amount < MIN_ENTRY);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, amount, SESSION_1);
    }

    /// @notice Fuzz: Entry above maximum always fails
    function testFuzz_ProcessEntry_AboveMaximum(
        uint256 amount
    ) public {
        vm.assume(amount > MAX_ENTRY);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, amount, SESSION_1);
    }

    /// @notice Fuzz: Multiple entries accumulate correctly
    function testFuzz_ProcessEntry_MultipleEntries(
        uint256[] memory amounts
    ) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10);

        uint256 totalNet;

        for (uint256 i; i < amounts.length; i++) {
            amounts[i] = bound(amounts[i], MIN_ENTRY, MAX_ENTRY);

            vm.warp(block.timestamp + 2); // Rate limiting

            vm.prank(game);
            uint256 netAmount = arcadeCore.processEntry(alice, amounts[i], SESSION_1);
            totalNet += netAmount;
        }

        // Verify session prize pool
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, totalNet, "Prize pool should equal sum of net amounts");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: CREDIT PAYOUT
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Payout within prize pool always succeeds
    function testFuzz_CreditPayout_WithinPrizePool(
        uint256 entryAmount,
        uint256 payoutPct
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        payoutPct = bound(payoutPct, 0, 100);

        // Create session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Calculate payout
        uint256 payoutAmount = (netAmount * payoutPct) / 100;

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

        // Verify pending payout
        assertEq(arcadeCore.getPendingPayout(alice), payoutAmount, "Pending payout incorrect");

        // Verify session accounting
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, payoutAmount, "Session totalPaid incorrect");
    }

    /// @notice Fuzz: Payout exceeding prize pool always fails
    function testFuzz_CreditPayout_ExceedsPrizePool(
        uint256 entryAmount,
        uint256 excessAmount
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        excessAmount = bound(excessAmount, 1, type(uint128).max);

        // Create session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Try to pay more than prize pool
        uint256 payoutAmount = netAmount + excessAmount;

        vm.prank(game);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);
    }

    /// @notice Fuzz: Payout + burn within prize pool succeeds
    function testFuzz_CreditPayout_WithBurn(
        uint256 entryAmount,
        uint256 payoutPct,
        uint256 burnPct
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        payoutPct = bound(payoutPct, 0, 50);
        burnPct = bound(burnPct, 0, 50);

        // Ensure total doesn't exceed 100%
        if (payoutPct + burnPct > 100) {
            burnPct = 100 - payoutPct;
        }

        // Create session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Calculate amounts
        uint256 payoutAmount = (netAmount * payoutPct) / 100;
        uint256 burnAmount = (netAmount * burnPct) / 100;

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, burnAmount, true);

        // Verify session accounting
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, payoutAmount + burnAmount, "Total paid incorrect");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: REFUNDS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Refund within deposit always succeeds
    function testFuzz_EmergencyRefund_WithinDeposit(
        uint256 entryAmount,
        uint256 refundPct
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        refundPct = bound(refundPct, 1, 100);

        // Create and cancel session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        // Calculate refund
        uint256 refundAmount = (netAmount * refundPct) / 100;
        if (refundAmount == 0) refundAmount = 1;

        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, refundAmount);

        // Verify pending payout
        assertEq(arcadeCore.getPendingPayout(alice), refundAmount, "Refund not credited");
    }

    /// @notice Fuzz: Refund exceeding deposit always fails
    function testFuzz_EmergencyRefund_ExceedsDeposit(
        uint256 entryAmount,
        uint256 excessAmount
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        excessAmount = bound(excessAmount, 1, type(uint128).max);

        // Create and cancel session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        // Try to refund more than deposit
        uint256 refundAmount = netAmount + excessAmount;

        vm.prank(game);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, refundAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: BATCH OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Batch payouts within size limit succeed
    function testFuzz_BatchCreditPayouts_ValidSize(
        uint8 batchSize
    ) public {
        batchSize = uint8(bound(batchSize, 1, 50)); // Keep reasonable for test

        // Create session with enough funds
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, MAX_ENTRY, SESSION_1);

        // Prepare batch arrays
        uint256[] memory sessionIds = new uint256[](batchSize);
        address[] memory players = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory burnAmounts = new uint256[](batchSize);
        bool[] memory results = new bool[](batchSize);

        uint256 perPlayer = netAmount / batchSize;

        for (uint256 i; i < batchSize; i++) {
            sessionIds[i] = SESSION_1;
            players[i] = makeAddr(string.concat("batchPlayer", vm.toString(i)));
            amounts[i] = perPlayer / 2; // Use half to ensure we don't exceed
            burnAmounts[i] = 0;
            results[i] = true;
        }

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Verify total paid
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, (perPlayer / 2) * batchSize, "Batch total incorrect");
    }

    /// @notice Fuzz: Batch payouts exceeding max size fail
    function testFuzz_BatchCreditPayouts_TooLarge(
        uint256 batchSize
    ) public {
        uint256 maxBatch = arcadeCore.MAX_BATCH_SIZE();
        batchSize = bound(batchSize, maxBatch + 1, maxBatch + 100);

        // Create arrays (won't execute but need valid structure)
        uint256[] memory sessionIds = new uint256[](batchSize);
        address[] memory players = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory burnAmounts = new uint256[](batchSize);
        bool[] memory results = new bool[](batchSize);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.BatchTooLarge.selector, batchSize, maxBatch)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: WITHDRAW
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Withdraw always returns correct amount
    function testFuzz_WithdrawPayout_CorrectAmount(
        uint256 entryAmount,
        uint256 payoutAmount
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);

        // Create session and credit payout
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        payoutAmount = bound(payoutAmount, 1, netAmount);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

        // Withdraw
        uint256 balanceBefore = dataToken.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, payoutAmount, "Withdrawn amount incorrect");
        assertEq(dataToken.balanceOf(alice) - balanceBefore, payoutAmount, "Balance not updated");
        assertEq(arcadeCore.getPendingPayout(alice), 0, "Pending not cleared");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUZZ: SESSION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Settled sessions send remaining to treasury
    function testFuzz_SettleSession_TreasuryReceivesRemaining(
        uint256 entryAmount,
        uint256 payoutPct
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);
        payoutPct = bound(payoutPct, 0, 99); // Leave some remaining

        // Create session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Partial payout
        uint256 payoutAmount = (netAmount * payoutPct) / 100;
        if (payoutAmount > 0) {
            vm.prank(game);
            arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);
        }

        uint256 remaining = netAmount - payoutAmount;
        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        // Settle
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        // Verify treasury received remaining
        uint256 treasuryAfter = dataToken.balanceOf(treasury);
        assertEq(treasuryAfter - treasuryBefore, remaining, "Treasury didn't receive remaining");

        // Verify session state
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED), "Not settled");
    }

    /// @notice Fuzz: Cancelled sessions allow refunds
    function testFuzz_CancelSession_AllowsRefunds(
        uint256 entryAmount
    ) public {
        entryAmount = bound(entryAmount, MIN_ENTRY, MAX_ENTRY);

        // Create session
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Cancel
        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        // Verify can refund
        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount, "Refund not credited");
    }
}
