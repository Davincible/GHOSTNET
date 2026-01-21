# ArcadeCore Session Tracking: Security Architecture

**Version:** 1.0  
**Created:** 2026-01-21  
**Status:** SPECIFICATION  
**Related Issues:** Critical #1 (Unbounded Emergency Refund), Critical #3 (Missing Session Payout Tracking)

---

## Executive Summary

This document specifies the session tracking system for ArcadeCore that prevents:
1. Unauthorized emergency refunds (drain attack via compromised game)
2. Unbounded payouts exceeding session prize pools
3. Double-settlement of sessions
4. Refunds exceeding actual player deposits

The core principle: **ArcadeCore must independently verify all financial operations against its own session records**, never trusting game contracts with unbounded authority.

---

## Threat Model

### Attack Vectors Addressed

| Vector | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| Rogue Game Drain | Compromised game calls `emergencyRefund(attacker, MAX_UINT)` | Critical | Session-bound refunds with deposit tracking |
| Phantom Payout | Game credits payout for non-existent session | Critical | Session existence and ownership validation |
| Overbilling | Game claims payout exceeding session's prize pool | Critical | Cumulative payout tracking per session |
| Double Settlement | Game settles same session twice | High | State machine with terminal states |
| Cross-Game Theft | Game A tries to refund from Game B's session | High | Game-to-session binding |

### Trust Boundaries

```
TRUSTED                          SEMI-TRUSTED                    UNTRUSTED
────────────────────────────────────────────────────────────────────────────
ArcadeCore                       Registered Games                External Calls
- Token custody                  - Can create sessions           - Player inputs
- Session state machine          - Can request settlements       - Block data
- Invariant enforcement          - CANNOT exceed deposits
                                 - CANNOT cross boundaries
```

---

## Data Structures

### Core Session Record

```solidity
/// @notice Session state machine states
enum SessionState {
    NONE,           // 0 - Default, session doesn't exist
    ACTIVE,         // 1 - Session created, accepting activity
    SETTLED,        // 2 - Terminal: Payouts completed
    CANCELLED       // 3 - Terminal: Refunds issued
}

/// @notice Core session tracking record stored in ArcadeCore
/// @dev One record per session, created on first processEntry() call
struct SessionRecord {
    address game;           // Game contract that owns this session
    uint256 prizePool;      // Total tokens available for payouts
    uint256 totalPaid;      // Cumulative payouts issued (invariant: totalPaid <= prizePool)
    SessionState state;     // Current state (state machine)
    uint64 createdAt;       // Block timestamp of creation
    uint64 settledAt;       // Block timestamp of settlement (0 if not settled)
}

/// @notice Player deposit tracking within a session
/// @dev Separate mapping due to Solidity struct limitations
/// @dev Key: keccak256(abi.encodePacked(sessionId, player))
mapping(bytes32 => uint256) public sessionDeposits;

/// @notice Helper to compute deposit key
function _depositKey(uint256 sessionId, address player) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(sessionId, player));
}
```

### Storage Layout

```solidity
/// @custom:storage-location erc7201:ghostnet.arcade.core
struct ArcadeCoreStorage {
    // ... existing fields ...
    
    // === SESSION TRACKING (NEW) ===
    
    /// @notice Session records by ID
    mapping(uint256 => SessionRecord) sessions;
    
    /// @notice Player deposits per session
    /// @dev Key: keccak256(sessionId, player) => deposit amount
    mapping(bytes32 => uint256) sessionDeposits;
    
    /// @notice Active sessions per game (for emergency cancellation)
    /// @dev game address => array of active session IDs
    mapping(address => uint256[]) gameActiveSessions;
    
    /// @notice Index tracking for O(1) removal from gameActiveSessions
    /// @dev sessionId => index in gameActiveSessions array
    mapping(uint256 => uint256) sessionIndex;
}
```

### Design Rationale

**Why separate `sessionDeposits` mapping?**
- Solidity doesn't allow mappings inside structs to be returned or copied
- Separate mapping with composite key provides O(1) lookup
- Key collision is cryptographically impossible with keccak256

**Why `gameActiveSessions` array?**
- Enables emergency cancellation of all sessions for a compromised game
- Index mapping allows O(1) removal without array shifting

---

## Function Specifications

### Modified: `processEntry()`

Creates or updates session records when players enter games.

