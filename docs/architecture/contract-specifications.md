# GHOSTNET Contract Specifications

**Version:** 1.1  
**Date:** January 2026  
**Status:** Ready for Implementation

---

## Compiler Requirements

| Requirement | Value |
|-------------|-------|
| **Solidity Version** | `^0.8.33` (minimum `0.8.28` for transient storage) |
| **EVM Target** | `prague` (for MegaETH compatibility) |
| **Optimizer** | Enabled, 200 runs |

### Foundry Configuration

```toml
[profile.default]
solc_version = "0.8.33"
evm_version = "prague"
optimizer = true
optimizer_runs = 200
```

### Dependencies (OpenZeppelin 5.x)

| Package | Version | Usage |
|---------|---------|-------|
| `@openzeppelin/contracts` | 5.x | Immutable contracts |
| `@openzeppelin/contracts-upgradeable` | 5.x | UUPS proxies |

### ReentrancyGuard Selection

MegaETH targets Prague EVM which supports EIP-1153 transient storage. Use transient variants for ~50% gas savings:

| Contract Type | Recommended Guard | Import Path |
|--------------|-------------------|-------------|
| Upgradeable (UUPS) | `ReentrancyGuardTransientUpgradeable` | `@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol` |
| Immutable | `ReentrancyGuardTransient` | `@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol` |

**Gas Comparison:**
| Operation | Standard Guard | Transient Guard |
|-----------|---------------|-----------------|
| First call (cold) | ~2,900 gas | ~200 gas |
| Subsequent (warm) | ~200 gas | ~200 gas |
| Unlock on exit | ~100 gas | 0 gas (auto-clears) |

**Requirements:**
- Solidity ≥0.8.24 (transient storage support)
- EVM target: `cancun` or `prague`

**Fallback:** If deploying to a chain without EIP-1153, use standard `ReentrancyGuardUpgradeable`. The contract specifications below show `ReentrancyGuardUpgradeable` in the inheritance list, but implementations SHOULD use the transient variant on MegaETH.

### Pragma Format

All contracts MUST use:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
```

---

## ERC-7201 Storage Slot Locations

GHOSTNET uses ERC-7201 namespaced storage for all upgradeable contracts to prevent storage slot collisions during upgrades.

### Computed Slot Values

| Contract | Namespace | Computed Slot |
|----------|-----------|---------------|
| GhostCore | `ghostnet.storage.GhostCore` | `0x47484f53544e45542e73746f726167652e47686f7374436f7265000000000000` |
| TraceScan | `ghostnet.storage.TraceScan` | `0x47484f53544e45542e73746f726167652e5472616365536361000000000000000` |
| RewardsDistributor | `ghostnet.storage.RewardsDistributor` | `0x47484f53544e45542e73746f726167652e5265776172647344697374726962757400` |
| DeadPool | `ghostnet.storage.DeadPool` | `0x47484f53544e45542e73746f726167652e44656164506f6f6c00000000000000` |

### Slot Computation Formula

Storage slots are computed per [ERC-7201](https://eips.ethereum.org/EIPS/eip-7201):

```solidity
/// @notice Compute ERC-7201 storage slot for a namespace
/// @param namespace The string namespace (e.g., "ghostnet.storage.GhostCore")
/// @return slot The computed storage slot
function computeStorageSlot(string memory namespace) internal pure returns (bytes32) {
    return keccak256(abi.encode(uint256(keccak256(bytes(namespace))) - 1)) & ~bytes32(uint256(0xff));
}
```

### Usage in Contracts

Each upgradeable contract follows this pattern:

```solidity
// Storage namespace declaration
/// @custom:storage-location erc7201:ghostnet.storage.GhostCore
struct GhostCoreStorage {
    // ... storage variables
}

// Computed slot constant
bytes32 private constant GHOSTCORE_STORAGE_LOCATION = 
    0x47484f53544e45542e73746f726167652e47686f7374436f7265000000000000;

// Storage accessor function
function _getGhostCoreStorage() private pure returns (GhostCoreStorage storage $) {
    assembly {
        $.slot := GHOSTCORE_STORAGE_LOCATION
    }
}
```

### Verification Script

Use this Foundry script to verify computed slots match expected values:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";

contract VerifyStorageSlots is Script {
    function run() public pure {
        // GhostCore
        bytes32 ghostCore = keccak256(
            abi.encode(uint256(keccak256("ghostnet.storage.GhostCore")) - 1)
        ) & ~bytes32(uint256(0xff));
        console.logBytes32(ghostCore);
        
        // TraceScan
        bytes32 traceScan = keccak256(
            abi.encode(uint256(keccak256("ghostnet.storage.TraceScan")) - 1)
        ) & ~bytes32(uint256(0xff));
        console.logBytes32(traceScan);
        
        // RewardsDistributor
        bytes32 rewards = keccak256(
            abi.encode(uint256(keccak256("ghostnet.storage.RewardsDistributor")) - 1)
        ) & ~bytes32(uint256(0xff));
        console.logBytes32(rewards);
        
        // DeadPool
        bytes32 deadPool = keccak256(
            abi.encode(uint256(keccak256("ghostnet.storage.DeadPool")) - 1)
        ) & ~bytes32(uint256(0xff));
        console.logBytes32(deadPool);
    }
}
```

**Important:** Before each upgrade, verify that the new implementation uses the same storage slot and that no fields have been reordered or removed from the storage struct. Fields may only be appended.

---

## Table of Contents

