# Randomness and Provably Fair Systems

## Infrastructure Document for GHOSTNET Arcade

**Version:** 2.0  
**Last Updated:** January 2026  
**Chain:** MegaETH  
**Solidity:** 0.8.33  

---

## Table of Contents

1. [Overview](#1-overview)
2. [MegaETH Randomness Constraints](#2-megaeth-randomness-constraints)
3. [Future Block Hash Pattern](#3-future-block-hash-pattern)
4. [Commit-Reveal Pattern](#4-commit-reveal-pattern)
5. [Multi-Component Seed](#5-multi-component-seed)
6. [Per-Game Implementations](#6-per-game-implementations)
7. [Verification UI](#7-verification-ui)
8. [Security Considerations](#8-security-considerations)

---

## 1. Overview

### Why Provable Fairness Matters

On-chain gambling games face a fundamental trust problem: players must believe the house isn't cheating. Provably fair systems solve this by making outcomes:

1. **Deterministic** — Given the same inputs, anyone can verify the same outputs
2. **Unpredictable** — Seeds cannot be known before bets are placed
3. **Verifiable** — All parameters and algorithms are transparent
4. **Immutable** — Every result is permanently recorded on-chain

### GHOSTNET Arcade Randomness Requirements

| Game | Randomness Need | Stakes | Solution |
|------|-----------------|--------|----------|
| **HASH CRASH** | Crash point determination | High | Future Block Hash |
| **BINARY BET** | Winning bit (0 or 1) | Medium | Commit-Reveal + Block Hash |
| **BOUNTY HUNT** | Target assignment | High | Future Block Hash |
| **ICE BREAKER** | Weak point timing | Low | Multi-Component Seed |

### Core Principle

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROVABLY FAIR PATTERN                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   PLAYERS ACT          SEED DETERMINED        OUTCOME REVEALED   │
│        │                     │                      │            │
│   [Bet/Commit]         [Block Mined]          [Result Computed]  │
│        │                     │                      │            │
│   Can't know seed      Hash captured          Deterministic      │
│                                                                  │
│   ─────────────────>  ─────────────────>  ─────────────────>    │
│        TIME                                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. MegaETH Randomness Constraints

### Block Model

MegaETH has a unique dual-block architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    MegaETH BLOCK MODEL                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Mini Blocks:  [M1][M2][M3]...[M99][M100]  (10ms each)          │
│                         ↓                                        │
│  EVM Block:    [═══════════ B1 ═══════════]  (1 second)         │
│                                                                  │
│  Epochs:       [════════════════════════════]  (~60 seconds)    │
│                         ↓                                        │
│                   prevrandao changes                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Constraints

| Property | MegaETH Behavior | Implication |
|----------|------------------|-------------|
| `block.timestamp` | 1-second resolution | Can't use for sub-second timing |
| `block.prevrandao` | Constant for ~60 seconds | **Cannot use directly** for per-round randomness |
| `blockhash()` | Available for last 256 blocks | ~4 minute window to use |
| EVM block time | 1 second | Fresh entropy every second |
| Chainlink VRF | **Not available** | Must use on-chain solutions |

### The prevrandao Problem

From our testing (see `docs/learnings/001-prevrandao-megaeth.md`):

```
Block 12345: prevrandao = 0xabc123...
Block 12346: prevrandao = 0xabc123... (same!)
Block 12347: prevrandao = 0xabc123... (same!)
... 50+ blocks ...
Block 12398: prevrandao = 0xdef456... (changed after ~60s)
```

**Why this matters:** If prevrandao is predictable for 60 seconds, players could:
1. Observe the current prevrandao
2. Calculate their outcome
3. Choose not to bet if unfavorable

**Solution:** Use **future block hashes** instead of prevrandao.

---

## 3. Future Block Hash Pattern

### The Core Idea

Commit to using a block hash from **N blocks in the future** at the moment betting closes. Since that block doesn't exist yet, no one can predict its hash.

```
BETTING PHASE                    SEED BLOCK              GAME
    │                                │                      │
    │  Players bet                   │  Block mined         │  Use seed
    │  (seed unknown)                │  (hash revealed)     │  (deterministic)
    │────────────────────────────────│──────────────────────│
         Phase duration                   ~5 blocks
```

### Implementation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FutureBlockRandomness
/// @notice Base contract for games using future block hash as randomness source
/// @dev Commit to a future block during betting, use its hash after it's mined
abstract contract FutureBlockRandomness is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════

    /// @notice How many blocks in the future to use for seed
    /// @dev 5 blocks = 5 seconds on MegaETH, enough to prevent prediction
    uint256 public constant SEED_BLOCK_DELAY = 5;

    /// @notice Maximum blocks before blockhash becomes unavailable
    uint256 public constant MAX_BLOCK_AGE = 256;

    // ══════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════

    error SeedBlockNotSet();
    error SeedBlockNotMined();
    error SeedBlockTooOld();
    error SeedBlockHashUnavailable();
    error BettingStillOpen();
    error BettingAlreadyClosed();

    // ══════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════

    event SeedBlockCommitted(uint256 indexed roundId, uint256 seedBlock);
    event SeedRevealed(uint256 indexed roundId, bytes32 blockHash, uint256 seed);

    // ══════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════

    struct RoundSeed {
        uint256 seedBlock;      // Block number to use for seed
        bytes32 blockHash;      // Captured block hash
        uint256 seed;           // Final seed value
        bool committed;         // Whether seed block has been set
        bool revealed;          // Whether seed has been revealed
    }

    mapping(uint256 => RoundSeed) public roundSeeds;

    // ══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Commit to a future block for randomness
    /// @dev Called when betting/registration phase closes
    /// @param roundId The round identifier
    function _commitSeedBlock(uint256 roundId) internal {
        RoundSeed storage rs = roundSeeds[roundId];
        if (rs.committed) revert BettingAlreadyClosed();

        rs.seedBlock = block.number + SEED_BLOCK_DELAY;
        rs.committed = true;

        emit SeedBlockCommitted(roundId, rs.seedBlock);
    }

    /// @notice Reveal the seed from the committed block
    /// @dev Called when seed block has been mined
    /// @param roundId The round identifier
    /// @return seed The final seed value
    function _revealSeed(uint256 roundId) internal returns (uint256 seed) {
        RoundSeed storage rs = roundSeeds[roundId];

        if (!rs.committed) revert SeedBlockNotSet();
        if (rs.revealed) return rs.seed; // Already revealed, return cached
        if (block.number <= rs.seedBlock) revert SeedBlockNotMined();
        if (block.number > rs.seedBlock + MAX_BLOCK_AGE) revert SeedBlockTooOld();

        bytes32 hash = blockhash(rs.seedBlock);
        if (hash == bytes32(0)) revert SeedBlockHashUnavailable();

        // Combine block hash with round-specific data for uniqueness
        seed = uint256(keccak256(abi.encode(
            hash,
            roundId,
            block.timestamp,
            address(this)
        )));

        rs.blockHash = hash;
        rs.seed = seed;
        rs.revealed = true;

        emit SeedRevealed(roundId, hash, seed);
    }

    /// @notice Check if seed is ready to be revealed
    /// @param roundId The round identifier
    function _isSeedReady(uint256 roundId) internal view returns (bool) {
        RoundSeed storage rs = roundSeeds[roundId];
        return rs.committed && 
               block.number > rs.seedBlock && 
               block.number <= rs.seedBlock + MAX_BLOCK_AGE;
    }

    /// @notice Get blocks remaining until seed is available
    /// @param roundId The round identifier
    function _blocksUntilSeed(uint256 roundId) internal view returns (uint256) {
        RoundSeed storage rs = roundSeeds[roundId];
        if (!rs.committed) return type(uint256).max;
        if (block.number >= rs.seedBlock) return 0;
        return rs.seedBlock - block.number;
    }
}
```

### Why This Works

1. **Unpredictable:** Block hash depends on all transactions in that block, their ordering, timing, etc.
2. **Uncommittable:** Players can't change their bets after the seed block is set
3. **Verifiable:** Anyone can check `blockhash(seedBlock)` matches the recorded hash
4. **No External Dependencies:** No oracles, no VRF costs

### Trust Assumption

The MegaETH sequencer could theoretically manipulate block hashes by:
- Reordering transactions
- Including/excluding specific transactions
- Timing block production

**However:**
- MegaETH is in "Frontier" phase with a trusted sequencer
- Manipulation would require collusion with specific players
- Reputation cost >> game stakes for reasonable bet sizes
- This is the same trust model as the rest of MegaETH operations

---

## 4. Commit-Reveal Pattern

### When to Use

Use commit-reveal when **players need to make a choice** that affects the outcome:
- BINARY BET (players choose 0 or 1)
- Any game where player input determines result

### How It Works

```
TIMELINE:
═════════

Phase 1: COMMIT (60 seconds)
┌──────────────────────────────────────────────────────────────┐
│  Player A commits: hash(0, secretA, addressA)                │
│  Player B commits: hash(1, secretB, addressB)                │
│  Player C commits: hash(0, secretC, addressC)                │
│                                                              │
│  No one knows anyone else's actual choice                    │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
Phase 2: LOCK (5 blocks = 5 seconds)
┌──────────────────────────────────────────────────────────────┐
│  No more commits accepted                                    │
│  Waiting for seed block to be mined                          │
│  Block hash captured                                         │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
Phase 3: REVEAL (45 seconds)
┌──────────────────────────────────────────────────────────────┐
│  Player A reveals: (0, secretA) → verified!                  │
│  Player B reveals: (1, secretB) → verified!                  │
│  Player C fails to reveal → forfeited!                       │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
Phase 4: RESOLUTION
┌──────────────────────────────────────────────────────────────┐
│  Block hash determines winner (LSB = 0 or 1)                 │
│  Winners split pot                                           │
│  Forfeited bets burned                                       │
└──────────────────────────────────────────────────────────────┘
```

### Implementation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title CommitRevealBase
/// @notice Base contract for commit-reveal games
abstract contract CommitRevealBase {

    struct Commitment {
        bytes32 hash;
        uint256 amount;
        uint8 revealedValue;    // 255 = not revealed
        bool revealed;
        bool processed;
    }

    mapping(uint256 => mapping(address => Commitment)) public commitments;

    error AlreadyCommitted();
    error NoCommitment();
    error AlreadyRevealed();
    error InvalidReveal();
    error RevealPhaseClosed();

    /// @notice Generate commitment hash
    /// @dev Called off-chain to create commitment
    function generateCommitment(
        uint8 choice,
        bytes32 secret,
        address player
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, secret, player));
    }

    /// @notice Submit a commitment
    function _commit(
        uint256 roundId,
        address player,
        bytes32 commitHash,
        uint256 amount
    ) internal {
        if (commitments[roundId][player].amount > 0) revert AlreadyCommitted();

        commitments[roundId][player] = Commitment({
            hash: commitHash,
            amount: amount,
            revealedValue: 255,
            revealed: false,
            processed: false
        });
    }

    /// @notice Reveal a commitment
    function _reveal(
        uint256 roundId,
        address player,
        uint8 value,
        bytes32 secret
    ) internal returns (uint8) {
        Commitment storage c = commitments[roundId][player];

        if (c.amount == 0) revert NoCommitment();
        if (c.revealed) revert AlreadyRevealed();

        bytes32 expectedHash = keccak256(abi.encodePacked(value, secret, player));
        if (expectedHash != c.hash) revert InvalidReveal();

        c.revealed = true;
        c.revealedValue = value;

        return value;
    }
}
```

---

## 5. Multi-Component Seed

### When to Use

Use multi-component seeds for **low-stakes, high-frequency** randomness:
- ICE BREAKER weak point positions
- Per-attempt variations
- Non-critical timing

### Implementation

```solidity
/// @notice Generate multi-component seed
/// @dev Combines multiple entropy sources
function _generateMultiSeed(
    uint256 nonce,
    address player
) internal view returns (uint256) {
    return uint256(keccak256(abi.encode(
        block.prevrandao,     // Constant for ~60s, but adds some entropy
        block.timestamp,      // 1-second resolution
        block.number,         // Changes every block
        nonce,                // Increments each use
        player,               // Player-specific
        address(this)         // Contract-specific
    )));
}
```

### Why This Is Acceptable for Low Stakes

- Multiple components make prediction harder
- Even if one component is known, others vary
- Economic incentive to manipulate < cost of manipulation
- Timing-based games don't have binary win/lose outcomes

---

## 6. Per-Game Implementations

### HASH CRASH

**Pattern:** Future Block Hash

```solidity
contract HashCrash is FutureBlockRandomness {

    function endBetting(uint256 roundId) external {
        // ... validate betting phase is over ...
        
        // Commit to future block for crash point
        _commitSeedBlock(roundId);
        
        rounds[roundId].state = RoundState.PENDING;
    }

    function startGame(uint256 roundId) external {
        require(_isSeedReady(roundId), "Seed not ready");
        
        uint256 seed = _revealSeed(roundId);
        uint256 crashPoint = _calculateCrashPoint(seed);
        
        rounds[roundId].crashPoint = crashPoint;
        rounds[roundId].state = RoundState.ACTIVE;
        rounds[roundId].startTime = block.timestamp;
    }

    function _calculateCrashPoint(uint256 seed) internal pure returns (uint256) {
        // Convert seed to uniform random in [0, 1) with high precision
        uint256 random = seed % 1e18;
        if (random == 0) random = 1;

        // House edge: 3%
        uint256 houseEdgeBps = 300;
        uint256 bps = 10000;

        // Crash point formula: (10000 - houseEdge) / (10000 - random_scaled)
        uint256 numerator = (bps - houseEdgeBps) * 1e18;
        uint256 denominator = 1e18 - random;

        uint256 crashPoint = numerator / denominator;

        // Minimum crash of 1.00x (100 basis points)
        if (crashPoint < 100) crashPoint = 100;

        return crashPoint;
    }
}
```

### BINARY BET

**Pattern:** Commit-Reveal + Future Block Hash

```solidity
contract BinaryBet is CommitRevealBase, FutureBlockRandomness {

    function commitBet(bytes32 commitHash, uint256 amount) external {
        // ... validate commit phase ...
        _commit(currentRoundId, msg.sender, commitHash, amount);
    }

    function lockRound() external {
        // ... validate commit phase over ...
        _commitSeedBlock(currentRoundId);
        rounds[currentRoundId].phase = Phase.LOCKED;
    }

    function startRevealPhase() external {
        require(_isSeedReady(currentRoundId), "Seed not ready");
        
        uint256 seed = _revealSeed(currentRoundId);
        
        // Winning bit is LSB of seed
        rounds[currentRoundId].winningBit = uint8(seed & 1);
        rounds[currentRoundId].phase = Phase.REVEAL;
        rounds[currentRoundId].revealDeadline = block.timestamp + REVEAL_DURATION;
    }

    function revealBet(uint8 choice, bytes32 secret) external {
        require(choice <= 1, "Invalid choice");
        _reveal(currentRoundId, msg.sender, choice, secret);
    }
}
```

### BOUNTY HUNT

**Pattern:** Future Block Hash (for target assignment)

```solidity
contract BountyHunt is FutureBlockRandomness {

    function startGame(uint256 gameId) external {
        // ... validate registration over, enough players ...
        
        _commitSeedBlock(gameId);
        games[gameId].state = GameState.ASSIGNING;
    }

    function assignTargets(uint256 gameId) external {
        require(_isSeedReady(gameId), "Seed not ready");
        
        uint256 seed = _revealSeed(gameId);
        
        // Fisher-Yates shuffle using seed
        address[] memory players = games[gameId].players;
        uint256 n = players.length;

        for (uint256 i = n - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encode(seed, i))) % (i + 1);
            (players[i], players[j]) = (players[j], players[i]);
        }

        // Assign circular chain: each player hunts the next
        for (uint256 i = 0; i < n; i++) {
            address hunter = players[i];
            address target = players[(i + 1) % n];
            games[gameId].targets[hunter] = target;
            games[gameId].huntedBy[target] = hunter;
        }

        games[gameId].state = GameState.ACTIVE;
    }
}
```

### ICE BREAKER

**Pattern:** Multi-Component Seed

```solidity
contract IceBreaker {
    
    uint256 private _attemptNonce;

    function _generateWeakPoints(
        address player,
        uint256 layer
    ) internal returns (uint256[] memory) {
        uint256 seed = uint256(keccak256(abi.encode(
            block.prevrandao,
            block.timestamp,
            block.number,
            _attemptNonce++,
            player,
            layer
        )));

        // Generate weak point positions from seed
        uint256[] memory points = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            points[i] = seed % 100; // Position 0-99
        }

        return points;
    }
}
```

---

## 7. Verification UI

### Verification Component

```svelte
<!-- FairnessVerification.svelte -->
<script lang="ts">
  import { keccak256, toHex, encodeAbiParameters } from 'viem';

  interface Props {
    roundId: number;
    seedBlock: number;
    blockHash: string;
    seed: string;
    outcome: string;
  }

  let { roundId, seedBlock, blockHash, seed, outcome }: Props = $props();

  // Verify the seed was computed correctly
  let computedSeed = $derived(() => {
    if (!blockHash) return null;
    
    const encoded = encodeAbiParameters(
      [
        { type: 'bytes32' },
        { type: 'uint256' },
        { type: 'uint256' },
        { type: 'address' }
      ],
      [blockHash as `0x${string}`, BigInt(roundId), Date.now(), CONTRACT_ADDRESS]
    );
    
    return keccak256(encoded);
  });

  let isVerified = $derived(
    computedSeed && computedSeed.toLowerCase() === seed.toLowerCase()
  );
</script>

<div class="verification-panel">
  <div class="header">PROVENANCE CHAIN</div>
  
  <div class="chain">
    <div class="step">
      <span class="label">SEED BLOCK</span>
      <span class="value">#{seedBlock}</span>
    </div>
    
    <div class="arrow">→</div>
    
    <div class="step">
      <span class="label">BLOCK HASH</span>
      <span class="value hash">{blockHash?.slice(0, 18)}...</span>
    </div>
    
    <div class="arrow">→</div>
    
    <div class="step">
      <span class="label">SEED</span>
      <span class="value hash">{seed?.slice(0, 18)}...</span>
    </div>
    
    <div class="arrow">→</div>
    
    <div class="step">
      <span class="label">OUTCOME</span>
      <span class="value">{outcome}</span>
    </div>
  </div>

  <div class="verification-status" class:verified={isVerified}>
    {#if isVerified}
      ✓ VERIFIED - Seed matches block hash
    {:else}
      ⏳ Verification pending...
    {/if}
  </div>

  <div class="verify-yourself">
    <p>Verify yourself:</p>
    <code>
      cast block {seedBlock} --rpc-url $MEGAETH_RPC | grep hash
    </code>
  </div>
</div>

<style>
  .verification-panel {
    font-family: 'IBM Plex Mono', monospace;
    background: var(--bg-terminal);
    border: 1px solid var(--color-primary);
    padding: 1rem;
  }

  .chain {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .step {
    display: flex;
    flex-direction: column;
    padding: 0.5rem;
    border: 1px solid var(--color-muted);
  }

  .label {
    font-size: 0.75rem;
    color: var(--color-muted);
  }

  .value {
    color: var(--color-primary);
  }

  .hash {
    font-size: 0.875rem;
  }

  .verification-status {
    margin-top: 1rem;
    padding: 0.5rem;
    background: rgba(255, 0, 0, 0.1);
    color: var(--color-danger);
  }

  .verification-status.verified {
    background: rgba(0, 255, 0, 0.1);
    color: var(--color-success);
  }

  .verify-yourself {
    margin-top: 1rem;
    font-size: 0.875rem;
  }

  .verify-yourself code {
    display: block;
    background: var(--bg-code);
    padding: 0.5rem;
    margin-top: 0.5rem;
  }
</style>
```

---

## 8. Security Considerations

### Sequencer Trust

MegaETH uses a single sequencer (during Frontier phase). This means:

| Risk | Mitigation |
|------|------------|
| Sequencer sees transactions first | Use future blocks (5+ blocks ahead) |
| Sequencer controls block ordering | Economic cost > manipulation benefit |
| Sequencer could collude | Reputation risk, legal liability |

**Acceptable for:** Games with stakes < $10,000 per round

**Not acceptable for:** High-stakes tournaments, jackpots > $100,000

### Block Hash Limitations

```
blockhash(N) is only available for:
- block.number - 256 < N < block.number

After 256 blocks (~4 minutes on MegaETH), blockhash returns 0
```

**Mitigation:** Always reveal seed within 200 blocks of seed block commit.

### Front-Running Prevention

| Attack | Prevention |
|--------|------------|
| See outcome, then bet | Future block hash (seed unknown during betting) |
| See others' choices | Commit-reveal (choices hidden until reveal) |
| Abort if losing | Forfeit on non-reveal (100% burn) |

### Replay Attacks

```solidity
// Bad: Same seed gives same result
uint256 seed = blockhash(block.number - 1);

// Good: Include unique identifiers
uint256 seed = uint256(keccak256(abi.encode(
    blockhash(seedBlock),
    roundId,           // Unique per round
    address(this)      // Unique per contract
)));
```

### Economic Security

For any game, ensure:

```
Cost to manipulate > Expected profit from manipulation

Where:
- Cost to manipulate ≈ sequencer reputation + legal risk + opportunity cost
- Expected profit = (stake * edge) * probability of success
```

---

## Appendix A: Quick Reference

### Choosing a Pattern

```
Is player choice involved?
├── YES → Use Commit-Reveal + Future Block Hash
└── NO
    ├── High stakes (>100 $DATA)? → Use Future Block Hash
    └── Low stakes, high frequency? → Use Multi-Component Seed
```

### MegaETH-Specific Constants

```solidity
// Block timing
uint256 constant BLOCK_TIME = 1 seconds;        // EVM blocks
uint256 constant PREVRANDAO_EPOCH = 60 seconds; // When prevrandao changes

// Safe delays
uint256 constant SEED_BLOCK_DELAY = 5;          // 5 seconds
uint256 constant MAX_BLOCK_AGE = 256;           // ~4 minutes
```

### Verification Checklist

- [ ] Seed block committed BEFORE betting closes
- [ ] Seed block is in the future (block.number + N)
- [ ] Block hash captured within 256 blocks
- [ ] Seed includes round-specific data (no replay)
- [ ] Outcome deterministically computed from seed
- [ ] All parameters logged for verification
