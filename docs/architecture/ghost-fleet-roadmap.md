# Ghost Fleet: Implementation Roadmap
## Phase-by-Phase Execution Plan

**Version:** 1.0  
**Status:** Draft  
**Date:** January 2026  
**Estimated Duration:** 10 weeks  

---

## Overview

This document provides a detailed, phase-by-phase implementation plan for the Ghost Fleet system. Each phase builds on the previous, with clear deliverables and acceptance criteria.

```
Timeline Overview
═════════════════

Week  1   2   3   4   5   6   7   8   9   10
      ├───┴───┤   │   │   │   │   │   │   │
      Phase 1: Extract megaeth-rpc
              ├───┴───┤   │   │   │   │   │
              Phase 2: evm-provider traits
                      ├───┴───┤   │   │   │
                      Phase 3: fleet-core
                              ├───┴───┤   │
                              Phase 4: ghostnet-actions
                                      ├───┴───┤
                                      Phase 5: ghost-fleet service
                                              ├───┤
                                              Phase 6: Production
```

---

## Phase 1: Extract MegaETH RPC Client
**Duration:** 2 weeks  
**Risk Level:** Low  
**Dependencies:** None  

### 1.1 Objective

Extract the MegaETH-specific RPC functionality from `ghostnet-indexer` into a standalone, reusable crate that can be shared across services.

### 1.2 Why First?

- **Lowest risk**: Refactoring existing, working code
- **Immediate value**: Indexer benefits from cleaner separation
- **Foundation**: Required by `evm-provider` in Phase 2
- **Validation**: Proves the crate structure works

### 1.3 Tasks

```
Week 1
──────
□ 1.1.1  Create workspace structure
         - Create services/Cargo.toml (workspace root)
         - Create services/crates/ directory
         - Update ghostnet-indexer to be workspace member
         
□ 1.1.2  Create megaeth-rpc crate scaffold
         - services/crates/megaeth-rpc/Cargo.toml
         - Basic lib.rs with module structure
         - README.md with usage examples

□ 1.1.3  Move cursor pagination code
         - Copy MegaEthRpcClient from indexer
         - Copy LogsWithCursorResponse, LogsWithCursorFilter
         - Copy FetchStats
         - Adapt error types for standalone use

□ 1.1.4  Add realtime API support
         - Implement realtime_sendRawTransaction
         - Add send_realtime_transaction method
         - Document MegaETH-specific behavior

Week 2
──────
□ 1.2.1  Create comprehensive error types
         - MegaEthError enum
         - Proper error conversion (From impls)
         - Error documentation

□ 1.2.2  Add configuration support
         - Timeout configuration
         - Retry configuration
         - Connection pooling options

□ 1.2.3  Write unit tests
         - Request serialization tests
         - Response deserialization tests
         - Error handling tests

□ 1.2.4  Update ghostnet-indexer
         - Add megaeth-rpc as dependency
         - Remove duplicated code
         - Update imports throughout
         - Run existing tests

□ 1.2.5  Documentation
         - API documentation (rustdoc)
         - Usage examples
         - MegaETH quirks documentation
```

### 1.4 Deliverables

| Deliverable | Description |
|-------------|-------------|
| `megaeth-rpc` crate | Standalone crate with cursor pagination + realtime API |
| Updated indexer | Uses new crate, all tests pass |
| Documentation | API docs + usage guide |

### 1.5 Acceptance Criteria

- [ ] `cargo build -p megaeth-rpc` succeeds
- [ ] `cargo test -p megaeth-rpc` passes
- [ ] `cargo test -p ghostnet-indexer` passes (no regressions)
- [ ] `cargo doc -p megaeth-rpc` generates clean documentation
- [ ] Crate has no GHOSTNET-specific code

### 1.6 File Structure After Phase 1

