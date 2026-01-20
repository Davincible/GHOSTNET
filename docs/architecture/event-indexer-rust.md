# GHOSTNET Event Indexer - Rust Backend Architecture

> **Version**: 1.0.0  
> **Last Updated**: 2026-01-20  
> **Status**: Specification

This document provides the complete architecture specification for building a Rust-based event indexer backend for the GHOSTNET protocol. The indexer is responsible for parsing, processing, and serving blockchain events from all GHOSTNET smart contracts.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Contract Event Catalog](#2-contract-event-catalog)
3. [Project Structure](#3-project-structure)
4. [Dependencies](#4-dependencies)
5. [Type Definitions](#5-type-definitions)
6. [ABI Bindings](#6-abi-bindings)
7. [Event Router](#7-event-router)
8. [Database Schema](#8-database-schema)
9. [Processing Architecture](#9-processing-architecture)
10. [API Specification](#10-api-specification)
11. [Deployment](#11-deployment)
12. [Implementation Checklist](#12-implementation-checklist)

---

## 1. Overview

### Purpose

The GHOSTNET Event Indexer serves as the backbone for:
- **Real-time event processing** from all GHOSTNET smart contracts
- **Historical data aggregation** for analytics and leaderboards
- **API layer** for frontend applications
- **WebSocket feeds** for live updates

### Key Requirements

| Requirement | Target |
|-------------|--------|
| Block processing latency | < 500ms from block confirmation |
| API response time (p99) | < 100ms |
| Reorg handling depth | 64 blocks |
| Data retention | Indefinite (full history) |
| Availability | 99.9% uptime |

### Technology Stack

- **Language**: Rust (2021 edition)
- **Async Runtime**: Tokio
- **Ethereum Client**: Alloy
- **Database**: PostgreSQL 15+
- **Cache**: Redis 7+
- **API Framework**: Axum
- **Metrics**: Prometheus

---

## 2. Contract Event Catalog

### 2.1 Contract Addresses

The following contracts emit events that must be indexed:

| Contract | Type | Description |
|----------|------|-------------|
| `DataToken` | Non-upgradeable | ERC20 token with transfer tax |
| `GhostCore` | UUPS Proxy | Main game logic |
| `TraceScan` | UUPS Proxy | Scan execution & death processing |
| `DeadPool` | UUPS Proxy | Prediction markets |
| `FeeRouter` | Non-upgradeable | Fee collection & buyback |
| `RewardsDistributor` | Non-upgradeable | Emission distribution |
| `TeamVesting` | Non-upgradeable | Team token vesting |

### 2.2 GhostCore Events

The core game contract emits events for position lifecycle and game mechanics.

```solidity
/// @notice Emitted when a user enters a position
event JackedIn(
    address indexed user,      // User's wallet address
    uint256 amount,            // Amount of DATA staked
    Level indexed level,       // Risk level (1-5)
    uint256 newTotal           // Total staked after this action
);

/// @notice Emitted when a user adds to existing position
event StakeAdded(
    address indexed user,      // User's wallet address
    uint256 amount,            // Amount added
    uint256 newTotal           // New total stake
);

/// @notice Emitted when a user extracts their position
event Extracted(
    address indexed user,      // User's wallet address
    uint256 amount,            // Principal returned
    uint256 rewards            // Rewards earned
);

/// @notice Emitted when positions are marked dead from a scan
event DeathsProcessed(
    Level indexed level,       // Which level was scanned
    uint256 count,             // Number of deaths in this batch
    uint256 totalDead,         // Total DATA from dead positions
    uint256 burned,            // Amount burned (30%)
    uint256 distributed        // Amount distributed to survivors
);

/// @notice Emitted when ghost streaks are incremented for survivors
event SurvivorsUpdated(
    Level indexed level,       // Which level
    uint256 count              // Number of survivors
);

/// @notice Emitted when cascade rewards are distributed
event CascadeDistributed(
    Level indexed sourceLevel, // Level where deaths occurred
    uint256 sameLevelAmount,   // Distributed to same-level survivors (30%)
    uint256 upstreamAmount,    // Distributed to safer levels (30%)
    uint256 burnAmount,        // Burned (30%)
    uint256 protocolAmount     // To treasury (10%)
);

/// @notice Emitted when emissions are added to a level
event EmissionsAdded(
    Level indexed level,       // Target level
    uint256 amount             // Amount of emissions
);

/// @notice Emitted when a boost is applied
event BoostApplied(
    address indexed user,      // User receiving boost
    BoostType boostType,       // Type of boost (0=DeathReduction, 1=YieldMultiplier)
    uint16 valueBps,           // Boost value in basis points
    uint64 expiry              // Unix timestamp when boost expires
);

/// @notice Emitted when system reset is triggered
event SystemResetTriggered(
    uint256 totalPenalty,      // Total penalty extracted from all positions
    address indexed jackpotWinner, // Last depositor wins jackpot
    uint256 jackpotAmount      // Jackpot payout
);

/// @notice Emitted when a position is culled (level at capacity)
event PositionCulled(
    address indexed victim,    // User who was culled
    uint256 penaltyAmount,     // Penalty taken
    uint256 returnedAmount,    // Amount returned to victim
    address indexed newEntrant // User who triggered culling
);
```

### 2.3 TraceScan Events

The scan execution contract emits events for the scan lifecycle.

```solidity
/// @notice Emitted when a scan is executed (Phase 1)
event ScanExecuted(
    Level indexed level,       // Which level is being scanned
    uint256 indexed scanId,    // Unique scan identifier
    uint256 seed,              // Deterministic seed from prevrandao
    uint64 executedAt          // Unix timestamp
);

/// @notice Emitted when deaths are submitted in a batch
event DeathsSubmitted(
    Level indexed level,       // Which level
    uint256 indexed scanId,    // Which scan
    uint256 count,             // Deaths in this batch
    uint256 totalDead,         // Total DATA from deaths
    address indexed submitter  // Who submitted (for keeper rewards)
);

/// @notice Emitted when a scan is finalized (Phase 2)
event ScanFinalized(
    Level indexed level,       // Which level
    uint256 indexed scanId,    // Which scan
    uint256 deathCount,        // Total deaths processed
    uint256 totalDead,         // Total DATA lost
    uint64 finalizedAt         // Unix timestamp
);
```

### 2.4 DeadPool Events

The prediction market contract emits events for betting rounds.

```solidity
/// @notice Emitted when a new betting round is created
event RoundCreated(
    uint256 indexed roundId,   // Unique round identifier
    RoundType roundType,       // Type: DeathCount, WhaleDeath, StreakRecord, SystemReset
    Level indexed targetLevel, // Which level (if applicable)
    uint256 line,              // Over/under line
    uint64 deadline            // Betting closes at
);

/// @notice Emitted when a bet is placed
event BetPlaced(
    uint256 indexed roundId,   // Which round
    address indexed user,      // Bettor's address
    bool isOver,               // true = OVER, false = UNDER
    uint256 amount             // Amount wagered
);

/// @notice Emitted when a round is resolved
event RoundResolved(
    uint256 indexed roundId,   // Which round
    bool outcome,              // true = OVER won, false = UNDER won
    uint256 totalPot,          // Total pot size
    uint256 burned             // Rake burned (5%)
);

/// @notice Emitted when winnings are claimed
event WinningsClaimed(
    uint256 indexed roundId,   // Which round
    address indexed user,      // Winner's address
    uint256 amount             // Payout amount
);
```

### 2.5 DataToken Events

The ERC20 token emits standard and custom events.

```solidity
/// @notice Standard ERC20 transfer
event Transfer(
    address indexed from,      // Sender (0x0 for mints)
    address indexed to,        // Recipient (DEAD_ADDRESS for burns)
    uint256 value              // Amount transferred
);

/// @notice Standard ERC20 approval
event Approval(
    address indexed owner,     // Token owner
    address indexed spender,   // Approved spender
    uint256 value              // Approved amount
);

/// @notice Emitted when tax exclusion status changes
event TaxExclusionSet(
    address indexed account,   // Affected address
    bool excluded              // New exclusion status
);

/// @notice Emitted when tokens are burned via tax
event TaxBurned(
    address indexed from,      // Transfer sender
    uint256 amount             // Amount burned (9% of 10% tax)
);

/// @notice Emitted when tokens are sent to treasury via tax
event TaxCollected(
    address indexed from,      // Transfer sender
    uint256 amount             // Amount to treasury (1% of 10% tax)
);
```

### 2.6 FeeRouter Events

The fee collection contract emits events for monetization flows.

```solidity
/// @notice Emitted when toll is collected (per-action fee)
event TollCollected(
    address indexed from,      // Who paid the toll
    uint256 amount,            // ETH amount
    bytes32 indexed reason     // Action identifier (e.g., "jackIn")
);

/// @notice Emitted when buyback is executed
event BuybackExecuted(
    uint256 ethSpent,          // ETH used for buyback
    uint256 dataReceived,      // DATA tokens bought
    uint256 dataBurned         // DATA tokens burned
);

/// @notice Emitted when operations funds are withdrawn
event OperationsWithdrawn(
    address indexed to,        // Recipient
    uint256 amount             // ETH amount
);

/// @notice Emitted when swap router is updated
event SwapRouterUpdated(
    address indexed newRouter  // New router address
);

/// @notice Emitted when toll amount is updated
event TollAmountUpdated(
    uint256 newAmount          // New toll in wei
);

/// @notice Emitted when operations wallet is updated
event OperationsWalletUpdated(
    address indexed newWallet  // New wallet address
);
```

### 2.7 RewardsDistributor Events

The emission distribution contract emits events for reward flows.

```solidity
/// @notice Emitted when emissions are distributed across levels
event EmissionsDistributed(
    uint256 totalAmount,       // Total DATA distributed
    uint256 timestamp          // Unix timestamp
);

/// @notice Emitted when level weights are updated
event WeightsUpdated(
    uint16[5] newWeights       // New weights for levels 1-5
);

/// @notice Emitted when GhostCore address is updated
event GhostCoreUpdated(
    address newGhostCore       // New GhostCore address
);
```

### 2.8 TeamVesting Events

The vesting contract emits events for team token releases.

```solidity
/// @notice Emitted when a team member claims vested tokens
event TokensClaimed(
    address indexed beneficiary, // Team member's address
    uint256 amount               // Amount claimed
);
```

### 2.9 Enum Definitions

For reference, these enums are used in events:

```solidity
/// @notice Risk levels (stored as uint8)
enum Level {
    NONE,       // 0 - Invalid/No position
    VAULT,      // 1 - Safest (5% death rate)
    MAINFRAME,  // 2 - Conservative (15% death rate)
    SUBNET,     // 3 - Balanced (25% death rate)
    DARKNET,    // 4 - High risk (35% death rate)
    BLACK_ICE   // 5 - Maximum risk (45% death rate)
}

/// @notice Boost types (stored as uint8)
enum BoostType {
    DEATH_REDUCTION,  // 0 - Reduces effective death rate
    YIELD_MULTIPLIER  // 1 - Multiplies reward earnings
}

/// @notice Prediction round types (stored as uint8)
enum RoundType {
    DEATH_COUNT,   // 0 - Over/under deaths in next scan
    WHALE_DEATH,   // 1 - Will a 1000+ DATA position die?
    STREAK_RECORD, // 2 - Will anyone hit 20 survival streak?
    SYSTEM_RESET   // 3 - Will timer hit <1 hour?
}
```

---

## 3. Project Structure

```
ghostnet-indexer/
├── Cargo.toml                     # Project manifest
├── Cargo.lock                     # Dependency lock file
├── .env.example                   # Environment template
├── config/
│   ├── default.toml               # Default configuration
│   ├── development.toml           # Dev overrides
│   └── production.toml            # Prod overrides
│
├── src/
│   ├── main.rs                    # Entry point & CLI
│   ├── lib.rs                     # Library root
│   │
│   ├── config/                    # Configuration module
│   │   ├── mod.rs
│   │   ├── settings.rs            # Config loading
│   │   └── contracts.rs           # Contract addresses & ABIs
│   │
│   ├── types/                     # Domain types
│   │   ├── mod.rs
│   │   ├── enums.rs               # Level, BoostType, RoundType
│   │   ├── events.rs              # Strongly-typed event structs
│   │   ├── entities.rs            # Position, Round, Scan, etc.
│   │   └── primitives.rs          # Address, U256 wrappers
│   │
│   ├── abi/                       # ABI bindings
│   │   ├── mod.rs                 # Re-exports all bindings
│   │   ├── ghost_core.rs          # GhostCore events
│   │   ├── trace_scan.rs          # TraceScan events
│   │   ├── dead_pool.rs           # DeadPool events
│   │   ├── data_token.rs          # DataToken events
│   │   ├── fee_router.rs          # FeeRouter events
│   │   └── rewards_distributor.rs # RewardsDistributor events
│   │
│   ├── indexer/                   # Core indexing logic
│   │   ├── mod.rs
│   │   ├── block_processor.rs     # Block-by-block processing
│   │   ├── log_decoder.rs         # Event log decoding
│   │   ├── event_router.rs        # Route events to handlers
│   │   ├── reorg_handler.rs       # Chain reorganization
│   │   └── checkpoint.rs          # Progress tracking
│   │
│   ├── handlers/                  # Event handlers
│   │   ├── mod.rs
│   │   ├── position_handler.rs    # JackedIn, StakeAdded, Extracted
│   │   ├── scan_handler.rs        # Scan lifecycle events
│   │   ├── death_handler.rs       # Death processing events
│   │   ├── market_handler.rs      # DeadPool events
│   │   ├── token_handler.rs       # Transfer, Tax events
│   │   ├── fee_handler.rs         # FeeRouter events
│   │   └── admin_handler.rs       # Config change events
│   │
│   ├── store/                     # Data persistence
│   │   ├── mod.rs
│   │   ├── traits.rs              # Store trait definitions
│   │   ├── postgres.rs            # PostgreSQL implementation
│   │   ├── redis.rs               # Redis cache layer
│   │   └── models/                # Database models
│   │       ├── mod.rs
│   │       ├── positions.rs
│   │       ├── scans.rs
│   │       ├── deaths.rs
│   │       ├── markets.rs
│   │       ├── transfers.rs
│   │       └── analytics.rs
│   │
│   ├── api/                       # HTTP API
│   │   ├── mod.rs
│   │   ├── server.rs              # Axum server setup
│   │   ├── routes/                # Route definitions
│   │   │   ├── mod.rs
│   │   │   ├── positions.rs
│   │   │   ├── scans.rs
│   │   │   ├── markets.rs
│   │   │   ├── leaderboards.rs
│   │   │   └── analytics.rs
│   │   ├── handlers/              # Request handlers
│   │   │   ├── mod.rs
│   │   │   └── ...
│   │   ├── websocket.rs           # WebSocket handler
│   │   └── middleware.rs          # Auth, CORS, logging
│   │
│   └── utils/
│       ├── mod.rs
│       ├── metrics.rs             # Prometheus metrics
│       ├── logging.rs             # Structured logging
│       └── health.rs              # Health checks
│
├── migrations/                    # SQL migrations
│   ├── 20260120000001_initial_schema.sql
│   ├── 20260120000002_positions.sql
│   ├── 20260120000003_scans.sql
│   ├── 20260120000004_markets.sql
│   ├── 20260120000005_analytics.sql
│   └── 20260120000006_indexes.sql
│
├── abis/                          # JSON ABIs (from Foundry)
│   ├── GhostCore.json
│   ├── TraceScan.json
│   ├── DeadPool.json
│   ├── DataToken.json
│   ├── FeeRouter.json
│   └── RewardsDistributor.json
│
└── tests/                         # Integration tests
    ├── common/
    │   └── mod.rs
    ├── indexer_tests.rs
    ├── handler_tests.rs
    └── api_tests.rs
```

---

## 4. Dependencies

### Cargo.toml

```toml
[package]
name = "ghostnet-indexer"
version = "0.1.0"
edition = "2021"
authors = ["GHOSTNET Team"]
description = "Event indexer for the GHOSTNET protocol"
license = "MIT"
repository = "https://github.com/ghostnet/indexer"

[dependencies]
# ═══════════════════════════════════════════════════════════════════════════════
# ETHEREUM
# ═══════════════════════════════════════════════════════════════════════════════
alloy = { version = "0.9", features = [
    "full",
    "provider-http",
    "provider-ws",
    "rpc-types-eth",
] }
alloy-sol-types = "0.9"
alloy-primitives = "0.9"

# ═══════════════════════════════════════════════════════════════════════════════
# ASYNC RUNTIME
# ═══════════════════════════════════════════════════════════════════════════════
tokio = { version = "1", features = ["full", "tracing"] }
futures = "0.3"
async-trait = "0.1"

# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE
# ═══════════════════════════════════════════════════════════════════════════════
sqlx = { version = "0.8", features = [
    "runtime-tokio",
    "postgres",
    "chrono",
    "uuid",
    "bigdecimal",
    "migrate",
] }
redis = { version = "0.27", features = ["tokio-comp", "connection-manager"] }

# ═══════════════════════════════════════════════════════════════════════════════
# WEB FRAMEWORK
# ═══════════════════════════════════════════════════════════════════════════════
axum = { version = "0.7", features = ["ws", "macros"] }
axum-extra = { version = "0.9", features = ["typed-header"] }
tower = { version = "0.5", features = ["util", "timeout", "limit"] }
tower-http = { version = "0.6", features = [
    "cors",
    "trace",
    "compression-gzip",
    "request-id",
] }
hyper = { version = "1", features = ["full"] }

# ═══════════════════════════════════════════════════════════════════════════════
# SERIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_with = "3"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & CLI
# ═══════════════════════════════════════════════════════════════════════════════
clap = { version = "4", features = ["derive", "env"] }
config = { version = "0.14", features = ["toml"] }
dotenvy = "0.15"

# ═══════════════════════════════════════════════════════════════════════════════
# OBSERVABILITY
# ═══════════════════════════════════════════════════════════════════════════════
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = [
    "env-filter",
    "json",
    "fmt",
] }
tracing-appender = "0.2"
metrics = "0.24"
metrics-exporter-prometheus = "0.16"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════
thiserror = "2"
anyhow = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "v7", "serde"] }
bigdecimal = { version = "0.4", features = ["serde"] }
hex = "0.4"
parking_lot = "0.12"
dashmap = "6"

[dev-dependencies]
tokio-test = "0.4"
wiremock = "0.6"
testcontainers = "0.23"
testcontainers-modules = { version = "0.11", features = ["postgres", "redis"] }
criterion = { version = "0.5", features = ["async_tokio"] }
proptest = "1"

[profile.release]
lto = true
codegen-units = 1
strip = true

[[bin]]
name = "ghostnet-indexer"
path = "src/main.rs"
```

---

## 5. Type Definitions

### 5.1 Enums (src/types/enums.rs)

```rust
use serde::{Deserialize, Serialize};
use sqlx::Type;

/// Risk levels from safest (1) to most dangerous (5)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
pub enum Level {
    None = 0,
    Vault = 1,
    Mainframe = 2,
    Subnet = 3,
    Darknet = 4,
    BlackIce = 5,
}

impl Level {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(Self::None),
            1 => Some(Self::Vault),
            2 => Some(Self::Mainframe),
            3 => Some(Self::Subnet),
            4 => Some(Self::Darknet),
            5 => Some(Self::BlackIce),
            _ => None,
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Self::None => "None",
            Self::Vault => "Vault",
            Self::Mainframe => "Mainframe",
            Self::Subnet => "Subnet",
            Self::Darknet => "Darknet",
            Self::BlackIce => "Black Ice",
        }
    }

    pub fn death_rate_bps(&self) -> u16 {
        match self {
            Self::None => 0,
            Self::Vault => 500,      // 5%
            Self::Mainframe => 1500, // 15%
            Self::Subnet => 2500,    // 25%
            Self::Darknet => 3500,   // 35%
            Self::BlackIce => 4500,  // 45%
        }
    }
}

/// Types of boosts that can be applied to positions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
pub enum BoostType {
    DeathReduction = 0,
    YieldMultiplier = 1,
}

impl BoostType {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(Self::DeathReduction),
            1 => Some(Self::YieldMultiplier),
            _ => None,
        }
    }
}

/// Types of prediction rounds
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
pub enum RoundType {
    DeathCount = 0,
    WhaleDeath = 1,
    StreakRecord = 2,
    SystemReset = 3,
}

impl RoundType {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(Self::DeathCount),
            1 => Some(Self::WhaleDeath),
            2 => Some(Self::StreakRecord),
            3 => Some(Self::SystemReset),
            _ => None,
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Self::DeathCount => "Death Count",
            Self::WhaleDeath => "Whale Death",
            Self::StreakRecord => "Streak Record",
            Self::SystemReset => "System Reset",
        }
    }
}
```

### 5.2 Event Structs (src/types/events.rs)

```rust
use alloy_primitives::{Address, B256, U256};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::enums::{BoostType, Level, RoundType};

/// Metadata attached to every event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventMetadata {
    pub block_number: u64,
    pub block_hash: B256,
    pub tx_hash: B256,
    pub tx_index: u64,
    pub log_index: u64,
    pub timestamp: DateTime<Utc>,
    pub contract: Address,
}

/// Unified enum for all GHOSTNET events
#[derive(Debug, Clone)]
pub enum GhostnetEvent {
    // ═══════════════════════════════════════════════════════════════════════════
    // GHOST CORE
    // ═══════════════════════════════════════════════════════════════════════════
    JackedIn(JackedInEvent),
    StakeAdded(StakeAddedEvent),
    Extracted(ExtractedEvent),
    DeathsProcessed(DeathsProcessedEvent),
    SurvivorsUpdated(SurvivorsUpdatedEvent),
    CascadeDistributed(CascadeDistributedEvent),
    EmissionsAdded(EmissionsAddedEvent),
    BoostApplied(BoostAppliedEvent),
    SystemResetTriggered(SystemResetTriggeredEvent),
    PositionCulled(PositionCulledEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // TRACE SCAN
    // ═══════════════════════════════════════════════════════════════════════════
    ScanExecuted(ScanExecutedEvent),
    DeathsSubmitted(DeathsSubmittedEvent),
    ScanFinalized(ScanFinalizedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // DEAD POOL
    // ═══════════════════════════════════════════════════════════════════════════
    RoundCreated(RoundCreatedEvent),
    BetPlaced(BetPlacedEvent),
    RoundResolved(RoundResolvedEvent),
    WinningsClaimed(WingsClaimedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // DATA TOKEN
    // ═══════════════════════════════════════════════════════════════════════════
    Transfer(TransferEvent),
    TaxBurned(TaxBurnedEvent),
    TaxCollected(TaxCollectedEvent),
    TaxExclusionSet(TaxExclusionSetEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE ROUTER
    // ═══════════════════════════════════════════════════════════════════════════
    TollCollected(TollCollectedEvent),
    BuybackExecuted(BuybackExecutedEvent),
    OperationsWithdrawn(OperationsWithdrawnEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // REWARDS DISTRIBUTOR
    // ═══════════════════════════════════════════════════════════════════════════
    EmissionsDistributed(EmissionsDistributedEvent),
    WeightsUpdated(WeightsUpdatedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // TEAM VESTING
    // ═══════════════════════════════════════════════════════════════════════════
    TokensClaimed(TokensClaimedEvent),
}

// ═══════════════════════════════════════════════════════════════════════════════
// GHOST CORE EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JackedInEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub level: Level,
    pub new_total: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StakeAddedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub new_total: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtractedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub rewards: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeathsProcessedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub count: U256,
    pub total_dead: U256,
    pub burned: U256,
    pub distributed: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SurvivorsUpdatedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub count: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CascadeDistributedEvent {
    pub meta: EventMetadata,
    pub source_level: Level,
    pub same_level_amount: U256,
    pub upstream_amount: U256,
    pub burn_amount: U256,
    pub protocol_amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmissionsAddedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BoostAppliedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub boost_type: BoostType,
    pub value_bps: u16,
    pub expiry: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemResetTriggeredEvent {
    pub meta: EventMetadata,
    pub total_penalty: U256,
    pub jackpot_winner: Address,
    pub jackpot_amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PositionCulledEvent {
    pub meta: EventMetadata,
    pub victim: Address,
    pub penalty_amount: U256,
    pub returned_amount: U256,
    pub new_entrant: Address,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE SCAN EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanExecutedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub scan_id: U256,
    pub seed: U256,
    pub executed_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeathsSubmittedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub scan_id: U256,
    pub count: U256,
    pub total_dead: U256,
    pub submitter: Address,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanFinalizedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub scan_id: U256,
    pub death_count: U256,
    pub total_dead: U256,
    pub finalized_at: u64,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD POOL EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoundCreatedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub round_type: RoundType,
    pub target_level: Level,
    pub line: U256,
    pub deadline: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BetPlacedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub user: Address,
    pub is_over: bool,
    pub amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoundResolvedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub outcome: bool,
    pub total_pot: U256,
    pub burned: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WingsClaimedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub user: Address,
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA TOKEN EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub to: Address,
    pub value: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxBurnedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxCollectedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxExclusionSetEvent {
    pub meta: EventMetadata,
    pub account: Address,
    pub excluded: bool,
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEE ROUTER EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TollCollectedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
    pub reason: B256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BuybackExecutedEvent {
    pub meta: EventMetadata,
    pub eth_spent: U256,
    pub data_received: U256,
    pub data_burned: U256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OperationsWithdrawnEvent {
    pub meta: EventMetadata,
    pub to: Address,
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARDS DISTRIBUTOR EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmissionsDistributedEvent {
    pub meta: EventMetadata,
    pub total_amount: U256,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeightsUpdatedEvent {
    pub meta: EventMetadata,
    pub new_weights: [u16; 5],
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM VESTING EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokensClaimedEvent {
    pub meta: EventMetadata,
    pub beneficiary: Address,
    pub amount: U256,
}
```

---

## 6. ABI Bindings

Use `alloy-sol-types` macro to generate type-safe event bindings.

### 6.1 GhostCore ABI (src/abi/ghost_core.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event JackedIn(
        address indexed user,
        uint256 amount,
        uint8 indexed level,
        uint256 newTotal
    );

    #[derive(Debug, PartialEq, Eq)]
    event StakeAdded(
        address indexed user,
        uint256 amount,
        uint256 newTotal
    );

    #[derive(Debug, PartialEq, Eq)]
    event Extracted(
        address indexed user,
        uint256 amount,
        uint256 rewards
    );

    #[derive(Debug, PartialEq, Eq)]
    event DeathsProcessed(
        uint8 indexed level,
        uint256 count,
        uint256 totalDead,
        uint256 burned,
        uint256 distributed
    );

    #[derive(Debug, PartialEq, Eq)]
    event SurvivorsUpdated(
        uint8 indexed level,
        uint256 count
    );

    #[derive(Debug, PartialEq, Eq)]
    event CascadeDistributed(
        uint8 indexed sourceLevel,
        uint256 sameLevelAmount,
        uint256 upstreamAmount,
        uint256 burnAmount,
        uint256 protocolAmount
    );

    #[derive(Debug, PartialEq, Eq)]
    event EmissionsAdded(
        uint8 indexed level,
        uint256 amount
    );

    #[derive(Debug, PartialEq, Eq)]
    event BoostApplied(
        address indexed user,
        uint8 boostType,
        uint16 valueBps,
        uint64 expiry
    );

    #[derive(Debug, PartialEq, Eq)]
    event SystemResetTriggered(
        uint256 totalPenalty,
        address indexed jackpotWinner,
        uint256 jackpotAmount
    );

    #[derive(Debug, PartialEq, Eq)]
    event PositionCulled(
        address indexed victim,
        uint256 penaltyAmount,
        uint256 returnedAmount,
        address indexed newEntrant
    );
}
```

### 6.2 TraceScan ABI (src/abi/trace_scan.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event ScanExecuted(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 seed,
        uint64 executedAt
    );

    #[derive(Debug, PartialEq, Eq)]
    event DeathsSubmitted(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 count,
        uint256 totalDead,
        address indexed submitter
    );

    #[derive(Debug, PartialEq, Eq)]
    event ScanFinalized(
        uint8 indexed level,
        uint256 indexed scanId,
        uint256 deathCount,
        uint256 totalDead,
        uint64 finalizedAt
    );
}
```

### 6.3 DeadPool ABI (src/abi/dead_pool.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event RoundCreated(
        uint256 indexed roundId,
        uint8 roundType,
        uint8 indexed targetLevel,
        uint256 line,
        uint64 deadline
    );

    #[derive(Debug, PartialEq, Eq)]
    event BetPlaced(
        uint256 indexed roundId,
        address indexed user,
        bool isOver,
        uint256 amount
    );

    #[derive(Debug, PartialEq, Eq)]
    event RoundResolved(
        uint256 indexed roundId,
        bool outcome,
        uint256 totalPot,
        uint256 burned
    );

    #[derive(Debug, PartialEq, Eq)]
    event WinningsClaimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount
    );
}
```

### 6.4 DataToken ABI (src/abi/data_token.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    #[derive(Debug, PartialEq, Eq)]
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    #[derive(Debug, PartialEq, Eq)]
    event TaxExclusionSet(
        address indexed account,
        bool excluded
    );

    #[derive(Debug, PartialEq, Eq)]
    event TaxBurned(
        address indexed from,
        uint256 amount
    );

    #[derive(Debug, PartialEq, Eq)]
    event TaxCollected(
        address indexed from,
        uint256 amount
    );
}
```

### 6.5 FeeRouter ABI (src/abi/fee_router.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event TollCollected(
        address indexed from,
        uint256 amount,
        bytes32 indexed reason
    );

    #[derive(Debug, PartialEq, Eq)]
    event BuybackExecuted(
        uint256 ethSpent,
        uint256 dataReceived,
        uint256 dataBurned
    );

    #[derive(Debug, PartialEq, Eq)]
    event OperationsWithdrawn(
        address indexed to,
        uint256 amount
    );

    #[derive(Debug, PartialEq, Eq)]
    event SwapRouterUpdated(
        address indexed newRouter
    );

    #[derive(Debug, PartialEq, Eq)]
    event TollAmountUpdated(
        uint256 newAmount
    );

    #[derive(Debug, PartialEq, Eq)]
    event OperationsWalletUpdated(
        address indexed newWallet
    );
}
```

### 6.6 RewardsDistributor ABI (src/abi/rewards_distributor.rs)

```rust
use alloy_sol_types::sol;

sol! {
    #[derive(Debug, PartialEq, Eq)]
    event EmissionsDistributed(
        uint256 totalAmount,
        uint256 timestamp
    );

    #[derive(Debug, PartialEq, Eq)]
    event WeightsUpdated(
        uint16[5] newWeights
    );

    #[derive(Debug, PartialEq, Eq)]
    event GhostCoreUpdated(
        address newGhostCore
    );
}
```

---

## 7. Event Router

The event router is responsible for decoding raw logs and dispatching to appropriate handlers.

### 7.1 Router Implementation (src/indexer/event_router.rs)

```rust
use alloy::rpc::types::Log;
use alloy_sol_types::SolEvent;
use anyhow::Result;
use tracing::{debug, instrument, warn};

use crate::abi::{data_token, dead_pool, fee_router, ghost_core, trace_scan};
use crate::handlers::*;
use crate::types::events::EventMetadata;

/// Routes decoded events to appropriate handlers
pub struct EventRouter {
    position_handler: PositionHandler,
    scan_handler: ScanHandler,
    death_handler: DeathHandler,
    market_handler: MarketHandler,
    token_handler: TokenHandler,
    fee_handler: FeeHandler,
}

impl EventRouter {
    pub fn new(
        position_handler: PositionHandler,
        scan_handler: ScanHandler,
        death_handler: DeathHandler,
        market_handler: MarketHandler,
        token_handler: TokenHandler,
        fee_handler: FeeHandler,
    ) -> Self {
        Self {
            position_handler,
            scan_handler,
            death_handler,
            market_handler,
            token_handler,
            fee_handler,
        }
    }

    /// Route a single log to its handler
    #[instrument(skip(self, log, meta), fields(topic0 = ?log.topics().first()))]
    pub async fn route_log(&self, log: &Log, meta: EventMetadata) -> Result<()> {
        let topic0 = match log.topics().first() {
            Some(t) => t,
            None => {
                debug!("Skipping log with no topics");
                return Ok(());
            }
        };

        // Match by event signature hash (topic0)
        match topic0.as_slice() {
            // ═══════════════════════════════════════════════════════════════════
            // GHOST CORE EVENTS
            // ═══════════════════════════════════════════════════════════════════
            x if x == ghost_core::JackedIn::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::JackedIn::decode_log(&log.inner, true)?;
                self.position_handler.handle_jacked_in(event, meta).await
            }
            x if x == ghost_core::StakeAdded::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::StakeAdded::decode_log(&log.inner, true)?;
                self.position_handler.handle_stake_added(event, meta).await
            }
            x if x == ghost_core::Extracted::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::Extracted::decode_log(&log.inner, true)?;
                self.position_handler.handle_extracted(event, meta).await
            }
            x if x == ghost_core::DeathsProcessed::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::DeathsProcessed::decode_log(&log.inner, true)?;
                self.death_handler.handle_deaths_processed(event, meta).await
            }
            x if x == ghost_core::SurvivorsUpdated::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::SurvivorsUpdated::decode_log(&log.inner, true)?;
                self.death_handler.handle_survivors_updated(event, meta).await
            }
            x if x == ghost_core::CascadeDistributed::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::CascadeDistributed::decode_log(&log.inner, true)?;
                self.death_handler.handle_cascade_distributed(event, meta).await
            }
            x if x == ghost_core::EmissionsAdded::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::EmissionsAdded::decode_log(&log.inner, true)?;
                self.death_handler.handle_emissions_added(event, meta).await
            }
            x if x == ghost_core::BoostApplied::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::BoostApplied::decode_log(&log.inner, true)?;
                self.position_handler.handle_boost_applied(event, meta).await
            }
            x if x == ghost_core::SystemResetTriggered::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::SystemResetTriggered::decode_log(&log.inner, true)?;
                self.death_handler.handle_system_reset(event, meta).await
            }
            x if x == ghost_core::PositionCulled::SIGNATURE_HASH.as_slice() => {
                let event = ghost_core::PositionCulled::decode_log(&log.inner, true)?;
                self.position_handler.handle_position_culled(event, meta).await
            }

            // ═══════════════════════════════════════════════════════════════════
            // TRACE SCAN EVENTS
            // ═══════════════════════════════════════════════════════════════════
            x if x == trace_scan::ScanExecuted::SIGNATURE_HASH.as_slice() => {
                let event = trace_scan::ScanExecuted::decode_log(&log.inner, true)?;
                self.scan_handler.handle_scan_executed(event, meta).await
            }
            x if x == trace_scan::DeathsSubmitted::SIGNATURE_HASH.as_slice() => {
                let event = trace_scan::DeathsSubmitted::decode_log(&log.inner, true)?;
                self.scan_handler.handle_deaths_submitted(event, meta).await
            }
            x if x == trace_scan::ScanFinalized::SIGNATURE_HASH.as_slice() => {
                let event = trace_scan::ScanFinalized::decode_log(&log.inner, true)?;
                self.scan_handler.handle_scan_finalized(event, meta).await
            }

            // ═══════════════════════════════════════════════════════════════════
            // DEAD POOL EVENTS
            // ═══════════════════════════════════════════════════════════════════
            x if x == dead_pool::RoundCreated::SIGNATURE_HASH.as_slice() => {
                let event = dead_pool::RoundCreated::decode_log(&log.inner, true)?;
                self.market_handler.handle_round_created(event, meta).await
            }
            x if x == dead_pool::BetPlaced::SIGNATURE_HASH.as_slice() => {
                let event = dead_pool::BetPlaced::decode_log(&log.inner, true)?;
                self.market_handler.handle_bet_placed(event, meta).await
            }
            x if x == dead_pool::RoundResolved::SIGNATURE_HASH.as_slice() => {
                let event = dead_pool::RoundResolved::decode_log(&log.inner, true)?;
                self.market_handler.handle_round_resolved(event, meta).await
            }
            x if x == dead_pool::WinningsClaimed::SIGNATURE_HASH.as_slice() => {
                let event = dead_pool::WinningsClaimed::decode_log(&log.inner, true)?;
                self.market_handler.handle_winnings_claimed(event, meta).await
            }

            // ═══════════════════════════════════════════════════════════════════
            // DATA TOKEN EVENTS
            // ═══════════════════════════════════════════════════════════════════
            x if x == data_token::Transfer::SIGNATURE_HASH.as_slice() => {
                let event = data_token::Transfer::decode_log(&log.inner, true)?;
                self.token_handler.handle_transfer(event, meta).await
            }
            x if x == data_token::TaxBurned::SIGNATURE_HASH.as_slice() => {
                let event = data_token::TaxBurned::decode_log(&log.inner, true)?;
                self.token_handler.handle_tax_burned(event, meta).await
            }
            x if x == data_token::TaxCollected::SIGNATURE_HASH.as_slice() => {
                let event = data_token::TaxCollected::decode_log(&log.inner, true)?;
                self.token_handler.handle_tax_collected(event, meta).await
            }

            // ═══════════════════════════════════════════════════════════════════
            // FEE ROUTER EVENTS
            // ═══════════════════════════════════════════════════════════════════
            x if x == fee_router::TollCollected::SIGNATURE_HASH.as_slice() => {
                let event = fee_router::TollCollected::decode_log(&log.inner, true)?;
                self.fee_handler.handle_toll_collected(event, meta).await
            }
            x if x == fee_router::BuybackExecuted::SIGNATURE_HASH.as_slice() => {
                let event = fee_router::BuybackExecuted::decode_log(&log.inner, true)?;
                self.fee_handler.handle_buyback_executed(event, meta).await
            }

            // ═══════════════════════════════════════════════════════════════════
            // UNKNOWN EVENTS
            // ═══════════════════════════════════════════════════════════════════
            _ => {
                warn!(
                    topic0 = ?topic0,
                    contract = ?meta.contract,
                    "Unknown event signature"
                );
                Ok(())
            }
        }
    }
}
```

---

## 8. Database Schema

### 8.1 Initial Schema (migrations/20260120000001_initial_schema.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXER STATE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE indexer_state (
    id SERIAL PRIMARY KEY,
    chain_id BIGINT NOT NULL,
    last_block BIGINT NOT NULL DEFAULT 0,
    last_block_hash BYTEA,
    last_block_timestamp TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(chain_id)
);

-- For reorg detection - store recent block hashes
CREATE TABLE block_history (
    block_number BIGINT PRIMARY KEY,
    block_hash BYTEA NOT NULL,
    parent_hash BYTEA NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Automatically prune old blocks (keep last 128)
CREATE INDEX idx_block_history_number ON block_history(block_number DESC);
```

