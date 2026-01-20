# Services

This directory contains backend services for GHOSTNET.

## Overview

Services are language-agnostic backend components. Currently supported:

- **Rust** (1.85+, Edition 2024) - High-performance services

## Creating a New Rust Service

1. Create a new directory: `services/<service-name>/`

2. Initialize with cargo:
   ```bash
   cd services
   cargo init <service-name>
   ```

3. Add standard configuration files:

   | File | Purpose |
   |------|---------|
   | `rust-toolchain.toml` | Pins Rust 1.85 with components |
   | `rustfmt.toml` | Edition 2024, 100 char width |
   | `deny.toml` | License/advisory policy |
   | `.cargo/config.toml` | Fast linker (mold/lld) |

4. Set up `Cargo.toml` with workspace lints (see template below)

## Configuration Templates

### rust-toolchain.toml

```toml
[toolchain]
channel = "1.85"
components = ["rust-src", "rust-analyzer", "clippy", "llvm-tools-preview"]
```

### rustfmt.toml

```toml
edition = "2024"
unstable_features = true
group_imports = "StdExternalCrate"
imports_granularity = "Item"
max_width = 100
```

### deny.toml

```toml
[advisories]
vulnerability = "deny"
unmaintained = "warn"
yanked = "deny"

[licenses]
unlicensed = "deny"
allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "MPL-2.0"]

[bans]
multiple-versions = "warn"
wildcards = "deny"
deny = [{ name = "openssl" }, { name = "openssl-sys" }]

[sources]
unknown-registry = "deny"
unknown-git = "deny"
```

### .cargo/config.toml

```toml
[build]
jobs = 8

[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[target.aarch64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[net]
git-fetch-with-cli = true
```

### Cargo.toml (workspace lints)

```toml
[package]
name = "my-service"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"

[lints.rust]
unsafe_code = "forbid"
missing_debug_implementations = "warn"

[lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"

[profile.release]
lto = "thin"
codegen-units = 1
strip = "symbols"
```

## Commands

```bash
just svc-build      # Build all services
just svc-release    # Build release
just svc-test       # Run tests (nextest)
just svc-test-all   # Run tests + doctests
just svc-lint       # Run clippy
just svc-fmt        # Format code
just svc-check      # Pre-commit checks (fmt, lint, test, deny)
just svc-deny       # Security/license audit
just svc-audit      # Vulnerability scan
just svc-coverage   # Generate coverage report
just svc-watch      # Watch for changes
```

## Best Practices

1. **Never use `unwrap()` in production** - Workspace lints forbid it
2. **Use `thiserror` for error types** - Clear, typed errors
3. **Use `anyhow` for application errors** - Easy context propagation
4. **Prefer `rustls` over OpenSSL** - Pure Rust TLS
5. **Run `just svc-check` before commits** - Enforces quality
6. **Use cargo-nextest for tests** - Faster parallel execution

## Rust Development Skills

Comprehensive guides are available in `.opencode/skill/`:

| Skill | Use When |
|-------|----------|
| `rust-project-setup` | Starting projects, workspaces, CI/CD |
| `rust-architecture-patterns` | DI, hexagonal architecture, DDD |
| `rust-implementation-patterns` | Types, errors, async, memory |
| `rust-web-apis` | Axum, databases, middleware |
| `rust-cli-desktop-systems` | CLI, TUI, Tauri, FFI, WASM |
| `rust-performance-optimization` | Benchmarks, profiling |
| `rust-testing-quality` | Testing, mocking, security |
| `rust-version-guide` | Rust versions, Edition 2024 |