```solidity
/// @notice Process entry fee for a game session
/// @param player Address of the player
/// @param amount Entry fee amount
/// @param sessionId Game-provided session ID (game tracks its own sessions)
/// @return netAmount Amount after rake (for prize pool)
/// @dev SECURITY: Creates session record if new, tracks player deposit
function processEntry(
    address player,
    uint256 amount,
    uint256 sessionId
) external nonReentrant whenNotPaused returns (uint256 netAmount);
```

**Implementation Logic:**

```solidity
function processEntry(
    address player,
    uint256 amount,
    uint256 sessionId
) external nonReentrant whenNotPaused returns (uint256 netAmount) {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Verify caller is registered game
    if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
    if ($.gameRegistry.isGamePaused(msg.sender)) revert GamePaused();
    
    // 2. Get or create session record
    SessionRecord storage session = $.sessions[sessionId];
    
    if (session.state == SessionState.NONE) {
        // New session - initialize
        session.game = msg.sender;
        session.state = SessionState.ACTIVE;
        session.createdAt = uint64(block.timestamp);
        
        // Track active session for game
        $.sessionIndex[sessionId] = $.gameActiveSessions[msg.sender].length;
        $.gameActiveSessions[msg.sender].push(sessionId);
    } else {
        // Existing session - verify ownership and state
        if (session.game != msg.sender) revert SessionGameMismatch();
        if (session.state != SessionState.ACTIVE) revert SessionNotActive();
    }
    
    // 3. Validate entry amount
    EntryConfig memory config = $.gameRegistry.getEntryConfig(msg.sender);
    if (amount < config.minEntry) revert InvalidEntryAmount();
    if (config.maxEntry > 0 && amount > config.maxEntry) revert InvalidEntryAmount();
    
    // 4. Check position requirement
    if (config.requiresPosition && !$.ghostCore.isAlive(player)) {
        revert PositionRequired();
    }
    
    // 5. Rate limiting
    PlayerStats storage stats = $.playerStats[player];
    if (block.timestamp < stats.lastPlayTime + MIN_PLAY_INTERVAL) {
        revert RateLimited();
    }
    
    // 6. Transfer tokens from player
    $.dataToken.safeTransferFrom(player, address(this), amount);
    
    // 7. Calculate and transfer rake
    uint256 rakeAmount = (amount * config.rakeBps) / BPS;
    netAmount = amount - rakeAmount;
    
    if (rakeAmount > 0) {
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
    
    // 8. Track deposit and update prize pool
    bytes32 depositKey = _depositKey(sessionId, player);
    $.sessionDeposits[depositKey] += netAmount;
    session.prizePool += netAmount;
    
    // 9. Update player stats
    stats.totalGamesPlayed++;
    stats.totalWagered += uint128(amount / AMOUNT_SCALE);
    stats.lastPlayTime = uint64(block.timestamp);
    $.totalGamesPlayed++;
    $.totalVolume += amount;
    
    emit EntryProcessed(msg.sender, player, sessionId, amount, netAmount, rakeAmount);
}
```

### Modified: `creditPayout()`

Validates payouts against session records.

```solidity
/// @notice Credit payout to player with session validation
/// @param sessionId Session this payout belongs to
/// @param player Address of the player
/// @param amount Payout amount
/// @param burnAmount Amount to burn from prize pool
/// @param won Whether player won
/// @dev SECURITY: Validates session exists, owned by caller, and payout within bounds
function creditPayout(
    uint256 sessionId,
    address player,
    uint256 amount,
    uint256 burnAmount,
    bool won
) external nonReentrant;
```

**Implementation Logic:**

```solidity
function creditPayout(
    uint256 sessionId,
    address player,
    uint256 amount,
    uint256 burnAmount,
    bool won
) external nonReentrant {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Verify caller is registered game
    if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
    
    // 2. Validate session
    SessionRecord storage session = $.sessions[sessionId];
    if (session.state == SessionState.NONE) revert SessionNotFound();
    if (session.game != msg.sender) revert SessionGameMismatch();
    if (session.state != SessionState.ACTIVE) revert SessionNotActive();
    
    // 3. Validate payout within prize pool bounds
    uint256 totalDisbursement = amount + burnAmount;
    if (session.totalPaid + totalDisbursement > session.prizePool) {
        revert PayoutExceedsPrizePool();
    }
    
    // 4. Update session totals
    session.totalPaid += totalDisbursement;
    
    // 5. Execute burn
    if (burnAmount > 0) {
        $.dataToken.safeTransfer(DEAD_ADDRESS, burnAmount);
        $.totalBurned += burnAmount;
    }
    
    // 6. Credit payout (pull pattern)
    if (amount > 0) {
        $.pendingPayouts[player] += amount;
        $.totalPendingPayouts += amount;
        emit PayoutCredited(player, amount, $.pendingPayouts[player]);
    }
    
    // 7. Update player stats
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
    
    emit GameSettled(msg.sender, player, sessionId, amount, burnAmount, won);
}
```