```
services/
├── Cargo.toml                    # NEW: Workspace root
├── crates/
│   └── megaeth-rpc/              # NEW: Extracted crate
│       ├── Cargo.toml
│       ├── README.md
│       └── src/
│           ├── lib.rs
│           ├── client.rs         # MegaEthClient
│           ├── cursor.rs         # Cursor pagination
│           ├── realtime.rs       # Realtime API
│           ├── types.rs          # Request/response types
│           └── error.rs          # Error types
│
└── ghostnet-indexer/             # MODIFIED: Now uses megaeth-rpc
    ├── Cargo.toml                # Updated deps
    └── src/
        └── indexer/
            └── megaeth_rpc.rs    # DELETED (moved to crate)
```

---

## Phase 2: EVM Provider Abstraction
**Duration:** 2 weeks  
**Risk Level:** Medium  
**Dependencies:** Phase 1  

### 2.1 Objective

Create a chain abstraction layer that allows the fleet to work with any EVM chain through a common interface.

### 2.2 Why This Approach?

- **Future-proof**: Easy to add new chains
- **Testable**: Mock providers for unit tests
- **Clean separation**: Chain quirks isolated in providers

### 2.3 Tasks

```
Week 3
──────
□ 2.1.1  Create evm-provider crate scaffold
         - services/crates/evm-provider/Cargo.toml
         - Module structure
         - README.md

□ 2.1.2  Define core traits
         - ChainProvider trait (basic operations)
         - ExtendedChainProvider trait (optional features)
         - NonceManager trait
         - Document trait contracts

□ 2.1.3  Define common types
         - TransactionRequest
         - TransactionReceipt  
         - LogFilter
         - ProviderError

□ 2.1.4  Implement StandardEvmProvider
         - Wraps alloy Provider
         - Implements ChainProvider
         - Works with any standard EVM RPC

Week 4
──────
□ 2.2.1  Implement MegaEthProvider
         - Uses megaeth-rpc internally
         - Implements ChainProvider + ExtendedChainProvider
         - Handles gas estimation quirks
         - Supports realtime API

□ 2.2.2  Implement NonceManager
         - Thread-safe nonce tracking
         - Atomic get-and-increment
         - Chain sync capability

□ 2.2.3  Create TransactionBuilder
         - Chain-agnostic tx building
         - Signing abstraction
         - Gas estimation handling

□ 2.2.4  Write tests
         - Mock provider for unit tests
         - Integration tests with anvil
         - MegaETH-specific tests

□ 2.2.5  Documentation
         - Trait documentation
         - Implementation guide
         - Examples for each provider
```

### 2.4 Deliverables

| Deliverable | Description |
|-------------|-------------|
| `evm-provider` crate | Chain abstraction with traits + implementations |
| `MegaEthProvider` | MegaETH-specific implementation |
| `StandardEvmProvider` | Generic EVM implementation |
| Mock provider | For testing without network |

### 2.5 Acceptance Criteria

- [ ] `ChainProvider` trait is chain-agnostic
- [ ] `MegaEthProvider` passes integration tests on testnet
- [ ] `StandardEvmProvider` works with anvil
- [ ] Mock provider enables fast unit tests
- [ ] No protocol-specific code in crate

### 2.6 Key Trait Definitions

```rust
// This is what we're building
#[async_trait]
pub trait ChainProvider: Send + Sync + 'static {
    fn chain_id(&self) -> u64;
    async fn get_balance(&self, address: Address) -> Result<U256>;
    async fn get_token_balance(&self, token: Address, account: Address) -> Result<U256>;
    async fn get_nonce(&self, address: Address) -> Result<u64>;
    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash>;
    async fn wait_for_receipt(&self, tx: TxHash, timeout: Duration) -> Result<Receipt>;
    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes>;
}

#[async_trait]
pub trait ExtendedChainProvider: ChainProvider {
    async fn send_realtime(&self, tx: Bytes) -> Result<Receipt>;
    async fn get_logs_with_cursor(&self, filter: &LogFilter, cursor: Option<&str>) -> Result<LogsWithCursor>;
}
```

---

## Phase 3: Fleet Core Framework
**Duration:** 2 weeks  
**Risk Level:** Medium  
**Dependencies:** Phase 2  

