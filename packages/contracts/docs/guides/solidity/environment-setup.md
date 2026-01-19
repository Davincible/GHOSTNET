# Environment Setup

A terminal-first, Nix-managed Solidity development environment with Neovim, Foundry v1.5, and professional security tooling.

---

## 1. The Nix Environment

### shell.nix

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  # Foundry from the official nix overlay
  foundry = pkgs.fetchurl {
    url = "https://github.com/foundry-rs/foundry/releases/download/stable/foundry_stable_linux_amd64.tar.gz";
    sha256 = ""; # Run nix-prefetch-url to get this
  };
in
pkgs.mkShell {
  name = "solidity-dev";

  buildInputs = with pkgs; [
    # Core toolchain
    # foundry-bin  # forge, cast, anvil, chisel (use overlay or fetchurl)
    solc          # Solidity compiler (fallback)
    
    # Security tooling
    slither-analyzer  # Static analysis
    mythril           # Symbolic execution
    
    # Node ecosystem (for LSP + solhint)
    nodejs_24
    nodePackages.npm
    
    # Python (for some security tools)
    python312
    python312Packages.pip
    python312Packages.setuptools
    
    # Dev utilities
    jq
    just
    git
  ];

  shellHook = ''
    # Install foundry if not present
    if ! command -v forge &> /dev/null; then
      echo "Installing Foundry..."
      curl -L https://foundry.paradigm.xyz | bash
      foundryup
    fi

    # Install Nomic Foundation LSP globally if not present
    if ! command -v nomicfoundation-solidity-language-server &> /dev/null; then
      echo "Installing Solidity LSP..."
      npm install -g @nomicfoundation/solidity-language-server
    fi

    # Install solhint if not present
    if ! command -v solhint &> /dev/null; then
      echo "Installing solhint..."
      npm install -g solhint
    fi

    export PS1="[sol-dev] $PS1"
    echo "Solidity dev environment loaded."
    echo "  forge $(forge --version 2>/dev/null | head -1 || echo 'not installed')"
  '';
}
```

### Alternative: Flake-based setup (flake.nix)

For reproducible builds across machines:

```nix
{
  description = "Solidity development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/stable";
    solc.url = "github:hellwolf/solc.nix";
  };

  outputs = { self, nixpkgs, flake-utils, foundry, solc }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            foundry.overlay
            solc.overlay
          ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Foundry suite
            foundry-bin
            
            # Pinned solc versions
            solc_0_8_33
            
            # Security
            slither-analyzer
            
            # Node + Python
            nodejs_24
            python312
            
            # Utils
            jq
            just
          ];

          shellHook = ''
            # npm globals
            export PATH="$HOME/.npm-global/bin:$PATH"
            
            # Install LSP + solhint if missing
            npm list -g @nomicfoundation/solidity-language-server &>/dev/null || \
              npm install -g @nomicfoundation/solidity-language-server
            npm list -g solhint &>/dev/null || npm install -g solhint
          '';
        };
      }
    );
}
```

---

## 2. Foundry v1.5 Configuration

Foundry v1.5.1 is the current stable release (supports solc 0.8.31+). Since v1.0 (February 2025), Foundry offers 5.2x faster compilation than Hardhat and 2x faster tests.

### Prague EVM (Pectra Upgrade)

Solidity 0.8.30+ defaults to the **Prague** EVM target. Ensure your toolchain targets Prague for EIP-7702 support:

```bash
# Update Foundry
foundryup

# Verify compiler
solc --version  # Should be 0.8.30+

# Install viem for EIP-7702 transactions
npm install viem@latest
```

### foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.33"
optimizer = true
optimizer_runs = 200
via_ir = false
evm_version = "prague"

# Formatting
[fmt]
line_length = 100
tab_width = 4
bracket_spacing = true
int_types = "long"
multiline_func_header = "params_first"
quote_style = "double"
number_underscore = "thousands"
single_line_statement_blocks = "preserve"

# Testing
[fuzz]
runs = 256
max_test_rejects = 65536
seed = "0x1"
dictionary_weight = 40

[invariant]
runs = 256
depth = 15
fail_on_revert = false
call_override = false
dictionary_weight = 80
include_storage = true
include_push_bytes = true

# Gas reporting
[profile.default.gas_report]
enabled = true
```

### .solhint.json

```json
{
  "extends": "solhint:recommended",
  "plugins": [],
  "rules": {
    "compiler-version": ["error", "^0.8.0"],
    "func-visibility": ["warn", { "ignoreConstructors": true }],
    "max-line-length": ["error", 100],
    "not-rely-on-time": "off",
    "reason-string": ["warn", { "maxLength": 64 }],
    "no-inline-assembly": "off"
  }
}
```

---

## 3. Neovim Configuration

### LSP Setup (lua/plugins/solidity.lua)

Using `lazy.nvim` as package manager:

