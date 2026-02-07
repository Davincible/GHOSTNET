# GHOSTNET Codebase Overview

> *A real-time survival game on MegaETH where players stake, earn, and try not to get traced.*

---

## What Is GHOSTNET?

GHOSTNET is a high-stakes, real-time survival game deployed on MegaETH. Players "jack in" by staking $DATA tokens into one of five risk levels, earn yield every second, and face periodic "trace scans" that can wipe their positions. When others die, survivors profit through a cascade redistribution mechanism.

**Full Name:** GHOSTNET: The Rabbitz Hole (MegaETH's mascot is a rabbit)

### The Game Loop

```
1. JACK IN          Stake $DATA at your chosen risk level
       ↓
2. EARN             Accumulate yield every second
       ↓
3. SURVIVE          Don't get traced in the scan
       ↓
4. EXTRACT          Cash out your gains (or stay for more)
```

### Risk Levels

| Level | Death Rate | Scan Frequency | Description |
|-------|------------|----------------|-------------|
| **THE VAULT** | 0% | Never | Safe haven, no yield |
| **MAINFRAME** | 2% | 24 hours | Conservative, steady returns |
| **SUBNET** | 15% | 8 hours | Moderate risk/reward |
| **DARKNET** | 40% | 2 hours | High stakes, high rewards |
| **BLACK ICE** | 90% | 30 minutes | Extreme gambling, massive yields |

---

## Architecture Philosophy

### Contracts Are Truth

The foundational principle of GHOSTNET: **smart contracts are the sole source of truth**. Everything else—indexers, APIs, web apps—is derived from on-chain state.

```
┌─────────────────────────────────────────────────────────────┐
│                    SOURCE OF TRUTH                          │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │            Smart Contracts (MegaETH)                │   │
│   │                                                     │   │
│   │  • GhostCore.sol    - Game logic, positions        │   │
│   │  • TraceScan.sol    - Scan execution, deaths       │   │
│   │  • DataToken.sol    - ERC20 token                  │   │
│   │  • DeadPool.sol     - Prediction market            │   │
│   │  • FeeRouter.sol    - Protocol fees & buybacks     │   │
│   │  • RewardsDistributor.sol - Yield distribution     │   │
│   └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          │ Events + State                   │
│                          ▼                                  │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Derived/Derived State                  │   │
│   │                                                     │   │
│   │  • ghostnet-indexer  - Event projection            │   │
│   │  • Web App          - UI representation            │   │
│   │  • Analytics        - Aggregated metrics           │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                             │
│   If indexer disagrees with chain → indexer is wrong       │
└─────────────────────────────────────────────────────────────┘
```

### Event-Driven Everything

The system is built on a stream of contract events:

- **JackedIn** - Player enters a level
- **Extracted** - Player exits with gains
- **DeathsProcessed** - Scan eliminated positions
- **CascadeDistributed** - Dead capital redistributed
- **ScanExecuted** - New scan initiated

All services consume this event stream to maintain consistent state.

---

## Monorepo Structure

```
GHOSTNET/
├── apps/
│   └── web/                    # SvelteKit frontend
│       ├── src/
│       │   ├── routes/         # Pages (/, /typing, etc.)
│       │   └── lib/
│       │       ├── core/       # Types, providers, stores
│       │       ├── features/   # Game features
│       │       └── ui/         # Terminal design system
│       ├── e2e/                # Playwright tests
│       └── docs/               # Frontend guides
│
├── packages/
│   └── contracts/              # Solidity smart contracts
│       ├── src/
│       │   ├── core/           # GhostCore, TraceScan
│       │   ├── token/          # DataToken, TeamVesting
│       │   ├── markets/        # DeadPool
│       │   └── periphery/      # FeeRouter
│       ├── test/               # Foundry tests
│       └── docs/               # Solidity guides
│
├── services/                   # Backend services
│   ├── ghostnet-indexer/       # Event indexer + API
│   ├── ghostnet-actions/       # Wallet automation library
│   ├── ghost-fleet/            # Wallet orchestrator
│   ├── crates/                 # Shared Rust crates
│   │   ├── megaeth-rpc/        # MegaETH RPC client
│   │   └── evm-provider/       # Chain abstraction
│   └── README.md               # Service development guide
│
├── docs/
│   ├── blueprint/              # Product documentation
│   │   ├── manifesto.md
│   │   ├── architecture.md
│   │   └── capabilities/
│   ├── design/                 # Technical specs
│   │   ├── contracts/
│   │   ├── arcade/             # Mini-games
│   │   └── services/           # Service architecture
│   ├── work/                   # Sprint tracking
│   ├── integrations/           # Platform guides
│   └── decisions/              # ADRs
│
├── .opencode/
│   └── skill/                  # AI development skills
│       └── rust-*/             # Rust development guides
│
├── shell.nix                   # Nix development environment
├── justfile                    # All project commands
└── AGENTS.md                   # AI assistant instructions
```

---

## Component Deep Dives

### 1. Web App (`apps/web/`)

**Technology Stack:**
- **Framework:** SvelteKit 2.x with Svelte 5 runes
- **Language:** TypeScript
- **Package Manager:** Bun
- **Styling:** Tailwind CSS with custom terminal theme
- **State:** Rune-based stores (`.svelte.ts`)
- **Web3:** Viem + Wagmi
- **Testing:** Vitest (Browser Mode), Playwright E2E

**Key Directories:**

```
src/lib/
├── core/                       # Foundation layer
│   ├── types/                  # TypeScript interfaces
│   ├── providers/              # Data providers (contract reads)
│   ├── stores/                 # Global state management
│   ├── settings/               # User preferences
│   └── audio/                  # ZzFX sound system
│
├── features/                   # Feature modules
│   ├── feed/                   # Live event feed
│   ├── position/               # Player position display
│   ├── network/                # Network vitals
│   ├── typing/                 # Trace Evasion mini-game
│   ├── welcome/                # Onboarding carousel
│   ├── header/                 # Header + wallet button
│   ├── nav/                    # Navigation
│   ├── actions/                # Jack In / Extract buttons
│   └── modals/                 # All modals (JackIn, Extract, Settings)
│
└── ui/                         # Design system
    ├── primitives/             # Button, Badge, ProgressBar
    ├── terminal/               # Shell, Box, Scanlines, Flicker
    ├── data-display/           # AddressDisplay, AmountDisplay
    └── layout/                 # Stack, Row
```

**Design Aesthetic:**

GHOSTNET uses a **terminal/hacker aesthetic** reminiscent of 90s cyberpunk:

- **Colors:** Green phosphor (`#00E5CC`), dark backgrounds, red for danger
- **Typography:** IBM Plex Mono, monospace everything
- **Effects:** CRT scanlines, subtle flicker, screen flashes on events
- **UI:** ASCII borders, terminal-style boxes, typing animations
- **Tone:** Cyberpunk, tense, high-stakes gambling meets hacking

**No rounded corners. No gradients. No soft shadows.**

**Key Patterns:**

```typescript
// Rune-based reactive state
let count = $state(0);
let doubled = $derived(count * 2);

$effect(() => {
  console.log('Count changed:', count);
});

// Props with TypeScript
interface Props {
  name: string;
  count?: number;
  onclick?: () => void;
}

let { name, count = 0, onclick }: Props = $props();
```

---

### 2. Smart Contracts (`packages/contracts/`)

**Technology Stack:**
- **Framework:** Foundry v1.x (forge, cast, anvil, chisel)
- **Language:** Solidity 0.8.33
- **Security:** Slither static analysis, Solhint linting
- **Dependencies:** OpenZeppelin 5.x, forge-std

**Contract Architecture:**

```
src/
├── core/                       # Core game logic
│   ├── GhostCore.sol          # Main staking, positions
│   ├── TraceScan.sol          # Scan execution, death logic
│   └── RewardsDistributor.sol # Yield distribution
│
├── token/                      # Token economics
│   ├── DataToken.sol          # ERC20 with taxes
│   └── TeamVesting.sol        # Vesting schedules
│
├── markets/                    # Prediction markets
│   └── DeadPool.sol           # Bet on scan outcomes
│
└── periphery/                  # Supporting contracts
    ├── FeeRouter.sol          # Fee collection, buybacks
    └── arcade/                # Mini-game contracts
        ├── ArcadeCore.sol
        ├── HashCrash.sol
        └── DailyOps.sol
```

**Key Mechanics:**

**Share-Based Accounting (MasterChef Pattern):**

```solidity
// Instead of iterating all positions to calculate rewards,
// we track accumulated rewards per share
uint256 public accRewardsPerShare;

function pendingRewards(address _user) public view returns (uint256) {
    Position storage position = positions[_user];
    return position.amount * accRewardsPerShare / 1e12 - position.rewardDebt;
}
```

**Cascade Distribution (60/30/10):**

When positions die, their capital is redistributed:
- 30% → Survivors at same level
- 30% → Survivors at upstream levels
- 30% → Burned forever (deflation)
- 10% → Protocol treasury

**Deterministic Death:**

```solidity
function isDead(uint256 seed, address user, uint16 deathRateBps) 
    public pure returns (bool) {
    uint256 random = uint256(keccak256(abi.encodePacked(seed, user)));
    return (random % 10000) < deathRateBps;
}
```

---

### 3. Backend Services (`services/`)

#### 3.1 ghostnet-indexer

**Purpose:** Event ingestion, persistence, and API serving

**Stack:** Rust 1.85+, Tokio, Axum, TimescaleDB, Apache Iggy

**Architecture:** Hexagonal (Ports & Adapters)

```
src/
├── indexer/                    # Core indexing
│   ├── block_processor.rs     # Historical backfill
│   ├── realtime_processor.rs  # WebSocket subscription
│   ├── event_router.rs        # Route 27 event types
│   ├── reorg_handler.rs       # Chain reorg recovery
│   └── checkpoint.rs          # Progress persistence
│
├── handlers/                   # Event handlers (7 domains)
│   ├── position_handler.rs
│   ├── scan_handler.rs
│   ├── death_handler.rs
│   ├── market_handler.rs
│   ├── token_handler.rs
│   ├── fee_handler.rs
│   └── emissions_handler.rs
│
├── ports/                      # Interface definitions
│   ├── store.rs               # Database port
│   ├── streaming.rs           # Message broker port
│   └── cache.rs               # Cache port
│
├── store/                      # Adapters
│   └── postgres.rs            # TimescaleDB implementation
│
├── streaming/                  # Adapters
│   └── iggy_publisher.rs      # Apache Iggy implementation
│
└── api/                        # HTTP layer (to be implemented)
    └── ...
```

**Event Flow:**

```
MegaETH RPC
    │ eth_getLogs / eth_subscribe
    ▼
BlockProcessor / RealtimeProcessor
    │ Raw logs
    ▼
EventRouter
    │ Decoded events (27 types)
    ▼
Handlers (7 domains)
    │ Domain events
    ├────────┬────────┬────────┐
    ▼        ▼        ▼        ▼
TimescaleDB  Iggy   Cache   (future: API)
```

#### 3.2 ghost-fleet

**Purpose:** Autonomous wallet orchestration for simulating organic activity

**Stack:** Rust, fleet-core plugin system

**Concept:** Manages multiple wallets with different "behavior profiles":
- **Conservative Whale** - High stakes, low activity, safe levels
- **Aggressive Degen** - Frequent trades, high-risk levels
- **Social Player** - Crew participation, arcade games

```
┌─────────────────────────────────────────┐
│           ghost-fleet                    │
│  (Main Orchestrator Service)             │
├─────────────────────────────────────────┤
│  Config → Engine → Scheduler → Safety    │
│                │                         │
│                ▼                         │
│  ┌─────────────────────────────────┐    │
│  │     ghostnet-actions (Plugin)  │    │
│  │  • jackIn      • extract       │    │
│  │  • addStake    • claimRewards  │    │
│  │  • hashCrashBet                │    │
│  └─────────────────────────────────┘    │
│                │                         │
│                ▼                         │
│  ┌─────────────────────────────────┐    │
│  │     evm-provider               │    │
│  │  (Chain abstraction)           │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

#### 3.3 ghostnet-actions

**Purpose:** Protocol-specific action library (not a standalone service)

**Pattern:** Implements `ActionPlugin` trait from `fleet-core`

**Key Files:**
- `plugin.rs` - Main plugin implementation
- `contracts.rs` - Contract ABIs and calldata builders
- `actions/ghost_core.rs` - Staking action decisions
- `actions/hashcrash.rs` - Arcade game decisions

---

## Data Flow Examples

### Flow 1: Jack In (Stake)

```
Player
    │ Click "Jack In"
    ▼
Web App
    │ viem: send transaction
    ▼
GhostCore Contract
    │ • Validate inputs
    │ • Transfer tokens
    │ • Emit JackedIn event
    ▼
MegaETH Chain
    │ Block mined
    ▼
ghostnet-indexer
    │ Detect JackedIn event
    │ • Update position in TimescaleDB
    │ • Publish to Iggy topic
    ▼
Web App
    │ WebSocket: receive event
    │ • Update UI
    │ • Play sound effect
    ▼
Player sees confirmation
```

### Flow 2: Trace Scan Execution

```
Keeper Bot (or Gelato)
    │ Call executeScan(level)
    ▼
TraceScan Contract
    │ • Generate seed from prevrandao
    │ • Emit ScanExecuted
    ▼
ghostnet-indexer
    │ • Stream warning to web app
    │ • Start countdown timer
    ▼
Web App (all players at level)
    │ Display scan warning
    │ Play alert sound
    ▼
Keeper Bot
    │ Call submitDeaths(proofs)
    ▼
GhostCore Contract
    │ • Verify death proofs
    │ • Mark positions dead
    │ • Emit DeathsSubmitted
    ▼
ghostnet-indexer
    │ • Update position statuses
    │ • Publish death events
    ▼
Web App
    │ Update feed: "X players traced"
    ▼
Keeper Bot
    │ Call finalizeScan()
    ▼
GhostCore Contract
    │ • Execute cascade distribution
    │ • Emit ScanFinalized
    ▼
ghostnet-indexer
    │ • Update survivor rewards
    │ • Publish cascade event
    ▼
Web App
    │ Update survivor positions
```

---

## Development Workflow

### Environment Setup

The project uses **Nix** for reproducible development environments:

```bash
# Environment loads automatically with direnv
# Or manually:
nix-shell

# Install all dependencies
just install
```

### Key Commands

```bash
# Web App
just web-dev              # Start dev server
just web-build            # Production build
just web-test             # Unit tests
just web-test-e2e         # E2E tests

# Smart Contracts
just contracts-build      # Compile contracts
just contracts-test       # Run tests
just contracts-check      # Full check (fmt, lint, test, slither)
just contracts-anvil      # Start local node

# Services
just svc-build            # Build all services
just svc-test             # Run service tests
just svc-check            # Pre-commit checks

# Integration
just generate-types       # Generate TS types from ABIs
just export-abis          # Export ABIs to web app
```

### Testing Strategy

| Layer | Tool | Purpose |
|-------|------|---------|
| **Contracts** | Foundry | Unit tests, fuzzing, invariant testing |
| **Web Unit** | Vitest | Component logic, store tests |
| **Web E2E** | Playwright | Full user flows |
| **Services** | cargo-nextest | Rust unit/integration tests |
| **Integration** | Custom | Cross-component testing |

---

## Integration Points

### Web3 Integration

```typescript
// Example: Reading position from contract
import { createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import GhostCoreAbi from '$lib/contracts/abis/GhostCore.json';

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
});