### 3.1 Objective

Build the generic orchestration primitives that power the fleet: wallet management, scheduling, safety mechanisms, and the plugin system.

### 3.2 Tasks

```
Week 5
──────
□ 3.1.1  Create fleet-core crate scaffold
         - services/crates/fleet-core/Cargo.toml
         - Module structure
         - README.md

□ 3.1.2  Implement wallet module
         - WalletState struct (generic)
         - Keystore (encryption/decryption)
         - WalletManager (lifecycle)
         - Wallet configuration loading

□ 3.1.3  Implement profiles module
         - BehaviorProfile struct
         - Standard profiles (whale, degen, etc.)
         - Profile configuration loading

□ 3.1.4  Implement scheduler module
         - Timing calculations
         - Jitter/randomization
         - Time-of-day weighting
         - AFK handling

Week 6
──────
□ 3.2.1  Implement safety module
         - CircuitBreaker
         - RateLimiter
         - Global pause mechanism

□ 3.2.2  Implement plugin system
         - ActionPlugin trait
         - PluginRegistry
         - PluginContext

□ 3.2.3  Implement behavior engine
         - Decision coordination
         - Plugin querying
         - Action selection

□ 3.2.4  Implement funding module
         - FundingNeed detection
         - Amount calculation
         - Anti-pattern rules

□ 3.2.5  Implement metrics module
         - Prometheus metrics
         - Standard counters/gauges
         - Plugin-extensible metrics

□ 3.2.6  Write comprehensive tests
         - Wallet management tests
         - Scheduler tests
         - Circuit breaker tests
         - Plugin system tests
```

### 3.3 Deliverables

| Deliverable | Description |
|-------------|-------------|
| `fleet-core` crate | Generic orchestration primitives |
| Wallet management | Keystore, state tracking, configuration |
| Plugin system | Trait + registry for action plugins |
| Safety mechanisms | Circuit breakers, rate limiting |
| Scheduler | Timing with randomization |

### 3.4 Acceptance Criteria

- [ ] Wallet management works without protocol knowledge
- [ ] Plugin trait is generic (no GHOSTNET references)
- [ ] Circuit breaker correctly trips and resets
- [ ] Scheduler produces varied, natural-looking timings
- [ ] All components are independently testable

### 3.5 Module Structure

```
fleet-core/src/
├── lib.rs
├── wallet/
│   ├── mod.rs
│   ├── state.rs        # WalletState
│   ├── keystore.rs     # Key encryption
│   └── manager.rs      # WalletManager
├── profiles/
│   ├── mod.rs
│   └── standard.rs     # Standard profiles
├── scheduler/
│   ├── mod.rs
│   └── timing.rs       # Time calculations
├── safety/
│   ├── mod.rs
│   ├── circuit_breaker.rs
│   └── rate_limiter.rs
├── plugins/
│   ├── mod.rs
│   ├── traits.rs       # ActionPlugin trait
│   └── registry.rs     # PluginRegistry
├── behavior/
│   ├── mod.rs
│   └── engine.rs       # BehaviorEngine
├── funding/
│   ├── mod.rs
│   └── manager.rs      # FundingManager
└── metrics/
    ├── mod.rs
    └── standard.rs     # Standard metrics
```

---

## Phase 4: GHOSTNET Actions Plugin
**Duration:** 2 weeks  
**Risk Level:** Medium  
**Dependencies:** Phase 3  

### 4.1 Objective

Implement the first action plugin for GHOSTNET protocol interactions. This validates the plugin architecture and provides the core functionality for market making.

### 4.2 Tasks

