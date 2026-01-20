# GHOSTNET Monorepo Agent Instructions

This document provides guidance for AI assistants working with this monorepo project.

## Project Overview

**GHOSTNET** is a real-time survival game on MegaETH. Players "jack in" by staking $DATA tokens, earn yield, survive periodic "trace scans" that can wipe positions, and extract gains. When others die, survivors profit.

**Full game name:** GHOSTNET: The Rabbitz Hole (MegaETH mascot is a rabbit)

### The Game Mechanics

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. JACK IN          Stake $DATA at your chosen risk level    │
│         ↓                                                       │
│   2. EARN             Accumulate yield every second             │
│         ↓                                                       │
│   3. SURVIVE          Don't get traced in the scan              │
│         ↓                                                       │
│   4. EXTRACT          Cash out your gains (or stay for more)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Risk Levels

| Level | Death Rate | Scan Frequency |
|-------|------------|----------------|
| THE VAULT | 0% (safe) | Never |
| MAINFRAME | 2% | 24 hours |
| SUBNET | 15% | 8 hours |
| DARKNET | 40% | 2 hours |
| BLACK ICE | 90% | 30 minutes |

### Mini-Games (reduce death rate)

- **Trace Evasion** — Typing game, up to -35% death rate
- **Hack Runs** — Yield multipliers
- **Dead Pool** — Bet on who lives/dies

---

## Design Aesthetic

GHOSTNET uses a **terminal/hacker aesthetic** with Matrix-like vibes:

- **Colors**: Green phosphor (`#00E5CC`), dark backgrounds, red for danger
- **Typography**: IBM Plex Mono, monospace everything
- **Effects**: CRT scanlines, subtle flicker, screen flashes on events
- **UI**: ASCII borders, terminal-style boxes, typing animations
- **Tone**: Cyberpunk, tense, high-stakes gambling meets hacking

When building UI, maintain this aesthetic. No rounded corners, no gradients, no soft shadows.

---

## Monorepo Structure

This is a **monorepo** containing:
- **Web App** (`apps/web/`): SvelteKit 2.x with Svelte 5 runes, TypeScript, Bun
- **Smart Contracts** (`packages/contracts/`): Foundry-based Solidity with security tooling
- **Services** (`services/`): Backend services (Rust 1.85+, Edition 2024)

```
.
├── apps/
│   └── web/                    # SvelteKit frontend/backend
│       ├── src/
│       │   ├── routes/         # Pages (/, /typing, etc.)
│       │   └── lib/
│       │       ├── core/       # Types, providers, stores, audio, settings
│       │       ├── features/   # Feature modules (feed, typing, welcome, etc.)
│       │       └── ui/         # Design system (primitives, terminal, layout)
│       ├── e2e/
│       └── docs/guides/SvelteBestPractices/  # Includes 28-Web3Integration.md
├── packages/
│   └── contracts/              # Solidity smart contracts
│       ├── src/
│       ├── test/
│       ├── script/
│       └── docs/guides/solidity/
├── services/                   # Backend services
│   └── <service-name>/         # Individual services (Rust, etc.)
│       ├── Cargo.toml
│       ├── rust-toolchain.toml
│       └── src/
├── .opencode/
│   ├── agents/                 # Agent definitions
│   └── skill/                  # Development skills (Rust, etc.)
├── docs/
│   ├── architecture/           # Implementation plan, specs
│   └── product/                # One-pager, product docs
├── shell.nix                   # Combined Nix environment
├── justfile                    # All commands (web-*, contracts-*, svc-*)
└── .github/workflows/          # CI pipeline
```

---

## Environment Setup

### Environment is automatic

When entering this directory, direnv automatically:
1. Loads the Nix shell (Node.js, Bun, Foundry, Slither, Playwright, Rust tooling)
2. Installs Foundry via `foundryup` if needed
3. Installs Solidity LSP and solhint
4. Configures sccache for Rust compilation caching

**You do NOT need to tell the user to:**
- Run `nix-shell`
- Install Foundry manually
- Install npm packages globally