### 8.2 Positions Schema (migrations/20260120000002_positions.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- USER POSITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_address BYTEA NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
    
    -- Amounts (stored as NUMERIC for precision)
    amount NUMERIC(78, 0) NOT NULL,
    reward_debt NUMERIC(78, 0) NOT NULL DEFAULT 0,
    
    -- Timestamps
    entry_timestamp TIMESTAMPTZ NOT NULL,
    last_add_timestamp TIMESTAMPTZ,
    
    -- Status
    ghost_streak INTEGER NOT NULL DEFAULT 0,
    is_alive BOOLEAN NOT NULL DEFAULT TRUE,
    is_extracted BOOLEAN NOT NULL DEFAULT FALSE,
    extracted_at TIMESTAMPTZ,
    
    -- Extraction details (if extracted)
    extracted_amount NUMERIC(78, 0),
    extracted_rewards NUMERIC(78, 0),
    
    -- Block info
    created_at_block BIGINT NOT NULL,
    created_at_tx BYTEA NOT NULL,
    updated_at_block BIGINT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Only one active position per user
    CONSTRAINT unique_active_position 
        UNIQUE NULLS NOT DISTINCT (user_address) 
        WHERE is_alive = TRUE AND is_extracted = FALSE
);

CREATE INDEX idx_positions_user ON positions(user_address);
CREATE INDEX idx_positions_level_alive ON positions(level) WHERE is_alive = TRUE;
CREATE INDEX idx_positions_ghost_streak ON positions(ghost_streak DESC) WHERE is_alive = TRUE;