```
Week 7
──────
□ 4.1.1  Create ghostnet-actions crate scaffold
         - services/ghostnet-actions/Cargo.toml
         - Module structure
         - README.md

□ 4.1.2  Define GHOSTNET-specific types
         - GhostnetState (position, rewards, etc.)
         - GhostnetProfile (maps from BehaviorProfile)
         - Level enum
         - Action data structures

□ 4.1.3  Create contract bindings
         - GhostCore ABI bindings
         - HashCrash ABI bindings
         - DataToken ABI bindings
         - Encoding/decoding helpers

□ 4.1.4  Implement GhostnetPlugin
         - Plugin trait implementation
         - Action registration
         - Configuration loading

Week 8
──────
□ 4.2.1  Implement GhostCore actions
         - decide_jack_in logic
         - decide_add_stake logic
         - decide_extract logic
         - decide_claim_rewards logic
         - Execute methods for each

□ 4.2.2  Implement HashCrash actions
         - decide_bet logic
         - decide_start_round logic
         - Execute methods
         - Round state tracking

□ 4.2.3  Implement state reading
         - Read position from GhostCore
         - Read pending rewards
         - Read HashCrash round state
         - Convert to plugin state format

□ 4.2.4  Profile mapping
         - Map risk_tolerance to level preferences
         - Map activity_level to action frequency
         - Map patience to extraction behavior

□ 4.2.5  Write tests
         - Decision logic tests
         - Action execution tests (mock provider)
         - State reading tests
         - Profile mapping tests
```

### 4.3 Deliverables

| Deliverable | Description |
|-------------|-------------|
| `ghostnet-actions` crate | Complete GHOSTNET plugin |
| GhostCore actions | JackIn, AddStake, Extract, ClaimRewards |
| HashCrash actions | PlaceBet, StartRound |
| State reading | Position and game state queries |

### 4.4 Acceptance Criteria

- [ ] Plugin implements `ActionPlugin` trait correctly
- [ ] All GhostCore actions work against testnet
- [ ] HashCrash actions work against testnet
- [ ] Profile mapping produces sensible behavior
- [ ] Plugin has no dependencies on fleet-core internals

### 4.5 Action Flow Example

```
BehaviorEngine calls plugin.decide_action()
                    │
                    ▼
GhostnetPlugin.decide_action()
    │
    ├── Get GHOSTNET state from wallet.plugin_states
    ├── Map BehaviorProfile → GhostnetProfile
    │
    ├── Try GhostCoreActions.decide()
    │   ├── If no position + balance → JackIn
    │   ├── If position alive + extract_prob → Extract
    │   ├── If position alive + compound_prob → AddStake
    │   └── Otherwise → None
    │
    └── Try HashCrashActions.decide()
        ├── If round open + join_prob → Bet
        └── Otherwise → None
                    │
                    ▼
Return Action { id: "ghostnet.jack_in", data: {...} }
```

---

## Phase 5: Ghost Fleet Service
**Duration:** 2 weeks  
**Risk Level:** Medium-High  
**Dependencies:** Phase 4  

### 5.1 Objective

Build the main service binary that wires everything together: configuration loading, component initialization, and the main execution loop.

### 5.2 Tasks

```
Week 9
──────
□ 5.1.1  Create ghost-fleet service scaffold
         - services/ghost-fleet/Cargo.toml
         - Binary structure
         - README.md

□ 5.1.2  Implement configuration system
         - Settings struct
         - TOML loading
         - Environment variable overrides
         - Validation

□ 5.1.3  Implement provider factory
         - Create provider based on config
         - MegaETH vs standard selection
         - Connection verification

□ 5.1.4  Implement plugin loading
         - Load enabled plugins from config
         - Register with PluginRegistry
         - Pass plugin-specific config

□ 5.1.5  Implement component initialization
         - WalletManager setup
         - BehaviorEngine setup
         - CircuitBreaker setup
         - Scheduler setup

Week 10 (Part 1)
────────────────
□ 5.2.1  Implement main service loop
         - Tick-based execution
         - Wallet processing
         - Error handling
         - Graceful shutdown

□ 5.2.2  Implement wallet processing
         - Check circuit breaker
         - Decide action via behavior engine
         - Execute action via plugin
         - Update state
         - Schedule next action

□ 5.2.3  Implement funding loop
         - Check wallet balances
         - Request funding from genesis
         - Execute funding transfers
         - Anti-pattern enforcement

□ 5.2.4  Implement health endpoints
         - /health - basic liveness
         - /health/ready - full readiness
         - /metrics - Prometheus endpoint

□ 5.2.5  Implement admin endpoints
         - /admin/pause - global pause
         - /admin/reset/{wallet} - reset circuit breaker
         - /admin/status - detailed status
```