**Prerequisite for Rust services:** rustup must be installed (https://rustup.rs)

### First-time Setup

After cloning, run:

```bash
just install  # Installs web deps + contract deps (forge-std, OpenZeppelin)
```

## Commands Reference

All commands use prefixes to indicate which part of the monorepo they affect:

```bash
just                      # Show all commands

# Top-level
just install              # Install everything
just check-all            # Run all checks
just test-all             # Run all tests
just clean-all            # Clean all artifacts

# Web App (apps/web)
just web-dev              # Start dev server
just web-build            # Build for production
just web-test             # Run unit tests
just web-test-e2e         # Run E2E tests
just web-lint             # Lint code
just web-format           # Format code

# Smart Contracts (packages/contracts)
just contracts-build      # Compile contracts
just contracts-test       # Run tests
just contracts-fmt        # Format code
just contracts-lint       # Run solhint
just contracts-slither    # Static analysis
just contracts-anvil      # Start local node
just contracts-check      # All pre-commit checks

# Services (services/)
just svc-build            # Build all services
just svc-release          # Build release
just svc-test             # Run tests (nextest)
just svc-test-all         # Run tests + doctests
just svc-lint             # Run clippy
just svc-fmt              # Format code
just svc-check            # All pre-commit checks
just svc-deny             # Security/license audit
just svc-audit            # Vulnerability scan
just svc-coverage         # Generate coverage report
just svc-watch            # Watch for changes

# Integration
just generate-types       # Generate TS types from ABIs
just export-abis          # Export ABIs to web app
```

---

## Web App (apps/web)

### Technology Stack

- **Framework**: SvelteKit 2.x with Svelte 5
- **Language**: TypeScript
- **Package Manager**: Bun
- **Testing**: Vitest (Browser Mode) + Playwright E2E

### Key Directories

```
apps/web/src/lib/
├── core/
│   ├── types/           # TypeScript interfaces (Position, FeedEvent, etc.)
│   ├── providers/       # Data providers (mock for now, Web3 later)
│   ├── stores/          # Provider initialization and context
│   ├── settings/        # User preferences (audio, visual effects)
│   └── audio/           # ZzFX sound system
├── features/
│   ├── feed/            # Live event feed
│   ├── position/        # Player position display
│   ├── network/         # Network vitals panel
│   ├── typing/          # Trace Evasion mini-game
│   ├── welcome/         # Onboarding carousel
│   ├── header/          # Header with wallet button
│   ├── nav/             # Navigation bar
│   ├── actions/         # Quick action buttons
│   └── modals/          # JackIn, Extract, Settings modals
└── ui/
    ├── primitives/      # Button, Badge, ProgressBar, etc.
    ├── terminal/        # Shell, Box, Scanlines, Flicker
    ├── data-display/    # AddressDisplay, AmountDisplay, LevelBadge
    └── layout/          # Stack, Row
```

### Svelte 5 Runes

This project uses Svelte 5 runes for reactivity:

```svelte
<script lang="ts">
  // Reactive state
  let count = $state(0);

  // Derived values (computed)
  let doubled = $derived(count * 2);

  // Side effects
  $effect(() => {
    console.log('Count changed:', count);
  });
</script>
```

### Stores (.svelte.ts files)

Rune-based stores must use the `.svelte.ts` extension:

```typescript
// src/lib/stores/counter.svelte.ts
export function createCounter(initial = 0) {
  let count = $state(initial);

  return {
    get count() { return count; },
    get doubled() { return count * 2; },
    increment() { count++; },
  };
}
```

### Component Props

Use `$props()` for typed props:

```svelte
<script lang="ts">
  interface Props {
    name: string;
    count?: number;
    onclick?: () => void;
  }

  let { name, count = 0, onclick }: Props = $props();
</script>
```

### Testing Guidelines

**Critical**: Test files must include `.svelte` in the name for runes to work:

| Pattern | Runes Work? | Use For |
|---------|-------------|---------|
| `*.svelte.test.ts` | Yes | Component & store tests |
| `*.server.test.ts` | No | Server-side logic |
| `*.ssr.test.ts` | No | SSR rendering tests |

### Web App Documentation

See `apps/web/docs/guides/SvelteBestPractices/` for comprehensive Svelte 5 guides:

- **Reactivity** (01-04): State, Derived, Effects
- **Components** (05-08): Props, Snippets, Events, Lifecycle
- **State Management** (09-11): Stores, Context, Collections
- **SvelteKit** (13-17): Data Loading, Forms, SSR
- **Testing** (26-27): Setup, Patterns

---

## Smart Contracts (packages/contracts)

### Technology Stack

- **Framework**: Foundry v1.x (forge, cast, anvil, chisel)
- **Language**: Solidity 0.8.33
- **Security**: Slither static analysis, Solhint linting
- **Dependencies**: OpenZeppelin 5.x, forge-std

### File Structure

```
packages/contracts/
├── src/               # Contract source files
├── test/              # Test files (*.t.sol)
├── script/            # Deployment scripts (*.s.sol)
├── lib/               # Git submodule dependencies
└── docs/guides/       # Solidity development guides
```

### Contract Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MyContract
/// @notice Brief description
contract MyContract is Ownable2Step, ReentrancyGuard {
    // Custom errors (gas efficient)
    error InvalidAmount();
    
    // Events
    event Deposited(address indexed user, uint256 amount);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        emit Deposited(msg.sender, msg.value);
    }
}
```

### Test Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract public target;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    
    function setUp() public {
        vm.prank(owner);
        target = new MyContract(owner);
        vm.deal(user, 100 ether);
    }
    
    function test_Deposit() public {
        vm.prank(user);
        target.deposit{value: 1 ether}();
        assertEq(address(target).balance, 1 ether);
    }
    
    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.prank(user);
        target.deposit{value: amount}();
    }
    
    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user);
        vm.expectRevert(MyContract.InvalidAmount.selector);
        target.deposit{value: 0}();
    }
}
```