-- Position history (for analytics)
CREATE TABLE position_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    position_id UUID REFERENCES positions(id),
    action VARCHAR(20) NOT NULL, -- 'created', 'stake_added', 'extracted', 'died', 'culled'
    amount_change NUMERIC(78, 0),
    new_total NUMERIC(78, 0),
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_position_history_position ON position_history(position_id);
CREATE INDEX idx_position_history_time ON position_history(created_at DESC);

-- Active boosts
CREATE TABLE boosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_address BYTEA NOT NULL,
    boost_type SMALLINT NOT NULL,
    value_bps SMALLINT NOT NULL,
    expiry TIMESTAMPTZ NOT NULL,
    applied_at_block BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_boosts_user ON boosts(user_address);
CREATE INDEX idx_boosts_expiry ON boosts(expiry) WHERE expiry > NOW();
```

### 8.3 Scans Schema (migrations/20260120000003_scans.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- SCAN HISTORY
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
    
    -- Scan data
    seed NUMERIC(78, 0) NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL,
    finalized_at TIMESTAMPTZ,
    
    -- Results (populated on finalization)
    death_count INTEGER,
    total_dead NUMERIC(78, 0),
    
    -- Cascade distribution
    burned NUMERIC(78, 0),
    distributed_same_level NUMERIC(78, 0),
    distributed_upstream NUMERIC(78, 0),
    protocol_fee NUMERIC(78, 0),
    
    -- Survivor count
    survivor_count INTEGER,
    
    -- Block info
    executed_block BIGINT NOT NULL,
    executed_tx BYTEA NOT NULL,
    finalized_block BIGINT,
    finalized_tx BYTEA,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(level, scan_id)
);

CREATE INDEX idx_scans_level_time ON scans(level, executed_at DESC);
CREATE INDEX idx_scans_pending ON scans(level, executed_at) WHERE finalized_at IS NULL;

-- Individual death records
CREATE TABLE deaths (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id UUID REFERENCES scans(id),
    user_address BYTEA NOT NULL,
    position_id UUID REFERENCES positions(id),
    
    -- Loss details
    amount_lost NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL,
    ghost_streak_at_death INTEGER,
    
    -- Block info
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_deaths_user ON deaths(user_address);
CREATE INDEX idx_deaths_scan ON deaths(scan_id);
CREATE INDEX idx_deaths_time ON deaths(created_at DESC);
```