### 5.3 Deliverables

| Deliverable | Description |
|-------------|-------------|
| `ghost-fleet` binary | Complete service executable |
| Configuration system | TOML + env var loading |
| Main loop | Wallet processing, funding, scheduling |
| Health/admin endpoints | Operational endpoints |

### 5.4 Acceptance Criteria

- [ ] Service starts and loads configuration
- [ ] Connects to MegaETH testnet
- [ ] Loads and initializes GHOSTNET plugin
- [ ] Processes wallets on schedule
- [ ] Executes actions successfully
- [ ] Health endpoints respond correctly
- [ ] Graceful shutdown works

### 5.5 Configuration Example

```toml
# ghost-fleet/config/testnet.toml

[service]
name = "ghost-fleet"
log_level = "info"
health_port = 8080

[chain]
chain_type = "megaeth"
chain_id = 6343
rpc_url = "https://carrot.megaeth.com/rpc"

[chain.megaeth]
gas_limit_override = 500000

[wallets]
keyfile = "keys/testnet.enc"

[funding]
min_native = "10000000000000000"
target_native = "50000000000000000"

[[funding.tokens]]
address = "0x..."  # DATA
min_balance = "50000000000000000000"
target_balance = "150000000000000000000"

[plugins]
enabled = ["ghostnet"]

[plugins.ghostnet]
ghost_core = "0x..."
hash_crash = "0x..."
arcade_core = "0x..."
data_token = "0x..."

[safety]
max_consecutive_errors = 5
circuit_breaker_cooldown_secs = 3600
global_pause = false

[profiles.whale]
risk_tolerance = 0.2
activity_level = 2.0
patience = 0.9
action_interval_base = 7200
action_interval_jitter_pct = 40

# ... other profiles
```

---

## Phase 6: Production Hardening
**Duration:** 1 week  
**Risk Level:** Medium  
**Dependencies:** Phase 5  

### 6.1 Objective

Prepare the system for production deployment with comprehensive testing, documentation, security review, and operational tooling.

### 6.2 Tasks

```
Week 10 (Part 2)
────────────────
□ 6.1.1  End-to-end testing
         - Full flow on testnet
         - 24-hour unattended run
         - Error injection testing
         - Recovery testing

□ 6.1.2  Performance testing
         - 100 wallet scale test
         - Measure action throughput
         - Memory usage profiling
         - RPC rate limit testing

□ 6.1.3  Security review
         - Key management audit
         - Configuration secrets check
         - Dependency audit (cargo-deny)
         - Log scrubbing verification

□ 6.1.4  Documentation completion
         - Deployment guide
         - Operations runbook
         - Configuration reference
         - Troubleshooting guide

□ 6.1.5  Operational tooling
         - Wallet generation script
         - Key encryption tool
         - Funding distribution script
         - Monitoring dashboard setup

□ 6.1.6  CI/CD setup
         - Build pipeline
         - Test automation
         - Docker image building
         - Deployment automation
```

### 6.3 Deliverables

| Deliverable | Description |
|-------------|-------------|
| Test results | E2E and performance test reports |
| Security audit | Review findings and fixes |
| Documentation | Complete operational docs |
| Tooling | Scripts for wallet setup, deployment |
| CI/CD | Automated build and deploy pipeline |

### 6.4 Acceptance Criteria

- [ ] 72-hour testnet run without manual intervention
- [ ] No security vulnerabilities in audit
- [ ] All documentation complete
- [ ] Monitoring dashboards operational
- [ ] Deployment pipeline functional

---

## Dependency Graph

