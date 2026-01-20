# GHOSTNET Smart Contracts Architecture Plan

**Version:** 0.3  
**Date:** January 2026  
**Status:** Ready for Implementation - All Core Decisions Finalized  
**Network:** MegaETH (Chain ID 6343 testnet, 4326 mainnet)  
**Testnet RPC:** https://carrot.megaeth.com/rpc

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
| **Randomness** | Block-based (prevrandao) + 60s lock | Zero latency, zero cost. Lock period prevents front-running. Verified on MegaETH. |
| **Token** | Immutable | Trust anchor - users need certainty tax rates won't change |
| **Game Logic** | UUPS Upgradeable | Game parameters need tuning, bugs need fixing |
| **Reward Distribution** | Share-based (MasterChef pattern) | O(1) gas regardless of participant count |
| **Mini-game Boosts** | Server signatures | Games are off-chain, server validates and signs boost claims |
| **Position Model** | Single per user, upgradeable stake | Simpler model, level change requires extract (10% tax friction) |
| **Death Processing** | Trustless batch verification | On-chain verifiable, permissionless, scales to thousands |
| **Cascade Split** | 30/30/30/10 absolute | Same-level/upstream/burn/protocol (matches product spec) |
| **Network Modifier** | DATA-based thresholds | No oracle dependency, configurable via admin |
| **Yield Sources** | Emissions + Cascade | Both additive to accRewardsPerShare |

### Verification Status

| Item | Status | Notes |
|------|--------|-------|
| prevrandao on MegaETH | **VERIFIED** | Constant for ~60s, acceptable with lock period |
| Position model design | **FINALIZED** | Single position per user |
| Death processing design | **FINALIZED** | Trustless batch verification |
| Cascade distribution | **FINALIZED** | 30/30/30/10 absolute split per product spec |
| Gelato Automate | Pending | Verify availability before mainnet |
| DEX Integration | Pending | Bronto/Bebop for buybacks |

---

## 2. Architectural Decisions

### 2.1 Randomness: Block-Based vs VRF

**Decision: Block-based randomness using `prevrandao` + 60-second lock period**

**Status:** VERIFIED on MegaETH testnet (January 2026)

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

**MegaETH-Specific Finding:** `prevrandao` stays constant for ~60 seconds on MegaETH (unlike Ethereum mainnet where it changes every block). This was verified via on-chain testing.

**Mitigation:** 60-second pre-scan lock period prevents extraction when scan is imminent. Combined with multi-component seed (prevrandao + timestamp + block number + nonce) and 19% economic cost of front-running, this is acceptable.

**Risk assessment:** MegaETH sequencer manipulation is theoretical, not practical. The sequencer (MegaETH Labs) has vastly more at stake in reputation than any GHOSTNET position value. The lock period eliminates the practical exploit window.

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

**Decision: Off-chain games with EIP-712 typed signatures**

**Rationale:**
- Typing games, hack runs happen in browser - can't be on-chain
- Server validates gameplay, signs boost approval
- Contract verifies signature, applies boost
- Simple, gas-efficient, appropriate trust model for entertainment

**Security: EIP-712 prevents cross-chain replay attacks**

The signature includes `chainId` and `verifyingContract` in the domain separator, ensuring signatures from testnet cannot be replayed on mainnet (or vice versa).