### 8.4 Markets Schema (migrations/20260120000004_markets.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- PREDICTION MARKET ROUNDS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id NUMERIC(78, 0) NOT NULL UNIQUE,
    round_type SMALLINT NOT NULL,
    target_level SMALLINT CHECK (target_level IS NULL OR target_level BETWEEN 1 AND 5),
    line NUMERIC(78, 0) NOT NULL,
    deadline TIMESTAMPTZ NOT NULL,
    
    -- Pool totals
    over_pool NUMERIC(78, 0) NOT NULL DEFAULT 0,
    under_pool NUMERIC(78, 0) NOT NULL DEFAULT 0,
    
    -- Resolution
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    outcome BOOLEAN, -- true = OVER won
    resolve_time TIMESTAMPTZ,
    total_burned NUMERIC(78, 0),
    
    -- Block info
    created_block BIGINT NOT NULL,
    created_tx BYTEA NOT NULL,
    resolved_block BIGINT,
    resolved_tx BYTEA,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rounds_active ON rounds(deadline) WHERE is_resolved = FALSE;
CREATE INDEX idx_rounds_type ON rounds(round_type, created_at DESC);

-- User bets
CREATE TABLE bets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID REFERENCES rounds(id),
    round_id_numeric NUMERIC(78, 0) NOT NULL,
    user_address BYTEA NOT NULL,
    
    -- Bet details
    amount NUMERIC(78, 0) NOT NULL,
    is_over BOOLEAN NOT NULL,
    
    -- Claim status
    is_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    winnings NUMERIC(78, 0),
    claimed_at TIMESTAMPTZ,
    
    -- Block info
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(round_id, user_address)
);

