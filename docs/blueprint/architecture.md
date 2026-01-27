---
type: blueprint-architecture
updated: 2026-01-27
tags:
  - type/blueprint
  - blueprint/architecture
---

# Architecture

## Executive Summary

GHOSTNET is a real-time survival game deployed on MegaETH where players stake $DATA tokens into one of five risk levels, earn yield, and face periodic "trace scans" that can wipe positions. The system operates as a three-component architecture: a SvelteKit web application provides the player interface, Solidity smart contracts on MegaETH serve as the source of truth for all financial state, and a Rust-based indexer bridges the two by projecting chain events into queryable state and real-time feeds.

The architecture optimizes for **sub-500ms event latency** to deliver the dopamine-driven experience the game requires. MegaETH's 10ms block times enable real-time gameplay mechanics that wouldn't be possible on slower chains. The design follows a strict principle: **contracts are truth, everything else is derived**. The indexer can be rebuilt from chain history; if it disagrees with on-chain state, the indexer is wrong.

The system is structured as a monorepo with clear boundaries: `apps/web` for the frontend, `packages/contracts` for Solidity, and `services/` for Rust backend services. Each component can evolve independently while maintaining well-defined interfaces through contract events and REST/WebSocket APIs.

---

## System Classification

| Attribute | Value |
|-----------|-------|
| **Type** | Monorepo Application (Web + Contracts + Services) |
| **Architecture Style** | Event-Driven with On-Chain Source of Truth |
| **Primary Patterns** | Event Sourcing (contracts), Share-Based Accounting (rewards), Hexagonal (indexer) |
| **Scale Tier** | Multi-instance (horizontally scalable indexer and API) |

---

## System Context

### What's Inside vs. Outside

```
                           EXTERNAL ACTORS
    +------------------------------------------------------------------+
    |                                                                   |
    |   [Players]          [Keepers/Bots]         [Admin Multisig]     |
    |       |                    |                       |              |
    +-------|--------------------|-----------------------|--------------+
            |                    |                       |
            v                    v                       v
+===========================================================================+
||                         GHOSTNET SYSTEM BOUNDARY                        ||
||                                                                         ||
||  +-------------------------------------------------------------------+  ||
||  |                      WEB APP (SvelteKit)                          |  ||
||  |                                                                   |  ||
||  |   - Wallet connect/disconnect                                     |  ||
||  |   - Jack In / Extract UI                                          |  ||
||  |   - Live feed + timers                                            |  ||
||  |   - Position display                                              |  ||
||  |   - Mini-games (typing)                                           |  ||
||  +---------------------------+---------------------------------------+  ||
||                              |                                          ||
||          (tx writes)         |            (event stream)                ||
||              |               |                   |                      ||
||              v               |                   v                      ||
||  +-----------------------+   |   +-------------------------------+      ||
||  |    SMART CONTRACTS    |   |   |          INDEXER              |      ||
||  |      (MegaETH)        |<--|-->|          (Rust)               |      ||
||  |                       |   |   |                               |      ||
||  |   DataToken (ERC20)   |   |   |   - Block processor           |      ||
||  |   GhostCore (game)    |   |   |   - Event handlers            |      ||
||  |   TraceScan (scans)   |   |   |   - TimescaleDB persistence   |      ||
||  |   DeadPool (betting)  |   |   |   - WebSocket streaming       |      ||
||  +-----------------------+   |   +-------------------------------+      ||
||              |               |                   |                      ||
||              v               |                   v                      ||
||  +-----------------------+   |   +-------------------------------+      ||
||  |     MegaETH Chain     |   |   |       TimescaleDB             |      ||
||  |   (10ms blocks)       |   |   |       Apache Iggy             |      ||
||  +-----------------------+   |   +-------------------------------+      ||
||                                                                         ||
+===========================================================================+
            |                    |                       |
            v                    v                       v
    +------------------------------------------------------------------+
    |                     EXTERNAL DEPENDENCIES                         |
    |                                                                   |
    |   [MegaETH RPC]      [Gelato Automate]      [DEX (Bronto)]       |
    |   (chain access)     (keeper network)       (token swaps)        |
    +------------------------------------------------------------------+
```

