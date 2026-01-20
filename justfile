# GHOSTNET Monorepo Commands
# Run `just` to see all available commands

# Default: show help
default:
    @just --list --unsorted

# ============================================================================
# TOP-LEVEL COMMANDS
# ============================================================================

# Install all dependencies (web + contracts + services)
install: web-install contracts-init svc-install
    @echo "All dependencies installed!"

# Run all checks (lint, test, security)
check-all: web-lint web-test contracts-check svc-check
    @echo "All checks passed!"

# Run all tests
test-all: web-test contracts-test svc-test-all
    @echo "All tests passed!"

# Clean all build artifacts
clean-all: web-clean contracts-clean svc-clean
    @echo "All build artifacts cleaned!"

# Start development (web dev server + anvil in background)
dev:
    @echo "Starting development environment..."
    @echo "Run 'just web-dev' in one terminal"
    @echo "Run 'just contracts-anvil' in another terminal"

# ============================================================================
# WEB APP COMMANDS (apps/web)
# ============================================================================

# Install web dependencies
[group('web')]
web-install:
    cd apps/web && bun install

# Start web dev server
[group('web')]
web-dev:
    cd apps/web && bun run dev

# Build web app for production
[group('web')]
web-build:
    cd apps/web && bun run build

# Preview production build
[group('web')]
web-preview:
    cd apps/web && bun run preview

# TypeScript type checking
[group('web')]
web-check:
    cd apps/web && bun run check

# TypeScript check (watch mode)
[group('web')]
web-check-watch:
    cd apps/web && bun run check:watch

# Run web unit tests
[group('web')]
web-test:
    cd apps/web && bun run test:unit

# Run web unit tests (watch mode)
[group('web')]
web-test-watch:
    cd apps/web && bun run test:unit:watch

# Run web unit tests with UI
[group('web')]
web-test-ui:
    cd apps/web && bun run test:unit:ui

# Run web unit tests with coverage
[group('web')]
web-test-coverage:
    cd apps/web && bun run test:unit:coverage

# Run E2E tests
[group('web')]
web-test-e2e:
    cd apps/web && bun run test:e2e

# Run E2E tests with UI
[group('web')]
web-test-e2e-ui:
    cd apps/web && bun run test:e2e:ui

# Lint web code
[group('web')]
web-lint:
    cd apps/web && bun run lint

# Format web code
[group('web')]
web-format:
    cd apps/web && bun run format

# Format and lint web code
[group('web')]
web-fix: web-format web-lint

# Clean web build artifacts
[group('web')]
web-clean:
    rm -rf apps/web/.svelte-kit apps/web/build apps/web/node_modules apps/web/coverage apps/web/playwright-report apps/web/test-results

# Fresh web install (clean + install)
[group('web')]
web-fresh: web-clean web-install

# Update web dependencies
[group('web')]
web-update:
    cd apps/web && bun update

# Show outdated web dependencies
[group('web')]
web-outdated:
    cd apps/web && bun outdated

# ============================================================================
# SMART CONTRACT COMMANDS (packages/contracts)
# ============================================================================

# Initialize contracts with forge-std + OpenZeppelin
[group('contracts')]
contracts-init:
    @echo "Initializing Foundry project..."
    cd packages/contracts && forge install foundry-rs/forge-std --no-commit
    cd packages/contracts && forge install OpenZeppelin/openzeppelin-contracts --no-commit
    @echo ""
    @echo "Contracts initialized! Create your first contract in packages/contracts/src/"

# Install/update contract dependencies
[group('contracts')]
contracts-install:
    cd packages/contracts && forge install

# Update contract dependencies
[group('contracts')]
contracts-update:
    cd packages/contracts && forge update

# Build contracts
[group('contracts')]
contracts-build:
    cd packages/contracts && forge build

# Build with size check
[group('contracts')]
contracts-build-sizes:
    cd packages/contracts && forge build --sizes

# Run contract tests
[group('contracts')]
contracts-test:
    cd packages/contracts && forge test -vvv

# Run tests matching a pattern
[group('contracts')]
contracts-test-match pattern:
    cd packages/contracts && forge test --match-test {{pattern}} -vvv

# Run tests for a specific contract
[group('contracts')]
contracts-test-contract contract:
    cd packages/contracts && forge test --match-contract {{contract}} -vvv