CREATE INDEX idx_bets_user ON bets(user_address, created_at DESC);
CREATE INDEX idx_bets_round ON bets(round_id);
CREATE INDEX idx_bets_unclaimed ON bets(round_id) WHERE is_claimed = FALSE;
```

### 8.5 Analytics Schema (migrations/20260120000005_analytics.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- TOKEN METRICS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Track significant transfers (for analytics, not every transfer)
CREATE TABLE token_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_address BYTEA NOT NULL,
    to_address BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    
    -- Tax info (if applicable)
    tax_burned NUMERIC(78, 0),
    tax_collected NUMERIC(78, 0),
    
    -- Block info
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    log_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial index - only index large transfers for quick queries
CREATE INDEX idx_transfers_large ON token_transfers(created_at DESC) 
    WHERE amount > 1000000000000000000000; -- > 1000 DATA

CREATE INDEX idx_transfers_from ON token_transfers(from_address, created_at DESC);
CREATE INDEX idx_transfers_to ON token_transfers(to_address, created_at DESC);

-- System resets
CREATE TABLE system_resets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    total_penalty NUMERIC(78, 0) NOT NULL,
    jackpot_winner BYTEA NOT NULL,
    jackpot_amount NUMERIC(78, 0) NOT NULL,
    
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fee router buybacks
CREATE TABLE buybacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eth_spent NUMERIC(78, 0) NOT NULL,
    data_received NUMERIC(78, 0) NOT NULL,
    data_burned NUMERIC(78, 0) NOT NULL,
    
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- AGGREGATED STATISTICS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Per-level statistics (updated by triggers or batch jobs)
CREATE TABLE level_stats (
    level SMALLINT PRIMARY KEY CHECK (level BETWEEN 1 AND 5),
    total_staked NUMERIC(78, 0) NOT NULL DEFAULT 0,
    alive_count INTEGER NOT NULL DEFAULT 0,
    total_deaths INTEGER NOT NULL DEFAULT 0,
    total_extracted INTEGER NOT NULL DEFAULT 0,
    total_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_distributed NUMERIC(78, 0) NOT NULL DEFAULT 0,
    highest_ghost_streak INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Initialize level stats
INSERT INTO level_stats (level) VALUES (1), (2), (3), (4), (5);

-- Global statistics
CREATE TABLE global_stats (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Singleton
    total_value_locked NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_positions INTEGER NOT NULL DEFAULT 0,
    total_deaths INTEGER NOT NULL DEFAULT 0,
    total_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_emissions_distributed NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_toll_collected NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_buyback_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    system_reset_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO global_stats DEFAULT VALUES;

-- Leaderboard cache (refreshed periodically)
CREATE TABLE leaderboard_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    leaderboard_type VARCHAR(50) NOT NULL,
    user_address BYTEA NOT NULL,
    score NUMERIC(78, 0) NOT NULL,
    rank INTEGER NOT NULL,
    metadata JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(leaderboard_type, user_address)
);

CREATE INDEX idx_leaderboard_rank ON leaderboard_cache(leaderboard_type, rank);
```