async function getPosition(address: `0x${string}`) {
  return await client.readContract({
    address: GHOST_CORE_ADDRESS,
    abi: GhostCoreAbi,
    functionName: 'getPosition',
    args: [address],
  });
}
```

### API Integration (Future)

```typescript
// Example: Fetching from indexer API
async function getLeaderboard(type: 'ghost_streak' | 'value') {
  const response = await fetch(
    `${INDEXER_API}/api/v1/leaderboard?type=${type}`
  );
  return await response.json();
}
```

### WebSocket Integration (Future)

```typescript
// Example: Real-time event stream
const ws = new WebSocket(`${INDEXER_WS}/ws/events`);

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === 'JACK_IN') {
    feedEvents = [msg.data, ...feedEvents];
    playSound('jack_in');
  }
};
```

---

## MegaETH Specifics

GHOSTNET is designed specifically for MegaETH's unique properties:

| Feature | MegaETH Support | Impact |
|---------|----------------|---------|
| **10ms block times** | ✅ | Real-time gameplay impossible on slower chains |
| **Mini-blocks** | ✅ Mainnet | Sub-block finality for instant feedback |
| **EIP-1153 transient storage** | ✅ | Gas optimizations in contracts |
| **Prague EVM** | ✅ | Latest EVM features |
| **Prevrandao** | ✅ | On-chain randomness for scans |

**Testnet RPC:** `https://carrot.megaeth.com/rpc` (Chain ID: 6343)

