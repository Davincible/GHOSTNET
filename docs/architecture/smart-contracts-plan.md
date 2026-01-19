# GHOSTNET Smart Contracts Architecture Plan

**Version:** 0.1 (Preliminary)  
**Date:** January 2026  
**Status:** Planning - Pending prevrandao Verification  
**Network:** MegaETH (Chain ID 6343 testnet, 4326 mainnet)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architectural Decisions](#2-architectural-decisions)
3. [Contract Architecture](#3-contract-architecture)
4. [Contract Specifications](#4-contract-specifications)
5. [Randomness Strategy](#5-randomness-strategy)
6. [Economic Flows](#6-economic-flows)
7. [Upgrade & Governance](#7-upgrade--governance)
8. [External Integrations](#8-external-integrations)
9. [Development Phases](#9-development-phases)
10. [Security Considerations](#10-security-considerations)
11. [Open Questions](#11-open-questions)
12. [Appendix: Session Log](#appendix-session-log)

---

## 1. Executive Summary

GHOSTNET is a real-time survival game on MegaETH requiring smart contracts for:

- **Token economics** - $DATA ERC20 with 10% transfer tax (9% burn, 1% treasury)
- **Core game loop** - Staking positions across 5 risk levels, periodic "trace scans" that kill positions
- **Redistribution** - "The Cascade" - 60/30/10 split of dead capital (rewards/burn/protocol)
- **Prediction market** - "Dead Pool" - Parimutuel betting on scan outcomes
- **Supporting systems** - Fee routing, emissions, consumables

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Randomness** | Block-based (prevrandao) | Zero latency, zero cost, no external deps. VRF not trustless on-chain anyway. |
| **Token** | Immutable | Trust anchor - users need certainty tax rates won't change |
| **Game Logic** | UUPS Upgradeable | Game parameters need tuning, bugs need fixing |
| **Reward Distribution** | Share-based (MasterChef pattern) | O(1) gas regardless of participant count |
| **Mini-game Boosts** | Server signatures | Games are off-chain, server validates and signs boost claims |

### Critical Dependency

**`prevrandao` verification on MegaETH** - Must confirm this opcode returns usable randomness on MegaETH before finalizing randomness strategy. Test contract and verification plan included below.

---

## 2. Architectural Decisions

### 2.1 Randomness: Block-Based vs VRF

**Decision: Block-based randomness using `prevrandao`**

**Analysis:**

| Factor | Block-Based | Gelato VRF |
|--------|-------------|------------|
| On-chain trustless | No (trust sequencer) | No (trust Gelato operator) |
| Off-chain verifiable | No | Yes (Drand signatures) |
| Latency | **0ms** | ~1500ms |
| Cost per scan | **$0** | Gas + 10-30% premium |
| External dependency | **None** | Gelato service |
| MegaETH support | Native | Not confirmed for mainnet |
| Complexity | **Minimal** | Moderate |

**Key insight:** Gelato VRF is NOT on-chain verifiable either (BLS12-381 proofs can't be verified on-chain until EIP-2537). Both options require trusting a reputable party.

**Risk assessment:** MegaETH sequencer manipulation is theoretical, not practical. The sequencer (MegaETH Labs) has vastly more at stake in reputation than any GHOSTNET position value.

**Fallback:** If `prevrandao` doesn't work on MegaETH, implement commit-reveal pattern.

### 2.2 Token Upgradeability

**Decision: Immutable token contract**

**Rationale:**
- Token is the primary "trust anchor" - promise that "we can't rug"
- Tax rates (9% burn, 1% treasury) should be permanent commitments
- Users need certainty these parameters won't change
- Game contracts can be whitelisted/de-whitelisted for tax exemption

**Trade-off accepted:** If we get tax rates wrong, we're stuck. Mitigation: extensive modeling before launch.

### 2.3 Game Logic Upgradeability

**Decision: UUPS Proxy pattern with Timelock**

**Rationale:**
- Game parameters WILL need tuning (death rates, intervals, multipliers)
- Bugs will be discovered
- MegaETH is new - may need platform-specific adaptations
- Users protected by timelock (48-hour delay on upgrades)

**Pattern:**
```
User → Proxy → Implementation (upgradeable)
                    ↓
             ProxyAdmin → Timelock (48h) → Multisig (3-of-5)
```

### 2.4 Reward Distribution

**Decision: Share-based accounting (MasterChef pattern)**

**Rationale:**
- O(1) gas for distribution regardless of participant count
- Battle-tested in Sushi, Uniswap staking, etc.
- Rewards accrue automatically, claimed on extract
- No iteration over positions during cascade

**Pattern:**
```solidity
struct LevelState {
    uint256 totalStaked;
    uint256 accRewardsPerShare; // Scaled by 1e18
}

// On cascade distribution:
levels[level].accRewardsPerShare += (rewardAmount * 1e18) / levels[level].totalStaked;

// On extract:
pending = position.amount * accRewardsPerShare / 1e18 - position.rewardDebt;
```

### 2.5 Mini-Game Integration

**Decision: Off-chain games with server-signed boost claims**

**Rationale:**
- Typing games, hack runs happen in browser - can't be on-chain
- Server validates gameplay, signs boost approval
- Contract verifies signature, applies boost
- Simple, gas-efficient, appropriate trust model for entertainment

**Pattern:**
```solidity
function applyBoost(
    uint256 positionId,
    uint8 boostType,
    uint16 boostBps,    // e.g., 1500 = -15% death rate
    uint256 expiry,
    bytes calldata signature
) external {
    bytes32 hash = keccak256(abi.encode(msg.sender, positionId, boostType, boostBps, expiry));
    require(ECDSA.recover(hash, signature) == boostSigner, "Invalid signature");
    // Apply boost...
}
```

---

## 3. Contract Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GHOSTNET CONTRACT ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ══════════════════════════════════════════════════════════════════════════ │
│  LAYER 1: IMMUTABLE CORE (Trust Anchors - Cannot be upgraded)               │
│  ══════════════════════════════════════════════════════════════════════════ │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │    DataToken       │  │    TeamVesting     │  │    LPBurner        │    │
│  │    ────────────    │  │    ──────────      │  │    ────────        │    │
│  │ • ERC20 + 10% tax  │  │ • 8% supply        │  │ • Burns LP on      │    │
│  │ • 9% → burn        │  │ • 1mo cliff        │  │   deployment       │    │
│  │ • 1% → treasury    │  │ • 24mo linear      │  │ • Irreversible     │    │
│  │ • Game whitelist   │  │ • Immutable        │  │                    │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ══════════════════════════════════════════════════════════════════════════ │
│  LAYER 2: UPGRADEABLE GAME LOGIC (UUPS + 48h Timelock + 3/5 Multisig)      │
│  ══════════════════════════════════════════════════════════════════════════ │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                           GhostCore.sol                               │  │
│  │  ────────────────────────────────────────────────────────────────────│  │
│  │  • Position management (jackIn, extract)                              │  │
│  │  • Level configurations (5 levels: Vault → Black Ice)                 │  │
│  │  • System reset timer                                                 │  │
│  │  • Cascade distribution (share-based)                                 │  │
│  │  • Boost application (from signed messages)                           │  │
│  │  • Emergency pause + withdrawal                                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          TraceScan.sol                                │  │
│  │  ────────────────────────────────────────────────────────────────────│  │
│  │  • Randomness generation (prevrandao-based)                           │  │
│  │  • Death selection algorithm                                          │  │
│  │  • Scan scheduling and execution                                      │  │
│  │  • Keeper interface (Gelato Automate compatible)                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          DeadPool.sol                                 │  │
│  │  ────────────────────────────────────────────────────────────────────│  │
│  │  • Parimutuel betting pools                                           │  │
│  │  • Round creation (death count, whale death, etc.)                    │  │
│  │  • Resolution from TraceScan outcomes                                 │  │
│  │  • 5% rake → burn                                                     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ══════════════════════════════════════════════════════════════════════════ │
│  LAYER 3: PERIPHERAL (Fully Replaceable)                                    │
│  ══════════════════════════════════════════════════════════════════════════ │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │    FeeRouter       │  │ RewardsDistributor │  │  ConsumablesShop   │    │
│  │    ─────────       │  │ ────────────────── │  │  ───────────────   │    │
│  │ • $2 ETH toll      │  │ • 60M DATA emissions│ │ • Black Market     │    │
│  │ • 90% → buyback    │  │ • ~82k/day over 24mo│ │ • Stimpacks, EMPs  │    │
│  │ • 10% → operations │  │ • Level weighting   │  │ • All burns        │    │
│  │ • Bronto/Bebop DEX │  │                    │  │                    │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ══════════════════════════════════════════════════════════════════════════ │
│  GOVERNANCE                                                                  │
│  ══════════════════════════════════════════════════════════════════════════ │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐                            │
│  │  TimelockController │  │    GnosisSafe      │                            │
│  │  ──────────────────│  │    ──────────      │                            │
│  │ • 48-hour delay    │  │ • 3-of-5 signers   │                            │
│  │ • Upgrade proposals │  │ • Team multisig    │                            │
│  └────────────────────┘  └────────────────────┘                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
packages/contracts/src/
├── token/
│   ├── DataToken.sol              # Immutable ERC20 + tax
│   ├── TeamVesting.sol            # Team token vesting
│   └── interfaces/
│       └── IDataToken.sol
│
├── core/
│   ├── GhostCore.sol              # Main game logic (UUPS)
│   ├── GhostCoreStorage.sol       # Storage layout for upgrades
│   ├── TraceScan.sol              # Randomness + death selection (UUPS)
│   ├── TraceScanStorage.sol       # Storage layout
│   └── interfaces/
│       ├── IGhostCore.sol
│       └── ITraceScan.sol
│
├── markets/
│   ├── DeadPool.sol               # Prediction market (UUPS)
│   ├── DeadPoolStorage.sol        # Storage layout
│   └── interfaces/
│       └── IDeadPool.sol
│
├── periphery/
│   ├── FeeRouter.sol              # ETH toll + buyback
│   ├── RewardsDistributor.sol     # Emission distribution
│   └── ConsumablesShop.sol        # Black market items
│
├── governance/
│   └── GhostTimelock.sol          # OpenZeppelin TimelockController
│
├── libraries/
│   ├── DeathMath.sol              # Death rate calculations
│   ├── CascadeLib.sol             # Reward distribution math
│   └── PositionLib.sol            # Position utilities
│
└── test/
    └── PrevRandaoTest.sol         # MegaETH randomness verification
```

---

## 4. Contract Specifications

### 4.1 DataToken.sol

```
┌─────────────────────────────────────────────────────────────────────┐
│ CONTRACT: DataToken                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Type:        ERC20 with Transfer Tax                                │
│ Upgradeable: NO (immutable)                                         │
│ Inherits:    ERC20, Ownable2Step                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ CONSTANTS:                                                           │
│ ├── TOTAL_SUPPLY:     100,000,000 * 10^18                           │
│ ├── TAX_RATE:         1000 (10% in basis points)                    │
│ ├── BURN_SHARE:       9000 (90% of tax → burn)                      │
│ └── TREASURY_SHARE:   1000 (10% of tax → treasury)                  │
│                                                                      │
│ STATE:                                                               │
│ ├── treasury:         address (receives 1% of transfers)            │
│ ├── isExcludedFromTax: mapping(address => bool)                     │
│ └── owner:            address (can update exclusions)               │
│                                                                      │
│ FUNCTIONS:                                                           │
│ ├── constructor(treasury, initialDistribution[])                    │
│ ├── _update() override - applies tax on non-excluded transfers      │
│ ├── setTaxExclusion(address, bool) - onlyOwner                      │
│ ├── burn(uint256) - public, burn own tokens                         │
│ └── renounceOwnership() - lock contract permanently                 │
│                                                                      │
│ INITIAL DISTRIBUTION:                                                │
│ ├── 60% (60M) → RewardsDistributor (The Mine)                       │
│ ├── 15% (15M) → Presale participants                                │
│ ├── 9%  (9M)  → Liquidity (to be burned)                            │
│ ├── 8%  (8M)  → TeamVesting contract                                │
│ └── 8%  (8M)  → Treasury                                            │
│                                                                      │
│ TAX LOGIC:                                                           │
│ ├── If sender OR recipient is excluded → no tax                     │
│ ├── Otherwise: 10% tax                                              │
│ │   ├── 9% sent to address(0xdead) [burn]                           │
│ │   └── 1% sent to treasury                                         │
│ └── Game contracts are excluded (internal transfers tax-free)       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 GhostCore.sol

```
┌─────────────────────────────────────────────────────────────────────┐
│ CONTRACT: GhostCore                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Type:        Core Game Logic                                        │
│ Upgradeable: YES (UUPS)                                             │
│ Inherits:    UUPSUpgradeable, ReentrancyGuardUpgradeable,          │
│              PausableUpgradeable, AccessControlUpgradeable          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ ROLES:                                                               │
│ ├── DEFAULT_ADMIN_ROLE  - Timelock (upgrade, pause)                 │
│ ├── SCANNER_ROLE        - TraceScan contract (process deaths)       │
│ └── BOOST_SIGNER_ROLE   - Backend signer (boost verification)       │
│                                                                      │
│ STRUCTS:                                                             │
│                                                                      │
│ Position {                                                           │
│   uint256 amount;           // Staked DATA                          │
│   uint8   level;            // 1-5 (Vault to Black Ice)             │
│   uint64  timestamp;        // When jacked in                       │
│   uint256 rewardDebt;       // For share-based accounting           │
│   bool    alive;            // false = traced                       │
│   Boost[] activeBoosts;     // From mini-games                      │
│ }                                                                    │
│                                                                      │
│ LevelConfig {                                                        │
│   uint16  baseDeathRateBps; // e.g., 4000 = 40%                     │
│   uint32  scanInterval;     // Seconds between scans                │
│   uint256 minStake;         // Minimum to jack in                   │
│   uint256 totalStaked;      // Sum of all positions                 │
│   uint256 accRewardsPerShare; // For cascade distribution           │
│   uint64  nextScanTime;     // Timestamp of next scan               │
│ }                                                                    │
│                                                                      │
│ Boost {                                                              │
│   uint8   boostType;        // 0=death reduction, 1=yield mult      │
│   uint16  valueBps;         // Basis points (e.g., 1500 = 15%)      │
│   uint64  expiry;           // Timestamp when boost expires         │
│ }                                                                    │
│                                                                      │
│ STATE:                                                               │
│ ├── dataToken:        IDataToken                                    │
│ ├── positions:        mapping(address => Position[])                │
│ ├── levels:           mapping(uint8 => LevelConfig)                 │
│ ├── systemResetDeadline: uint256                                    │
│ ├── boostSigner:      address                                       │
│ └── treasury:         address                                       │
│                                                                      │
│ CORE FUNCTIONS:                                                      │
│                                                                      │
│ jackIn(uint256 amount, uint8 level)                                 │
│ ├── Transfers DATA from user (tax-exempt, whitelisted)              │
│ ├── Creates Position with alive=true                                │
│ ├── Updates level.totalStaked                                       │
│ ├── Extends systemResetDeadline based on amount                     │
│ └── Emits JackedIn(user, positionId, amount, level)                 │
│                                                                      │
│ extract(uint256 positionId)                                         │
│ ├── Requires position.alive == true                                 │
│ ├── Calculates pending rewards (share-based)                        │
│ ├── Transfers amount + rewards to user                              │
│ ├── Updates level.totalStaked                                       │
│ └── Emits Extracted(user, positionId, amount, rewards)              │
│                                                                      │
│ processDeaths(uint8 level, address[] deadUsers)                     │
│ ├── onlyRole(SCANNER_ROLE)                                          │
│ ├── For each dead user:                                             │
│ │   ├── Mark position.alive = false                                 │
│ │   ├── Calculate cascade split (60/30/10)                          │
│ │   └── Update level.totalStaked                                    │
│ ├── Distribute 60% via accRewardsPerShare                           │
│ ├── Burn 30%                                                        │
│ ├── Send 10% to treasury                                            │
│ └── Emits TraceScanCompleted(level, deathCount, totalBurned)        │
│                                                                      │
│ applyBoost(positionId, boostType, valueBps, expiry, signature)      │
│ ├── Verifies ECDSA signature from boostSigner                       │
│ ├── Checks expiry > block.timestamp                                 │
│ ├── Adds Boost to position.activeBoosts                             │
│ └── Emits BoostApplied(user, positionId, boostType, valueBps)       │
│                                                                      │
│ VIEW FUNCTIONS:                                                      │
│ ├── getPosition(address, positionId) → Position                     │
│ ├── getPendingRewards(address, positionId) → uint256                │
│ ├── getEffectiveDeathRate(address, positionId) → uint16             │
│ ├── getLevelStats(uint8 level) → LevelConfig                        │
│ └── getSystemResetCountdown() → uint256                             │
│                                                                      │
│ ADMIN FUNCTIONS:                                                     │
│ ├── pause() / unpause() - onlyRole(DEFAULT_ADMIN_ROLE)              │
│ ├── updateLevelConfig() - onlyRole(DEFAULT_ADMIN_ROLE)              │
│ ├── setBoostSigner() - onlyRole(DEFAULT_ADMIN_ROLE)                 │
│ └── emergencyWithdraw() - when paused, users can exit               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.3 TraceScan.sol

```
┌─────────────────────────────────────────────────────────────────────┐
│ CONTRACT: TraceScan                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Type:        Randomness + Death Selection                           │
│ Upgradeable: YES (UUPS)                                             │
│ Inherits:    UUPSUpgradeable, AccessControlUpgradeable              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ ROLES:                                                               │
│ ├── DEFAULT_ADMIN_ROLE  - Timelock                                  │
│ └── KEEPER_ROLE         - Gelato Automate / manual keeper           │
│                                                                      │
│ STATE:                                                               │
│ ├── ghostCore:      IGhostCore                                      │
│ ├── scanNonce:      uint256 (prevents replay)                       │
│ └── lastScanBlock:  mapping(uint8 => uint256)                       │
│                                                                      │
│ FUNCTIONS:                                                           │
│                                                                      │
│ executeScan(uint8 level) external                                   │
│ ├── Anyone can call when timer expired (or KEEPER_ROLE)             │
│ ├── require(block.timestamp >= ghostCore.nextScanTime(level))       │
│ ├── Generate seed from prevrandao + state                           │
│ ├── Iterate positions, determine deaths                             │
│ ├── Call ghostCore.processDeaths(level, deadAddresses)              │
│ └── Emits ScanExecuted(level, seed, deathCount)                     │
│                                                                      │
│ _generateSeed(uint8 level) internal view → uint256                  │
│ └── keccak256(prevrandao, block.timestamp, level, scanNonce)        │
│                                                                      │
│ _selectDeaths(uint8 level, uint256 seed) internal view              │
│ ├── Get all alive positions for level                               │
│ ├── For each position:                                              │
│ │   ├── positionSeed = keccak256(seed, positionIndex)               │
│ │   ├── effectiveDeathRate = baseRate * networkMod * boostMod       │
│ │   └── if (positionSeed % 10000 < effectiveDeathRate) → dead       │
│ └── Return array of dead addresses                                  │
│                                                                      │
│ VIEW FUNCTIONS:                                                      │
│ ├── canExecuteScan(uint8 level) → bool                              │
│ ├── getExpectedDeaths(uint8 level) → uint256 (estimate)             │
│ └── getNetworkModifier() → uint16 (based on TVL)                    │
│                                                                      │
│ KEEPER INTERFACE (Gelato Automate compatible):                       │
│ ├── checker() → (bool canExec, bytes execPayload)                   │
│ └── Returns true + encoded executeScan() when any level ready       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.4 DeadPool.sol

```
┌─────────────────────────────────────────────────────────────────────┐
│ CONTRACT: DeadPool                                                   │
├─────────────────────────────────────────────────────────────────────┤
│ Type:        Parimutuel Prediction Market                           │
│ Upgradeable: YES (UUPS)                                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ STRUCTS:                                                             │
│                                                                      │
│ Round {                                                              │
│   RoundType  roundType;     // DEATH_COUNT, WHALE_DEATH, etc.       │
│   uint8      targetLevel;   // Which level this round targets       │
│   uint256    line;          // Over/under line (e.g., 50 deaths)    │
│   uint256    overPool;      // Total bet on OVER                    │
│   uint256    underPool;     // Total bet on UNDER                   │
│   uint64     deadline;      // Betting closes at                    │
│   uint64     resolveTime;   // When outcome determined              │
│   bool       resolved;      // Has been resolved                    │
│   bool       outcome;       // true=OVER won, false=UNDER won       │
│ }                                                                    │
│                                                                      │
│ Bet {                                                                │
│   uint256 amount;                                                    │
│   bool    isOver;           // true=OVER, false=UNDER               │
│   bool    claimed;                                                   │
│ }                                                                    │
│                                                                      │
│ STATE:                                                               │
│ ├── rounds:         mapping(uint256 => Round)                       │
│ ├── bets:           mapping(uint256 => mapping(address => Bet))     │
│ ├── roundCount:     uint256                                         │
│ ├── rakeBps:        uint16 (500 = 5%)                               │
│ └── dataToken:      IDataToken                                      │
│                                                                      │
│ ROUND TYPES:                                                         │
│ ├── DEATH_COUNT    - Over/under deaths in next scan                 │
│ ├── WHALE_DEATH    - Will a 1000+ DATA position die?                │
│ ├── STREAK_RECORD  - Will anyone hit 20 survival streak?            │
│ └── SYSTEM_RESET   - Will timer hit <1 hour?                        │
│                                                                      │
│ FUNCTIONS:                                                           │
│                                                                      │
│ createRound(type, targetLevel, line, deadline)                      │
│ ├── onlyRole(ROUND_CREATOR_ROLE)                                    │
│ └── Emits RoundCreated(roundId, type, line, deadline)               │
│                                                                      │
│ placeBet(roundId, isOver, amount)                                   │
│ ├── require(block.timestamp < round.deadline)                       │
│ ├── Transfer DATA from user                                         │
│ ├── Add to overPool or underPool                                    │
│ └── Emits BetPlaced(roundId, user, isOver, amount)                  │
│                                                                      │
│ resolveRound(roundId, outcome)                                      │
│ ├── onlyRole(RESOLVER_ROLE) - TraceScan or keeper                   │
│ ├── Calculate rake (5%) → burn                                      │
│ ├── Set round.resolved = true, round.outcome                        │
│ └── Emits RoundResolved(roundId, outcome, totalPot, burned)         │
│                                                                      │
│ claimWinnings(roundId)                                              │
│ ├── require(round.resolved && user bet on winning side)             │
│ ├── Calculate share: (userBet / winningPool) * (totalPot - rake)    │
│ ├── Transfer winnings                                               │
│ └── Emits WinningsClaimed(roundId, user, amount)                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Randomness Strategy

### Primary: Block-Based (prevrandao)

```solidity
function _generateSeed(uint8 level) internal returns (uint256) {
    return uint256(keccak256(abi.encode(
        block.prevrandao,     // RANDAO from L1 or L2 equivalent
        block.timestamp,      // Current block time
        block.number,         // Block height
        level,                // Which level
        _scanNonce++          // Incrementing nonce
    )));
}
```

### Fallback: Commit-Reveal (If prevrandao Fails)

```solidity
// Phase 1: Commit
function commitScan(uint8 level) external {
    require(block.timestamp >= nextScanTime[level], "Too early");
    scanCommitBlock[level] = block.number + 1;
}

// Phase 2: Reveal (after 1 EVM block = 1 second)
function revealScan(uint8 level) external {
    uint256 commitBlock = scanCommitBlock[level];
    require(block.number > commitBlock, "Wait for next block");
    
    uint256 seed = uint256(blockhash(commitBlock));
    _processDeaths(level, seed);
}
```

### Verification Required

**CRITICAL:** Must verify `prevrandao` behavior on MegaETH before finalizing. See Section 11.

---

## 6. Economic Flows

### 6.1 The Cascade (Death Redistribution)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TRACED POSITION: 100 DATA                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 60% → REWARD POOL (60 DATA)                                 │    │
│  │                                                              │    │
│  │ Distribution:                                                │    │
│  │ ├── 50% → Same-level survivors (proportional to stake)      │    │
│  │ └── 50% → Upstream levels (split by TVL weight)             │    │
│  │                                                              │    │
│  │ Implementation: Increment accRewardsPerShare for each level │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 30% → BURN (30 DATA)                                        │    │
│  │                                                              │    │
│  │ Action: dataToken.transfer(address(0xdead), 30 DATA)        │    │
│  │ Result: Permanent supply reduction                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 10% → PROTOCOL (10 DATA)                                    │    │
│  │                                                              │    │
│  │ Action: dataToken.transfer(treasury, 10 DATA)               │    │
│  │ Use: Operations, development, growth                        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Multi-Source Burns

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BURN SOURCES                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SOURCE                           │  MECHANISM                       │
│  ─────────────────────────────────┼─────────────────────────────────│
│  1. Cascade Deaths (30%)          │  Direct burn in GhostCore       │
│  2. Transfer Tax (9%)             │  In DataToken._update()         │
│  3. ETH Toll Buyback (90% of $2)  │  FeeRouter swaps + burns        │
│  4. Dead Pool Rake (5%)           │  DeadPool.resolveRound()        │
│  5. Consumables (100%)            │  ConsumablesShop purchases      │
│                                                                      │
│  BREAK-EVEN ANALYSIS:                                                │
│  ─────────────────────────────────────────────────────────────────  │
│  Daily Emission: ~82,000 DATA (from RewardsDistributor)             │
│  Required Burns: ~82,000 DATA                                        │
│  Estimated Volume for Net Deflation: ~$175,000/day                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. Upgrade & Governance

### Governance Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│                      GOVERNANCE FLOW                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  NORMAL UPGRADE:                                                     │
│  ───────────────                                                    │
│  Team Proposes → Multisig Signs (3/5) → Timelock (48h) → Executes  │
│                                                                      │
│  EMERGENCY PAUSE:                                                    │
│  ────────────────                                                   │
│  Any Admin → Immediate Pause → Users can emergencyWithdraw()        │
│  (Upgrades still require 48h timelock even when paused)             │
│                                                                      │
│  ROLE HIERARCHY:                                                     │
│  ───────────────                                                    │
│  TimelockController (48h)                                           │
│       └── DEFAULT_ADMIN_ROLE for all upgradeable contracts          │
│                                                                      │
│  GnosisSafe (3-of-5)                                                │
│       └── Proposer + Executor roles on Timelock                     │
│                                                                      │
│  WHAT CAN BE CHANGED:                                                │
│  ────────────────────                                               │
│  ✓ Level configurations (death rates, intervals, min stakes)        │
│  ✓ System reset timer parameters                                    │
│  ✓ Boost signer address                                             │
│  ✓ New contract implementations (upgrades)                          │
│  ✓ Adding new features (new periphery contracts)                    │
│                                                                      │
│  WHAT CANNOT BE CHANGED:                                             │
│  ──────────────────────                                             │
│  ✗ Token tax rate (hardcoded 10%)                                   │
│  ✗ Burn/treasury split (hardcoded 9%/1%)                            │
│  ✗ Total token supply                                               │
│  ✗ Team vesting schedule                                            │
│  ✗ LP burn (irreversible at launch)                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. External Integrations

### 8.1 Gelato Automate (Keepers)

```solidity
// TraceScan.sol - Gelato-compatible checker
function checker() external view returns (bool canExec, bytes memory execPayload) {
    for (uint8 level = 1; level <= 5; level++) {
        if (canExecuteScan(level)) {
            return (true, abi.encodeCall(this.executeScan, (level)));
        }
    }
    return (false, bytes(""));
}
```

**Setup:**
1. Deploy TraceScan with KEEPER_ROLE for Gelato's executor
2. Create Gelato task pointing to checker()
3. Fund Gelato Gas Tank (1Balance)

### 8.2 DEX Integration (Bronto/Bebop)

```solidity
// FeeRouter.sol - Buyback mechanism
function processETHToll() external {
    uint256 ethBalance = address(this).balance;
    uint256 buybackAmount = ethBalance * 90 / 100;
    
    // Swap ETH → DATA via Bronto or Bebop
    uint256 dataReceived = _swapETHForDATA(buybackAmount);
    
    // Burn received DATA
    dataToken.transfer(DEAD_ADDRESS, dataReceived);
    
    // Send 10% to operations
    payable(operations).transfer(ethBalance - buybackAmount);
}
```

---

## 9. Development Phases

### Phase 1: Foundation (Week 1-2)

**Deliverables:**
- [ ] DataToken.sol - Token with tax mechanics
- [ ] TeamVesting.sol - Vesting contract
- [ ] Basic GhostCore.sol - Stake/extract only (no deaths yet)
- [ ] Unit tests for token and basic staking
- [ ] **prevrandao verification on MegaETH testnet**

**Milestone:** Users can stake and withdraw DATA with tax mechanics working.

### Phase 2: Core Game (Week 3-4)

**Deliverables:**
- [ ] TraceScan.sol - Randomness + death selection
- [ ] Complete GhostCore.sol - Death processing, cascade
- [ ] System reset timer
- [ ] Share-based reward distribution
- [ ] Gelato Automate integration for keepers
- [ ] Integration tests for full game loop

**Milestone:** Complete game loop working on testnet.

### Phase 3: Prediction Market (Week 5)

**Deliverables:**
- [ ] DeadPool.sol - Parimutuel betting
- [ ] Round creation and resolution
- [ ] Integration with TraceScan outcomes
- [ ] Rake burning

**Milestone:** Users can bet on scan outcomes.

### Phase 4: Periphery (Week 6)

**Deliverables:**
- [ ] FeeRouter.sol - ETH toll + buyback
- [ ] RewardsDistributor.sol - Emission schedule
- [ ] ConsumablesShop.sol - Black market
- [ ] Boost signature verification
- [ ] Governance setup (Timelock + Multisig)

**Milestone:** All economic flows operational.

### Phase 5: Security (Week 7-8)

**Deliverables:**
- [ ] Internal audit pass
- [ ] External audit (if budget allows)
- [ ] Bug bounty setup
- [ ] Testnet stress testing
- [ ] Mainnet deployment scripts
- [ ] Emergency procedures documentation

**Milestone:** Production-ready contracts.

---

## 10. Security Considerations

### Known Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Reentrancy in extract() | Critical | ReentrancyGuard, CEI pattern |
| Flash loan stake manipulation | High | Minimum stake duration (1 block) |
| Sequencer randomness manipulation | Medium | Practical risk near-zero; can add VRF later |
| Upgrade key compromise | High | Multisig + 48h Timelock |
| Boost signature forgery | Medium | Secure key management, signature expiry |
| Oracle/keeper failure | Medium | Permissionless scan execution fallback |
| Integer overflow | Low | Solidity 0.8+ built-in checks |

### Invariants to Verify

```
1. totalStaked[level] == sum(positions[*].amount) for alive positions
2. sum(all positions) + burned + extracted == initial supply
3. accRewardsPerShare only increases (never decreases)
4. position.rewardDebt <= position.amount * accRewardsPerShare
5. systemResetDeadline only extends on deposits (never shortens)
```

### Audit Focus Areas

1. **Cascade math** - Rounding, share calculations
2. **Death selection** - Fairness, no manipulation vectors
3. **Upgrade safety** - Storage layout compatibility
4. **Access control** - Role assignments, privilege escalation
5. **Token integration** - Tax exemptions, burn mechanics

---

## 11. Open Questions

### Critical (Blocking)

1. **prevrandao on MegaETH**
   - Does it return usable randomness?
   - Is it different per block?
   - Verification plan in next section

2. **Gelato Automate on MegaETH**
   - Is it available on mainnet?
   - What's the execution latency?

### Important (Should Resolve Before Launch)

3. **DEX for buyback**
   - Bronto vs Bebop integration?
   - Liquidity depth concerns?

4. **Team multisig composition**
   - Who are the 5 signers?
   - What's the geographic distribution?

5. **Audit budget/timeline**
   - Can we get audited before launch?
   - Which firm?

### Nice to Have

6. **Gas optimization targets**
   - What's the max acceptable gas for executeScan()?
   - How many positions can we process per scan?

7. **Indexer strategy**
   - Envio? Custom subgraph?
   - Real-time feed requirements

---

## Appendix: Session Log

### Architectural Decisions Made (2026-01-19)

| Decision | Choice | Confidence | Revisit If |
|----------|--------|------------|------------|
| Randomness source | Block-based (prevrandao) | Medium | prevrandao fails on MegaETH |
| Token upgradeability | Immutable | High | - |
| Game logic upgradeability | UUPS + Timelock | High | - |
| Reward distribution | Share-based (MasterChef) | High | - |
| Mini-game boosts | Server signatures | High | - |
| VRF integration | Deferred (not needed) | Medium | User demand, regulatory |

### Assumptions Made

| Assumption | Basis | Verification Needed |
|------------|-------|---------------------|
| prevrandao works on MegaETH | EVM compatibility claim | Yes - test contract |
| MegaETH sequencer won't manipulate | Reputation economics | No - accepted risk |
| Gelato Automate available | Listed as partner | Yes - confirm mainnet |
| 10B gas limit sufficient | MegaETH docs | Yes - test at scale |

### Research Completed

- [x] MegaETH platform capabilities (docs/MEGAETH.md)
- [x] Gelato VRF analysis (docs/GelatoVRF.md)
- [x] Product requirements (docs/product/master-design.md)

### Research Pending

- [ ] prevrandao behavior verification
- [ ] Bronto Finance integration docs
- [ ] Gelato Automate on MegaETH mainnet
- [ ] Actual gas costs on MegaETH

---

*Document maintained by: Architecture Team*
*Last updated: 2026-01-19*