### Modified: `emergencyRefund()`

Validates refunds against recorded deposits.

```solidity
/// @notice Emergency refund with session and deposit validation
/// @param sessionId Session to refund from
/// @param player Address to refund
/// @param amount Amount to refund (must not exceed deposit)
/// @dev SECURITY: Verifies caller owns session, amount <= deposit, marks session cancelled
function emergencyRefund(
    uint256 sessionId,
    address player,
    uint256 amount
) external nonReentrant;
```

**Implementation Logic:**

```solidity
function emergencyRefund(
    uint256 sessionId,
    address player,
    uint256 amount
) external nonReentrant {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Verify caller is registered game
    if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
    
    // 2. Validate session ownership
    SessionRecord storage session = $.sessions[sessionId];
    if (session.state == SessionState.NONE) revert SessionNotFound();
    if (session.game != msg.sender) revert SessionGameMismatch();
    
    // 3. Validate session is active (not already settled/cancelled)
    if (session.state != SessionState.ACTIVE) revert SessionNotActive();
    
    // 4. Validate refund against player's deposit
    bytes32 depositKey = _depositKey(sessionId, player);
    uint256 playerDeposit = $.sessionDeposits[depositKey];
    
    if (amount > playerDeposit) revert RefundExceedsDeposit();
    if (amount == 0) revert InvalidRefundAmount();
    
    // 5. Update deposit tracking
    $.sessionDeposits[depositKey] = playerDeposit - amount;
    session.prizePool -= amount;
    
    // 6. Credit refund to player's pending balance (pull pattern)
    $.pendingPayouts[player] += amount;
    $.totalPendingPayouts += amount;
    
    emit EmergencyRefund(msg.sender, player, sessionId, amount);
}
```

### New: `settleSession()`

Marks a session as fully settled, preventing further payouts.

```solidity
/// @notice Mark session as settled, preventing further payouts
/// @param sessionId Session to settle
/// @dev SECURITY: Only owning game can settle, transfers remaining pool to treasury
function settleSession(uint256 sessionId) external nonReentrant;
```

**Implementation Logic:**

```solidity
function settleSession(uint256 sessionId) external nonReentrant {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Verify caller is registered game
    if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
    
    // 2. Validate session ownership
    SessionRecord storage session = $.sessions[sessionId];
    if (session.state == SessionState.NONE) revert SessionNotFound();
    if (session.game != msg.sender) revert SessionGameMismatch();
    if (session.state != SessionState.ACTIVE) revert SessionNotActive();
    
    // 3. Mark as settled
    session.state = SessionState.SETTLED;
    session.settledAt = uint64(block.timestamp);
    
    // 4. Handle remaining prize pool (unclaimed portion)
    uint256 remaining = session.prizePool - session.totalPaid;
    if (remaining > 0) {
        // Option A: Send to treasury (house edge)
        $.dataToken.safeTransfer($.treasury, remaining);
        // Option B: Burn (deflationary) - alternative
        // $.dataToken.safeTransfer(DEAD_ADDRESS, remaining);
    }
    
    // 5. Remove from active sessions tracking
    _removeActiveSession(msg.sender, sessionId);
    
    emit SessionSettled(msg.sender, sessionId, session.totalPaid, remaining);
}
```

### New: `cancelSession()`

Cancels a session and allows batch refunds.

```solidity
/// @notice Cancel session and mark for refunds
/// @param sessionId Session to cancel
/// @dev SECURITY: Only owning game can cancel, changes state to CANCELLED
function cancelSession(uint256 sessionId) external nonReentrant;
```

**Implementation Logic:**