### Security Workflow

**CRITICAL**: Always run before committing:

```bash
just contracts-check  # Runs: fmt-check, lint, test, slither-high
```

### Contract Documentation

See `packages/contracts/docs/guides/solidity/` for comprehensive guides:

| Guide | Topics |
|-------|--------|
| [security-fundamentals.md](packages/contracts/docs/guides/solidity/security-fundamentals.md) | Threat modeling, OWASP Top 10 |
| [vulnerabilities.md](packages/contracts/docs/guides/solidity/vulnerabilities.md) | Access control, reentrancy, oracles |
| [modern-solidity.md](packages/contracts/docs/guides/solidity/modern-solidity.md) | 0.8.x features, transient storage |
| [patterns-upgrades.md](packages/contracts/docs/guides/solidity/patterns-upgrades.md) | Design patterns, UUPS proxies |
| [gas-optimization.md](packages/contracts/docs/guides/solidity/gas-optimization.md) | Safe vs dangerous optimizations |
| [testing-deployment.md](packages/contracts/docs/guides/solidity/testing-deployment.md) | Testing strategies, deployment |

---

## Services (services/)

### Technology Stack

- **Language**: Rust 1.85+ (Edition 2024)
- **Toolchain**: rustup via `rust-toolchain.toml`
- **Testing**: cargo-nextest (parallel), proptest (property-based)
- **Security**: cargo-deny, cargo-audit
- **Lints**: Clippy pedantic, forbid unsafe

### File Structure (per service)

```
services/<service-name>/
├── Cargo.toml              # Package manifest
├── rust-toolchain.toml     # Rust version (1.85)
├── rustfmt.toml            # Formatter config
├── deny.toml               # Dependency policy
├── .cargo/
│   └── config.toml         # Build config (fast linker)
├── src/
│   ├── lib.rs              # Library root
│   ├── main.rs             # Binary entry point
│   └── ...
└── tests/                  # Integration tests
```

### Standard Configuration Files

Each Rust service should include these files (see `services/README.md` for templates):

| File | Purpose |
|------|---------|
| `rust-toolchain.toml` | Pins Rust 1.85 with components |
| `rustfmt.toml` | Edition 2024, 100 char width |
| `deny.toml` | License/advisory policy |
| `.cargo/config.toml` | Fast linker (mold/lld) |

### Workspace Lints (Cargo.toml)

Every service should use strict lints:

```toml
[lints.rust]
unsafe_code = "forbid"
missing_debug_implementations = "warn"

[lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
```

### Pre-commit Workflow

**CRITICAL**: Always run before committing Rust code:

```bash
just svc-check  # Runs: fmt-check, lint, test, deny
```

### Rust Development Skills

This project includes comprehensive Rust development guides as skills. **Use these during development** to ensure best practices and modern patterns.