**Pattern:**
```solidity
// Domain separator (set once in constructor/initializer)
bytes32 public DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256("GHOSTNET"),
    keccak256("1"),
    block.chainid,
    address(this)
));

bytes32 public constant BOOST_TYPEHASH = keccak256(
    "Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"
);

function applyBoost(
    uint8 boostType,
    uint16 valueBps,
    uint64 expiry,
    bytes32 nonce,
    bytes calldata signature
) external {
    // EIP-712 typed data hash
    bytes32 structHash = keccak256(abi.encode(
        BOOST_TYPEHASH, msg.sender, boostType, valueBps, expiry, nonce
    ));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    
    require(ECDSA.recover(digest, signature) == boostSigner, "Invalid signature");
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
│   uint256 amount;           // Total staked DATA (can increase)     │
│   uint8   level;            // 1-5 (locked once chosen)             │
│   uint64  entryTimestamp;   // When first jacked in                 │
│   uint64  lastAddTimestamp; // When last added stake (for lock)     │
│   uint256 rewardDebt;       // For share-based accounting           │
│   bool    alive;            // false = traced                       │
│   uint16  ghostStreak;      // Consecutive scan survivals           │
│   Boost[] activeBoosts;     // From mini-games                      │
│ }                                                                    │
│                                                                      │
│ LevelConfig {                                                        │
│   uint16  baseDeathRateBps; // e.g., 4000 = 40%                     │
│   uint32  scanInterval;     // Seconds between scans                │
│   uint256 minStake;         // Minimum to jack in                   │
│   uint256 totalStaked;      // Sum of all alive positions           │
│   uint256 aliveCount;       // Number of alive positions            │
│   uint256 accRewardsPerShare; // For reward distribution (1e18)     │
│   uint64  nextScanTime;     // Timestamp of next scan               │
│ }                                                                    │
│                                                                      │
│ Boost {                                                              │
│   uint8   boostType;        // 0=death reduction, 1=yield mult      │
│   uint16  valueBps;         // Basis points (e.g., 1500 = 15%)      │
│   uint64  expiry;           // Timestamp when boost expires         │
│ }                                                                    │
│                                                                      │
│ SystemReset {                                                        │
│   uint256 deadline;         // When system resets if no deposits    │
│   address lastDepositor;    // Eligible for jackpot if reset        │
│   uint256 lastDepositTime;  // Timestamp of last deposit            │
│ }                                                                    │
│                                                                      │
│ STATE:                                                               │
│ ├── dataToken:        IDataToken                                    │
│ ├── positions:        mapping(address => Position)  // ONE per user │
│ ├── levels:           mapping(uint8 => LevelConfig)                 │
│ ├── systemReset:      SystemReset                                   │
│ ├── boostSigner:      address                                       │
│ ├── treasury:         address                                       │
│ └── networkModThresholds: uint256[4]  // DATA thresholds            │
│                                                                      │
│ CONSTANTS:                                                           │
│ ├── LOCK_PERIOD:         60 seconds                                 │
│ ├── CASCADE_SAME_LEVEL:  3000 (30% of dead capital)                 │
│ ├── CASCADE_UPSTREAM:    3000 (30% of dead capital)                 │
│ ├── CASCADE_BURN:        3000 (30% of dead capital)                 │
│ └── CASCADE_PROTOCOL:    1000 (10% of dead capital)                 │
│                                                                      │
│ CORE FUNCTIONS:                                                      │
│                                                                      │
│ jackIn(uint256 amount, uint8 level)                                 │
│ ├── If no position: create new with level                           │
│ ├── If has position: require same level, add to amount              │
│ ├── Update lastAddTimestamp (resets lock period)                    │
│ ├── Update level.totalStaked, level.aliveCount                      │
│ ├── Extend systemReset.deadline based on amount                     │
│ ├── Update systemReset.lastDepositor                                │
│ └── Emits JackedIn(user, amount, level, newTotal)                   │
│                                                                      │
│ extract() - note: no positionId needed (one per user)               │
│ ├── Requires position exists and alive == true                      │
│ ├── Requires NOT in lock period (60s before next scan)              │
│ ├── Claims pending rewards (emissions + cascade)                    │
│ ├── Transfers amount + rewards to user                              │
│ ├── Deletes position, updates level.totalStaked                     │
│ └── Emits Extracted(user, amount, rewards)                          │
│                                                                      │
│ addStake(uint256 amount)                                            │
│ ├── Requires existing alive position                                │
│ ├── Adds to position.amount                                         │
│ ├── Updates lastAddTimestamp                                        │
│ ├── Updates rewardDebt (settle pending first)                       │
│ └── Emits StakeAdded(user, amount, newTotal)                        │
│                                                                      │
│ processDeaths(address[] deadUsers)                                  │
│ ├── onlyRole(SCANNER_ROLE)                                          │
│ ├── For each dead user:                                             │
│ │   ├── Verify isDead(scanSeed, user) == true                       │
│ │   ├── Mark position.alive = false, ghostStreak = 0                │
│ │   ├── Accumulate dead capital                                     │
│ │   └── Update level.totalStaked, level.aliveCount                  │
│ ├── Calculate cascade: 60% rewards, 30% burn, 10% protocol          │
│ ├── Distribute rewards:                                             │
│ │   ├── 30% to same-level (accRewardsPerShare)                      │
│ │   └── 30% to upstream levels (by TVL weight)                      │
│ ├── Execute burn (30%)                                              │
│ ├── Send to treasury (10%)                                          │
│ └── Emits DeathsProcessed(level, count, burned, distributed)        │
│                                                                      │
│ incrementGhostStreak(address[] survivors)                           │
│ ├── onlyRole(SCANNER_ROLE)                                          │
│ ├── For each survivor: position.ghostStreak++                       │
│ └── Emits SurvivorsUpdated(level, count)                            │
│                                                                      │
│ triggerSystemReset()                                                │
│ ├── Requires block.timestamp >= systemReset.deadline                │
│ ├── Calculate penalty (25% of all positions)                        │
│ ├── Distribute: 50% to lastDepositor, 30% burn, 20% protocol        │
│ ├── Apply penalty to all positions                                  │
│ ├── Reset deadline to default                                       │
│ └── Emits SystemReset(penalty, jackpotWinner, jackpotAmount)        │
│                                                                      │
│ addEmissionRewards(uint8 level, uint256 amount)                     │
│ ├── onlyRole(DISTRIBUTOR_ROLE) - RewardsDistributor                 │
│ ├── Adds to level.accRewardsPerShare                                │
│ └── Emits EmissionsAdded(level, amount)                             │
│                                                                      │
│ applyBoost(boostType, valueBps, expiry, signature)                  │
│ ├── Verifies ECDSA signature from boostSigner                       │
│ ├── Checks expiry > block.timestamp                                 │
│ ├── Adds Boost to position.activeBoosts                             │
│ └── Emits BoostApplied(user, boostType, valueBps)                   │
│                                                                      │
│ VIEW FUNCTIONS:                                                      │
│ ├── getPosition(address) → Position                                 │
│ ├── getPendingRewards(address) → uint256                            │
│ ├── getEffectiveDeathRate(address) → uint16                         │
│ ├── getLevelStats(uint8 level) → LevelConfig                        │
│ ├── getSystemResetCountdown() → uint256                             │
│ ├── getNetworkModifier() → uint16                                   │
│ ├── isInLockPeriod(address) → bool                                  │
│ └── getTotalValueLocked() → uint256                                 │
│                                                                      │
│ ADMIN FUNCTIONS:                                                     │
│ ├── pause() / unpause() - onlyRole(DEFAULT_ADMIN_ROLE)              │
│ ├── updateLevelConfig() - onlyRole(DEFAULT_ADMIN_ROLE)              │
│ ├── setBoostSigner() - onlyRole(DEFAULT_ADMIN_ROLE)                 │
│ ├── setNetworkModThresholds() - onlyRole(DEFAULT_ADMIN_ROLE)        │
│ └── emergencyWithdraw() - when paused, users can exit               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.3 TraceScan.sol

```
┌─────────────────────────────────────────────────────────────────────┐
│ CONTRACT: TraceScan                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Type:        Randomness + Trustless Death Verification              │
│ Upgradeable: YES (UUPS)                                             │
│ Inherits:    UUPSUpgradeable, AccessControlUpgradeable              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ DESIGN: Trustless Batch Verification                                │
│ ─────────────────────────────────────                               │
│ Deaths are DETERMINISTIC from (seed, address). Anyone can verify.   │
│ No iteration in critical path - deaths submitted in batches.        │
│                                                                      │
│ ROLES:                                                               │
│ ├── DEFAULT_ADMIN_ROLE  - Timelock                                  │
│ └── KEEPER_ROLE         - Gelato Automate (optional, anyone can call)│
│                                                                      │
│ STRUCTS:                                                             │
│                                                                      │
│ Scan {                                                               │
│   uint256 seed;             // Deterministic seed for this scan     │
│   uint64  executedAt;       // When scan was executed               │
│   uint64  finalizedAt;      // When cascade was distributed         │
│   uint8   level;            // Which level this scan targets        │
│   uint256 totalDead;        // Accumulated dead capital             │
│   uint256 deathCount;       // Number of deaths processed           │
│   bool    finalized;        // Has cascade been distributed         │
│ }                                                                    │
│                                                                      │
│ STATE:                                                               │
│ ├── ghostCore:          IGhostCore                                  │
│ ├── currentScans:       mapping(uint8 => Scan)  // Per level        │
│ ├── scanNonce:          uint256 (prevents replay)                   │
│ ├── submissionWindow:   uint256 (default: 120 seconds)              │
│ └── processedInScan:    mapping(uint8 => mapping(address => bool))  │
│                                                                      │
│ CONSTANTS:                                                           │
│ └── MAX_BATCH_SIZE:     100 (deaths per submission tx)              │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ PHASE 1: SCAN EXECUTION (O(1) - stores seed only)                   │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ executeScan(uint8 level) external                                   │
│ ├── Anyone can call when timer expired                              │
│ ├── require(block.timestamp >= ghostCore.nextScanTime(level))       │
│ ├── require(!currentScans[level].active) // No pending scan         │
│ ├── Generate seed: keccak256(prevrandao, timestamp, level, nonce++) │
│ ├── Store Scan{seed, executedAt, level, ...}                        │
│ ├── Update ghostCore.nextScanTime(level)                            │
│ └── Emits ScanExecuted(level, seed, executedAt)                     │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ PHASE 2: DEATH PROOF SUBMISSION (Batched, trustless)                │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ submitDeaths(uint8 level, address[] deadUsers) external             │
│ ├── Anyone can call (permissionless)                                │
│ ├── require(scan.executedAt > 0 && !scan.finalized)                 │
│ ├── For each user in batch (max 100):                               │
│ │   ├── require(!processedInScan[level][user]) // Not duplicate     │
│ │   ├── require(ghostCore.isAlive(user, level)) // Has position     │
│ │   ├── uint256 deathRate = ghostCore.getEffectiveDeathRate(user)   │
│ │   ├── bool shouldDie = isDead(scan.seed, user, deathRate)         │
│ │   ├── require(shouldDie, "User should not die") // VERIFY!        │
│ │   ├── processedInScan[level][user] = true                         │
│ │   └── scan.totalDead += position.amount; scan.deathCount++        │
│ ├── Call ghostCore.processDeaths(deadUsers) // Mark dead            │
│ └── Emits DeathsSubmitted(level, deadUsers.length, submitter)       │
│                                                                      │
│ isDead(uint256 seed, address user, uint16 deathRateBps) pure → bool │
│ ├── uint256 roll = uint256(keccak256(seed, user)) % 10000           │
│ └── return roll < deathRateBps                                      │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ PHASE 3: CASCADE FINALIZATION                                       │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ finalizeScan(uint8 level) external                                  │
│ ├── Anyone can call after submission window                         │
│ ├── require(block.timestamp >= scan.executedAt + submissionWindow)  │
│ ├── require(!scan.finalized)                                        │
│ ├── Call ghostCore.distributeCascade(level, scan.totalDead)         │
│ ├── Call ghostCore.incrementGhostStreak(level) // Survivors         │
│ ├── scan.finalized = true; scan.finalizedAt = now                   │
│ ├── Clear processedInScan mapping for level                         │
│ └── Emits ScanFinalized(level, deathCount, totalDead, distributed)  │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ VIEW FUNCTIONS                                                       │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ canExecuteScan(uint8 level) → bool                                  │
│ ├── Timer expired AND no pending unfinalized scan                   │
│                                                                      │
│ canFinalizeScan(uint8 level) → bool                                 │
│ ├── Scan exists AND submission window passed AND not finalized      │
│                                                                      │
│ wouldDie(uint8 level, address user) → bool                          │
│ ├── Check if user would die in current pending scan                 │
│ ├── Returns false if no pending scan                                │
│                                                                      │
│ getCurrentScan(uint8 level) → Scan                                  │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ KEEPER INTERFACE (Gelato Automate compatible)                       │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ checker() → (bool canExec, bytes execPayload)                       │
│ ├── Check all levels for:                                           │
│ │   ├── Scan ready to execute → return executeScan calldata         │
│ │   ├── Scan ready to finalize → return finalizeScan calldata       │
│ └── Returns first actionable item found                             │
│                                                                      │
│ ═══════════════════════════════════════════════════════════════════ │
│ TRUSTLESS PROPERTIES                                                 │
│ ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│ ✓ Keeper cannot lie about deaths (contract verifies isDead())       │
│ ✓ Anyone can submit death proofs (permissionless)                   │
│ ✓ Deaths are deterministic and reproducible from seed               │
│ ✓ No iteration required in critical path                            │
│ ✓ Scales to thousands of positions via batching                     │
│                                                                      │
│ GAS ESTIMATES:                                                       │
│ ├── executeScan(): ~50,000 gas (seed storage only)                  │
│ ├── submitDeaths(100): ~2,500,000 gas (verification + marking)      │
│ └── finalizeScan(): ~200,000 gas (cascade distribution)             │
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