```solidity
function cancelSession(uint256 sessionId) external nonReentrant {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Verify caller is registered game
    if (!$.gameRegistry.isGameRegistered(msg.sender)) revert GameNotRegistered();
    
    // 2. Validate session ownership
    SessionRecord storage session = $.sessions[sessionId];
    if (session.state == SessionState.NONE) revert SessionNotFound();
    if (session.game != msg.sender) revert SessionGameMismatch();
    if (session.state != SessionState.ACTIVE) revert SessionNotActive();
    
    // 3. Mark as cancelled (allows refunds, blocks payouts)
    session.state = SessionState.CANCELLED;
    session.settledAt = uint64(block.timestamp);
    
    // 4. Remove from active sessions tracking
    _removeActiveSession(msg.sender, sessionId);
    
    emit SessionCancelled(msg.sender, sessionId, session.prizePool);
}
```

### New: Admin Emergency Functions

```solidity
/// @notice Admin can pause a compromised game and cancel all its sessions
/// @param game Game address to quarantine
/// @dev Only DEFAULT_ADMIN_ROLE, use with extreme caution
function emergencyQuarantineGame(address game) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ArcadeCoreStorage storage $ = _getStorage();
    
    // 1. Pause game in registry
    $.gameRegistry.pauseGame(game);
    
    // 2. Get all active sessions for this game
    uint256[] storage activeSessions = $.gameActiveSessions[game];
    
    // 3. Cancel all sessions (state only, refunds handled separately)
    for (uint256 i = 0; i < activeSessions.length; i++) {
        uint256 sessionId = activeSessions[i];
        SessionRecord storage session = $.sessions[sessionId];
        if (session.state == SessionState.ACTIVE) {
            session.state = SessionState.CANCELLED;
            session.settledAt = uint64(block.timestamp);
            emit SessionCancelled(game, sessionId, session.prizePool);
        }
    }
    
    // 4. Clear active sessions array
    delete $.gameActiveSessions[game];
    
    emit GameQuarantined(game, activeSessions.length);
}
```

---

## Security Invariants

These invariants MUST hold at all times. Test with fuzzing and formal verification where possible.

### Invariant 1: Payout Bound

```
For all sessions s:
  s.totalPaid <= s.prizePool
```

**Enforcement:** `creditPayout()` reverts if `totalPaid + disbursement > prizePool`

### Invariant 2: Refund Bound

```
For all sessions s, players p:
  refundAmount <= sessionDeposits[s][p]
```

**Enforcement:** `emergencyRefund()` reverts if `amount > playerDeposit`

### Invariant 3: Game Ownership

```
For all sessions s:
  Only s.game can call creditPayout(s, ...) or emergencyRefund(s, ...)
```

**Enforcement:** Both functions check `session.game == msg.sender`

### Invariant 4: State Machine Finality

```
For all sessions s:
  If s.state == SETTLED || s.state == CANCELLED:
    No payouts or refunds can occur
```

**Enforcement:** Both functions check `session.state == ACTIVE`

### Invariant 5: Deposit Consistency

```
For all sessions s:
  sum(sessionDeposits[s][p] for all p) <= s.prizePool
```

**Enforcement:** `processEntry()` adds to both atomically

### Invariant 6: ArcadeCore Solvency

```
dataToken.balanceOf(arcadeCore) >= totalPendingPayouts + sum(s.prizePool - s.totalPaid for all active s)
```

**Enforcement:** All token movements go through validated paths

---

## Custom Errors

```solidity
// === SESSION ERRORS ===
error SessionNotFound();           // Session ID doesn't exist
error SessionGameMismatch();       // Caller doesn't own this session  
error SessionNotActive();          // Session is SETTLED or CANCELLED
error SessionAlreadyExists();      // Tried to create duplicate session

// === PAYOUT ERRORS ===
error PayoutExceedsPrizePool();    // totalPaid + amount > prizePool
error InvalidPayoutAmount();       // Zero payout not allowed

// === REFUND ERRORS ===
error RefundExceedsDeposit();      // Refund > player's deposit
error InvalidRefundAmount();       // Zero refund not allowed

// === ADMIN ERRORS ===
error GameNotQuarantinable();      // Game has no active sessions
```

---

## Events

