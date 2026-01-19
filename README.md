# Solidity + SvelteKit Monorepo Template

A modern full-stack Web3 development template combining:
- **SvelteKit 2.x** with Svelte 5 runes for the frontend/backend
- **Foundry** for Solidity smart contract development
- **Nix** for reproducible development environment

## Features

### Web App (apps/web)
- **Svelte 5** with runes (`$state`, `$derived`, `$effect`)
- **SvelteKit 2** for full-stack TypeScript development
- **Bun** as package manager
- **Vitest** with Browser Mode for component testing
- **Playwright** for E2E testing
- **ESLint + Prettier** for code quality

### Smart Contracts (packages/contracts)
- **Foundry** - Fast compilation, testing, deployment
- **Slither** - Static security analysis
- **Solhint** - Linting and best practices
- **OpenZeppelin 5.x** - Security primitives
- **GitHub Actions** - CI with security gates

### Developer Experience
- **Nix shell** - Reproducible environment (no manual installs)
- **direnv** - Automatic environment loading
- **Just** - Task runner with organized commands

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

## Project Structure

```
.
├── apps/
│   └── web/                    # SvelteKit application
│       ├── src/
│       │   ├── routes/         # SvelteKit routes
│       │   └── lib/
│       │       ├── components/ # Svelte components
│       │       ├── stores/     # Rune-based stores (.svelte.ts)
│       │       └── contracts/  # Generated contract types & ABIs
│       ├── e2e/                # Playwright E2E tests
│       └── docs/guides/        # Svelte 5 best practices + Web3 integration
│
├── packages/
│   └── contracts/              # Solidity smart contracts
│       ├── src/                # Contract source files
│       ├── test/               # Foundry tests (*.t.sol)
│       ├── script/             # Deployment scripts (*.s.sol)
│       ├── lib/                # Git submodule dependencies
│       └── docs/guides/        # Solidity security guides
│
├── shell.nix                   # Nix development environment
├── justfile                    # All commands
└── .github/workflows/          # CI pipeline
```

## Commands

All commands use prefixes for clarity:

```bash
just                        # Show all commands

# Top-level
just install                # Install everything
just check-all              # Run all checks (lint, test, security)
just test-all               # Run all tests
just clean-all              # Clean all artifacts

# Web App
just web-dev                # Start dev server
just web-build              # Production build
just web-test               # Unit tests
just web-test-e2e           # E2E tests
just web-lint               # Lint code
just web-format             # Format code

# Smart Contracts
just contracts-build        # Compile contracts
just contracts-test         # Run tests
just contracts-fmt          # Format code
just contracts-lint         # Solhint linting
just contracts-slither      # Static analysis
just contracts-anvil        # Start local node
just contracts-check        # All pre-commit checks

# Integration
just export-abis            # Export ABIs to web app
just generate-types         # Generate TypeScript types
```

## Development Workflow

### 1. Smart Contract Development

```bash
# Start local blockchain
just contracts-anvil

# Write contracts in packages/contracts/src/
# Write tests in packages/contracts/test/

# Run tests
just contracts-test

# Deploy locally
just contracts-deploy-local

# Run security checks
just contracts-check
```

### 2. Web App Development

```bash
# Start dev server
just web-dev

# After contract changes, export ABIs
just export-abis
just generate-types  # If using wagmi

# Run tests
just web-test
just web-test-e2e
```

### 3. Integration

See `apps/web/docs/guides/SvelteBestPractices/28-Web3Integration.md` for connecting the web app to contracts using viem/wagmi.

## Testing

### Web App Tests

| Test Type | File Pattern | Run Command |
|-----------|--------------|-------------|
| Component | `*.svelte.test.ts` | `just web-test` |
| Server | `*.server.test.ts` | `just web-test` |
| E2E | `e2e/*.test.ts` | `just web-test-e2e` |

**Important**: Use `.svelte.test.ts` for files that use Svelte 5 runes.

### Contract Tests

```bash
just contracts-test              # All tests
just contracts-test-match "Deposit"  # Match pattern
just contracts-fuzz              # Extended fuzz testing
just contracts-coverage          # Coverage report
```

## Security

### Pre-commit Checks

```bash
# Run ALL checks before committing
just check-all

# Or run separately
just web-lint
just contracts-check  # fmt, lint, test, slither
```

### Contract Security Checklist

- [ ] All tests pass (`just contracts-test`)
- [ ] No high Slither findings (`just contracts-slither-high`)
- [ ] Fuzz tests pass (`just contracts-fuzz`)
- [ ] Access control reviewed
- [ ] Reentrancy paths checked

See `packages/contracts/docs/guides/solidity/` for comprehensive security guides.

## Environment Setup

### Prerequisites

- [Nix](https://nixos.org/download.html) (recommended: Determinate installer)
- [direnv](https://direnv.net/)

### How It Works

The `shell.nix` provides:
- Node.js 22 LTS
- Bun package manager
- Foundry toolchain (forge, cast, anvil)
- Slither analyzer
- Playwright browsers
- Solidity LSP and solhint

When you `cd` into the directory with direnv enabled, everything is ready.

### Manual Setup (without direnv)

```bash
nix-shell
just install
```

## Documentation

### Web App
- `apps/web/docs/guides/SvelteBestPractices/` - Svelte 5 patterns
- [Svelte 5 Docs](https://svelte.dev/docs)
- [SvelteKit Docs](https://svelte.dev/docs/kit)

### Smart Contracts
- `packages/contracts/docs/guides/solidity/` - Security & patterns
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin 5.x](https://docs.openzeppelin.com/contracts/5.x)

### Integration
- `apps/web/docs/guides/SvelteBestPractices/28-Web3Integration.md` - Connecting web to contracts
- [Viem Docs](https://viem.sh)
- [Wagmi Docs](https://wagmi.sh)

## License

MIT