### Decision: Block-Based (prevrandao) + Pre-Scan Lock Period

**Status:** VERIFIED AND APPROVED (January 2026)

After testing on MegaETH testnet, we confirmed that `prevrandao` stays constant for ~60 seconds across multiple blocks. After analysis, we determined this is **acceptable for GHOSTNET** with mitigations.

### Implementation

```solidity
function _generateSeed(uint8 level) internal returns (uint256) {
    return uint256(keccak256(abi.encode(
        block.prevrandao,     // RANDAO - constant for ~60s on MegaETH
        block.timestamp,      // Changes every 1s (EVM block)
        block.number,         // Changes every block
        level,                // Which level
        _scanNonce++          // Incrementing nonce (prevents replay)
    )));
}
```

### Pre-Scan Lock Period

To prevent last-second extraction when a scan is imminent:

```solidity
uint256 public constant LOCK_PERIOD = 60 seconds;

modifier notInLockPeriod(uint8 level) {
    uint256 nextScan = levels[level].nextScanTime;
    require(
        block.timestamp < nextScan - LOCK_PERIOD || block.timestamp >= nextScan,
        "Position locked: scan imminent"
    );
    _;
}

function extract(uint256 positionId) external notInLockPeriod(position.level) {
    // ... extraction logic
}
```