```solidity
// === SESSION LIFECYCLE ===
event SessionCreated(
    address indexed game,
    uint256 indexed sessionId,
    uint64 timestamp
);

event SessionSettled(
    address indexed game,
    uint256 indexed sessionId,
    uint256 totalPaid,
    uint256 remaining
);

event SessionCancelled(
    address indexed game,
    uint256 indexed sessionId,
    uint256 prizePool
);

// === EXISTING EVENTS (MODIFIED) ===
event EmergencyRefund(
    address indexed game,
    address indexed player,
    uint256 indexed sessionId,  // Added
    uint256 amount
);

event GameSettled(
    address indexed game,
    address indexed player,
    uint256 indexed sessionId,
    uint256 payout,
    uint256 burned,
    bool won
);

// === ADMIN ===
event GameQuarantined(
    address indexed game,
    uint256 sessionsAffected
);
```

---

## State Diagram

```
                    processEntry()
                         │
                         ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │                         ACTIVE                              │
    │    - Accepts processEntry() for more deposits              │
    │    - Accepts creditPayout() within bounds                   │
    │    - Accepts emergencyRefund() within deposits             │
    │                                                             │
    └────────────────┬───────────────────────┬────────────────────┘
                     │                       │
          settleSession()              cancelSession()
          or all paid out              or emergencyQuarantine
                     │                       │
                     ▼                       ▼
    ┌────────────────────────┐   ┌────────────────────────┐
    │        SETTLED         │   │       CANCELLED        │
    │  - No more payouts     │   │  - No more payouts     │
    │  - No more refunds     │   │  - Allows refunds      │
    │  - Remaining → treasury│   │  - Until pool empty    │
    └────────────────────────┘   └────────────────────────┘
                     │                       │
                     └───────────┬───────────┘
                                 │
                           TERMINAL STATES
                     (no transitions possible)
```

**Note on CANCELLED state:** Players can still claim refunds from a cancelled session until the prize pool is exhausted. This is intentional - we want players to be able to recover funds even after cancellation.

---

## Gas Considerations

### Storage Access Patterns

| Operation | SLOADs | SSTOREs | Notes |
|-----------|--------|---------|-------|
| processEntry (new session) | 4 | 5 | Creates record + deposit |
| processEntry (existing session) | 4 | 3 | Updates existing |
| creditPayout | 3 | 3 | Session + deposit lookup |
| emergencyRefund | 3 | 3 | Similar to payout |
| settleSession | 2 | 2 | Minimal state change |

### Optimization Notes

1. **Composite key for deposits**: Single SLOAD vs nested mapping (2 SLOADs)
2. **Session record packing**: All fields fit in 2 slots
3. **Active sessions array**: Only needed for quarantine (rare admin operation)

---

## Testing Requirements

### Unit Tests

- [ ] `processEntry` creates session on first call
- [ ] `processEntry` updates existing session on subsequent calls
- [ ] `processEntry` rejects if session owned by different game
- [ ] `creditPayout` succeeds within prize pool bounds
- [ ] `creditPayout` reverts at exactly prizePool + 1
- [ ] `creditPayout` reverts for non-existent session
- [ ] `creditPayout` reverts for wrong game
- [ ] `creditPayout` reverts for settled session
- [ ] `emergencyRefund` succeeds within deposit bounds
- [ ] `emergencyRefund` reverts at exactly deposit + 1
- [ ] `emergencyRefund` reverts for wrong game
- [ ] `settleSession` transfers remaining to treasury
- [ ] `cancelSession` allows subsequent refunds

### Fuzz Tests

- [ ] `processEntry` amount fuzzing (deposit tracking)
- [ ] Multiple `creditPayout` calls never exceed prizePool
- [ ] `emergencyRefund` never exceeds cumulative deposits
- [ ] State machine transitions are valid

### Invariant Tests

- [ ] Invariant 1: totalPaid <= prizePool (always)
- [ ] Invariant 6: ArcadeCore solvency (always)

### Integration Tests

- [ ] Full game flow: entries → payouts → settlement
- [ ] Cancellation flow: entries → cancel → refunds
- [ ] Admin quarantine: pause + cancel all sessions

---

## Migration Notes

If upgrading existing ArcadeCore:

1. **Storage compatibility**: New mappings added at end of storage struct
2. **Interface change**: `processEntry` now takes `sessionId` parameter
3. **Games must upgrade**: Pass session ID to `processEntry`
4. **Backward compatibility**: Consider adding wrapper that generates session ID

---

## Changelog

- **v1.0** (2026-01-21): Initial specification addressing Critical Issues #1 and #3
