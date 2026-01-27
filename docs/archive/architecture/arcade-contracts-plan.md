# GHOSTNET Arcade: Contract Architecture Plan

**Version:** 1.0  
**Created:** 2026-01-21  
**Author:** Architecture Session  
**Status:** PLANNING (Pre-Implementation)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Design Principles](#2-design-principles)
3. [Integration Points](#3-integration-points)
4. [Contract Hierarchy](#4-contract-hierarchy)
5. [Detailed Contract Specifications](#5-detailed-contract-specifications)
6. [Randomness Architecture](#6-randomness-architecture)
7. [Security Model](#7-security-model)
8. [Gas Optimization Strategy](#8-gas-optimization-strategy)
9. [Upgrade Strategy](#9-upgrade-strategy)
10. [Implementation Order](#10-implementation-order)
11. [Open Questions](#11-open-questions)

---

## 1. Executive Summary

### What We're Building

A modular arcade game system for GHOSTNET that:
- Supports 9 different mini-games with varying mechanics
- Integrates with the existing GhostCore position system for boosts
- Uses MegaETH-compatible randomness (no VRF available)
- Burns $DATA tokens as core economic mechanic
- Provides provably fair outcomes

### Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Upgradeability | UUPS Proxy for ArcadeCore only | Balance between upgradability and gas costs |
| Randomness | Future block hash pattern | MegaETH has no VRF; prevrandao is constant for ~60s |
| Token flow | Pull-payment pattern | Prevents DoS via gas griefing |
| Game registration | Whitelist via registry | Security - only audited games can interact |
| Integration | Read-only from GhostCore | Arcade reads boost eligibility, doesn't modify positions |

### What We're NOT Building Yet

- Matchmaking service (deferred to CODE DUEL implementation)
- Spectator betting contracts (Phase 3B)
- Crew/team contracts (Phase 3C)

---

## 2. Design Principles

### 2.1 Separation of Concerns

```
┌─────────────────────────────────────────────────────────────────┐
│                    RESPONSIBILITY BOUNDARIES                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ArcadeCore           "The Bank"                                │
│  ───────────────────────────────────────────────────────────    │
│  • Token custody                                                 │
│  • Entry fee collection                                          │
│  • Payout distribution                                           │
│  • Burn execution                                                │
│  • Global rate limiting                                          │
│  • Player statistics                                             │
│                                                                  │
│  GameRegistry         "The Gatekeeper"                          │
│  ───────────────────────────────────────────────────────────    │
│  • Game whitelist                                                │
│  • Per-game configuration                                        │
│  • Per-game pause                                                │
│  • Fee structure                                                 │
│                                                                  │
│  Individual Games     "The Logic"                               │
│  ───────────────────────────────────────────────────────────    │
│  • Game-specific rules                                           │
│  • Session management                                            │
│  • Outcome determination                                         │
│  • Player actions                                                │
│                                                                  │
│  Randomness Bases     "The Entropy"                             │
│  ───────────────────────────────────────────────────────────    │
│  • Seed commitment                                               │
│  • Hash capture                                                  │
│  • Provenance tracking                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Trust Minimization

**Principle:** Games should not hold tokens. All token custody in ArcadeCore.

```solidity
// BAD: Game holds tokens
function placeBet() external {
    dataToken.transferFrom(msg.sender, address(this), amount); // Game holds!
}

// GOOD: ArcadeCore holds tokens
function placeBet() external {
    (sessionId, netAmount) = arcadeCore.processEntry(msg.sender, amount, gameId);
    // ArcadeCore now holds tokens, game just tracks session
}
```

### 2.3 Fail-Safe Defaults

Every game must handle:
- What happens if seed block expires (256 blocks)?
- What happens if no one reveals in commit-reveal?
- What happens if game is paused mid-session?

**Default:** Refund players. Never lock funds.

### 2.4 Composability with GhostCore

```
┌─────────────────┐         ┌─────────────────┐
│   GhostCore     │◄────────│   ArcadeCore    │
│   (Positions)   │  reads  │   (Games)       │
└─────────────────┘         └─────────────────┘
        │                           │
        │                           │
        ▼                           ▼
   Boost eligibility          Mini-game rewards
   isAlive() check            can grant boosts
```

**Integration is READ-ONLY from Arcade to GhostCore:**
- `ghostCore.isAlive(player)` - Check if player has position
- `ghostCore.getPosition(player)` - Read stake amount for tiered games
- `ghostCore.getActiveBoosts(player)` - Check existing boosts

**Arcade does NOT call:**
- `jackIn()`, `extract()`, `addStake()` - Player's decision
- `applyBoost()` - Requires server signature (different flow)

### 2.5 EIP-7702 (EOA Delegation) Considerations

With Prague EVM (Solidity 0.8.30+), EOAs can delegate to smart contracts via EIP-7702. This allows externally owned accounts to temporarily act as smart contracts.

**Security Analysis for Arcade Contracts:**

| Check Pattern | Used in Arcade? | Risk Level | Notes |
|---------------|-----------------|------------|-------|
| `tx.origin == msg.sender` | **No** | N/A | We never use this anti-pattern |
| `extcodesize == 0` | **No** | N/A | We never check for EOA this way |
| Address-based rate limiting | Yes | **None** | Works correctly—limits by address regardless of EOA status |
| Signature verification | Via GhostCore | **Unaffected** | ECDSA signatures remain valid for delegated EOAs |
| `msg.sender` checks | Yes | **None** | Delegated EOAs still have consistent `msg.sender` |

**Conclusion:** EIP-7702 does **NOT** introduce security risks for this design.

**Why we're safe:**
1. **No `tx.origin` usage:** We never assume `tx.origin == msg.sender` means "human user"
2. **No code-size checks:** We don't use `extcodesize == 0` to identify EOAs
3. **Address-based accounting:** All tracking (rate limits, pending payouts, player stats) uses `msg.sender` addresses, which work identically for delegated EOAs

**Acceptable behavior with EIP-7702:**
- Players with delegated EOAs can automate gameplay (e.g., auto-cashout at target multiplier)
- This is functionally equivalent to using a smart contract wallet (already supported)
- Rate limiting and session tracking work identically
- Bots using delegated EOAs face the same constraints as smart contract bots

**No additional mitigations required.** The existing design is EIP-7702 compatible by default.

---

## 3. Integration Points

### 3.1 DataToken Integration

```solidity
// NO tax exclusion - ArcadeCore subject to standard 10% transfer tax
// This is intentional: maximizes burn, consistent with ecosystem
```

**Token Flow (CONFIRMED):**

```
Player → ArcadeCore (entry)     : TAX APPLIES (10%) → Burns $DATA
ArcadeCore → DEAD_ADDRESS       : TAX APPLIES (10%) → Burns $DATA  
ArcadeCore → Winner (withdraw)  : TAX APPLIES (10%) → Burns $DATA
```

**Effective Economics:**

```
Stated house edge: 3% (rake)
Entry tax: 10% 
Exit tax on winnings: 10%

Example - Player enters with 100 DATA, wins 2x:
─────────────────────────────────────────────────
Step 1: Deposit 100 DATA
  - Tax burned: 10 DATA
  - Enters prize pool: 90 DATA
  - After 3% rake: 87.3 DATA in pool

Step 2: Win 2x multiplier
  - Prize: 174.6 DATA credited to pending

Step 3: Withdraw 174.6 DATA
  - Tax burned: 17.46 DATA
  - Player receives: 157.14 DATA
─────────────────────────────────────────────────
Net result: 157.14 DATA from 100 DATA deposit
Effective return: 57% on a "2x win"
Breakeven multiplier: ~1.23x (before rake)
To actually double money: Need ~2.5x win

Total burned in this flow: 27.46 DATA (27.46% of deposit!)
```

**Design Rationale:** This aggressive burn rate is intentional. The arcade is entertainment-first, and the tokenomics benefit from high burn. Players who want pure gambling economics can use other platforms; GHOSTNET arcade is for $DATA believers who want to play AND burn.

### 3.2 GhostCore Integration

```solidity
interface IArcadeGhostIntegration {
    /// @notice Check if player is eligible for arcade games
    /// @dev Player must have an alive position
    function isArcadeEligible(address player) external view returns (bool);
    
    /// @notice Get player's stake tier for tiered entry games
    function getPlayerTier(address player) external view returns (uint8);
    
    /// @notice Check if boost is active
    function hasArcadeBoost(address player) external view returns (bool);
}
```

**Integration Modes:**

| Game | GhostCore Requirement | Benefit |
|------|----------------------|---------|
| HASH CRASH | Optional | Position holders get reduced rake |
| CODE DUEL | Optional | Position holders can bet higher |
| DAILY OPS | Required | Rewards benefit position |
| ICE BREAKER | Required | Boosts apply to position |
| BINARY BET | Optional | None |
| BOUNTY HUNT | Required | Death rate reduction reward |
| PROXY WAR | Required | Crew integration |
| ZERO DAY | Optional | Leaderboard bonus |
| SHADOW PROTOCOL | Required | Core gameplay |

### 3.3 Treasury Integration

```solidity
// Arcade sends rake to same treasury as GhostCore
address public treasury; // Same address as GhostCore.treasury

// Consider: Separate arcade treasury for analytics?
// Decision: Use same treasury, track via events
```

### 3.4 Game Lifecycle Management

Games follow a strict lifecycle from registration through potential deregistration. Games cannot be instantly removed to protect players mid-game.

#### Registration

```solidity
function registerGame(
    address game,
    EntryConfig calldata config
) external onlyOwner {
    require(game != address(0), "Zero address");
    require(!games[game].isActive, "Already registered");
    
    games[game] = GameInfo({
        gameId: IArcadeGame(game).gameId(),
        name: IArcadeGame(game).getGameInfo().name,
        description: IArcadeGame(game).getGameInfo().description,
        category: IArcadeGame(game).getGameInfo().category,
        minPlayers: IArcadeGame(game).getGameInfo().minPlayers,
        maxPlayers: IArcadeGame(game).getGameInfo().maxPlayers,
        isActive: true,
        launchedAt: uint64(block.timestamp)
    });
    
    entryConfigs[game] = config;
    
    emit GameRegistered(game, games[game].gameId, games[game].name);
}
```

#### Deregistration (Graceful)

The deregistration process protects players with active sessions:

**Step 1: Mark for Removal** (immediate effect)

```solidity
/// @notice Grace period before game can be removed (7 days)
uint256 public constant REMOVAL_GRACE_PERIOD = 7 days;

/// @notice Tracks when a game can be finally removed
mapping(address game => uint256 removalTime) public gameRemovalTime;

/// @notice Mark a game for removal - starts grace period
/// @dev Game immediately stops accepting new sessions
function markGameForRemoval(address game) external onlyOwner {
    require(isGameRegistered(game), "Not registered");
    require(gameRemovalTime[game] == 0, "Already marked for removal");
    
    gameRemovalTime[game] = block.timestamp + REMOVAL_GRACE_PERIOD;
    games[game].isActive = false; // Immediately stop new entries
    
    emit GameMarkedForRemoval(game, gameRemovalTime[game]);
}

/// @notice Cancel removal and restore game to active status
function cancelGameRemoval(address game) external onlyOwner {
    require(gameRemovalTime[game] != 0, "Not marked for removal");
    
    delete gameRemovalTime[game];
    games[game].isActive = true;
    
    emit GameRemovalCancelled(game);
}
```

**Step 2: Grace Period** (7 days)

During the grace period:
- Game **cannot** accept new sessions (`isActive = false`)
- Existing sessions **can** complete normally
- Players **can** withdraw any pending payouts
- Admin **can** cancel removal via `cancelGameRemoval()`

**Step 3: Final Removal** (after grace period)

```solidity
/// @notice Complete game removal after grace period
/// @dev Fails if any sessions are still active
function removeGame(address game) external onlyOwner {
    require(gameRemovalTime[game] != 0, "Not marked for removal");
    require(block.timestamp >= gameRemovalTime[game], "Grace period active");
    require(!hasActiveSessions(game), "Active sessions exist");
    
    delete games[game];
    delete entryConfigs[game];
    delete gameRemovalTime[game];
    
    emit GameRemoved(game);
}

/// @notice Check if game has any active sessions
/// @dev Games must implement session tracking for this check
function hasActiveSessions(address game) public view returns (bool) {
    return IArcadeGame(game).currentSessionId() > 0 && 
           IArcadeGame(game).getSessionState(
               IArcadeGame(game).currentSessionId()
           ) != SessionState.SETTLED &&
           IArcadeGame(game).getSessionState(
               IArcadeGame(game).currentSessionId()
           ) != SessionState.CANCELLED;
}
```

**Step 4: Emergency Removal** (with active sessions)

For critical security situations (discovered exploit, compromised game):

```solidity
/// @notice Force-remove game and refund all players
/// @dev Only for critical security situations - refunds all active sessions
/// @param game The game contract address
/// @param sessionIds Array of active session IDs to refund
function emergencyRemoveGame(
    address game, 
    uint256[] calldata sessionIds
) external onlyOwner {
    require(isGameRegistered(game), "Not registered");
    
    // Force-cancel all specified active sessions
    for (uint256 i; i < sessionIds.length;) {
        // Each game must implement emergencyCancel which calls arcadeCore.emergencyRefund
        try IArcadeGame(game).emergencyCancel(sessionIds[i], "Emergency game removal") {
            // Successfully cancelled and refunded
        } catch {
            // Log but continue - don't let one failure block removal
            emit EmergencyCancelFailed(game, sessionIds[i]);
        }
        unchecked { ++i; }
    }
    
    // Remove game immediately
    delete games[game];
    delete entryConfigs[game];
    delete gameRemovalTime[game];
    
    emit GameEmergencyRemoved(game, sessionIds.length);
}
```

#### Lifecycle State Diagram

```
                ┌────────────────────────────────────────────────────┐
                │                    REGISTERED                       │
                │              (isActive = true)                      │
                │         Accepting new sessions                      │
                └───────────────────┬────────────────────────────────┘
                                    │
                       markGameForRemoval()
                                    │
                                    ▼
                ┌────────────────────────────────────────────────────┐
                │               PENDING REMOVAL                       │
                │             (isActive = false)                      │
                │    No new sessions, existing can complete           │
                │         Grace period: 7 days                        │
                └───────────────────┬──────────────────┬─────────────┘
                                    │                  │
        cancelGameRemoval()         │                  │ emergencyRemoveGame()
        (back to REGISTERED)        │                  │ (immediate, with refunds)
                                    │                  │
                       removeGame() │                  │
                    (after 7 days)  │                  │
                                    ▼                  ▼
                ┌────────────────────────────────────────────────────┐
                │                    REMOVED                          │
                │           Game fully deregistered                   │
                │         All state cleaned up                        │
                └────────────────────────────────────────────────────┘
```

---

## 4. Contract Hierarchy

```
packages/contracts/src/arcade/
├── ArcadeCore.sol              # Central hub (UUPS upgradeable)
├── GameRegistry.sol            # Game whitelist & config (Ownable2Step)
├── interfaces/
│   ├── IArcadeCore.sol         # Core interface
│   ├── IArcadeGame.sol         # Game interface (games implement this)
│   ├── IGameRegistry.sol       # Registry interface
│   └── IArcadeTypes.sol        # Shared types
├── randomness/
│   ├── FutureBlockRandomness.sol    # Base for block hash games
│   └── CommitRevealBase.sol         # Base for player-choice games
├── games/
│   ├── HashCrash.sol           # Phase 3A
│   ├── DailyOps.sol            # Phase 3A
│   ├── BinaryBet.sol           # Phase 3B
│   ├── IceBreaker.sol          # Phase 3B
│   ├── BountyHunt.sol          # Phase 3B
│   └── ...                     # Future games
└── test/
    ├── ArcadeCore.t.sol
    ├── GameRegistry.t.sol
    └── games/
        └── HashCrash.t.sol
```

### Inheritance Diagram

```
                    ┌──────────────────────┐
                    │   OpenZeppelin       │
                    │   Base Contracts     │
                    └──────────┬───────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ UUPSUpgradeable│    │ Ownable2Step   │    │ ReentrancyGuard │
│ AccessControl  │    │                │    │                 │
│ Pausable       │    │                │    │                 │
└───────┬───────┘    └────────┬────────┘    └────────┬────────┘
        │                     │                      │
        ▼                     ▼                      │
┌───────────────┐    ┌─────────────────┐            │
│  ArcadeCore   │    │  GameRegistry   │            │
└───────────────┘    └─────────────────┘            │
                                                    │
                    ┌───────────────────────────────┤
                    │                               │
                    ▼                               ▼
        ┌─────────────────────┐         ┌─────────────────────┐
        │FutureBlockRandomness│         │  CommitRevealBase   │
        │  (abstract)         │         │  (abstract)         │
        └──────────┬──────────┘         └──────────┬──────────┘
                   │                               │
        ┌──────────┼──────────┐                   │
        │          │          │                   │
        ▼          ▼          ▼                   ▼
   HashCrash  BountyHunt  IceBreaker         BinaryBet
```

---

## 5. Detailed Contract Specifications

### 5.1 IArcadeTypes.sol

Shared types used across all arcade contracts.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IArcadeTypes
/// @notice Shared types for GHOSTNET Arcade
interface IArcadeTypes {
    
    // ═══════════════════════════════════════════════════════════════
    // ENUMS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Game categories for UI grouping and configuration
    enum GameCategory {
        CASINO,         // 0 - Games of chance (Hash Crash, Binary Bet)
        COMPETITIVE,    // 1 - PvP games (Code Duel, Proxy War)
        SKILL,          // 2 - Skill-based (Ice Breaker, Zero Day)
        PROGRESSION,    // 3 - Daily/streak games (Daily Ops)
        SOCIAL          // 4 - Social features (Bounty Hunt, Shadow Protocol)
    }
    
    /// @notice Standard game session states
    enum SessionState {
        NONE,           // 0 - Session doesn't exist
        BETTING,        // 1 - Accepting bets/entries
        LOCKED,         // 2 - No more entries, waiting for seed
        ACTIVE,         // 3 - Game in progress
        RESOLVING,      // 4 - Determining outcomes
        SETTLED,        // 5 - Payouts complete
        CANCELLED,      // 6 - Refunded
        EXPIRED         // 7 - Seed block expired, refunding
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Entry fee configuration per game
    struct EntryConfig {
        uint128 minEntry;           // Minimum entry fee in DATA
        uint128 maxEntry;           // Maximum entry fee (0 = no max)
        uint16 rakeBps;             // Protocol rake in basis points (max 1000 = 10%)
        uint16 burnBps;             // Burn rate in basis points (of rake)
        bool requiresPosition;      // Must have GhostCore position
        bool boostEligible;         // Can earn death reduction boosts
    }
    
    /// @notice Player statistics (packed for storage efficiency)
    /// @dev Amount fields are scaled by AMOUNT_SCALE (1e6) for uint128 packing.
    ///      Precision: Tracks amounts down to 1e-12 DATA (1 pico-DATA).
    ///      Max trackable: ~340 billion DATA per field (uint128 / 1e6).
    struct PlayerStats {
        uint64 totalGamesPlayed;    // Total games across all arcade
        uint64 totalWins;           // Total wins
        uint64 totalLosses;         // Total losses
        uint128 totalWagered;       // Total DATA wagered (scaled by 1e6, multiply by 1e6 for wei)
        uint128 totalWon;           // Total DATA won (scaled by 1e6, multiply by 1e6 for wei)
        uint128 totalBurned;        // Contributed to burns (scaled by 1e6, multiply by 1e6 for wei)
        uint32 currentStreak;       // Current win streak
        uint32 maxStreak;           // Best win streak ever
        uint64 lastPlayTime;        // Timestamp of last play (for rate limiting)
    }
    
    /// @notice Game metadata for registry
    struct GameInfo {
        bytes32 gameId;             // Unique identifier (keccak256 of name)
        string name;                // Display name
        string description;         // Short description
        GameCategory category;      // Game category
        uint8 minPlayers;           // Minimum players (1 for solo)
        uint8 maxPlayers;           // Maximum players (0 = unlimited)
        bool isActive;              // Accepting new sessions
        uint64 launchedAt;          // Launch timestamp
    }
    
    /// @notice Randomness seed tracking
    struct SeedInfo {
        uint256 seedBlock;          // Block number for seed
        bytes32 blockHash;          // Captured block hash
        uint256 seed;               // Derived seed value
        bool committed;             // Seed block set
        bool revealed;              // Seed captured
    }
}
```

### 5.2 IArcadeCore.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IArcadeTypes} from "./IArcadeTypes.sol";

/// @title IArcadeCore
/// @notice Central hub interface for GHOSTNET Arcade
interface IArcadeCore is IArcadeTypes {
    
    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error GameNotRegistered();
    error GamePaused();
    error InvalidEntryAmount();
    error PositionRequired();
    error RateLimited();
    error ZeroAddress();
    error NotAuthorized();
    error TransferFailed();
    error NothingToWithdraw();
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    // NOTE: Event indexing strategy for off-chain analytics:
    // - Index addresses (game, player) for filtering by participant
    // - Index sessionId for filtering by specific session
    // - Do NOT index amounts (filtering by exact amount is rare)
    // - Do NOT index booleans (only 2 values, not worth bloom filter space)
    // - Max 3 indexed params per event (EVM limitation)
    
    event EntryProcessed(
        address indexed game,           // Filter: "all entries to HashCrash"
        address indexed player,         // Filter: "all entries by 0x123..."
        uint256 indexed sessionId,      // Filter: "all entries in session 42"
        uint256 grossAmount,            // Not indexed (query by range is rare)
        uint256 netAmount,
        uint256 rakeAmount
    );
    
    event GameSettled(
        address indexed game,           // Filter: "all settlements from HashCrash"
        address indexed player,         // Filter: "all settlements for 0x123..."
        uint256 indexed sessionId,      // Filter: "all settlements in session 42"
        uint256 payout,                 // Not indexed
        uint256 burned,
        bool won                        // Not indexed (boolean - just 2 values)
    );
    
    event PayoutCredited(
        address indexed player,         // Filter: "all credits to 0x123..."
        address indexed game,           // Filter: "all credits from HashCrash"
        uint256 amount,                 // Not indexed
        uint256 newPending
    );
    
    event PayoutWithdrawn(
        address indexed player,
        uint256 amount
    );
    
    event EmergencyRefund(
        address indexed game,           // Filter: "all refunds from HashCrash"
        address indexed player,         // Filter: "all refunds to 0x123..."
        uint256 indexed sessionId,      // Filter: "refunds in session 42"
        uint256 amount
    );
    
    // Game lifecycle events (see Section 3.4)
    event GameRegistered(
        address indexed game,           // Filter: "registration events for game"
        bytes32 indexed gameId,         // Filter: "by canonical game ID"
        string name                     // Not indexed (string)
    );
    
    event GameMarkedForRemoval(
        address indexed game,
        uint256 removalTime             // Not indexed (timestamp)
    );
    
    event GameRemovalCancelled(
        address indexed game
    );
    
    event GameRemoved(
        address indexed game
    );
    
    event GameEmergencyRemoved(
        address indexed game,
        uint256 sessionsRefunded        // Not indexed
    );
    
    event EmergencyCancelFailed(
        address indexed game,
        uint256 indexed sessionId       // Which session failed to cancel
    );
    
    // Circuit breaker events
    event CircuitBreakerTripped(
        string indexed reason,          // Index for filtering by reason type
        uint256 value                   // Threshold that was exceeded
    );
    
    // ═══════════════════════════════════════════════════════════════
    // GAME INTERACTION (Called by registered games)
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Process entry fee for a game session
    /// @param player Address of the player
    /// @param amount Entry fee amount
    /// @return sessionId Unique session identifier
    /// @return netAmount Amount after rake (for prize pool)
    function processEntry(
        address player,
        uint256 amount
    ) external returns (uint256 sessionId, uint256 netAmount);
    
    /// @notice Credit payout to player (pull-payment)
    /// @param player Address of the player
    /// @param amount Payout amount
    /// @param burnAmount Amount to burn
    /// @param won Whether player won
    function creditPayout(
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) external;
    
    /// @notice Batch credit payouts (gas efficient)
    /// @param players Array of player addresses
    /// @param amounts Array of payout amounts
    /// @param burnAmounts Array of burn amounts
    /// @param results Array of win/loss flags
    function batchCreditPayouts(
        address[] calldata players,
        uint256[] calldata amounts,
        uint256[] calldata burnAmounts,
        bool[] calldata results
    ) external;
    
    /// @notice Emergency refund for cancelled sessions
    /// @param player Address to refund
    /// @param amount Amount to refund
    function emergencyRefund(
        address player,
        uint256 amount
    ) external;
    
    // ═══════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Withdraw pending payouts (pull-payment)
    /// @return amount Amount withdrawn
    function withdrawPayouts() external returns (uint256 amount);
    
    /// @notice Get pending payout balance
    /// @param player Address to check
    /// @return amount Pending payout amount
    function getPendingPayout(address player) external view returns (uint256 amount);
    
    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Get player statistics
    function getPlayerStats(address player) external view returns (PlayerStats memory);
    
    /// @notice Get global arcade statistics
    function getGlobalStats() external view returns (
        uint256 totalGamesPlayed,
        uint256 totalVolume,
        uint256 totalBurned,
        uint256 totalRakeCollected
    );
    
    /// @notice Check if player can play (rate limit)
    function canPlay(address player) external view returns (bool);
    
    /// @notice Get DATA token address
    function dataToken() external view returns (address);
    
    /// @notice Get GhostCore address
    function ghostCore() external view returns (address);
    
    /// @notice Get GameRegistry address
    function gameRegistry() external view returns (address);
}
```

### 5.3 IArcadeGame.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IArcadeTypes} from "./IArcadeTypes.sol";

/// @title IArcadeGame
/// @notice Interface that all GHOSTNET Arcade games must implement
interface IArcadeGame is IArcadeTypes {
    
    // ═══════════════════════════════════════════════════════════════
    // METADATA
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Get game metadata
    function getGameInfo() external view returns (GameInfo memory);
    
    /// @notice Get game's unique identifier
    function gameId() external view returns (bytes32);
    
    // ═══════════════════════════════════════════════════════════════
    // SESSION QUERIES
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Get current session ID (for continuous games like HashCrash)
    function currentSessionId() external view returns (uint256);
    
    /// @notice Get session state
    function getSessionState(uint256 sessionId) external view returns (SessionState);
    
    /// @notice Check if player is in session
    function isPlayerInSession(uint256 sessionId, address player) external view returns (bool);
    
    /// @notice Get session prize pool
    function getSessionPrizePool(uint256 sessionId) external view returns (uint256);
    
    // ═══════════════════════════════════════════════════════════════
    // ADMIN
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Pause game (only PAUSER_ROLE)
    function pause() external;
    
    /// @notice Unpause game (only PAUSER_ROLE)
    function unpause() external;
    
    /// @notice Check if game is paused
    function isPaused() external view returns (bool);
    
    // ═══════════════════════════════════════════════════════════════
    // EMERGENCY
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Cancel active session and refund players
    /// @param sessionId Session to cancel
    /// @param reason Cancellation reason
    function emergencyCancel(uint256 sessionId, string calldata reason) external;
}
```

### 5.4 ArcadeCore.sol (Skeleton)

> **Security Note:** This skeleton includes session tracking to address Critical Issues #1 and #3
> from the security review. See `src/arcade/ArcadeCoreSessionTracking.md` for full specification.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from 
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IArcadeCore} from "./interfaces/IArcadeCore.sol";
import {IGameRegistry} from "./interfaces/IGameRegistry.sol";
import {IGhostCore} from "../core/interfaces/IGhostCore.sol";

/// @title ArcadeCore
/// @notice Central hub for GHOSTNET Arcade - handles token custody, payouts, and stats
/// @dev UUPS upgradeable with timelock protection on upgrades.
/// Games interact via processEntry() and creditPayout().
///
/// Security Model:
/// - Uses AccessControlDefaultAdminRulesUpgradeable for admin transfer delays (3 days)
/// - 2-day timelock on all upgrades via propose/execute pattern
/// - Admin role should be transferred to TimelockController after deployment
/// - No emergency bypass for upgrades (pause is sufficient for emergencies)
/// - SESSION TRACKING (Critical Issues #1, #3):
///   * All payouts bounded by session prize pool
///   * All refunds bounded by player deposits  
///   * Sessions owned by creating game (cross-game isolation)
///   * Terminal states (SETTLED/CANCELLED) prevent double-settlement
///
/// Token Flow:
/// 1. Player approves ArcadeCore for DATA
/// 2. Game calls processEntry(sessionId) → ArcadeCore pulls tokens, tracks deposit
/// 3. Game determines outcome
/// 4. Game calls creditPayout(sessionId) → ArcadeCore validates and credits
/// 5. Player calls withdrawPayouts() → ArcadeCore sends tokens
///
/// @custom:security-contact security@ghostnet.game
contract ArcadeCore is
    IArcadeCore,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardTransientUpgradeable
{
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint16 private constant BPS = 10_000;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    /// @notice Minimum time between plays per player (anti-spam)
    uint256 public constant MIN_PLAY_INTERVAL = 1 seconds;
    
    /// @notice Scale factor for packing large amounts into uint128
    /// @dev Using 1e6 (not 1e12) to track small wagers accurately.
    ///      - Minimum trackable: 1e6 wei = 1e-12 DATA (1 pico-DATA)
    ///      - Maximum trackable: uint128.max / 1e6 ≈ 340 billion DATA
    ///      - Precision loss: Amounts < 1e6 wei truncate to 0 (negligible)
    ///
    /// Design decision: Reduced from 1e12 to 1e6 to accurately track
    /// arcade micro-transactions. With 1e12, bets under 0.000001 DATA
    /// were lost entirely, skewing analytics and leaderboards.
    uint256 private constant AMOUNT_SCALE = 1e6;
    
    /// @notice Timelock delay for upgrades (2 days minimum)
    uint48 public constant UPGRADE_TIMELOCK = 2 days;
    
    /// @notice Initial delay for admin transfers via AccessControlDefaultAdminRules (3 days)
    uint48 public constant INITIAL_ADMIN_DELAY = 3 days;
    
    // ═══════════════════════════════════════════════════════════════
    // UPGRADE TIMELOCK STORAGE
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Pending upgrade proposal
    struct PendingUpgrade {
        address implementation;     // New implementation address
        uint48 readyAt;            // Timestamp when upgrade can execute
        bool executed;             // Whether upgrade was executed
    }
    
    /// @notice Mapping of upgrade ID to pending upgrade
    /// @dev ID = keccak256(abi.encode(implementation))
    mapping(bytes32 => PendingUpgrade) public pendingUpgrades;
    
    // ═══════════════════════════════════════════════════════════════
    // UPGRADE EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event UpgradeProposed(
        address indexed implementation, 
        uint256 readyAt,
        bytes32 indexed upgradeId
    );
    event UpgradeCancelled(
        address indexed implementation,
        bytes32 indexed upgradeId
    );
    event UpgradeExecuted(
        address indexed implementation,
        bytes32 indexed upgradeId
    );
    
    // ═══════════════════════════════════════════════════════════════
    // UPGRADE ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error UpgradeAlreadyProposed(bytes32 upgradeId);
    error UpgradeNotProposed(bytes32 upgradeId);
    error UpgradeTimelockActive(uint256 readyAt);
    error UpgradeAlreadyExecuted(bytes32 upgradeId);
    
    // ═══════════════════════════════════════════════════════════════
    // CIRCUIT BREAKER CONSTANTS (Issue #6, Recommendation #15)
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Maximum single payout (prevents catastrophic bugs/exploits)
    /// @dev 500k DATA - largest expected payout ~100k, 5x safety margin
    uint256 public constant MAX_SINGLE_PAYOUT = 500_000 ether;
    
    /// @notice Maximum total payouts per hour
    /// @dev 5M DATA - allows high activity while detecting anomalies
    uint256 public constant MAX_HOURLY_PAYOUTS = 5_000_000 ether;
    
    /// @notice Maximum total payouts per day
    /// @dev 20M DATA - prevents rapid balance drain
    uint256 public constant MAX_DAILY_PAYOUTS = 20_000_000 ether;
    
    // ═══════════════════════════════════════════════════════════════
    // FLASH LOAN & CIRCUIT BREAKER ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Player exceeded per-block wager limit (flash loan protection)
    error FlashLoanProtection(uint256 requested, uint256 maxAllowed);
    
    /// @notice Global per-block wager limit exceeded
    error GlobalWagerLimitExceeded();
    
    /// @notice Circuit breaker is active - all payouts halted
    error CircuitBreakerActive();
    
    /// @notice Single payout exceeds maximum allowed
    error PayoutTooLarge(uint256 amount, uint256 max);
    
    /// @notice Hourly payout limit exceeded
    error HourlyPayoutLimitExceeded(uint256 total, uint256 max);
    
    /// @notice Daily payout limit exceeded
    error DailyPayoutLimitExceeded(uint256 total, uint256 max);
    
    // ═══════════════════════════════════════════════════════════════
    // FLASH LOAN & CIRCUIT BREAKER EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event CircuitBreakerTripped(string reason, uint256 value);
    event CircuitBreakerReset(address indexed admin);
    event FlashLoanBlocked(address indexed player, uint256 attemptedAmount, uint256 limit);
    event WagerLimitsUpdated(uint256 maxWagerPerBlock, uint256 maxTotalWagerPerBlock);
    
    // ═══════════════════════════════════════════════════════════════
    // STRUCTS (Flash Loan Protection)
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Per-player block activity for flash loan protection
    /// @dev Packed into single slot: 8 + 16 + 8 = 32 bytes
    struct PlayerBlockActivity {
        uint64 lastPlayBlock;           // Last block player wagered
        uint128 currentBlockWagered;    // Total wagered in current block
        uint64 lastPlayTime;            // Timestamp for time-based rate limit
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STORAGE (ERC-7201 Namespaced)
    // ═══════════════════════════════════════════════════════════════
    
    /// @custom:storage-location erc7201:ghostnet.arcade.core
    struct ArcadeCoreStorage {
        // External contracts
        IERC20 dataToken;
        IGhostCore ghostCore;
        IGameRegistry gameRegistry;
        address treasury;
        
        // Player data
        mapping(address => PlayerStats) playerStats;
        mapping(address => uint256) pendingPayouts;
        
        // Flash loan protection: per-player block activity
        mapping(address => PlayerBlockActivity) playerActivity;
        
        // Flash loan protection: global per-block tracking
        uint256 currentBlockWagers;     // Total wagers in current block
        uint256 lastWagerBlock;         // Block number of last wager
        
        // Flash loan protection: configurable limits (adjustable via timelock)
        uint256 maxWagerPerBlock;       // Per player, per block (default 100k DATA)
        uint256 maxTotalWagerPerBlock;  // Global per block (default 1M DATA)
        
        // Circuit breaker state
        uint256 hourlyPayouts;          // Running total for current hour
        uint256 dailyPayouts;           // Running total for current day
        uint256 lastHourTimestamp;      // Hour boundary timestamp
        uint256 lastDayTimestamp;       // Day boundary timestamp
        bool circuitBreakerTripped;     // Emergency stop flag
        
        // Global counters
        uint256 totalGamesPlayed;
        uint256 totalVolume;
        uint256 totalBurned;
        uint256 totalRakeCollected;
        uint256 totalPendingPayouts;
        
        // Session counter (global, not per-game)
        uint256 nextSessionId;
    }
    
    // ERC-7201 storage location computed as:
    // keccak256(abi.encode(uint256(keccak256("ghostnet.arcade.core")) - 1)) & ~bytes32(uint256(0xff))
    //
    // Step-by-step computation:
    // 1. keccak256("ghostnet.arcade.core") = 0xf4bb7e489db23ba92ae66b35a7fdd4c4ac4ae776305ccdc785c26c14d5bf1bc9
    // 2. Subtract 1 = 0xf4bb7e489db23ba92ae66b35a7fdd4c4ac4ae776305ccdc785c26c14d5bf1bc8
    // 3. keccak256(abi.encode(step2)) = 0x23be64d05fac248fb764bd09c34964ec29dda503b401477753a17a4370094b1f
    // 4. Mask with ~0xff = 0x23be64d05fac248fb764bd09c34964ec29dda503b401477753a17a4370094b00
    bytes32 private constant STORAGE_LOCATION = 
        0x23be64d05fac248fb764bd09c34964ec29dda503b401477753a17a4370094b00;
    
    function _getStorage() private pure returns (ArcadeCoreStorage storage $) {
        assembly { $.slot := STORAGE_LOCATION }
    }

    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ═══════════════════════════════════════════════════════════════
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice Initialize the ArcadeCore contract
    /// @param _dataToken DATA token address
    /// @param _ghostCore GhostCore contract address
    /// @param _gameRegistry GameRegistry contract address
    /// @param _treasury Treasury address for rake collection
    /// @param _admin Initial admin (should be deployer, then transferred to timelock)
    /// @dev Admin delay is set to INITIAL_ADMIN_DELAY (3 days) for secure admin transfers
    function initialize(
        address _dataToken,
        address _ghostCore,
        address _gameRegistry,
        address _treasury,
        address _admin
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(INITIAL_ADMIN_DELAY, _admin);
        __Pausable_init();
        __ReentrancyGuardTransient_init();
        
        // Validate addresses
        if (_dataToken == address(0)) revert ZeroAddress();
        if (_ghostCore == address(0)) revert ZeroAddress();
        if (_gameRegistry == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        
        ArcadeCoreStorage storage $ = _getStorage();
        $.dataToken = IERC20(_dataToken);
        $.ghostCore = IGhostCore(_ghostCore);
        $.gameRegistry = IGameRegistry(_gameRegistry);
        $.treasury = _treasury;
        $.nextSessionId = 1;
        
        // Flash loan protection defaults (Issue #6)
        $.maxWagerPerBlock = 100_000 ether;      // 100k DATA per player per block
        $.maxTotalWagerPerBlock = 1_000_000 ether; // 1M DATA global per block
        
        // Circuit breaker initialization (Recommendation #15)
        $.lastHourTimestamp = block.timestamp;
        $.lastDayTimestamp = block.timestamp;
        
        // Grant PAUSER_ROLE to admin (can be adjusted post-deployment)
        _grantRole(PAUSER_ROLE, _admin);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // UPGRADE TIMELOCK FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Propose an upgrade to a new implementation
    /// @param newImplementation Address of the new implementation contract
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Starts the 2-day timelock.
    function proposeUpgrade(address newImplementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
        
        bytes32 upgradeId = keccak256(abi.encode(newImplementation));
        PendingUpgrade storage pending = pendingUpgrades[upgradeId];
        
        // Cannot re-propose an active or executed upgrade
        if (pending.readyAt != 0) revert UpgradeAlreadyProposed(upgradeId);
        
        uint48 readyAt = uint48(block.timestamp) + UPGRADE_TIMELOCK;
        
        pendingUpgrades[upgradeId] = PendingUpgrade({
            implementation: newImplementation,
            readyAt: readyAt,
            executed: false
        });
        
        emit UpgradeProposed(newImplementation, readyAt, upgradeId);
    }
    
    /// @notice Cancel a pending upgrade proposal
    /// @param implementation Address of the proposed implementation to cancel
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. Can cancel at any time before execution.
    function cancelUpgrade(address implementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 upgradeId = keccak256(abi.encode(implementation));
        PendingUpgrade storage pending = pendingUpgrades[upgradeId];
        
        if (pending.readyAt == 0) revert UpgradeNotProposed(upgradeId);
        if (pending.executed) revert UpgradeAlreadyExecuted(upgradeId);
        
        delete pendingUpgrades[upgradeId];
        
        emit UpgradeCancelled(implementation, upgradeId);
    }
    
    /// @notice Get upgrade proposal details
    /// @param implementation Address of the proposed implementation
    /// @return readyAt Timestamp when upgrade can execute (0 if not proposed)
    /// @return executed Whether the upgrade was already executed
    /// @return timeRemaining Seconds until upgrade is ready (0 if ready or not proposed)
    function getUpgradeStatus(address implementation) external view returns (
        uint256 readyAt,
        bool executed,
        uint256 timeRemaining
    ) {
        bytes32 upgradeId = keccak256(abi.encode(implementation));
        PendingUpgrade storage pending = pendingUpgrades[upgradeId];
        
        readyAt = pending.readyAt;
        executed = pending.executed;
        
        if (readyAt > 0 && block.timestamp < readyAt) {
            timeRemaining = readyAt - block.timestamp;
        }
    }
    
    /// @notice UUPS upgrade authorization with timelock enforcement
    /// @param newImplementation Address of the new implementation
    /// @dev Called internally by upgradeTo/upgradeToAndCall. Enforces timelock.
    function _authorizeUpgrade(address newImplementation) internal override {
        // Must have admin role
        _checkRole(DEFAULT_ADMIN_ROLE);
        
        bytes32 upgradeId = keccak256(abi.encode(newImplementation));
        PendingUpgrade storage pending = pendingUpgrades[upgradeId];
        
        // Verify proposal exists
        if (pending.readyAt == 0) revert UpgradeNotProposed(upgradeId);
        
        // Verify timelock has passed
        if (block.timestamp < pending.readyAt) {
            revert UpgradeTimelockActive(pending.readyAt);
        }
        
        // Verify not already executed
        if (pending.executed) revert UpgradeAlreadyExecuted(upgradeId);
        
        // Mark as executed
        pending.executed = true;
        
        emit UpgradeExecuted(newImplementation, upgradeId);
    }

    // ═══════════════════════════════════════════════════════════════
    // GAME INTERACTION
    // ═══════════════════════════════════════════════════════════════
    
    /// @inheritdoc IArcadeCore
    function processEntry(
        address player,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 sessionId, uint256 netAmount) {
        ArcadeCoreStorage storage $ = _getStorage();
        
        // 1. Verify caller is registered game
        if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
        if ($.gameRegistry.isGamePaused(msg.sender)) revert GamePaused();
        
        // 2. Get entry config and validate
        EntryConfig memory config = $.gameRegistry.getEntryConfig(msg.sender);
        if (amount < config.minEntry) revert InvalidEntryAmount();
        if (config.maxEntry > 0 && amount > config.maxEntry) revert InvalidEntryAmount();
        
        // 3. Check position requirement
        if (config.requiresPosition && !$.ghostCore.isAlive(player)) {
            revert PositionRequired();
        }
        
        // 4. Rate limiting (time-based)
        PlayerStats storage stats = $.playerStats[player];
        if (block.timestamp < stats.lastPlayTime + MIN_PLAY_INTERVAL) {
            revert RateLimited();
        }
        
        // 5. Flash loan protection (block-based limits) - Issue #6
        _enforceFlashLoanProtection($, player, amount);
        
        // 6. Transfer tokens from player
        $.dataToken.safeTransferFrom(player, address(this), amount);
        
        // 7. Calculate and transfer rake
        uint256 rakeAmount = (amount * config.rakeBps) / BPS;
        netAmount = amount - rakeAmount;
        
        if (rakeAmount > 0) {
            // Split rake: burn portion + treasury portion
            uint256 burnAmount = (rakeAmount * config.burnBps) / BPS;
            uint256 treasuryAmount = rakeAmount - burnAmount;
            
            if (burnAmount > 0) {
                $.dataToken.safeTransfer(DEAD_ADDRESS, burnAmount);
                $.totalBurned += burnAmount;
            }
            if (treasuryAmount > 0) {
                $.dataToken.safeTransfer($.treasury, treasuryAmount);
            }
            $.totalRakeCollected += rakeAmount;
        }
        
        // 8. Generate session ID and update stats
        sessionId = ++$.nextSessionId;
        stats.totalGamesPlayed++;
        // Scale down for uint128 storage (1e6 scale = pico-DATA precision)
        stats.totalWagered += uint128(amount / AMOUNT_SCALE);
        stats.lastPlayTime = uint64(block.timestamp);
        $.totalGamesPlayed++;
        $.totalVolume += amount;
        
        emit EntryProcessed(msg.sender, player, sessionId, amount, netAmount, rakeAmount);
    }
    
    /// @inheritdoc IArcadeCore
    function creditPayout(
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) external nonReentrant {
        ArcadeCoreStorage storage $ = _getStorage();
        
        // 1. Verify caller is registered game
        if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
        
        // 2. Circuit breaker check (Recommendation #15)
        // NOTE: Only checks payouts, NOT burns - burns are always allowed
        if (amount > 0) {
            _enforceCircuitBreaker($, amount);
        }
        
        // 3. Execute burn
        if (burnAmount > 0) {
            $.dataToken.safeTransfer(DEAD_ADDRESS, burnAmount);
            $.totalBurned += burnAmount;
        }
        
        // 4. Credit payout (pull pattern)
        if (amount > 0) {
            $.pendingPayouts[player] += amount;
            $.totalPendingPayouts += amount;
            emit PayoutCredited(player, msg.sender, amount, $.pendingPayouts[player]);
        }
        
        // 5. Update stats (amounts scaled down by 1e6 for uint128 packing)
        PlayerStats storage stats = $.playerStats[player];
        if (won) {
            stats.totalWins++;
            stats.totalWon += uint128(amount / AMOUNT_SCALE);
            stats.currentStreak++;
            if (stats.currentStreak > stats.maxStreak) {
                stats.maxStreak = stats.currentStreak;
            }
        } else {
            stats.totalLosses++;
            stats.currentStreak = 0;
        }
        stats.totalBurned += uint128(burnAmount / AMOUNT_SCALE);
        
        emit GameSettled(msg.sender, player, 0, amount, burnAmount, won);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @inheritdoc IArcadeCore
    /// @notice Withdraw pending payouts
    /// @dev IMPORTANT: Works even when contract is paused!
    ///      Players must always be able to access their earned funds.
    ///      This is a core security property - funds are never locked.
    ///
    /// Design rationale:
    /// - Pause is for STOPPING NEW ACTIVITY, not trapping funds
    /// - Emergency scenarios may require pausing while users withdraw
    /// - DoS via pause would be possible if withdrawals were blocked
    /// - Same pattern used by OpenZeppelin's PullPayment
    function withdrawPayouts() external nonReentrant returns (uint256 amount) {
        // NOTE: No whenNotPaused modifier - withdrawals ALWAYS work
        ArcadeCoreStorage storage $ = _getStorage();
        
        amount = $.pendingPayouts[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        
        $.pendingPayouts[msg.sender] = 0;
        $.totalPendingPayouts -= amount;
        
        $.dataToken.safeTransfer(msg.sender, amount);
        
        emit PayoutWithdrawn(msg.sender, amount);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // FLASH LOAN PROTECTION (Issue #6)
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Enforce per-player and global block-based wager limits
    /// @dev Called during processEntry() to prevent same-block flash loan attacks
    /// @param $ Storage pointer (passed to avoid redundant SLOAD)
    /// @param player Player address
    /// @param amount Wager amount
    function _enforceFlashLoanProtection(
        ArcadeCoreStorage storage $,
        address player,
        uint256 amount
    ) internal {
        PlayerBlockActivity storage activity = $.playerActivity[player];
        
        // Per-player block limit
        if (block.number == activity.lastPlayBlock) {
            // Same block - check cumulative limit
            uint256 newTotal = uint256(activity.currentBlockWagered) + amount;
            if (newTotal > $.maxWagerPerBlock) {
                emit FlashLoanBlocked(player, amount, $.maxWagerPerBlock);
                revert FlashLoanProtection(amount, $.maxWagerPerBlock - activity.currentBlockWagered);
            }
            activity.currentBlockWagered = uint128(newTotal);
        } else {
            // New block - reset counter
            if (amount > $.maxWagerPerBlock) {
                emit FlashLoanBlocked(player, amount, $.maxWagerPerBlock);
                revert FlashLoanProtection(amount, $.maxWagerPerBlock);
            }
            activity.lastPlayBlock = uint64(block.number);
            activity.currentBlockWagered = uint128(amount);
        }
        
        // Global block limit
        if (block.number != $.lastWagerBlock) {
            $.currentBlockWagers = 0;
            $.lastWagerBlock = block.number;
        }
        $.currentBlockWagers += amount;
        if ($.currentBlockWagers > $.maxTotalWagerPerBlock) {
            revert GlobalWagerLimitExceeded();
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CIRCUIT BREAKER (Recommendation #15)
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Enforce payout limits and trip circuit breaker if exceeded
    /// @dev Called during creditPayout() to detect abnormal payout patterns
    /// @param $ Storage pointer (passed to avoid redundant SLOAD)
    /// @param amount Payout amount
    function _enforceCircuitBreaker(
        ArcadeCoreStorage storage $,
        uint256 amount
    ) internal {
        // Check if circuit breaker is already tripped
        if ($.circuitBreakerTripped) revert CircuitBreakerActive();
        
        // Single payout limit
        if (amount > MAX_SINGLE_PAYOUT) {
            _tripCircuitBreaker($, "Single payout exceeded", amount);
            revert PayoutTooLarge(amount, MAX_SINGLE_PAYOUT);
        }
        
        // Hourly limit (reset on new hour)
        uint256 currentHour = block.timestamp / 1 hours;
        if (currentHour != $.lastHourTimestamp / 1 hours) {
            $.hourlyPayouts = 0;
            $.lastHourTimestamp = block.timestamp;
        }
        $.hourlyPayouts += amount;
        if ($.hourlyPayouts > MAX_HOURLY_PAYOUTS) {
            _tripCircuitBreaker($, "Hourly payout exceeded", $.hourlyPayouts);
            revert HourlyPayoutLimitExceeded($.hourlyPayouts, MAX_HOURLY_PAYOUTS);
        }
        
        // Daily limit (reset on new day)
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay != $.lastDayTimestamp / 1 days) {
            $.dailyPayouts = 0;
            $.lastDayTimestamp = block.timestamp;
        }
        $.dailyPayouts += amount;
        if ($.dailyPayouts > MAX_DAILY_PAYOUTS) {
            _tripCircuitBreaker($, "Daily payout exceeded", $.dailyPayouts);
            revert DailyPayoutLimitExceeded($.dailyPayouts, MAX_DAILY_PAYOUTS);
        }
    }
    
    /// @notice Trip the circuit breaker
    /// @param $ Storage pointer
    /// @param reason Human-readable reason
    /// @param value The value that triggered the breaker
    function _tripCircuitBreaker(
        ArcadeCoreStorage storage $,
        string memory reason,
        uint256 value
    ) internal {
        $.circuitBreakerTripped = true;
        emit CircuitBreakerTripped(reason, value);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Update per-player per-block wager limit
    /// @param newLimit New limit in wei (e.g., 100_000 ether for 100k DATA)
    function setMaxWagerPerBlock(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ArcadeCoreStorage storage $ = _getStorage();
        $.maxWagerPerBlock = newLimit;
        emit WagerLimitsUpdated(newLimit, $.maxTotalWagerPerBlock);
    }
    
    /// @notice Update global per-block wager limit
    /// @param newLimit New limit in wei
    function setMaxTotalWagerPerBlock(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ArcadeCoreStorage storage $ = _getStorage();
        $.maxTotalWagerPerBlock = newLimit;
        emit WagerLimitsUpdated($.maxWagerPerBlock, newLimit);
    }
    
    /// @notice Get current flash loan protection limits
    /// @return maxPerPlayer Per-player per-block limit
    /// @return maxGlobal Global per-block limit
    function getFlashLoanLimits() external view returns (uint256 maxPerPlayer, uint256 maxGlobal) {
        ArcadeCoreStorage storage $ = _getStorage();
        return ($.maxWagerPerBlock, $.maxTotalWagerPerBlock);
    }
    
    /// @notice Check if circuit breaker is currently tripped
    /// @return tripped True if circuit breaker is active
    function isCircuitBreakerTripped() external view returns (bool tripped) {
        return _getStorage().circuitBreakerTripped;
    }
    
    /// @notice Get current payout limits and usage
    /// @return hourlyUsed Current hour's payout total
    /// @return dailyUsed Current day's payout total
    /// @return hourlyMax Maximum hourly payouts
    /// @return dailyMax Maximum daily payouts
    /// @return singleMax Maximum single payout
    function getPayoutLimits() external view returns (
        uint256 hourlyUsed,
        uint256 dailyUsed,
        uint256 hourlyMax,
        uint256 dailyMax,
        uint256 singleMax
    ) {
        ArcadeCoreStorage storage $ = _getStorage();
        return (
            $.hourlyPayouts,
            $.dailyPayouts,
            MAX_HOURLY_PAYOUTS,
            MAX_DAILY_PAYOUTS,
            MAX_SINGLE_PAYOUT
        );
    }
    
    /// @notice Reset circuit breaker after investigation
    /// @dev Only callable by admin. Should only be called after root cause analysis.
    ///      Consider using a timelock for this in production.
    function resetCircuitBreaker() external onlyRole(DEFAULT_ADMIN_ROLE) {
        ArcadeCoreStorage storage $ = _getStorage();
        $.circuitBreakerTripped = false;
        $.hourlyPayouts = 0;
        $.dailyPayouts = 0;
        $.lastHourTimestamp = block.timestamp;
        $.lastDayTimestamp = block.timestamp;
        emit CircuitBreakerReset(msg.sender);
    }
    
    // ... additional implementation (view functions, session tracking, etc.)
}
```

---

## 6. Randomness Architecture

### 6.1 The MegaETH Challenge

```
PROBLEM: prevrandao is constant for ~60 seconds on MegaETH

Block 100: prevrandao = 0xabc...
Block 101: prevrandao = 0xabc... (same!)
Block 160: prevrandao = 0xdef... (finally changed)

If we use prevrandao directly:
1. Player observes current prevrandao
2. Player calculates their outcome
3. Player only bets if favorable
→ Exploitable!
```

#### MegaETH Timing Analysis

MegaETH operates with ~100ms block times, which fundamentally changes timing assumptions:

| Mainnet Ethereum | MegaETH | Factor |
|------------------|---------|--------|
| 12s blocks | 100ms blocks | 120x faster |
| 256 blocks = 51 min | 256 blocks = 25.6s | Much tighter |
| prevrandao updates per block | prevrandao constant ~60s | Unusable directly |

**Critical Timing Constraints:**

| Constraint | Blocks | Time (MegaETH) | Notes |
|------------|--------|----------------|-------|
| EVM blockhash limit | 256 | 25.6 seconds | Hard limit, cannot exceed |
| prevrandao update cycle | ~600 | ~60 seconds | Too slow, don't use |
| Typical tx confirmation | 1-3 | 100-300ms | Fast under normal load |
| Network congestion delay | 50-100+ | 5-10+ seconds | **This is the risk** |

**Reveal Window Math:**

```
Effective Reveal Window = MAX_BLOCK_AGE - SEED_BLOCK_DELAY

With SEED_BLOCK_DELAY = 5:
  Window = 256 - 5 = 251 blocks = 25.1 seconds

With SEED_BLOCK_DELAY = 50:
  Window = 256 - 50 = 206 blocks = 20.6 seconds

With SEED_BLOCK_DELAY = 100:
  Window = 256 - 100 = 156 blocks = 15.6 seconds
```

**Risk Assessment:**

| Scenario | Delay | SEED_DELAY=5 | SEED_DELAY=50 | SEED_DELAY=100 |
|----------|-------|--------------|---------------|----------------|
| Normal operation | 1-2s | ✅ Safe | ✅ Safe | ✅ Safe |
| Light congestion | 5s | ✅ Safe | ✅ Safe | ✅ Safe |
| Moderate congestion | 10s | ✅ Safe | ✅ Safe | ✅ Safe |
| Heavy congestion | 15s | ✅ Safe | ✅ Safe | ⚠️ Tight |
| Severe congestion | 20s | ⚠️ Tight | ⚠️ Tight | ❌ Fails |
| Network incident | 25s+ | ❌ Fails | ❌ Fails | ❌ Fails |

**Recommendation:** Use `SEED_BLOCK_DELAY = 50` (5 seconds) as the baseline, with EIP-2935 fallback for extended reliability.

### 6.2 Future Block Hash Solution

```
SOLUTION: Commit to a FUTURE block's hash

Timeline:
─────────────────────────────────────────────────────────────────────
   BETTING PHASE          LOCK                    GAME
   [Players bet]          [Seed block set]        [Use blockhash]
   Block N                Block N+1               Block N+50+
─────────────────────────────────────────────────────────────────────
                          seedBlock = N+50
                          
At Block N+50:
- blockhash(N+50) is now available
- This hash was unknowable during betting
- Use it as seed for all outcomes
```

### 6.3 FutureBlockRandomness.sol
#### Constant Selection Rationale

| Constant | Value | Time (MegaETH) | Justification |
|----------|-------|----------------|---------------|
| `SEED_BLOCK_DELAY` | 50 | 5 seconds | Prevents block proposer prediction; short enough for good UX |
| `MAX_BLOCK_AGE` | 256 | 25.6 seconds | EVM hard limit, cannot be changed |
| `EXTENDED_HISTORY_WINDOW` | 8191 | ~13.6 minutes | EIP-2935 limit (if available) |

**Why 50 blocks (5 seconds) for SEED_BLOCK_DELAY:**

1. **Security**: 5 seconds is long enough that predicting/influencing 50 consecutive block hashes is computationally infeasible
2. **UX**: 5 second wait is acceptable for game flow (feels like "processing")
3. **Window**: Leaves 206 blocks (20.6 seconds) for reveal, sufficient for most congestion scenarios

**REMOVED: REVEAL_WINDOW constant**

The previous `REVEAL_WINDOW = 200` was redundant and misleading. The actual reveal window is always:
```
Effective Window = MAX_BLOCK_AGE - SEED_BLOCK_DELAY
```
We now calculate this dynamically rather than having a separate constant that can drift out of sync.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BlockhashHistory} from "./BlockhashHistory.sol";

/// @title FutureBlockRandomness
/// @notice Base contract for games using future block hash as randomness
/// @dev Inherit this and call _commitSeedBlock() when betting closes.
///      Supports EIP-2935 extended history for improved reliability.
///
/// MegaETH Timing (100ms blocks):
/// - SEED_BLOCK_DELAY = 50 blocks = 5 seconds (unpredictable)
/// - MAX_BLOCK_AGE = 256 blocks = 25.6 seconds (EVM limit)
/// - Effective reveal window = 206 blocks = 20.6 seconds
/// - With EIP-2935: window extends to ~13.6 minutes
///
/// @custom:security-contact security@ghostnet.game
abstract contract FutureBlockRandomness {
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Blocks to wait before seed is ready
    /// @dev 50 blocks = 5 seconds on MegaETH. Provides sufficient entropy
    ///      while maintaining acceptable UX. Shorter delays risk prediction.
    uint256 public constant SEED_BLOCK_DELAY = 50;
    
    /// @notice Maximum blocks before native blockhash() returns 0
    /// @dev EVM hard limit - cannot be changed. On MegaETH = 25.6 seconds.
    uint256 public constant MAX_BLOCK_AGE = 256;
    
    /// @notice Extended history window via EIP-2935 (Prague EVM)
    /// @dev If MegaETH supports Prague EVM, we can access ~13.6 minutes of history.
    ///      Falls back to native blockhash if EIP-2935 unavailable.
    uint256 public constant EXTENDED_HISTORY_WINDOW = 8191;
    
    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error SeedNotCommitted();
    error SeedNotReady();
    error SeedExpired();
    error SeedAlreadyCommitted();
    error SeedAlreadyRevealed();
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event SeedCommitted(uint256 indexed roundId, uint256 seedBlock, uint256 deadline);
    event SeedRevealed(uint256 indexed roundId, bytes32 blockHash, uint256 seed, bool usedExtendedHistory);
    event SeedExpired(uint256 indexed roundId, uint256 seedBlock, uint256 expiredAtBlock);
    
    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════
    
    struct RoundSeed {
        uint64 seedBlock;       // Block number to use for seed
        uint64 commitBlock;     // Block when commitment was made (for deadline calc)
        bytes32 blockHash;      // Captured hash (0 until revealed)
        uint256 seed;           // Final derived seed (0 until revealed)
        bool committed;
        bool revealed;
        bool usedExtendedHistory; // True if EIP-2935 was used for reveal
    }
    
    mapping(uint256 roundId => RoundSeed) internal _roundSeeds;
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Commit to a future block for randomness
    /// @param roundId The round identifier
    function _commitSeedBlock(uint256 roundId) internal {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (rs.committed) revert SeedAlreadyCommitted();
        
        uint64 seedBlock = uint64(block.number + SEED_BLOCK_DELAY);
        rs.seedBlock = seedBlock;
        rs.commitBlock = uint64(block.number);
        rs.committed = true;
        
        // Calculate deadline: prefer extended history if available, else native limit
        uint256 deadline = seedBlock + _getEffectiveWindow();
        
        emit SeedCommitted(roundId, seedBlock, deadline);
    }
    
    /// @notice Reveal and cache the seed
    /// @dev Attempts native blockhash first (cheaper), falls back to EIP-2935
    /// @param roundId The round identifier
    /// @return seed The derived seed value
    function _revealSeed(uint256 roundId) internal returns (uint256 seed) {
        RoundSeed storage rs = _roundSeeds[roundId];
        
        if (!rs.committed) revert SeedNotCommitted();
        if (rs.revealed) return rs.seed;
        if (block.number <= rs.seedBlock) revert SeedNotReady();
        
        // Try to get blockhash - native first, then extended history
        (bytes32 hash, bool usedExtended) = _getBlockhash(rs.seedBlock);
        
        if (hash == bytes32(0)) {
            // Both native and extended failed - seed is truly expired
            revert SeedExpired();
        }
        
        // Derive seed with round-specific data to prevent cross-game replay
        seed = uint256(keccak256(abi.encode(
            hash,
            roundId,
            address(this),
            block.chainid
        )));
        
        rs.blockHash = hash;
        rs.seed = seed;
        rs.revealed = true;
        rs.usedExtendedHistory = usedExtended;
        
        emit SeedRevealed(roundId, hash, seed, usedExtended);
    }
    
    /// @notice Get blockhash, trying native first then EIP-2935
    /// @param blockNumber The block to get hash for
    /// @return hash The block hash (or bytes32(0) if unavailable)
    /// @return usedExtended True if EIP-2935 was used
    function _getBlockhash(uint256 blockNumber) internal view returns (bytes32 hash, bool usedExtended) {
        uint256 age = block.number - blockNumber;
        
        // Try native blockhash first (cheaper, works for recent 256 blocks)
        if (age <= MAX_BLOCK_AGE) {
            hash = blockhash(blockNumber);
            if (hash != bytes32(0)) {
                return (hash, false);
            }
        }
        
        // Try EIP-2935 extended history
        if (age <= EXTENDED_HISTORY_WINDOW) {
            hash = BlockhashHistory.getBlockhash(blockNumber);
            if (hash != bytes32(0)) {
                return (hash, true);
            }
        }
        
        // Both failed
        return (bytes32(0), false);
    }
    
    /// @notice Check if seed can be revealed
    function _isSeedReady(uint256 roundId) internal view returns (bool) {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (!rs.committed || rs.revealed) return false;
        if (block.number <= rs.seedBlock) return false;
        
        // Check if within any available window
        uint256 age = block.number - rs.seedBlock;
        return age <= _getEffectiveWindow();
    }
    
    /// @notice Check if seed has expired (beyond all recovery options)
    function _isSeedExpired(uint256 roundId) internal view returns (bool) {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (!rs.committed || rs.revealed) return false;
        if (block.number <= rs.seedBlock) return false;
        
        uint256 age = block.number - rs.seedBlock;
        return age > _getEffectiveWindow();
    }
    
    /// @notice Get the effective window (checks EIP-2935 availability)
    /// @dev Caches the check result since EIP-2935 support won't change mid-tx
    function _getEffectiveWindow() internal view returns (uint256) {
        if (BlockhashHistory.isAvailable()) {
            return EXTENDED_HISTORY_WINDOW;
        }
        return MAX_BLOCK_AGE;
    }
    
    /// @notice Get remaining time to reveal (in blocks)
    /// @param roundId The round identifier
    /// @return blocksRemaining Blocks until expiry (0 if expired or not committed)
    function getRemainingRevealWindow(uint256 roundId) external view returns (uint256 blocksRemaining) {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (!rs.committed || rs.revealed) return 0;
        if (block.number <= rs.seedBlock) {
            // Not ready yet - return full window plus blocks until ready
            return (rs.seedBlock - block.number) + _getEffectiveWindow();
        }
        
        uint256 deadline = rs.seedBlock + _getEffectiveWindow();
        if (block.number >= deadline) return 0;
        
        return deadline - block.number;
    }
    
    /// @notice Get seed info for verification UI
    function getSeedInfo(uint256 roundId) external view returns (
        uint256 seedBlock,
        uint256 commitBlock,
        bytes32 blockHash,
        uint256 seed,
        bool committed,
        bool revealed,
        bool usedExtendedHistory,
        uint256 effectiveWindow
    ) {
        RoundSeed storage rs = _roundSeeds[roundId];
        return (
            rs.seedBlock, 
            rs.commitBlock,
            rs.blockHash, 
            rs.seed, 
            rs.committed, 
            rs.revealed,
            rs.usedExtendedHistory,
            _getEffectiveWindow()
        );
    }
}
```

### 6.4 BlockhashHistory.sol (EIP-2935 Helper)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title BlockhashHistory
/// @notice Helper library for EIP-2935 extended block hash history
/// @dev EIP-2935 (Prague EVM) provides access to block hashes beyond the 256-block limit
///      via a system contract. Window is 8191 blocks (~13.6 minutes on MegaETH).
///
/// Usage:
/// - Call isAvailable() once to check if the network supports EIP-2935
/// - Use getBlockhash() for blocks beyond native blockhash() range
/// - Falls back gracefully on networks without Prague EVM
///
/// @custom:security This is a VIEW-only library. No state modifications.
library BlockhashHistory {
    
    /// @notice EIP-2935 system contract address (standardized)
    address internal constant HISTORY_CONTRACT = 0x0000F90827F1C53a10Cb7A02335B175320002935;
    
    /// @notice Maximum blocks of history available via EIP-2935
    uint256 internal constant HISTORY_WINDOW = 8191;
    
    /// @notice Check if EIP-2935 is available on this network
    /// @dev Checks for code at the system contract address
    /// @return available True if EIP-2935 is supported
    function isAvailable() internal view returns (bool available) {
        uint256 size;
        assembly {
            size := extcodesize(HISTORY_CONTRACT)
        }
        return size > 0;
    }
    
    /// @notice Get block hash from EIP-2935 history contract
    /// @dev Returns bytes32(0) if block is too old or contract unavailable
    /// @param blockNumber The block number to query
    /// @return hash The block hash, or bytes32(0) if unavailable
    function getBlockhash(uint256 blockNumber) internal view returns (bytes32 hash) {
        // Bounds check
        if (block.number <= blockNumber) return bytes32(0);
        if (block.number - blockNumber > HISTORY_WINDOW) return bytes32(0);
        
        // Check availability
        if (!isAvailable()) return bytes32(0);
        
        // Query the history contract
        // EIP-2935 spec: staticcall with block number, returns 32-byte hash
        (bool success, bytes memory data) = HISTORY_CONTRACT.staticcall(
            abi.encode(blockNumber)
        );
        
        if (success && data.length == 32) {
            hash = abi.decode(data, (bytes32));
        }
        
        return hash;
    }
    
    /// @notice Get the history window size
    /// @return window Number of blocks of history available (8191)
    function getWindowSize() internal pure returns (uint256 window) {
        return HISTORY_WINDOW;
    }
}
```

### 6.5 Randomness Failure Recovery

> **See Also:** For a comprehensive randomness congestion mitigation system including keeper incentives,
> graceful degradation, and operational procedures, see:
> [`docs/architecture/randomness-congestion-mitigation.md`](./randomness-congestion-mitigation.md)

When seeds expire (reveal window missed), games must handle recovery gracefully. This section documents the required failure handling.

#### Expiry Detection

```solidity
/// @notice Called periodically or by keeper to check for expired seeds
function checkAndHandleExpiredSeed(uint256 roundId) external {
    if (!_isSeedExpired(roundId)) return;
    
    // Mark session as EXPIRED
    sessions[roundId].state = SessionState.EXPIRED;
    
    // Emit event for indexers/UI
    emit SeedExpired(roundId, _roundSeeds[roundId].seedBlock, block.number);
    
    // Trigger refund process
    _initiateRefunds(roundId);
}
```

#### Refund Process

Games must implement `_initiateRefunds()` to return player deposits:

```solidity
function _initiateRefunds(uint256 roundId) internal {
    Session storage session = sessions[roundId];
    
    // Iterate all players in this round
    for (uint256 i; i < session.playerCount;) {
        address player = session.players[i];
        uint256 deposit = session.deposits[player];
        
        if (deposit > 0) {
            // Clear deposit to prevent double-refund
            session.deposits[player] = 0;
            
            // Request refund via ArcadeCore
            arcadeCore.emergencyRefund(player, deposit);
        }
        
        unchecked { ++i; }
    }
}
```

#### Monitoring & Alerts

**Off-chain systems should monitor for:**

1. **SeedCommitted events** - Track deadline
2. **Block number approaching deadline** - Alert if no SeedRevealed within 80% of window
3. **SeedExpired events** - Trigger investigation, may indicate systemic issue

**Recommended keeper bot behavior:**

```typescript
// Keeper should call reveal proactively
const SAFETY_MARGIN = 50; // blocks before deadline

async function monitorRounds() {
  const activeRounds = await getActiveRoundsWithPendingSeeds();
  
  for (const round of activeRounds) {
    const blocksRemaining = await game.getRemainingRevealWindow(round.id);
    
    if (blocksRemaining > 0 && blocksRemaining < SAFETY_MARGIN) {
      // Attempt reveal to capture seed before expiry
      await game.revealSeed(round.id);
    }
  }
}
```

#### Edge Cases

| Scenario | Handling |
|----------|----------|
| Seed expires during pause | Unpause triggers expiry check |
| Network fork at seed block | Use blockhash from canonical chain |
| EIP-2935 becomes unavailable mid-round | Falls back to native 256-block limit |
| Player attempts action after expiry | Revert with `SessionExpired` error |


### 6.6 CommitRevealBase.sol

For games where players make choices (BINARY BET):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title CommitRevealBase  
/// @notice Base for games with player choice commitment
abstract contract CommitRevealBase {
    
    struct Commitment {
        bytes32 hash;           // keccak256(choice, secret, player)
        uint128 amount;         // Bet amount
        uint8 revealedChoice;   // 255 = not revealed
        bool revealed;
    }
    
    mapping(uint256 roundId => mapping(address => Commitment)) internal _commitments;
    
    error AlreadyCommitted();
    error NotCommitted();
    error AlreadyRevealed();
    error InvalidReveal();
    error RevealPeriodClosed();
    
    event Committed(uint256 indexed roundId, address indexed player, uint256 amount);
    event Revealed(uint256 indexed roundId, address indexed player, uint8 choice);
    event Forfeited(uint256 indexed roundId, address indexed player, uint256 amount);
    
    /// @notice Generate commitment hash (call off-chain)
    function generateCommitmentHash(
        uint8 choice,
        bytes32 secret,
        address player
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, secret, player));
    }
    
    function _commit(
        uint256 roundId,
        address player,
        bytes32 commitHash,
        uint128 amount
    ) internal {
        Commitment storage c = _commitments[roundId][player];
        if (c.amount > 0) revert AlreadyCommitted();
        
        c.hash = commitHash;
        c.amount = amount;
        c.revealedChoice = 255;
        
        emit Committed(roundId, player, amount);
    }
    
    function _reveal(
        uint256 roundId,
        address player,
        uint8 choice,
        bytes32 secret
    ) internal returns (uint8) {
        Commitment storage c = _commitments[roundId][player];
        
        if (c.amount == 0) revert NotCommitted();
        if (c.revealed) revert AlreadyRevealed();
        
        bytes32 expected = keccak256(abi.encodePacked(choice, secret, player));
        if (expected != c.hash) revert InvalidReveal();
        
        c.revealed = true;
        c.revealedChoice = choice;
        
        emit Revealed(roundId, player, choice);
        return choice;
    }
    
    function _forfeit(uint256 roundId, address player) internal returns (uint128 amount) {
        Commitment storage c = _commitments[roundId][player];
        
        if (c.amount == 0 || c.revealed) return 0;
        
        amount = c.amount;
        c.amount = 0;
        
        emit Forfeited(roundId, player, amount);
    }
}
```


---

## 7. Security Model

### 7.1 Access Control Matrix

| Function | ArcadeCore | GameRegistry | Games | Players | Admin |
|----------|:----------:|:------------:|:-----:|:-------:|:-----:|
| `processEntry()` | - | - | ✓ | - | - |
| `creditPayout()` | - | - | ✓ | - | - |
| `withdrawPayouts()` | - | - | - | ✓ | - |
| `registerGame()` | - | - | - | - | ✓ |
| `pauseGame()` | - | - | - | - | ✓ |
| `pause()` (global) | - | - | - | - | ✓ |
| `setTreasury()` | - | - | - | - | ✓ |

### 7.2 Reentrancy Protection

```solidity
// ArcadeCore: All external token interactions protected
function processEntry(...) external nonReentrant { ... }
function creditPayout(...) external nonReentrant { ... }
function withdrawPayouts() external nonReentrant { ... }

// Games: Protected at entry points
function placeBet(...) external nonReentrant { ... }
function cashOut(...) external nonReentrant { ... }
```

### 7.3 Pull-Payment Pattern

Why pull instead of push:
1. **DoS Prevention:** Malicious contract can't block payouts by reverting
2. **Gas Griefing:** Sender doesn't pay gas for complex receivers
3. **Atomicity:** Batch settlements don't fail on single recipient

```solidity
// BAD: Push payment
function settle(address[] memory winners, uint256[] memory amounts) {
    for (uint i = 0; i < winners.length; i++) {
        token.transfer(winners[i], amounts[i]); // Can revert!
    }
}

// GOOD: Pull payment
function settle(address[] memory winners, uint256[] memory amounts) {
    for (uint i = 0; i < winners.length; i++) {
        pendingPayouts[winners[i]] += amounts[i]; // Never reverts
    }
}
```

### 7.4 Rate Limiting

```solidity
// Per-player rate limit
uint256 public constant MIN_PLAY_INTERVAL = 1 seconds;

// In processEntry():
if (block.timestamp < stats.lastPlayTime + MIN_PLAY_INTERVAL) {
    revert RateLimited();
}
stats.lastPlayTime = block.timestamp;
```

### 7.5 Emergency Procedures

```
SCENARIO: Critical bug discovered in HashCrash

1. Admin calls gameRegistry.pauseGame(hashCrash)
   → No new entries accepted
   
2. Admin calls hashCrash.emergencyCancel(currentRoundId, "Security issue")
   → All current bettors refunded via arcadeCore.emergencyRefund()
   
3. Fix deployed, security audit
   
4. Admin calls gameRegistry.unpauseGame(hashCrash)
```

### 7.6 Invariants to Test

These invariants must be tested using Foundry's invariant testing framework. See `packages/contracts/test/arcade/invariants/` for full implementation.

**Critical Invariants:**

| # | Invariant | Severity | Test Method |
|---|-----------|----------|-------------|
| 1 | ArcadeCore balance >= totalPendingPayouts | **Critical** | `invariant_Solvency()` |
| 2 | Sum of pending payouts == totalPendingPayouts | High | `invariant_PayoutConsistency()` |
| 3 | Player can always withdraw pending balance | High | `invariant_WithdrawalsAlwaysSucceed()` |
| 4 | Only registered games can credit payouts | **Critical** | `invariant_OnlyRegisteredGamesCanCredit()` |
| 5 | Seed can only be used once per round | Medium | `invariant_SeedSingleUse()` |
| 6 | Upgrades require 2-day timelock | **Critical** | `invariant_UpgradeTimelockEnforced()` |
| 7 | totalBurned is monotonically increasing | Medium | `invariant_BurnMonotonicity()` |

**Foundry Invariant Test Structure:**

```solidity
// packages/contracts/test/arcade/invariants/ArcadeCoreInvariant.t.sol
contract ArcadeCoreInvariantTest is Test {
    ArcadeCore public arcadeCore;
    ArcadeCoreHandler public handler;
    uint256 public lastRecordedBurn;
    
    function setUp() public {
        handler = new ArcadeCoreHandler(arcadeCore, dataToken, mockGame);
        targetContract(address(handler));
    }
    
    /// @notice CRITICAL: ArcadeCore must always be solvent
    function invariant_Solvency() public view {
        assertGe(
            dataToken.balanceOf(address(arcadeCore)),
            arcadeCore.totalPendingPayouts(),
            "INVARIANT VIOLATED: ArcadeCore is insolvent"
        );
    }
    
    /// @notice Sum of individual payouts must equal tracked total
    function invariant_PayoutConsistency() public view {
        uint256 sum = 0;
        address[] memory allPlayers = handler.getPlayers();
        for (uint256 i = 0; i < allPlayers.length; i++) {
            sum += arcadeCore.getPendingPayout(allPlayers[i]);
        }
        assertEq(sum, arcadeCore.totalPendingPayouts());
    }
    
    /// @notice Burned tokens must be monotonically increasing
    function invariant_BurnMonotonicity() public {
        uint256 currentBurned = arcadeCore.totalBurned();
        assertGe(currentBurned, lastRecordedBurn);
        lastRecordedBurn = currentBurned;
    }
    
    /// @notice Only registered games can credit payouts
    function invariant_OnlyRegisteredGamesCanCredit() public view {
        assertEq(handler.unauthorizedCreditSuccesses(), 0);
    }
}

/// @title ArcadeCoreHandler - Stateful handler for invariant fuzzing
contract ArcadeCoreHandler is Test {
    address[] public players;
    uint256 public unauthorizedCreditSuccesses;
    
    function placeBet(uint256 playerSeed, uint256 amount) external { /* fuzz player interactions */ }
    function creditPayout(uint256 playerSeed, uint256 amount) external { /* fuzz payouts */ }
    function withdraw(uint256 playerSeed) external { /* fuzz withdrawals */ }
    
    function attemptUnauthorizedCredit(address attacker, address victim, uint256 amount) external {
        vm.prank(attacker);
        try arcadeCore.creditPayout(victim, amount, 0, true) {
            unauthorizedCreditSuccesses++; // Should never increment
        } catch {}
    }
    
    function getPlayers() external view returns (address[] memory) { return players; }
}
```

**Running invariant tests:**

```bash
# Quick run (CI) - ~1000 call sequences
forge test --match-contract ArcadeCoreInvariant --fuzz-runs 1000

# Deep run (pre-release) - ~100k call sequences  
forge test --match-contract ArcadeCoreInvariant --fuzz-runs 100000
```

### 7.7 Timelock Protection

ArcadeCore implements multi-layered timelock protection to prevent unauthorized or malicious upgrades:

#### Admin Transfer Protection (via AccessControlDefaultAdminRules)

```solidity
// Admin transfers require 3-day waiting period
INITIAL_ADMIN_DELAY = 3 days;

// Transfer flow:
// 1. Current admin calls beginDefaultAdminTransfer(newAdmin)
// 2. Wait 3 days
// 3. newAdmin calls acceptDefaultAdminTransfer()
```

This prevents:
- Immediate admin hijacking if key is compromised
- Accidental transfer to wrong address
- Social engineering attacks that pressure quick transfers

#### Upgrade Timelock Protection

| Operation | Timelock | Bypass Allowed? |
|-----------|----------|-----------------|
| Contract upgrade | 2 days | **NO** |
| Admin transfer | 3 days | **NO** |
| Game pause | Immediate | Yes (emergency) |
| Global pause | Immediate | Yes (emergency) |

**Upgrade Flow:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           UPGRADE TIMELINE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Day 0         Day 1         Day 2         Day 3+                           │
│    │             │             │             │                               │
│    ▼             │             │             │                               │
│  ┌──────┐        │             │             │                               │
│  │Propose│       │             │             │                               │
│  │Upgrade│       │             │             │                               │
│  └───┬───┘       │             │             │                               │
│      │           │             │             │                               │
│      ▼───────────▼─────────────▼             │                               │
│    [ TIMELOCK PERIOD - 48 hours ]           │                               │
│    Community can review & respond           │                               │
│      │                                       │                               │
│      │         ┌────────┐                    │                               │
│      └─────────┤ Cancel │ (optional)         │                               │
│                │Upgrade │                    │                               │
│                └────────┘                    │                               │
│                                              ▼                               │
│                                         ┌──────┐                             │
│                                         │Execute│                            │
│                                         │Upgrade│                            │
│                                         └──────┘                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why No Emergency Bypass for Upgrades:**

1. **Pause is sufficient**: If a bug is discovered, `pause()` immediately stops all gameplay
2. **Upgrades cannot fix in-flight issues**: Pending payouts remain accessible during pause
3. **Malicious upgrades are catastrophic**: A bypass could drain ALL funds instantly
4. **2 days is reasonable**: Enough time to deploy fix, but not so long as to be impractical

**Monitoring Recommendations:**

```
On UpgradeProposed event:
1. Alert security team immediately
2. Review proposed implementation code
3. Verify proposal came from expected multisig
4. If suspicious: prepare cancelUpgrade transaction

On UpgradeCancelled event:
1. Log reason for cancellation
2. Investigate if unauthorized proposal attempt

On UpgradeExecuted event:
1. Verify new implementation behaves correctly
2. Run post-upgrade health checks
```

### 7.8 Formal Verification Candidates

The following invariants are candidates for formal verification using Certora or Halmos. Formal verification provides mathematical proofs that invariants hold for ALL possible inputs, not just fuzzed samples.

| Invariant | Priority | Tool | Rationale |
|-----------|----------|------|-----------|
| **Solvency** | **Critical** | Certora | Funds at risk if violated |
| **Payout Consistency** | High | Certora | Accounting integrity |
| **Access Control** | **Critical** | Certora | Prevents unauthorized fund movement |
| Burn Monotonicity | Medium | Halmos | Economic model integrity |
| Session Single-Settlement | High | Certora | Prevents double-spend |
| Withdrawal Liveness | High | Certora | Players can always exit |

**Certora Specification Sketch:**

```cvl
// spec/ArcadeCore.spec

ghost mathint sumPendingPayouts {
    init_state axiom sumPendingPayouts == 0;
}

hook Sstore pendingPayouts[KEY address player] uint256 newValue (uint256 oldValue) {
    sumPendingPayouts = sumPendingPayouts - oldValue + newValue;
}

invariant solvencyInvariant()
    dataToken.balanceOf(currentContract) >= totalPendingPayouts()

invariant payoutSumConsistency()
    sumPendingPayouts == to_mathint(totalPendingPayouts())

rule onlyRegisteredGamesCanCredit(env e, address player, uint256 amount) {
    bool registered = gameRegistry.isGameRegistered(e.msg.sender);
    creditPayout@withrevert(e, player, amount, 0, true);
    assert !registered => lastReverted;
}

rule burnNeverDecreases(env e, method f) {
    uint256 burnBefore = totalBurned();
    calldataarg args;
    f(e, args);
    assert totalBurned() >= burnBefore;
}
```

**Recommendation:** Prioritize formal verification for **solvency** and **access control** before mainnet deployment. Budget 2-4 weeks for Certora specification.

### 7.9 Flash Loan Protection (Issue #6)

**Attack Vector:**
```
1. Attacker flash borrows 1M DATA
2. Calculates favorable outcomes for multiple betting positions
3. Places bets across multiple sessions/games in SAME BLOCK
4. If games use predictable randomness (same block), attacker wins
5. Withdraws winnings, repays flash loan, keeps profit
```

**Problem:** Time-based rate limiting (1 second) doesn't prevent same-block attacks because multiple transactions can occur in a single block.

**Solution:** Block-based wager limits at both per-player and global levels.

```solidity
// Per-player block activity tracking
struct PlayerBlockActivity {
    uint64 lastPlayBlock;           // Last block player wagered
    uint128 currentBlockWagered;    // Total wagered in current block
    uint64 lastPlayTime;            // Timestamp for time-based rate limit
}

// Configurable limits (adjustable by admin with timelock)
uint256 public maxWagerPerBlock = 100_000 ether;      // Per player, per block
uint256 public maxTotalWagerPerBlock = 1_000_000 ether; // Global, per block

// In processEntry():
function _enforceFlashLoanProtection(address player, uint256 amount) internal {
    PlayerBlockActivity storage activity = _playerActivity[player];
    
    if (block.number == activity.lastPlayBlock) {
        // Same block - enforce per-player limit
        if (activity.currentBlockWagered + amount > maxWagerPerBlock) {
            revert FlashLoanProtection(amount, maxWagerPerBlock - activity.currentBlockWagered);
        }
        activity.currentBlockWagered += uint128(amount);
    } else {
        // New block - reset counter
        activity.lastPlayBlock = uint64(block.number);
        activity.currentBlockWagered = uint128(amount);
    }
    
    // Global same-block limit
    if (block.number != _lastWagerBlock) {
        _currentBlockWagers = 0;
        _lastWagerBlock = block.number;
    }
    _currentBlockWagers += amount;
    if (_currentBlockWagers > maxTotalWagerPerBlock) {
        revert GlobalWagerLimitExceeded();
    }
}
```

**Threshold Rationale:**

| Limit | Value | Rationale |
|-------|-------|-----------|
| Per-player per-block | 100k DATA | ~10x typical max bet, prevents concentrated attacks |
| Global per-block | 1M DATA | ~10 players at max, limits total exposure |

**Admin Functions:**

```solidity
// Adjustable via timelock for market conditions
function setMaxWagerPerBlock(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE);
function setMaxTotalWagerPerBlock(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE);
function getFlashLoanLimits() external view returns (uint256, uint256);
```

### 7.10 Circuit Breakers (Recommendation #15)

**Problems Addressed:**
1. Abnormally large single payouts (bug or exploit)
2. Sustained high payout rates (economic attack)
3. Rapid drain of ArcadeCore balance

**Implementation:**

```solidity
// Circuit breaker constants
uint256 public constant MAX_SINGLE_PAYOUT = 500_000 ether;
uint256 public constant MAX_HOURLY_PAYOUTS = 5_000_000 ether;
uint256 public constant MAX_DAILY_PAYOUTS = 20_000_000 ether;

// Circuit breaker state
uint256 internal _hourlyPayouts;
uint256 internal _dailyPayouts;
uint256 internal _lastHourTimestamp;
uint256 internal _lastDayTimestamp;
bool public circuitBreakerTripped;

function _enforceCircuitBreaker(uint256 amount) internal {
    if (circuitBreakerTripped) revert CircuitBreakerActive();
    
    // Single payout limit
    if (amount > MAX_SINGLE_PAYOUT) {
        _tripCircuitBreaker("Single payout exceeded", amount);
        revert PayoutTooLarge(amount, MAX_SINGLE_PAYOUT);
    }
    
    // Hourly limit (reset on new hour)
    uint256 currentHour = block.timestamp / 1 hours;
    if (currentHour != _lastHourTimestamp / 1 hours) {
        _hourlyPayouts = 0;
        _lastHourTimestamp = block.timestamp;
    }
    _hourlyPayouts += amount;
    if (_hourlyPayouts > MAX_HOURLY_PAYOUTS) {
        _tripCircuitBreaker("Hourly payout exceeded", _hourlyPayouts);
        revert HourlyPayoutLimitExceeded(_hourlyPayouts, MAX_HOURLY_PAYOUTS);
    }
    
    // Daily limit (reset on new day)
    uint256 currentDay = block.timestamp / 1 days;
    if (currentDay != _lastDayTimestamp / 1 days) {
        _dailyPayouts = 0;
        _lastDayTimestamp = block.timestamp;
    }
    _dailyPayouts += amount;
    if (_dailyPayouts > MAX_DAILY_PAYOUTS) {
        _tripCircuitBreaker("Daily payout exceeded", _dailyPayouts);
        revert DailyPayoutLimitExceeded(_dailyPayouts, MAX_DAILY_PAYOUTS);
    }
}

function _tripCircuitBreaker(string memory reason, uint256 value) internal {
    circuitBreakerTripped = true;
    emit CircuitBreakerTripped(reason, value);
}

// Admin can reset after investigation (requires timelock in production)
function resetCircuitBreaker() external onlyRole(DEFAULT_ADMIN_ROLE) {
    circuitBreakerTripped = false;
    _hourlyPayouts = 0;
    _dailyPayouts = 0;
    _lastHourTimestamp = block.timestamp;
    _lastDayTimestamp = block.timestamp;
    emit CircuitBreakerReset(msg.sender);
}
```

**Threshold Rationale:**

| Limit | Value | Rationale |
|-------|-------|-----------|
| Single payout | 500k DATA | 5x expected max (~100k), catches bugs |
| Hourly | 5M DATA | ~10x single, allows high activity |
| Daily | 20M DATA | ~4x hourly, sustainable rate |

**Critical Design Decision: Withdrawals NOT Blocked**

```solidity
function withdrawPayouts() external nonReentrant returns (uint256 amount) {
    // NOTE: Withdrawals are NOT blocked by circuit breaker
    // Players must always be able to withdraw earned funds
    // Circuit breaker only prevents NEW payouts from games
    ...
}
```

**Circuit Breaker Response Procedure:**

```
When CircuitBreakerTripped event fires:

1. IMMEDIATE (0-5 minutes)
   - Alert security team (PagerDuty/Slack)
   - Pause affected game(s) if identifiable
   - Begin incident log

2. INVESTIGATION (5-60 minutes)
   - Query events to identify source
   - Check for exploited game contracts
   - Assess damage (payouts credited vs available balance)

3. REMEDIATION (1-24 hours)
   - If exploit: Deploy fix to affected game
   - If false positive: Document why limits triggered
   - Prepare post-mortem

4. RESET (after investigation complete)
   - Admin calls resetCircuitBreaker()
   - Monitor closely for recurrence
   - Adjust thresholds if needed
```

---

## 8. Gas Optimization Strategy

### 8.1 Storage Packing

```solidity
// PlayerStats: 3 slots instead of 8
struct PlayerStats {
    uint64 totalGamesPlayed;    // slot 0
    uint64 totalWins;           // slot 0
    uint64 totalLosses;         // slot 0
    uint64 lastPlayTime;        // slot 0
    uint128 totalWagered;       // slot 1
    uint128 totalWon;           // slot 1
    uint128 totalBurned;        // slot 2 (partial)
    uint32 currentStreak;       // slot 2
    uint32 maxStreak;           // slot 2
}

// RoundSeed: 2 slots instead of 5
struct RoundSeed {
    uint64 seedBlock;           // slot 0
    bool committed;             // slot 0
    bool revealed;              // slot 0
    // 22 bytes remaining in slot 0
    bytes32 blockHash;          // slot 1
    uint256 seed;               // slot 2
}
```

#### Storage vs Precision Tradeoff (AMOUNT_SCALE)

**Problem:** Packing amount fields (totalWagered, totalWon, totalBurned) into uint128 requires scaling.

**Options evaluated:**

| Option | Scale | Min Trackable | Max Trackable | Storage | Notes |
|--------|-------|---------------|---------------|---------|-------|
| 1e12 (rejected) | 1e12 | 0.000001 DATA | ~340T DATA | 3 slots | **Loses micro-bets** |
| 1e6 (chosen) | 1e6 | 1e-12 DATA | ~340B DATA | 3 slots | Accurate for arcade |
| Full precision | N/A | 1 wei | 2^256 wei | 5 slots | +40k gas first write |

**Decision:** Use `AMOUNT_SCALE = 1e6` (reduced from 1e12).

- **Precision gained:** Tracks down to 1 pico-DATA (1e-12 DATA = 1e6 wei)
- **Precision lost:** Amounts < 1e6 wei truncate to 0 (negligible, ~$0.0000000001)
- **Max trackable:** ~340 billion DATA per player (more than total supply)
- **Gas cost:** Unchanged (still 3 storage slots)

**Example improvement:**
```
Player bets 100x at 0.0000005 DATA (5e11 wei) each:
- With 1e12 scale: Tracked = 0 (all lost!)
- With 1e6 scale:  Tracked = 500,000 scaled units = 0.00005 DATA ✓
```

### 8.2 Batch Operations

```solidity
// Gas efficient batch settlement
function batchCreditPayouts(
    address[] calldata players,
    uint256[] calldata amounts,
    uint256[] calldata burnAmounts,
    bool[] calldata results
) external nonReentrant {
    // Single SLOAD for storage pointer
    ArcadeCoreStorage storage $ = _getStorage();
    
    // Accumulate totals for single transfers
    uint256 totalBurn;
    uint256 totalPayout;
    
    uint256 len = players.length;
    for (uint256 i; i < len;) {
        // Update in-memory, commit once
        totalBurn += burnAmounts[i];
        totalPayout += amounts[i];
        $.pendingPayouts[players[i]] += amounts[i];
        
        unchecked { ++i; }
    }
    
    // Single burn transfer
    if (totalBurn > 0) {
        $.dataToken.safeTransfer(DEAD_ADDRESS, totalBurn);
    }
    
    $.totalPendingPayouts += totalPayout;
    $.totalBurned += totalBurn;
}
```

### 8.3 Transient Storage Reentrancy Guard

ArcadeCore uses `ReentrancyGuardTransientUpgradeable` (EIP-1153) instead of the traditional storage-based guard:

```solidity
// Storage-based (OLD): ~5000 gas per guarded call
// SSTORE to set lock, SSTORE to clear lock

// Transient-based (NEW): ~100 gas per guarded call  
// TSTORE to set lock, TSTORE to clear lock
// Auto-cleared at end of transaction

import {ReentrancyGuardTransientUpgradeable} from 
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
```

**Gas savings:** ~4,900 gas per protected function call. With `processEntry()`, `creditPayout()`, and `withdrawPayouts()` all using `nonReentrant`, this saves ~14,700 gas per typical user flow.

**Requirement:** EIP-1153 support (Cancun upgrade, available on all modern chains including MegaETH).

### 8.4 Custom Errors (vs require strings)

```solidity
// BAD: ~50 bytes per error message stored
require(msg.sender == owner, "Only owner can call");

// GOOD: 4 bytes selector
error NotOwner();
if (msg.sender != owner) revert NotOwner();

// Gas savings: ~200 gas per error check
```

### 8.5 Unchecked Math

When using `unchecked` blocks, we must prove overflow is impossible. This section documents the safety analysis for all unchecked operations.

#### Rake Calculation

```solidity
uint256 rake = (amount * rakeBps) / BPS;
```

**Overflow Safety Analysis:**

| Variable | Constraint | Max Value |
|----------|-----------|-----------|
| `amount` | User-provided, validated by maxEntry | 1000e18 DATA (config) |
| `rakeBps` | Capped at 1000 (10%) by EntryConfig validation | 1000 |
| `BPS` | Constant | 10,000 |

**Calculation:**
- `amount * rakeBps` max = `1000e18 * 1000` = `1e24`
- `type(uint256).max` = `~1.16e77`
- **Overflow requires:** `amount > type(uint256).max / 1000` = `~1.16e74`
- Total DATA supply is ~1 billion = `1e27 wei` (assuming 18 decimals)

**Conclusion:** Overflow is mathematically impossible given any realistic token amount.

#### Loop Counter

```solidity
for (uint256 i; i < len;) {
    // ... loop body
    unchecked { ++i; } // Saves ~60 gas per iteration
}
```

**Overflow Safety Analysis:**

| Variable | Constraint | Max Value |
|----------|-----------|-----------|
| `len` | Array length | Bounded by block gas limit |
| `i` | Counter | Increments by 1 per iteration |

**Calculation:**
- Maximum realistic iterations (batch operations): ~1000
- uint256 overflow requires: `2^256` iterations = `~1.16e77`
- At 1 iteration per 100ms block, overflow would take `~3.7e66 years`

**Conclusion:** Overflow is impossible within any practical execution context.

#### Net Amount Subtraction

```solidity
uint256 rake = (amount * rakeBps) / BPS;
unchecked {
    uint256 net = amount - rake; // Safe: rake <= amount
}
```

**Underflow Safety Analysis:**
- `rake = (amount * rakeBps) / BPS`
- Since `rakeBps <= 10000` (100%) and `BPS = 10000`:
  - `rake = amount * (rakeBps / BPS) <= amount * 1 = amount`
- Therefore: `rake <= amount` is always true
- **`amount - rake` can never underflow**

**Conclusion:** Underflow is mathematically impossible.

#### Summary of Unchecked Operations

| Operation | Location | Safety Guarantee |
|-----------|----------|------------------|
| `amount * rakeBps` | `processEntry()` | Max product << uint256.max |
| `++i` in loops | All batch operations | Iterations << uint256.max |
| `amount - rake` | `processEntry()` | rake <= amount always |
| `rakeAmount - burnAmount` | `processEntry()` | burnBps <= BPS ensures burn <= rake |

---

## 9. Upgrade Strategy

### 9.1 What's Upgradeable

| Contract | Upgradeable | Reason |
|----------|:-----------:|--------|
| ArcadeCore | ✓ UUPS | Central hub, bug fixes critical |
| GameRegistry | ✗ | Simple config, redeploy if needed |
| Individual Games | ✗ | Isolated scope, redeploy + re-register |
| Randomness Bases | ✗ | Abstract, included in game deployment |

### 9.2 UUPS Pattern for ArcadeCore with Timelock

ArcadeCore uses UUPS upgradeability with a **mandatory 2-day timelock** on all upgrades. This prevents a compromised admin key from immediately deploying a malicious implementation.

```solidity
contract ArcadeCore is 
    UUPSUpgradeable, 
    AccessControlDefaultAdminRulesUpgradeable  // 3-day admin transfer delay
{
    uint48 public constant UPGRADE_TIMELOCK = 2 days;
    
    struct PendingUpgrade {
        address implementation;
        uint48 readyAt;
        bool executed;
    }
    mapping(bytes32 => PendingUpgrade) public pendingUpgrades;
    
    /// @notice Version for upgrade tracking
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
    
    /// @notice Step 1: Propose upgrade (starts 2-day timer)
    function proposeUpgrade(address newImplementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 id = keccak256(abi.encode(newImplementation));
        require(pendingUpgrades[id].readyAt == 0, "Already proposed");
        
        pendingUpgrades[id] = PendingUpgrade({
            implementation: newImplementation,
            readyAt: uint48(block.timestamp) + UPGRADE_TIMELOCK,
            executed: false
        });
        emit UpgradeProposed(newImplementation, block.timestamp + UPGRADE_TIMELOCK, id);
    }
    
    /// @notice Step 2: Execute upgrade (after timelock)
    /// Called via upgradeTo() or upgradeToAndCall()
    function _authorizeUpgrade(address newImplementation) internal override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        
        bytes32 id = keccak256(abi.encode(newImplementation));
        PendingUpgrade storage pending = pendingUpgrades[id];
        
        require(pending.readyAt != 0, "Not proposed");
        require(block.timestamp >= pending.readyAt, "Timelock active");
        require(!pending.executed, "Already executed");
        
        pending.executed = true;
        emit UpgradeExecuted(newImplementation, id);
    }
    
    /// @notice Cancel a pending upgrade (safety valve)
    function cancelUpgrade(address implementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 id = keccak256(abi.encode(implementation));
        require(pendingUpgrades[id].readyAt != 0, "Not proposed");
        require(!pendingUpgrades[id].executed, "Already executed");
        
        delete pendingUpgrades[id];
        emit UpgradeCancelled(implementation, id);
    }
}
```

**Upgrade Checklist:**

1. Deploy new implementation contract
2. Call `proposeUpgrade(newImplementationAddress)`
3. Wait 2 days (monitoring for suspicious activity)
4. Call `upgradeToAndCall(newImplementationAddress, "")` 
5. Verify new implementation is active

### 9.3 Storage Compatibility with ERC-7201

ArcadeCore uses **ERC-7201 namespaced storage**, which eliminates the need for traditional `__gap` variables. The storage struct lives at a deterministic location based on a namespace hash, preventing collisions across upgrades and inherited contracts.

**Why ERC-7201 over __gap:**

| Aspect | `__gap` Pattern | ERC-7201 Namespaced |
|--------|-----------------|---------------------|
| Storage collision risk | Possible if gaps miscounted | Eliminated by hash |
| Adding new fields | Requires gap bookkeeping | Just append to struct |
| Inheritance safety | Fragile | Safe by design |
| Tooling support | Manual verification | OpenZeppelin plugin support |
| Gas cost | Same | Same |

**Upgrading ArcadeCore:**

```solidity
// V1 Storage (deployed)
/// @custom:storage-location erc7201:ghostnet.arcade.core
struct ArcadeCoreStorage {
    IERC20 dataToken;
    IGhostCore ghostCore;
    IGameRegistry gameRegistry;
    address treasury;
    mapping(address => PlayerStats) playerStats;
    mapping(address => uint256) pendingPayouts;
    uint256 totalGamesPlayed;
    uint256 totalVolume;
    uint256 totalBurned;
    uint256 totalRakeCollected;
    uint256 totalPendingPayouts;
    uint256 nextSessionId;
}

// V2 Storage (upgraded) - SAFE: just append new fields
/// @custom:storage-location erc7201:ghostnet.arcade.core
struct ArcadeCoreStorage {
    // ... all V1 fields unchanged ...
    
    // New V2 fields (appended at end)
    address newFeatureContract;
    mapping(address => uint256) newPlayerData;
}
```

**Rules for ERC-7201 Upgrades:**

1. **Never remove fields** from the storage struct
2. **Never reorder fields** within the struct
3. **Never change field types** (uint256 → uint128 is NOT allowed)
4. **Always append** new fields at the end of the struct
5. **Never change the namespace** string ("ghostnet.arcade.core")

**Adding a New Namespaced Struct:**

For entirely new feature modules, create a separate namespace:

```solidity
/// @custom:storage-location erc7201:ghostnet.arcade.tournaments
struct TournamentStorage {
    mapping(uint256 => Tournament) tournaments;
    uint256 nextTournamentId;
}

// Compute separately: keccak256(abi.encode(uint256(keccak256("ghostnet.arcade.tournaments")) - 1)) & ~bytes32(uint256(0xff))
bytes32 private constant TOURNAMENT_STORAGE_LOCATION = 0x...; // Different hash
```

This pattern allows modular storage that can be added in future versions without affecting the core storage layout.

---

## 10. Implementation Order

### Phase 1: Infrastructure (Week 1)

```
Day 1-2: Interfaces
├── IArcadeTypes.sol
├── IArcadeCore.sol
├── IArcadeGame.sol
└── IGameRegistry.sol

Day 3-4: Core Contracts
├── GameRegistry.sol
├── ArcadeCore.sol (skeleton)
└── Unit tests

Day 5: Randomness
├── FutureBlockRandomness.sol
├── CommitRevealBase.sol
└── Unit tests for randomness
```

### Phase 2: First Game - HASH CRASH (Week 2)

```
Day 1-2: Contract
├── HashCrash.sol
├── Integration with ArcadeCore
└── Unit tests

Day 3-4: Testing
├── Fuzz tests
├── Invariant tests
└── Integration tests

Day 5: Audit prep
├── Slither analysis
├── Manual review
└── Documentation
```

### Phase 3: Validation (Week 3)

```
├── Local testnet deployment
├── E2E testing with frontend
├── Gas profiling
├── Security review
└── Testnet deployment
```

---

## 11. Open Questions

### 11.1 Tax Handling (RESOLVED)

**Question:** Should ArcadeCore payouts be exempt from DataToken's 10% transfer tax?

**Decision:** **Tax on BOTH entry AND exit.** Full 10% transfer tax applies to all arcade transactions.

**Rationale:**
- Consistent with all other $DATA transfers in the ecosystem
- Maximizes burn mechanism effectiveness
- Players accept the tax as part of the game economics

**Effective Economics:**
```
Player deposits 100 DATA → 90 DATA enters prize pool (10% tax burned)
Player wins 2x → 180 DATA prize credited
Player withdraws → 162 DATA received (10% tax burned)

Breakeven multiplier: ~1.23x (before rake)
To double money: Need ~2.47x win
```

**Implementation:** No special tax exemptions needed. ArcadeCore treated like any other address.

**Note:** This is a deliberate design choice favoring tokenomics over player UX. The high effective cost is offset by the game's entertainment value and potential for large wins.

### 11.2 GhostCore Boost Integration (RESOLVED)

**Question:** How do arcade wins grant boosts to GhostCore positions?

**Decision:** **Server-signed boosts.** Use existing GhostCore signature-based flow.

**Flow:**
```
1. Player wins arcade game (on-chain)
2. Backend indexes GameSettled event
3. Backend verifies win conditions
4. Backend signs boost authorization
5. Player claims boost on GhostCore (on-chain)
```

**GhostCore interface (existing):**
```solidity
function applyBoost(
    BoostType boostType,
    uint16 valueBps,
    uint64 expiry,
    bytes32 nonce,
    bytes calldata signature  // Server signature
) external;
```

**Rationale:**
- Already implemented and battle-tested in GhostCore
- Allows flexible anti-abuse logic (rate limiting, suspicious pattern detection)
- No contract upgrades required for launch
- Centralization is acceptable for boost rewards (not critical path)

**Future consideration:** Direct contract integration (trustless) can be added in Phase 2 if needed, requiring GhostCore upgrade to add `ARCADE_ROLE`.

### 11.3 Matchmaking Service Scope

**Question:** What goes on-chain vs off-chain for CODE DUEL matchmaking?

**Proposed split:**
- **Off-chain:** Queue management, skill matching, ready checks
- **On-chain:** Wager escrow, result settlement, dispute resolution

**TBD:** Detailed spec needed before CODE DUEL implementation.

### 11.4 Seed Block Expiry Handling (RESOLVED)

**Question:** What happens if no one calls `_revealSeed()` within 256 blocks?

**Solution:** Self-service refund mechanism. Players can claim their own refunds without waiting for admin intervention.

#### Self-Service Expired Session Refunds

When a seed expires (blockhash unavailable after 256 blocks, or 8191 blocks with EIP-2935), players can trigger their own refunds permissionlessly.

**Design principles:**
1. **Self-service:** Any address can call for any player (altruistic or self)
2. **No admin dependency:** Works even if operators are offline
3. **Gas-efficient batching:** Multiple players can be refunded in one tx
4. **No incentive needed:** Players are motivated to recover their own funds

**Implementation in game contracts (e.g., HashCrash.sol):**

```solidity
/// @notice Claim refund for expired session
/// @dev Anyone can call this for any player with an expired session.
///      This enables players to self-service OR for keepers/friends to help.
/// @param roundId The round with an expired seed
/// @param player The player address to refund
function claimExpiredRefund(uint256 roundId, address player) external {
    RoundSeed storage rs = _roundSeeds[roundId];
    
    // Verify seed is truly expired (not just uncommitted or revealed)
    if (!rs.committed) revert SeedNotCommitted();
    if (rs.revealed) revert SeedAlreadyRevealed();
    
    // Check native blockhash first, then EIP-2935 fallback
    bytes32 hash = _getBlockHash(rs.seedBlock);
    if (hash != bytes32(0)) revert SeedNotExpired(); // Can still reveal!
    
    // Get player's deposit in this round
    uint256 deposit = _playerDeposits[roundId][player];
    if (deposit == 0) revert NoDepositInRound();
    
    // Mark as refunded (prevent double-claim)
    _playerDeposits[roundId][player] = 0;
    
    // Request refund from ArcadeCore
    // ArcadeCore.emergencyRefund credits to player's pending balance
    arcadeCore.emergencyRefund(roundId, player, deposit);
    
    emit ExpiredRefundClaimed(roundId, player, deposit);
}

/// @notice Batch claim refunds for multiple players in one tx
/// @dev Gas-efficient for operators helping clear stuck rounds
/// @param roundId The round with an expired seed
/// @param players Array of player addresses to refund
function batchClaimExpiredRefunds(
    uint256 roundId, 
    address[] calldata players
) external {
    RoundSeed storage rs = _roundSeeds[roundId];
    
    // Verify seed is expired once (gas optimization)
    if (!rs.committed) revert SeedNotCommitted();
    if (rs.revealed) revert SeedAlreadyRevealed();
    bytes32 hash = _getBlockHash(rs.seedBlock);
    if (hash != bytes32(0)) revert SeedNotExpired();
    
    // Process each player
    for (uint256 i; i < players.length;) {
        uint256 deposit = _playerDeposits[roundId][players[i]];
        
        // Skip players with no deposit (don't revert batch)
        if (deposit > 0) {
            _playerDeposits[roundId][players[i]] = 0;
            arcadeCore.emergencyRefund(roundId, players[i], deposit);
            emit ExpiredRefundClaimed(roundId, players[i], deposit);
        }
        
        unchecked { ++i; }
    }
}
```

**Events for indexing:**

```solidity
event ExpiredRefundClaimed(
    uint256 indexed roundId,
    address indexed player,
    uint256 amount
);
```

**Operational considerations:**

| Scenario | Who Calls | Gas Paid By |
|----------|-----------|-------------|
| Player self-service | Player | Player |
| Friend/helper | Third party | Helper (altruistic) |
| Operator cleanup | Backend keeper | Protocol (operational cost) |
| Batch clearing | Anyone with list | Caller |

**Why no keeper reward?**
- Players already have incentive (their own funds)
- Adding rewards complicates accounting
- Could consider: small gas reimbursement from rake pool (future feature)

**Frontend UX:**
1. Detect expired sessions (seedBlock + EIP2935_WINDOW < block.number)
2. Show "Claim Refund" button for affected users
3. Call `claimExpiredRefund(roundId, userAddress)`
4. Refresh pending balance in ArcadeCore

---

## Appendix A: File Checklist

```
packages/contracts/src/arcade/
├── [ ] ArcadeCore.sol
├── [ ] GameRegistry.sol
├── interfaces/
│   ├── [ ] IArcadeCore.sol
│   ├── [ ] IArcadeGame.sol
│   ├── [ ] IArcadeTypes.sol
│   └── [ ] IGameRegistry.sol
├── randomness/
│   ├── [ ] FutureBlockRandomness.sol
│   └── [ ] CommitRevealBase.sol
└── games/
    └── [ ] HashCrash.sol

packages/contracts/test/arcade/
├── [ ] ArcadeCore.t.sol
├── [ ] GameRegistry.t.sol
├── [ ] FutureBlockRandomness.t.sol
├── [ ] CommitRevealBase.t.sol
└── games/
    └── [ ] HashCrash.t.sol
```

---

## Appendix B: Deployment Sequence

### Phase 1: Initial Deployment (Deployer as Admin)

```
1. Deploy DataToken (if not exists)
2. Deploy GhostCore (if not exists)
3. Deploy TimelockController(
     minDelay: 2 days,
     proposers: [multisig],
     executors: [multisig],
     admin: address(0)  // No separate admin - proposers manage themselves
   )
4. Deploy GameRegistry(owner: deployer)  // Temporary, will transfer to timelock
5. Deploy ArcadeCore implementation contract
6. Deploy ERC1967Proxy pointing to ArcadeCore implementation
7. Initialize ArcadeCore proxy with:
   - dataToken: DataToken address
   - ghostCore: GhostCore address  
   - gameRegistry: GameRegistry address
   - treasury: Treasury address
   - admin: deployer address (TEMPORARY - will transfer to timelock)
   NOTE: INITIAL_ADMIN_DELAY (3 days) is set automatically
8. Call gameRegistry.setArcadeCore(arcadeCore)
9. Call dataToken.setTaxExclusion(arcadeCore, true)
```

### Phase 2: Game Deployment

```
10. Deploy HashCrash(arcadeCore)
11. Call gameRegistry.registerGame(hashCrash, entryConfig)
12. Deploy additional games as needed
13. Verify all contracts on block explorer
```

### Phase 3: Admin Transfer to Timelock (CRITICAL)

```
14. Call arcadeCore.beginDefaultAdminTransfer(timelockAddress)
    → Starts 3-day waiting period
    
15. Wait 3 days (INITIAL_ADMIN_DELAY)
    → During this time, deployer still has admin control
    → Monitor for any issues requiring immediate action
    
16. From timelock (via multisig proposal): 
    Call arcadeCore.acceptDefaultAdminTransfer()
    → Timelock is now the admin
    
17. Transfer GameRegistry ownership to timelock:
    Call gameRegistry.transferOwnership(timelockAddress)
    Call gameRegistry.acceptOwnership() from timelock
    
18. Verify deployer has NO remaining privileged roles:
    - arcadeCore.hasRole(DEFAULT_ADMIN_ROLE, deployer) == false
    - arcadeCore.hasRole(PAUSER_ROLE, deployer) == false  
    - gameRegistry.owner() == timelockAddress
```

### Phase 4: Post-Transfer Verification

```
19. Test timelock-gated operations:
    - Propose a test upgrade (DO NOT execute)
    - Cancel the test upgrade
    - Verify proposeUpgrade works from timelock
    - Verify cancelUpgrade works from timelock
    
20. Grant operational roles via timelock proposals:
    - PAUSER_ROLE to operations multisig (for emergencies)
    - Any game-specific roles as needed
    
21. Document all deployed addresses and role assignments
```

### Deployment Checklist

| Step | Contract/Action | Address/Status | Verified |
|------|-----------------|----------------|----------|
| 1 | DataToken | | [ ] |
| 2 | GhostCore | | [ ] |
| 3 | TimelockController | | [ ] |
| 4 | GameRegistry | | [ ] |
| 5-7 | ArcadeCore (proxy) | | [ ] |
| 10 | HashCrash | | [ ] |
| 14-16 | Admin → Timelock | | [ ] |
| 17 | GameRegistry → Timelock | | [ ] |
| 18 | Deployer revoked | | [ ] |

### Emergency Contacts

Before deployment, document:
- Primary multisig address: `____________`
- Backup multisig address: `____________`
- Security team contact: `____________`
- Incident response runbook location: `____________`

---

*This document should be updated as implementation progresses and decisions are finalized.*
