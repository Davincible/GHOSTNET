# Codebase Guide

> Navigation map for the GHOSTNET monorepo. For full documentation, see [AGENTS.md](../../AGENTS.md).

---

## Repository Structure

```
.
├── apps/
│   └── web/                    # SvelteKit 2.x frontend (Svelte 5 runes)
│       ├── src/
│       │   ├── routes/         # Page routes (+page.svelte files)
│       │   └── lib/            # Shared code (core, features, ui, web3)
│       ├── e2e/                # Playwright E2E tests
│       └── docs/guides/        # Svelte best practices
│
├── packages/
│   └── contracts/              # Foundry Solidity contracts
│       ├── src/                # Contract source files
│       │   ├── core/           # GhostCore, TraceScan
│       │   ├── token/          # DataToken, TeamVesting
│       │   ├── arcade/         # ArcadeCore, GameRegistry, games
│       │   ├── markets/        # DeadPool prediction market
│       │   ├── periphery/      # FeeRouter, RewardsDistributor
│       │   └── randomness/     # BlockhashHistory, FutureBlockRandomness
│       ├── test/               # Forge tests (*.t.sol)
│       ├── script/             # Deployment scripts (*.s.sol)
│       └── docs/guides/        # Solidity security guides
│
├── services/
│   └── ghostnet-indexer/       # Rust event indexer (1.85+)
│       ├── src/
│       │   ├── main.rs         # Binary entry point
│       │   ├── lib.rs          # Library root
│       │   ├── abi/            # Contract ABI bindings
│       │   ├── config/         # Configuration loading
│       │   ├── handlers/       # Event handlers per contract
│       │   ├── indexer/        # Block processor, event router
│       │   ├── store/          # PostgreSQL + cache
│       │   ├── streaming/      # Apache Iggy publisher
│       │   └── types/          # Domain types (entities, events, enums)
│       └── tests/              # Integration tests
│
├── docs/
│   ├── blueprint/              # Product truth (manifesto, architecture, capabilities, quality, roadmap, codebase)
│   ├── work/                   # Work tracking (status, backlog, recent, epics/)
│   ├── design/                 # Deep specs (arcade/, contracts/, copy-writing-bible.md)
│   ├── integrations/           # Platform guides (megaeth.md, gelato-vrf.md)
│   ├── learnings/              # Lessons learned
│   ├── decisions/              # ADRs
│   ├── workflow/               # Methodology guides
│   ├── sessions/               # Planning session logs
│   ├── architecture/           # Technical specs (frontend, backend, security, ops)
│   └── archive/                # Historical docs (old product/, old architecture/)
│
├── justfile                    # All commands (just <cmd>)
├── shell.nix                   # Nix development environment
└── AGENTS.md                   # Full monorepo documentation
```

---

## Entry Points

### Web App (`apps/web/`)

| Entry Point | Location | Purpose |
|-------------|----------|---------|
| Main dashboard | `src/routes/+page.svelte` | Primary game interface |
| Trace Evasion | `src/routes/typing/+page.svelte` | Typing mini-game |
| Hash Crash | `src/routes/arcade/hash-crash/+page.svelte` | Crash game |
| Daily Ops | `src/routes/arcade/daily-ops/+page.svelte` | Daily missions |
| Duels | `src/routes/games/duels/+page.svelte` | 1v1 wagering |
| Hack Run | `src/routes/games/hackrun/+page.svelte` | Yield multiplier game |
| Crew | `src/routes/crew/+page.svelte` | Guild system |
| Market | `src/routes/market/+page.svelte` | Consumables shop |
| Leaderboard | `src/routes/leaderboard/+page.svelte` | Rankings |
| Layout | `src/routes/+layout.svelte` | App shell, providers |

### Smart Contracts (`packages/contracts/`)

| Entry Point | Location | Purpose |
|-------------|----------|---------|
| GhostCore | `src/core/GhostCore.sol` | Main game: positions, cascade |
| TraceScan | `src/core/TraceScan.sol` | Death scan execution |
| DataToken | `src/token/DataToken.sol` | $DATA ERC20 token |
| DeadPool | `src/markets/DeadPool.sol` | Prediction market |
| ArcadeCore | `src/arcade/ArcadeCore.sol` | Arcade session management |
| HashCrash | `src/arcade/games/HashCrash.sol` | Crash game |
| DailyOps | `src/arcade/games/DailyOps.sol` | Daily missions |
| DuelEscrow | `src/arcade/games/DuelEscrow.sol` | 1v1 escrow |
| FeeRouter | `src/periphery/FeeRouter.sol` | Fee distribution |
| RewardsDistributor | `src/periphery/RewardsDistributor.sol` | Reward claims |
| TeamVesting | `src/token/TeamVesting.sol` | Token vesting |
| Deploy script | `script/Deploy.s.sol` | Main deployment |

### Indexer (`services/ghostnet-indexer/`)