```lua
return {
  -- LSP config
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Nomic Foundation Solidity LSP
        solidity_ls_nomicfoundation = {
          cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
          filetypes = { "solidity" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
              "foundry.toml",
              "hardhat.config.js",
              "hardhat.config.ts",
              ".git"
            )(fname)
          end,
          single_file_support = true,
        },
      },
    },
  },

  -- Formatting with conform.nvim
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        solidity = { "forge_fmt" },
      },
      formatters = {
        forge_fmt = {
          command = "forge",
          args = { "fmt", "--raw", "-" },
          stdin = true,
        },
      },
    },
  },

  -- Treesitter for syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "solidity" },
    },
  },

  -- Optional: solhint diagnostics via nvim-lint
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        solidity = { "solhint" },
      },
    },
  },
}
```

### Minimal standalone config (init.lua snippet)

If you're not using a Neovim distro:

```lua
-- Solidity LSP
local lspconfig = require("lspconfig")

lspconfig.solidity_ls_nomicfoundation.setup({
  cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
  filetypes = { "solidity" },
  root_dir = lspconfig.util.root_pattern("foundry.toml", ".git"),
  single_file_support = true,
})

-- Format on save with forge fmt
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.sol",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Keymaps for Foundry commands
vim.keymap.set("n", "<leader>ft", "<cmd>!forge test -vvv<CR>", { desc = "Forge test" })
vim.keymap.set("n", "<leader>fb", "<cmd>!forge build<CR>", { desc = "Forge build" })
vim.keymap.set("n", "<leader>ff", "<cmd>!forge fmt<CR>", { desc = "Forge format" })
vim.keymap.set("n", "<leader>fc", "<cmd>!forge coverage<CR>", { desc = "Forge coverage" })
```

---

## 4. Project Structure

```
my-project/
├── src/
│   └── MyContract.sol
├── test/
│   ├── MyContract.t.sol        # Unit tests
│   └── invariants/
│       └── MyContract.invariants.sol
├── script/
│   └── Deploy.s.sol
├── lib/                        # Git submodules
│   ├── forge-std/
│   └── openzeppelin-contracts/
├── foundry.toml
├── shell.nix                   # or flake.nix
├── justfile
├── slither.config.json
├── .solhint.json
└── .github/
    └── workflows/
        └── ci.yml
```

---

## 5. Task Runner (justfile)

```just
# Default recipe
default:
    @just --list

# Build contracts
build:
    forge build

# Run all tests
test:
    forge test -vvv

# Run specific test
test-match pattern:
    forge test --match-test {{pattern}} -vvv

# Format code
fmt:
    forge fmt

# Check formatting (CI)
fmt-check:
    forge fmt --check

# Lint with solhint
lint:
    solhint 'src/**/*.sol' 'test/**/*.sol'

# Static analysis
slither:
    slither . --exclude-informational

# Full security scan
security: slither
    @echo "Running Mythril (this may take a while)..."
    myth analyze src/*.sol --execution-timeout 120 || true

# Coverage report
coverage:
    forge coverage --report lcov

# Gas report
gas:
    forge test --gas-report

# Fuzz with extended runs
fuzz:
    forge test --fuzz-runs 10000

# Invariant tests
invariant:
    forge test --match-contract Invariant

# Start local node
anvil:
    anvil --fork-url $RPC_URL

# Deploy to testnet
deploy-testnet:
    forge script script/Deploy.s.sol --rpc-url $TESTNET_RPC --broadcast --verify

# Clean build artifacts
clean:
    forge clean
    rm -rf cache out
```

---

## 6. CI/CD (GitHub Actions)

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
  FOUNDRY_PROFILE: ci

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1

      - name: Build
        run: forge build --sizes

      - name: Test
        run: forge test -vvv

      - name: Check formatting
        run: forge fmt --check

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1

      - name: Install Slither
        run: pip3 install slither-analyzer

      - name: Run Slither
        run: slither . --exclude-informational --fail-on high
        continue-on-error: false

  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1

      - name: Coverage
        run: forge coverage --report lcov

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./lcov.info
```

---

## 7. AI Workflow Integration

### Claude Code / Aider

For agentic assistance in your Solidity workflow:

```bash
# Aider for iterative refactors
pip install aider-chat
aider src/*.sol test/*.sol --model claude-sonnet-4-20250514

# Or Claude Code
claude-code
```

**Safety rules for AI agents in smart contract repos:**

1. Never let agents touch `.env`, keystores, or deploy keys
2. Run agents in a sandboxed copy for large refactors
3. Require "always add tests" for any contract changes
4. No direct mainnet deploy commands
5. Review all generated code before committing

### Copilot in Neovim

```lua
-- copilot.lua config
{
  "github/copilot.vim",
  event = "InsertEnter",
  config = function()
    vim.g.copilot_filetypes = {
      solidity = true,
    }
  end,
}
```

---

## 8. Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry v1.0 Announcement](https://www.paradigm.xyz/2025/02/announcing-foundry-v1-0)
- [Slither Documentation](https://github.com/crytic/slither/wiki)
- [Nomic Foundation LSP](https://github.com/NomicFoundation/hardhat-vscode)
- [SWC Registry](https://swcregistry.io/) - Smart Contract Weakness Classification
- [solc.nix](https://github.com/hellwolf/solc.nix) - Nix-managed Solidity compilers
- [foundry.nix](https://github.com/shazow/foundry.nix) - Foundry Nix overlay
