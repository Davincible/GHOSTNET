# GHOSTNET Monorepo Development Shell
#
# This shell provides a complete development environment for:
# - SvelteKit web application (Node.js, Bun, Playwright)
# - Solidity smart contracts (Foundry, Slither, Solhint)
# - Rust services (cargo tooling via Nix, toolchain via rustup)
#
# Usage:
# - With direnv: just `cd` into the directory (after `direnv allow`)
# - Manual: `nix-shell` then `just install`
#
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "ghostnet-monorepo";

  buildInputs = with pkgs; [
    # === Node.js Ecosystem ===
    nodejs_22          # LTS for compatibility
    bun                # Fast package manager for web app

    # === Python (for Slither) ===
    python312
    python312Packages.pip
    python312Packages.setuptools

    # === Security Tools ===
    slither-analyzer   # Solidity static analysis

    # === Testing ===
    playwright-driver.browsers  # E2E browser binaries

    # === Rust Ecosystem ===
    # Rust toolchain is managed by rustup via rust-toolchain.toml
    # Ensure rustup is installed: https://rustup.rs

    # Build optimization tools
    sccache            # Compilation caching
    mold               # Faster linker (Linux)
    lld                # LLVM linker (macOS/fallback)

    # Cargo extensions
    cargo-nextest      # Faster test runner
    cargo-deny         # Dependency policy enforcement
    cargo-llvm-cov     # Code coverage
    cargo-audit        # Security vulnerability scanning
    cargo-outdated     # Check for outdated dependencies
    cargo-machete      # Find unused dependencies
    cargo-flamegraph   # Flamegraph generation
    cargo-benchcmp     # Compare benchmark results
    cargo-watch        # Watch for changes and run commands

    # === Development Utilities ===
    just               # Command runner
    jq                 # JSON manipulation
    git
  ];

  shellHook = ''
    # === Playwright Setup ===
    export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

    # === NPM Global Setup (for Solidity LSP + solhint) ===
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
    mkdir -p "$NPM_CONFIG_PREFIX"

    # === Foundry Setup ===
    if ! command -v forge &> /dev/null; then
      echo "Installing Foundry..."
      curl -L https://foundry.paradigm.xyz | bash
      export PATH="$HOME/.foundry/bin:$PATH"
      foundryup
    else
      export PATH="$HOME/.foundry/bin:$PATH"
    fi

    # === Solidity LSP Setup ===
    if ! command -v nomicfoundation-solidity-language-server &> /dev/null; then
      echo "Installing Solidity LSP..."
      npm install -g @nomicfoundation/solidity-language-server
    fi

    # === Solhint Setup ===
    if ! command -v solhint &> /dev/null; then
      echo "Installing solhint..."
      npm install -g solhint
    fi

    # === Rust/sccache Setup ===
    export SCCACHE_CACHE_SIZE="10G"
    export SCCACHE_DIR="$HOME/.cache/sccache"
    
    # CRITICAL: Override TMPDIR for sccache to use a stable temp directory
    # Nix sets TMPDIR to /private/tmp/nix-shell-XXX which gets cleaned up
    # This causes sccache failures with "Failed to create temp dir"
    export TMPDIR="$HOME/.cache/sccache/tmp"
    mkdir -p "$TMPDIR"
    
    export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
    
    # Stop any existing sccache server (uses old TMPDIR)
    ${pkgs.sccache}/bin/sccache --stop-server 2>/dev/null || true

    # === Welcome Message ===
    echo ""
    echo "GHOSTNET Monorepo"
    echo "================="
    echo ""
    echo "Web App (apps/web):"
    echo "  Node.js: $(node --version)"
    echo "  Bun: $(bun --version)"
    echo ""
    echo "Smart Contracts (packages/contracts):"
    echo "  Forge: $(forge --version 2>/dev/null | head -1 || echo 'run foundryup')"
    echo "  Slither: $(slither --version 2>/dev/null || echo 'available')"
    echo ""
    echo "Services (services/):"
    if command -v rustup &> /dev/null; then
      echo "  Rust: $(rustc --version 2>/dev/null || echo 'will install on first cargo command')"
    else
      echo "  Rust: Install rustup from https://rustup.rs"
    fi
    echo "  sccache: enabled (''${SCCACHE_CACHE_SIZE} cache)"
    echo ""
    echo "Run 'just' to see available commands"
    echo "Run 'just install' to set up all projects"
  '';
}