# Run fuzz tests with extended runs
[group('contracts')]
contracts-fuzz:
    cd packages/contracts && forge test --fuzz-runs 10000

# Run invariant tests
[group('contracts')]
contracts-invariant:
    cd packages/contracts && forge test --match-path "test/invariants/*" -vvv

# Format contract code
[group('contracts')]
contracts-fmt:
    cd packages/contracts && forge fmt

# Check contract formatting
[group('contracts')]
contracts-fmt-check:
    cd packages/contracts && forge fmt --check

# Lint contracts with solhint
[group('contracts')]
contracts-lint:
    cd packages/contracts && solhint 'src/**/*.sol' 'test/**/*.sol' 'script/**/*.sol'

# Run Slither static analysis
[group('contracts')]
contracts-slither:
    cd packages/contracts && slither . --config-file slither.config.json

# Run Slither (high severity only)
[group('contracts')]
contracts-slither-high:
    cd packages/contracts && slither . --exclude-informational --exclude-low

# Generate Slither report
[group('contracts')]
contracts-slither-report:
    cd packages/contracts && slither . --json slither-report.json

# Full security check
[group('contracts')]
contracts-security: contracts-slither contracts-fuzz
    @echo "Security checks complete."

# Generate coverage report
[group('contracts')]
contracts-coverage:
    cd packages/contracts && forge coverage

# Generate LCOV coverage report
[group('contracts')]
contracts-coverage-lcov:
    cd packages/contracts && forge coverage --report lcov

# Generate gas report
[group('contracts')]
contracts-gas:
    cd packages/contracts && forge test --gas-report

# Start local Anvil node
[group('contracts')]
contracts-anvil:
    anvil

# Start Anvil with mainnet fork
[group('contracts')]
contracts-anvil-fork:
    anvil --fork-url $MAINNET_RPC_URL

# Open Chisel REPL
[group('contracts')]
contracts-chisel:
    chisel

# Deploy to local Anvil
[group('contracts')]
contracts-deploy-local:
    cd packages/contracts && forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (dry run)
[group('contracts')]
contracts-deploy-testnet-dry:
    cd packages/contracts && forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL

# Deploy to testnet
[group('contracts')]
contracts-deploy-testnet:
    cd packages/contracts && forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Verify contract on Etherscan
[group('contracts')]
contracts-verify address contract:
    cd packages/contracts && forge verify-contract {{address}} {{contract}} --chain sepolia

# Clean contract build artifacts
[group('contracts')]
contracts-clean:
    cd packages/contracts && forge clean
    rm -rf packages/contracts/cache packages/contracts/out packages/contracts/broadcast