### Why prevrandao is Acceptable (Analysis)

#### The Concern
On MegaETH, `prevrandao` stays constant for ~60 seconds. This theoretically allows:
1. Observing the current prevrandao value
2. Calculating if you'll die in the upcoming scan
3. Extracting before the scan to avoid death

#### Why It Doesn't Break the Game

**1. You can't change your fate, only observe it**
- Death selection: `keccak256(seed, yourAddress) % 10000 < deathRate`
- Your address is fixed - you can only see the outcome early, not change it

**2. Front-running is expensive (19% cost)**
| Action | Result |
|--------|--------|
| Stay and die | Lose 100% of position |
| Extract (10% tax) + Re-enter (10% tax) | Lose ~19% of position |

At 40% death rate, expected loss = 40%, so front-running (19% loss) is rational.
BUT: players who constantly front-run burn themselves via taxes anyway.

**3. The lock period eliminates the exploit window**
With a 60-second lock before scans, players cannot extract once they can predict.

**4. Multi-component seed adds uncertainty**
Even with constant prevrandao, `block.timestamp` and `block.number` change every second.
Exact scan execution block is unpredictable (Gelato keeper timing).

**5. Statistical fairness is preserved**
Selection remains uniformly random. Every address has equal probability.
Predictability doesn't change fairness - only gives brief reaction window.

