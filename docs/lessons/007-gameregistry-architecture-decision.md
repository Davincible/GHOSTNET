# Lesson: GameRegistry Architecture Decision

**Date:** 2026-01-22  
**Component:** packages/contracts/src/arcade/GameRegistry.sol

## Problem

The codebase had two competing patterns for game registration:

1. **ArcadeCore built-in**: The existing `ArcadeCore.sol` had game registration functions (registerGame, unregisterGame, pauseGame, etc.) with 501 tests passing.

2. **IGameRegistry interface**: A separate interface existed expecting a standalone `GameRegistry` contract that would manage game metadata and provide features like grace period removal.

## Analysis

### Option A: Refactor ArcadeCore to delegate to GameRegistry
- **Pro**: Single source of truth for game registration
- **Con**: Would require significant changes to ArcadeCore, potentially breaking 501 existing tests
- **Con**: More complex upgrade path

### Option B: Keep ArcadeCore registration + Create GameRegistry for metadata
- **Pro**: Preserves all existing tests
- **Pro**: GameRegistry adds new functionality without breaking changes
- **Con**: Two places manage game state (potential confusion)

## Decision

**Chose Option B**: Create GameRegistry as a coordination layer that:

1. Stores game metadata (GameInfo from IArcadeGame)
2. Provides 7-day grace period for game removal (security feature)
3. Calls through to ArcadeCore for actual registration/unregistration
4. Owns EntryConfig while ArcadeCore owns paused state

## Key Design Points

### Grace Period for Removal
- 7-day delay before games can be removed
- Automatically pauses game when marked for removal
- Allows cancellation during grace period
- Protects players from sudden game removal ("rug pull")

### Coordination with ArcadeCore
```
GameRegistry.registerGame(game, config)
    -> stores GameInfo and EntryConfig
    -> calls arcadeCore.registerGame(game, coreConfig)

GameRegistry.removeGame(game)  [after 7-day grace]
    -> clears local storage
    -> calls arcadeCore.unregisterGame(game)
```

### GameRegistry requires GAME_ADMIN_ROLE in ArcadeCore
- Must be granted after deployment
- Allows GameRegistry to manage games in ArcadeCore

## Implementation Details

**Files created:**
- `packages/contracts/src/arcade/GameRegistry.sol` - 320 lines
- `packages/contracts/test/arcade/GameRegistry.t.sol` - 640 lines

**Test coverage:**
- 40 tests for GameRegistry
- Total suite now 1038 tests (up from 501)

**Key features:**
- Uses OpenZeppelin's Ownable2Step for safe ownership transfer
- Uses EnumerableSet for efficient game tracking
- Validates rake (max 10%) and burn (max 100%) rates
- Handles non-compliant game contracts gracefully

## Verification

```bash
just contracts-test  # 1038 tests passing
just contracts-fmt   # Code formatted
```

## Future Considerations

1. **Migration path**: If we later want GameRegistry as sole source of truth, we can:
   - Add a "readFromRegistry" flag to ArcadeCore
   - Have ArcadeCore call `gameRegistry.isGameRegistered()` instead of its own mapping
   - This would be a non-breaking upgrade

2. **Testnet deployment**: Deploy GameRegistry alongside ArcadeCore and grant it GAME_ADMIN_ROLE

3. **Consider making removal grace period configurable**: Currently hardcoded at 7 days
