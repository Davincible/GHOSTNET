# Solidity + SvelteKit Monorepo Development Shell
#
# This shell provides a complete development environment for:
# - SvelteKit web application (Node.js, Bun, Playwright)
# - Solidity smart contracts (Foundry, Slither, Solhint)
#
# Usage:
# - With direnv: just `cd` into the directory (after `direnv allow`)
# - Manual: `nix-shell` then `just install`
#
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "solidity-svelte-monorepo";

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

    # === Welcome Message ===
    echo ""
    echo "Solidity + SvelteKit Monorepo"
    echo "=============================="
    echo ""
    echo "Web App (apps/web):"
    echo "  Node.js: $(node --version)"
    echo "  Bun: $(bun --version)"
    echo ""
    echo "Smart Contracts (packages/contracts):"
    echo "  Forge: $(forge --version 2>/dev/null | head -1 || echo 'run foundryup')"
    echo "  Slither: $(slither --version 2>/dev/null || echo 'available')"
    echo ""
    echo "Run 'just' to see available commands"
    echo "Run 'just install' to set up both projects"
  '';
}