#### Economic Analysis

| Player Type | Behavior | Outcome |
|-------------|----------|---------|
| Casual | Plays normally, accepts death lottery | Fun game experience |
| Sophisticated | Builds prediction bots | Pays 19% "skill tax" per cycle |
| Front-runner | Extracts before predicted death | Burns tokens via taxes (good for tokenomics) |

### Alternatives Considered

#### Commit-Reveal Pattern
```solidity
// Would require 2 transactions and ~1-2 second delay
function commitScan(uint8 level) external { ... }
function revealScan(uint8 level) external { ... }
```

**Rejected because:**
- Adds latency (1-2 seconds per scan)
- Adds complexity (2-phase execution)
- Marginal security benefit given lock period mitigation
- Front-running cost (19%) is sufficient deterrent

#### Gelato VRF
**Rejected because:**
- Not on-chain verifiable (BLS12-381 requires EIP-2537)
- Same trust model as prevrandao (trust Gelato vs trust sequencer)
- Adds external dependency and per-request costs
- ~1500ms latency per request

---

## 6. Economic Flows

### 6.1 The Cascade (Death Redistribution)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TRACED POSITION: 100 DATA                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ABSOLUTE SPLIT: 30 / 30 / 30 / 10                                  │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 30% → SAME-LEVEL SURVIVORS (30 DATA)                        │    │
│  │                                                              │    │
│  │ • Distributed proportionally by stake size                  │    │
│  │ • Creates within-level competition                          │    │
│  │ • "Jackpot" for surviving high-risk levels                  │    │
│  │ • Implementation: Increment level's accRewardsPerShare      │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 30% → UPSTREAM LEVELS (30 DATA)                             │    │
│  │                                                              │    │
│  │ • Flows UP to safer levels (lower risk tiers)               │    │
│  │ • Split by TVL weight of each upstream level                │    │
│  │ • Creates "degens feed whales" dynamic                      │    │
│  │                                                              │    │
│  │ Example (DARKNET death):                                     │    │
│  │ ├── SUBNET receives share based on SUBNET TVL               │    │
│  │ ├── MAINFRAME receives share based on MAINFRAME TVL         │    │
│  │ └── VAULT receives share based on VAULT TVL                 │    │
│  │                                                              │    │
│  │ Example (BLACK ICE death):                                   │    │
│  │ └── Flows to all 4 levels above (DARKNET→VAULT)             │    │
│  │                                                              │    │
│  │ Edge case (VAULT death):                                     │    │
│  │ └── No upstream → this 30% goes to same-level survivors     │    │
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
│  ═══════════════════════════════════════════════════════════════    │
│                                                                      │
│  IMPLEMENTATION CONSTANTS:                                           │
│                                                                      │
│  // Primary split (of total dead capital)                           │
│  uint16 constant CASCADE_SAME_LEVEL = 3000;  // 30%                 │
│  uint16 constant CASCADE_UPSTREAM   = 3000;  // 30%                 │
│  uint16 constant CASCADE_BURN       = 3000;  // 30%                 │
│  uint16 constant CASCADE_PROTOCOL   = 1000;  // 10%                 │
│                                                                      │
│  // Note: Same-level + Upstream = 60% total rewards                 │
│  // This is equivalent to "60% rewards split 50/50"                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Emissions (The Mine)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    THE MINE: 60,000,000 DATA                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SOURCE: RewardsDistributor contract holding 60% of supply          │
│  DURATION: 24 months linear vesting                                  │
│  RATE: ~82,000 DATA per day                                         │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ DISTRIBUTION BY LEVEL (of daily 82,000 DATA):               │    │
│  │                                                              │    │
│  │ Level        │ Weight │ Daily Allocation │ Purpose           │    │
│  │ ─────────────┼────────┼──────────────────┼─────────────────  │    │
│  │ VAULT        │   5%   │   ~4,100 DATA    │ Safe haven yield  │    │
│  │ MAINFRAME    │  10%   │   ~8,200 DATA    │ Conservative      │    │
│  │ SUBNET       │  20%   │  ~16,400 DATA    │ Balanced          │    │
│  │ DARKNET      │  30%   │  ~24,600 DATA    │ Degen rewards     │    │
│  │ BLACK ICE    │  35%   │  ~28,700 DATA    │ High risk premium │    │
│  │                                                              │    │
│  │ Within each level: proportional to stake size                │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  IMPLEMENTATION:                                                     │
│  ├── RewardsDistributor.distribute() called periodically            │
│  ├── Calculates elapsed time × emission rate                        │
│  ├── Splits by level weights                                        │
│  └── Calls ghostCore.addEmissionRewards(level, amount)              │
│                                                                      │
│  RELATIONSHIP TO CASCADE:                                            │
│  ├── Emissions = BASE yield (predictable, from token supply)        │
│  ├── Cascade = BONUS yield (variable, from deaths)                  │
│  └── Both accumulate to accRewardsPerShare (additive)               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.3 System Reset Mechanics

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SYSTEM RESET TIMER & JACKPOT                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PURPOSE: Create urgency for deposits, prevent stagnation           │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ TIMER MECHANICS:                                             │    │
│  │                                                              │    │
│  │ • Global countdown timer visible to all                      │    │
│  │ • Any deposit extends timer based on amount:                 │    │
│  │   ├── < 50 DATA:      +1 hour                               │    │
│  │   ├── 50-200 DATA:    +4 hours                              │    │
│  │   ├── 200-500 DATA:   +8 hours                              │    │
│  │   ├── 500-1000 DATA:  +16 hours                             │    │
│  │   └── > 1000 DATA:    Full reset (24 hours)                 │    │
│  │                                                              │    │
│  │ • Timer is capped at max (24 hours)                         │    │
│  │ • Last depositor tracked for jackpot eligibility            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ IF TIMER HITS ZERO (System Reset):                          │    │
│  │                                                              │    │
│  │ PENALTY: 25% of ALL positions across ALL levels             │    │
│  │                                                              │    │
│  │ DISTRIBUTION OF PENALTY POOL:                                │    │
│  │ ├── 50% → Last depositor (JACKPOT)                          │    │
│  │ ├── 30% → Burned                                            │    │
│  │ └── 20% → Protocol treasury                                 │    │
│  │                                                              │    │
│  │ EXAMPLE: 1,000,000 DATA total staked                        │    │
│  │ ├── Penalty pool: 250,000 DATA                              │    │
│  │ ├── Jackpot winner: 125,000 DATA                            │    │
│  │ ├── Burned: 75,000 DATA                                     │    │
│  │ └── Treasury: 50,000 DATA                                   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  GAME THEORY:                                                        │
│  ├── Creates "chicken" game as timer approaches zero                │
│  ├── Large deposits become heroic (full reset)                      │
│  ├── Last-second deposits are risky but jackpot-eligible            │
│  └── Content moments when timer gets low (urgency in feed)          │
│                                                                      │
│  IMPLEMENTATION:                                                     │
│  ├── systemReset.deadline: timestamp when reset triggers            │
│  ├── systemReset.lastDepositor: address eligible for jackpot        │
│  ├── triggerSystemReset(): callable by anyone when deadline passed  │
│  └── Applied proportionally to all positions (not instant death)    │
│                                                                      │
│  GAS OPTIMIZATION (Hybrid Lazy Settlement):                         │
│  ───────────────────────────────────────────                        │
│  • Emit PositionPenalized events immediately (O(n) events, cheap)   │
│  • Defer storage writes until user's next interaction (lazy)        │
│  • Store currentReset.epoch and penaltyBps globally                 │
│  • On extract/jackIn/claim: check if lastResetEpoch < currentEpoch  │
│  • View function getEffectivePosition() for accurate UI display     │
│  • Gas: ~10M (events) vs ~60M (full storage) for 10k positions      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.4 Multi-Source Burns

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
│  6. System Reset (30% of penalty) │  triggerSystemReset()           │
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