### External Actors

| Actor | Interaction | Protocol | Volume |
|-------|-------------|----------|--------|
| **Players** | Stake, extract, play mini-games, view feed | Web UI + Wallet RPC | Hundreds/day |
| **Keepers/Bots** | Execute scans, submit death batches | Direct contract calls | Per scan interval |
| **Admin Multisig** | Upgrade contracts, configure parameters | Timelock + Multisig | Rare |
| **MegaETH RPC** | Read/write blockchain state | JSON-RPC over HTTP/WS | Continuous |
| **Gelato Automate** | Trigger periodic scan executions | Keeper network | Per level interval |

---

## Component Architecture

```
+-------------------------------------------------------------------------+
|                           COMPONENT RELATIONSHIPS                        |
+-------------------------------------------------------------------------+
|                                                                          |
|   PRESENTATION LAYER                                                     |
|   +-----------------------------------------------------------------+   |
|   |                      apps/web (SvelteKit)                        |   |
|   |                                                                  |   |
|   |   lib/core/         - Types, providers, stores, event bus       |   |
|   |   lib/features/     - Feed, position, typing, modals            |   |
|   |   lib/ui/           - Terminal primitives, design system        |   |
|   |   routes/           - Pages (/, /typing, etc.)                  |   |
|   +-----------------------------------------------------------------+   |
|              |                                        |                  |
|              | viem (tx signing)                      | REST/WS          |
|              v                                        v                  |
|   CONTRACT LAYER                           SERVICE LAYER                 |
|   +-----------------------------+    +--------------------------------+  |
|   | packages/contracts          |    | services/ghostnet-indexer      |  |
|   |                             |    |                                |  |
|   | src/token/                  |    | src/indexer/  - Block/log      |  |
|   |   DataToken.sol             |    | src/handlers/ - Event routing  |  |
|   |   TeamVesting.sol           |    | src/store/    - TimescaleDB    |  |
|   |                             |    | src/api/      - REST + WS      |  |
|   | src/core/                   |    | src/streaming/- Iggy pub/sub   |  |
|   |   GhostCore.sol             |    +--------------------------------+  |
|   |   TraceScan.sol             |                    |                   |
|   |   RewardsDistributor.sol    |                    v                   |
|   |                             |    +--------------------------------+  |
|   | src/markets/                |    | DATA STORES                    |  |
|   |   DeadPool.sol              |    |                                |  |
|   |                             |    | TimescaleDB  - Events, state   |  |
|   | src/periphery/              |    | Apache Iggy  - Event streaming |  |
|   |   FeeRouter.sol             |    | moka/dashmap - In-memory cache |  |
|   +-----------------------------+    +--------------------------------+  |
|              |                                                           |
|              v                                                           |
|   +---------------------------------------------------------------------+|
|   |                         MegaETH (Chain ID 6343/4326)                ||
|   |   - 10ms block times    - EIP-1153 transient storage                ||
|   |   - Prague EVM          - prevrandao-based randomness               ||
|   +---------------------------------------------------------------------+|
+-------------------------------------------------------------------------+
```

### Component Details

#### Web App (`apps/web`)

**Responsibility:** Player interface and experience delivery.

**Owns:**
- UI state (which panel is open, form inputs)
- Visual/audio effects orchestration
- Wallet connection lifecycle

**Collaborates with:**
- Contracts: Sends transactions (jackIn, extract)
- Indexer: Receives real-time event feed via WebSocket, queries state via REST

**Exposes:**
- Web UI at configured domain

**Key invariants:**
- Never stores authoritative financial state (always reads from chain or indexer)
- Degrades gracefully when indexer unavailable (falls back to direct RPC)

#### Smart Contracts (`packages/contracts`)

**Responsibility:** Source of truth for all financial state and game rules.

**Owns:**
- Token balances and transfers
- Position state (stake amounts, levels, alive/dead status)
- Scan execution and death determination
- Reward distribution (cascade, emissions)

