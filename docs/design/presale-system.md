# GHOSTNET Presale System — Design Specification

**Version:** 3.0
**Date:** 2026-01-28
**Status:** Draft — Post-Second-Review, Awaiting Parameter Decisions
**Network:** MegaETH (Chain ID 6343 testnet / 4326 mainnet)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Presale Contract](#3-presale-contract)
4. [Claim Contract](#4-claim-contract)
5. [Pricing Modes](#5-pricing-modes)
6. [Frontend — The Presale Page](#6-frontend--the-presale-page)
7. [Integration With DataToken](#7-integration-with-datatoken)
8. [Security Considerations](#8-security-considerations)
9. [Configuration Reference](#9-configuration-reference)
10. [Open Parameters](#10-open-parameters)

---

## 1. Overview

### What This Is

The presale is the **first touchpoint** with GHOSTNET. Pre-launch. Before the game exists. Users send ETH on MegaETH, receive a $DATA allocation, and claim tokens at TGE.

### Terminology

| Context | Verb | Example |
|---------|------|---------|
| Contract / spec | **contribute** | `contribute()`, "user contributes ETH" |
| UI button / feed | **acquire** | "ACQUIRE $DATA", "0x7a3f acquired 50,000 $DATA" |

> **N1 resolved:** "contribute" is the canonical contract-level verb. "acquire" is the user-facing action label.

### The Two Contracts

```
PRE-LAUNCH                                    TGE
───────────────────────────────────────────────┼──────────────────
                                               │
  GhostPresale.sol                             │  PresaleClaim.sol
  ┌─────────────────────┐                      │  ┌─────────────────────┐
  │ Accepts ETH         │                      │  │ Holds $DATA         │
  │ Tracks allocations  │──── finalize() ──────┤  │ Reads allocations   │
  │ Computes pricing    │                      │  │ Users claim tokens  │
  │ Configurable params │                      │  │ One-time claim      │
  └─────────────────────┘                      │  └─────────────────────┘
       │                                       │        │
       ▼                                       │        ▼
  Owner withdraws ETH                          │  $DATA flows to users
  (for liquidity seeding, ops)                 │  (tax-excluded transfer)
```

### Key Properties

- **Two pricing modes**: Ascending tranches OR linear bonding curve (selected at deploy)
- **Everything configurable**: Prices, supplies, caps, timing — all owner-settable
- **Presale supply**: Parameterized (default: 15M $DATA, matching manifesto 15% allocation)
- **Claim at TGE**: Presale records allocations; separate contract distributes tokens
- **No token dependency at presale time**: $DATA doesn't need to exist yet
- **ETH only**: Users pay with native ETH on MegaETH
- **No allowlist mechanism**: The presale is open to all. This is a deliberate choice — GHOSTNET is permissionless from day one.

---

## 2. Architecture

### Contract Relationships

```
                    ┌──────────────────┐
                    │    Owner (EOA)    │
                    └────────┬─────────┘
                             │ configures, finalizes
                             ▼
                    ┌──────────────────┐
                    │  GhostPresale    │
                    │                  │
                    │  • pricingMode   │
                    │  • contributions │
                    │  • allocations   │
                    │  • totalRaised   │
                    │  • totalSold     │
                    │  • config params │
                    │                  │
                    │  IMMUTABLE:      │
                    │  NOT upgradeable │
                    │  NOT self-       │
                    │    destructable  │
                    └────────┬─────────┘
                             │ presale address passed to claim
                             ▼
                    ┌──────────────────┐        ┌──────────────┐
                    │  PresaleClaim    │◄───────│  DataToken    │
                    │                  │  holds  │  ($DATA)     │
                    │  • reads allocs  │  tokens └──────────────┘
                    │  • tracks claims │
                    │  • one-time per  │
                    │    address       │
                    │  • backup alloc  │
                    │    snapshot      │
                    └──────────────────┘
```

> **H3 resolved:** GhostPresale MUST NOT be upgradeable or self-destructable. It is deployed as an immutable contract. PresaleClaim includes a `snapshotAllocations()` backup function (see §4) to copy allocations locally in case of cross-contract read issues.

### State Machine

```
                ┌─────────┐
                │ PENDING │
                └────┬────┘
                     │ open()
                     ▼
                ┌─────────┐
           ┌────│  OPEN   │────┬──────────────────┐
           │    └─────────┘    │                   │
           │                   │                   │
     finalize()          enableRefunds()    emergencyRefunds()
           │                   │           (anyone, after deadline)
           ▼                   ▼                   │
    ┌────────────┐      ┌───────────┐              │
    │ FINALIZED  │      │ REFUNDING │◄─────────────┘
    └────────────┘      └───────────┘
      (terminal)          (terminal)
```

> **C3 resolved:** `FINALIZED` and `REFUNDING` are mutually exclusive terminal states. Once in either state, the presale cannot transition further. `finalize()` requires state == OPEN. `enableRefunds()` requires state == OPEN. Neither can be called once the other has been called.

> **H1-NEW resolved:** If the owner disappears and never calls `finalize()` or `enableRefunds()`, contributors are not stuck. After `emergencyDeadline` (configurable, e.g., 90 days after open), **any address** can call `emergencyRefunds()` to transition the presale to REFUNDING. This is a dead-man's switch — no single key can permanently lock user funds.

### Lifecycle

```
Phase 1: DEPLOY
  → Deploy GhostPresale with pricingMode + initial config
  → State = PENDING

Phase 2: CONFIGURE
  → Owner sets all parameters (prices, supply, caps, timing)
  → Owner opens presale → State = OPEN

Phase 3: LIVE
  → Users send ETH via contribute()
  → Contract computes $DATA allocation based on pricing mode
  → Events emitted for frontend feed
  → Owner can pause/unpause if needed
  → Owner can extend end time via extendEndTime()

Phase 4a: FINALIZE (happy path)
  → Owner calls finalize() → State = FINALIZED (terminal)
  → No more contributions
  → Owner withdraws ETH

Phase 4b: REFUND (emergency path — owner-initiated)
  → Owner calls enableRefunds() → State = REFUNDING (terminal)
  → No more contributions, no finalize possible
  → Users call refund() to reclaim ETH

Phase 4c: EMERGENCY REFUND (dead-man's switch)
  → If state == OPEN and block.timestamp > emergencyDeadline:
  → ANY address calls emergencyRefunds() → State = REFUNDING (terminal)
  → Users call refund() to reclaim ETH
  → Protects contributors if owner key is lost

Phase 5: TGE (only after FINALIZED)
  → Deploy DataToken (presale supply allocation minted to PresaleClaim)
  → Deploy PresaleClaim pointing to GhostPresale + DataToken
  → Owner enables claiming (after verifying funding)

Phase 6: CLAIM
  → Users call claim() on PresaleClaim
  → Contract reads allocation from GhostPresale
  → Transfers $DATA to user (tax-excluded)
```

---

## 3. Presale Contract

### `GhostPresale.sol`

```
Inheritance: Ownable2Step, ReentrancyGuard, Pausable

Enums:
  PricingMode    { TRANCHE, BONDING_CURVE }
  PresaleState   { PENDING, OPEN, FINALIZED, REFUNDING }

Structs:
  TrancheConfig {
    uint256 supply       // $DATA available in this tranche
    uint256 pricePerToken // ETH per $DATA (in wei, 18 decimals)
  }

  CurveConfig {
    uint256 startPrice   // ETH per $DATA at sold=0
    uint256 endPrice     // ETH per $DATA at sold=totalSupply
    uint256 totalSupply  // Total $DATA available on curve
  }

  PresaleConfig {
    uint256 minContribution          // Min ETH per tx (0 = no min)
    uint256 maxContribution          // Max ETH per tx (0 = no max)
    uint256 maxPerWallet             // Max ETH total per wallet (0 = no max)
    bool    allowMultipleContributions // Allow same wallet to contribute again
    uint256 startTime                // Unix timestamp (0 = immediate when opened)
    uint256 endTime                  // Unix timestamp (0 = no deadline)
    uint256 emergencyDeadline        // Seconds after open() when anyone can trigger emergency refunds (e.g., 90 days)
  }

Storage:
  PricingMode public immutable pricingMode   // Set at construction
  PresaleState public state                  // PENDING → OPEN → FINALIZED | REFUNDING
  uint256 public openedAt                    // Timestamp when open() was called (for emergency deadline)

  PresaleConfig public config                // All configurable params

  // Tranche mode
  TrancheConfig[] public tranches            // Dynamic array of tranches

  // Bonding curve mode
  CurveConfig public curve                   // Single curve config

  // Accounting
  mapping(address => uint256) public contributions  // ETH contributed per address
  mapping(address => uint256) public allocations    // $DATA allocated per address
  uint256 public totalRaised                        // Total ETH received
  uint256 public totalSold                          // Total $DATA allocated (single source of truth)
  uint256 public contributorCount                   // Unique contributors
```

> **N4 resolved:** `sold` fields removed from `TrancheConfig` and `CurveConfig`. `totalSold` at the top level is the single source of truth. For tranche mode, the current tranche is computed from `totalSold` and cumulative tranche supply boundaries.

> **H4 resolved:** `maxPerWallet` is a **UX guardrail**, not a sybil-resistant cap. Any user can create multiple wallets to bypass this limit. It exists to prevent accidental over-contribution from a single wallet, not to enforce fair distribution.

### Custom Errors

```solidity
error PresaleNotOpen();
error PresaleNotPending();
error PresaleNotFinalized();
error PresaleNotRefunding();
error InvalidState(PresaleState current, PresaleState required);
error BelowMinContribution(uint256 sent, uint256 minimum);
error AboveMaxContribution(uint256 sent, uint256 maximum);
error WalletCapExceeded(uint256 total, uint256 cap);
error MultipleContributionsNotAllowed();
error PresaleSoldOut();
error AllocationBelowMinimum(uint256 allocation, uint256 minAllocation);
error InvalidTranchePrice();       // Prices must be ascending and > 0
error InvalidCurveParams();        // endPrice must be > startPrice, totalSupply > 0
error EndPriceMustExceedStartPrice();
error NoContribution();
error InvalidAddress();
error InvalidEndTime(uint256 newEndTime, uint256 currentEndTime);
error RefundsNotEnabled();
error EmergencyDeadlineNotReached(uint256 current, uint256 deadline);
error PricingNotConfigured();
error ETHRefundFailed();
```

> **No `receive()` or `fallback()` functions.** Direct ETH transfers to GhostPresale revert. All ETH must flow through `contribute()`. This prevents untracked ETH from accumulating in the contract.

### Functions

#### User-Facing

```solidity
/// @notice Contribute ETH to the presale
/// @param minAllocation Minimum $DATA the caller expects; reverts if actual < this (slippage protection)
/// @dev Computes $DATA allocation based on pricing mode.
///      When contribution exceeds remaining supply, allocates remaining tokens and refunds excess ETH.
///      Increments contributorCount only when allocations[msg.sender] was previously 0.
/// @return allocation Amount of $DATA allocated for this contribution
function contribute(uint256 minAllocation) external payable nonReentrant whenNotPaused returns (uint256 allocation);

/// @notice Preview how much $DATA a given ETH amount would buy at current state
/// @param ethAmount Amount of ETH to simulate
/// @return dataAmount Estimated $DATA allocation
/// @return priceImpact Price change percentage (bonding curve only, 0 for tranches)
function preview(uint256 ethAmount) external view returns (uint256 dataAmount, uint256 priceImpact);

/// @notice Get current price per $DATA
/// @return price Current price in ETH (wei per 1e18 $DATA)
function currentPrice() external view returns (uint256 price);

/// @notice Get full presale progress info
/// @return raised Total ETH raised
/// @return sold Total $DATA sold
/// @return supply Total $DATA available
/// @return price Current price
/// @return contributors Number of unique contributors
function progress() external view returns (
    uint256 raised, uint256 sold, uint256 supply, uint256 price, uint256 contributors
);
```

> **L1 resolved:** `contribute()` takes a `minAllocation` parameter for slippage protection. If the computed allocation is less than `minAllocation`, the transaction reverts with `AllocationBelowMinimum`. This protects against stale `preview()` results.

> **L2 resolved:** `contributorCount` increments only when `allocations[msg.sender]` was previously 0, ensuring unique contributor count.

> **H5 resolved:** When a contribution exceeds remaining supply (in either tranche or bonding curve mode), the contract allocates remaining tokens and refunds excess ETH via low-level `call`. This is consistent across both pricing modes.

#### Owner-Only

```solidity
/// @notice Set presale configuration
/// @dev Only callable in PENDING state
function setConfig(PresaleConfig calldata _config) external onlyOwner;

/// @notice Extend the presale end time
/// @dev Callable in OPEN state. New end time must be > current end time.
function extendEndTime(uint256 newEndTime) external onlyOwner;

/// @notice Add a tranche (TRANCHE mode only, PENDING state)
/// @dev Price must be > previous tranche price (strictly ascending)
function addTranche(uint256 supply, uint256 pricePerToken) external onlyOwner;

/// @notice Remove all tranches and re-add (for reconfiguration)
/// @dev Only callable in PENDING state
function clearTranches() external onlyOwner;

/// @notice Set bonding curve parameters (BONDING_CURVE mode only, PENDING state)
/// @dev Reverts with EndPriceMustExceedStartPrice if endPrice <= startPrice
function setCurve(uint256 startPrice, uint256 endPrice, uint256 totalSupply) external onlyOwner;

/// @notice Open the presale for contributions
/// @dev Transitions: PENDING → OPEN. Sets openedAt = block.timestamp.
///      Validates pricing is configured:
///      - Tranche mode: tranches.length > 0
///      - Bonding curve: curve.totalSupply > 0 && curve.startPrice > 0 && curve.endPrice > curve.startPrice
function open() external onlyOwner;

/// @notice Finalize the presale — no more contributions
/// @dev Transitions: OPEN → FINALIZED (terminal). Cannot be called if REFUNDING.
function finalize() external onlyOwner;

/// @notice Withdraw raised ETH (only after finalized)
/// @dev Uses low-level call for ETH transfer (not transfer/send)
function withdrawETH(address to) external onlyOwner;

/// @notice Enable refunds — emergency exit, terminal state
/// @dev Transitions: OPEN → REFUNDING (terminal). Cannot be called if FINALIZED.
function enableRefunds() external onlyOwner;
```

> **M6 resolved:** `setConfig()` is restricted to PENDING state. `extendEndTime()` is callable in OPEN state, allowing the owner to extend the deadline without reconfiguring everything.

> **C2 resolved:** `setCurve()` enforces `endPrice > startPrice` with an explicit `EndPriceMustExceedStartPrice` revert. A flat curve (equal prices) is not supported — use tranche mode with a single tranche instead.

> **L5 resolved:** `withdrawETH()` uses low-level `call` for ETH transfer, not `transfer` or `send` (which forward only 2300 gas and can fail with contract recipients).

#### Emergency

```solidity
/// @notice Claim refund if refunds are enabled
/// @dev Only callable in REFUNDING state. Uses low-level call for ETH transfer.
///      Intentionally NOT gated by whenNotPaused — refunds must always be
///      available once enabled. This is an emergency exit and must not be blockable.
function refund() external nonReentrant;

/// @notice Dead-man's switch: if owner hasn't finalized or enabled refunds
///         within the emergency deadline, anyone can trigger refunds.
/// @dev Transitions: OPEN → REFUNDING (terminal). Permissionless.
///      Requires state == OPEN and block.timestamp > openedAt + config.emergencyDeadline.
function emergencyRefunds() external;
```

> **M1-NEW resolved:** `refund()` intentionally lacks `whenNotPaused`. Refunds are an emergency exit mechanism and must always be available once the REFUNDING state is reached. Pausing the contract cannot block refunds.

### Events

```solidity
event Contributed(
    address indexed contributor,
    uint256 ethAmount,
    uint256 dataAllocation,
    uint256 avgPrice,       // Average price paid in this contribution (ethAmount / dataAllocation)
    uint256 currentPrice    // Spot price after this contribution
);
event PresaleOpened(uint256 timestamp);
event PresaleFinalized(uint256 totalRaised, uint256 totalSold, uint256 contributors);
event ConfigUpdated(PresaleConfig config);
event TrancheCompleted(uint256 indexed trancheIndex, uint256 nextPrice);
event RefundsEnabled();
event Refunded(address indexed contributor, uint256 ethAmount);
event ETHWithdrawn(address indexed to, uint256 amount);
event EndTimeExtended(uint256 oldEndTime, uint256 newEndTime);
event EmergencyRefundsTriggered(address indexed triggeredBy, uint256 timestamp);
```

> **M1 resolved:** `Contributed` event emits both `avgPrice` (ethAmount / dataAllocation, the average price the contributor paid) and `currentPrice` (the spot price after the contribution). This eliminates ambiguity.

> **M4 resolved:** `ConfigUpdated` emits the full `PresaleConfig` struct.

> **M5 resolved:** `TrancheCompleted` event emitted when a contribution fills a tranche and pricing advances to the next.

### Pricing Logic

#### Tranche Mode

```
For a contribution of X ETH:

1. Determine current tranche from totalSold:
   - Compute cumulative supply boundaries from tranches[]
   - Current tranche = first tranche where cumulative supply > totalSold

2. Calculate how many $DATA X buys at current tranche price:
   tokens = X * 1e18 / tranche.pricePerToken

3. If tokens > remaining in current tranche:
   a. Allocate remaining at this tranche price
   b. Deduct corresponding ETH cost
   c. Emit TrancheCompleted(currentIndex, nextPrice)
   d. Advance to next tranche
   e. Spend remaining ETH at new tranche price
   f. Repeat until ETH exhausted or all tranches full

4. If all tranches full and ETH remains:
   Allocate what was available, refund remaining ETH via low-level call.
   Revert with ETHRefundFailed if the refund call returns false.
   Do NOT revert on partial fill itself — only on refund failure.

5. Revert only if totalSold == total supply BEFORE the contribution (fully sold out).
```

#### Bonding Curve Mode

Linear curve: `price(sold) = startPrice + (endPrice - startPrice) × sold / totalSupply`

```
For a contribution of X ETH when Y $DATA already sold:

The cost to buy from Y to Y+Z is the integral:
  cost = startPrice × Z + (endPrice - startPrice) × Z × (2Y + Z) / (2 × totalSupply)

We solve for Z given cost = X using PRBMathUD60x18 (see Appendix A).

If Z > totalSupply - Y: cap at remaining, refund excess ETH via low-level call.
Revert with ETHRefundFailed if the refund call returns false.
```

> **M4-NEW resolved:** All ETH refund calls (partial fills in both pricing modes) MUST `require(success)` on the low-level `call`. If the refund fails (e.g., contributor is a contract with a reverting receive), the entire transaction reverts. Users never lose excess ETH silently.

All math uses **PRBMathUD60x18** (`@prb/math@^4.0.0`) for fixed-point arithmetic. No inline safe math alternatives — PRBMath is the committed library for this contract.

---

## 4. Claim Contract

### `PresaleClaim.sol`

```
Inheritance: Ownable2Step, ReentrancyGuard, Pausable

Constructor args:
  IERC20 _dataToken           // The $DATA token
  IGhostPresale _presale      // The presale contract (reads allocations)
  uint256 _claimDeadline      // Unix timestamp after which owner can recover unclaimed tokens

Storage:
  IERC20 public immutable dataToken
  IGhostPresale public immutable presale
  uint256 public immutable claimDeadline       // e.g., 6 months after TGE
  bool public claimingEnabled                  // Owner enables after funding
  bool public recovered                        // True after recoverUnclaimed called — claims disabled
  mapping(address => bool) public claimed      // Has this address claimed?
  mapping(address => uint256) public snapshotted // Backup allocation snapshots
  uint256 public totalClaimed                  // Running total of claimed tokens
```

> **H1 resolved:** PresaleClaim inherits `Ownable2Step` for owner functions.

> **M2 resolved:** PresaleClaim inherits `Pausable` — owner can pause claims in an emergency.

> **M3 resolved:** `claimDeadline` is an immutable set at construction. `recoverUnclaimed()` requires `block.timestamp > claimDeadline`.

### Custom Errors

```solidity
error ClaimingNotEnabled();
error ClaimingClosed();           // After recoverUnclaimed, claims are disabled
error AlreadyClaimed();
error NoAllocation();
error InsufficientBalance(uint256 available, uint256 required);
error ClaimDeadlineNotReached(uint256 current, uint256 deadline);
error InvalidAddress();
```

### Functions

```solidity
/// @notice Claim $DATA allocation from presale
/// @dev Reads allocation from GhostPresale (or snapshot fallback), transfers tokens
function claim() external nonReentrant whenNotPaused returns (uint256 amount);

/// @notice Check claimable amount for an address
function claimable(address account) external view returns (uint256);

/// @notice Enable claiming (owner only, after contract is funded with $DATA)
/// @dev Verifies dataToken.balanceOf(address(this)) >= presale.totalSold()
function enableClaiming() external onlyOwner;

/// @notice Snapshot allocations from presale as local backup
/// @dev Owner-only. Copies allocations from GhostPresale into local storage.
///      Provides resilience against cross-contract read failures.
function snapshotAllocations(address[] calldata accounts) external onlyOwner;

/// @notice Recover unclaimed tokens after deadline (owner only)
/// @dev Requires block.timestamp > claimDeadline.
///      Transfers only the unclaimed portion: balanceOf(this) - (totalAllocated - totalClaimed).
///      After recovery, disables further claiming to prevent race conditions.
function recoverUnclaimed(address to) external onlyOwner;
```

> **H2 resolved:** `enableClaiming()` includes an explicit check: `if (dataToken.balanceOf(address(this)) < presale.totalSold()) revert InsufficientBalance(...)`. This prevents enabling claims when the contract is underfunded.

> **H3 resolved:** `snapshotAllocations()` lets the owner copy allocation data from GhostPresale into local `snapshotted` mapping. The `claim()` function reads from GhostPresale first; if that returns 0 and a snapshot exists, it falls back to the snapshot. This provides resilience against cross-contract dependency issues.

### Events

```solidity
event Claimed(address indexed claimer, uint256 amount);
event ClaimingEnabled(uint256 totalSupplyAvailable);
event AllocationsSnapshotted(uint256 count);
event UnclaimedRecovered(address indexed to, uint256 amount);
```

### Claim Logic

```
1. Require claimingEnabled == true
2. Require recovered == false (claims disabled after recovery)
3. Require paused == false
4. Require claimed[msg.sender] == false
5. Read allocation = presale.allocations(msg.sender)
6. If allocation == 0 and snapshotted[msg.sender] > 0:
     allocation = snapshotted[msg.sender]  // Fallback to backup snapshot
7. Require allocation > 0
8. Set claimed[msg.sender] = true
9. totalClaimed += allocation
10. Transfer allocation of $DATA to msg.sender (using SafeERC20)
11. Emit Claimed(msg.sender, allocation)
```

### Integration Note

The PresaleClaim contract must be **tax-excluded** on the DataToken. The $DATA minted to it should transfer to claimers without the 10% tax. The owner calls `dataToken.setTaxExclusion(presaleClaim, true)` after deployment.

> **No `receive()` or `fallback()` functions on PresaleClaim.** This contract handles tokens, not ETH. Direct ETH transfers revert.

> **M7 note:** Tax exclusion via `setTaxExclusion` is **bidirectional** by design — it excludes the address as both sender and recipient. This is intentional: presale claimers receive tokens tax-free FROM the claim contract, and any accidental transfers TO the claim contract are also tax-free. The DataToken `_update` function skips tax when `_taxExcluded[from] || _taxExcluded[to]`, which means excluding the PresaleClaim address covers both directions. This is the desired behavior.

---

## 5. Pricing Modes — Deep Dive

### Tranche Mode — Mental Model

```
    Price
    ▲
    │
$0.008 ┤              ┌─────────────┐
    │              │  TRANCHE 3   │
$0.005 ┤    ┌─────────┤  5M $DATA   │
    │    │TRANCHE 2│             │
$0.003 ┤────┤ 5M $DATA│             │
    │ T1 │         │             │
    │5M  │         │             │
    └────┴─────────┴─────────────┴───► $DATA sold
    0    5M        10M           15M
```

**Feed moments:** "TRANCHE 1 SOLD OUT — PRICE NOW $0.005" is a shareable event.

**Configuration flexibility:**
- Any number of tranches (1 to N)
- Any supply per tranche
- Any price per tranche (must be **strictly ascending** — enforced)
- Can be reconfigured before presale opens

**Current tranche derivation:** The current tranche is not tracked in storage. It is computed from `totalSold` and the cumulative sum of `tranches[i].supply`. This eliminates redundant state.

> **L1-NEW note:** Due to integer division, tranche boundaries may not align exactly with `totalSold`. A tranche may have up to 1 wei of "dust" remaining after a contribution that nominally fills it. The derivation handles this naturally — any dust is allocated at that tranche's price on the next contribution. The economic impact is negligible (sub-wei).

### Bonding Curve Mode — Mental Model

```
    Price
    ▲
    │
 end ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╱
    │                            ╱
    │                         ╱
    │                      ╱
    │                   ╱
    │                ╱ ◄── continuous, every contribution moves it
    │             ╱
    │          ╱
    │       ╱
start┤────╱
    │
    └─────────────────────────────────► $DATA sold
    0                            supply
```

**Feed moments:** Every contribution moves the price. Constant content. "Price just crossed $0.005!"

**Configuration:**
- Start price, end price, total supply — all configurable
- **endPrice must be strictly greater than startPrice** — flat curves are not supported (use single-tranche mode instead)
- Linear curve only for v1 — simplest to audit, most predictable

### Why Not Both Simultaneously?

Complexity with no benefit. Pick one per deployment. The contract supports both — just deploy with the mode you want. If you want to experiment, deploy on testnet with each mode and see which feels better.

---

## 6. Frontend — The Presale Page

### Route

`/presale` — Standalone page, not a modal. This is the landing page pre-launch.

### Page Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│  ░░░ SIGNAL INTERCEPTED ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  GHOSTNET PRE-LAUNCH TRANSMISSION                                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 1: HERO                                                     │
│  ──────────────────                                                  │
│  A network is coming. Jack in. Survive trace scans.                  │
│  Extract gains. When others die, you profit.                         │
│                                                                      │
│  LP BURNED 🔥 │ TEAM 24mo VEST │ 30% DEATH BURN │ MEGAETH           │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 2: PRICING + PROGRESS                                       │
│  ──────────────────────────────                                      │
│                                                                      │
│  [TRANCHE MODE]                    [BONDING CURVE MODE]              │
│  ┌──────────────────────┐          ┌──────────────────────┐          │
│  │ T1: $0.003  ████ 89% │          │      ╱               │          │
│  │ T2: $0.005  ░░░░     │    OR    │    ╱  YOU ARE HERE   │          │
│  │ T3: $0.008  ░░░░     │          │  ╱                   │          │
│  └──────────────────────┘          └──────────────────────┘          │
│                                                                      │
│  RAISED: ██.██ ETH │ SOLD: ██M / 15M $DATA │ ███ CONTRIBUTORS       │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 3: CONTRIBUTION FORM                                        │
│  ─────────────────────────────                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  AMOUNT (ETH):  [ 0.1____________ ]  [MAX]                   │    │
│  │                                                              │    │
│  │  YOU RECEIVE:   33,333 $DATA                                 │    │
│  │  PRICE:         $0.003 / $DATA                               │    │
│  │  PRICE IMPACT:  +0.02% (curve only)                          │    │
│  │  SLIPPAGE:      min 33,000 $DATA                             │    │
│  │                                                              │    │
│  │  [ CONNECT WALLET ]   or   [ ACQUIRE $DATA ]                 │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 4: LIVE FEED                                                │
│  ─────────────────────                                               │
│  > 0x7a3f acquired 50,000 $DATA (0.15 ETH)              2m ago      │
│  > 0x9c2d acquired 200,000 $DATA (0.60 ETH) 🐋          5m ago      │
│  > TRANCHE 1: 89% FILLED                                            │
│  > 0x3b1a acquired 10,000 $DATA (0.03 ETH)              8m ago      │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 5: YOUR POSITION (post-contribution)                        │
│  ─────────────────────────────────────────────                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  ACQUIRED:      50,000 $DATA                                 │    │
│  │  CONTRIBUTED:   0.15 ETH                                     │    │
│  │  AVG PRICE:     $0.003 / $DATA                               │    │
│  │  RANK:          #47 of 312 contributors                      │    │
│  │  CLAIM:         AT TGE  [COUNTDOWN]                           │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 6: TOKENOMICS                                               │
│  ─────────────────────                                               │
│  Supply: 100M │ Presale: 15% │ LP: 9% (BURNED) │ Team: 8% (vested) │
│  Game: 60% │ Treasury: 8%                                            │
│                                                                      │
│  5 BURN ENGINES: Death tax, ETH toll, trading tax, bet rake, items   │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SECTION 7: TRUST ANCHORS                                            │
│  ─────────────────────────                                           │
│  Contract: 0x... (verified on explorer)                              │
│  Pricing mode: TRANCHE │ Total supply: 15M $DATA                     │
│  Owner: 0x... │ Source: github.com/ghostnet/contracts                │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Boot Sequence (First Load)

When the page loads, a 2-3 second terminal boot plays:

```
> Scanning frequencies...
> ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
> SIGNAL DETECTED
> Decrypting transmission...
> SOURCE: GHOSTNET
> STATUS: PRE-LAUNCH
> PRESALE: ACTIVE
>
> Establishing connection...
```

This is **skippable** (click/key to skip). Returning visitors skip it automatically (localStorage flag). The boot creates atmosphere without blocking repeat users.

### Real-Time Updates

The page listens to `Contributed` events from the presale contract. Every contribution:
- Appears in the live feed section
- Updates raised/sold/contributors counts
- Updates pricing display (tranche progress or curve position)
- Whale contributions (>threshold) get highlighted with 🐋

On MegaETH with sub-ms finality, this feed updates in real-time. The presale page **trains users to watch a live feed** — the exact behavior the game needs.

### Post-Contribution Confirmation

After a successful contribution, the form area transforms:

```
> ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
> ALLOCATION CONFIRMED
> 50,000 $DATA reserved for 0x7a3f
> Claim available at TGE
>
> Welcome to GHOSTNET, operator.
> The network remembers.
```

Typing animation. Terminal green. A moment, not a toast notification.

### States

| Page State | Condition | Display |
|------------|-----------|---------|
| **NOT STARTED** | `state == PENDING` or `block.timestamp < startTime` | Countdown to open + teaser info |
| **LIVE** | `state == OPEN` and within time bounds | Full contribution form |
| **SOLD OUT** | All supply allocated | "PRESALE COMPLETE" + stats summary |
| **ENDED** | `state == FINALIZED` or past endTime | "PRESALE CLOSED" + stats + claim info |
| **REFUNDING** | `state == REFUNDING` | "REFUNDS ENABLED" + refund button for contributors |
| **CLAIM ACTIVE** | PresaleClaim deployed + enabled | Claim button appears for contributors |
| **CLAIMED** | User has already claimed | Shows claimed amount + link to game |

> **L3 resolved:** REFUNDING state added to frontend state table.

> **L3-NEW note (frontrunning open()):** Setting `startTime` to a future timestamp (e.g., 10 minutes after planned `open()` call) provides frontrun protection for the presale opening. Without a `startTime`, the first contributor to react after the `open()` transaction lands gets the lowest price. Recommend always setting `startTime` to a known public time.

---

## 7. Integration With DataToken

### At Token Deploy Time

The DataToken constructor takes `recipients[]` and `amounts[]`. The presale allocation flows to the PresaleClaim contract:

```
DataToken constructor recipients:
  [0] RewardsDistributor  → 60,000,000 $DATA  (The Mine)
  [1] PresaleClaim         → presale supply     (Presale — default 15,000,000)
  [2] LP address           →  9,000,000 $DATA  (Liquidity — then burn LP tokens)
  [3] TeamVesting          →  8,000,000 $DATA  (Team)
  [4] Treasury multisig    →  8,000,000 $DATA  (Treasury)
```

### Tax Exclusion

After DataToken deployment, owner calls:
```solidity
dataToken.setTaxExclusion(address(presaleClaim), true);
```

This ensures presale claimers receive their full allocation without the 10% transfer tax.

> **M7 note:** This exclusion is bidirectional by design. See §4 Integration Note for details.

### TGE Deployment Checklist

**CRITICAL ordering — steps must be performed in this exact sequence:**

```
□ 1. Deploy PresaleClaim(dataToken, presale, claimDeadline)
□ 2. Deploy DataToken with PresaleClaim address in recipients[]
       → Verify: dataToken.balanceOf(presaleClaim) == presale supply
□ 3. CRITICAL: dataToken.setTaxExclusion(address(presaleClaim), true)
       → Verify: dataToken.isExcludedFromTax(presaleClaim) == true
       ⚠️  FAILURE TO DO THIS BEFORE STEP 4 CAUSES CLAIMERS TO LOSE 10% TO TAX
□ 4. presaleClaim.enableClaiming()
       → Verify: will revert if balance < totalSold (H2 protection)
□ 5. Announce claiming is live
```

> **L4-NEW resolved:** Tax exclusion MUST be set BEFORE `enableClaiming()`. This is the most dangerous ordering dependency — silent 10% loss if violated. The checklist makes the ordering explicit and verifiable.

---

## 8. Security Considerations

### Presale Contract

| Risk | Mitigation |
|------|------------|
| Reentrancy on contribute() | ReentrancyGuard + checks-effects-interactions |
| ETH stuck in contract | withdrawETH() only after FINALIZED; enableRefunds() as escape hatch leading to terminal REFUNDING state |
| Refund/finalize race condition | FINALIZED and REFUNDING are mutually exclusive terminal states; both require state == OPEN |
| Overflow in curve math | Solidity 0.8.33 built-in overflow checks + PRBMathUD60x18 for fixed-point |
| Front-running contributions | Acceptable — presale is not an auction, all contributors get their price. `minAllocation` provides slippage protection |
| Owner rug (withdraw before finalize) | withdrawETH requires FINALIZED state |
| Precision loss in curve | PRBMathUD60x18 provides 18-decimal fixed-point. See Appendix A for quadratic solver. Fuzz test required (see §8.3) |
| Dust contributions | minContribution config prevents spam |
| Multiple contributions bypass | `allowMultipleContributions` flag; if false, revert if allocations[msg.sender] > 0 |
| Division by zero (flat curve) | setCurve enforces endPrice > startPrice with explicit revert |
| Sybil attacks via maxPerWallet | maxPerWallet is a UX guardrail only — documented, not relied upon for security |
| ETH transfer failures | All ETH transfers use low-level `call` with `require(success)`. Failed refund reverts entire tx |
| Partial fill on sold-out | Contribution allocates remaining tokens, refunds excess ETH. Reverts if refund fails |
| Owner key loss | `emergencyRefunds()` — permissionless dead-man's switch after `emergencyDeadline` |
| Open without pricing | `open()` validates tranches/curve are configured. Reverts with `PricingNotConfigured` |
| Direct ETH transfers | No `receive()`/`fallback()` — direct ETH transfers revert |
| Frontrunning open() | Set `startTime` to future timestamp for protection (see §6 note) |

### Claim Contract

| Risk | Mitigation |
|------|------------|
| Double claim | `claimed` mapping, checked before transfer |
| Insufficient $DATA balance | `enableClaiming()` verifies `balanceOf >= totalSold` |
| Unclaimed tokens locked forever | `recoverUnclaimed()` requires `block.timestamp > claimDeadline`. Transfers only unclaimed portion. Disables further claims after recovery |
| Recovery/claim race | `recoverUnclaimed()` sets `recovered = true`, blocking further claims. Recovers `balance - (totalSold - totalClaimed)` only |
| Presale contract compromised | `snapshotAllocations()` backup; PresaleClaim reads allocations via view — no state mutation risk |
| Missing Ownable | Inherits Ownable2Step |
| No emergency pause | Inherits Pausable |
| GhostPresale upgraded/destroyed | GhostPresale is immutable by design (not upgradeable, no selfdestruct). Documented as invariant. |

### Invariants

These properties must **never** be violated:

```
// Conservation
totalSold == sum(allocations[addr]) for all addresses
totalRaised == sum(contributions[addr]) for all addresses
address(this).balance >= totalRaised (until withdrawETH or refunds)

// State machine
state transitions: PENDING→OPEN→FINALIZED | OPEN→REFUNDING (only)
FINALIZED and REFUNDING are terminal — no further transitions

// Pricing
currentPrice() is monotonically non-decreasing (both modes)
Every contribution receives tokens at the correct price for totalSold at time of execution

// Claim
totalClaimed <= dataToken.balanceOf(address(presaleClaim)) at enableClaiming time
Each address can claim exactly once
claimed[addr] == true implies allocation was transferred
```

### Required Fuzz Test Ranges

The bonding curve math MUST be fuzz tested across these ranges:

| Parameter | Min | Max | Notes |
|-----------|-----|-----|-------|
| ethAmount | 1 wei | 10,000 ether | Test dust and whale contributions |
| startPrice | 1e6 (0.000000000001 ETH) | 1e18 (1 ETH per token) | Wide price range |
| endPrice | startPrice + 1 | 10 × startPrice | Must be > startPrice |
| totalSupply | 1e18 (1 token) | 1e26 (100M tokens) | Full range |
| currentSold | 0 | totalSupply - 1 | Empty to nearly full |

**Minimum fuzz runs:** 100,000 for curve math, 10,000 for tranche math.

**Properties to verify under fuzz:**
- `tokensReceived > 0` for any `ethAmount >= minContribution` when supply remains
- `actualCost <= ethAmount` (never charge more than sent)
- `excessRefund == ethAmount - actualCost` (exact refund)
- `totalSold` never exceeds `totalSupply`
- No revert for valid inputs within bounds

### Audit Scope

Both contracts are in scope for security review. The presale contract handles ETH directly, making it high-priority. The bonding curve math is the highest-risk component — precision edge cases around very small and very large contributions need thorough fuzz testing as specified above.

---

## 9. Configuration Reference

Every configurable parameter in one place:

### Deploy-Time (Immutable)

| Parameter | Type | Description |
|-----------|------|-------------|
| `pricingMode` | enum | TRANCHE or BONDING_CURVE — set at construction |
| `owner` | address | Ownable2Step initial owner |

### Pre-Open Configuration (setConfig, PENDING state only)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `minContribution` | uint256 | 0 | Min ETH per transaction (0 = no min) |
| `maxContribution` | uint256 | 0 | Max ETH per transaction (0 = no max) |
| `maxPerWallet` | uint256 | 0 | Max total ETH per wallet (0 = unlimited). **UX guardrail only — not sybil-resistant.** |
| `allowMultipleContributions` | bool | true | Allow same wallet to contribute again |
| `startTime` | uint256 | 0 | Presale start (0 = when open() called). Recommend setting to future time to prevent frontrunning open() |
| `endTime` | uint256 | 0 | Presale deadline (0 = no deadline) |
| `emergencyDeadline` | uint256 | 90 days | Seconds after open() when anyone can trigger emergency refunds. Dead-man's switch for owner key loss |

### Open-State Configuration (extendEndTime only)

| Parameter | Type | Description |
|-----------|------|-------------|
| `endTime` | uint256 | New end time, must be > current endTime |

### Tranche Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `tranches[i].supply` | uint256 | $DATA available in tranche i |
| `tranches[i].pricePerToken` | uint256 | ETH per 1e18 $DATA in tranche i |

Constraints:
- At least 1 tranche required
- Prices must be **strictly ascending** (`tranches[i+1].pricePerToken > tranches[i].pricePerToken`)
- Sum of tranche supplies = total presale allocation (configurable, default 15M $DATA)

### Curve Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `curve.startPrice` | uint256 | Price at sold=0 (ETH per 1e18 $DATA) |
| `curve.endPrice` | uint256 | Price at sold=totalSupply |
| `curve.totalSupply` | uint256 | Total $DATA available on curve |

Constraints:
- `endPrice > startPrice` (strictly — enforced with `EndPriceMustExceedStartPrice` revert)
- `startPrice > 0`
- `totalSupply > 0`

### PresaleClaim Parameters (deploy-time)

| Parameter | Type | Description |
|-----------|------|-------------|
| `dataToken` | address | The $DATA token (immutable) |
| `presale` | address | The GhostPresale contract (immutable) |
| `claimDeadline` | uint256 | Timestamp after which unclaimed tokens can be recovered (immutable) |

---

## 10. Open Parameters

These need values before implementation begins. Provided as suggestions — owner can change at any time pre-open.

| Parameter | Suggested Value | Notes |
|-----------|----------------|-------|
| Pricing mode | TBD | Tranche or Bonding Curve |
| Presale supply | 15,000,000 $DATA | Default per manifesto — configurable |
| Tranche 1 price | $0.003 / $DATA | ~40% discount to launch FDV |
| Tranche 2 price | $0.005 / $DATA | Launch price per manifesto |
| Tranche 3 price | $0.008 / $DATA | ~60% premium over launch |
| Tranche supplies | 5M / 5M / 5M | Equal splits |
| Curve start price | $0.002 / $DATA | ~60% discount |
| Curve end price | $0.010 / $DATA | 2x launch price |
| Curve supply | 15,000,000 $DATA | Full presale allocation |
| Min contribution | 0.01 ETH | Prevent dust |
| Max per wallet | None (0) | UX guardrail only |
| Multiple contributions | true | Allow topping up |
| Start time | TBD | Launch date. Set to future time to prevent frontrunning open() |
| End time | None (0) | Ends when sold out or finalized |
| Emergency deadline | 90 days | Dead-man's switch for owner key loss |
| Claim deadline | TGE + 6 months | After this, owner can recover unclaimed (disables further claims) |

---

## Appendix A: Bonding Curve Math — Detailed

### The Curve

Linear: `price(s) = P₀ + (P₁ - P₀) · s / S`

Where:
- `s` = total $DATA sold so far
- `S` = total supply on curve
- `P₀` = start price (must be > 0)
- `P₁` = end price (must be > P₀, enforced by `setCurve`)

### Cost to Buy Z Tokens Starting at Y Sold

```
cost = ∫(Y to Y+Z) price(s) ds
     = ∫(Y to Y+Z) [P₀ + (P₁ - P₀) · s / S] ds
     = P₀·Z + (P₁ - P₀)/(2S) · [(Y+Z)² - Y²]
     = P₀·Z + (P₁ - P₀)/(2S) · Z · (2Y + Z)
```

### Tokens Received for X ETH Starting at Y Sold

Solve for Z in: `P₀·Z + (P₁ - P₀)/(2S) · Z · (2Y + Z) = X`

Let:
- `a = (P₁ - P₀) / (2S)` — always > 0 since P₁ > P₀ (enforced)
- `b = P₀ + (P₁ - P₀) · Y / S` — price at current sold level
- `c = X` — ETH contributed

Quadratic: `a·Z² + b·Z - c = 0`

```
Z = (-b + √(b² + 4ac)) / (2a)
```

We take the positive root. Since `a > 0`, `b > 0`, `c > 0`, the discriminant `b² + 4ac > b²`, so `√(b² + 4ac) > b`, and Z > 0. No division by zero is possible because `a > 0` is guaranteed by the `endPrice > startPrice` invariant.

### PRBMathUD60x18 Implementation

All arithmetic uses **PRBMathUD60x18** (Paul Razvan Berg's fixed-point math library). This library represents numbers as `uint256` with 18 decimal places of precision (i.e., `1.0 = 1e18`).

**Why PRBMath and not inline scaling:**
- Audited library with known precision characteristics
- Provides `sqrt`, `mul`, `div` with correct rounding for 60x18 fixed-point
- Eliminates the class of intermediate-truncation bugs where `a / b * c` loses precision
- Industry standard for DeFi bonding curve math

```solidity
import { UD60x18, ud, unwrap, sqrt as prb_sqrt } from "@prb/math/UD60x18.sol";

/// @notice Compute tokens received for a given ETH contribution on the bonding curve
/// @dev Uses PRBMathUD60x18 for all intermediate arithmetic to prevent precision loss.
///      The quadratic formula Z = (-b + sqrt(b² + 4ac)) / (2a) is computed in UD60x18 space.
/// @param ethAmount ETH contributed (in wei, 18 decimals)
/// @param currentSold $DATA already sold (in wei, 18 decimals)
/// @return tokens $DATA tokens to allocate (in wei, 18 decimals)
function _curveTokensForETH(uint256 ethAmount, uint256 currentSold) internal view returns (uint256 tokens) {
    uint256 P0 = curve.startPrice;
    uint256 P1 = curve.endPrice;
    uint256 S = curve.totalSupply;
    uint256 Y = currentSold;

    // All values are already in 18-decimal wei, compatible with UD60x18

    // slope = P1 - P0 (always > 0, enforced by setCurve)
    UD60x18 slope = ud(P1 - P0);
    UD60x18 supply = ud(S);

    // a = slope / (2 * S)
    UD60x18 a = slope.div(supply.mul(ud(2e18)));

    // b = P0 + slope * Y / S  (current spot price)
    UD60x18 b = ud(P0).add(slope.mul(ud(Y)).div(supply));

    // c = ethAmount
    UD60x18 c = ud(ethAmount);

    // discriminant = b² + 4ac
    UD60x18 disc = b.mul(b).add(ud(4e18).mul(a).mul(c));

    // Z = (sqrt(disc) - b) / (2a)
    UD60x18 sqrtDisc = prb_sqrt(disc);
    UD60x18 twoA = a.mul(ud(2e18));
    UD60x18 Z = (sqrtDisc.sub(b)).div(twoA);

    tokens = unwrap(Z);

    // Cap at remaining supply
    uint256 remaining = S - Y;
    if (tokens > remaining) {
        tokens = remaining;
    }
}
```

**Precision notes:**
- PRBMathUD60x18 maintains 18 decimals throughout. No intermediate truncation.
- The `sqrt` function uses the Babylonian method with 18-decimal precision.
- The subtraction `sqrtDisc - b` is safe because `disc > b²` implies `sqrt(disc) > b`.
- For very small `ethAmount` (< ~1e6 wei), the allocation may round to 0. The `minAllocation` parameter on `contribute()` protects users from this.
- For very large `ethAmount` that exceeds remaining supply, the cap-and-refund path handles the excess.

### Cost Verification Function

After computing Z tokens, verify the actual cost to prevent rounding from overcharging:

```solidity
/// @notice Compute the ETH cost of buying Z tokens starting at Y sold
/// @dev Used to verify allocation and compute exact refund
function _curveCostForTokens(uint256 tokenAmount, uint256 currentSold) internal view returns (uint256 cost) {
    UD60x18 Z = ud(tokenAmount);
    UD60x18 Y_val = ud(currentSold);
    UD60x18 P0 = ud(curve.startPrice);
    UD60x18 slope = ud(curve.endPrice - curve.startPrice);
    UD60x18 S = ud(curve.totalSupply);

    // cost = P0 * Z + slope * Z * (2Y + Z) / (2S)
    UD60x18 term1 = P0.mul(Z);
    UD60x18 term2 = slope.mul(Z).mul(Y_val.mul(ud(2e18)).add(Z)).div(S.mul(ud(2e18)));

    cost = unwrap(term1.add(term2));
}
```

The `contribute()` function computes Z via `_curveTokensForETH`, then verifies cost via `_curveCostForTokens`, and refunds `ethAmount - cost` if there's any excess.

---

## Appendix B: Session Log

### 2026-01-28: Initial Design

**Decisions made:**
- Two-contract architecture (presale + claim) — separates ETH collection from token distribution
- Support both tranche and bonding curve pricing — selected at deploy time, not runtime switchable
- Everything configurable by owner pre-open — no hardcoded economics
- Claim reads directly from presale contract — no merkle tree needed
- PresaleClaim must be tax-excluded on DataToken
- Linear bonding curve for v1 — simplest to audit, most predictable

**Assumptions:**
- MegaETH is the only network (no cross-chain presale)
- ETH is the only contribution currency
- $DATA token does not need to exist at presale deploy time
- Presale supply (default 15M $DATA) matches manifesto — but supply is configurable
- Owner is a trusted EOA or multisig — no on-chain governance for presale parameters

**Bets:**
- Linear curve is sufficient — we don't need polynomial/exponential for a presale
- Two contracts is cleaner than one — even though it adds a deploy step, it separates concerns cleanly
- Reading allocations cross-contract is cheaper than duplicating state — single source of truth
- The presale page IS the first GHOSTNET experience — treating it as marketing, not just infrastructure

### 2026-01-28: Security/Architecture Review — All Findings Addressed (v2.0)

**Review summary:** 3 critical, 5 high, 7 medium, 5 low, 6 nitpick findings. All resolved in this version.

**Critical fixes:**
- **C1:** Committed to PRBMathUD60x18. Rewrote bonding curve pseudocode with correct fixed-point arithmetic. Added fuzz test ranges and precision notes. Removed "or inline safe math" language.
- **C2:** `setCurve()` now enforces `endPrice > startPrice` with `EndPriceMustExceedStartPrice` custom error. Flat curve language removed. Division by zero is structurally impossible.
- **C3:** Added `REFUNDING` as terminal state. State machine: `PENDING → OPEN → FINALIZED` OR `OPEN → REFUNDING`. Both `finalize()` and `enableRefunds()` require state == OPEN. Mutually exclusive terminal paths.

**High fixes:**
- **H1:** PresaleClaim inherits `Ownable2Step`.
- **H2:** `enableClaiming()` verifies `dataToken.balanceOf(address(this)) >= presale.totalSold()`.
- **H3:** Documented GhostPresale as non-upgradeable/non-destructable. Added `snapshotAllocations()` backup function on PresaleClaim.
- **H4:** Documented `maxPerWallet` as UX guardrail, not sybil-resistant.
- **H5:** Both tranche and bonding curve modes allocate remaining tokens and refund excess ETH when contribution exceeds remaining supply.

**Medium fixes:**
- **M1:** `Contributed` event emits both `avgPrice` and `currentPrice`.
- **M2:** PresaleClaim inherits `Pausable`.
- **M3:** `recoverUnclaimed()` requires `block.timestamp > claimDeadline` (immutable, set at construction).
- **M4:** `ConfigUpdated` event emits full `PresaleConfig` struct.
- **M5:** Added `TrancheAdvanced(uint256 indexed trancheIndex, uint256 newPrice)` event.
- **M6:** Added `extendEndTime()` callable in OPEN state. `setConfig` remains PENDING-only.
- **M7:** Documented bidirectional tax exclusion as intentional.

**Low fixes:**
- **L1:** Added `minAllocation` parameter to `contribute()` for slippage protection.
- **L2:** Specified `contributorCount` increments only when `allocations[msg.sender]` was previously 0.
- **L3:** Added REFUNDING state to frontend state table.
- **L4:** Documented no-allowlist as conscious omission.
- **L5:** Specified all ETH transfers use low-level `call`.

**Nitpick fixes:**
- **N1:** Documented contribute/acquire verb mapping.
- **N2:** REFUNDING state added (addressed by C3).
- **N3:** Committed to PRBMath exclusively (addressed by C1).
- **N4:** Removed `sold` from `TrancheConfig` and `CurveConfig`. `totalSold` is single source of truth.
- **N5:** ADR expanded with gas, max raise, and precision testing sections.
- **N6:** Parameterized presale supply throughout — "presale supply (default: 15M $DATA)".

### 2026-01-28: Second Review — All New Findings Addressed (v3.0)

**Review summary:** 26/26 previous fixes verified ✅. 1 new high, 5 new medium, 4 new low, 3 new nitpick findings. All resolved.

**High fix:**
- **H1-NEW:** Added `emergencyRefunds()` — permissionless dead-man's switch. After `emergencyDeadline` (configurable, default 90 days post-open), any address can trigger REFUNDING state. Owner key loss can never permanently lock user ETH.

**Medium fixes:**
- **M1-NEW:** Documented `refund()` intentionally lacks `whenNotPaused`. Emergency exit must not be blockable by pause.
- **M2-NEW:** `recoverUnclaimed()` now transfers only `balance - (totalSold - totalClaimed)` (unclaimed portion only). Sets `recovered = true` to disable further claims, preventing race conditions.
- **M3-NEW:** `open()` validates pricing is configured (tranches.length > 0 or curve params set). Reverts with `PricingNotConfigured`.
- **M4-NEW:** All ETH refund calls require `success`. Failed refund reverts entire transaction with `ETHRefundFailed`. Users never lose excess ETH silently.
- **M5-NEW:** Explicitly specified no `receive()`/`fallback()` on both GhostPresale and PresaleClaim. Direct ETH transfers revert.

**Low fixes:**
- **L1-NEW:** Documented tranche boundary dust from integer division (sub-wei, negligible).
- **L2-NEW:** `clearTranches()` specified as PENDING-state-only.
- **L3-NEW:** Documented `startTime` strategy for frontrunning `open()` protection.
- **L4-NEW:** Added TGE Deployment Checklist with explicit ordering. Tax exclusion MUST be set before `enableClaiming()`.

**Nitpick fixes:**
- **N1-NEW:** Renamed `multipleContributions` → `allowMultipleContributions`.
- **N2-NEW:** Renamed `TrancheAdvanced` → `TrancheCompleted`.
- **N3-NEW:** Pinned PRBMath to `@prb/math@^4.0.0`.
