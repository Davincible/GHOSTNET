# GHOSTNET

```
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗███╗   ██╗███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   ██╔██╗ ██║█████╗     ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║███████╗   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝   
```

**Jack In. Don't Get Traced.**

A real-time survival game on MegaETH where you stake $DATA tokens, earn yield, survive periodic trace scans, and extract gains. When others die, you profit.

---

## The Game

You're a hacker. You jack into a hostile network. You earn yield while you're inside. But every few hours, the system runs a **trace scan**—and if you get caught, you lose everything.

**The deeper you go, the higher the risk, the bigger the rewards.**

| Level | Risk | Death Rate | Potential APY |
|-------|------|------------|---------------|
| THE VAULT | Safe | 0% | 100-500% |
| MAINFRAME | Low | 2% | 1,000% |
| SUBNET | Medium | 15% | 5,000% |
| DARKNET | High | 40% | 20,000% |
| BLACK ICE | Extreme | 90% | ∞ (2x or 0) |

---

## How It Works

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

**Want an edge?** Play mini-games to reduce your death rate:
- **Trace Evasion** — Type fast, reduce death rate up to 35%
- **Hack Runs** — Complete runs for yield multipliers  
- **Dead Pool** — Bet on who lives and dies

---

## Tech Stack

### Web App (`apps/web/`)
- **SvelteKit 2.x** with Svelte 5 runes
- **TypeScript** + **Bun** package manager
- **Vitest** (Browser Mode) + **Playwright** E2E
- **Viem/Wagmi** for Web3 integration
- Terminal/hacker aesthetic with CRT effects

### Smart Contracts (`packages/contracts/`)
- **Foundry** for development and testing
- **Solidity 0.8.33** with OpenZeppelin 5.x
- **Slither** static analysis + **Solhint** linting

### Developer Experience
- **Nix shell** for reproducible environment
- **direnv** for automatic loading
- **Just** task runner

---

## Quick Start

```bash
# 1. Enter directory (direnv auto-loads environment)
cd GHOSTNET

# 2. Install all dependencies
just install

# 3. Start development
just web-dev          # Start web dev server (terminal 1)
just contracts-anvil  # Start local blockchain (terminal 2)
```

---

## Project Structure

```
.
├── apps/
│   └── web/                    # SvelteKit application
│       ├── src/
│       │   ├── routes/         # Pages (/, /typing, etc.)
│       │   └── lib/
│       │       ├── core/       # Types, providers, stores
│       │       ├── features/   # Feature modules (feed, typing, etc.)
│       │       └── ui/         # Design system components
│       └── docs/               # Development guides
│
├── packages/
│   └── contracts/              # Solidity smart contracts
│       ├── src/                # Contract source files
│       ├── test/               # Foundry tests
│       └── docs/               # Security guides
│
├── docs/
│   ├── architecture/           # Implementation plan, specs
│   └── product/                # Product docs, one-pager
│
├── shell.nix                   # Nix development environment
└── justfile                    # All commands
```

---

## Commands

```bash
just                        # Show all commands

# Web App
just web-dev                # Start dev server
just web-build              # Production build
just web-test               # Unit tests
just web-lint               # Lint code

# Smart Contracts
just contracts-build        # Compile contracts
just contracts-test         # Run tests
just contracts-check        # All pre-commit checks (fmt, lint, test, slither)
just contracts-anvil        # Start local node

# Full Stack
just install                # Install everything
just check-all              # Run all checks
just export-abis            # Export ABIs to web app
```

---

## Current Status

The frontend is **95% complete** with mock data:

| Feature | Status |
|---------|--------|
| Command Center (main dashboard) | ✅ Complete |
| Live Feed (real-time events) | ✅ Complete |
| Position & Network Vitals | ✅ Complete |
| Typing Game (Trace Evasion) | ✅ Complete |
| Audio System | ✅ Complete |
| Visual Effects (scanlines, flicker) | ✅ Complete |
| Settings (audio, visual toggles) | ✅ Complete |
| Smart Contracts | 🔲 Not started |

See `docs/architecture/implementation-plan.md` for detailed progress.

---

## Documentation

- **Product**: `docs/product/one-pager.md` - Game overview
- **Architecture**: `docs/architecture/` - Implementation plan, specs
- **Web Guides**: `apps/web/docs/guides/` - Svelte 5 patterns, Web3 integration
- **Contract Guides**: `packages/contracts/docs/guides/` - Security, patterns

---

## Contributing

```bash
# Run ALL checks before committing
just check-all

# Or run separately
just web-lint
just contracts-check
```

---

## Links

- **Website**: [ghostnet.io] (coming soon)
- **Twitter**: [@ghostnet_io]
- **Discord**: [discord.gg/ghostnet]

---

**Play fast. Die young. Or don't die at all.**

*Built on MegaETH. Sub-millisecond. Feels like a video game.*