**Collaborates with:**
- External: Receives transactions from players and keepers
- Internal: Emits events consumed by indexer

**Exposes:**
- Public functions: `jackIn()`, `extract()`, `executeScan()`, `submitDeaths()`, etc.
- View functions: `getPosition()`, `getLevelConfig()`, `getPendingRewards()`
- Events: JackedIn, Extracted, DeathsProcessed, CascadeDistributed, etc.

**Key invariants:**
- `INV-001`: Total positions value <= contract token balance (solvency)
- `INV-002`: Death determination is deterministic from (seed, address, deathRate)
- `INV-003`: Cascade distribution sums to 100% (30+30+30+10)

#### Indexer (`services/ghostnet-indexer`)

**Responsibility:** Project on-chain events into queryable state and real-time streams.

**Owns:**
- Derived state (leaderboards, analytics, aggregates)
- Event persistence history
- WebSocket connection management

**Collaborates with:**
- MegaETH RPC: Subscribes to blocks and logs
- TimescaleDB: Persists events and state
- Apache Iggy: Publishes events for streaming

**Exposes:**
- REST API: `/api/v1/positions`, `/api/v1/scans`, etc.
- WebSocket: `/ws` for real-time event streaming
- Metrics: `/metrics` for observability

**Key invariants:**
- `INV-I-001`: State is rebuildable from chain history (no authoritative data)
- `INV-I-002`: Events are delivered in block order (no reordering)

---

## Boundaries

### On-Chain / Off-Chain Boundary

**The Boundary:**
- Separates: Authoritative financial state (on-chain) from derived/UI state (off-chain)
- Implemented via: Contract ABI + Events

**The Contract:**
- CAN cross: Transactions (user actions), Events (state changes), View calls (reads)
- CANNOT cross: Private state, non-emitted internal changes
- Direction: Bidirectional (writes in, events out)

**The Rationale:**
- Protects against: Data loss, censorship, single points of failure
- Enables: Trustless verification, multiple frontends/indexers
- Without it: Users must trust the operator; loses crypto's core value proposition

### Web / Indexer Boundary

**The Boundary:**
- Separates: Presentation logic from data aggregation
- Implemented via: REST API + WebSocket protocol

**The Contract:**
- CAN cross: JSON-serialized events, query parameters, pagination
- CANNOT cross: Raw database queries, internal caching state
- Direction: Bidirectional (queries in, events out)

**The Rationale:**
- Protects against: Frontend coupling to backend implementation
- Enables: Multiple frontend versions, mobile apps, third-party integrations
- Without it: Changes to data layer break all clients

### Upgradeable / Immutable Contract Boundary

**The Boundary:**
- Separates: Tunable game logic (UUPS proxies) from trust anchors (immutable)
- Implemented via: Proxy pattern with Timelock

**The Contract:**
- Immutable: DataToken (tax rates permanent), TeamVesting (vesting terms permanent)
- Upgradeable: GhostCore, TraceScan, DeadPool (48h timelock + 3/5 multisig)

**The Rationale:**
- Protects against: Malicious upgrades (timelock), permanent bugs (upgradeability)
- Enables: Bug fixes, parameter tuning, MegaETH-specific adaptations
- Without it: Either stuck with bugs forever or users can't trust tokenomics

---

## Data Model

### Core Entities

| Entity | What It Represents | Identity | Lifecycle |
|--------|-------------------|----------|-----------|
| **Position** | A player's stake in the game | (address) | Created at jackIn, destroyed at extract or death. **One position per user**; level is locked once chosen. |
| **TraceScan** | A periodic scan execution | (level, scanId) | Created at executeScan, finalized after submission window |
| **DeadPoolRound** | A betting round on scan outcomes | roundId | Created, betting, resolved, claimed |
| **Cascade** | Distribution of dead capital | (scanId) | Instantaneous on scan finalization |

### Value Objects