### 8.6 Indexes (migrations/20260120000006_indexes.sql)

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- ADDITIONAL INDEXES FOR COMMON QUERIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Position queries by level and amount (for culling risk display)
CREATE INDEX idx_positions_level_amount ON positions(level, amount ASC) 
    WHERE is_alive = TRUE;

-- Recent activity by user
CREATE INDEX idx_position_history_user_time ON position_history(
    (SELECT user_address FROM positions WHERE id = position_id), 
    created_at DESC
);

-- Scan queries for next scan time
CREATE INDEX idx_scans_next ON scans(level, executed_at DESC) 
    WHERE finalized_at IS NOT NULL;

-- Active bets for user
CREATE INDEX idx_bets_user_active ON bets(user_address) 
    WHERE is_claimed = FALSE;

-- Pending rounds (for resolution)
CREATE INDEX idx_rounds_pending ON rounds(deadline) 
    WHERE is_resolved = FALSE AND deadline < NOW();
```

---

## 9. Processing Architecture

### 9.1 System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           GHOSTNET Event Indexer                                │
└─────────────────────────────────────────────────────────────────────────────────┘

                                 ┌─────────────┐
                                 │   Ethereum  │
                                 │     RPC     │
                                 │  (MegaETH)  │
                                 └──────┬──────┘
                                        │
                                        │ eth_getLogs / eth_subscribe
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              BLOCK PROCESSOR                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Fetcher   │───▶│   Filter    │───▶│   Decoder   │───▶│   Router    │    │
│  │             │    │ (contracts) │    │  (alloy)    │    │  (events)   │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘    │
│                                                                   │           │
│         ┌─────────────────────────────────────────────────────────┤           │
│         │                                                         │           │
│         ▼                                                         ▼           │
│  ┌─────────────┐                                           ┌─────────────┐    │
│  │   Reorg     │                                           │ Checkpoint  │    │
│  │  Handler    │                                           │   Manager   │    │
│  └─────────────┘                                           └─────────────┘    │
└───────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ Typed Events
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              EVENT HANDLERS                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Position   │  │    Scan     │  │   Death     │  │   Market    │          │
│  │  Handler    │  │   Handler   │  │  Handler    │  │  Handler    │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                │                  │
│         └────────────────┴────────────────┴────────────────┘                  │
│                                   │                                           │
└───────────────────────────────────┼───────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                           STORE TRAIT                                    │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│         │                              │                              │        │
│         ▼                              ▼                              ▼        │
│  ┌─────────────┐               ┌─────────────┐               ┌─────────────┐  │
│  │ PostgreSQL  │               │    Redis    │               │  WebSocket  │  │
│  │   (sqlx)    │               │   (cache)   │               │  Broadcast  │  │
│  └─────────────┘               └─────────────┘               └─────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              API LAYER                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    REST     │  │  WebSocket  │  │   Metrics   │  │   Health    │          │
│  │   (Axum)    │  │   (Axum)    │  │ (Prometheus)│  │   Checks    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘          │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Block Processing Loop

```rust
// Pseudocode for main processing loop
async fn run_indexer(config: Config, store: Store) -> Result<()> {
    let provider = create_provider(&config.rpc_url).await?;
    let mut last_block = store.get_last_indexed_block().await?;
    
    loop {
        // Get current chain head
        let head = provider.get_block_number().await?;
        
        // Process blocks in batches
        while last_block < head {
            let to_block = std::cmp::min(last_block + BATCH_SIZE, head);
            
            // Fetch logs for all contracts
            let logs = provider
                .get_logs(&Filter::new()
                    .address(config.contract_addresses.clone())
                    .from_block(last_block + 1)
                    .to_block(to_block))
                .await?;
            
            // Check for reorgs
            if let Some(reorg_block) = detect_reorg(&provider, &store).await? {
                handle_reorg(&store, reorg_block).await?;
                last_block = reorg_block - 1;
                continue;
            }
            
            // Process each log
            for log in logs {
                let meta = extract_metadata(&log, &provider).await?;
                router.route_log(&log, meta).await?;
            }
            
            // Update checkpoint
            store.set_last_indexed_block(to_block).await?;
            last_block = to_block;
            
            metrics::BLOCKS_PROCESSED.inc_by((to_block - last_block) as u64);
        }
        
        // Wait for new blocks
        tokio::time::sleep(Duration::from_millis(config.poll_interval_ms)).await;
    }
}
```

---

## 10. API Specification

### 10.1 REST Endpoints

#### Positions

```yaml
# Get all active positions
GET /api/v1/positions
Query:
  - level: int (optional, 1-5)
  - limit: int (default 100, max 1000)
  - offset: int (default 0)