### Resolved

1. ~~**prevrandao on MegaETH**~~ ✅
   - VERIFIED: Returns usable randomness, constant for ~60s
   - Acceptable with 60s lock period

2. ~~**Position model**~~ ✅
   - Single position per user, can add stake
   - Level locked, must extract to change

3. ~~**Cascade split**~~ ✅
   - 30/30/30/10 absolute (same-level/upstream/burn/protocol)
   - Matches product specification
   - VAULT deaths: upstream portion goes to same-level

4. ~~**Death processing at scale**~~ ✅
   - Trustless batch verification
   - No off-chain trust required

5. ~~**Network modifier**~~ ✅
   - DATA-based thresholds (no oracle)
   - Configurable via admin setter

6. ~~**Yield sources**~~ ✅
   - Emissions (The Mine) + Cascade (deaths)
   - Both additive to accRewardsPerShare

### Important (Should Resolve Before Launch)

7. **Gelato Automate on MegaETH**
   - Is it available on mainnet?
   - What's the execution latency?
   - Fallback: Permissionless execution works without keeper

8. **DEX for buyback**
   - Bronto vs Bebop integration?
   - Liquidity depth concerns?

9. **Team multisig composition**
   - Who are the 5 signers?
   - What's the geographic distribution?

10. **Audit budget/timeline**
    - Can we get audited before launch?
    - Which firm?