**Deployment Note:** MegaETH uses MegaEVM which has different gas costs. Always use `--skip-simulation` for Foundry deployments.

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `AGENTS.md` | AI assistant instructions |
| `justfile` | All project commands |
| `shell.nix` | Development environment |
| `docs/blueprint/architecture.md` | System architecture |
| `docs/blueprint/manifesto.md` | Product vision |
| `apps/web/docs/guides/SvelteBestPractices/` | Frontend patterns |
| `packages/contracts/docs/guides/solidity/` | Contract patterns |

---

## Common Pitfalls

### Web App
1. **Test files must include `.svelte`** - Files without `.svelte` in name won't compile runes
2. **SSR safety** - Don't access `window`/`document` at module level
3. **Provider lifecycle** - Properly initialize providers in stores

### Contracts
1. **Never commit `.env`** - Contains private keys
2. **Always use `Ownable2Step`** - Prevents accidental ownership loss
3. **Use `SafeERC20`** - Handles non-compliant tokens
4. **Check MegaETH gas** - Use higher gas limits than standard EVM

### Services
1. **Run in Nix shell** - Environment variables like `RUSTC_WRAPPER` must be set
2. **Don't override linker on macOS** - Use default linker, not lld
3. **Respect workspace lints** - `unsafe_code = "forbid"`, no `unwrap()`