Response: { positions: Position[], total: int }

# Get position by user address
GET /api/v1/positions/:address
Response: Position | null

# Get position history
GET /api/v1/positions/:address/history
Query:
  - limit: int (default 50)
Response: PositionHistory[]

# Get positions at risk of culling
GET /api/v1/positions/at-risk
Query:
  - level: int (required)
  - threshold: int (bottom N positions)
Response: Position[]
```

#### Scans

```yaml
# Get recent scans
GET /api/v1/scans
Query:
  - level: int (optional)
  - limit: int (default 20)
Response: Scan[]

# Get scan by ID
GET /api/v1/scans/:level/:scanId
Response: Scan

# Get next scan time for level
GET /api/v1/scans/:level/next
Response: { level: int, next_scan_at: timestamp, seconds_remaining: int }

# Get deaths for a scan
GET /api/v1/scans/:level/:scanId/deaths
Response: Death[]
```

#### Deaths

```yaml
# Get recent deaths
GET /api/v1/deaths
Query:
  - level: int (optional)
  - limit: int (default 50)
Response: Death[]

# Get user's death history
GET /api/v1/deaths/:address
Response: Death[]
```

#### Markets (DeadPool)

```yaml
# Get active rounds
GET /api/v1/rounds
Query:
  - type: string (optional: death_count, whale_death, streak_record, system_reset)
  - active_only: bool (default true)
Response: Round[]

# Get round details
GET /api/v1/rounds/:roundId
Response: Round

# Get bets for a round
GET /api/v1/rounds/:roundId/bets
Response: Bet[]

# Get user's bets
GET /api/v1/bets/:address
Query:
  - unclaimed_only: bool (default false)
Response: Bet[]

# Get odds for a round
GET /api/v1/rounds/:roundId/odds
Response: { over_odds: float, under_odds: float, over_pool: string, under_pool: string }
```

#### Analytics

```yaml
# Get global statistics
GET /api/v1/stats
Response: GlobalStats

# Get per-level statistics
GET /api/v1/stats/levels
Response: LevelStats[]

# Get TVL history
GET /api/v1/stats/tvl/history
Query:
  - interval: string (hour, day, week)
  - from: timestamp
  - to: timestamp
Response: { timestamp: timestamp, tvl: string }[]

# Get burn statistics
GET /api/v1/stats/burns
Response: { total_burned: string, tax_burned: string, death_burned: string, buyback_burned: string }
```

#### Leaderboards

```yaml
# Get ghost streak leaderboard
GET /api/v1/leaderboard/streak
Query:
  - limit: int (default 100)