| Value Object | Represents | Validation Rules |
|--------------|------------|------------------|
| **Level** | Risk level tier (1-5) | Must be 1-5, immutable once position created |
| **Amount** | Token quantity (uint256) | Must be >= minStake for level |
| **DeathRate** | Probability of death (uint16 bps) | 0-10000, modified by boosts and network |
| **Boost** | Temporary modifier | Type (death/yield), value (bps), expiry (timestamp) |

### Aggregate Boundaries

| Aggregate | Root | Contains | Consistency Rule |
|-----------|------|----------|------------------|
| **Position** | Position | Boosts[] | Single position per address, level locked |
| **LevelState** | LevelConfig | totalStaked, aliveCount, accRewardsPerShare | Reflects sum of all positions at level |
| **Scan** | TraceScan | processedUsers mapping | All deaths processed before finalization |

### Entity Relationships

```
Player (address)
    |
    +--[1:1]-- Position
    |              |
    |              +--[N:1]-- Level (configuration)
    |              +--[1:N]-- Boost (temporary modifiers)
    |
    +--[1:N]-- Bet (DeadPool wagers)
                   |
                   +--[N:1]-- Round (betting round)

TraceScan
    |
    +--[1:N]-- DeathSubmission (batched death proofs)
    +--[1:1]-- Cascade (reward distribution)
```

---

## Invariants

### Domain Invariants (Must Always Be True)

| ID | Invariant | Enforced By |
|----|-----------|-------------|
| `INV-D-001` | Contract solvency: sum(positions) <= token balance | Transfer checks in jackIn/extract |
| `INV-D-002` | Position uniqueness: max 1 position per address | Mapping structure in GhostCore |
| `INV-D-003` | Level immutability: position.level cannot change | jackIn checks existing position |
| `INV-D-004` | Death determinism: isDead(seed, address, rate) is pure | Pure function in TraceScan |
| `INV-D-005` | Cascade completeness: 30+30+30+10 = 100% of dead capital | Hardcoded constants |
| `INV-D-006` | Lock period enforcement: no extract within 60s of scan | Time check in extract() |

### Architectural Invariants

| ID | Invariant | Enforced By |
|----|-----------|-------------|
| `INV-A-001` | Indexer has no authoritative data | Design review, rebuildable from chain |
| `INV-A-002` | Events are the contract interface | No RPC reads for state sync |
| `INV-A-003` | Web never stores balances locally | Code review, no localStorage for amounts |
| `INV-A-004` | Upgrades require 48h delay | TimelockController configuration |

---

## Key Flows

### Flow 1: Jack In (Stake)

**Purpose:** Player enters a risk level with staked $DATA.
**Trigger:** User clicks "Jack In" and confirms transaction.
**Actors:** Player, Web App, GhostCore Contract, Indexer

```
Player          Web App           GhostCore          Indexer         Feed
   |                |                  |                 |              |
   |--[1] Click---->|                  |                 |              |
   |                |--[2] tx:jackIn-->|                 |              |
   |                |                  |--[3] validate-->|              |
   |                |                  |--[4] transfer-->|              |
   |                |                  |--[5] emit------>|              |
   |                |                  |                 |--[6] decode->|
   |                |                  |                 |--[7] persist>|
   |                |<-----------------|-----------------|-[8] WS event-|
   |<--[9] update---|                  |                 |              |
```

**State Changes:**
- Position created/updated in GhostCore storage
- Token transferred from player to contract
- Level totalStaked incremented
- System reset deadline extended

**Failure Modes:**
- Insufficient balance: Transaction reverts, user sees error
- Below minStake: Transaction reverts with clear message
- Level at capacity: Triggers culling (separate flow)

### Flow 2: Trace Scan Execution

**Purpose:** Periodic scan determines who lives and dies.
**Trigger:** Timer expires, keeper calls `executeScan`.
**Actors:** Keeper, TraceScan, GhostCore, Indexer, All Players at Level

