# GHOSTNET Event Indexer Architecture

> **Version**: 2.2.0  
> **Last Updated**: 2026-01-20  
> **Status**: Specification (Review Complete)  
> **Supersedes**: `event-indexer-rust.md`, `backend-architecture-old.md`  
> **Review**: See `docs/lessons/indexer-architecture-review.md` for review notes

This document provides the complete architecture specification for the GHOSTNET Event Indexer - a high-performance Rust-based backend service that indexes blockchain events, persists them to TimescaleDB, streams them via Apache Iggy, and exposes REST/WebSocket APIs.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture](#3-system-architecture)
4. [Contract Event Catalog](#4-contract-event-catalog)
5. [Project Structure](#5-project-structure)
6. [Dependencies](#6-dependencies)
7. [Type Definitions](#7-type-definitions)
   - 7.1 [Enums](#71-enums-srctypesenumsrs)
   - 7.2 [Event Structs](#72-event-structs-srctypeseventsrs)
   - 7.3 [Ports - Trait Definitions](#73-ports---trait-definitions-srcportsrs)
   - 7.4 [Error Types](#74-error-types-srcerrorrs)
   - 7.5 [Primitive Newtypes](#75-primitive-newtypes-srctypesprimitivesrs)
   - 7.6 [Entity Types](#76-entity-types-srctypesentitiesrs)
8. [ABI Bindings](#8-abi-bindings)
9. [Event Router](#9-event-router)
   - 9.1 [Handler Traits](#91-handler-traits-srchandlerstraitsrs)
   - 9.2 [Router Implementation](#92-router-implementation-srcindexerevent_routerrs)
10. [TimescaleDB Schema](#10-timescaledb-schema)
11. [Compression & Columnstore](#11-compression--columnstore)
12. [Continuous Aggregates](#12-continuous-aggregates)
13. [Data Retention Policies](#13-data-retention-policies)
14. [Reorg Handling](#14-reorg-handling)
15. [Apache Iggy Integration](#15-apache-iggy-integration)
16. [In-Memory Caching](#16-in-memory-caching)
17. [Processing Architecture](#17-processing-architecture)
18. [API Specification](#18-api-specification)
19. [WebSocket Protocol](#19-websocket-protocol)
20. [Deployment](#20-deployment)
21. [Monitoring & Observability](#21-monitoring--observability)
22. [Security](#22-security)
23. [Testing Strategy](#23-testing-strategy)
24. [Configuration Validation](#24-configuration-validation)
25. [Implementation Checklist](#25-implementation-checklist)

---

## 1. Overview

### 1.1 Purpose

The GHOSTNET Event Indexer serves as the backbone for the entire GHOSTNET ecosystem:

| Function | Description |
|----------|-------------|
| **Event Indexing** | Listen to all GHOSTNET smart contract events from MegaETH |
| **Data Persistence** | Store events in TimescaleDB with time-series optimizations |
| **Real-time Streaming** | Broadcast events via Apache Iggy for instant client updates |
| **API Layer** | RESTful endpoints for positions, scans, markets, analytics |
| **WebSocket Gateway** | Real-time event streaming to connected clients |
| **Analytics Engine** | Pre-computed aggregates for dashboards and leaderboards |

### 1.2 Design Principles

1. **Performance First**: Sub-500ms block-to-client latency
2. **Reliability**: Handle chain reorgs gracefully, never lose data
3. **Scalability**: Horizontal scaling via Iggy consumer groups
4. **Simplicity**: Single binary, minimal external dependencies
5. **Observability**: Comprehensive metrics, structured logging

### 1.3 Key Requirements

| Requirement | Target | Rationale |
|-------------|--------|-----------|
| Block processing latency | < 500ms from confirmation | Real-time feed responsiveness |
| API response time (p99) | < 100ms | Snappy UI experience |
| Reorg handling depth | 64 blocks | MegaETH finality guarantees |
| Data retention | Indefinite for aggregates | Historical analytics |
| Availability | 99.9% uptime | Critical infrastructure |

### 1.4 Non-Goals

- **Not a full node**: We rely on RPC providers, not self-hosted nodes
- **Not a general-purpose indexer**: Optimized specifically for GHOSTNET contracts
- **Not a wallet service**: No private key management

---

## 2. Technology Stack

### 2.1 Core Technologies

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| **Language** | Rust | 1.85+ (Edition 2024) | Memory safety, performance, ecosystem |
| **Runtime** | Tokio | 1.x | Industry-standard async runtime |
| **Database** | TimescaleDB | 2.22+ | Time-series optimization, compression |
| **Streaming** | Apache Iggy | 0.6+ | Rust-native, high-throughput messaging |
| **API Framework** | Axum | 0.7+ | Type-safe, tower ecosystem |
| **Ethereum Client** | Alloy | 0.9+ | Modern, type-safe, tree-shakeable |
| **Caching** | moka + dashmap | Latest | In-memory LRU cache, concurrent maps |

### 2.2 Why These Choices?

#### Rust over Node.js/Go

- **No garbage collection**: Predictable latency (critical for real-time feeds)
- **Memory safety**: Eliminates entire classes of bugs
- **Ecosystem**: Alloy (Ethereum), Iggy (streaming) are Rust-native
- **Performance**: 10-100x faster than interpreted languages for CPU-bound work

#### TimescaleDB over PostgreSQL

- **Hypertables**: Automatic partitioning by time, 10-100x faster range queries
- **Compression**: 90%+ storage reduction with columnar compression
- **Continuous Aggregates**: Pre-computed analytics, incrementally updated
- **Retention Policies**: Automatic data lifecycle management
- **Still PostgreSQL**: Full SQL compatibility, existing tooling works

#### Apache Iggy over Redis/Kafka

- **Rust-native**: Single binary, no JVM/ZooKeeper dependencies
- **Performance**: Millions of messages/second, sub-ms latency
- **Persistence**: Append-only log with configurable retention
- **Consumer Groups**: Built-in load balancing for horizontal scaling
- **WebSocket Support**: Direct browser connectivity for live feeds

#### In-Memory Caching over Redis

- **Simplicity**: No external service to manage
- **Latency**: Zero network hop for cache access
- **Sufficient**: Hot data fits in memory (positions, leaderboards)
- **Rate Limiting**: Tower middleware + in-memory counters

### 2.3 Technology Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GHOSTNET INDEXER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                              ┌─────────────────┐                            │
│                              │    MegaETH      │                            │
│                              │    RPC Node     │                            │
│                              └────────┬────────┘                            │
│                                       │                                      │
│                                       │ eth_getLogs / eth_subscribe         │
│                                       ▼                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         INDEXER CORE (Rust)                             │ │
│  │                                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │    Block     │  │     Log      │  │    Event     │  │   Reorg     │ │ │
│  │  │  Processor   │─▶│   Decoder    │─▶│   Router     │─▶│  Handler    │ │ │
│  │  │   (Alloy)    │  │(alloy-sol)   │  │              │  │             │ │ │
│  │  └──────────────┘  └──────────────┘  └──────┬───────┘  └─────────────┘ │ │
│  │                                              │                          │ │
│  │         ┌────────────────────────────────────┼────────────────────┐    │ │
│  │         │                                    │                    │    │ │
│  │         ▼                                    ▼                    ▼    │ │
│  │  ┌──────────────┐                   ┌──────────────┐      ┌──────────┐ │ │
│  │  │   Position   │                   │    Scan      │      │  Market  │ │ │
│  │  │   Handler    │                   │   Handler    │      │ Handler  │ │ │
│  │  └──────────────┘                   └──────────────┘      └──────────┘ │ │
│  │                                                                          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                      │
│              ┌────────────────────────┼────────────────────────┐            │
│              │                        │                        │            │
│              ▼                        ▼                        ▼            │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │     TimescaleDB     │  │    Apache Iggy      │  │    In-Memory        │ │
│  │     (PostgreSQL)    │  │    (Streaming)      │  │    (Caching)        │ │
│  │                     │  │                     │  │                     │ │
│  │  • Hypertables      │  │  • ghostnet stream  │  │  • moka LRU cache   │ │
│  │  • Compression      │  │  • positions topic  │  │  • dashmap maps     │ │
│  │  • Cont. Aggregates │  │  • scans topic      │  │  • Rate limiters    │ │
│  │  • Retention        │  │  • deaths topic     │  │                     │ │
│  │                     │  │  • markets topic    │  │                     │ │
│  │  Port: 5432         │  │  • feed topic       │  │                     │ │
│  │                     │  │                     │  │                     │ │
│  │                     │  │  Port: 8090 (TCP)   │  │                     │ │
│  └─────────────────────┘  └──────────┬──────────┘  └─────────────────────┘ │
│                                      │                                      │
│                                      │ Subscribe                            │
│                                      ▼                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                           API LAYER (Axum)                              │ │
│  │                                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │     REST     │  │  WebSocket   │  │   Metrics    │  │   Health    │ │ │
│  │  │   /api/v1/*  │  │   /ws        │  │  /metrics    │  │  /health    │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘ │ │
│  │                                                                          │ │
│  │  Port: 8080                                                              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                      │
│                                       ▼                                      │
│                              ┌─────────────────┐                            │
│                              │     Clients     │                            │
│                              │   (SvelteKit)   │                            │
│                              └─────────────────┘                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. System Architecture

### 3.1 Component Overview

The indexer consists of five major subsystems:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SUBSYSTEM ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 1. INDEXER CORE                                                       │   │
│  │    Responsibility: Fetch blocks, decode logs, route events           │   │
│  │    Components: BlockProcessor, LogDecoder, EventRouter, ReorgHandler │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                       │                                      │
│                                       ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 2. EVENT HANDLERS                                                     │   │
│  │    Responsibility: Process typed events, update state                │   │
│  │    Components: PositionHandler, ScanHandler, DeathHandler,           │   │
│  │                MarketHandler, TokenHandler, FeeHandler               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                       │                                      │
│                                       ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 3. DATA LAYER                                                         │   │
│  │    Responsibility: Persist data, cache hot paths, stream events      │   │
│  │    Components: PostgresStore, IggyPublisher, MemoryCache             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                       │                                      │
│                                       ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 4. API LAYER                                                          │   │
│  │    Responsibility: Serve REST API, WebSocket connections             │   │
│  │    Components: AxumServer, RestRoutes, WebSocketHandler, Middleware  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                       │                                      │
│                                       ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 5. INFRASTRUCTURE                                                     │   │
│  │    Responsibility: Configuration, logging, metrics, health           │   │
│  │    Components: Config, Logging, Metrics, HealthCheck                 │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. INGEST                                                                   │
│     MegaETH RPC ──▶ Block Processor ──▶ Filter by contract addresses        │
│                                                                              │
│  2. DECODE                                                                   │
│     Raw Logs ──▶ Log Decoder ──▶ Typed Events (JackedIn, Extracted, etc.)  │
│                                                                              │
│  3. ROUTE                                                                    │
│     Typed Events ──▶ Event Router ──▶ Appropriate Handler                   │
│                                                                              │
│  4. PROCESS                                                                  │
│     Handler ──▶ Update database ──▶ Publish to Iggy ──▶ Update cache       │
│                                                                              │
│  5. SERVE                                                                    │
│     REST API  ◀── Database queries                                          │
│     WebSocket ◀── Iggy subscription                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Latency Budget

Every millisecond counts for real-time feeds. Our target is < 500ms block-to-client:

| Stage | Target | Accumulated |
|-------|--------|-------------|
| Block confirmation → RPC delivers | < 100ms | 100ms |
| RPC → Indexer receives logs | < 50ms | 150ms |
| Log decoding + routing | < 10ms | 160ms |
| Handler processing | < 20ms | 180ms |
| Database write (async) | < 50ms | 230ms |
| Iggy publish | < 10ms | 240ms |
| Iggy → WebSocket handler | < 10ms | 250ms |
| WebSocket → Client receives | < 50ms | **300ms** |
| **Buffer** | 200ms | **500ms** |

### 3.4 Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| RPC unavailable | Health check fails | Exponential backoff, switch provider |
| TimescaleDB down | Connection pool errors | Queue writes in memory, retry |
| Iggy unavailable | Publish fails | Queue messages, retry with backoff |
| Chain reorg | Parent hash mismatch | Rollback to fork point, reindex |
| OOM | Memory limits exceeded | Graceful shutdown, alert |

---

## 4. Contract Event Catalog

### 4.1 Contract Addresses

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

### 4.2 GhostCore Events

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

### 4.3 TraceScan Events

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

### 4.4 DeadPool Events

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

### 4.5 DataToken Events

The ERC20 token emits standard and custom events.

```solidity
/// @notice Standard ERC20 transfer
event Transfer(
    address indexed from,      // Sender (0x0 for mints)
    address indexed to,        // Recipient (DEAD_ADDRESS for burns)
    uint256 value              // Amount transferred
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

/// @notice Emitted when tax exclusion status changes
event TaxExclusionSet(
    address indexed account,   // Affected address
    bool excluded              // New exclusion status
);
```

### 4.6 FeeRouter Events

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
```

### 4.7 RewardsDistributor Events

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
```

### 4.8 TeamVesting Events

```solidity
/// @notice Emitted when a team member claims vested tokens
event TokensClaimed(
    address indexed beneficiary, // Team member's address
    uint256 amount               // Amount claimed
);
```

### 4.9 Enum Definitions

```solidity
/// @notice Risk levels (stored as uint8)
enum Level {
    NONE,       // 0 - Invalid/No position
    VAULT,      // 1 - Safest (0% death rate)
    MAINFRAME,  // 2 - Conservative (2% death rate)
    SUBNET,     // 3 - Balanced (15% death rate)
    DARKNET,    // 4 - High risk (40% death rate)
    BLACK_ICE   // 5 - Maximum risk (90% death rate)
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

## 5. Project Structure

```
services/ghostnet-indexer/
├── Cargo.toml                     # Project manifest
├── Cargo.lock                     # Dependency lock file
├── rust-toolchain.toml            # Rust 1.85 + components
├── rustfmt.toml                   # Formatter config
├── deny.toml                      # Dependency policy
├── .env.example                   # Environment template
│
├── .cargo/
│   └── config.toml                # Build config (fast linker)
│
├── config/
│   ├── default.toml               # Default configuration
│   ├── development.toml           # Dev overrides
│   └── production.toml            # Prod overrides
│
├── migrations/
│   ├── 00001_enable_timescaledb.sql
│   ├── 00002_indexer_state.sql
│   ├── 00003_positions.sql
│   ├── 00004_scans.sql
│   ├── 00005_markets.sql
│   ├── 00006_analytics.sql
│   ├── 00007_continuous_aggregates.sql
│   └── 00008_retention_policies.sql
│
├── src/
│   ├── main.rs                    # Entry point & CLI
│   ├── lib.rs                     # Library root
│   │
│   ├── config/                    # Configuration module
│   │   ├── mod.rs
│   │   ├── settings.rs            # Config loading
│   │   └── contracts.rs           # Contract addresses
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
│   │   └── fee_handler.rs         # FeeRouter events
│   │
│   ├── store/                     # Data persistence
│   │   ├── mod.rs
│   │   ├── traits.rs              # Store trait definitions
│   │   ├── postgres.rs            # TimescaleDB implementation
│   │   ├── cache.rs               # In-memory cache (moka)
│   │   └── models/                # Database models
│   │       ├── mod.rs
│   │       ├── positions.rs
│   │       ├── scans.rs
│   │       ├── deaths.rs
│   │       ├── markets.rs
│   │       ├── transfers.rs
│   │       └── analytics.rs
│   │
│   ├── streaming/                 # Message streaming
│   │   ├── mod.rs
│   │   ├── iggy.rs                # Iggy client wrapper
│   │   ├── publisher.rs           # Event publishing
│   │   └── topics.rs              # Topic definitions
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
│   │   └── middleware.rs          # Auth, CORS, rate limiting
│   │
│   └── utils/
│       ├── mod.rs
│       ├── metrics.rs             # Prometheus metrics
│       ├── logging.rs             # Structured logging
│       └── health.rs              # Health checks
│
├── tests/                         # Integration tests
│   ├── common/
│   │   └── mod.rs
│   ├── indexer_tests.rs
│   ├── handler_tests.rs
│   └── api_tests.rs
│
├── Dockerfile                     # Container build
└── docker-compose.yml             # Local development stack
```

---

## 6. Dependencies

### 6.1 Cargo.toml

```toml
[package]
name = "ghostnet-indexer"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"
authors = ["GHOSTNET Team"]
description = "Event indexer for the GHOSTNET protocol"
license = "MIT"
repository = "https://github.com/ghostnet/indexer"

# ═══════════════════════════════════════════════════════════════════════════════
# LINTS
# ═══════════════════════════════════════════════════════════════════════════════

[lints.rust]
unsafe_code = "forbid"
missing_debug_implementations = "warn"
missing_docs = "warn"

[lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
# Allow some pedantic lints that are too noisy
module_name_repetitions = "allow"
must_use_candidate = "allow"

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

[dependencies]
# ───────────────────────────────────────────────────────────────────────────────
# ETHEREUM
# ───────────────────────────────────────────────────────────────────────────────
alloy = { version = "0.9", features = [
    "full",
    "provider-http",
    "provider-ws",
    "rpc-types-eth",
] }
alloy-sol-types = "0.9"
alloy-primitives = "0.9"

# ───────────────────────────────────────────────────────────────────────────────
# ASYNC RUNTIME
# ───────────────────────────────────────────────────────────────────────────────
tokio = { version = "1", features = ["full", "tracing"] }
futures = "0.3"
async-trait = "0.1"

# ───────────────────────────────────────────────────────────────────────────────
# DATABASE (TimescaleDB)
# ───────────────────────────────────────────────────────────────────────────────
sqlx = { version = "0.8", features = [
    "runtime-tokio",
    "postgres",
    "chrono",
    "uuid",
    "bigdecimal",
    "migrate",
] }

# ───────────────────────────────────────────────────────────────────────────────
# MESSAGE STREAMING (Apache Iggy)
# ───────────────────────────────────────────────────────────────────────────────
iggy = "0.6"

# ───────────────────────────────────────────────────────────────────────────────
# IN-MEMORY CACHING
# ───────────────────────────────────────────────────────────────────────────────
moka = { version = "0.12", features = ["future"] }
dashmap = "6"

# ───────────────────────────────────────────────────────────────────────────────
# WEB FRAMEWORK
# ───────────────────────────────────────────────────────────────────────────────
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

# ───────────────────────────────────────────────────────────────────────────────
# SERIALIZATION
# ───────────────────────────────────────────────────────────────────────────────
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_with = "3"

# ───────────────────────────────────────────────────────────────────────────────
# CONFIGURATION & CLI
# ───────────────────────────────────────────────────────────────────────────────
clap = { version = "4", features = ["derive", "env"] }
config = { version = "0.14", features = ["toml"] }
dotenvy = "0.15"

# ───────────────────────────────────────────────────────────────────────────────
# OBSERVABILITY
# ───────────────────────────────────────────────────────────────────────────────
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = [
    "env-filter",
    "json",
    "fmt",
] }
tracing-appender = "0.2"
metrics = "0.24"
metrics-exporter-prometheus = "0.16"

# ───────────────────────────────────────────────────────────────────────────────
# UTILITIES
# ───────────────────────────────────────────────────────────────────────────────
thiserror = "2"
anyhow = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "v7", "serde"] }
bigdecimal = { version = "0.4", features = ["serde"] }
hex = "0.4"
parking_lot = "0.12"

# ═══════════════════════════════════════════════════════════════════════════════
# DEV DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

[dev-dependencies]
tokio-test = "0.4"
wiremock = "0.6"
testcontainers = "0.23"
testcontainers-modules = { version = "0.11", features = ["postgres"] }
criterion = { version = "0.5", features = ["async_tokio"] }
proptest = "1"

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD PROFILE
# ═══════════════════════════════════════════════════════════════════════════════

[profile.release]
lto = "thin"
codegen-units = 1
strip = "symbols"
panic = "abort"

# Optimize dependencies in dev builds for faster runtime performance
[profile.dev.package."*"]
opt-level = 2

[[bin]]
name = "ghostnet-indexer"
path = "src/main.rs"
```

### 6.2 Supporting Configuration Files

#### rust-toolchain.toml

```toml
[toolchain]
channel = "1.85"
components = ["rust-src", "rust-analyzer", "clippy", "rustfmt", "llvm-tools-preview"]
```

#### rustfmt.toml

```toml
edition = "2024"
unstable_features = true
group_imports = "StdExternalCrate"
imports_granularity = "Item"
max_width = 100
```

#### deny.toml

```toml
[advisories]
vulnerability = "deny"
unmaintained = "warn"
yanked = "deny"

[licenses]
unlicensed = "deny"
allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "MPL-2.0"]

[bans]
multiple-versions = "warn"
wildcards = "deny"
deny = [{ name = "openssl" }, { name = "openssl-sys" }]

[sources]
unknown-registry = "deny"
unknown-git = "deny"
```

#### .cargo/config.toml

```toml
# Linux: Use mold linker (fastest)
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[target.aarch64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

# macOS: Use lld linker
[target.x86_64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.aarch64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

# Windows: Use lld-link
[target.x86_64-pc-windows-msvc]
linker = "lld-link"

[net]
git-fetch-with-cli = true

# Useful aliases for development
[alias]
lint = "clippy --all-targets --all-features -- -D warnings"
t = "nextest run"
ta = "nextest run --all-features"
```

---

## 7. Type Definitions

### 7.1 Enums (src/types/enums.rs)

```rust
use serde::{Deserialize, Serialize};
use sqlx::Type;

/// Risk levels from safest (1) to most dangerous (5)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive]  // Allow future level additions without breaking changes
pub enum Level {
    None = 0,
    Vault = 1,
    Mainframe = 2,
    Subnet = 3,
    Darknet = 4,
    BlackIce = 5,
}

/// Error returned when an invalid level value is provided
#[derive(Debug, Clone, Copy, thiserror::Error)]
#[error("invalid level value: {0}")]
pub struct InvalidLevel(pub u8);

impl TryFrom<u8> for Level {
    type Error = InvalidLevel;
    
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::None),
            1 => Ok(Self::Vault),
            2 => Ok(Self::Mainframe),
            3 => Ok(Self::Subnet),
            4 => Ok(Self::Darknet),
            5 => Ok(Self::BlackIce),
            _ => Err(InvalidLevel(value)),
        }
    }
}

impl Level {

    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::None => "None",
            Self::Vault => "Vault",
            Self::Mainframe => "Mainframe",
            Self::Subnet => "Subnet",
            Self::Darknet => "Darknet",
            Self::BlackIce => "Black Ice",
        }
    }

    /// Base death rate in basis points (100 = 1%)
    #[must_use]
    pub const fn death_rate_bps(&self) -> u16 {
        match self {
            Self::None => 0,
            Self::Vault => 0,        // 0%
            Self::Mainframe => 200,  // 2%
            Self::Subnet => 1500,    // 15%
            Self::Darknet => 4000,   // 40%
            Self::BlackIce => 9000,  // 90%
        }
    }

    /// Scan frequency in seconds
    #[must_use]
    pub const fn scan_interval_secs(&self) -> u64 {
        match self {
            Self::None => 0,
            Self::Vault => 0,           // Never (safe)
            Self::Mainframe => 86400,   // 24 hours
            Self::Subnet => 28800,      // 8 hours
            Self::Darknet => 7200,      // 2 hours
            Self::BlackIce => 1800,     // 30 minutes
        }
    }
}

/// Types of boosts that can be applied to positions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive]  // Allow future boost types
pub enum BoostType {
    DeathReduction = 0,
    YieldMultiplier = 1,
}

/// Error returned when an invalid boost type value is provided
#[derive(Debug, Clone, Copy, thiserror::Error)]
#[error("invalid boost type value: {0}")]
pub struct InvalidBoostType(pub u8);

impl TryFrom<u8> for BoostType {
    type Error = InvalidBoostType;
    
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::DeathReduction),
            1 => Ok(Self::YieldMultiplier),
            _ => Err(InvalidBoostType(value)),
        }
    }
}

impl BoostType {

    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::DeathReduction => "Death Reduction",
            Self::YieldMultiplier => "Yield Multiplier",
        }
    }
}

/// Types of prediction rounds
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[repr(i16)]
#[sqlx(type_name = "smallint")]
#[non_exhaustive]  // Allow future round types
pub enum RoundType {
    DeathCount = 0,
    WhaleDeath = 1,
    StreakRecord = 2,
    SystemReset = 3,
}

/// Error returned when an invalid round type value is provided
#[derive(Debug, Clone, Copy, thiserror::Error)]
#[error("invalid round type value: {0}")]
pub struct InvalidRoundType(pub u8);

impl TryFrom<u8> for RoundType {
    type Error = InvalidRoundType;
    
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::DeathCount),
            1 => Ok(Self::WhaleDeath),
            2 => Ok(Self::StreakRecord),
            3 => Ok(Self::SystemReset),
            _ => Err(InvalidRoundType(value)),
        }
    }
}

impl RoundType {

    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::DeathCount => "Death Count",
            Self::WhaleDeath => "Whale Death",
            Self::StreakRecord => "Streak Record",
            Self::SystemReset => "System Reset",
        }
    }
}

/// Position exit reasons
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[sqlx(type_name = "varchar")]
#[non_exhaustive]  // Allow future exit reasons
pub enum ExitReason {
    Extracted,
    Traced,
    Culled,
    SystemReset,
}
```

### 7.2 Event Structs (src/types/events.rs)

```rust
use alloy_primitives::{Address, B256, U256};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::enums::{BoostType, Level, RoundType};

/// Metadata attached to every indexed event
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
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
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]  // CRITICAL: New event types will be added as contracts evolve
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
    WinningsClaimed(WinningsClaimedEvent),

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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JackedInEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub level: Level,
    pub new_total: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StakeAddedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub new_total: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExtractedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub amount: U256,
    pub rewards: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeathsProcessedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub count: U256,
    pub total_dead: U256,
    pub burned: U256,
    pub distributed: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SurvivorsUpdatedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub count: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CascadeDistributedEvent {
    pub meta: EventMetadata,
    pub source_level: Level,
    pub same_level_amount: U256,
    pub upstream_amount: U256,
    pub burn_amount: U256,
    pub protocol_amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmissionsAddedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BoostAppliedEvent {
    pub meta: EventMetadata,
    pub user: Address,
    pub boost_type: BoostType,
    pub value_bps: u16,
    pub expiry: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SystemResetTriggeredEvent {
    pub meta: EventMetadata,
    pub total_penalty: U256,
    pub jackpot_winner: Address,
    pub jackpot_amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScanExecutedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub scan_id: U256,
    pub seed: U256,
    pub executed_at: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeathsSubmittedEvent {
    pub meta: EventMetadata,
    pub level: Level,
    pub scan_id: U256,
    pub count: U256,
    pub total_dead: U256,
    pub submitter: Address,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoundCreatedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub round_type: RoundType,
    pub target_level: Level,
    pub line: U256,
    pub deadline: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BetPlacedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub user: Address,
    pub is_over: bool,
    pub amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoundResolvedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub outcome: bool,
    pub total_pot: U256,
    pub burned: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WinningsClaimedEvent {
    pub meta: EventMetadata,
    pub round_id: U256,
    pub user: Address,
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA TOKEN EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TransferEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub to: Address,
    pub value: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxBurnedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxCollectedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxExclusionSetEvent {
    pub meta: EventMetadata,
    pub account: Address,
    pub excluded: bool,
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEE ROUTER EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TollCollectedEvent {
    pub meta: EventMetadata,
    pub from: Address,
    pub amount: U256,
    pub reason: B256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BuybackExecutedEvent {
    pub meta: EventMetadata,
    pub eth_spent: U256,
    pub data_received: U256,
    pub data_burned: U256,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OperationsWithdrawnEvent {
    pub meta: EventMetadata,
    pub to: Address,
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARDS DISTRIBUTOR EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmissionsDistributedEvent {
    pub meta: EventMetadata,
    pub total_amount: U256,
    pub timestamp: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WeightsUpdatedEvent {
    pub meta: EventMetadata,
    pub new_weights: [u16; 5],
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM VESTING EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TokensClaimedEvent {
    pub meta: EventMetadata,
    pub beneficiary: Address,
    pub amount: U256,
}
```

### 7.3 Ports - Trait Definitions (src/ports.rs)

Following hexagonal architecture, we define trait-based ports that the domain layer uses. Infrastructure provides concrete implementations (adapters).

```rust
//! Port definitions for dependency injection and testability.
//! 
//! Ports are trait definitions that describe what the domain layer needs.
//! Adapters (in the infrastructure layer) implement these traits.

use async_trait::async_trait;
use alloy_primitives::B256;
use chrono::{DateTime, Utc};

use crate::error::Result;
use crate::types::entities::*;
use crate::types::enums::Level;
use crate::types::events::*;
use crate::types::primitives::{BlockNumber, EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE PORTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for position persistence operations
#[async_trait]
pub trait PositionStore: Send + Sync {
    /// Get active position for a user address
    async fn get_active_position(&self, address: &EthAddress) -> Result<Option<Position>>;
    
    /// Save or update a position
    async fn save_position(&self, position: &Position) -> Result<()>;
    
    /// Get positions at risk of culling for a level
    async fn get_at_risk_positions(&self, level: Level, threshold: u32) -> Result<Vec<Position>>;
    
    /// Record position history entry
    async fn record_history(&self, entry: &PositionHistoryEntry) -> Result<()>;
}

/// Port for scan persistence operations
#[async_trait]
pub trait ScanStore: Send + Sync {
    /// Save a new scan
    async fn save_scan(&self, scan: &Scan) -> Result<()>;
    
    /// Update scan with finalization data
    async fn finalize_scan(&self, scan_id: &str, data: ScanFinalizationData) -> Result<()>;
    
    /// Get recent scans for a level
    async fn get_recent_scans(&self, level: Level, limit: u32) -> Result<Vec<Scan>>;
}

/// Port for death record persistence
#[async_trait]
pub trait DeathStore: Send + Sync {
    /// Record deaths from a scan
    async fn record_deaths(&self, deaths: &[Death]) -> Result<()>;
    
    /// Get deaths for a scan
    async fn get_deaths_for_scan(&self, scan_id: &str) -> Result<Vec<Death>>;
    
    /// Get user's death history
    async fn get_user_deaths(&self, address: &EthAddress, limit: u32) -> Result<Vec<Death>>;
}

/// Port for market/betting persistence
#[async_trait]
pub trait MarketStore: Send + Sync {
    /// Save a new round
    async fn save_round(&self, round: &Round) -> Result<()>;
    
    /// Update round with bet
    async fn record_bet(&self, bet: &Bet) -> Result<()>;
    
    /// Resolve a round
    async fn resolve_round(&self, round_id: &str, outcome: bool, burned: &TokenAmount) -> Result<()>;
    
    /// Get active rounds
    async fn get_active_rounds(&self, limit: u32) -> Result<Vec<Round>>;
}

/// Port for indexer state management
#[async_trait]
pub trait IndexerStateStore: Send + Sync {
    /// Get last indexed block number
    async fn get_last_block(&self) -> Result<BlockNumber>;
    
    /// Set last indexed block
    async fn set_last_block(&self, block: BlockNumber, hash: B256) -> Result<()>;
    
    /// Insert block hash for reorg detection
    async fn insert_block_hash(&self, block: BlockNumber, hash: B256, parent: B256, timestamp: u64) -> Result<()>;
    
    /// Get stored block hash for reorg check
    async fn get_block_hash(&self, block: BlockNumber) -> Result<Option<B256>>;
    
    /// Execute reorg rollback
    async fn execute_reorg_rollback(&self, fork_point: BlockNumber) -> Result<()>;
}

/// Port for analytics/statistics
#[async_trait]
pub trait StatsStore: Send + Sync {
    /// Get global statistics
    async fn get_global_stats(&self) -> Result<GlobalStats>;
    
    /// Get statistics for a level
    async fn get_level_stats(&self, level: Level) -> Result<LevelStats>;
    
    /// Update level statistics
    async fn update_level_stats(&self, level: Level, delta: LevelStatsDelta) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING PORT
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for event streaming/publishing
#[async_trait]
pub trait EventPublisher: Send + Sync {
    /// Publish an event to the streaming system
    async fn publish(&self, event: &GhostnetEvent) -> Result<()>;
    
    /// Publish to a specific topic
    async fn publish_to_topic(&self, topic: &str, payload: &[u8]) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CACHING PORT
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for in-memory caching
pub trait Cache: Send + Sync {
    /// Get cached position
    fn get_position(&self, address: &EthAddress) -> Option<Position>;
    
    /// Cache a position
    fn set_position(&self, address: &EthAddress, position: Option<Position>);
    
    /// Invalidate cached position
    fn invalidate_position(&self, address: &EthAddress);
    
    /// Get cached global stats
    fn get_global_stats(&self) -> Option<GlobalStats>;
    
    /// Cache global stats
    fn set_global_stats(&self, stats: GlobalStats);
    
    /// Check rate limit (returns true if allowed)
    fn check_rate_limit(&self, key: &str, limit: u32, window_secs: u64) -> bool;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIME PORT (for testability)
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for time operations (allows injecting fake time in tests)
pub trait Clock: Send + Sync {
    /// Get current UTC time
    fn now(&self) -> DateTime<Utc>;
}

/// Production clock implementation
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }
}

/// Test clock implementation
#[cfg(test)]
pub struct FakeClock {
    pub time: std::sync::atomic::AtomicI64,
}

#[cfg(test)]
impl FakeClock {
    pub fn new(time: DateTime<Utc>) -> Self {
        Self {
            time: std::sync::atomic::AtomicI64::new(time.timestamp()),
        }
    }
    
    pub fn advance(&self, duration: chrono::Duration) {
        self.time.fetch_add(duration.num_seconds(), std::sync::atomic::Ordering::SeqCst);
    }
}

#[cfg(test)]
impl Clock for FakeClock {
    fn now(&self) -> DateTime<Utc> {
        DateTime::from_timestamp(
            self.time.load(std::sync::atomic::Ordering::SeqCst),
            0
        ).unwrap_or_default()
    }
}
```

### 7.4 Error Types (src/error.rs)

Following the layered error handling pattern, we define error types for each architectural layer:

```rust
//! Layered error types for the indexer.
//! 
//! Each layer defines its own errors:
//! - DomainError: Business logic violations
//! - InfraError: Infrastructure failures (DB, network, etc.)
//! - AppError: Application-level errors combining domain and infra
//! - ApiError: HTTP-specific errors with status codes

use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;
use thiserror::Error;

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN ERRORS (no external dependencies)
// ═══════════════════════════════════════════════════════════════════════════════

/// Domain-level errors representing business logic violations
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum DomainError {
    #[error("invalid level value: {0}")]
    InvalidLevel(u8),
    
    #[error("position not found for address: {0}")]
    PositionNotFound(String),
    
    #[error("scan not found: level={level}, scan_id={scan_id}")]
    ScanNotFound { level: u8, scan_id: String },
    
    #[error("round not found: {0}")]
    RoundNotFound(String),
    
    #[error("invalid state transition: {from} -> {to}")]
    InvalidStateTransition { from: String, to: String },
    
    #[error("position already exists for address: {0}")]
    PositionAlreadyExists(String),
    
    #[error("round already resolved: {0}")]
    RoundAlreadyResolved(String),
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFRASTRUCTURE ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Infrastructure-level errors from external systems
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum InfraError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("RPC error: {0}")]
    Rpc(#[source] Box<dyn std::error::Error + Send + Sync>),
    
    #[error("streaming error: {0}")]
    Streaming(#[source] Box<dyn std::error::Error + Send + Sync>),
    
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    
    #[error("event decoding error: {0}")]
    EventDecoding(String),
    
    #[error("resource not found")]
    NotFound,
    
    #[error("connection pool exhausted")]
    PoolExhausted,
}

// ═══════════════════════════════════════════════════════════════════════════════
// APPLICATION ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Application-level errors combining domain and infrastructure
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum AppError {
    #[error(transparent)]
    Domain(#[from] DomainError),
    
    #[error(transparent)]
    Infra(#[from] InfraError),
    
    #[error("chain reorg detected at block {0}")]
    ReorgDetected(u64),
    
    #[error("configuration error: {0}")]
    Config(String),
    
    #[error("initialization error: {0}")]
    Initialization(String),
    
    #[error("shutdown requested")]
    ShutdownRequested,
}

/// Type alias for application Results
pub type Result<T> = std::result::Result<T, AppError>;

// ═══════════════════════════════════════════════════════════════════════════════
// API ERRORS (HTTP-specific)
// ═══════════════════════════════════════════════════════════════════════════════

/// API-level errors with HTTP status codes
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum ApiError {
    #[error(transparent)]
    App(#[from] AppError),
    
    #[error("rate limited: retry after {retry_after_secs} seconds")]
    RateLimited { retry_after_secs: u64 },
    
    #[error("invalid request: {0}")]
    BadRequest(String),
    
    #[error("unauthorized")]
    Unauthorized,
    
    #[error("internal error")]
    Internal(#[source] anyhow::Error),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message) = match &self {
            // Domain errors map to client errors
            ApiError::App(AppError::Domain(DomainError::PositionNotFound(_))) |
            ApiError::App(AppError::Domain(DomainError::ScanNotFound { .. })) |
            ApiError::App(AppError::Domain(DomainError::RoundNotFound(_))) => {
                (StatusCode::NOT_FOUND, "NOT_FOUND", self.to_string())
            }
            
            ApiError::App(AppError::Domain(DomainError::InvalidLevel(_))) |
            ApiError::App(AppError::Domain(DomainError::InvalidStateTransition { .. })) |
            ApiError::BadRequest(_) => {
                (StatusCode::BAD_REQUEST, "BAD_REQUEST", self.to_string())
            }
            
            ApiError::App(AppError::Domain(DomainError::PositionAlreadyExists(_))) |
            ApiError::App(AppError::Domain(DomainError::RoundAlreadyResolved(_))) => {
                (StatusCode::CONFLICT, "CONFLICT", self.to_string())
            }
            
            ApiError::RateLimited { retry_after_secs } => {
                return (
                    StatusCode::TOO_MANY_REQUESTS,
                    [("Retry-After", retry_after_secs.to_string())],
                    Json(json!({
                        "error": {
                            "code": "RATE_LIMITED",
                            "message": self.to_string(),
                            "retry_after_secs": retry_after_secs
                        }
                    }))
                ).into_response();
            }
            
            ApiError::Unauthorized => {
                (StatusCode::UNAUTHORIZED, "UNAUTHORIZED", self.to_string())
            }
            
            // Infrastructure and internal errors: log but don't expose details
            ApiError::App(AppError::Infra(_)) |
            ApiError::App(AppError::ReorgDetected(_)) |
            ApiError::App(AppError::Config(_)) |
            ApiError::App(AppError::Initialization(_)) |
            ApiError::App(AppError::ShutdownRequested) |
            ApiError::Internal(_) => {
                tracing::error!(error = ?self, "Internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Internal error".into())
            }
        };
        
        (status, Json(json!({
            "error": {
                "code": code,
                "message": message
            }
        }))).into_response()
    }
}
```

### 7.5 Primitive Newtypes (src/types/primitives.rs)

Validated newtypes provide type safety and domain semantics. Raw bytes and strings are replaced with validated wrappers.

```rust
//! Validated primitive types for domain entities.
//! 
//! These newtypes provide:
//! - Type safety (can't accidentally pass amount as address)
//! - Validation at construction time
//! - Domain semantics in function signatures

use std::fmt;
use std::str::FromStr;

use bigdecimal::BigDecimal;
use serde::{Deserialize, Serialize};
use thiserror::Error;

// ═══════════════════════════════════════════════════════════════════════════════
// ETHEREUM ADDRESS
// ═══════════════════════════════════════════════════════════════════════════════

/// Validated 20-byte Ethereum address.
/// 
/// This newtype ensures addresses are always exactly 20 bytes.
/// Use `Address` from alloy-primitives for on-chain interaction,
/// but this type for persistence and domain logic.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct EthAddress([u8; 20]);

impl EthAddress {
    /// Create from a fixed-size array (infallible).
    #[must_use]
    pub const fn new(bytes: [u8; 20]) -> Self {
        Self(bytes)
    }
    
    /// Try to create from a byte slice.
    pub fn from_slice(slice: &[u8]) -> Result<Self, InvalidAddress> {
        let bytes: [u8; 20] = slice
            .try_into()
            .map_err(|_| InvalidAddress::WrongLength(slice.len()))?;
        Ok(Self(bytes))
    }
    
    /// Parse from hex string (with or without 0x prefix).
    pub fn from_hex(s: &str) -> Result<Self, InvalidAddress> {
        let s = s.strip_prefix("0x").unwrap_or(s);
        if s.len() != 40 {
            return Err(InvalidAddress::WrongLength(s.len() / 2));
        }
        let bytes = hex::decode(s).map_err(|_| InvalidAddress::InvalidHex)?;
        Self::from_slice(&bytes)
    }
    
    /// Get the underlying bytes.
    #[must_use]
    pub const fn as_bytes(&self) -> &[u8; 20] {
        &self.0
    }
    
    /// Get as a byte slice.
    #[must_use]
    pub fn as_slice(&self) -> &[u8] {
        &self.0
    }
    
    /// Convert to checksum hex string with 0x prefix.
    #[must_use]
    pub fn to_checksum(&self) -> String {
        // Simplified: just lowercase hex. For full EIP-55 checksum,
        // use alloy-primitives::Address::to_checksum()
        format!("0x{}", hex::encode(self.0))
    }
}

impl fmt::Debug for EthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "EthAddress({})", self.to_checksum())
    }
}

impl fmt::Display for EthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_checksum())
    }
}

impl From<EthAddress> for String {
    fn from(addr: EthAddress) -> Self {
        addr.to_checksum()
    }
}

impl TryFrom<String> for EthAddress {
    type Error = InvalidAddress;
    
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::from_hex(&s)
    }
}

impl From<[u8; 20]> for EthAddress {
    fn from(bytes: [u8; 20]) -> Self {
        Self::new(bytes)
    }
}

impl From<alloy_primitives::Address> for EthAddress {
    fn from(addr: alloy_primitives::Address) -> Self {
        Self::new(addr.0 .0)
    }
}

impl From<EthAddress> for alloy_primitives::Address {
    fn from(addr: EthAddress) -> Self {
        Self::from(addr.0)
    }
}

/// Error for invalid Ethereum addresses.
#[derive(Debug, Clone, Error)]
pub enum InvalidAddress {
    #[error("wrong length: expected 20 bytes, got {0}")]
    WrongLength(usize),
    #[error("invalid hex encoding")]
    InvalidHex,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN AMOUNT
// ═══════════════════════════════════════════════════════════════════════════════

/// Non-negative token amount with arbitrary precision.
/// 
/// Backed by `BigDecimal` for exact arithmetic. Amounts are always non-negative.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct TokenAmount(BigDecimal);

impl TokenAmount {
    /// Zero amount.
    pub fn zero() -> Self {
        Self(BigDecimal::from(0))
    }
    
    /// Create from BigDecimal, validating non-negative.
    pub fn new(value: BigDecimal) -> Result<Self, InvalidAmount> {
        if value.sign() == bigdecimal::num_bigint::Sign::Minus {
            return Err(InvalidAmount::Negative);
        }
        Ok(Self(value))
    }
    
    /// Parse from string representation.
    pub fn parse(s: &str) -> Result<Self, InvalidAmount> {
        let value = BigDecimal::from_str(s).map_err(|_| InvalidAmount::ParseError)?;
        Self::new(value)
    }
    
    /// Create from U256 (wei) with decimals.
    pub fn from_wei(wei: alloy_primitives::U256, decimals: u8) -> Self {
        let wei_str = wei.to_string();
        let value = BigDecimal::from_str(&wei_str)
            .expect("U256 string is always valid")
            / BigDecimal::from(10_u64.pow(decimals as u32));
        Self(value)
    }
    
    /// Get the underlying BigDecimal.
    #[must_use]
    pub fn as_decimal(&self) -> &BigDecimal {
        &self.0
    }
    
    /// Convert to wei (U256) given decimals.
    pub fn to_wei(&self, decimals: u8) -> alloy_primitives::U256 {
        let scaled = &self.0 * BigDecimal::from(10_u64.pow(decimals as u32));
        let int = scaled.to_string().split('.').next().unwrap().to_string();
        alloy_primitives::U256::from_str(&int).unwrap_or_default()
    }
    
    /// Check if zero.
    #[must_use]
    pub fn is_zero(&self) -> bool {
        self.0.sign() == bigdecimal::num_bigint::Sign::NoSign
    }
    
    /// Saturating addition.
    #[must_use]
    pub fn saturating_add(&self, other: &Self) -> Self {
        Self(&self.0 + &other.0)
    }
    
    /// Saturating subtraction (floors at zero).
    #[must_use]
    pub fn saturating_sub(&self, other: &Self) -> Self {
        let result = &self.0 - &other.0;
        if result.sign() == bigdecimal::num_bigint::Sign::Minus {
            Self::zero()
        } else {
            Self(result)
        }
    }
}

impl fmt::Debug for TokenAmount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "TokenAmount({})", self.0)
    }
}

impl fmt::Display for TokenAmount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl From<TokenAmount> for String {
    fn from(amount: TokenAmount) -> Self {
        amount.0.to_string()
    }
}

impl TryFrom<String> for TokenAmount {
    type Error = InvalidAmount;
    
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::parse(&s)
    }
}

impl Default for TokenAmount {
    fn default() -> Self {
        Self::zero()
    }
}

/// Error for invalid token amounts.
#[derive(Debug, Clone, Error)]
pub enum InvalidAmount {
    #[error("amount cannot be negative")]
    Negative,
    #[error("failed to parse amount")]
    ParseError,
}

// ═══════════════════════════════════════════════════════════════════════════════
// GHOST STREAK (bounded counter)
// ═══════════════════════════════════════════════════════════════════════════════

/// Ghost streak counter (non-negative, bounded).
/// 
/// Tracks consecutive scan survivals. Max value is `i32::MAX` for DB compatibility.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct GhostStreak(i32);

impl GhostStreak {
    /// Zero streak.
    pub const ZERO: Self = Self(0);
    
    /// Maximum possible streak (for DB i32 compatibility).
    pub const MAX: Self = Self(i32::MAX);
    
    /// Create a new streak value.
    pub fn new(value: i32) -> Result<Self, InvalidStreak> {
        if value < 0 {
            return Err(InvalidStreak::Negative);
        }
        Ok(Self(value))
    }
    
    /// Get the value.
    #[must_use]
    pub const fn get(&self) -> i32 {
        self.0
    }
    
    /// Increment by one (saturating at MAX).
    #[must_use]
    pub fn increment(&self) -> Self {
        Self(self.0.saturating_add(1))
    }
    
    /// Reset to zero.
    #[must_use]
    pub const fn reset(&self) -> Self {
        Self::ZERO
    }
}

impl Default for GhostStreak {
    fn default() -> Self {
        Self::ZERO
    }
}

impl From<GhostStreak> for i32 {
    fn from(streak: GhostStreak) -> Self {
        streak.0
    }
}

impl TryFrom<i32> for GhostStreak {
    type Error = InvalidStreak;
    
    fn try_from(value: i32) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}

/// Error for invalid ghost streak values.
#[derive(Debug, Clone, Error)]
pub enum InvalidStreak {
    #[error("streak cannot be negative")]
    Negative,
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK NUMBER (for type clarity)
// ═══════════════════════════════════════════════════════════════════════════════

/// Block number newtype for clarity.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct BlockNumber(pub u64);

impl BlockNumber {
    #[must_use]
    pub const fn new(n: u64) -> Self {
        Self(n)
    }
    
    #[must_use]
    pub const fn get(&self) -> u64 {
        self.0
    }
}

impl From<u64> for BlockNumber {
    fn from(n: u64) -> Self {
        Self(n)
    }
}

impl From<BlockNumber> for u64 {
    fn from(b: BlockNumber) -> Self {
        b.0
    }
}

impl From<BlockNumber> for i64 {
    fn from(b: BlockNumber) -> Self {
        b.0 as i64
    }
}
```

### 7.6 Entity Types (src/types/entities.rs)

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::enums::{BoostType, ExitReason, Level, RoundType};
use super::primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};

/// Active or historical position
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Position {
    pub id: Uuid,
    pub user_address: EthAddress,
    pub level: Level,
    pub amount: TokenAmount,
    pub reward_debt: TokenAmount,
    pub entry_timestamp: DateTime<Utc>,
    pub last_add_timestamp: Option<DateTime<Utc>>,
    pub ghost_streak: GhostStreak,
    pub is_alive: bool,
    pub is_extracted: bool,
    pub exit_reason: Option<ExitReason>,
    pub exit_timestamp: Option<DateTime<Utc>>,
    pub extracted_amount: Option<TokenAmount>,
    pub extracted_rewards: Option<TokenAmount>,
    pub created_at_block: BlockNumber,
    pub updated_at: DateTime<Utc>,
}

/// Scan execution record
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Scan {
    pub id: Uuid,
    pub scan_id: String,       // On-chain scan ID (U256 as string)
    pub level: Level,
    pub seed: String,          // U256 as string
    pub executed_at: DateTime<Utc>,
    pub finalized_at: Option<DateTime<Utc>>,
    pub death_count: Option<u32>,
    pub total_dead: Option<TokenAmount>,
    pub burned: Option<TokenAmount>,
    pub distributed_same_level: Option<TokenAmount>,
    pub distributed_upstream: Option<TokenAmount>,
    pub protocol_fee: Option<TokenAmount>,
    pub survivor_count: Option<u32>,
}

/// Data for finalizing a scan (used by ScanStore port)
#[derive(Debug, Clone)]
pub struct ScanFinalizationData {
    pub finalized_at: DateTime<Utc>,
    pub death_count: u32,
    pub total_dead: TokenAmount,
    pub burned: TokenAmount,
    pub distributed_same_level: TokenAmount,
    pub distributed_upstream: TokenAmount,
    pub protocol_fee: TokenAmount,
    pub survivor_count: u32,
}

/// Individual death record
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Death {
    pub id: Uuid,
    pub scan_id: Option<Uuid>,
    pub user_address: EthAddress,
    pub position_id: Option<Uuid>,
    pub amount_lost: TokenAmount,
    pub level: Level,
    pub ghost_streak_at_death: Option<GhostStreak>,
    pub created_at: DateTime<Utc>,
}

/// Prediction market round
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Round {
    pub id: Uuid,
    pub round_id: String,      // On-chain round ID (U256 as string)
    pub round_type: RoundType,
    pub target_level: Option<Level>,
    pub line: TokenAmount,
    pub deadline: DateTime<Utc>,
    pub over_pool: TokenAmount,
    pub under_pool: TokenAmount,
    pub is_resolved: bool,
    pub outcome: Option<bool>,
    pub resolve_time: Option<DateTime<Utc>>,
    pub total_burned: Option<TokenAmount>,
}

/// User bet on a round
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Bet {
    pub id: Uuid,
    pub round_id: Uuid,
    pub user_address: EthAddress,
    pub amount: TokenAmount,
    pub is_over: bool,
    pub is_claimed: bool,
    pub winnings: Option<TokenAmount>,
    pub claimed_at: Option<DateTime<Utc>>,
}

/// Active boost on a user
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Boost {
    pub id: Uuid,
    pub user_address: EthAddress,
    pub boost_type: BoostType,
    pub value_bps: i16,
    pub expiry: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

/// Position history entry (for tracking changes over time)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PositionHistoryEntry {
    pub id: Uuid,
    pub position_id: Uuid,
    pub user_address: EthAddress,
    pub action: PositionAction,
    pub amount_change: TokenAmount,
    pub new_total: TokenAmount,
    pub block_number: BlockNumber,
    pub timestamp: DateTime<Utc>,
}

/// Actions that can be recorded in position history
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[non_exhaustive]
pub enum PositionAction {
    JackedIn,
    StakeAdded,
    Extracted,
    Traced,
    Culled,
    SystemReset,
    RewardsClaimed,
}

/// Per-level aggregate statistics
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LevelStats {
    pub level: Level,
    pub total_staked: TokenAmount,
    pub alive_count: u32,
    pub total_deaths: u32,
    pub total_extracted: u32,
    pub total_burned: TokenAmount,
    pub total_distributed: TokenAmount,
    pub highest_ghost_streak: GhostStreak,
    pub updated_at: DateTime<Utc>,
}

/// Delta for updating level statistics
#[derive(Debug, Clone, Default)]
pub struct LevelStatsDelta {
    pub staked_delta: Option<TokenAmount>,
    pub alive_delta: Option<i32>,
    pub deaths_delta: Option<u32>,
    pub extracted_delta: Option<u32>,
    pub burned_delta: Option<TokenAmount>,
    pub distributed_delta: Option<TokenAmount>,
    pub new_highest_streak: Option<GhostStreak>,
}

/// Global protocol statistics
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GlobalStats {
    pub total_value_locked: TokenAmount,
    pub total_positions: u32,
    pub total_deaths: u32,
    pub total_burned: TokenAmount,
    pub total_emissions_distributed: TokenAmount,
    pub total_toll_collected: TokenAmount,
    pub total_buyback_burned: TokenAmount,
    pub system_reset_count: u32,
    pub updated_at: DateTime<Utc>,
}

/// Leaderboard entry
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeaderboardEntry {
    pub rank: u32,
    pub user_address: EthAddress,
    pub score: TokenAmount,
    pub metadata: Option<serde_json::Value>,
}
```

---

## 8. ABI Bindings

Use `alloy-sol-types` macro to generate type-safe event bindings from Solidity signatures.

### 8.1 GhostCore ABI (src/abi/ghost_core.rs)

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

### 8.2 TraceScan ABI (src/abi/trace_scan.rs)

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

### 8.3 DeadPool ABI (src/abi/dead_pool.rs)

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

### 8.4 DataToken ABI (src/abi/data_token.rs)

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

### 8.5 FeeRouter ABI (src/abi/fee_router.rs)

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
}
```

### 8.6 RewardsDistributor ABI (src/abi/rewards_distributor.rs)

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
}
```

---

## 9. Event Router

The event router decodes raw logs and dispatches to appropriate handlers.

### 9.1 Handler Traits (src/handlers/traits.rs)

First, define trait ports for each handler type to enable testing:

```rust
use async_trait::async_trait;
use crate::abi::{ghost_core, trace_scan, dead_pool, data_token, fee_router};
use crate::error::Result;
use crate::types::events::EventMetadata;

/// Port for position event handling
#[async_trait]
pub trait PositionPort: Send + Sync {
    async fn handle_jacked_in(&self, event: ghost_core::JackedIn, meta: EventMetadata) -> Result<()>;
    async fn handle_stake_added(&self, event: ghost_core::StakeAdded, meta: EventMetadata) -> Result<()>;
    async fn handle_extracted(&self, event: ghost_core::Extracted, meta: EventMetadata) -> Result<()>;
    async fn handle_boost_applied(&self, event: ghost_core::BoostApplied, meta: EventMetadata) -> Result<()>;
    async fn handle_position_culled(&self, event: ghost_core::PositionCulled, meta: EventMetadata) -> Result<()>;
}

/// Port for scan event handling
#[async_trait]
pub trait ScanPort: Send + Sync {
    async fn handle_scan_executed(&self, event: trace_scan::ScanExecuted, meta: EventMetadata) -> Result<()>;
    async fn handle_deaths_submitted(&self, event: trace_scan::DeathsSubmitted, meta: EventMetadata) -> Result<()>;
    async fn handle_scan_finalized(&self, event: trace_scan::ScanFinalized, meta: EventMetadata) -> Result<()>;
}

/// Port for death event handling
#[async_trait]
pub trait DeathPort: Send + Sync {
    async fn handle_deaths_processed(&self, event: ghost_core::DeathsProcessed, meta: EventMetadata) -> Result<()>;
    async fn handle_survivors_updated(&self, event: ghost_core::SurvivorsUpdated, meta: EventMetadata) -> Result<()>;
    async fn handle_cascade_distributed(&self, event: ghost_core::CascadeDistributed, meta: EventMetadata) -> Result<()>;
    async fn handle_system_reset(&self, event: ghost_core::SystemResetTriggered, meta: EventMetadata) -> Result<()>;
}

/// Port for market event handling
#[async_trait]
pub trait MarketPort: Send + Sync {
    async fn handle_round_created(&self, event: dead_pool::RoundCreated, meta: EventMetadata) -> Result<()>;
    async fn handle_bet_placed(&self, event: dead_pool::BetPlaced, meta: EventMetadata) -> Result<()>;
    async fn handle_round_resolved(&self, event: dead_pool::RoundResolved, meta: EventMetadata) -> Result<()>;
    async fn handle_winnings_claimed(&self, event: dead_pool::WinningsClaimed, meta: EventMetadata) -> Result<()>;
}

/// Port for token event handling
#[async_trait]
pub trait TokenPort: Send + Sync {
    async fn handle_transfer(&self, event: data_token::Transfer, meta: EventMetadata) -> Result<()>;
    async fn handle_tax_burned(&self, event: data_token::TaxBurned, meta: EventMetadata) -> Result<()>;
    async fn handle_tax_collected(&self, event: data_token::TaxCollected, meta: EventMetadata) -> Result<()>;
}

/// Port for fee event handling
#[async_trait]
pub trait FeePort: Send + Sync {
    async fn handle_toll_collected(&self, event: fee_router::TollCollected, meta: EventMetadata) -> Result<()>;
    async fn handle_buyback_executed(&self, event: fee_router::BuybackExecuted, meta: EventMetadata) -> Result<()>;
}
```

### 9.2 Router Implementation (src/indexer/event_router.rs)

```rust
use alloy::rpc::types::Log;
use alloy_sol_types::SolEvent;
use tracing::{debug, instrument, warn};

use crate::abi::{data_token, dead_pool, fee_router, ghost_core, trace_scan};
use crate::error::Result;
use crate::handlers::traits::*;
use crate::types::events::EventMetadata;

/// Routes decoded events to appropriate handlers.
/// 
/// Generic over handler traits to enable testing with mock implementations.
pub struct EventRouter<P, S, D, M, T, F>
where
    P: PositionPort,
    S: ScanPort,
    D: DeathPort,
    M: MarketPort,
    T: TokenPort,
    F: FeePort,
{
    position_handler: P,
    scan_handler: S,
    death_handler: D,
    market_handler: M,
    token_handler: T,
    fee_handler: F,
}

impl<P, S, D, M, T, F> EventRouter<P, S, D, M, T, F>
where
    P: PositionPort,
    S: ScanPort,
    D: DeathPort,
    M: MarketPort,
    T: TokenPort,
    F: FeePort,
{
    pub fn new(
        position_handler: P,
        scan_handler: S,
        death_handler: D,
        market_handler: M,
        token_handler: T,
        fee_handler: F,
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

    /// Route a single log to its handler.
    /// 
    /// # Cancellation Safety
    /// 
    /// This method is cancellation-safe. If cancelled, no handler will have
    /// partially processed the event - handlers are atomic operations.
    #[instrument(skip(self, log, meta), fields(topic0 = ?log.topics().first()))]
    pub async fn route_log(&self, log: &Log, meta: EventMetadata) -> Result<()> {
        let Some(topic0) = log.topics().first() else {
            debug!("Skipping log with no topics");
            return Ok(());
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

## 10. TimescaleDB Schema

### 10.1 Hybrid Table Strategy

TimescaleDB provides two storage modes:

| Mode | Best For | Characteristics |
|------|----------|-----------------|
| **Hypertables** | Time-series, append-only | Auto-partitioning, compression, fast range queries |
| **Regular Tables** | Entities with updates | Standard PostgreSQL, efficient point lookups |

Our schema uses a **hybrid approach**:

| Table | Type | Rationale |
|-------|------|-----------|
| `indexer_state` | Regular | Configuration, 1 row per chain |
| `block_history` | Hypertable | Auto-pruned, reorg detection |
| `positions` | Regular | Entity with frequent updates |
| `position_history` | Hypertable | Audit trail, append-only |
| `boosts` | Regular | Few rows, expiry queries |
| `scans` | Hypertable | Time-series scan history |
| `deaths` | Hypertable | High volume event log |
| `rounds` | Regular | Entity, status lookups |
| `bets` | Hypertable | Time-ordered betting |
| `token_transfers` | Hypertable | Very high volume |
| `buybacks` | Hypertable | Low volume, pure time-series |
| `system_resets` | Regular | Very rare events |
| `level_stats` | Regular | 5 rows, aggregates |
| `global_stats` | Regular | 1 row singleton |
| `leaderboard_cache` | Regular | Periodically refreshed |

### 10.2 Migration: Enable TimescaleDB

```sql
-- migrations/00001_enable_timescaledb.sql

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Verify installation
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'
    ) THEN
        RAISE EXCEPTION 'TimescaleDB extension not installed';
    END IF;
END $$;

-- Configure TimescaleDB for optimal performance
ALTER SYSTEM SET timescaledb.max_background_workers = 8;
SELECT pg_reload_conf();
```

### 10.3 Migration: Indexer State

```sql
-- migrations/00002_indexer_state.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXER STATE (Regular Table - Configuration)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE indexer_state (
    id SERIAL PRIMARY KEY,
    chain_id BIGINT NOT NULL UNIQUE,
    last_block BIGINT NOT NULL DEFAULT 0,
    last_block_hash BYTEA,
    last_block_timestamp TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE indexer_state IS 'Tracks indexer progress per chain';

-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCK HISTORY (Hypertable - Auto-pruned for reorg detection)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE block_history (
    block_number BIGINT NOT NULL,
    block_hash BYTEA NOT NULL,
    parent_hash BYTEA NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (timestamp, block_number)
);

-- Convert to hypertable with 1-hour chunks
SELECT create_hypertable('block_history', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour');

-- Auto-prune after 30 minutes (covers 64+ block reorgs on MegaETH)
SELECT add_retention_policy('block_history', INTERVAL '30 minutes');

CREATE INDEX idx_block_history_number ON block_history(block_number DESC);

COMMENT ON TABLE block_history IS 'Recent block hashes for reorg detection, auto-pruned';
```

### 10.4 Migration: Positions

```sql
-- migrations/00003_positions.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITIONS (Regular Table - Entity with Updates)
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
    exit_reason VARCHAR(20),  -- 'extracted', 'traced', 'culled', 'system_reset'
    exit_timestamp TIMESTAMPTZ,
    
    -- Extraction details (if extracted)
    extracted_amount NUMERIC(78, 0),
    extracted_rewards NUMERIC(78, 0),
    
    -- Block info
    created_at_block BIGINT NOT NULL,
    created_at_tx BYTEA NOT NULL,
    updated_at_block BIGINT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_positions_user ON positions(user_address);
CREATE INDEX idx_positions_level_alive ON positions(level) WHERE is_alive = TRUE;
CREATE INDEX idx_positions_ghost_streak ON positions(ghost_streak DESC) WHERE is_alive = TRUE;
CREATE INDEX idx_positions_level_amount ON positions(level, amount ASC) WHERE is_alive = TRUE;

-- Partial unique constraint: only one active position per user
CREATE UNIQUE INDEX idx_positions_unique_active 
    ON positions(user_address) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

COMMENT ON TABLE positions IS 'Active and historical player positions';

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITION HISTORY (Hypertable - Append-only Audit Trail)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE position_history (
    id UUID DEFAULT gen_random_uuid(),
    position_id UUID NOT NULL,
    user_address BYTEA NOT NULL,  -- Denormalized for efficient queries
    action VARCHAR(20) NOT NULL,   -- 'created', 'stake_added', 'extracted', 'died', 'culled'
    amount_change NUMERIC(78, 0),
    new_total NUMERIC(78, 0),
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('position_history', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

-- Compression settings: segment by user for efficient wallet history queries
ALTER TABLE position_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('position_history', INTERVAL '1 day');
SELECT add_retention_policy('position_history', INTERVAL '365 days');

CREATE INDEX idx_position_history_user ON position_history(user_address, created_at DESC);
CREATE INDEX idx_position_history_position ON position_history(position_id, created_at DESC);

COMMENT ON TABLE position_history IS 'Immutable audit log of position changes';

-- ═══════════════════════════════════════════════════════════════════════════════
-- BOOSTS (Regular Table - Few Rows)
-- ═══════════════════════════════════════════════════════════════════════════════

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
CREATE INDEX idx_boosts_active ON boosts(user_address, expiry) WHERE expiry > NOW();

COMMENT ON TABLE boosts IS 'Active boosts from mini-games';
```

### 10.5 Migration: Scans

```sql
-- migrations/00004_scans.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCANS (Hypertable - Time-series)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE scans (
    id UUID DEFAULT gen_random_uuid(),
    scan_id NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
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
    PRIMARY KEY (executed_at, id),
    UNIQUE (level, scan_id)
);

SELECT create_hypertable('scans', 'executed_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE scans SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'executed_at DESC'
);

SELECT add_compression_policy('scans', INTERVAL '7 days');

CREATE INDEX idx_scans_level_time ON scans(level, executed_at DESC);
CREATE INDEX idx_scans_pending ON scans(level, executed_at) WHERE finalized_at IS NULL;

COMMENT ON TABLE scans IS 'Trace scan execution and results';

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEATHS (Hypertable - High Volume Events)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE deaths (
    id UUID DEFAULT gen_random_uuid(),
    scan_id UUID,  -- Reference to scans table (no FK for performance)
    user_address BYTEA NOT NULL,
    position_id UUID,
    amount_lost NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL,
    ghost_streak_at_death INTEGER,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('deaths', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE deaths SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'created_at DESC, user_address'
);

SELECT add_compression_policy('deaths', INTERVAL '3 days');
SELECT add_retention_policy('deaths', INTERVAL '365 days');

CREATE INDEX idx_deaths_user ON deaths(user_address, created_at DESC);
CREATE INDEX idx_deaths_level ON deaths(level, created_at DESC);

COMMENT ON TABLE deaths IS 'Individual death records from trace scans';
```

### 10.6 Migration: Markets (DeadPool)

```sql
-- migrations/00005_markets.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROUNDS (Regular Table - Entity with Updates)
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
    outcome BOOLEAN,  -- true = OVER won
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

COMMENT ON TABLE rounds IS 'DeadPool prediction market rounds';

-- ═══════════════════════════════════════════════════════════════════════════════
-- BETS (Hypertable - Time-ordered)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE bets (
    id UUID DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL,
    round_id_numeric NUMERIC(78, 0) NOT NULL,
    user_address BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    is_over BOOLEAN NOT NULL,
    is_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    winnings NUMERIC(78, 0),
    claimed_at TIMESTAMPTZ,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id),
    UNIQUE (round_id, user_address)
);

SELECT create_hypertable('bets', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE bets SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('bets', INTERVAL '7 days');
SELECT add_retention_policy('bets', INTERVAL '90 days');

CREATE INDEX idx_bets_user ON bets(user_address, created_at DESC);
CREATE INDEX idx_bets_round ON bets(round_id);
CREATE INDEX idx_bets_unclaimed ON bets(round_id) WHERE is_claimed = FALSE;

COMMENT ON TABLE bets IS 'User bets on DeadPool rounds';
```

### 10.7 Migration: Analytics

```sql
-- migrations/00006_analytics.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- TOKEN TRANSFERS (Hypertable - Very High Volume)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE token_transfers (
    id UUID DEFAULT gen_random_uuid(),
    from_address BYTEA NOT NULL,
    to_address BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    tax_burned NUMERIC(78, 0),
    tax_collected NUMERIC(78, 0),
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    log_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('token_transfers', 'created_at',
    chunk_time_interval => INTERVAL '6 hours');

ALTER TABLE token_transfers SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'from_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('token_transfers', INTERVAL '1 day');
SELECT add_retention_policy('token_transfers', INTERVAL '90 days');

-- Index only large transfers for whale tracking
CREATE INDEX idx_transfers_large ON token_transfers(created_at DESC) 
    WHERE amount > 1000000000000000000000;  -- > 1000 DATA

CREATE INDEX idx_transfers_from ON token_transfers(from_address, created_at DESC);
CREATE INDEX idx_transfers_to ON token_transfers(to_address, created_at DESC);

COMMENT ON TABLE token_transfers IS 'DATA token transfers (high volume, time-limited retention)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- BUYBACKS (Hypertable - Low Volume)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE buybacks (
    id UUID DEFAULT gen_random_uuid(),
    eth_spent NUMERIC(78, 0) NOT NULL,
    data_received NUMERIC(78, 0) NOT NULL,
    data_burned NUMERIC(78, 0) NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('buybacks', 'created_at',
    chunk_time_interval => INTERVAL '7 days');

ALTER TABLE buybacks SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('buybacks', INTERVAL '30 days');

COMMENT ON TABLE buybacks IS 'FeeRouter buyback and burn events';

-- ═══════════════════════════════════════════════════════════════════════════════
-- SYSTEM RESETS (Regular Table - Very Rare)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE system_resets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    total_penalty NUMERIC(78, 0) NOT NULL,
    jackpot_winner BYTEA NOT NULL,
    jackpot_amount NUMERIC(78, 0) NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE system_resets IS 'System reset events (very rare)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- AGGREGATED STATISTICS (Regular Tables - Singleton/Few Rows)
-- ═══════════════════════════════════════════════════════════════════════════════

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

COMMENT ON TABLE level_stats IS 'Per-level aggregate statistics';

CREATE TABLE global_stats (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- Singleton
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

COMMENT ON TABLE global_stats IS 'Global protocol statistics (singleton)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- LEADERBOARD CACHE (Regular Table - Periodically Refreshed)
-- ═══════════════════════════════════════════════════════════════════════════════

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

COMMENT ON TABLE leaderboard_cache IS 'Pre-computed leaderboards for fast queries';
```

---

## 11. Compression & Columnstore

### 11.1 How Compression Works

TimescaleDB uses a hybrid row-columnar storage engine called **Hypercore**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HYPERTABLE STORAGE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   RECENT DATA (Rowstore)              OLDER DATA (Columnstore)              │
│   ─────────────────────               ───────────────────────               │
│   • Fast INSERT/UPDATE                • 90%+ compression                    │
│   • Uncompressed                      • Vectorized queries                  │
│   • Real-time queries                 • Sparse indexes                      │
│   • Last 1-24 hours                   • Analytics-optimized                 │
│                                                                              │
│   ┌─────────────────┐                 ┌─────────────────┐                   │
│   │ Chunk N (today) │  ──compress──▶  │ Chunk N-7       │                   │
│   │ Uncompressed    │                 │ Compressed      │                   │
│   └─────────────────┘                 └─────────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Compression Encoding

Compression achieves 90%+ reduction through multiple techniques:

| Technique | Applied To | Savings |
|-----------|-----------|---------|
| **Delta encoding** | Timestamps | 10-20x |
| **Dictionary encoding** | Addresses, enums | 5-10x |
| **Gorilla encoding** | Numeric values | 2-5x |
| **LZ4 compression** | Final pass | 2-4x |

### 11.3 Segmentby Strategy

The `segmentby` column determines how data is grouped within compressed chunks:

```sql
-- GOOD: Query pattern matches segmentby
-- All of a user's data is in the same segment
ALTER TABLE token_transfers SET (
    timescaledb.compress_segmentby = 'from_address'
);

-- Query benefits: only decompresses one segment
SELECT * FROM token_transfers
WHERE from_address = '\x1234...'
  AND created_at > NOW() - INTERVAL '7 days';
```

**Segmentby Selection Guide:**

| Table | Segmentby | Rationale |
|-------|-----------|-----------|
| `token_transfers` | `from_address` | Wallet history queries |
| `position_history` | `user_address` | User position audit |
| `deaths` | `level` | Level-specific death analytics |
| `scans` | `level` | Per-level scan history |
| `bets` | `user_address` | User betting history |
| `buybacks` | (none) | Pure time-series, no filtering |

### 11.4 Orderby Strategy

The `orderby` column determines sort order within segments:

```sql
-- Query pattern: "most recent first"
ALTER TABLE deaths SET (
    timescaledb.compress_orderby = 'created_at DESC, user_address'
);

-- Query benefits from ordering
SELECT * FROM deaths 
WHERE level = 3 
ORDER BY created_at DESC 
LIMIT 100;  -- Very fast: reads first 100 from ordered segment
```

### 11.5 Bloom Filter Indexes (v2.20+)

Bloom filters enable fast point lookups on non-segmentby columns:

```sql
-- Enable bloom filters (on by default in TimescaleDB 2.20+)
SET timescaledb.enable_sparse_index_bloom = on;

-- Query benefits from bloom filter
SELECT * FROM token_transfers
WHERE created_at > NOW() - INTERVAL '7 days'
  AND tx_hash = '\xabcd...';  -- Bloom filter filters chunks
```

### 11.6 Compression Monitoring

```sql
-- Check compression status
SELECT 
    hypertable_name,
    compression_status,
    COUNT(*) as chunk_count,
    pg_size_pretty(SUM(before_compression_total_bytes)) as uncompressed,
    pg_size_pretty(SUM(after_compression_total_bytes)) as compressed,
    ROUND(AVG(compression_ratio), 2) as avg_ratio
FROM timescaledb_information.compressed_chunk_stats
GROUP BY hypertable_name, compression_status;

-- Manual compression for specific chunks (useful during maintenance)
SELECT compress_chunk(c.chunk_schema || '.' || c.chunk_name)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'token_transfers'
  AND c.is_compressed = false
  AND c.range_end < NOW() - INTERVAL '1 day';
```

---

## 12. Continuous Aggregates

Continuous aggregates are incrementally-updated materialized views that TimescaleDB refreshes automatically.

### 12.1 Migration: Continuous Aggregates

```sql
-- migrations/00007_continuous_aggregates.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- TVL CHANGES (Hourly)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW tvl_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    action,
    SUM(CASE WHEN action IN ('created', 'stake_added') THEN amount_change ELSE 0 END) as deposits,
    SUM(CASE WHEN action = 'extracted' THEN ABS(amount_change) ELSE 0 END) as withdrawals,
    SUM(CASE WHEN action IN ('died', 'culled') THEN ABS(amount_change) ELSE 0 END) as losses,
    COUNT(*) as event_count
FROM position_history
GROUP BY bucket, action
WITH NO DATA;

SELECT add_continuous_aggregate_policy('tvl_hourly',
    start_offset => INTERVAL '24 hours',
    end_offset => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEATH STATISTICS (Hourly per Level)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW death_stats_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    level,
    COUNT(*) as death_count,
    SUM(amount_lost) as total_lost,
    AVG(amount_lost) as avg_lost,
    MAX(amount_lost) as max_lost,
    AVG(ghost_streak_at_death) as avg_streak_at_death
FROM deaths
GROUP BY bucket, level
WITH NO DATA;

SELECT add_continuous_aggregate_policy('death_stats_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Compress the continuous aggregate itself
ALTER MATERIALIZED VIEW death_stats_hourly SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('death_stats_hourly', INTERVAL '7 days');

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCAN METRICS (Daily per Level)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW scan_metrics_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', executed_at) AS bucket,
    level,
    COUNT(*) as scan_count,
    SUM(death_count) as total_deaths,
    SUM(total_dead) as total_lost,
    SUM(burned) as total_burned,
    AVG(death_count) as avg_deaths_per_scan,
    AVG(survivor_count) as avg_survivors
FROM scans
WHERE finalized_at IS NOT NULL
GROUP BY bucket, level
WITH NO DATA;

SELECT add_continuous_aggregate_policy('scan_metrics_daily',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRANSFER VOLUME (Hourly)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW transfer_volume_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    COUNT(*) as transfer_count,
    SUM(amount) as total_volume,
    SUM(COALESCE(tax_burned, 0)) as total_tax_burned,
    SUM(COALESCE(tax_collected, 0)) as total_tax_collected,
    COUNT(DISTINCT from_address) as unique_senders,
    COUNT(DISTINCT to_address) as unique_receivers
FROM token_transfers
GROUP BY bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('transfer_volume_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRANSFER VOLUME (Daily - Hierarchical from Hourly)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW transfer_volume_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', bucket) AS bucket,
    SUM(transfer_count) as transfer_count,
    SUM(total_volume) as total_volume,
    SUM(total_tax_burned) as total_tax_burned,
    SUM(total_tax_collected) as total_tax_collected
FROM transfer_volume_hourly
GROUP BY time_bucket('1 day', bucket)
WITH NO DATA;

SELECT add_continuous_aggregate_policy('transfer_volume_daily',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- BUYBACK METRICS (Daily)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW buyback_metrics_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', created_at) AS bucket,
    COUNT(*) as buyback_count,
    SUM(eth_spent) as total_eth_spent,
    SUM(data_received) as total_data_received,
    SUM(data_burned) as total_data_burned
FROM buybacks
GROUP BY bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('buyback_metrics_daily',
    start_offset => INTERVAL '90 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);
```

### 12.2 Querying Continuous Aggregates

```sql
-- API: GET /api/v1/stats/tvl/history
SELECT 
    bucket,
    SUM(deposits) - SUM(withdrawals) - SUM(losses) as net_tvl_change
FROM tvl_hourly
WHERE bucket >= NOW() - INTERVAL '7 days'
GROUP BY bucket
ORDER BY bucket;

-- API: GET /api/v1/stats/deaths/by-level
SELECT 
    level,
    SUM(death_count) as total_deaths,
    SUM(total_lost) as total_lost,
    AVG(avg_streak_at_death) as avg_streak
FROM death_stats_hourly
WHERE bucket >= NOW() - INTERVAL '30 days'
GROUP BY level
ORDER BY level;

-- API: GET /api/v1/stats/volume/daily
SELECT 
    bucket,
    transfer_count,
    total_volume,
    total_tax_burned
FROM transfer_volume_daily
WHERE bucket >= NOW() - INTERVAL '30 days'
ORDER BY bucket;
```

---

## 13. Data Retention Policies

### 13.1 Migration: Retention Policies

```sql
-- migrations/00008_retention_policies.sql

-- ═══════════════════════════════════════════════════════════════════════════════
-- DATA RETENTION POLICIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Block history: Keep only recent for reorg detection (30 minutes)
-- Already set in 00002_indexer_state.sql

-- Token transfers: Keep 90 days of raw data
-- Continuous aggregates retain summarized data longer
SELECT add_retention_policy('token_transfers', INTERVAL '90 days');

-- Deaths: Keep 1 year (important for historical analysis)
SELECT add_retention_policy('deaths', INTERVAL '365 days');

-- Position history: Keep 1 year
SELECT add_retention_policy('position_history', INTERVAL '365 days');

-- Bets: Keep 90 days
SELECT add_retention_policy('bets', INTERVAL '90 days');

-- Scans: Keep indefinitely (low volume, important history)
-- No retention policy

-- Buybacks: Keep indefinitely (very low volume)
-- No retention policy

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONTINUOUS AGGREGATE RETENTION
-- Keep aggregates longer than raw data
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT add_retention_policy('transfer_volume_hourly', INTERVAL '365 days');
SELECT add_retention_policy('transfer_volume_daily', INTERVAL '730 days');
SELECT add_retention_policy('death_stats_hourly', INTERVAL '365 days');
SELECT add_retention_policy('scan_metrics_daily', INTERVAL '730 days');
SELECT add_retention_policy('buyback_metrics_daily', INTERVAL '730 days');
```

### 13.2 Retention Strategy Summary

| Data | Raw Retention | Aggregate Retention | Rationale |
|------|---------------|---------------------|-----------|
| `block_history` | 30 minutes | N/A | Reorg detection only |
| `token_transfers` | 90 days | 2 years (daily) | Volume data, summarized long-term |
| `deaths` | 1 year | 2 years (hourly) | Important history |
| `position_history` | 1 year | N/A | Audit trail |
| `bets` | 90 days | N/A | Historical betting |
| `scans` | Indefinite | 2 years (daily) | Low volume, critical |
| `buybacks` | Indefinite | 2 years (daily) | Very low volume |

---

## 14. Reorg Handling

### 14.1 Reorg Detection

Chain reorganizations occur when the canonical chain changes:

```
Block 100 ─── Block 101 ─── Block 102 ─── Block 103 (our head)
                  │
                  └─── Block 101' ─── Block 102' ─── Block 103' ─── Block 104' (new canonical)
                       
Reorg detected at block 101:
1. Delete all data from blocks 101-103
2. Re-index blocks 101'-104'
```

### 14.2 Detection Implementation

```rust
// src/indexer/reorg_handler.rs

use anyhow::Result;
use tracing::{info, warn};

pub struct ReorgHandler {
    store: PostgresStore,
    max_reorg_depth: u64,
}

impl ReorgHandler {
    /// Check if the new block's parent matches our stored hash
    pub async fn check_for_reorg(
        &self,
        new_block_number: u64,
        new_parent_hash: &[u8],
    ) -> Result<Option<u64>> {
        let parent_block = new_block_number.saturating_sub(1);
        
        // Get stored hash for parent block
        let stored_hash = self.store.get_block_hash(parent_block).await?;
        
        match stored_hash {
            None => {
                // We don't have the parent - might be first sync or large gap
                Ok(None)
            }
            Some(hash) if hash == new_parent_hash => {
                // Hashes match - no reorg
                Ok(None)
            }
            Some(_) => {
                // Hash mismatch - reorg detected!
                // Find the fork point by walking back
                let fork_point = self.find_fork_point(parent_block).await?;
                warn!(
                    fork_point,
                    current_block = new_block_number,
                    "Chain reorg detected"
                );
                Ok(Some(fork_point))
            }
        }
    }
    
    /// Walk back to find where chains diverge
    async fn find_fork_point(&self, from_block: u64) -> Result<u64> {
        let min_block = from_block.saturating_sub(self.max_reorg_depth);
        
        for block_num in (min_block..=from_block).rev() {
            // Compare our stored hash with chain's hash
            // (Would need RPC call to get actual chain hash)
            // For simplicity, we rollback to min_block
        }
        
        Ok(min_block)
    }
    
    /// Handle reorg by rolling back affected data
    pub async fn handle_reorg(&self, fork_point: u64) -> Result<()> {
        info!(fork_point, "Rolling back data for reorg");
        
        // Call stored procedure for efficient rollback
        self.store.execute_reorg_rollback(fork_point).await?;
        
        info!(fork_point, "Reorg rollback complete");
        Ok(())
    }
}
```

### 14.3 Database Rollback Function

```sql
-- Efficient reorg rollback using TimescaleDB
CREATE OR REPLACE FUNCTION handle_reorg(reorg_block BIGINT)
RETURNS void AS $$
DECLARE
    reorg_timestamp TIMESTAMPTZ;
BEGIN
    -- Get the timestamp of the reorg block
    SELECT timestamp INTO reorg_timestamp
    FROM block_history
    WHERE block_number = reorg_block;
    
    IF reorg_timestamp IS NULL THEN
        reorg_timestamp := NOW() - INTERVAL '1 minute';
    END IF;
    
    -- Delete from hypertables (TimescaleDB optimizes by chunk)
    DELETE FROM token_transfers WHERE block_number >= reorg_block;
    DELETE FROM deaths WHERE block_number >= reorg_block;
    DELETE FROM bets WHERE block_number >= reorg_block;
    DELETE FROM block_history WHERE block_number >= reorg_block;
    
    -- Delete from position_history
    DELETE FROM position_history WHERE block_number >= reorg_block;
    
    -- Revert position state changes
    -- This is complex - positions may need to be "unextracted", "revived", etc.
    -- For simplicity, mark affected positions for re-sync
    UPDATE positions 
    SET updated_at = NOW()
    WHERE updated_at_block >= reorg_block;
    
    -- Update scans
    DELETE FROM scans WHERE executed_block >= reorg_block;
    
    -- Update rounds
    UPDATE rounds 
    SET is_resolved = FALSE, 
        outcome = NULL, 
        resolved_block = NULL
    WHERE resolved_block >= reorg_block;
    
    -- Invalidate continuous aggregates for affected time range
    CALL refresh_continuous_aggregate('tvl_hourly', reorg_timestamp, NOW());
    CALL refresh_continuous_aggregate('death_stats_hourly', reorg_timestamp, NOW());
    CALL refresh_continuous_aggregate('transfer_volume_hourly', reorg_timestamp, NOW());
    
    -- Update indexer state
    UPDATE indexer_state 
    SET last_block = reorg_block - 1,
        last_block_hash = (
            SELECT block_hash FROM block_history 
            WHERE block_number = reorg_block - 1
            ORDER BY timestamp DESC
            LIMIT 1
        ),
        updated_at = NOW();
    
    RAISE NOTICE 'Reorg handled: rolled back to block %', reorg_block - 1;
END;
$$ LANGUAGE plpgsql;
```

---

## 15. Apache Iggy Integration

### 15.1 Overview

Apache Iggy provides the real-time event streaming layer:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IGGY ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   INDEXER (Producer)                                                         │
│   ─────────────────                                                         │
│   • Publishes events to Iggy after database write                           │
│   • Uses TCP transport (port 8090) for maximum performance                  │
│                                                                              │
│                              │                                               │
│                              ▼                                               │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                        IGGY SERVER                                    │  │
│   │                                                                        │  │
│   │   Stream: ghostnet                                                     │  │
│   │   ├── Topic: positions (3 partitions)                                 │  │
│   │   │   └── JackedIn, StakeAdded, Extracted, PositionCulled            │  │
│   │   ├── Topic: scans (5 partitions - one per level)                    │  │
│   │   │   └── ScanExecuted, DeathsSubmitted, ScanFinalized               │  │
│   │   ├── Topic: deaths (5 partitions - one per level)                   │  │
│   │   │   └── DeathsProcessed, CascadeDistributed, SystemReset           │  │
│   │   ├── Topic: markets (3 partitions)                                  │  │
│   │   │   └── RoundCreated, BetPlaced, RoundResolved, WinningsClaimed    │  │
│   │   ├── Topic: tokens (3 partitions)                                   │  │
│   │   │   └── Transfer, TaxBurned, TaxCollected                          │  │
│   │   └── Topic: feed (1 partition)                                      │  │
│   │       └── All events combined for live feed                          │  │
│   │                                                                        │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│              ┌───────────────┴───────────────┐                              │
│              │                               │                              │
│              ▼                               ▼                              │
│   API WEBSOCKET HANDLER           EXTERNAL CONSUMERS                        │
│   (Consumer Group: api-ws)        (Consumer Group: analytics)               │
│   • Subscribes to `feed` topic    • Subscribes to specific topics          │
│   • Broadcasts to WebSocket       • Process for analytics, alerts          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.2 Iggy Client Setup (src/streaming/iggy.rs)

```rust
use anyhow::Result;
use iggy::client::Client;
use iggy::clients::client::IggyClient;
use iggy::compression::compression_algorithm::CompressionAlgorithm;
use iggy::utils::expiry::IggyExpiry;
use iggy::utils::topic_size::MaxTopicSize;
use tracing::info;

/// Iggy client wrapper for GHOSTNET
pub struct GhostnetIggy {
    client: IggyClient,
    stream_id: u32,
}

impl GhostnetIggy {
    /// Connect to Iggy server
    pub async fn connect(address: &str, username: &str, password: &str) -> Result<Self> {
        let client = IggyClient::builder()
            .with_tcp()
            .with_server_address(address.parse()?)
            .build()?;
        
        client.connect().await?;
        client.login_user(username, password).await?;
        
        info!("Connected to Iggy at {}", address);
        
        Ok(Self {
            client,
            stream_id: 1,
        })
    }
    
    /// Initialize stream and topics
    pub async fn initialize(&self) -> Result<()> {
        // Create stream (idempotent)
        let _ = self.client.create_stream("ghostnet", Some(self.stream_id)).await;
        
        // Create topics
        let topics = [
            ("positions", 3),
            ("scans", 5),      // One partition per level
            ("deaths", 5),
            ("markets", 3),
            ("tokens", 3),
            ("feed", 1),       // Single partition for ordered feed
        ];
        
        for (name, partitions) in topics {
            let _ = self.client.create_topic(
                &self.stream_id.try_into()?,
                name,
                partitions,
                CompressionAlgorithm::None,
                None,  // replication factor
                None,  // topic ID (auto-assign)
                IggyExpiry::NeverExpire,
                MaxTopicSize::ServerDefault,
            ).await;
        }
        
        info!("Initialized Iggy stream and topics");
        Ok(())
    }
    
    /// Get the underlying client for publishing
    pub fn client(&self) -> &IggyClient {
        &self.client
    }
    
    pub fn stream_id(&self) -> u32 {
        self.stream_id
    }
}
```

### 15.3 Event Publisher (src/streaming/publisher.rs)

```rust
use anyhow::Result;
use iggy::client::MessageClient;
use iggy::messages::send_messages::{IggyMessage, Partitioning};
use serde::Serialize;
use tracing::debug;

use super::iggy::GhostnetIggy;
use crate::types::events::*;

/// Topic names
pub mod topics {
    pub const POSITIONS: &str = "positions";
    pub const SCANS: &str = "scans";
    pub const DEATHS: &str = "deaths";
    pub const MARKETS: &str = "markets";
    pub const TOKENS: &str = "tokens";
    pub const FEED: &str = "feed";
}

/// Publisher for streaming events to Iggy
pub struct EventPublisher {
    iggy: GhostnetIggy,
}

impl EventPublisher {
    pub fn new(iggy: GhostnetIggy) -> Self {
        Self { iggy }
    }
    
    /// Publish event to specific topic and optionally to feed
    async fn publish<T: Serialize>(
        &self,
        topic: &str,
        event: &T,
        partition_key: Option<&str>,
        include_in_feed: bool,
    ) -> Result<()> {
        let payload = serde_json::to_vec(event)?;
        let mut messages = vec![IggyMessage::new(None, payload.clone().into())];
        
        // Determine partitioning strategy
        let partitioning = match partition_key {
            Some(key) => Partitioning::messages_key_str(key)?,
            None => Partitioning::balanced(),
        };
        
        // Publish to specific topic
        self.iggy.client().send_messages(
            &self.iggy.stream_id().try_into()?,
            &topic.try_into()?,
            &partitioning,
            &mut messages,
        ).await?;
        
        debug!(topic, "Published event to Iggy");
        
        // Also publish to feed for live updates
        if include_in_feed {
            let mut feed_messages = vec![IggyMessage::new(None, payload.into())];
            self.iggy.client().send_messages(
                &self.iggy.stream_id().try_into()?,
                &topics::FEED.try_into()?,
                &Partitioning::balanced(),
                &mut feed_messages,
            ).await?;
        }
        
        Ok(())
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // POSITION EVENTS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn publish_jacked_in(&self, event: &JackedInEvent) -> Result<()> {
        let key = hex::encode(&event.user.0);
        self.publish(topics::POSITIONS, event, Some(&key), true).await
    }
    
    pub async fn publish_stake_added(&self, event: &StakeAddedEvent) -> Result<()> {
        let key = hex::encode(&event.user.0);
        self.publish(topics::POSITIONS, event, Some(&key), true).await
    }
    
    pub async fn publish_extracted(&self, event: &ExtractedEvent) -> Result<()> {
        let key = hex::encode(&event.user.0);
        self.publish(topics::POSITIONS, event, Some(&key), true).await
    }
    
    pub async fn publish_position_culled(&self, event: &PositionCulledEvent) -> Result<()> {
        let key = hex::encode(&event.victim.0);
        self.publish(topics::POSITIONS, event, Some(&key), true).await
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SCAN EVENTS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn publish_scan_executed(&self, event: &ScanExecutedEvent) -> Result<()> {
        let key = format!("{}", event.level as u8);
        self.publish(topics::SCANS, event, Some(&key), true).await
    }
    
    pub async fn publish_scan_finalized(&self, event: &ScanFinalizedEvent) -> Result<()> {
        let key = format!("{}", event.level as u8);
        self.publish(topics::SCANS, event, Some(&key), true).await
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DEATH EVENTS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn publish_deaths_processed(&self, event: &DeathsProcessedEvent) -> Result<()> {
        let key = format!("{}", event.level as u8);
        self.publish(topics::DEATHS, event, Some(&key), true).await
    }
    
    pub async fn publish_system_reset(&self, event: &SystemResetTriggeredEvent) -> Result<()> {
        self.publish(topics::DEATHS, event, None, true).await
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET EVENTS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn publish_round_created(&self, event: &RoundCreatedEvent) -> Result<()> {
        self.publish(topics::MARKETS, event, None, true).await
    }
    
    pub async fn publish_bet_placed(&self, event: &BetPlacedEvent) -> Result<()> {
        let key = hex::encode(&event.user.0);
        self.publish(topics::MARKETS, event, Some(&key), true).await
    }
    
    pub async fn publish_round_resolved(&self, event: &RoundResolvedEvent) -> Result<()> {
        self.publish(topics::MARKETS, event, None, true).await
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN EVENTS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn publish_transfer(&self, event: &TransferEvent) -> Result<()> {
        // Only publish large transfers to feed
        let large_threshold = "1000000000000000000000"; // 1000 DATA
        let include_in_feed = event.value.to_string() > large_threshold.to_string();
        
        let key = hex::encode(&event.from.0);
        self.publish(topics::TOKENS, event, Some(&key), include_in_feed).await
    }
    
    pub async fn publish_buyback(&self, event: &BuybackExecutedEvent) -> Result<()> {
        self.publish(topics::TOKENS, event, None, true).await
    }
}
```

### 15.4 WebSocket Consumer (src/api/websocket.rs)

```rust
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::Response,
};
use futures::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicU64, Ordering};
use tokio::sync::broadcast;
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use super::AppState;
use crate::error::Result;

/// Active WebSocket connection counter for metrics
static WS_CONNECTIONS: AtomicU64 = AtomicU64::new(0);

/// Client-to-server message types
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
enum ClientMessage {
    Subscribe { channels: Vec<String> },
    SubscribeUser { address: String },
    Unsubscribe { channels: Vec<String> },
    Ping,
}

/// Server-to-client message types
#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
enum ServerMessage {
    FeedEvent { event: serde_json::Value, timestamp: i64 },
    ConnectionState { status: &'static str },
    Pong,
    Error { message: String },
}

/// WebSocket handler that streams events from Iggy.
/// 
/// # Cancellation Safety
/// 
/// This handler is cancellation-safe. If the connection is dropped:
/// - The connection counter is decremented
/// - All spawned tasks are aborted
/// - No resources are leaked
pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> Response {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: AppState) {
    let (mut sender, mut receiver) = socket.split();
    
    // Generate unique client ID for logging/debugging
    let client_id = Uuid::new_v4();
    
    // Track connection
    let connection_count = WS_CONNECTIONS.fetch_add(1, Ordering::Relaxed) + 1;
    metrics::gauge!("websocket_connections").set(connection_count as f64);
    info!(client_id = %client_id, connections = connection_count, "WebSocket client connected");
    
    // Send connection confirmation
    let welcome = serde_json::to_string(&ServerMessage::ConnectionState { status: "connected" })
        .unwrap_or_default();
    if sender.send(Message::Text(welcome)).await.is_err() {
        decrement_connections();
        return;
    }
    
    // Subscribe to broadcast channel
    let mut event_rx = state.event_tx.subscribe();
    
    // Spawn task to forward events to WebSocket
    let send_task = tokio::spawn(async move {
        loop {
            match event_rx.recv().await {
                Ok(event) => {
                    let msg = Message::Text(event);
                    if sender.send(msg).await.is_err() {
                        break;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    warn!(client_id = %client_id, lagged = n, "Client lagging, skipped messages");
                    metrics::counter!("websocket_messages_lagged").increment(n);
                    // Continue - client will catch up
                }
                Err(broadcast::error::RecvError::Closed) => {
                    debug!(client_id = %client_id, "Broadcast channel closed");
                    break;
                }
            }
        }
    });
    
    // Handle incoming messages (for subscriptions, heartbeats)
    let recv_task = tokio::spawn(async move {
        while let Some(result) = receiver.next().await {
            match result {
                Ok(Message::Text(text)) => {
                    match serde_json::from_str::<ClientMessage>(&text) {
                        Ok(ClientMessage::Ping) => {
                            debug!(client_id = %client_id, "Received ping");
                            // Pong is handled automatically by axum for WebSocket ping frames
                        }
                        Ok(ClientMessage::Subscribe { channels }) => {
                            debug!(client_id = %client_id, ?channels, "Subscribe request");
                            // TODO: Implement per-channel filtering
                        }
                        Ok(ClientMessage::SubscribeUser { address }) => {
                            debug!(client_id = %client_id, address, "Subscribe to user");
                            // TODO: Implement user-specific filtering
                        }
                        Ok(ClientMessage::Unsubscribe { channels }) => {
                            debug!(client_id = %client_id, ?channels, "Unsubscribe request");
                        }
                        Err(e) => {
                            warn!(client_id = %client_id, error = ?e, "Invalid message format");
                        }
                    }
                }
                Ok(Message::Close(_)) => {
                    debug!(client_id = %client_id, "Client sent close frame");
                    break;
                }
                Ok(Message::Ping(_)) | Ok(Message::Pong(_)) => {
                    // Handled automatically by axum
                }
                Ok(Message::Binary(_)) => {
                    debug!(client_id = %client_id, "Ignoring binary message");
                }
                Err(e) => {
                    error!(client_id = %client_id, error = ?e, "WebSocket error");
                    metrics::counter!("websocket_errors").increment(1);
                    break;
                }
            }
        }
    });
    
    // Wait for either task to complete, then abort the other
    tokio::select! {
        _ = send_task => {
            // recv_task will be dropped and aborted
        },
        _ = recv_task => {
            // send_task will be dropped and aborted
        },
    }
    
    decrement_connections();
    info!(client_id = %client_id, "WebSocket client disconnected");
}

fn decrement_connections() {
    let count = WS_CONNECTIONS.fetch_sub(1, Ordering::Relaxed) - 1;
    metrics::gauge!("websocket_connections").set(count as f64);
}

/// Background task that polls Iggy and broadcasts to all WebSocket clients
pub async fn iggy_to_broadcast(
    iggy: &IggyClient,
    event_tx: broadcast::Sender<String>,
) -> Result<()> {
    let consumer = Consumer::new(1);  // Consumer ID
    let mut offset = 0u64;
    
    loop {
        let polled = iggy.poll_messages(
            &1u32.try_into()?,              // stream
            &"feed".try_into()?,            // topic
            Some(1),                         // partition
            &consumer,
            &PollingStrategy::offset(offset),
            100,                             // batch size
            false,                           // auto_commit
        ).await?;
        
        if polled.messages.is_empty() {
            tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            continue;
        }
        
        for message in &polled.messages {
            let payload = String::from_utf8_lossy(&message.payload);
            // Broadcast to all connected WebSocket clients
            let _ = event_tx.send(payload.to_string());
        }
        
        offset += polled.messages.len() as u64;
    }
}
```

---

## 16. In-Memory Caching

### 16.1 Cache Design

We use in-memory caching for hot data paths:

| Cache | Library | Purpose | TTL |
|-------|---------|---------|-----|
| Position cache | moka | Active positions by address | 5 minutes |
| Stats cache | moka | Level and global stats | 1 minute |
| Leaderboard cache | moka | Top 100 leaderboards | 5 minutes |
| Rate limiter | dashmap | Request counts per IP/user | Rolling window |

### 16.2 Cache Implementation (src/store/cache.rs)

```rust
use std::sync::Arc;
use std::time::Duration;

use dashmap::DashMap;
use moka::future::Cache;
use tracing::debug;

use crate::types::entities::{GlobalStats, LeaderboardEntry, LevelStats, Position};

/// In-memory cache for hot data
pub struct MemoryCache {
    /// Position cache by user address (hex string)
    positions: Cache<String, Option<Position>>,
    
    /// Level stats cache (5 entries)
    level_stats: Cache<i16, LevelStats>,
    
    /// Global stats cache (singleton)
    global_stats: Cache<(), GlobalStats>,
    
    /// Leaderboard cache by type
    leaderboards: Cache<String, Vec<LeaderboardEntry>>,
    
    /// Rate limiter: (identifier, window_start) -> count
    rate_limits: Arc<DashMap<String, (u64, u32)>>,
}

impl MemoryCache {
    pub fn new() -> Self {
        Self {
            positions: Cache::builder()
                .max_capacity(10_000)
                .time_to_live(Duration::from_secs(300))  // 5 minutes
                .build(),
            
            level_stats: Cache::builder()
                .max_capacity(5)
                .time_to_live(Duration::from_secs(60))   // 1 minute
                .build(),
            
            global_stats: Cache::builder()
                .max_capacity(1)
                .time_to_live(Duration::from_secs(60))   // 1 minute
                .build(),
            
            leaderboards: Cache::builder()
                .max_capacity(20)
                .time_to_live(Duration::from_secs(300))  // 5 minutes
                .build(),
            
            rate_limits: Arc::new(DashMap::new()),
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // POSITION CACHE
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn get_position(&self, address: &str) -> Option<Option<Position>> {
        self.positions.get(address).await
    }
    
    pub async fn set_position(&self, address: &str, position: Option<Position>) {
        self.positions.insert(address.to_string(), position).await;
        debug!(address, "Cached position");
    }
    
    pub async fn invalidate_position(&self, address: &str) {
        self.positions.invalidate(address).await;
        debug!(address, "Invalidated position cache");
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // STATS CACHE
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn get_level_stats(&self, level: i16) -> Option<LevelStats> {
        self.level_stats.get(&level).await
    }
    
    pub async fn set_level_stats(&self, stats: LevelStats) {
        self.level_stats.insert(stats.level as i16, stats).await;
    }
    
    pub async fn get_global_stats(&self) -> Option<GlobalStats> {
        self.global_stats.get(&()).await
    }
    
    pub async fn set_global_stats(&self, stats: GlobalStats) {
        self.global_stats.insert((), stats).await;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // LEADERBOARD CACHE
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub async fn get_leaderboard(&self, leaderboard_type: &str) -> Option<Vec<LeaderboardEntry>> {
        self.leaderboards.get(leaderboard_type).await
    }
    
    pub async fn set_leaderboard(&self, leaderboard_type: &str, entries: Vec<LeaderboardEntry>) {
        self.leaderboards.insert(leaderboard_type.to_string(), entries).await;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // RATE LIMITING
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Check and increment rate limit. Returns true if allowed.
    pub fn check_rate_limit(&self, key: &str, limit: u32, window_secs: u64) -> bool {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        
        let window_start = now - (now % window_secs);
        let cache_key = format!("{}:{}", key, window_start);
        
        let mut entry = self.rate_limits.entry(cache_key).or_insert((window_start, 0));
        
        if entry.0 != window_start {
            // New window
            *entry = (window_start, 1);
            true
        } else if entry.1 < limit {
            entry.1 += 1;
            true
        } else {
            false
        }
    }
    
    /// Clean up old rate limit entries
    pub fn cleanup_rate_limits(&self, max_age_secs: u64) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        
        let cutoff = now.saturating_sub(max_age_secs);
        
        self.rate_limits.retain(|_, (window_start, _)| *window_start > cutoff);
    }
}

impl Default for MemoryCache {
    fn default() -> Self {
        Self::new()
    }
}
```

---

## 17. Processing Architecture

### 17.1 Main Processing Loop

```rust
// src/indexer/block_processor.rs

use alloy::providers::Provider;
use alloy::rpc::types::{BlockNumberOrTag, Filter};
use std::time::Duration;
use tokio::sync::watch;
use tracing::{info, warn, error};

use crate::config::Settings;
use crate::error::{AppError, Result};
use crate::handlers::traits::*;
use crate::indexer::{EventRouter, ReorgHandler};
use crate::ports::{IndexerStateStore, EventPublisher};

/// Main indexer that processes blocks.
/// 
/// Generic over provider and storage implementations for testability.
pub struct BlockProcessor<P, S, R, Pub>
where
    P: Provider + Clone + Send + Sync + 'static,
    S: IndexerStateStore,
    R: Send + Sync,  // EventRouter with all handler bounds
    Pub: EventPublisher,
{
    provider: P,
    store: S,
    router: R,
    reorg_handler: ReorgHandler<S>,
    publisher: Pub,
    config: Settings,
}

impl<P, S, R, Pub> BlockProcessor<P, S, R, Pub>
where
    P: Provider + Clone + Send + Sync + 'static,
    S: IndexerStateStore,
    R: Send + Sync,
    Pub: EventPublisher,
{
    pub fn new(
        provider: P,
        store: S,
        router: R,
        reorg_handler: ReorgHandler<S>,
        publisher: Pub,
        config: Settings,
    ) -> Self {
        Self {
            provider,
            store,
            router,
            reorg_handler,
            publisher,
            config,
        }
    }
    
    /// Main processing loop with graceful shutdown support.
    /// 
    /// # Arguments
    /// 
    /// * `shutdown` - Watch channel that signals shutdown when value changes
    /// 
    /// # Cancellation Safety
    /// 
    /// This method supports graceful shutdown. When the shutdown signal is received:
    /// 1. Current block batch completes processing
    /// 2. Pending database writes are flushed
    /// 3. The method returns `Ok(())`
    /// 
    /// No data is lost during shutdown - the indexer can resume from the last
    /// checkpointed block.
    pub async fn run(&self, mut shutdown: watch::Receiver<()>) -> Result<()> {
        let mut last_block = self.store.get_last_block().await?;
        
        info!(last_block, "Starting block processor");
        
        loop {
            // Check for shutdown signal
            if shutdown.has_changed().unwrap_or(false) {
                info!("Shutdown signal received, completing current batch");
                break;
            }
            
            // Get current chain head
            let head = match self.provider.get_block_number().await {
                Ok(h) => h,
                Err(e) => {
                    error!(error = ?e, "Failed to get block number, retrying...");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                    continue;
                }
            };
            
            // Process blocks in batches
            while last_block < head {
                // Check shutdown between batches
                if shutdown.has_changed().unwrap_or(false) {
                    info!(last_block, "Shutdown during batch, saving checkpoint");
                    break;
                }
                let to_block = std::cmp::min(
                    last_block + self.config.batch_size,
                    head,
                );
                
                // Fetch logs for all contracts
                let filter = Filter::new()
                    .address(self.config.contract_addresses.clone())
                    .from_block(last_block + 1)
                    .to_block(to_block);
                
                let logs = self.provider.get_logs(&filter).await?;
                
                // Check for reorgs
                if let Some(fork_point) = self.check_reorg(last_block + 1).await? {
                    warn!(fork_point, "Handling chain reorg");
                    self.reorg_handler.handle_reorg(fork_point).await?;
                    last_block = fork_point - 1;
                    continue;
                }
                
                // Process each log
                for log in logs {
                    let meta = self.extract_metadata(&log).await?;
                    self.router.route_log(&log, meta).await?;
                }
                
                // Store block hash for reorg detection
                self.store_block_hash(to_block).await?;
                
                // Update checkpoint
                self.store.set_last_indexed_block(to_block).await?;
                last_block = to_block;
                
                // Update metrics
                metrics::counter!("indexer_blocks_processed_total").increment((to_block - last_block) as u64);
                metrics::gauge!("indexer_block_lag").set((head - to_block) as f64);
            }
            
            // Wait for new blocks, but allow shutdown to interrupt
            tokio::select! {
                _ = shutdown.changed() => {
                    info!("Shutdown signal received during wait");
                    break;
                }
                _ = tokio::time::sleep(Duration::from_millis(self.config.poll_interval_ms)) => {}
            }
        }
        
        info!(last_block, "Block processor shutdown complete");
        Ok(())
    }
    
    async fn check_reorg(&self, block: u64) -> Result<Option<u64>> {
        let block_data = self.provider
            .get_block_by_number(BlockNumberOrTag::Number(block), false)
            .await?;
        
        if let Some(block_data) = block_data {
            let parent_hash = block_data.header.parent_hash;
            self.reorg_handler.check_for_reorg(block, parent_hash.as_slice()).await
        } else {
            Ok(None)
        }
    }
    
    async fn extract_metadata(&self, log: &Log) -> Result<EventMetadata> {
        let block = self.provider
            .get_block_by_number(BlockNumberOrTag::Number(log.block_number.unwrap()), false)
            .await?
            .ok_or_else(|| anyhow::anyhow!("Block not found"))?;
        
        Ok(EventMetadata {
            block_number: log.block_number.unwrap(),
            block_hash: log.block_hash.unwrap(),
            tx_hash: log.transaction_hash.unwrap(),
            tx_index: log.transaction_index.unwrap(),
            log_index: log.log_index.unwrap(),
            timestamp: chrono::DateTime::from_timestamp(block.header.timestamp as i64, 0)
                .unwrap_or_default(),
            contract: log.address,
        })
    }
    
    async fn store_block_hash(&self, block_number: u64) -> Result<()> {
        let block = self.provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number), false)
            .await?
            .ok_or_else(|| anyhow::anyhow!("Block not found"))?;
        
        self.store.insert_block_history(
            block_number,
            block.header.hash.as_slice(),
            block.header.parent_hash.as_slice(),
            block.header.timestamp,
        ).await
    }
}
```

---

## 18. API Specification

### 18.1 REST Endpoints

#### Positions

```yaml
# Get active position by user address
GET /api/v1/positions/:address
Response: Position | null

# Get position history
GET /api/v1/positions/:address/history
Query:
  - limit: int (default 50, max 100)
  - offset: int (default 0)
Response: { events: PositionHistory[], total: int }

# Get all active positions
GET /api/v1/positions
Query:
  - level: int (optional, 1-5)
  - limit: int (default 100, max 1000)
  - offset: int (default 0)
Response: { positions: Position[], total: int }

# Get positions at risk of culling
GET /api/v1/positions/at-risk
Query:
  - level: int (required, 1-5)
  - threshold: int (bottom N positions, default 50)
Response: Position[]
```

#### Scans

```yaml
# Get recent scans
GET /api/v1/scans
Query:
  - level: int (optional, 1-5)
  - limit: int (default 20, max 100)
Response: Scan[]

# Get scan by ID
GET /api/v1/scans/:level/:scanId
Response: Scan

# Get next scan time for level
GET /api/v1/scans/:level/next
Response: { 
  level: int, 
  next_scan_at: timestamp, 
  seconds_remaining: int 
}

# Get deaths for a scan
GET /api/v1/scans/:level/:scanId/deaths
Query:
  - limit: int (default 100)
Response: Death[]
```

#### Deaths

```yaml
# Get recent deaths
GET /api/v1/deaths
Query:
  - level: int (optional, 1-5)
  - limit: int (default 50, max 100)
Response: Death[]

# Get user's death history
GET /api/v1/deaths/:address
Query:
  - limit: int (default 20)
Response: Death[]
```

#### Markets (DeadPool)

```yaml
# Get active rounds
GET /api/v1/rounds
Query:
  - type: string (optional: death_count, whale_death, streak_record, system_reset)
  - active_only: bool (default true)
  - limit: int (default 20)
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
  - limit: int (default 50)
Response: Bet[]

# Get odds for a round
GET /api/v1/rounds/:roundId/odds
Response: { 
  over_odds: float, 
  under_odds: float, 
  over_pool: string, 
  under_pool: string 
}
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
Response: { 
  total_burned: string, 
  tax_burned: string, 
  death_burned: string, 
  buyback_burned: string 
}

# Get death statistics by level
GET /api/v1/stats/deaths
Query:
  - period: string (day, week, month, all)
Response: { level: int, count: int, total_lost: string, avg_streak: float }[]
```

#### Leaderboards

```yaml
# Get ghost streak leaderboard
GET /api/v1/leaderboard/streak
Query:
  - limit: int (default 100, max 500)
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

# Get biggest losses
GET /api/v1/leaderboard/losses
Query:
  - limit: int (default 100)
  - period: string (all, month, week)
Response: { rank: int, address: string, total_lost: string, death_count: int }[]
```

### 18.2 API Server Setup (src/api/server.rs)

```rust
use axum::{
    extract::State,
    routing::{get, post},
    Router,
};
use std::sync::Arc;
use tokio::sync::broadcast;
use tower_http::{
    compression::CompressionLayer,
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::store::{MemoryCache, PostgresStore};
use crate::streaming::GhostnetIggy;

/// Shared application state
#[derive(Clone)]
pub struct AppState {
    pub store: PostgresStore,
    pub cache: Arc<MemoryCache>,
    pub event_tx: broadcast::Sender<String>,
}

/// Build the Axum router.
/// 
/// NOTE: Uses Axum 0.8+ syntax with {param} for path parameters.
pub fn build_router(state: AppState) -> Router {
    Router::new()
        // Positions
        .route("/api/v1/positions", get(handlers::list_positions))
        .route("/api/v1/positions/{address}", get(handlers::get_position))
        .route("/api/v1/positions/{address}/history", get(handlers::get_position_history))
        .route("/api/v1/positions/at-risk", get(handlers::get_at_risk_positions))
        
        // Scans
        .route("/api/v1/scans", get(handlers::list_scans))
        .route("/api/v1/scans/{level}/{scan_id}", get(handlers::get_scan))
        .route("/api/v1/scans/{level}/next", get(handlers::get_next_scan))
        .route("/api/v1/scans/{level}/{scan_id}/deaths", get(handlers::get_scan_deaths))
        
        // Deaths
        .route("/api/v1/deaths", get(handlers::list_deaths))
        .route("/api/v1/deaths/{address}", get(handlers::get_user_deaths))
        
        // Markets
        .route("/api/v1/rounds", get(handlers::list_rounds))
        .route("/api/v1/rounds/{round_id}", get(handlers::get_round))
        .route("/api/v1/rounds/{round_id}/bets", get(handlers::get_round_bets))
        .route("/api/v1/rounds/{round_id}/odds", get(handlers::get_round_odds))
        .route("/api/v1/bets/{address}", get(handlers::get_user_bets))
        
        // Analytics
        .route("/api/v1/stats", get(handlers::get_global_stats))
        .route("/api/v1/stats/levels", get(handlers::get_level_stats))
        .route("/api/v1/stats/tvl/history", get(handlers::get_tvl_history))
        .route("/api/v1/stats/burns", get(handlers::get_burn_stats))
        .route("/api/v1/stats/deaths", get(handlers::get_death_stats))
        
        // Leaderboards
        .route("/api/v1/leaderboard/streak", get(handlers::get_streak_leaderboard))
        .route("/api/v1/leaderboard/earnings", get(handlers::get_earnings_leaderboard))
        .route("/api/v1/leaderboard/survivors", get(handlers::get_survivors_leaderboard))
        .route("/api/v1/leaderboard/losses", get(handlers::get_losses_leaderboard))
        
        // WebSocket
        .route("/ws", get(websocket::websocket_handler))
        
        // Health (Kubernetes probes)
        .route("/health", get(handlers::liveness))
        .route("/health/live", get(handlers::liveness))
        .route("/health/ready", get(handlers::readiness))
        .route("/health/startup", get(handlers::startup))
        
        // Metrics
        .route("/metrics", get(handlers::metrics))
        
        // Middleware (order matters: bottom-to-top for requests)
        .layer(TraceLayer::new_for_http())
        .layer(CompressionLayer::new())
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state)
}
```

---

## 19. WebSocket Protocol

### 19.1 Connection

```
URL: wss://api.ghostnet.gg/ws
```

### 19.2 Message Types

#### Server → Client

```typescript
// Feed event (most common)
{
  type: "FEED_EVENT",
  event: {
    type: "JACK_IN" | "EXTRACTED" | "TRACED" | "SCAN_EXECUTED" | ...,
    data: { ... },
    timestamp: 1705790400000
  }
}

// Position update (for subscribed user)
{
  type: "POSITION_UPDATE",
  position: { ... }
}

// Scan warning
{
  type: "SCAN_WARNING",
  level: 4,
  seconds_until: 60
}

// Connection state
{
  type: "CONNECTION_STATE",
  status: "connected" | "reconnecting" | "error"
}
```

#### Client → Server

```typescript
// Subscribe to specific events
{
  type: "SUBSCRIBE",
  channels: ["positions", "scans", "deaths", "markets"]
}

// Subscribe to specific user's events
{
  type: "SUBSCRIBE_USER",
  address: "0x..."
}

// Unsubscribe
{
  type: "UNSUBSCRIBE",
  channels: ["deaths"]
}

// Ping (keepalive)
{
  type: "PING"
}
```

### 19.3 Event Types for Feed

| Event Type | Description | Data |
|------------|-------------|------|
| `JACK_IN` | User entered position | user, amount, level |
| `STAKE_ADDED` | User added to position | user, amount, new_total |
| `EXTRACTED` | User extracted | user, amount, rewards |
| `POSITION_CULLED` | Position culled | victim, penalty, new_entrant |
| `SCAN_EXECUTED` | Scan started | level, scan_id |
| `DEATHS_PROCESSED` | Deaths processed | level, count, total_lost |
| `SCAN_FINALIZED` | Scan completed | level, deaths, survivors |
| `SYSTEM_RESET` | System reset triggered | total_penalty, jackpot_winner |
| `ROUND_CREATED` | New betting round | round_id, type, deadline |
| `BET_PLACED` | Bet placed | round_id, user, amount, is_over |
| `ROUND_RESOLVED` | Round resolved | round_id, outcome, total_pot |
| `LARGE_TRANSFER` | Whale transfer | from, to, amount |
| `BUYBACK` | Buyback executed | eth_spent, data_burned |

---

## 20. Deployment

### 20.1 Environment Variables

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
# DATABASE (TimescaleDB)
# ═══════════════════════════════════════════════════════════════════════════════
DATABASE_URL=postgres://ghostnet:password@localhost:5432/ghostnet_indexer
DATABASE_MAX_CONNECTIONS=20

# ═══════════════════════════════════════════════════════════════════════════════
# STREAMING (Apache Iggy)
# ═══════════════════════════════════════════════════════════════════════════════
IGGY_ADDRESS=localhost:8090
IGGY_USERNAME=iggy
IGGY_PASSWORD=iggy

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

### 20.2 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  # ═══════════════════════════════════════════════════════════════════════════
  # TIMESCALEDB
  # ═══════════════════════════════════════════════════════════════════════════
  timescaledb:
    image: timescale/timescaledb:latest-pg16
    container_name: ghostnet-timescaledb
    environment:
      POSTGRES_USER: ghostnet
      POSTGRES_PASSWORD: ${DB_PASSWORD:-password}
      POSTGRES_DB: ghostnet_indexer
    volumes:
      - timescaledb_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ghostnet -d ghostnet_indexer"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ═══════════════════════════════════════════════════════════════════════════
  # APACHE IGGY
  # ═══════════════════════════════════════════════════════════════════════════
  iggy:
    image: apache/iggy:latest
    container_name: ghostnet-iggy
    ports:
      - "8090:8090"  # TCP
      - "8091:8080"  # HTTP/WebSocket
    cap_add:
      - SYS_NICE
    security_opt:
      - seccomp:unconfined
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - iggy_data:/data
    environment:
      IGGY_ROOT_USERNAME: iggy
      IGGY_ROOT_PASSWORD: ${IGGY_PASSWORD:-iggy}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ═══════════════════════════════════════════════════════════════════════════
  # INDEXER SERVICE
  # ═══════════════════════════════════════════════════════════════════════════
  indexer:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ghostnet-indexer
    environment:
      DATABASE_URL: postgres://ghostnet:${DB_PASSWORD:-password}@timescaledb:5432/ghostnet_indexer
      IGGY_ADDRESS: iggy:8090
      IGGY_USERNAME: iggy
      IGGY_PASSWORD: ${IGGY_PASSWORD:-iggy}
      RPC_URL: ${RPC_URL}
      LOG_LEVEL: info
      API_HOST: 0.0.0.0
      API_PORT: 8080
    ports:
      - "8080:8080"   # API
      - "9090:9090"   # Metrics
    depends_on:
      timescaledb:
        condition: service_healthy
      iggy:
        condition: service_healthy
    restart: unless-stopped

volumes:
  timescaledb_data:
  iggy_data:
```

### 20.3 Dockerfile

```dockerfile
# Dockerfile

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD STAGE
# ═══════════════════════════════════════════════════════════════════════════════

FROM rust:1.85-bookworm AS builder

WORKDIR /app

# Install mold linker for faster builds
RUN apt-get update && apt-get install -y mold clang && rm -rf /var/lib/apt/lists/*

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY .cargo .cargo

# Create dummy main.rs to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies
RUN cargo build --release

# Remove dummy and copy real source
RUN rm -rf src
COPY src ./src
COPY migrations ./migrations

# Build real application
RUN touch src/main.rs && cargo build --release

# ═══════════════════════════════════════════════════════════════════════════════
# RUNTIME STAGE
# ═══════════════════════════════════════════════════════════════════════════════

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/ghostnet-indexer /usr/local/bin/
COPY --from=builder /app/migrations /app/migrations

WORKDIR /app

ENV RUST_LOG=info
ENV RUST_BACKTRACE=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["ghostnet-indexer"]
CMD ["run"]
```

---

## 21. Monitoring & Observability

### 21.1 Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `indexer_blocks_processed_total` | Counter | Total blocks processed |
| `indexer_events_processed_total` | Counter | Events by type |
| `indexer_block_lag` | Gauge | Blocks behind chain head |
| `indexer_reorgs_total` | Counter | Chain reorgs detected |
| `api_requests_total` | Counter | API requests by endpoint |
| `api_request_duration_seconds` | Histogram | Request latency |
| `websocket_connections` | Gauge | Active WebSocket connections |
| `db_query_duration_seconds` | Histogram | Database query latency |
| `iggy_messages_published_total` | Counter | Messages sent to Iggy |
| `cache_hits_total` | Counter | Cache hits by cache type |
| `cache_misses_total` | Counter | Cache misses by cache type |

### 21.2 Structured Logging

```rust
// Example log output (JSON format)
{
  "timestamp": "2026-01-20T15:30:00.000Z",
  "level": "INFO",
  "target": "ghostnet_indexer::handlers::position",
  "message": "Processed JackedIn event",
  "fields": {
    "user": "0x7a3f...9c2d",
    "amount": "500000000000000000000",
    "level": 4,
    "block": 12345678,
    "processing_time_ms": 12
  }
}
```

### 21.3 Health Checks

```rust
// GET /health - Basic liveness
{
  "status": "healthy",
  "version": "0.1.0",
  "uptime_secs": 3600
}

// GET /health/ready - Detailed readiness
{
  "status": "ready",
  "checks": {
    "database": { "status": "healthy", "latency_ms": 2 },
    "iggy": { "status": "healthy", "latency_ms": 1 },
    "rpc": { "status": "healthy", "latency_ms": 45 }
  },
  "indexer": {
    "last_block": 12345678,
    "chain_head": 12345680,
    "lag": 2
  }
}
```

### 21.4 Alerting Rules

| Condition | Severity | Action |
|-----------|----------|--------|
| `indexer_block_lag > 100` | Critical | Page on-call |
| `api_request_duration_seconds{p99} > 0.5` | Warning | Slack alert |
| `indexer_reorgs_total increase > 5/hour` | Warning | Investigate |
| `websocket_connections > 10000` | Warning | Scale up |
| `db_query_duration_seconds{p99} > 0.2` | Warning | Optimize queries |

---

## 22. Security

### 22.1 API Security

| Measure | Implementation |
|---------|----------------|
| **Rate Limiting** | In-memory counters, 100 req/min unauthenticated |
| **Input Validation** | All inputs validated with serde |
| **SQL Injection** | Parameterized queries via SQLx |
| **CORS** | Configurable allowed origins |
| **Request Size** | Max 1MB body size |

### 22.2 Secrets Management

| Secret | Storage | Access |
|--------|---------|--------|
| Database password | Environment variable | Kubernetes secrets |
| Iggy credentials | Environment variable | Kubernetes secrets |
| RPC URL | Environment variable | Kubernetes secrets |

### 22.3 Network Security

- TimescaleDB: Internal network only, no public exposure
- Iggy: Internal network only
- API: Public via load balancer with TLS termination
- Metrics: Internal network only

---

## 23. Testing Strategy

### 23.1 Test Categories

| Category | Purpose | Tools | Location |
|----------|---------|-------|----------|
| **Unit Tests** | Test individual functions/methods | Standard Rust tests | `src/**/*.rs` |
| **Integration Tests** | Test component interactions | testcontainers | `tests/` |
| **Property Tests** | Test invariants with random input | proptest | `tests/property/` |
| **E2E Tests** | Test full request/response cycle | reqwest + testcontainers | `tests/e2e/` |

### 23.2 Unit Test Patterns

Use mock implementations of port traits:

```rust
// tests/common/mocks.rs

use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Mutex;

use ghostnet_indexer::ports::*;
use ghostnet_indexer::types::entities::*;
use ghostnet_indexer::error::Result;

/// Mock position store for testing
#[derive(Default)]
pub struct MockPositionStore {
    positions: Mutex<HashMap<Vec<u8>, Position>>,
    history: Mutex<Vec<PositionHistoryEntry>>,
}

#[async_trait]
impl PositionStore for MockPositionStore {
    async fn get_active_position(&self, address: &[u8]) -> Result<Option<Position>> {
        Ok(self.positions.lock().unwrap().get(address).cloned())
    }
    
    async fn save_position(&self, position: &Position) -> Result<()> {
        self.positions.lock().unwrap()
            .insert(position.user_address.clone(), position.clone());
        Ok(())
    }
    
    async fn get_at_risk_positions(&self, _level: Level, _threshold: u32) -> Result<Vec<Position>> {
        Ok(vec![])
    }
    
    async fn record_history(&self, entry: &PositionHistoryEntry) -> Result<()> {
        self.history.lock().unwrap().push(entry.clone());
        Ok(())
    }
}

impl MockPositionStore {
    pub fn with_position(position: Position) -> Self {
        let store = Self::default();
        store.positions.lock().unwrap()
            .insert(position.user_address.clone(), position);
        store
    }
    
    pub fn get_history(&self) -> Vec<PositionHistoryEntry> {
        self.history.lock().unwrap().clone()
    }
}

/// Mock event publisher that captures published events
#[derive(Default)]
pub struct MockEventPublisher {
    events: Mutex<Vec<GhostnetEvent>>,
}

#[async_trait]
impl EventPublisher for MockEventPublisher {
    async fn publish(&self, event: &GhostnetEvent) -> Result<()> {
        self.events.lock().unwrap().push(event.clone());
        Ok(())
    }
    
    async fn publish_to_topic(&self, _topic: &str, _payload: &[u8]) -> Result<()> {
        Ok(())
    }
}

impl MockEventPublisher {
    pub fn get_events(&self) -> Vec<GhostnetEvent> {
        self.events.lock().unwrap().clone()
    }
}
```

### 23.3 Integration Tests with Testcontainers

```rust
// tests/integration/position_handler_test.rs

use testcontainers::{clients::Cli, Container};
use testcontainers_modules::postgres::Postgres;
use sqlx::PgPool;

use ghostnet_indexer::handlers::PositionHandler;
use ghostnet_indexer::store::PostgresPositionStore;

struct TestContext<'a> {
    _container: Container<'a, Postgres>,
    pool: PgPool,
}

impl<'a> TestContext<'a> {
    async fn new(docker: &'a Cli) -> Self {
        let container = docker.run(Postgres::default());
        let port = container.get_host_port_ipv4(5432);
        
        let url = format!("postgres://postgres:postgres@localhost:{}/postgres", port);
        let pool = PgPool::connect(&url).await.unwrap();
        
        // Run migrations
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        
        Self {
            _container: container,
            pool,
        }
    }
}

#[tokio::test]
async fn test_position_handler_jacked_in() {
    let docker = Cli::default();
    let ctx = TestContext::new(&docker).await;
    
    let store = PostgresPositionStore::new(ctx.pool.clone());
    let publisher = MockEventPublisher::default();
    let clock = FakeClock::new(Utc::now());
    
    let handler = PositionHandler::new(store, publisher, clock);
    
    // Create test event
    let event = ghost_core::JackedIn {
        user: Address::from([0x42; 20]),
        amount: U256::from(1000),
        level: 3,
        newTotal: U256::from(1000),
    };
    
    let meta = EventMetadata {
        block_number: 100,
        block_hash: B256::ZERO,
        tx_hash: B256::ZERO,
        tx_index: 0,
        log_index: 0,
        timestamp: Utc::now(),
        contract: Address::ZERO,
    };
    
    // Execute
    handler.handle_jacked_in(event, meta).await.unwrap();
    
    // Verify
    let position = handler.store.get_active_position(&[0x42; 20]).await.unwrap();
    assert!(position.is_some());
    let pos = position.unwrap();
    assert_eq!(pos.level, Level::Subnet);
    assert!(pos.is_alive);
}
```

### 23.4 Property-Based Testing

```rust
// tests/property/level_tests.rs

use proptest::prelude::*;
use ghostnet_indexer::types::enums::Level;

proptest! {
    #[test]
    fn level_roundtrip(value in 0u8..=5) {
        if let Ok(level) = Level::try_from(value) {
            assert_eq!(level as u8, value);
        }
    }
    
    #[test]
    fn invalid_levels_rejected(value in 6u8..=255) {
        assert!(Level::try_from(value).is_err());
    }
    
    #[test]
    fn death_rate_in_bounds(value in 1u8..=5) {
        let level = Level::try_from(value).unwrap();
        let rate = level.death_rate_bps();
        assert!(rate <= 10000, "Death rate should be <= 100%");
    }
}
```

### 23.5 E2E API Tests

```rust
// tests/e2e/api_tests.rs

use axum::http::StatusCode;
use reqwest::Client;
use serde_json::json;

#[tokio::test]
async fn test_get_position_not_found() {
    let app = spawn_test_app().await;
    let client = Client::new();
    
    let response = client
        .get(&format!("{}/api/v1/positions/0x1234567890abcdef", app.address))
        .send()
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
    
    let body: serde_json::Value = response.json().await.unwrap();
    assert_eq!(body["error"]["code"], "NOT_FOUND");
}

#[tokio::test]
async fn test_health_endpoints() {
    let app = spawn_test_app().await;
    let client = Client::new();
    
    // Liveness
    let response = client
        .get(&format!("{}/health/live", app.address))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    
    // Readiness
    let response = client
        .get(&format!("{}/health/ready", app.address))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}
```

### 23.6 Test Data Builders

```rust
// tests/common/builders.rs

use ghostnet_indexer::types::entities::*;
use ghostnet_indexer::types::enums::*;
use chrono::Utc;
use uuid::Uuid;

pub struct PositionBuilder {
    position: Position,
}

impl PositionBuilder {
    pub fn new() -> Self {
        Self {
            position: Position {
                id: Uuid::new_v4(),
                user_address: vec![0x42; 20],
                level: Level::Subnet,
                amount: "1000000000000000000".to_string(),
                reward_debt: "0".to_string(),
                entry_timestamp: Utc::now(),
                last_add_timestamp: None,
                ghost_streak: 0,
                is_alive: true,
                is_extracted: false,
                exit_reason: None,
                exit_timestamp: None,
                extracted_amount: None,
                extracted_rewards: None,
                created_at_block: 100,
                updated_at: Utc::now(),
            },
        }
    }
    
    pub fn with_level(mut self, level: Level) -> Self {
        self.position.level = level;
        self
    }
    
    pub fn with_amount(mut self, amount: &str) -> Self {
        self.position.amount = amount.to_string();
        self
    }
    
    pub fn with_streak(mut self, streak: i32) -> Self {
        self.position.ghost_streak = streak;
        self
    }
    
    pub fn dead(mut self) -> Self {
        self.position.is_alive = false;
        self.position.exit_reason = Some(ExitReason::Traced);
        self.position.exit_timestamp = Some(Utc::now());
        self
    }
    
    pub fn build(self) -> Position {
        self.position
    }
}
```

### 23.7 Test Configuration

```toml
# Cargo.toml - dev-dependencies section
[dev-dependencies]
tokio-test = "0.4"
wiremock = "0.6"
testcontainers = "0.23"
testcontainers-modules = { version = "0.11", features = ["postgres"] }
criterion = { version = "0.5", features = ["async_tokio"] }
proptest = "1"
fake = { version = "2.9", features = ["chrono", "uuid"] }
```

---

## 24. Configuration Validation

### 24.1 Settings with Validation (src/config/settings.rs)

```rust
use serde::Deserialize;
use std::time::Duration;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("missing required field: {0}")]
    Missing(&'static str),
    
    #[error("invalid value for {field}: {reason}")]
    Invalid { field: &'static str, reason: String },
    
    #[error("file error: {0}")]
    File(#[from] std::io::Error),
    
    #[error("parse error: {0}")]
    Parse(#[from] config::ConfigError),
}

/// Application settings with validation.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]  // Catch typos in config files
pub struct Settings {
    pub rpc: RpcSettings,
    pub database: DatabaseSettings,
    pub iggy: IggySettings,
    pub api: ApiSettings,
    pub indexer: IndexerSettings,
    
    #[serde(default)]
    pub logging: LoggingSettings,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RpcSettings {
    pub url: String,
    
    #[serde(default = "default_chain_id")]
    pub chain_id: u64,
    
    #[serde(default = "default_start_block")]
    pub start_block: u64,
}

fn default_chain_id() -> u64 { 6342 }  // MegaETH
fn default_start_block() -> u64 { 0 }

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DatabaseSettings {
    pub url: String,
    
    #[serde(default = "default_max_connections")]
    pub max_connections: u32,
    
    #[serde(default = "default_min_connections")]
    pub min_connections: u32,
    
    #[serde(default, with = "humantime_serde")]
    pub acquire_timeout: Option<Duration>,
}

fn default_max_connections() -> u32 { 20 }
fn default_min_connections() -> u32 { 5 }

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct IggySettings {
    pub address: String,
    pub username: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ApiSettings {
    #[serde(default = "default_host")]
    pub host: String,
    
    #[serde(default = "default_port")]
    pub port: u16,
    
    #[serde(default)]
    pub cors_origins: Vec<String>,
}

fn default_host() -> String { "0.0.0.0".to_string() }
fn default_port() -> u16 { 8080 }

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct IndexerSettings {
    #[serde(default = "default_poll_interval")]
    pub poll_interval_ms: u64,
    
    #[serde(default = "default_batch_size")]
    pub batch_size: u64,
    
    #[serde(default = "default_reorg_depth")]
    pub reorg_depth: u64,
    
    pub contracts: ContractAddresses,
}

fn default_poll_interval() -> u64 { 1000 }
fn default_batch_size() -> u64 { 100 }
fn default_reorg_depth() -> u64 { 64 }

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContractAddresses {
    pub data_token: String,
    pub ghost_core: String,
    pub trace_scan: String,
    pub dead_pool: String,
    pub fee_router: String,
    pub rewards_distributor: String,
}

#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LoggingSettings {
    #[serde(default = "default_log_level")]
    pub level: String,
    
    #[serde(default)]
    pub format: LogFormat,
}

fn default_log_level() -> String { "info".to_string() }

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LogFormat {
    #[default]
    Json,
    Pretty,
}

impl Settings {
    /// Load settings from config files and environment.
    pub fn load() -> Result<Self, ConfigError> {
        let env = std::env::var("APP_ENV").unwrap_or_else(|_| "development".to_string());
        
        let settings: Settings = config::Config::builder()
            // Layer 1: Defaults
            .add_source(config::File::with_name("config/default").required(false))
            // Layer 2: Environment-specific
            .add_source(config::File::with_name(&format!("config/{}", env)).required(false))
            // Layer 3: Local overrides (gitignored)
            .add_source(config::File::with_name("config/local").required(false))
            // Layer 4: Environment variables
            .add_source(
                config::Environment::with_prefix("GHOSTNET")
                    .separator("__")
                    .try_parsing(true)
            )
            .build()?
            .try_deserialize()?;
        
        settings.validate()?;
        
        Ok(settings)
    }
    
    /// Validate settings after loading.
    pub fn validate(&self) -> Result<(), ConfigError> {
        // Validate RPC URL
        if self.rpc.url.is_empty() {
            return Err(ConfigError::Missing("rpc.url"));
        }
        if !self.rpc.url.starts_with("http://") && !self.rpc.url.starts_with("https://") {
            return Err(ConfigError::Invalid {
                field: "rpc.url",
                reason: "must start with http:// or https://".to_string(),
            });
        }
        
        // Validate database URL
        if self.database.url.is_empty() {
            return Err(ConfigError::Missing("database.url"));
        }
        if !self.database.url.starts_with("postgres://") {
            return Err(ConfigError::Invalid {
                field: "database.url",
                reason: "must start with postgres://".to_string(),
            });
        }
        
        // Validate connection pool
        if self.database.max_connections == 0 {
            return Err(ConfigError::Invalid {
                field: "database.max_connections",
                reason: "must be > 0".to_string(),
            });
        }
        if self.database.min_connections > self.database.max_connections {
            return Err(ConfigError::Invalid {
                field: "database.min_connections",
                reason: "cannot exceed max_connections".to_string(),
            });
        }
        
        // Validate Iggy settings
        if self.iggy.address.is_empty() {
            return Err(ConfigError::Missing("iggy.address"));
        }
        
        // Validate API port
        if self.api.port == 0 {
            return Err(ConfigError::Invalid {
                field: "api.port",
                reason: "must be > 0".to_string(),
            });
        }
        
        // Validate indexer settings
        if self.indexer.batch_size == 0 {
            return Err(ConfigError::Invalid {
                field: "indexer.batch_size",
                reason: "must be > 0".to_string(),
            });
        }
        
        // Validate contract addresses are valid hex
        self.validate_address("contracts.data_token", &self.indexer.contracts.data_token)?;
        self.validate_address("contracts.ghost_core", &self.indexer.contracts.ghost_core)?;
        self.validate_address("contracts.trace_scan", &self.indexer.contracts.trace_scan)?;
        self.validate_address("contracts.dead_pool", &self.indexer.contracts.dead_pool)?;
        self.validate_address("contracts.fee_router", &self.indexer.contracts.fee_router)?;
        
        Ok(())
    }
    
    fn validate_address(&self, field: &'static str, address: &str) -> Result<(), ConfigError> {
        if address.is_empty() {
            return Err(ConfigError::Missing(field));
        }
        if !address.starts_with("0x") || address.len() != 42 {
            return Err(ConfigError::Invalid {
                field,
                reason: "must be a 42-character hex address starting with 0x".to_string(),
            });
        }
        if hex::decode(&address[2..]).is_err() {
            return Err(ConfigError::Invalid {
                field,
                reason: "invalid hex characters".to_string(),
            });
        }
        Ok(())
    }
}
```

---

## 25. Implementation Checklist

### Phase 1: Project Setup
- [ ] Initialize Rust project with `cargo init`
- [ ] Add `Cargo.toml` with dependencies
- [ ] Add `rust-toolchain.toml`, `rustfmt.toml`, `deny.toml`
- [ ] Add `.cargo/config.toml`
- [ ] Create `config/` directory with TOML configs
- [ ] Create `.env.example`

### Phase 2: Foundation
- [ ] Implement `src/config/` - Settings and contract addresses
- [ ] Implement `src/types/enums.rs` - Level, BoostType, RoundType
- [ ] Implement `src/types/events.rs` - All event structs
- [ ] Implement `src/types/entities.rs` - Position, Scan, Death, etc.
- [ ] Implement `src/abi/` - ABI bindings with `alloy-sol-types`

### Phase 3: Database
- [ ] Create `migrations/00001_enable_timescaledb.sql`
- [ ] Create `migrations/00002_indexer_state.sql`
- [ ] Create `migrations/00003_positions.sql`
- [ ] Create `migrations/00004_scans.sql`
- [ ] Create `migrations/00005_markets.sql`
- [ ] Create `migrations/00006_analytics.sql`
- [ ] Create `migrations/00007_continuous_aggregates.sql`
- [ ] Create `migrations/00008_retention_policies.sql`
- [ ] Implement `src/store/postgres.rs` - SQLx store

### Phase 4: Indexer Core
- [ ] Implement `src/indexer/block_processor.rs`
- [ ] Implement `src/indexer/log_decoder.rs`
- [ ] Implement `src/indexer/event_router.rs`
- [ ] Implement `src/indexer/reorg_handler.rs`
- [ ] Implement `src/indexer/checkpoint.rs`

### Phase 5: Event Handlers
- [ ] Implement `src/handlers/position_handler.rs`
- [ ] Implement `src/handlers/scan_handler.rs`
- [ ] Implement `src/handlers/death_handler.rs`
- [ ] Implement `src/handlers/market_handler.rs`
- [ ] Implement `src/handlers/token_handler.rs`
- [ ] Implement `src/handlers/fee_handler.rs`

### Phase 6: Streaming (Iggy)
- [ ] Implement `src/streaming/iggy.rs` - Client wrapper
- [ ] Implement `src/streaming/publisher.rs` - Event publishing
- [ ] Implement `src/streaming/topics.rs` - Topic definitions
- [ ] Create Iggy initialization script

### Phase 7: Caching
- [ ] Implement `src/store/cache.rs` - moka + dashmap

### Phase 8: API Layer
- [ ] Implement `src/api/server.rs` - Axum setup
- [ ] Implement `src/api/routes/positions.rs`
- [ ] Implement `src/api/routes/scans.rs`
- [ ] Implement `src/api/routes/markets.rs`
- [ ] Implement `src/api/routes/analytics.rs`
- [ ] Implement `src/api/routes/leaderboards.rs`
- [ ] Implement `src/api/websocket.rs`
- [ ] Implement `src/api/middleware.rs`

### Phase 9: Observability
- [ ] Implement `src/utils/metrics.rs` - Prometheus
- [ ] Implement `src/utils/logging.rs` - Structured logging
- [ ] Implement `src/utils/health.rs` - Health checks

### Phase 10: Entry Point
- [ ] Implement `src/main.rs` - CLI with clap
- [ ] Implement `src/lib.rs` - Library exports

### Phase 11: Testing
- [ ] Unit tests for handlers
- [ ] Integration tests with testcontainers
- [ ] Load testing scripts

### Phase 12: Deployment
- [ ] Create `Dockerfile`
- [ ] Create `docker-compose.yml`
- [ ] Create Kubernetes manifests
- [ ] CI/CD pipeline

---

## Appendix A: Event Signature Hashes

Event signature hashes are computed at compile time by `alloy-sol-types`. For reference:

```
JackedIn(address,uint256,uint8,uint256)         → keccak256(...)
Extracted(address,uint256,uint256)              → keccak256(...)
Transfer(address,address,uint256)               → 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
```

---

## Appendix B: References

- [TimescaleDB Documentation](https://docs.timescale.com)
- [Apache Iggy Documentation](https://iggy.apache.org/docs)
- [Alloy Documentation](https://alloy.rs)
- [Axum Documentation](https://docs.rs/axum)
- [SQLx Documentation](https://docs.rs/sqlx)
- [GHOSTNET Smart Contracts](../../packages/contracts/)
- [TimescaleDB Advanced Guide](./timescaledb-advanced.md)

---

*This document should be updated as implementation progresses and decisions are made.*