```
Phase 1                    Phase 2                    Phase 3
megaeth-rpc      ────────▶ evm-provider     ────────▶ fleet-core
                           │                          │
                           │                          │
                           ▼                          ▼
                    Phase 4                    Phase 5
                    ghostnet-actions  ────────▶ ghost-fleet
                                                      │
                                                      ▼
                                               Phase 6
                                               Production
```

---

## Risk Register

| Phase | Risk | Likelihood | Impact | Mitigation |
|-------|------|------------|--------|------------|
| 1 | Indexer regression | Low | High | Comprehensive tests before/after |
| 2 | Trait design issues | Medium | Medium | Review with team, iterate early |
| 3 | Plugin interface too rigid | Medium | High | Design review, prototype first |
| 4 | Contract interaction failures | Medium | Medium | Testnet validation, error handling |
| 5 | Integration complexity | High | Medium | Incremental integration, good logging |
| 6 | Undetected issues at scale | Medium | High | Extended testnet runs, monitoring |

---

## Resource Requirements

### Development
- 1 senior Rust developer (full-time)
- Part-time code review support

### Infrastructure
- MegaETH testnet access
- CI/CD pipeline (GitHub Actions)
- Testnet ETH + DATA tokens
- Small VPS for testing (~$20/month)

### Testing
- 100 test wallet private keys
- ~1 ETH testnet for gas
- ~20,000 DATA testnet for operations

---

## Success Metrics by Phase

| Phase | Metric | Target |
|-------|--------|--------|
| 1 | Indexer test pass rate | 100% |
| 2 | Provider test coverage | > 80% |
| 3 | Core test coverage | > 80% |
| 4 | Actions success rate on testnet | > 95% |
| 5 | Service uptime in testing | > 99% |
| 6 | Unattended run duration | 72+ hours |

---

## Checkpoint Reviews

After each phase, conduct a review:

### Review Checklist
- [ ] All acceptance criteria met
- [ ] Tests passing
- [ ] Documentation updated
- [ ] No security concerns
- [ ] Performance acceptable
- [ ] Ready for next phase

### Review Participants
- Lead developer
- Code reviewer
- (Phase 5+) Operations/DevOps

---

## Post-Launch Roadmap

After Phase 6, future work includes:

### Near-term (1-2 months)
- [ ] Mainnet deployment
- [ ] Scale to 200 wallets
- [ ] DeadPool integration
- [ ] Performance optimization

### Medium-term (3-6 months)
- [ ] Second action plugin (token swaps)
- [ ] Multi-chain support
- [ ] Web dashboard for monitoring
- [ ] Automated wallet rotation

### Long-term (6+ months)
- [ ] Additional plugins (NFT, DeFi)
- [ ] Cross-chain operations
- [ ] ML-based behavior tuning
- [ ] Decentralized operation

---

## Quick Reference

### Phase Summary

| Phase | Duration | Key Deliverable | Risk |
|-------|----------|-----------------|------|
| 1 | 2 weeks | megaeth-rpc crate | Low |
| 2 | 2 weeks | evm-provider crate | Medium |
| 3 | 2 weeks | fleet-core crate | Medium |
| 4 | 2 weeks | ghostnet-actions plugin | Medium |
| 5 | 2 weeks | ghost-fleet service | Medium-High |
| 6 | 1 week | Production readiness | Medium |

### Commands Cheat Sheet

```bash
# Phase 1
just svc-build -p megaeth-rpc
just svc-test -p megaeth-rpc
just svc-test -p ghostnet-indexer  # Verify no regression

# Phase 2
just svc-build -p evm-provider
just svc-test -p evm-provider

# Phase 3
just svc-build -p fleet-core
just svc-test -p fleet-core

# Phase 4
just svc-build -p ghostnet-actions
just svc-test -p ghostnet-actions

# Phase 5
just svc-build -p ghost-fleet
just svc-test -p ghost-fleet
cargo run -p ghost-fleet -- --config config/testnet.toml

# All
just svc-check  # Full lint + test
```

---

*End of Roadmap Document*