```
Keeper        TraceScan       GhostCore        Indexer        Web App
   |              |               |                |              |
   |--[1] exec--->|               |                |              |
   |              |--[2] seed---->|                |              |
   |              |--[3] emit ScanExecuted-------->|              |
   |              |               |                |--[4] stream->|
   |              |               |                |              |--[5] warning
   |              |               |                |              |
   |--[6] submit--|               |                |              |
   |   Deaths[]   |               |                |              |
   |              |--[7] verify-->|                |              |
   |              |--[8] process->|                |              |
   |              |               |--[9] mark dead |              |
   |              |--[10] emit DeathsSubmitted---->|              |
   |              |               |                |--[11] feed-->|
   |              |               |                |              |
   |--[12] finalize-------------->|                |              |
   |              |--[13] cascade>|                |              |
   |              |               |--[14] distribute              |
   |              |--[15] emit ScanFinalized------>|              |
   |              |               |                |--[16] update>|
```

**State Changes:**
- Scan seed recorded (deterministic from prevrandao)
- Dead positions marked alive=false
- Cascade distributed (30% same-level, 30% upstream, 30% burn, 10% protocol)
- Survivor streaks incremented
- Next scan time updated

**Failure Modes:**
- Keeper offline: Anyone can call (permissionless)
- Invalid death proof: Transaction reverts, bad actor gains nothing
- Chain reorg: Indexer rolls back, reprocesses from fork point

### Flow 3: Extract (Withdraw)

**Purpose:** Player exits position and claims principal + rewards.
**Trigger:** User clicks "Extract" and confirms transaction.
**Actors:** Player, Web App, GhostCore Contract, Indexer

```
Player          Web App           GhostCore          Indexer
   |                |                  |                 |
   |--[1] Click---->|                  |                 |
   |                |--[2] check lock->|                 |
   |                |<--[3] not locked-|                 |
   |                |--[4] tx:extract->|                 |
   |                |                  |--[5] calc rewards
   |                |                  |--[6] transfer-->|
   |                |                  |--[7] delete pos>|
   |                |                  |--[8] emit------>|
   |                |                  |                 |--[9] update
   |                |<-----------------|-----------------|-[10] confirm
   |<--[11] show----|                  |                 |
```

**State Changes:**
- Position deleted from storage
- Principal + rewards transferred to player
- Level totalStaked decremented

**Failure Modes:**
- In lock period: Transaction reverts (60s before scan)
- Position dead: Cannot extract (already processed in scan)

### Flow 4: Death and Cascade

**Purpose:** Dead positions fund survivors and protocol.
**Trigger:** Scan finalization processes dead capital.
**Actors:** TraceScan, GhostCore, All Survivors

```
TraceScan                GhostCore                     Levels
    |                        |                           |
    |--[1] finalize--------->|                           |
    |                        |--[2] calc dead capital--->|
    |                        |                           |
    |                        |--[3] 30% same level------>| accRewards += share
    |                        |--[4] 30% upstream-------->| accRewards += share
    |                        |--[5] 30% burn------------>| transfer to 0xdead
    |                        |--[6] 10% protocol-------->| transfer to treasury
    |                        |                           |
    |<--[7] emit CascadeDistributed---------------------|
```

**State Changes:**
- Each survivor's claimable rewards increase (via accRewardsPerShare)
- 30% of dead capital burned forever
- 10% to treasury for operations

---

## Error Handling

| Category | Examples | Strategy |
|----------|----------|----------|
| **Validation** | Below minStake, invalid level | Revert with custom error, clear UI feedback |
| **Business** | In lock period, position dead | Revert with descriptive error, disable button in UI |
| **Infrastructure** | RPC down, DB unavailable | Retry with backoff, graceful degradation |
| **Chain** | Reorg detected | Roll back indexed state, reprocess from fork |
| **Unexpected** | Contract bug | Pause contract, emergency withdraw available |

---

## Cross-Cutting Concerns

### Authentication & Authorization

| Aspect | Approach |
|--------|----------|
| Identity | Wallet signature (no accounts, no passwords) |
| Session | Connection-based (wallet remains connected) |
| Authorization | On-chain roles (SCANNER_ROLE, ADMIN_ROLE) via AccessControl |

### Observability