# Check for outdated dependencies
[group('contracts')]
contracts-outdated:
    @echo "Checking lib/ for updates..."
    @for dir in packages/contracts/lib/*/; do \
        echo "Checking $$dir..."; \
        (cd "$$dir" && git fetch --quiet && git log HEAD..origin/main --oneline 2>/dev/null | head -5) || true; \
    done

# Generate remappings file
[group('contracts')]
contracts-remappings:
    cd packages/contracts && forge remappings > remappings.txt

# Run all contract pre-commit checks
[group('contracts')]
contracts-check: contracts-fmt-check contracts-lint contracts-test contracts-slither-high
    @echo "All contract checks passed!"

# ============================================================================
# INTEGRATION COMMANDS
# ============================================================================

# Generate TypeScript types from contract ABIs (requires wagmi CLI)
[group('integration')]
generate-types:
    @echo "Generating TypeScript types from contract ABIs..."
    cd apps/web && bunx wagmi generate
    @echo "Types generated in apps/web/src/lib/contracts/"

# Export contract ABIs to web app
[group('integration')]
export-abis:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Exporting ABIs to web app..."
    mkdir -p apps/web/src/lib/contracts/abis
    contracts=("DataToken" "GhostCore" "TraceScan" "DeadPool" "RewardsDistributor" "FeeRouter" "TeamVesting")
    for name in "${contracts[@]}"; do
        src="packages/contracts/out/${name}.sol/${name}.json"
        if [ -f "$src" ]; then
            jq '.abi' "$src" > "apps/web/src/lib/contracts/abis/${name}.json"
            echo "  Exported: ${name}.json"
        else
            echo "  Warning: $src not found"
        fi
    done
    echo "ABIs exported to apps/web/src/lib/contracts/abis/"

# Full integration sync: build contracts, export ABIs, generate types
[group('integration')]
sync-contracts: contracts-build export-abis generate-types
    @echo "Contract integration complete!"

# ============================================================================
# SERVICES COMMANDS (services/)
# ============================================================================

# Install/check services dependencies
[group('services')]
svc-install:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo fetch; \
    else \
        echo "No services to install yet. Create a service in services/"; \
    fi

# Build all services (debug)
[group('services')]
svc-build:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo build; \
    else \
        echo "No services to build yet."; \
    fi

# Build all services (release)
[group('services')]
svc-release:
    cd services && cargo build --release

# Build release with locked dependencies (for CI/deployment)
[group('services')]
svc-release-locked:
    cd services && cargo build --release --locked

# Check code without building (faster feedback)
[group('services')]
svc-check-code:
    cd services && cargo check

# Run tests with nextest (fast, parallel)
[group('services')]
svc-test:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo nextest run; \
    else \
        echo "No services to test yet."; \
    fi

# Run doc tests (nextest doesn't support these)
[group('services')]
svc-test-doc:
    cd services && cargo test --doc

# Run all tests (nextest + doctests)
[group('services')]
svc-test-all: svc-test svc-test-doc

# Run tests with retries for flaky tests
[group('services')]
svc-test-retry:
    cd services && cargo nextest run --retries 2

# Run tests with coverage
[group('services')]
svc-coverage:
    cd services && cargo llvm-cov nextest --lcov --output-path lcov.info

# Run tests with HTML coverage report
[group('services')]
svc-coverage-html:
    cd services && cargo llvm-cov nextest --html

# Run clippy
[group('services')]
svc-lint:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo clippy --all-features -- -D warnings; \
    else \
        echo "No services to lint yet."; \
    fi

# Run clippy and fix issues
[group('services')]
svc-lint-fix:
    cd services && cargo clippy --all-features --fix --allow-dirty

# Format code (requires nightly)
[group('services')]
svc-fmt:
    cd services && cargo +nightly fmt

# Check formatting without changing files
[group('services')]
svc-fmt-check:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo +nightly fmt --check; \
    else \
        echo "No services to check formatting yet."; \
    fi

# Run cargo-deny checks (licenses, advisories, sources)
[group('services')]
svc-deny:
    @if [ -d "services" ] && [ -n "$(ls -A services 2>/dev/null)" ]; then \
        cd services && cargo deny check; \
    else \
        echo "No services to audit yet."; \
    fi

# Run security audit
[group('services')]
svc-audit:
    cd services && cargo audit

# Check for outdated dependencies
[group('services')]
svc-outdated:
    cd services && cargo outdated

# Find unused dependencies
[group('services')]
svc-unused:
    cd services && cargo machete

# Update all dependencies
[group('services')]
svc-update:
    cd services && cargo update

# Pre-commit checks (run before committing)
[group('services')]
svc-check: svc-fmt-check svc-lint svc-test svc-deny

# CI checks (full validation)
[group('services')]
svc-ci: svc-fmt-check svc-lint svc-test-all svc-deny svc-audit

# Clean build artifacts
[group('services')]
svc-clean:
    @if [ -d "services" ]; then \
        cd services && cargo clean 2>/dev/null || true; \
    fi

# Watch for changes and run checks
[group('services')]
svc-watch:
    cd services && cargo watch -x check -x test

# Build documentation
[group('services')]
svc-doc:
    cd services && cargo doc

# Build and open documentation
[group('services')]
svc-doc-open:
    cd services && cargo doc --open

# Run benchmarks
[group('services')]
svc-bench:
    cd services && cargo bench

# Generate flamegraph
[group('services')]
svc-flamegraph BIN:
    cd services && cargo flamegraph --bin {{BIN}}

# Show sccache stats
[group('services')]
svc-sccache-stats:
    sccache --show-stats

# Add a dependency to a service
[group('services')]
svc-add SERVICE CRATE:
    cd services/{{SERVICE}} && cargo add {{CRATE}}

# Show dependency tree
[group('services')]
svc-tree:
    cd services && cargo tree

# Show duplicate dependencies
[group('services')]
svc-tree-dupes:
    cd services && cargo tree --duplicates