| Skill | Use When |
|-------|----------|
| `rust-project-setup` | Starting projects, configuring workspaces, CI/CD |
| `rust-architecture-patterns` | Designing modules, DI, hexagonal architecture, DDD |
| `rust-implementation-patterns` | Types, errors, async, data structures, memory |
| `rust-web-apis` | Axum, databases, middleware, observability |
| `rust-cli-desktop-systems` | CLI (Clap), TUI (Ratatui), Tauri, FFI, WASM |
| `rust-performance-optimization` | Benchmarking, profiling, optimization |
| `rust-testing-quality` | Testing, mocking, security auditing, production readiness |
| `rust-version-guide` | Rust version changes, migration, Edition 2024 |

### When to Load Which Skill

- **Starting a new service?** → `rust-project-setup`
- **Designing architecture?** → `rust-architecture-patterns`
- **Writing code?** → `rust-implementation-patterns` (most frequent)
- **Building web APIs?** → `rust-web-apis`
- **Building CLI/TUI?** → `rust-cli-desktop-systems`
- **Code is slow?** → `rust-performance-optimization`
- **Writing tests or reviewing?** → `rust-testing-quality`
- **Upgrading Rust version?** → `rust-version-guide`

---

## Web3 Integration

### Connecting Web App to Contracts

See `apps/web/docs/guides/SvelteBestPractices/28-Web3Integration.md` for the complete guide.

**Quick overview:**

1. **Build contracts** to generate ABIs:
   ```bash
   just contracts-build
   ```

2. **Export ABIs** to web app:
   ```bash
   just export-abis
   ```

3. **Generate TypeScript types** (requires wagmi config):
   ```bash
   just generate-types
   ```

4. **Use in Svelte components**:
   ```svelte
   <script lang="ts">
     import { createPublicClient, http } from 'viem';
     import { mainnet } from 'viem/chains';
     import MyContractAbi from '$lib/contracts/abis/MyContract.json';
     
     const client = createPublicClient({
       chain: mainnet,
       transport: http(),
     });
     
     let balance = $state<bigint>(0n);
     
     async function fetchBalance(address: `0x${string}`) {
       balance = await client.readContract({
         address: CONTRACT_ADDRESS,
         abi: MyContractAbi,
         functionName: 'balances',
         args: [address],
       });
     }
   </script>
   ```

### Local Development Workflow

1. **Start local node**:
   ```bash
   just contracts-anvil
   ```

2. **Deploy contracts locally**:
   ```bash
   just contracts-deploy-local
   ```

3. **Start web dev server** (in another terminal):
   ```bash
   just web-dev
   ```

4. **Configure web app** to use localhost:8545

---

## Common Pitfalls

### Web App

1. **Test file naming**: Files without `.svelte` in name won't compile runes
2. **SSR safety**: Don't access `window`/`document` at module level
3. **Derived in tests**: Use `untrack()` when reading `$derived` in assertions

### Smart Contracts

1. **Never commit `.env` files** - Contains private keys
2. **Always use `Ownable2Step`** not `Ownable` - Prevents accidental ownership loss
3. **Use `SafeERC20`** for all token transfers - Handles non-compliant tokens
4. **Avoid `tx.origin`** - Broken by EIP-7702 delegation
5. **Use custom errors** not require strings - Gas efficient

### Integration

1. **Rebuild contracts** after changes before exporting ABIs
2. **Regenerate types** after contract interface changes
3. **Check network** - Ensure web app connects to correct chain (local vs testnet)

---

## Notes for AI Assistants

1. **This is GHOSTNET** - A survival/staking game with terminal aesthetics
2. **This is a monorepo** - Always check which part (web/contracts/services) is being discussed
3. **Use prefixed commands** - `just web-*` for web, `just contracts-*` for contracts, `just svc-*` for services
4. **Environment is automatic** - Don't tell users to install tools manually
5. **Maintain the aesthetic** - Terminal look, green phosphor, no soft UI
6. **Security is paramount** - Always suggest security patterns for contracts
7. **Review the docs/** - Comprehensive guides available in each subproject
8. **Run `just check-all` before commits** - Enforces quality across all projects
9. **Never suggest committing secrets** - .env, private keys, etc.

## Resources

### Web App
- [Svelte 5 Documentation](https://svelte.dev/docs)
- [SvelteKit Documentation](https://svelte.dev/docs/kit)
- [Viem Documentation](https://viem.sh)
- [Wagmi Documentation](https://wagmi.sh)

### Smart Contracts
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts 5.x](https://docs.openzeppelin.com/contracts/5.x)
- [OWASP Smart Contract Top 10](https://scs.owasp.org)
- [Solidity Documentation](https://docs.soliditylang.org)