| Entry Point | Location | Purpose |
|-------------|----------|---------|
| Binary | `src/main.rs` | CLI entry point |
| Library | `src/lib.rs` | Module exports |
| Block processor | `src/indexer/block_processor.rs` | Chain sync |
| Event router | `src/indexer/event_router.rs` | Event dispatch |
| Realtime processor | `src/indexer/realtime_processor.rs` | Live block handling |
| Reorg handler | `src/indexer/reorg_handler.rs` | Chain reorg recovery |
| Settings | `src/config/settings.rs` | Configuration |

---

## Key Abstractions

### Blueprint Concepts to Code

| Blueprint Concept | Web Location | Contract Location | Indexer Location |
|-------------------|--------------|-------------------|------------------|
| Position | `lib/core/types/index.ts` | `src/core/GhostCore.sol` | `src/types/entities.rs` |
| Risk Levels | `lib/core/types/index.ts` (LEVELS) | `src/core/GhostCoreStorage.sol` | `src/types/enums.rs` |
| TraceScan | `lib/core/types/index.ts` (FeedEventType) | `src/core/TraceScan.sol` | `src/handlers/scan_handler.rs` |
| Cascade | `lib/features/feed/` | `src/core/GhostCore.sol` | `src/handlers/death_handler.rs` |
| The Feed | `lib/features/feed/FeedPanel.svelte` | Events in all contracts | `src/streaming/` |
| Modifiers | `lib/core/types/index.ts` (Modifier) | Boost system in GhostCore | `src/types/entities.rs` |

### Domain Types

| Domain | Web Types | Contract Struct/Event | Indexer Entity |
|--------|-----------|----------------------|----------------|
| Position | `Position` | `Position` struct | `Position` |
| User | `User` | N/A (address-based) | N/A |
| Crew | `Crew`, `CrewMember` | [TBD - not yet implemented] | [TBD] |
| Dead Pool | `DeadPoolRound`, `DeadPoolResult` | `Round`, `Bet` | [TBD] |
| Scan | `FeedEvent` (TRACE_SCAN_*) | `ScanExecuted`, `ScanFinalized` | `Scan` |

---

## Module Map

### Web App Modules (`apps/web/src/lib/`)

| Module | Location | Responsibility |
|--------|----------|----------------|
| Core Types | `core/types/` | TypeScript interfaces |
| Providers | `core/providers/` | Data fetching (mock, web3) |
| Stores | `core/stores/` | Global state management |
| Audio | `core/audio/` | ZzFX sound system |
| Web3 | `web3/` | Wallet, chains, contracts |
| Feed | `features/feed/` | Live event display |
| Position | `features/position/` | Player position panel |
| Typing | `features/typing/` | Trace Evasion game |
| Hack Run | `features/hackrun/` | Yield multiplier game |
| Hash Crash | `features/hash-crash/` | Crash game |
| Daily | `features/daily/` | Daily missions |
| Dead Pool | `features/deadpool/` | Prediction market |
| Crew | `features/crew/` | Guild system |
| Market | `features/market/` | Consumables shop |
| Leaderboard | `features/leaderboard/` | Rankings |
| Header | `features/header/` | App header, wallet |
| Modals | `features/modals/` | JackIn, Extract, Settings |
| UI Primitives | `ui/primitives/` | Button, Badge, ProgressBar |
| UI Terminal | `ui/terminal/` | Shell, Box, Scanlines |
| UI Data | `ui/data-display/` | AddressDisplay, AmountDisplay |
| UI Layout | `ui/layout/` | Stack, Row |
| UI Modal | `ui/modal/` | Modal component |
| Visualizations | `ui/visualizations/` | Network globe, radar, etc. |

### Contract Modules (`packages/contracts/src/`)

| Module | Location | Responsibility |
|--------|----------|----------------|
| Core | `core/` | GhostCore, TraceScan, storage |
| Token | `token/` | DataToken, TeamVesting |
| Arcade | `arcade/` | Session management, games |
| Markets | `markets/` | DeadPool prediction market |
| Periphery | `periphery/` | FeeRouter, RewardsDistributor |
| Randomness | `randomness/` | On-chain randomness |
| Interfaces | `*/interfaces/` | Contract interfaces |
| Mocks | `mocks/` | Test mocks |

### Indexer Modules (`services/ghostnet-indexer/src/`)

| Module | Location | Responsibility |
|--------|----------|----------------|
| Types | `types/` | Enums, events, entities, primitives |
| Config | `config/` | Settings loading |
| ABI | `abi/` | Contract bindings |
| Indexer | `indexer/` | Block processing, routing |
| Handlers | `handlers/` | Per-contract event handling |
| Store | `store/` | PostgreSQL, cache |
| Streaming | `streaming/` | Iggy publisher, topics |
| Ports | `ports/` | Interface traits |
| Error | `error.rs` | Error types |

---

## Key Files