### Nice to Have

11. **Gas optimization**
    - Batch size tuning for submitDeaths()
    - Target: 100 deaths per tx (~2.5M gas)

12. **Indexer strategy**
    - Envio? Custom subgraph?
    - Real-time feed requirements

---

## Appendix: Session Log

### Architectural Decisions Made (2026-01-19)

| Decision | Choice | Confidence | Revisit If |
|----------|--------|------------|------------|
| Randomness source | Block-based (prevrandao) + 60s lock | High | Evidence of systematic exploitation |
| Token upgradeability | Immutable | High | - |
| Game logic upgradeability | UUPS + Timelock | High | - |
| Reward distribution | Share-based (MasterChef) | High | - |
| Mini-game boosts | Server signatures | High | - |
| Position model | Single per user, upgradeable stake | High | User demand for multiple |
| Death processing | Trustless batch verification | High | Gas issues at extreme scale |
| Cascade split | 30/30/30/10 absolute | High | - |
| System reset | Include jackpot in V1 | Medium | Complexity issues |
| Network modifier | DATA-based thresholds | High | Need for USD precision |
| Yield sources | Emissions + Cascade (additive) | High | - |

### Assumptions Verified

| Assumption | Result | Notes |
|------------|--------|-------|
| prevrandao works on MegaETH | ✅ VERIFIED | Constant for ~60s, acceptable with lock |
| Single position sufficient | ✅ DECIDED | Simplifies implementation significantly |
| Batch verification scales | ✅ DESIGNED | ~100 deaths per tx, ~2.5M gas |

### Assumptions Pending Verification

| Assumption | Basis | Verification Needed |
|------------|-------|---------------------|
| MegaETH sequencer won't manipulate | Reputation economics | No - accepted risk |
| Gelato Automate available | Listed as partner | Yes - confirm mainnet |
| 10B gas limit sufficient | MegaETH docs | Yes - test batch sizes |
| 120s submission window adequate | Keeper reliability | Yes - monitor in production |

### Research Completed

- [x] MegaETH platform capabilities (docs/MEGAETH.md)
- [x] Gelato VRF analysis (docs/GelatoVRF.md)
- [x] Product requirements (docs/product/master-design.md)
- [x] prevrandao behavior verification (deployed test contract)
- [x] Product vs architecture alignment review

### Research Pending

- [ ] Bronto Finance integration docs
- [ ] Gelato Automate on MegaETH mainnet
- [ ] Actual gas costs on MegaETH for batch operations

---

*Document maintained by: Architecture Team*
*Last updated: 2026-01-19*