1. [Contract Overview](#1-contract-overview)
2. [Deployment Order & Dependencies](#2-deployment-order--dependencies)
3. [DataToken.sol](#3-datatokensol)
4. [TeamVesting.sol](#4-teamvestingsol)
5. [GhostCore.sol](#5-ghostcoresol)
6. [TraceScan.sol](#6-tracescansol)
7. [RewardsDistributor.sol](#7-rewardsdistributorsol)
8. [DeadPool.sol](#8-deadpoolsol)
9. [FeeRouter.sol](#9-feeroutersol)
10. [Governance Contracts](#10-governance-contracts)
11. [Libraries](#11-libraries)
12. [Interfaces](#12-interfaces)

---

## 1. Contract Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CONTRACT DEPENDENCY GRAPH                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                            ┌──────────────┐                             │
│                            │  DataToken   │                             │
│                            │  (ERC20)     │                             │
│                            └──────┬───────┘                             │
│                                   │                                      │
│            ┌──────────────────────┼──────────────────────┐              │
│            │                      │                      │              │
│            ▼                      ▼                      ▼              │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐         │
│   │ TeamVesting  │      │  GhostCore   │      │  DeadPool    │         │
│   │              │      │  (UUPS)      │      │  (UUPS)      │         │
│   └──────────────┘      └──────┬───────┘      └──────────────┘         │
│                                │                                        │
│                    ┌───────────┼───────────┐                           │
│                    │           │           │                           │
│                    ▼           ▼           ▼                           │
│           ┌──────────────┐ ┌────────┐ ┌──────────────┐                 │
│           │  TraceScan   │ │Rewards │ │  FeeRouter   │                 │
│           │  (UUPS)      │ │Distrib │ │              │                 │
│           └──────────────┘ └────────┘ └──────────────┘                 │
│                                                                          │
│  LEGEND:                                                                │
│  ─────────────────────────────────────────────────────────────────────  │
│  Solid box = Contract                                                   │
│  Arrow = Dependency (points to what it depends on)                      │
│  (UUPS) = Upgradeable via UUPS proxy                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Contract Summary

| Contract | Type | Upgradeable | Description |
|----------|------|-------------|-------------|
| DataToken | ERC20 | No | Token with 10% transfer tax |
| TeamVesting | Vesting | No | 8% supply, 24-month vesting |
| GhostCore | Game Logic | Yes (UUPS) | Positions, cascade, system reset |
| TraceScan | Randomness | Yes (UUPS) | Death selection, batch verification |
| RewardsDistributor | Emissions | Yes (UUPS) | 60M tokens over 24 months |
| DeadPool | Prediction | Yes (UUPS) | Parimutuel betting |
| FeeRouter | Fees | No | ETH toll collection, buyback |
| GhostTimelock | Governance | No | 48-hour upgrade delay |

---

## 2. Deployment Order & Dependencies

```
PHASE 1: Core Infrastructure
────────────────────────────
1. Deploy DataToken
   └── Args: treasury, initialHolders[], initialAmounts[]

2. Deploy TeamVesting
   └── Args: dataToken, beneficiary, startTime

3. Deploy GhostTimelock
   └── Args: minDelay (48 hours), proposers[], executors[]

PHASE 2: Game Contracts (Proxies)
─────────────────────────────────
4. Deploy GhostCore (via ERC1967Proxy)
   └── Args: dataToken, treasury, timelockAdmin
   └── Initialize: levels config, system reset params

5. Deploy TraceScan (via ERC1967Proxy)
   └── Args: ghostCore, timelockAdmin
   └── Initialize: submission window

6. Deploy RewardsDistributor (via ERC1967Proxy)
   └── Args: dataToken, ghostCore, timelockAdmin
   └── Initialize: level weights, emission rate

PHASE 3: Peripheral
───────────────────
7. Deploy FeeRouter
   └── Args: dataToken, dexRouter, treasury

8. Deploy DeadPool (via ERC1967Proxy)
   └── Args: dataToken, traceScan, timelockAdmin

PHASE 4: Configuration
──────────────────────
9. DataToken.setTaxExclusion(ghostCore, true)
10. DataToken.setTaxExclusion(rewardsDistributor, true)
11. DataToken.setTaxExclusion(deadPool, true)
12. GhostCore.grantRole(SCANNER_ROLE, traceScan)
13. GhostCore.grantRole(DISTRIBUTOR_ROLE, rewardsDistributor)
14. TraceScan.grantRole(KEEPER_ROLE, gelatoAutomate)  // optional
15. Transfer 60M DATA to RewardsDistributor
16. Transfer 8M DATA to TeamVesting
17. Burn LP tokens (separate tx)
```

---

## 3. DataToken.sol

### Overview

```
Type:        ERC20 with Transfer Tax
Upgradeable: NO (immutable)
Inherits:    ERC20, ERC20Burnable, Ownable2Step
```

### Storage

```solidity
// Constants
address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

// State
address public treasury;
mapping(address => bool) public isExcludedFromTax;

// Constants (could be immutable)
uint256 public constant TOTAL_SUPPLY = 100_000_000e18;
uint16 public constant TAX_RATE_BPS = 1000;      // 10%
uint16 public constant BURN_SHARE_BPS = 9000;    // 90% of tax (9% of transfer)
uint16 public constant TREASURY_SHARE_BPS = 1000; // 10% of tax (1% of transfer)
```

### Constructor

```solidity
constructor(
    address _treasury,
    address[] memory _initialHolders,
    uint256[] memory _initialAmounts
) ERC20("GHOSTNET Data", "DATA") Ownable(msg.sender) {
    require(_treasury != address(0), "Invalid treasury");
    require(_initialHolders.length == _initialAmounts.length, "Length mismatch");
    
    treasury = _treasury;
    
    // Mint to initial holders
    uint256 totalMinted;
    for (uint256 i = 0; i < _initialHolders.length; i++) {
        _mint(_initialHolders[i], _initialAmounts[i]);
        totalMinted += _initialAmounts[i];
    }
    require(totalMinted == TOTAL_SUPPLY, "Must mint exact supply");
    
    // Exclude treasury from tax
    isExcludedFromTax[_treasury] = true;
}
```

### Functions

```solidity
// ═══════════════════════════════════════════════════════════════════
// ADMIN FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// @notice Set tax exclusion for an address (game contracts)
/// @param account Address to exclude/include
/// @param excluded True to exclude from tax
function setTaxExclusion(address account, bool excluded) external onlyOwner {
    isExcludedFromTax[account] = excluded;
    emit TaxExclusionSet(account, excluded);
}

/// @notice Update treasury address
/// @param newTreasury New treasury address
function setTreasury(address newTreasury) external onlyOwner {
    require(newTreasury != address(0), "Invalid treasury");
    address oldTreasury = treasury;
    treasury = newTreasury;
    emit TreasuryUpdated(oldTreasury, newTreasury);
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL OVERRIDES
// ═══════════════════════════════════════════════════════════════════

/// @notice Override transfer to apply tax
function _update(
    address from,
    address to,
    uint256 amount
) internal virtual override {
    // Skip tax for minting, burning, or excluded addresses
    if (from == address(0) || to == address(0) || 
        isExcludedFromTax[from] || isExcludedFromTax[to]) {
        super._update(from, to, amount);
        return;
    }
    
    // Calculate tax
    uint256 taxAmount = (amount * TAX_RATE_BPS) / 10000;
    uint256 burnAmount = (taxAmount * BURN_SHARE_BPS) / 10000;
    uint256 treasuryAmount = taxAmount - burnAmount;
    uint256 transferAmount = amount - taxAmount;
    
    // Execute transfers
    super._update(from, DEAD_ADDRESS, burnAmount);      // Burn
    super._update(from, treasury, treasuryAmount);       // Treasury
    super._update(from, to, transferAmount);             // Recipient
    
    emit TaxCollected(from, to, taxAmount, burnAmount, treasuryAmount);
}
```

### Events

```solidity
event TaxExclusionSet(address indexed account, bool excluded);
event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
event TaxCollected(
    address indexed from,
    address indexed to,
    uint256 taxAmount,
    uint256 burnAmount,
    uint256 treasuryAmount
);
```

### Initial Distribution

```
Recipient               Amount          Purpose
─────────────────────────────────────────────────
RewardsDistributor     60,000,000      The Mine (emissions)
Presale Contract       15,000,000      Presale participants
Liquidity Pool          9,000,000      DEX liquidity (LP burned)
TeamVesting             8,000,000      Team allocation
Treasury                8,000,000      Operations
─────────────────────────────────────────────────
TOTAL                 100,000,000
```

---

## 4. TeamVesting.sol

### Overview

```
Type:        Linear Vesting
Upgradeable: NO (immutable)
Inherits:    Ownable2Step
Uses:        SafeERC20 for IERC20
```

### Storage

```solidity
IERC20 public immutable dataToken;
address public beneficiary;
uint256 public immutable startTime;
uint256 public immutable cliffDuration;    // 30 days
uint256 public immutable vestingDuration;  // 730 days (24 months)
uint256 public immutable totalAllocation;
uint256 public released;
```

### Constructor

```solidity
constructor(
    IERC20 _dataToken,
    address _beneficiary,
    uint256 _startTime
) Ownable(msg.sender) {
    require(address(_dataToken) != address(0), "Invalid token");
    require(_beneficiary != address(0), "Invalid beneficiary");
    require(_startTime >= block.timestamp, "Start in past");
    
    dataToken = _dataToken;
    beneficiary = _beneficiary;
    startTime = _startTime;
    cliffDuration = 30 days;
    vestingDuration = 730 days;
    totalAllocation = 8_000_000e18;
}
```

### Functions

```solidity
/// @notice Calculate vested amount
function vestedAmount() public view returns (uint256) {
    if (block.timestamp < startTime + cliffDuration) {
        return 0;
    }
    
    uint256 elapsed = block.timestamp - startTime;
    if (elapsed >= vestingDuration) {
        return totalAllocation;
    }
    
    return (totalAllocation * elapsed) / vestingDuration;
}

/// @notice Calculate releasable amount
function releasableAmount() public view returns (uint256) {
    return vestedAmount() - released;
}

/// @notice Release vested tokens
/// @dev Uses SafeERC20 for defense in depth
function release() external {
    uint256 amount = releasableAmount();
    require(amount > 0, "Nothing to release");
    
    released += amount;
    dataToken.safeTransfer(beneficiary, amount);
    
    emit TokensReleased(beneficiary, amount);
}

/// @notice Update beneficiary (e.g., to multisig)
function setBeneficiary(address newBeneficiary) external onlyOwner {
    require(newBeneficiary != address(0), "Invalid beneficiary");
    address oldBeneficiary = beneficiary;
    beneficiary = newBeneficiary;
    emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
}
```

### Events

```solidity
event TokensReleased(address indexed beneficiary, uint256 amount);
event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);
```

---

## 5. GhostCore.sol

### Overview

```
Type:        Core Game Logic
Upgradeable: YES (UUPS)
Inherits:    UUPSUpgradeable, ReentrancyGuardUpgradeable, 
             PausableUpgradeable, AccessControlUpgradeable
```

### Storage Layout

```solidity
// ═══════════════════════════════════════════════════════════════════
// STORAGE - Follow ERC-7201 namespaced storage pattern for upgrades
// ═══════════════════════════════════════════════════════════════════

/// @custom:storage-location erc7201:ghostnet.storage.GhostCore
struct GhostCoreStorage {
    // Token reference
    IDataToken dataToken;
    address treasury;
    
    // Positions: one per user
    mapping(address => Position) positions;
    
    // Level configurations
    mapping(uint8 => LevelConfig) levels;
    
    // System reset
    SystemReset systemReset;
    
    // Boost signer for mini-game verifications
    address boostSigner;
    
    // Network modifier thresholds (DATA amounts)
    uint256[4] networkModThresholds;
    
    // Used boost nonces (prevent replay)
    mapping(bytes32 => bool) usedBoostNonces;
    
    // Track all users with positions (for iteration if needed)
    EnumerableSet.AddressSet positionHolders;
}

struct Position {
    uint256 amount;           // Total staked DATA
    uint8 level;              // 1-5 (locked once set)
    uint64 entryTimestamp;    // When first jacked in
    uint64 lastAddTimestamp;  // When last added stake
    uint256 rewardDebt;       // For share-based accounting
    bool alive;               // false = traced
    uint16 ghostStreak;       // Consecutive survivals
    uint64 lastResetEpoch;    // Last reset epoch settled (for lazy penalty)
}

struct LevelConfig {
    uint16 baseDeathRateBps;  // e.g., 4000 = 40%
    uint32 scanInterval;      // Seconds between scans
    uint256 minStake;         // Minimum to jack in
    uint256 totalStaked;      // Sum of all alive positions
    uint256 aliveCount;       // Number of alive positions
    uint256 accRewardsPerShare; // Scaled by 1e18
    uint64 nextScanTime;      // Timestamp of next scan
    
    // Culling parameters (capacity management)
    uint256 maxPositions;     // Maximum positions allowed (0 = unlimited)
    uint16 cullingBottomPct;  // Bottom X% eligible for culling (default 5000 = 50%)
    uint16 cullingPenaltyBps; // Penalty on culled positions (default 8000 = 80% loss)
}

struct SystemReset {
    uint64 deadline;          // When reset triggers
    address lastDepositor;    // Jackpot recipient
    uint64 lastDepositTime;   // When last deposit occurred
}

// Boosts stored separately to avoid struct complexity
mapping(address => Boost[]) activeBoosts;

struct Boost {
    uint8 boostType;          // 0 = death reduction, 1 = yield multiplier
    uint16 valueBps;          // Basis points
    uint64 expiry;            // When boost expires
}
```

### Constants

```solidity
// Roles
bytes32 public constant SCANNER_ROLE = keccak256("SCANNER_ROLE");
bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

// Cascade splits (basis points of dead capital)
uint16 public constant CASCADE_SAME_LEVEL = 3000;   // 30%
uint16 public constant CASCADE_UPSTREAM = 3000;     // 30%
uint16 public constant CASCADE_BURN = 3000;         // 30%
uint16 public constant CASCADE_PROTOCOL = 1000;     // 10%

// Lock period
uint64 public constant LOCK_PERIOD = 60;            // seconds

// System reset
uint64 public constant DEFAULT_RESET_DEADLINE = 24 hours;
uint64 public constant MAX_RESET_DEADLINE = 24 hours;

// Culling defaults
uint16 public constant DEFAULT_CULLING_BOTTOM_PCT = 5000;  // 50%
uint16 public constant DEFAULT_CULLING_PENALTY_BPS = 8000; // 80% loss

// Precision
uint256 public constant PRECISION = 1e18;
```

### Initializer

```solidity
function initialize(
    IDataToken _dataToken,
    address _treasury,
    address _admin,
    LevelConfig[5] calldata _levelConfigs,
    uint256[4] calldata _networkModThresholds
) external initializer {
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
    __AccessControl_init();
    
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    $.dataToken = _dataToken;
    $.treasury = _treasury;
    $.networkModThresholds = _networkModThresholds;
    
    // Initialize levels
    for (uint8 i = 0; i < 5; i++) {
        $.levels[i + 1] = _levelConfigs[i];
        $.levels[i + 1].nextScanTime = uint64(block.timestamp) + _levelConfigs[i].scanInterval;
    }
    
    // Initialize system reset
    $.systemReset.deadline = uint64(block.timestamp) + DEFAULT_RESET_DEADLINE;
}
```

### Core Functions

```solidity
// ═══════════════════════════════════════════════════════════════════
// PLAYER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// @notice Jack into the network (create or add to position)
/// @param amount Amount of DATA to stake
/// @param level Security clearance level (1-5), ignored if position exists
/// @dev If level is at capacity, triggers weighted random culling of bottom X%
function jackIn(uint256 amount, uint8 level) external nonReentrant whenNotPaused {
    require(amount > 0, "Amount must be positive");
    require(level >= 1 && level <= 5, "Invalid level");
    
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // Settle any pending reset penalty first (lazy settlement)
    _settleResetPenalty(msg.sender);
    
    Position storage pos = $.positions[msg.sender];
    
    if (pos.amount == 0) {
        // New position
        require(amount >= $.levels[level].minStake, "Below minimum stake");
        
        LevelConfig storage levelConfig = $.levels[level];
        
        // Check if level is at capacity - trigger culling if so
        if (levelConfig.maxPositions > 0 && levelConfig.aliveCount >= levelConfig.maxPositions) {
            _triggerCulling(level, msg.sender);
        }
        
        pos.level = level;
        pos.entryTimestamp = uint64(block.timestamp);
        pos.alive = true;
        pos.ghostStreak = 0;
        pos.lastResetEpoch = currentReset.epoch; // Start with current epoch
        
        $.positionHolders.add(msg.sender);
        levelConfig.aliveCount++;
    } else {
        // Adding to existing position
        require(pos.alive, "Position is dead");
        level = pos.level; // Use existing level
        
        // Settle pending rewards first
        _settleRewards(msg.sender);
    }
    
    pos.amount += amount;
    pos.lastAddTimestamp = uint64(block.timestamp);
    pos.rewardDebt = (pos.amount * $.levels[level].accRewardsPerShare) / PRECISION;
    
    $.levels[level].totalStaked += amount;
    
    // Extend system reset deadline
    _extendResetDeadline(amount, msg.sender);
    
    // Transfer tokens (tax-exempt)
    $.dataToken.transferFrom(msg.sender, address(this), amount);
    
    emit JackedIn(msg.sender, amount, level, pos.amount);
}

/// @notice Extract from the network (withdraw position)
function extract() external nonReentrant whenNotPaused {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // Settle any pending reset penalty first (lazy settlement)
    _settleResetPenalty(msg.sender);
    
    Position storage pos = $.positions[msg.sender];
    
    require(pos.amount > 0, "No position");
    require(pos.alive, "Position is dead");
    require(!_isInLockPeriod(pos.level), "Position locked: scan imminent");
    
    // Calculate rewards
    uint256 pending = _pendingRewards(msg.sender);
    uint256 totalAmount = pos.amount + pending;
    
    // Update level stats
    $.levels[pos.level].totalStaked -= pos.amount;
    $.levels[pos.level].aliveCount--;
    
    // Store values before deletion for event
    uint256 principal = pos.amount;
    
    // Clear position
    delete $.positions[msg.sender];
    $.positionHolders.remove(msg.sender);
    
    // Transfer tokens
    $.dataToken.transfer(msg.sender, totalAmount);
    
    emit Extracted(msg.sender, principal, pending);
}

/// @notice Claim accumulated rewards without extracting
function claimRewards() external nonReentrant whenNotPaused {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // Settle any pending reset penalty first (lazy settlement)
    _settleResetPenalty(msg.sender);
    
    Position storage pos = $.positions[msg.sender];
    
    require(pos.amount > 0 && pos.alive, "No active position");
    
    uint256 pending = _pendingRewards(msg.sender);
    require(pending > 0, "No rewards to claim");
    
    pos.rewardDebt = (pos.amount * $.levels[pos.level].accRewardsPerShare) / PRECISION;
    
    $.dataToken.transfer(msg.sender, pending);
    
    emit RewardsClaimed(msg.sender, pending);
}

// ═══════════════════════════════════════════════════════════════════
// SCANNER FUNCTIONS (Called by TraceScan)
// ═══════════════════════════════════════════════════════════════════

/// @notice Process deaths and distribute cascade
/// @param level The level being processed
/// @param deadUsers Array of users who died
/// @param totalDeadCapital Total DATA from dead positions
/// @dev nonReentrant for defense in depth (cascade makes external transfers)
function processDeaths(
    uint8 level,
    address[] calldata deadUsers,
    uint256 totalDeadCapital
) external onlyRole(SCANNER_ROLE) nonReentrant {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // Mark users as dead
    for (uint256 i = 0; i < deadUsers.length; i++) {
        Position storage pos = $.positions[deadUsers[i]];
        require(pos.alive && pos.level == level, "Invalid death");
        
        pos.alive = false;
        pos.ghostStreak = 0;
        
        $.levels[level].totalStaked -= pos.amount;
        $.levels[level].aliveCount--;
    }
    
    // Distribute cascade
    _distributeCascade(level, totalDeadCapital);
    
    emit DeathsProcessed(level, deadUsers.length, totalDeadCapital);
}

/// @notice Increment ghost streak for survivors
/// @param level The level that completed a scan
/// @param survivors Array of surviving users
function incrementGhostStreak(
    uint8 level,
    address[] calldata survivors
) external onlyRole(SCANNER_ROLE) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    for (uint256 i = 0; i < survivors.length; i++) {
        Position storage pos = $.positions[survivors[i]];
        if (pos.alive && pos.level == level) {
            pos.ghostStreak++;
        }
    }
    
    emit GhostStreaksUpdated(level, survivors.length);
}

/// @notice Update next scan time for a level
function updateNextScanTime(uint8 level) external onlyRole(SCANNER_ROLE) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    $.levels[level].nextScanTime = uint64(block.timestamp) + $.levels[level].scanInterval;
}

// ═══════════════════════════════════════════════════════════════════
// DISTRIBUTOR FUNCTIONS (Called by RewardsDistributor)
// ═══════════════════════════════════════════════════════════════════

/// @notice Add emission rewards to a level
function addEmissionRewards(uint8 level, uint256 amount) external onlyRole(DISTRIBUTOR_ROLE) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    if ($.levels[level].totalStaked > 0) {
        $.levels[level].accRewardsPerShare += (amount * PRECISION) / $.levels[level].totalStaked;
    }
    
    emit EmissionsAdded(level, amount);
}

// ═══════════════════════════════════════════════════════════════════
// SYSTEM RESET (Hybrid: Events Now, Storage Lazy)
// ═══════════════════════════════════════════════════════════════════
//
// DESIGN DECISION: We use a hybrid approach for gas efficiency:
// - Emit events immediately (O(n) but cheap ~500 gas/event)
// - Defer storage writes until user's next interaction (lazy settlement)
// - This provides immediate feed visibility while avoiding expensive storage loops
//
// At 10,000 positions: ~10M gas (events only) vs ~60M gas (full storage writes)

/// @notice Current reset epoch and penalty info
struct ResetEpoch {
    uint64 epoch;           // Incremented on each reset
    uint64 timestamp;       // When reset occurred
    uint16 penaltyBps;      // Penalty in basis points (e.g., 2500 = 25%)
}

ResetEpoch public currentReset;

/// @notice Trigger system reset if deadline passed
/// @dev Emits events for all positions but defers storage updates (lazy settlement)
function triggerSystemReset() external nonReentrant {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    require(block.timestamp >= $.systemReset.deadline, "Deadline not reached");
    
    uint16 penaltyBps = 2500; // 25% penalty
    
    // Calculate total staked and penalty amounts
    uint256 totalStaked;
    for (uint8 i = 1; i <= 5; i++) {
        totalStaked += $.levels[i].totalStaked;
    }
    
    uint256 penaltyPool = (totalStaked * penaltyBps) / 10000;
    
    // Increment reset epoch (O(1) storage)
    currentReset = ResetEpoch({
        epoch: currentReset.epoch + 1,
        timestamp: uint64(block.timestamp),
        penaltyBps: penaltyBps
    });
    
    // Emit events for each position WITHOUT writing to storage
    // This enables immediate feed updates while keeping gas low
    uint256 len = $.positionHolders.length();
    for (uint256 i = 0; i < len; i++) {
        address user = $.positionHolders.at(i);
        Position storage pos = $.positions[user];
        
        if (pos.alive && pos.amount > 0) {
            uint256 penalty = pos.amount * penaltyBps / 10000;
            // Emit event only - no storage write
            emit PositionPenalized(user, pos.level, penalty, pos.amount - penalty);
        }
    }
    
    // Update level totals (O(5) storage writes)
    for (uint8 level = 1; level <= 5; level++) {
        $.levels[level].totalStaked = $.levels[level].totalStaked * (10000 - penaltyBps) / 10000;
    }
    
    // Distribute penalty pool
    uint256 jackpot = (penaltyPool * 5000) / 10000;      // 50%
    uint256 burnAmount = (penaltyPool * 3000) / 10000;   // 30%
    uint256 protocolAmount = penaltyPool - jackpot - burnAmount; // 20%
    
    // Transfer jackpot to last depositor
    if ($.systemReset.lastDepositor != address(0) && jackpot > 0) {
        $.dataToken.transfer($.systemReset.lastDepositor, jackpot);
    }
    
    // Burn
    if (burnAmount > 0) {
        $.dataToken.transfer(address(0xdead), burnAmount);
    }
    
    // Protocol
    if (protocolAmount > 0) {
        $.dataToken.transfer($.treasury, protocolAmount);
    }
    
    // Reset deadline
    $.systemReset.deadline = uint64(block.timestamp) + DEFAULT_RESET_DEADLINE;
    address winner = $.systemReset.lastDepositor;
    $.systemReset.lastDepositor = address(0);
    
    emit SystemResetTriggered(penaltyPool, winner, jackpot);
}

/// @notice Settle any pending reset penalty for a user
/// @dev Called internally before any position interaction
function _settleResetPenalty(address user) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    Position storage pos = $.positions[user];
    
    // Check if user has unsettled penalty from a reset
    if (pos.lastResetEpoch < currentReset.epoch && pos.amount > 0) {
        // Apply the penalty to storage
        pos.amount = pos.amount * (10000 - currentReset.penaltyBps) / 10000;
        pos.lastResetEpoch = currentReset.epoch;
    }
}

/// @notice Get effective position after any pending penalties
/// @dev Use this for accurate balance display in UI
function getEffectivePosition(address user) external view returns (
    uint256 amount,
    uint256 pendingPenalty,
    bool hasPendingPenalty
) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    Position storage pos = $.positions[user];
    
    if (pos.lastResetEpoch < currentReset.epoch && pos.amount > 0) {
        hasPendingPenalty = true;
        pendingPenalty = pos.amount * currentReset.penaltyBps / 10000;
        amount = pos.amount - pendingPenalty;
    } else {
        amount = pos.amount;
        pendingPenalty = 0;
        hasPendingPenalty = false;
    }
}

// ═══════════════════════════════════════════════════════════════════
// BOOST FUNCTIONS (EIP-712 Typed Signatures)
// ═══════════════════════════════════════════════════════════════════
//
// SECURITY: Uses EIP-712 typed data signatures to prevent cross-chain replay.
// The DOMAIN_SEPARATOR includes chainId and contract address, ensuring
// signatures are only valid for this specific deployment.

bytes32 public constant DOMAIN_TYPEHASH = keccak256(
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
);

bytes32 public constant BOOST_TYPEHASH = keccak256(
    "Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"
);

/// @notice EIP-712 domain separator (set in initializer)
bytes32 public DOMAIN_SEPARATOR;

/// @notice Initialize domain separator (called in initialize())
function _initializeDomainSeparator() internal {
    DOMAIN_SEPARATOR = keccak256(abi.encode(
        DOMAIN_TYPEHASH,
        keccak256("GHOSTNET"),
        keccak256("1"),
        block.chainid,
        address(this)
    ));
}

/// @notice Apply a boost from mini-game completion
/// @param boostType Type of boost (0 = death reduction, 1 = yield multiplier)
/// @param valueBps Boost value in basis points
/// @param expiry Timestamp when boost expires
/// @param nonce Unique nonce to prevent replay
/// @param signature EIP-712 signature from boost signer
/// @dev Follows CEI pattern: nonce marked used BEFORE signature verification
function applyBoost(
    uint8 boostType,
    uint16 valueBps,
    uint64 expiry,
    bytes32 nonce,
    bytes calldata signature
) external {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // CHECKS
    require($.positions[msg.sender].alive, "No active position");
    require(expiry > block.timestamp, "Boost expired");
    require(!$.usedBoostNonces[nonce], "Nonce already used");
    
    // EFFECTS - Mark nonce used BEFORE verification (CEI pattern)
    $.usedBoostNonces[nonce] = true;
    
    // Build EIP-712 typed data hash
    bytes32 structHash = keccak256(abi.encode(
        BOOST_TYPEHASH,
        msg.sender,
        boostType,
        valueBps,
        expiry,
        nonce
    ));
    
    // EIP-712 digest
    bytes32 digest = keccak256(abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        structHash
    ));
    
    // Verify signature with error handling
    (address signer, ECDSA.RecoverError error, ) = ECDSA.tryRecover(digest, signature);
    require(error == ECDSA.RecoverError.NoError, "Invalid signature format");
    require(signer == $.boostSigner, "Invalid signer");
    
    // INTERACTIONS - Add boost
    activeBoosts[msg.sender].push(Boost({
        boostType: boostType,
        valueBps: valueBps,
        expiry: expiry
    }));
    
    emit BoostApplied(msg.sender, boostType, valueBps, expiry);
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// @notice Trigger weighted random culling when level is at capacity
/// @param level The level being entered
/// @param newEntrant The address of the new player (excluded from culling)
/// @dev Selects victim from bottom X% by stake using weighted random (lower stake = higher chance)
function _triggerCulling(uint8 level, address newEntrant) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    LevelConfig storage levelConfig = $.levels[level];
    
    // Get eligible positions (bottom X% by stake)
    address[] memory eligible = _getEligibleForCulling(level, newEntrant);
    require(eligible.length > 0, "No eligible positions for culling");
    
    // Calculate weights (inverse of stake - lower stake = higher weight)
    uint256 totalWeight;
    uint256[] memory weights = new uint256[](eligible.length);
    
    for (uint256 i = 0; i < eligible.length; i++) {
        // Weight = inverse of stake (using 1e36 for precision)
        // Smaller stake = higher weight = higher chance of being culled
        weights[i] = 1e36 / $.positions[eligible[i]].amount;
        totalWeight += weights[i];
    }
    
    // Generate random seed using prevrandao
    uint256 seed = uint256(keccak256(abi.encodePacked(
        block.prevrandao,
        block.timestamp,
        newEntrant,
        level,
        block.number
    )));
    
    // Select victim using weighted random
    uint256 randomValue = seed % totalWeight;
    address victim;
    uint256 cumulative;
    
    for (uint256 i = 0; i < eligible.length; i++) {
        cumulative += weights[i];
        if (randomValue < cumulative) {
            victim = eligible[i];
            break;
        }
    }
    
    // Execute culling
    _executeCulling(victim, level, levelConfig.cullingPenaltyBps);
}

/// @notice Get positions eligible for culling (bottom X% by stake)
/// @param level The level to check
/// @param excludeAddress Address to exclude (new entrant)
/// @return eligible Array of addresses in the bottom X%
function _getEligibleForCulling(uint8 level, address excludeAddress) internal view returns (address[] memory eligible) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    LevelConfig storage levelConfig = $.levels[level];
    
    uint256 bottomPct = levelConfig.cullingBottomPct; // e.g., 5000 = 50%
    
    // Collect all positions at this level with their amounts
    uint256 count;
    address[] memory allPositions = new address[](levelConfig.aliveCount);
    uint256[] memory amounts = new uint256[](levelConfig.aliveCount);
    
    // Iterate through position holders at this level
    // Note: In production, use level-specific enumerable set for efficiency
    uint256 holderCount = $.positionHolders.length();
    for (uint256 i = 0; i < holderCount && count < levelConfig.aliveCount; i++) {
        address holder = $.positionHolders.at(i);
        Position storage pos = $.positions[holder];
        
        if (pos.alive && pos.level == level && holder != excludeAddress) {
            allPositions[count] = holder;
            amounts[count] = pos.amount;
            count++;
        }
    }
    
    // Find threshold for bottom X% (simple approach: sort and take bottom)
    // Production note: Consider off-chain sorting with on-chain verification
    uint256 eligibleCount = (count * bottomPct) / 10000;
    if (eligibleCount == 0) eligibleCount = 1; // At least one must be eligible
    
    // Simple selection: find the eligibleCount lowest amounts
    eligible = new address[](eligibleCount);
    bool[] memory selected = new bool[](count);
    
    for (uint256 j = 0; j < eligibleCount; j++) {
        uint256 minAmount = type(uint256).max;
        uint256 minIndex;
        
        for (uint256 i = 0; i < count; i++) {
            if (!selected[i] && amounts[i] < minAmount) {
                minAmount = amounts[i];
                minIndex = i;
            }
        }
        
        selected[minIndex] = true;
        eligible[j] = allPositions[minIndex];
    }
}

/// @notice Execute the culling of a position
/// @param victim Address being culled
/// @param level Level of the position
/// @param penaltyBps Penalty in basis points (e.g., 8000 = 80% loss)
function _executeCulling(address victim, uint8 level, uint16 penaltyBps) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    Position storage pos = $.positions[victim];
    
    uint256 totalAmount = pos.amount;
    uint256 penaltyAmount = (totalAmount * penaltyBps) / 10000;
    uint256 returnAmount = totalAmount - penaltyAmount;
    
    // Mark position as dead
    pos.alive = false;
    pos.ghostStreak = 0;
    
    // Update level stats
    $.levels[level].totalStaked -= totalAmount;
    $.levels[level].aliveCount--;
    
    // Remove from position holders
    $.positionHolders.remove(victim);
    
    // Distribute penalty via cascade (same as death)
    if (penaltyAmount > 0) {
        _distributeCascade(level, penaltyAmount);
    }
    
    // Return remaining amount to victim
    if (returnAmount > 0) {
        $.dataToken.safeTransfer(victim, returnAmount);
    }
    
    emit PositionCulled(victim, level, totalAmount, penaltyAmount, returnAmount);
}

function _distributeCascade(uint8 level, uint256 totalDeadCapital) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    uint256 sameLevelAmount = (totalDeadCapital * CASCADE_SAME_LEVEL) / 10000;
    uint256 upstreamAmount = (totalDeadCapital * CASCADE_UPSTREAM) / 10000;
    uint256 burnAmount = (totalDeadCapital * CASCADE_BURN) / 10000;
    uint256 protocolAmount = totalDeadCapital - sameLevelAmount - upstreamAmount - burnAmount;
    
    // Same-level distribution
    if ($.levels[level].totalStaked > 0) {
        $.levels[level].accRewardsPerShare += (sameLevelAmount * PRECISION) / $.levels[level].totalStaked;
    }
    
    // Upstream distribution
    if (level > 1) {
        _distributeUpstream(level, upstreamAmount);
    } else {
        // VAULT has no upstream - give to same level
        if ($.levels[level].totalStaked > 0) {
            $.levels[level].accRewardsPerShare += (upstreamAmount * PRECISION) / $.levels[level].totalStaked;
        }
    }
    
    // Burn
    $.dataToken.transfer(address(0xdead), burnAmount);
    
    // Protocol
    $.dataToken.transfer($.treasury, protocolAmount);
    
    emit CascadeDistributed(level, sameLevelAmount, upstreamAmount, burnAmount, protocolAmount);
}

function _distributeUpstream(uint8 fromLevel, uint256 amount) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    // Calculate total TVL of upstream levels
    uint256 totalUpstreamTVL;
    for (uint8 i = 1; i < fromLevel; i++) {
        totalUpstreamTVL += $.levels[i].totalStaked;
    }
    
    if (totalUpstreamTVL == 0) return;
    
    // Distribute proportionally
    for (uint8 i = 1; i < fromLevel; i++) {
        if ($.levels[i].totalStaked > 0) {
            uint256 levelShare = (amount * $.levels[i].totalStaked) / totalUpstreamTVL;
            $.levels[i].accRewardsPerShare += (levelShare * PRECISION) / $.levels[i].totalStaked;
        }
    }
}

function _pendingRewards(address user) internal view returns (uint256) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    Position storage pos = $.positions[user];
    
    if (pos.amount == 0) return 0;
    
    uint256 accRewards = $.levels[pos.level].accRewardsPerShare;
    return (pos.amount * accRewards / PRECISION) - pos.rewardDebt;
}

function _settleRewards(address user) internal {
    uint256 pending = _pendingRewards(user);
    if (pending > 0) {
        GhostCoreStorage storage $ = _getGhostCoreStorage();
        $.dataToken.transfer(user, pending);
        emit RewardsClaimed(user, pending);
    }
}

function _isInLockPeriod(uint8 level) internal view returns (bool) {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    uint64 nextScan = $.levels[level].nextScanTime;
    return block.timestamp >= nextScan - LOCK_PERIOD && block.timestamp < nextScan;
}

function _extendResetDeadline(uint256 amount, address depositor) internal {
    GhostCoreStorage storage $ = _getGhostCoreStorage();
    
    uint64 extension;
    if (amount < 50e18) {
        extension = 1 hours;
    } else if (amount < 200e18) {
        extension = 4 hours;
    } else if (amount < 500e18) {
        extension = 8 hours;
    } else if (amount < 1000e18) {
        extension = 16 hours;
    } else {
        extension = 24 hours; // Full reset
    }
    
    uint64 newDeadline = uint64(block.timestamp) + extension;
    if (newDeadline > $.systemReset.deadline) {
        $.systemReset.deadline = newDeadline > uint64(block.timestamp) + MAX_RESET_DEADLINE 
            ? uint64(block.timestamp) + MAX_RESET_DEADLINE 
            : newDeadline;
    }
    
    $.systemReset.lastDepositor = depositor;
    $.systemReset.lastDepositTime = uint64(block.timestamp);
}

// ═══════════════════════════════════════════════════════════════════
// VIEW FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

function getPosition(address user) external view returns (Position memory);
function getLevelConfig(uint8 level) external view returns (LevelConfig memory);
function getPendingRewards(address user) external view returns (uint256);
function getEffectiveDeathRate(address user) external view returns (uint16);
function getNetworkModifier() external view returns (uint16);
function getSystemResetInfo() external view returns (SystemReset memory);
function isInLockPeriod(uint8 level) external view returns (bool);
function getTotalValueLocked() external view returns (uint256);
function getPositionCount(uint8 level) external view returns (uint256);

/// @notice Get current reset epoch information
/// @return epoch The current reset epoch number
/// @return timestamp When the current epoch started  
/// @return penaltyBps Penalty applied in current epoch (basis points)
function getCurrentResetEpoch() external view returns (
    uint64 epoch,
    uint64 timestamp,
    uint16 penaltyBps
);

/// @notice Get culling risk for a position (probability of being culled on next jackIn at capacity)
/// @param user Address to check
/// @return riskBps Risk in basis points (0-10000), 0 if not in bottom X% or level not at capacity
/// @return isEligible Whether the position is currently in the culling-eligible bottom X%
/// @return levelCapacityPct Current capacity percentage of the level (10000 = 100%)
function getCullingRisk(address user) external view returns (
    uint16 riskBps,
    bool isEligible,
    uint16 levelCapacityPct
);

// ═══════════════════════════════════════════════════════════════════
// ADMIN FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

function pause() external onlyRole(DEFAULT_ADMIN_ROLE);
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE);
function setBoostSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE);
function setNetworkModThresholds(uint256[4] calldata thresholds) external onlyRole(DEFAULT_ADMIN_ROLE);
function updateLevelConfig(uint8 level, LevelConfig calldata config) external onlyRole(DEFAULT_ADMIN_ROLE);
function emergencyWithdraw() external; // When paused, users can exit without rewards
function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE);

/// @notice Update culling parameters for a level
/// @param level Level to update
/// @param maxPositions Maximum positions (0 = unlimited)
/// @param cullingBottomPct Bottom X% eligible for culling (5000 = 50%)
/// @param cullingPenaltyBps Penalty when culled (8000 = 80% loss)
function setCullingParams(
    uint8 level,
    uint256 maxPositions,
    uint16 cullingBottomPct,
    uint16 cullingPenaltyBps
) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### Events

```solidity
event JackedIn(address indexed user, uint256 amount, uint8 level, uint256 totalAmount);
event Extracted(address indexed user, uint256 principal, uint256 rewards);
event RewardsClaimed(address indexed user, uint256 amount);
event DeathsProcessed(uint8 indexed level, uint256 count, uint256 totalCapital);
event GhostStreaksUpdated(uint8 indexed level, uint256 count);
event CascadeDistributed(uint8 indexed level, uint256 sameLevel, uint256 upstream, uint256 burned, uint256 protocol);
event EmissionsAdded(uint8 indexed level, uint256 amount);
event SystemResetTriggered(uint256 penaltyPool, address indexed jackpotWinner, uint256 jackpotAmount);
event PositionPenalized(address indexed user, uint8 indexed level, uint256 penalty, uint256 newAmount);
event BoostApplied(address indexed user, uint8 boostType, uint16 valueBps, uint64 expiry);
event LevelConfigUpdated(uint8 indexed level);
event BoostSignerUpdated(address indexed oldSigner, address indexed newSigner);

// Culling events
event PositionCulled(address indexed victim, uint8 indexed level, uint256 totalAmount, uint256 penaltyAmount, uint256 returnedAmount);
event CullingParamsUpdated(uint8 indexed level, uint256 maxPositions, uint16 cullingBottomPct, uint16 cullingPenaltyBps);
```

---

## 6. TraceScan.sol

### Overview

```
Type:        Trustless Death Verification
Upgradeable: YES (UUPS)
Inherits:    UUPSUpgradeable, AccessControlUpgradeable
```

### Storage Layout

```solidity
/// @custom:storage-location erc7201:ghostnet.storage.TraceScan
struct TraceScanStorage {
    IGhostCore ghostCore;
    
    // Current active scan per level
    mapping(uint8 => Scan) currentScans;
    
    // Track processed users per scan using EPOCH-BASED pattern
    // mapping: level => scanId => user => processed
    // This enables implicit cleanup: old scanId entries become irrelevant
    // without requiring O(n) gas to delete them
    mapping(uint8 => mapping(uint256 => mapping(address => bool))) processedInScan;
    
    // Global nonce for seed generation (also used as scanId)
    uint256 scanNonce;
    
    // Configurable submission window
    uint64 submissionWindow;
}

struct Scan {
    uint256 scanId;            // Unique scan identifier (from scanNonce)
    uint256 seed;              // Deterministic seed
    uint64 executedAt;         // When scan started
    uint64 finalizedAt;        // When cascade distributed
    uint256 totalDeadCapital;  // Accumulated from deaths
    uint256 deathCount;        // Number processed
    bool active;               // Is there a pending scan
    bool finalized;            // Has cascade been distributed
}
```

### Storage Cleanup Strategy

**Design Decision:** Epoch-based mapping pattern for `processedInScan`

**Problem:** The `processedInScan` mapping tracks which users have been submitted during a scan. After finalization, these entries become stale but are never deleted. Explicit cleanup would require O(n) gas (potentially millions of gas for large scans), which could exceed block limits.

**Solution:** Use a three-level mapping keyed by `scanId`:
```solidity
// Before (problematic):
mapping(uint8 => mapping(address => bool)) processedInScan;
// Lookup: processedInScan[level][user]

// After (epoch-based):
mapping(uint8 => mapping(uint256 => mapping(address => bool))) processedInScan;
// Lookup: processedInScan[level][scan.scanId][user]
```

**Why This Works:**
1. Each scan gets a unique `scanId` (from incrementing `scanNonce`)
2. When checking if a user was processed, we include the `scanId` in the lookup
3. Old `scanId` entries naturally become irrelevant without explicit deletion
4. Storage is "logically" cleaned on each new scan (O(1) gas)
5. The mapping keys (stale entries) remain but are never accessed again

**Gas Analysis:**
| Operation | Before (explicit clear) | After (epoch-based) |
|-----------|------------------------|---------------------|
| Clear 1,000 users | ~5,000,000 gas | 0 gas |
| Clear 10,000 users | ~50,000,000 gas (exceeds block) | 0 gas |
| Lookup cost | ~2,100 gas (cold) | ~2,100 gas (cold) |

**Trade-off:** Stale storage slots are never reclaimed. This is acceptable because:
1. MegaETH storage costs are low
2. The alternative (explicit clearing) is unbounded and can DoS the protocol
3. Slots are ~32 bytes each, growth is linear with unique (level, scanId, user) tuples
4. State growth is bounded by protocol activity, not accumulated forever

### Constants

```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
uint256 public constant MAX_BATCH_SIZE = 100;
uint64 public constant DEFAULT_SUBMISSION_WINDOW = 120; // seconds
```

### Functions

```solidity
// ═══════════════════════════════════════════════════════════════════
// PHASE 1: SCAN EXECUTION
// ═══════════════════════════════════════════════════════════════════

/// @notice Execute a scan for a level (stores seed, starts death collection)
/// @param level The level to scan
function executeScan(uint8 level) external {
    TraceScanStorage storage $ = _getTraceScanStorage();
    
    require(level >= 1 && level <= 5, "Invalid level");
    require(!$.currentScans[level].active, "Scan already active");
    
    IGhostCore.LevelConfig memory config = $.ghostCore.getLevelConfig(level);
    require(block.timestamp >= config.nextScanTime, "Too early");
    
    // Increment nonce and use as scanId (enables epoch-based storage cleanup)
    uint256 scanId = ++$.scanNonce;
    
    // Generate deterministic seed
    uint256 seed = uint256(keccak256(abi.encode(
        block.prevrandao,
        block.timestamp,
        block.number,
        level,
        scanId
    )));
    
    // Initialize scan with unique scanId
    $.currentScans[level] = Scan({
        scanId: scanId,
        seed: seed,
        executedAt: uint64(block.timestamp),
        finalizedAt: 0,
        totalDeadCapital: 0,
        deathCount: 0,
        active: true,
        finalized: false
    });
    
    emit ScanExecuted(level, scanId, seed, block.timestamp);
}

// ═══════════════════════════════════════════════════════════════════
// PHASE 2: DEATH PROOF SUBMISSION
// ═══════════════════════════════════════════════════════════════════

/// @notice Submit batch of dead users (anyone can call, contract verifies)
/// @param level The level being processed
/// @param deadUsers Array of users claiming to be dead
function submitDeaths(uint8 level, address[] calldata deadUsers) external {
    TraceScanStorage storage $ = _getTraceScanStorage();
    Scan storage scan = $.currentScans[level];
    
    require(scan.active && !scan.finalized, "No active scan");
    require(deadUsers.length <= MAX_BATCH_SIZE, "Batch too large");
    
    // Cache scanId for epoch-based lookup
    uint256 scanId = scan.scanId;
    
    address[] memory verifiedDead = new address[](deadUsers.length);
    uint256 verifiedCount;
    uint256 totalCapital;
    
    for (uint256 i = 0; i < deadUsers.length; i++) {
        address user = deadUsers[i];
        
        // Skip if already processed in THIS scan (epoch-based lookup)
        if ($.processedInScan[level][scanId][user]) continue;
        
        // Get position info
        IGhostCore.Position memory pos = $.ghostCore.getPosition(user);
        
        // Skip if not alive or wrong level
        if (!pos.alive || pos.level != level) continue;
        
        // Get effective death rate (includes boosts)
        uint16 deathRate = $.ghostCore.getEffectiveDeathRate(user);
        
        // VERIFY death is valid
        require(_isDead(scan.seed, user, deathRate), "User should not die");
        
        // Mark processed for THIS scan (epoch-based storage)
        $.processedInScan[level][scanId][user] = true;
        verifiedDead[verifiedCount] = user;
        verifiedCount++;
        totalCapital += pos.amount;
    }
    
    // Update scan stats
    scan.deathCount += verifiedCount;
    scan.totalDeadCapital += totalCapital;
    
    // Trim array and send to GhostCore
    assembly {
        mstore(verifiedDead, verifiedCount)
    }
    
    if (verifiedCount > 0) {
        $.ghostCore.processDeaths(level, verifiedDead, totalCapital);
    }
    
    emit DeathsSubmitted(level, verifiedCount, msg.sender);
}

/// @notice Check if a user would die given current scan seed
/// @param seed The scan seed
/// @param user The user address
/// @param deathRateBps Death rate in basis points
function _isDead(uint256 seed, address user, uint16 deathRateBps) internal pure returns (bool) {
    uint256 roll = uint256(keccak256(abi.encode(seed, user))) % 10000;
    return roll < deathRateBps;
}

// ═══════════════════════════════════════════════════════════════════
// PHASE 3: FINALIZATION
// ═══════════════════════════════════════════════════════════════════

/// @notice Finalize scan and trigger cascade distribution
/// @param level The level to finalize
function finalizeScan(uint8 level) external {
    TraceScanStorage storage $ = _getTraceScanStorage();
    Scan storage scan = $.currentScans[level];
    
    require(scan.active && !scan.finalized, "Cannot finalize");
    require(block.timestamp >= scan.executedAt + $.submissionWindow, "Submission window open");
    
    scan.finalized = true;
    scan.finalizedAt = uint64(block.timestamp);
    scan.active = false;
    
    // Update next scan time
    $.ghostCore.updateNextScanTime(level);
    
    // NOTE: No explicit clearing of processedInScan needed!
    // The epoch-based pattern (keyed by scanId) means old entries
    // become irrelevant automatically when the next scan starts.
    // This saves potentially millions of gas vs O(n) deletion.
    
    emit ScanFinalized(level, scan.scanId, scan.deathCount, scan.totalDeadCapital);
}

// ═══════════════════════════════════════════════════════════════════
// KEEPER INTERFACE (Gelato compatible)
// ═══════════════════════════════════════════════════════════════════

/// @notice Check if any action is needed
function checker() external view returns (bool canExec, bytes memory execPayload) {
    TraceScanStorage storage $ = _getTraceScanStorage();
    
    for (uint8 level = 1; level <= 5; level++) {
        // Check if scan can be executed
        if (canExecuteScan(level)) {
            return (true, abi.encodeCall(this.executeScan, (level)));
        }
        
        // Check if scan can be finalized
        if (canFinalizeScan(level)) {
            return (true, abi.encodeCall(this.finalizeScan, (level)));
        }
    }
    
    return (false, bytes(""));
}

// ═══════════════════════════════════════════════════════════════════
// VIEW FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

function canExecuteScan(uint8 level) public view returns (bool);
function canFinalizeScan(uint8 level) public view returns (bool);
function getCurrentScan(uint8 level) external view returns (Scan memory);
function wouldDie(address user) external view returns (bool);
function getSubmissionWindow() external view returns (uint64);

// ═══════════════════════════════════════════════════════════════════
// ADMIN FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

function setSubmissionWindow(uint64 window) external onlyRole(DEFAULT_ADMIN_ROLE);
function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE);
```

### Events

```solidity
event ScanExecuted(uint8 indexed level, uint256 indexed scanId, uint256 seed, uint256 timestamp);
event DeathsSubmitted(uint8 indexed level, uint256 count, address indexed submitter);
event ScanFinalized(uint8 indexed level, uint256 indexed scanId, uint256 deathCount, uint256 totalCapital);
event SubmissionWindowUpdated(uint64 oldWindow, uint64 newWindow);
```

---

## 7. RewardsDistributor.sol

### Overview

```
Type:        Emission Distribution
Upgradeable: YES (UUPS)
Inherits:    UUPSUpgradeable, AccessControlUpgradeable
```

### Storage Layout

```solidity
/// @custom:storage-location erc7201:ghostnet.storage.RewardsDistributor
struct RewardsDistributorStorage {
    IDataToken dataToken;
    IGhostCore ghostCore;
    
    uint256 startTime;
    uint256 lastDistributionTime;
    uint256 totalDistributed;
    
    // Level weights in basis points (must sum to 10000)
    uint16[5] levelWeights;
}
```

### Constants

```solidity
uint256 public constant TOTAL_EMISSIONS = 60_000_000e18;
uint256 public constant EMISSION_DURATION = 730 days; // 24 months
uint256 public constant DAILY_EMISSION = TOTAL_EMISSIONS / 730;
```

### Functions

```solidity
function initialize(
    IDataToken _dataToken,
    IGhostCore _ghostCore,
    address _admin,
    uint16[5] calldata _levelWeights
) external initializer;

/// @notice Distribute pending emissions to levels
function distribute() external {
    RewardsDistributorStorage storage $ = _getStorage();
    
    uint256 elapsed = block.timestamp - $.lastDistributionTime;
    uint256 toDistribute = (TOTAL_EMISSIONS * elapsed) / EMISSION_DURATION;
    
    // Cap at remaining
    uint256 remaining = TOTAL_EMISSIONS - $.totalDistributed;
    if (toDistribute > remaining) {
        toDistribute = remaining;
    }
    
    if (toDistribute == 0) return;
    
    // Distribute to each level
    for (uint8 level = 1; level <= 5; level++) {
        uint256 levelShare = (toDistribute * $.levelWeights[level - 1]) / 10000;
        if (levelShare > 0) {
            $.dataToken.approve(address($.ghostCore), levelShare);
            $.ghostCore.addEmissionRewards(level, levelShare);
        }
    }
    
    $.totalDistributed += toDistribute;
    $.lastDistributionTime = block.timestamp;
    
    emit EmissionsDistributed(toDistribute, $.totalDistributed);
}

/// @notice Gelato checker
function checker() external view returns (bool canExec, bytes memory execPayload) {
    RewardsDistributorStorage storage $ = _getStorage();
    
    uint256 elapsed = block.timestamp - $.lastDistributionTime;
    uint256 pending = (TOTAL_EMISSIONS * elapsed) / EMISSION_DURATION;
    
    // Distribute if more than 0.1% of daily pending
    if (pending > DAILY_EMISSION / 1000) {
        return (true, abi.encodeCall(this.distribute, ()));
    }
    
    return (false, bytes(""));
}

// View functions
function getPendingEmissions() external view returns (uint256);
function getTotalDistributed() external view returns (uint256);
function getRemainingEmissions() external view returns (uint256);
function getLevelWeights() external view returns (uint16[5] memory);

// Admin functions
function setLevelWeights(uint16[5] calldata weights) external onlyRole(DEFAULT_ADMIN_ROLE);
function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE);
```

### Events

```solidity
event EmissionsDistributed(uint256 amount, uint256 totalDistributed);
event LevelWeightsUpdated(uint16[5] weights);
```

---

## 8. DeadPool.sol

### Overview

```
Type:        Parimutuel Prediction Market
Upgradeable: YES (UUPS)
Inherits:    UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable
```

### Storage Layout

```solidity
/// @custom:storage-location erc7201:ghostnet.storage.DeadPool
struct DeadPoolStorage {
    IDataToken dataToken;
    ITraceScan traceScan;
    
    mapping(uint256 => Round) rounds;
    mapping(uint256 => mapping(address => Bet)) bets;
    
    uint256 roundCount;
    uint16 rakeBps; // Default 500 = 5%
}

struct Round {
    RoundType roundType;
    uint8 targetLevel;
    uint256 line;              // Over/under line
    uint256 overPool;          // Total bet on OVER
    uint256 underPool;         // Total bet on UNDER
    uint64 deadline;           // Betting closes
    uint64 resolveTime;        // When outcome known
    bool resolved;
    bool outcome;              // true = OVER won
    uint256 actualValue;       // Actual result
}

struct Bet {
    uint256 amount;
    bool isOver;
    bool claimed;
}

enum RoundType {
    DEATH_COUNT,      // Over/under deaths in scan
    WHALE_DEATH,      // Will a 1000+ position die?
    STREAK_BREAK,     // Will a 10+ streak break?
    SYSTEM_RESET      // Will timer hit < 1 hour?
}
```

### Functions

```solidity
// Round creation (admin or automated)
function createRound(
    RoundType roundType,
    uint8 targetLevel,
    uint256 line,
    uint64 deadline
) external onlyRole(ROUND_CREATOR_ROLE) returns (uint256 roundId);

// Betting
function placeBet(uint256 roundId, bool isOver, uint256 amount) external nonReentrant;
function cancelBet(uint256 roundId) external nonReentrant; // Only if round cancelled

// Resolution
function resolveRound(uint256 roundId, uint256 actualValue) external onlyRole(RESOLVER_ROLE);

// Claiming
function claimWinnings(uint256 roundId) external nonReentrant;
function claimMultiple(uint256[] calldata roundIds) external nonReentrant;

// View functions
function getRound(uint256 roundId) external view returns (Round memory);
function getBet(uint256 roundId, address user) external view returns (Bet memory);
function getWinnings(uint256 roundId, address user) external view returns (uint256);
function getImpliedOdds(uint256 roundId) external view returns (uint256 overOdds, uint256 underOdds);

// Admin
function setRake(uint16 rakeBps) external onlyRole(DEFAULT_ADMIN_ROLE);
function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE);
```

### Events

```solidity
event RoundCreated(uint256 indexed roundId, RoundType roundType, uint8 targetLevel, uint256 line, uint64 deadline);
event BetPlaced(uint256 indexed roundId, address indexed user, bool isOver, uint256 amount);
event RoundResolved(uint256 indexed roundId, bool outcome, uint256 actualValue, uint256 totalPot, uint256 burned);
event WinningsClaimed(uint256 indexed roundId, address indexed user, uint256 amount);
```

---

## 9. FeeRouter.sol

### Overview

```
Type:        Fee Collection & Buyback
Upgradeable: NO (simple, replaceable)
Inherits:    Ownable2Step, ReentrancyGuard
```

### Storage

```solidity
IDataToken public immutable dataToken;
address public dexRouter;      // Bronto/Bebop router
address public treasury;
address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

uint16 public buybackShareBps = 9000;  // 90% of ETH fees
uint16 public operationsShareBps = 1000; // 10% of ETH fees
```

### Functions

```solidity
/// @notice Receive ETH fees from transactions
receive() external payable {
    emit FeeReceived(msg.sender, msg.value);
}

/// @notice Execute buyback with accumulated ETH
/// @param minDataOut Minimum DATA tokens to receive (slippage protection)
/// @dev Slippage protection prevents sandwich attacks and DEX manipulation
function executeBuyback(uint256 minDataOut) external nonReentrant {
    uint256 ethBalance = address(this).balance;
    require(ethBalance > 0, "No ETH to process");
    
    uint256 buybackAmount = (ethBalance * buybackShareBps) / 10000;
    uint256 operationsAmount = ethBalance - buybackAmount;
    
    // Swap ETH for DATA with slippage protection
    uint256 dataReceived = _swapETHForDATA(buybackAmount, minDataOut);
    require(dataReceived >= minDataOut, "Slippage exceeded");
    
    // Burn received DATA
    dataToken.safeTransfer(DEAD, dataReceived);
    
    // Send to operations
    (bool success, ) = treasury.call{value: operationsAmount}("");
    require(success, "Operations transfer failed");
    
    emit BuybackExecuted(buybackAmount, dataReceived, operationsAmount);
}

/// @notice Get expected output for buyback (for frontend slippage calculation)
/// @param ethAmount Amount of ETH to quote
/// @return expectedData Expected DATA output at current prices
function getBuybackQuote(uint256 ethAmount) external view returns (uint256 expectedData);

function _swapETHForDATA(uint256 ethAmount, uint256 minOut) internal returns (uint256);

// Admin
function setDexRouter(address router) external onlyOwner;
function setTreasury(address newTreasury) external onlyOwner;
function setBuybackShare(uint16 shareBps) external onlyOwner;
function rescueTokens(address token, uint256 amount) external onlyOwner;
```

### Events

```solidity
event FeeReceived(address indexed from, uint256 amount);
event BuybackExecuted(uint256 ethSpent, uint256 dataBurned, uint256 operationsAmount);
event DexRouterUpdated(address indexed oldRouter, address indexed newRouter);
```

---

## 10. Governance Contracts

### GhostTimelock.sol

```solidity
// OpenZeppelin TimelockController with 48-hour minimum delay
// Proposers: Team multisig
// Executors: Team multisig
// Admin: Self (can update delay through timelock)

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GhostTimelock is TimelockController {
    constructor(
        uint256 minDelay,        // 48 hours = 172800 seconds
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
```

---

## 11. Libraries

### DeathMath.sol

```solidity
library DeathMath {
    /// @notice Calculate effective death rate with modifiers
    function calculateEffectiveDeathRate(
        uint16 baseRate,
        uint16 networkModifier,    // 8500 = 0.85x
        uint16 boostReduction      // 1500 = -15%
    ) internal pure returns (uint16) {
        // Apply network modifier
        uint256 modified = (uint256(baseRate) * networkModifier) / 10000;
        
        // Apply boost reduction
        if (boostReduction >= modified) {
            return 0;
        }
        return uint16(modified - boostReduction);
    }
    
    /// @notice Calculate network modifier based on TVL
    function calculateNetworkModifier(
        uint256 totalStaked,
        uint256[4] memory thresholds  // [1M, 5M, 10M, 20M] in wei
    ) internal pure returns (uint16) {
        if (totalStaked < thresholds[0]) return 12000;      // 1.2x (early danger)
        if (totalStaked < thresholds[1]) return 10000;      // 1.0x (normal)
        if (totalStaked < thresholds[2]) return 9000;       // 0.9x (safer)
        return 8500;                                         // 0.85x (strong)
    }
}
```

### CascadeLib.sol

```solidity
library CascadeLib {
    uint16 constant SAME_LEVEL = 3000;
    uint16 constant UPSTREAM = 3000;
    uint16 constant BURN = 3000;
    uint16 constant PROTOCOL = 1000;
    
    struct CascadeSplit {
        uint256 sameLevel;
        uint256 upstream;
        uint256 burn;
        uint256 protocol;
    }
    
    /// @notice Calculate cascade distribution split
    /// @param totalCapital Total dead capital to distribute
    /// @return split The calculated split amounts
    /// @dev Protocol amount is remainder to avoid dust accumulation
    function calculateSplit(uint256 totalCapital) internal pure returns (CascadeSplit memory split) {
        split.sameLevel = (totalCapital * SAME_LEVEL) / 10000;
        split.upstream = (totalCapital * UPSTREAM) / 10000;
        split.burn = (totalCapital * BURN) / 10000;
        // Protocol gets remainder - ensures no dust lost
        split.protocol = totalCapital - split.sameLevel - split.upstream - split.burn;
        
        // Invariant: sum must equal total (verified in tests)
        // assert(split.sameLevel + split.upstream + split.burn + split.protocol == totalCapital);
    }
}
```

---

## 12. Interfaces

### IDataToken.sol

```solidity
interface IDataToken is IERC20 {
    function setTaxExclusion(address account, bool excluded) external;
    function isExcludedFromTax(address account) external view returns (bool);
    function treasury() external view returns (address);
}
```

### IGhostCore.sol

```solidity
interface IGhostCore {
    struct Position {
        uint256 amount;
        uint8 level;
        uint64 entryTimestamp;
        uint64 lastAddTimestamp;
        uint256 rewardDebt;
        bool alive;
        uint16 ghostStreak;
    }
    
    struct LevelConfig {
        uint16 baseDeathRateBps;
        uint32 scanInterval;
        uint256 minStake;
        uint256 totalStaked;
        uint256 aliveCount;
        uint256 accRewardsPerShare;
        uint64 nextScanTime;
    }
    
    struct SystemReset {
        uint64 deadline;
        address lastDepositor;
        uint64 lastDepositTime;
    }
    
    // Player functions
    function jackIn(uint256 amount, uint8 level) external;
    function extract() external;
    function claimRewards() external;
    
    // Scanner functions
    function processDeaths(uint8 level, address[] calldata deadUsers, uint256 totalCapital) external;
    function incrementGhostStreak(uint8 level, address[] calldata survivors) external;
    function updateNextScanTime(uint8 level) external;
    
    // Distributor functions
    function addEmissionRewards(uint8 level, uint256 amount) external;
    
    // View functions
    function getPosition(address user) external view returns (Position memory);
    function getLevelConfig(uint8 level) external view returns (LevelConfig memory);
    function getEffectiveDeathRate(address user) external view returns (uint16);
    function getPendingRewards(address user) external view returns (uint256);
    function getSystemResetInfo() external view returns (SystemReset memory);
    function getTotalValueLocked() external view returns (uint256);
}
```

### ITraceScan.sol

```solidity
interface ITraceScan {
    struct Scan {
        uint256 seed;
        uint64 executedAt;
        uint64 finalizedAt;
        uint256 totalDeadCapital;
        uint256 deathCount;
        bool active;
        bool finalized;
    }
    
    function executeScan(uint8 level) external;
    function submitDeaths(uint8 level, address[] calldata deadUsers) external;
    function finalizeScan(uint8 level) external;
    
    function canExecuteScan(uint8 level) external view returns (bool);
    function canFinalizeScan(uint8 level) external view returns (bool);
    function getCurrentScan(uint8 level) external view returns (Scan memory);
    function wouldDie(address user) external view returns (bool);
}
```

### IRewardsDistributor.sol

```solidity
interface IRewardsDistributor {
    function distribute() external;
    function getPendingEmissions() external view returns (uint256);
    function getTotalDistributed() external view returns (uint256);
    function getRemainingEmissions() external view returns (uint256);
}
```

---

## File Structure

```
packages/contracts/src/
├── token/
│   ├── DataToken.sol
│   ├── TeamVesting.sol
│   └── interfaces/
│       └── IDataToken.sol
│
├── core/
│   ├── GhostCore.sol
│   ├── TraceScan.sol
│   ├── RewardsDistributor.sol
│   └── interfaces/
│       ├── IGhostCore.sol
│       ├── ITraceScan.sol
│       └── IRewardsDistributor.sol
│
├── markets/
│   ├── DeadPool.sol
│   └── interfaces/
│       └── IDeadPool.sol
│
├── periphery/
│   └── FeeRouter.sol
│
├── governance/
│   └── GhostTimelock.sol
│
├── libraries/
│   ├── DeathMath.sol
│   └── CascadeLib.sol
│
└── test/
    └── PrevRandaoTest.sol
```

---

*Document Version: 1.0*
*Last Updated: January 2026*