| File | Purpose | When to Modify |
|------|---------|----------------|
| `justfile` | All commands | Adding new tasks |
| `shell.nix` | Dev environment | Adding tools |
| `AGENTS.md` | Monorepo docs | Structure changes |
| `apps/web/svelte.config.js` | SvelteKit config | Build settings |
| `apps/web/vite.config.ts` | Vite config | Build/test settings |
| `apps/web/wagmi.config.ts` | Wagmi codegen | Contract type generation |
| `packages/contracts/foundry.toml` | Foundry config | Compiler settings |
| `services/ghostnet-indexer/Cargo.toml` | Rust config | Dependencies |

---

## Navigation Guide

| If you want to... | Look at... |
|-------------------|------------|
| Add a new page | `apps/web/src/routes/` |
| Add a new feature | `apps/web/src/lib/features/<name>/` |
| Add a UI component | `apps/web/src/lib/ui/` |
| Add a core type | `apps/web/src/lib/core/types/` |
| Connect to contracts | `apps/web/src/lib/web3/` |
| Add a smart contract | `packages/contracts/src/` |
| Add contract tests | `packages/contracts/test/` |
| Deploy contracts | `packages/contracts/script/` |
| Handle a new event | `services/ghostnet-indexer/src/handlers/` |
| Add indexer storage | `services/ghostnet-indexer/src/store/` |
| Add streaming topic | `services/ghostnet-indexer/src/streaming/` |

---

## Build & Run Commands

### Development

```bash
# Setup (first time)
just install

# Start development (3 terminals)
just contracts-anvil     # Terminal 1: Local blockchain
just svc-indexer-dev     # Terminal 2: Indexer
just web-dev             # Terminal 3: Web app

# Or use guidance
just mvp-dev
```

### Testing

```bash
just web-test            # Web unit tests
just contracts-test      # Contract tests
just svc-test            # Indexer tests

just test-all            # Everything
just mvp-test            # MVP subset only
```

### Pre-commit Checks

```bash
just web-lint && just web-test
just contracts-check
just svc-check

just check-all           # Everything
just mvp-check           # MVP subset only
```

---

## Testing Structure

### Web App

| Test Type | Location | Pattern | Command |
|-----------|----------|---------|---------|
| Unit | `src/**/*.svelte.test.ts` | Co-located | `just web-test` |
| E2E | `e2e/` | Playwright | `just web-test-e2e` |

### Smart Contracts

| Test Type | Location | Pattern | Command |
|-----------|----------|---------|---------|
| Unit | `test/*.t.sol` | Per-contract | `just contracts-test` |
| Integration | `test/Integration.t.sol` | Cross-contract | `just contracts-test` |
| E2E | `test/E2E.t.sol` | Full flows | `just contracts-test` |
| Security | `test/Security.t.sol` | Attack vectors | `just contracts-test` |
| Invariant | `test/arcade/*.Invariant.t.sol` | Property-based | `just contracts-test` |

### Indexer

| Test Type | Location | Pattern | Command |
|-----------|----------|---------|---------|
| Unit | `src/**/*.rs` (inline) | `#[cfg(test)]` | `just svc-test` |
| Integration | `tests/*.rs` | Full flows | `just svc-test` |

---

## Configuration Files

### Root

| File | Purpose |
|------|---------|
| `justfile` | Task runner commands |
| `shell.nix` | Nix development environment |
| `.env.example` | Environment variables template |
| `.envrc` | direnv configuration |

### Web App

| File | Purpose |
|------|---------|
| `svelte.config.js` | SvelteKit configuration |
| `vite.config.ts` | Vite build/test config |
| `wagmi.config.ts` | Contract type generation |
| `playwright.config.ts` | E2E test config |
| `eslint.config.js` | Linting rules |
| `prettier.config.mjs` | Formatting rules |

### Contracts

| File | Purpose |
|------|---------|
| `foundry.toml` | Foundry configuration |
| `remappings.txt` | Import remappings |
| `slither.config.json` | Static analysis config |
| `.solhint.json` | Solidity linting |

### Indexer

| File | Purpose |
|------|---------|
| `Cargo.toml` | Rust dependencies |
| `rust-toolchain.toml` | Rust version (1.85) |
| `rustfmt.toml` | Formatting rules |
| `deny.toml` | Dependency policy |
| `.cargo/config.toml` | Build config (linker) |

---

## TBD Items

Components not yet implemented or requiring additional work:

| Component | Status | Notes |
|-----------|--------|-------|
| Crew contracts | Not started | Social layer on-chain |
| API endpoints | Stub only | `indexer/src/api/` module |
| WebSocket streaming | Architecture only | Iggy publisher ready |
| Leaderboard indexing | Not started | Needs aggregation queries |
| Duel contracts | Implemented | `DuelEscrow.sol` ready |

---

## See Also

- [AGENTS.md](../../AGENTS.md) - Complete monorepo documentation
- [Architecture Blueprint](./architecture.md) - Technical architecture
- [Manifesto](./manifesto.md) - Product vision
- [Capabilities](./capabilities/) - Feature specifications