---

## Future Architecture (Ishizue Integration)

The services are migrating to the **Ishizue** microservices framework:

| Current | Future |
|---------|--------|
| `ghostnet-indexer` | `ghostnet-api` (Ishizue service with HTTP + gRPC + WS) |
| `ghost-fleet` (CLI) | `ghostnet-fleet` (Ishizue admin service) |
| N/A | `ghostnet-signer` (New EIP-712 signing service) |

See `docs/design/services/ishizue-integration-plan.md` for full specification.

---

## Contributing

1. **Read the blueprint** - Start with `docs/blueprint/manifesto.md`
2. **Follow the workflow** - Check `docs/workflow/README.md`
3. **Run checks before commit** - `just check-all`
4. **Write tests** - All code must have test coverage
5. **Document decisions** - Create ADRs in `docs/decisions/`

---

## Resources

- **Svelte 5:** https://svelte.dev/docs
- **SvelteKit:** https://svelte.dev/docs/kit
- **Foundry:** https://book.getfoundry.sh/
- **OpenZeppelin:** https://docs.openzeppelin.com/contracts/5.x
- **Viem:** https://viem.sh
- **MegaETH:** See `docs/integrations/megaeth.md`

---

*"The code is the city; the documentation is the zoning law."*

*— Nori, Documentation Steward*
