# Ghost Fleet: Requirements Document
## Multi-Chain Activity Orchestration System

**Version:** 2.0  
**Status:** Draft  
**Date:** January 2026  

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals](#2-goals)
3. [System Concept](#3-system-concept)
4. [Architecture Principles](#4-architecture-principles)
5. [Wallet Network](#5-wallet-network)
6. [Action Framework](#6-action-framework)
7. [Player Behavior](#7-player-behavior)
8. [Chain Abstraction](#8-chain-abstraction)
9. [Timing Requirements](#9-timing-requirements)
10. [Funding Strategy](#10-funding-strategy)
11. [Safety & Controls](#11-safety--controls)
12. [Monitoring](#12-monitoring)
13. [Crate Structure](#13-crate-structure)
14. [Use Cases](#14-use-cases)
15. [Cost Expectations](#15-cost-expectations)
16. [Risks & Mitigations](#16-risks--mitigations)
17. [Success Criteria](#17-success-criteria)
18. [Open Questions](#18-open-questions)

---

## 1. Overview

### 1.1 What Is Ghost Fleet?

Ghost Fleet is a **generic activity orchestration system** that manages networks of wallets performing on-chain actions. While the first use case is GHOSTNET market making, the architecture is designed to support any automated on-chain activity:

- Token buying/selling
- NFT minting
- Protocol interactions
- Liquidity provision
- Any smart contract interactions

### 1.2 Design Philosophy

**Chain Agnostic**: The core orchestration logic works with any EVM chain. Chain-specific features (like MegaETH's cursor pagination) are abstracted behind traits.

**Action Plugins**: Actions are defined as pluggable modules. GHOSTNET actions are one plugin; token swapping could be another. The core doesn't know or care about specific protocols.

**Reusable Infrastructure**: Wallet management, scheduling, funding, and safety mechanisms are generic. Only the "what to do" part changes per use case.

**Shared Crates**: Common functionality (MegaETH client, chain abstractions) lives in shared crates used by multiple services.

### 1.3 First Use Case: GHOSTNET

The initial deployment will create organic-looking activity on GHOSTNET:
- Jack in/extract from GhostCore
- Play HashCrash mini-game
- Generate realistic Live Feed content

But the system is built to support future use cases without rewriting the core.

---

## 2. Goals

### 2.1 Primary Goals

| Priority | Goal | Description |
|----------|------|-------------|
| P0 | **Generic Framework** | Build reusable orchestration, not GHOSTNET-specific code |
| P0 | **Chain Abstraction** | Support multiple EVM chains via trait abstractions |
| P0 | **Shared Crates** | Extract common code into reusable crates |
| P1 | **GHOSTNET Activity** | First use case: generate GHOSTNET feed activity |
| P1 | **Natural Patterns** | Activity must look like real human users |
| P1 | **Operational Safety** | Circuit breakers, kill switches, monitoring |

### 2.2 Architecture Goals

| Goal | Description |
|------|-------------|
| **Extensibility** | Adding new action types requires minimal code changes |
| **Chain Flexibility** | Switching chains requires only configuration + provider impl |
| **Testability** | All components testable in isolation via traits |
| **Single MegaETH Client** | One shared crate for MegaETH-specific features |

### 2.3 What We Are NOT Doing

- Building a GHOSTNET-only system
- Hard-coding chain-specific logic into the core
- Duplicating MegaETH client code across services

---

## 3. System Concept

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GHOST FLEET ORCHESTRATOR                           │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                          CORE (Generic)                                 │ │
│  │                                                                         │ │
│  │   Wallet Manager │ Scheduler │ Funding │ Safety │ Metrics              │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│                    ┌───────────────┼───────────────┐                        │
│                    ▼               ▼               ▼                        │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐            │
│  │  Action Plugin:  │ │  Action Plugin:  │ │  Action Plugin:  │            │
│  │    GHOSTNET      │ │   Token Swap     │ │      NFT         │            │
│  │                  │ │                  │ │                  │            │
│  │ • JackIn         │ │ • Buy            │ │ • Mint           │            │
│  │ • Extract        │ │ • Sell           │ │ • Transfer       │            │
│  │ • HashCrash      │ │ • Approve        │ │ • List           │            │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘            │
│                                    │                                         │
└────────────────────────────────────┼─────────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
           ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
           │   MegaETH    │ │   Ethereum   │ │   Arbitrum   │
           │   Provider   │ │   Provider   │ │   Provider   │
           └──────────────┘ └──────────────┘ └──────────────┘
                    │                │                │
                    ▼                ▼                ▼
           ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
           │   MegaETH    │ │   Ethereum   │ │   Arbitrum   │
           │   Network    │ │   Network    │ │   Network    │
           └──────────────┘ └──────────────┘ └──────────────┘
```

### 3.2 Core vs Plugins

| Layer | Responsibility | Examples |
|-------|----------------|----------|
| **Core** | Wallet management, scheduling, safety | Keystore, circuit breakers, metrics |
| **Action Plugins** | What actions to perform | GHOSTNET, swaps, mints |
| **Chain Providers** | How to interact with chains | MegaETH-specific RPC, standard EVM |

### 3.3 Dependency Flow

```
┌─────────────────┐     ┌─────────────────┐
│   ghost-fleet   │────▶│   megaeth-rpc   │  (shared MegaETH client)
│   (service)     │     └─────────────────┘
│                 │
│                 │────▶┌─────────────────┐
│                 │     │  evm-provider   │  (chain abstraction traits)
└─────────────────┘     └─────────────────┘
         │
         │              ┌─────────────────┐
         └─────────────▶│ ghostnet-actions│  (GHOSTNET-specific actions)
                        └─────────────────┘
```

---

## 4. Architecture Principles

### 4.1 Trait-Based Abstraction

Every external dependency is abstracted behind a trait:

| Trait | Purpose | Implementations |
|-------|---------|-----------------|
| `ChainProvider` | Basic EVM operations | `MegaEthProvider`, `StandardEvmProvider` |
| `ActionPlugin` | Defines available actions | `GhostnetPlugin`, `SwapPlugin` |
| `WalletStore` | Wallet persistence | `FileStore`, `DatabaseStore` |
| `Scheduler` | Timing decisions | `RandomizedScheduler`, `FixedScheduler` |

### 4.2 Configuration-Driven

Behavior is controlled by configuration, not code:

```toml
# Which chain to use
[chain]
type = "megaeth"
rpc_url = "https://carrot.megaeth.com/rpc"

# Which actions to enable
[actions]
enabled = ["ghostnet"]

# GHOSTNET-specific config (only loaded if enabled)
[actions.ghostnet]
ghost_core = "0x..."
hash_crash = "0x..."
```

### 4.3 Plugin Registration

Actions register themselves at startup:

```
1. Core loads configuration
2. Core asks: "What action plugins are enabled?"
3. Config says: ["ghostnet", "token_swap"]
4. Core loads GhostnetPlugin, TokenSwapPlugin
5. Each plugin registers its actions
6. Core's behavior engine uses registered actions
```

### 4.4 No Chain-Specific Code in Core

The core orchestrator MUST NOT contain:
- MegaETH-specific code
- GHOSTNET contract addresses
- Any protocol-specific logic

All such code lives in plugins or providers.

---

## 5. Wallet Network

### 5.1 Wallet Hierarchy

Same three-tier structure, but generic:

```
TIER 0: TREASURY
├── Controlled by team (manual)
├── Never interacts with protocols
├── Funds genesis wallets
│
▼
TIER 1: GENESIS WALLETS (5-10)
├── Buffer layer
├── Distributes to player wallets
├── May perform actions (for cover)
│
▼
TIER 2: PLAYER WALLETS (50-200)
├── Active participants
├── Each has personality profile
├── Perform configured actions
```

### 5.2 Wallet Configuration

Wallets are configured independently of actions:

```toml
# Wallet definitions (generic)
[[wallets.genesis]]
id = "genesis-01"
encrypted_key = "..."

[[wallets.player]]
id = "player-001"
encrypted_key = "..."
profile = "degen"
funded_by = "genesis-01"
```

The same wallets could be used for GHOSTNET today, token swapping tomorrow.

---

## 6. Action Framework

### 6.1 What Is an Action?

An action is any discrete on-chain operation:

| Category | Examples |
|----------|----------|
| **DeFi** | Swap, provide liquidity, stake, unstake |
| **Gaming** | GHOSTNET jack-in, HashCrash bet, claim rewards |
| **NFT** | Mint, transfer, list, delist |
| **Token** | Transfer, approve, wrap/unwrap |
| **Generic** | Any contract call |

### 6.2 Action Plugin Interface

Each plugin defines:

1. **Available Actions**: What operations are possible
2. **Decision Logic**: When/why to perform each action
3. **Execution Logic**: How to build and submit transactions
4. **State Reading**: How to check current state

### 6.3 GHOSTNET Plugin Actions

For the first use case:

| Action | Description | Inputs |
|--------|-------------|--------|
| `JackIn` | Create staking position | amount, level |
| `AddStake` | Increase position | amount |
| `Extract` | Withdraw position | (none) |
| `ClaimRewards` | Claim pending rewards | (none) |
| `HashCrashBet` | Place crash game bet | amount, target |
| `StartRound` | Start new game round | (none) |

### 6.4 Future Plugin Examples

**Token Swap Plugin:**
| Action | Description |
|--------|-------------|
| `SwapExactIn` | Swap exact input amount |
| `SwapExactOut` | Swap for exact output amount |
| `Approve` | Approve router to spend |

**NFT Plugin:**
| Action | Description |
|--------|-------------|
| `Mint` | Mint new NFT |
| `Transfer` | Send NFT to address |
| `List` | List on marketplace |

---

## 7. Player Behavior

### 7.1 Personality Profiles (Generic)

Profiles define behavior patterns independent of specific actions:

| Profile | Risk | Activity | Description |
|---------|------|----------|-------------|
| **Whale** | Low | Low | Large positions, patient |
| **Grinder** | Medium | Medium | Steady, consistent |
| **Degen** | High | High | Risk-loving, active |
| **Casual** | Mixed | Low | Sporadic, random |
| **Sniper** | Extreme | Burst | All-in plays |

### 7.2 Profile-to-Action Mapping

Profiles don't know about specific actions. Instead, they define:
- Risk tolerance (affects which actions get high-risk parameters)
- Activity level (affects frequency)
- Patience (affects holding durations)

The action plugin interprets these for its specific context.

**Example: How "Degen" maps to different plugins:**

| Plugin | Degen Interpretation |
|--------|---------------------|
| GHOSTNET | Prefers DARKNET/BLACK_ICE, holds positions longer |
| Token Swap | Larger trades, more frequent, riskier tokens |
| NFT | Mints early, flips quickly |

### 7.3 Profile Distribution

Recommended for any use case:

| Profile | Percentage |
|---------|------------|
| Whale | 5% |
| Grinder | 20% |
| Degen | 40% |
| Casual | 25% |
| Sniper | 10% |

---

## 8. Chain Abstraction

### 8.1 Why Abstract Chains?

Different chains have different:
- Gas mechanics (EIP-1559 vs legacy)
- RPC capabilities (MegaETH cursor pagination)
- Timing (block times, finality)
- Quirks (MegaETH gas estimation)

### 8.2 Chain Provider Trait

The core needs these capabilities from any chain:

| Capability | Description |
|------------|-------------|
| Get balance (ETH) | Native token balance |
| Get balance (ERC20) | Token balance |
| Get nonce | Transaction count |
| Send transaction | Submit signed tx |
| Wait for receipt | Confirmation |
| Estimate gas | (optional, can hardcode) |

### 8.3 MegaETH-Specific Features

MegaETH has features not in standard EVM:

| Feature | Description | Where Used |
|---------|-------------|------------|
| Cursor pagination | `eth_getLogsWithCursor` | Indexer backfill |
| Realtime API | `realtime_sendRawTransaction` | Fast confirmations |
| Mini blocks | 10ms preconfirmation | UX optimization |

These belong in the **megaeth-rpc** shared crate, not the core.

### 8.4 Chain Configuration

```toml
[chain]
type = "megaeth"  # or "ethereum", "arbitrum", etc.
chain_id = 6343
rpc_url = "https://carrot.megaeth.com/rpc"

# MegaETH-specific (ignored for other chains)
[chain.megaeth]
use_realtime_api = true
gas_limit_override = 500000
```

---

## 9. Timing Requirements

### 9.1 Generic Timing

Timing is profile-based, not action-based:

| Profile | Base Interval | Jitter |
|---------|---------------|--------|
| Whale | ~2 hours | ±40% |
| Grinder | ~30 minutes | ±50% |
| Degen | ~15 minutes | ±60% |
| Casual | ~1 hour | ±80% |
| Sniper | ~10 minutes | ±40% |

### 9.2 Time-of-Day Patterns

Activity varies by hour (UTC):

| Period | Activity Level |
|--------|----------------|
| 00:00-06:00 | 30% (low) |
| 06:00-12:00 | 70% (rising) |
| 12:00-18:00 | 130% (peak) |
| 18:00-24:00 | 100% (declining) |

### 9.3 AFK Periods

Wallets randomly go inactive:
- Duration based on profile
- More frequent for casual profiles
- Creates natural gaps

---

## 10. Funding Strategy

### 10.1 Generic Funding

Funding is independent of actions:

1. Monitor wallet balances (native + configured tokens)
2. When below threshold, request from genesis
3. Genesis distributes with randomized amounts/timing
4. Cross-pollination for organic appearance

### 10.2 Token Configuration

Each use case configures which tokens to track:

```toml
[funding]
# Native token (ETH) - always required for gas
min_native = "0.01"
target_native = "0.05"

# Additional tokens (use-case specific)
[[funding.tokens]]
address = "0x..."  # DATA token
symbol = "DATA"
min_balance = "50"
target_balance = "150"
```

### 10.3 Anti-Pattern Detection

Same rules regardless of use case:
- No rapid-fire transfers from same genesis
- No identical amounts
- Vary timing throughout day

---

## 11. Safety & Controls

### 11.1 Circuit Breakers

Per-wallet protection:
- Track consecutive errors
- Trip after N failures
- Require manual reset or cooldown

### 11.2 Rate Limiting

System-wide limits:
- Max actions per wallet per hour
- Max total actions per minute
- Prevent runaway loops

### 11.3 Kill Switch

Global pause capability:
- Configuration flag
- Stops all activity immediately
- For emergencies

### 11.4 Loss Limits

Track financial exposure:
- Alert if losses exceed threshold
- Pause and investigate anomalies

---

## 12. Monitoring

### 12.1 Generic Metrics

Track regardless of use case:

| Metric | Description |
|--------|-------------|
| Active wallets | Currently operating |
| Actions per hour | Activity level |
| Error rate | Failures / total |
| Circuit breakers | Tripped count |
| Wallet balances | By token |

### 12.2 Plugin-Specific Metrics

Each plugin can add its own:

**GHOSTNET:**
- Positions by level
- HashCrash win rate
- TVL contribution

**Token Swap:**
- Volume traded
- Slippage average
- Failed swaps

### 12.3 Alerting

| Condition | Severity |
|-----------|----------|
| No actions in 30 min | High |
| Circuit breaker tripped | High |
| Error rate > 10% | Medium |
| Low balance | Medium |

---

## 13. Crate Structure

### 13.1 Shared Crates

Extract common functionality into reusable crates:

```
services/
├── crates/
│   ├── megaeth-rpc/           # MegaETH-specific RPC client
│   │   ├── cursor pagination
│   │   ├── realtime API
│   │   └── MegaETH quirks
│   │
│   ├── evm-provider/          # Chain abstraction traits
│   │   ├── ChainProvider trait
│   │   ├── Standard EVM impl
│   │   └── Transaction building
│   │
│   └── fleet-core/            # Orchestration primitives
│       ├── Wallet management
│       ├── Scheduling
│       ├── Circuit breakers
│       └── Metrics
│
├── ghost-fleet/               # Main service
│   └── Uses: megaeth-rpc, evm-provider, fleet-core
│
├── ghostnet-indexer/          # Existing indexer
│   └── Uses: megaeth-rpc (extracted from current code)
│
└── ghostnet-actions/          # GHOSTNET action plugin
    └── GhostCore, HashCrash interactions
```

### 13.2 Crate Dependencies

```
ghost-fleet (service)
├── fleet-core (orchestration)
├── evm-provider (chain abstraction)
├── megaeth-rpc (MegaETH client)
└── ghostnet-actions (plugin)

ghostnet-indexer (existing)
├── megaeth-rpc (extracted)
└── (other deps)

ghostnet-actions (plugin)
├── evm-provider (traits)
└── alloy (contract bindings)
```

### 13.3 Migration Path

1. **Extract megaeth-rpc** from indexer into shared crate
2. **Create evm-provider** with chain abstraction traits
3. **Create fleet-core** with generic orchestration
4. **Create ghostnet-actions** as first plugin
5. **Build ghost-fleet** service using all crates

---

## 14. Use Cases

### 14.1 Current: GHOSTNET Market Making

Generate organic activity on GHOSTNET:
- Stake positions across risk levels
- Play HashCrash mini-game
- Create realistic feed content

**Plugin**: `ghostnet-actions`
**Chain**: MegaETH

### 14.2 Future: Token Launch Support

Support token launches with organic trading:
- Gradual accumulation
- Varied buy sizes
- Natural holding patterns

**Plugin**: `token-swap-actions`
**Chain**: Any DEX-enabled chain

### 14.3 Future: NFT Collection Activity

Maintain activity for NFT collections:
- Minting participation
- Secondary trading
- Marketplace listings

**Plugin**: `nft-actions`
**Chain**: Chain with target marketplace

### 14.4 Future: Multi-Protocol DeFi

Participate across multiple protocols:
- Liquidity provision
- Yield farming
- Governance voting

**Plugin**: `defi-actions`
**Chain**: Multiple (multi-chain support)

---

## 15. Cost Expectations

### 15.1 MegaETH Costs (Current)

| Activity | Daily Txns | Daily Cost |
|----------|------------|------------|
| Actions | ~700 | ~$0.70 |
| Funding | ~50 | ~$0.05 |
| **Total** | ~750 | **~$0.75/day** |

### 15.2 Other Chains (Comparative)

| Chain | Est. Cost/Tx | 750 Txns/Day |
|-------|--------------|--------------|
| MegaETH | $0.001 | $0.75 |
| Arbitrum | $0.05 | $37.50 |
| Optimism | $0.05 | $37.50 |
| Ethereum L1 | $5.00 | $3,750 |

MegaETH's low costs make high-frequency activity feasible.

### 15.3 Capital Requirements

Independent of use case:
- 100 player wallets × average stake
- Genesis buffer
- Gas reserves

For GHOSTNET: ~15,000 DATA + 1 ETH initial

---

## 16. Risks & Mitigations

### 16.1 Technical

| Risk | Mitigation |
|------|------------|
| Chain-specific bugs | Trait abstraction, thorough testing |
| Single point of failure | Circuit breakers, graceful degradation |
| Nonce issues | Per-chain nonce management |

### 16.2 Detection

| Risk | Mitigation |
|------|------------|
| Pattern recognition | Randomization, varied profiles |
| Funding tracing | Multi-hop distribution |
| Behavioral analysis | Natural "mistakes," losses |

### 16.3 Economic

| Risk | Mitigation |
|------|------------|
| Higher losses than expected | Loss limits, alerts |
| Gas price spikes | Rate limiting, pause capability |
| Token price drops | Budget in USD terms |

---

## 17. Success Criteria

### 17.1 Architecture Success

- [ ] MegaETH client extracted to shared crate
- [ ] Chain provider trait supports 2+ chains
- [ ] GHOSTNET actions work as plugin
- [ ] Core has zero protocol-specific code

### 17.2 Operational Success

- [ ] 100 wallets active on testnet
- [ ] 72-hour unattended run
- [ ] Error rate < 5%
- [ ] No detection incidents

### 17.3 Extensibility Success

- [ ] Can add new action plugin in < 1 day
- [ ] Can switch chains via configuration
- [ ] Second use case implemented without core changes

---

## 18. Open Questions

### 18.1 Decisions Needed

| Question | Options |
|----------|---------|
| Crate naming? | `megaeth-rpc` / `megaeth-client` / other |
| Workspace structure? | Flat services/ or nested services/crates/ |
| Plugin loading? | Compile-time features or runtime discovery |
| Multi-chain? | Single instance per chain or multi-chain instance |

### 18.2 TBD

- [ ] Exact trait definitions for ChainProvider
- [ ] Plugin interface specification
- [ ] Configuration schema finalization
- [ ] Shared crate versioning strategy

---

## Appendix: Glossary

| Term | Definition |
|------|------------|
| **Ghost Fleet** | The orchestration system (generic) |
| **Action Plugin** | Module defining specific on-chain actions |
| **Chain Provider** | Trait abstraction for blockchain interaction |
| **Profile** | Wallet personality (risk, activity level) |
| **megaeth-rpc** | Shared crate for MegaETH-specific features |

---

*End of Requirements Document*