| Aspect | Implementation |
|--------|----------------|
| Logging | Structured JSON (tracing in Rust, pino in Node) |
| Metrics | Prometheus (block latency, event counts, API p99) |
| Tracing | Correlation IDs through event pipeline |
| Alerting | Grafana rules on block lag, error rates |

### Configuration

| Aspect | Approach |
|--------|----------|
| Contracts | Immutable params in code, tunable via admin functions |
| Indexer | TOML config files + environment overrides |
| Web | Environment variables, build-time config |

---

## Integrations

| System | Purpose | Protocol | Auth | Failure Strategy |
|--------|---------|----------|------|------------------|
| MegaETH RPC | Chain access | JSON-RPC/WS | None | Switch provider, retry |
| Gelato Automate | Scan automation | Keeper network | API key | Fall back to manual |
| Bronto DEX | Token buyback | On-chain swap | None | Queue for retry |

---

## Key Decisions

| Decision | What | Why | Trade-off | Reference |
|----------|------|-----|-----------|-----------|
| Block-based randomness | prevrandao + 60s lock | Zero latency, zero cost | Trust sequencer | smart-contracts-plan.md |
| Immutable token | DataToken cannot upgrade | Trust anchor for users | Stuck if wrong | smart-contracts-plan.md |
| Share-based rewards | MasterChef pattern | O(1) gas for distribution | Complexity | smart-contracts-plan.md |
| Event-sourced UI | Central event bus | Unified sound/visual/state | Indirection | frontend-architecture.md |
| Rust indexer | Alloy + TimescaleDB | Performance, no GC pauses | Smaller talent pool | indexer-architecture.md |
| Epoch-based cleanup | scanId-keyed mappings | O(1) storage cleanup | Stale slots not reclaimed | specifications.md |

---

## Technical Debt

| Item | Impact | Root Cause | Remediation |
|------|--------|------------|-------------|
| MegaETH WS flakiness | Polling fallback needed | Testnet instability | Monitor mainnet, adjust |
| Culling O(n) search | Gas cost at scale | Simplicity for MVP | Level-specific enumerable sets |
| No formal verification | Potential bugs | Time constraints | Audit + formal methods post-launch |

---

## Domain Architecture Anchors

The following sections provide navigation anchors for capability documents.

### Core Economic Engine

The economic engine is the heart of GHOSTNET. It handles stake deposits, yield calculation, and death redistribution. See [[capabilities/core]] for detailed capability specifications.

Key components:
- **GhostCore contract** - Main game logic and position management
- **TraceScan contract** - Periodic survival checks
- **Share-based accounting** - MasterChef-style yield distribution

### Economic Engine

The deflationary mechanics that make GHOSTNET sustainable. Token burns occur on every significant action. See [[capabilities/economy]] for detailed capability specifications.

Key mechanisms:
- **The Cascade** - 60/30/10 redistribution of dead positions
- **Burn Engine** - Protocol fees, death tax, and activity burns
- **ETH Toll Booth** - Fixed ETH fee on transactions

### Social Layer

Community features that drive engagement and retention. See [[capabilities/social]] for detailed capability specifications.

Key features:
- **The Feed** - Real-time event stream of all game activity
- **Leaderboards** - Competition and status display
- **Crews** - Team formation with yield bonuses

### Emergency Procedures

Emergency response mechanisms for protecting user funds. See `docs/architecture/emergency-procedures.md` for operational details.

Key capabilities:
- **Circuit Breaker** - Global pause functionality
- **Emergency Withdraw** - Principal recovery during pause
- **Admin Multisig** - Timelocked privileged operations

---

## References

For deeper technical details, see:

- **Contract specifications:** `docs/design/contracts/specifications.md`
- **Contract architecture:** `docs/archive/architecture/smart-contracts-plan.md` (historical)
- **Frontend architecture:** `docs/architecture/frontend-architecture.md`
- **Indexer architecture:** `docs/architecture/backend/indexer-architecture.md`
- **MVP scope:** `docs/architecture/mvp-scope.md`
- **MegaETH deployment:** `docs/integrations/megaeth.md`