Response: { rank: int, address: string, streak: int, level: int }[]

# Get top earners
GET /api/v1/leaderboard/earnings
Query:
  - limit: int (default 100)
  - period: string (all, month, week)
Response: { rank: int, address: string, earnings: string }[]

# Get survivors (longest alive)
GET /api/v1/leaderboard/survivors
Query:
  - limit: int (default 100)
Response: { rank: int, address: string, alive_since: timestamp, level: int }[]
```

### 10.2 WebSocket API

```yaml
# Connect to WebSocket
WS /api/v1/ws

# Subscribe to events
>>> { "type": "subscribe", "channels": ["positions", "scans", "deaths", "markets"] }
<<< { "type": "subscribed", "channels": ["positions", "scans", "deaths", "markets"] }

# Unsubscribe
>>> { "type": "unsubscribe", "channels": ["deaths"] }
<<< { "type": "unsubscribed", "channels": ["deaths"] }

# Subscribe to specific user
>>> { "type": "subscribe", "user": "0x..." }
<<< { "type": "subscribed", "user": "0x..." }

# Event messages
<<< { "type": "event", "channel": "positions", "event": "jacked_in", "data": {...} }
<<< { "type": "event", "channel": "scans", "event": "scan_executed", "data": {...} }
<<< { "type": "event", "channel": "deaths", "event": "death_processed", "data": {...} }
<<< { "type": "event", "channel": "markets", "event": "bet_placed", "data": {...} }
```

---

## 11. Deployment

### 11.1 Environment Variables

```bash
# config/.env.example

# ═══════════════════════════════════════════════════════════════════════════════
# ETHEREUM
# ═══════════════════════════════════════════════════════════════════════════════
RPC_URL=https://rpc.megaeth.io
CHAIN_ID=6342
START_BLOCK=0

# Contract addresses (set after deployment)
DATA_TOKEN_ADDRESS=0x...
GHOST_CORE_ADDRESS=0x...
TRACE_SCAN_ADDRESS=0x...
DEAD_POOL_ADDRESS=0x...
FEE_ROUTER_ADDRESS=0x...
REWARDS_DISTRIBUTOR_ADDRESS=0x...

# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE
# ═══════════════════════════════════════════════════════════════════════════════
DATABASE_URL=postgres://ghostnet:password@localhost:5432/ghostnet_indexer
DATABASE_MAX_CONNECTIONS=20

# ═══════════════════════════════════════════════════════════════════════════════
# REDIS
# ═══════════════════════════════════════════════════════════════════════════════
REDIS_URL=redis://localhost:6379
REDIS_PREFIX=ghostnet:

# ═══════════════════════════════════════════════════════════════════════════════
# API
# ═══════════════════════════════════════════════════════════════════════════════
API_HOST=0.0.0.0
API_PORT=8080
CORS_ORIGINS=http://localhost:3000,https://ghostnet.gg

# ═══════════════════════════════════════════════════════════════════════════════
# OBSERVABILITY
# ═══════════════════════════════════════════════════════════════════════════════
LOG_LEVEL=info
LOG_FORMAT=json
METRICS_PORT=9090

# ═══════════════════════════════════════════════════════════════════════════════
# INDEXER
# ═══════════════════════════════════════════════════════════════════════════════
POLL_INTERVAL_MS=1000
BATCH_SIZE=100
REORG_DEPTH=64
```

### 11.2 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  indexer:
    build: .
    environment:
      - DATABASE_URL=postgres://ghostnet:password@postgres:5432/ghostnet_indexer
      - REDIS_URL=redis://redis:6379
      - RPC_URL=${RPC_URL}
    ports:
      - "8080:8080"
      - "9090:9090"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: ghostnet
      POSTGRES_PASSWORD: password
      POSTGRES_DB: ghostnet_indexer
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

volumes:
  postgres_data:
  redis_data:
```

### 11.3 Dockerfile

```dockerfile
# Dockerfile
FROM rust:1.75 as builder

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/ghostnet-indexer /usr/local/bin/
COPY --from=builder /app/migrations /app/migrations

ENV RUST_LOG=info

ENTRYPOINT ["ghostnet-indexer"]
CMD ["run"]
```

---

## 12. Implementation Checklist

### Phase 1: Foundation
- [ ] Initialize Rust project with dependencies
- [ ] Set up configuration management
- [ ] Create type definitions (enums, events, entities)
- [ ] Generate ABI bindings with alloy-sol-types
- [ ] Implement database migrations
- [ ] Set up logging and metrics

### Phase 2: Indexer Core
- [ ] Implement block processor
- [ ] Implement log decoder
- [ ] Implement event router
- [ ] Implement reorg handler
- [ ] Implement checkpoint manager
- [ ] Add integration tests for indexing

### Phase 3: Event Handlers
- [ ] Position handler (JackedIn, StakeAdded, Extracted, PositionCulled)
- [ ] Scan handler (ScanExecuted, DeathsSubmitted, ScanFinalized)
- [ ] Death handler (DeathsProcessed, CascadeDistributed, SystemResetTriggered)
- [ ] Market handler (RoundCreated, BetPlaced, RoundResolved, WinningsClaimed)
- [ ] Token handler (Transfer, TaxBurned, TaxCollected)
- [ ] Fee handler (TollCollected, BuybackExecuted)

### Phase 4: Data Layer
- [ ] PostgreSQL store implementation
- [ ] Redis cache layer
- [ ] WebSocket broadcast channel
- [ ] Leaderboard computation

### Phase 5: API
- [ ] REST API routes
- [ ] WebSocket handler
- [ ] Authentication middleware (if needed)
- [ ] Rate limiting
- [ ] API documentation (OpenAPI)

### Phase 6: Operations
- [ ] Docker containerization
- [ ] Health checks
- [ ] Prometheus metrics
- [ ] Alerting rules
- [ ] Deployment scripts

---

## Appendix: Event Signature Hashes

For quick reference, these are the keccak256 hashes of event signatures:

```
JackedIn(address,uint256,uint8,uint256)         = 0x...
StakeAdded(address,uint256,uint256)             = 0x...
Extracted(address,uint256,uint256)              = 0x...
DeathsProcessed(uint8,uint256,uint256,uint256,uint256) = 0x...
SurvivorsUpdated(uint8,uint256)                 = 0x...
CascadeDistributed(uint8,uint256,uint256,uint256,uint256) = 0x...
EmissionsAdded(uint8,uint256)                   = 0x...
BoostApplied(address,uint8,uint16,uint64)       = 0x...
SystemResetTriggered(uint256,address,uint256)   = 0x...
PositionCulled(address,uint256,uint256,address) = 0x...
ScanExecuted(uint8,uint256,uint256,uint64)      = 0x...
DeathsSubmitted(uint8,uint256,uint256,uint256,address) = 0x...
ScanFinalized(uint8,uint256,uint256,uint256,uint64) = 0x...
RoundCreated(uint256,uint8,uint8,uint256,uint64) = 0x...
BetPlaced(uint256,address,bool,uint256)         = 0x...
RoundResolved(uint256,bool,uint256,uint256)     = 0x...
WinningsClaimed(uint256,address,uint256)        = 0x...
Transfer(address,address,uint256)               = 0xddf252ad...
TaxBurned(address,uint256)                      = 0x...
TaxCollected(address,uint256)                   = 0x...
TollCollected(address,uint256,bytes32)          = 0x...
BuybackExecuted(uint256,uint256,uint256)        = 0x...
EmissionsDistributed(uint256,uint256)           = 0x...
```

*Note: Actual hashes will be computed at compile time by alloy-sol-types*

---

## References

- [Alloy Documentation](https://alloy.rs)
- [Axum Framework](https://github.com/tokio-rs/axum)
- [SQLx](https://github.com/launchbadge/sqlx)
- [GHOSTNET Smart Contracts](../packages/contracts/)
