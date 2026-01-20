---
name: rust-project-setup
description: Project initialization, workspace configuration, and build setup for Rust. Use when starting new projects, creating workspace structures, configuring Cargo.toml, setting up CI/CD pipelines, choosing Rust edition/MSRV, configuring lints, or optimizing compile times.
---

# Rust Project Setup

This guide covers project initialization, workspace configuration, and build setup for Rust projects. It reflects the current stable toolchain (Rust 1.85+, Edition 2024) as of February 2025.

## 1. Quick Start Decision Tree

### Single Crate vs Workspace

```
Start Here
    │
    ▼
┌─────────────────────────────────────────┐
│ Do you have multiple binaries sharing   │
│ common code, or clear domain boundaries?│
└─────────────────────────────────────────┘
    │                    │
   YES                  NO
    │                    │
    ▼                    ▼
┌──────────────┐   ┌──────────────────────┐
│ WORKSPACE    │   │ SINGLE CRATE         │
│              │   │                      │
│ - Multiple   │   │ - Small/medium libs  │
│   binaries   │   │ - Single binary apps │
│ - Plugin     │   │ - Tightly coupled    │
│   systems    │   │   functionality      │
│ - Separate   │   │                      │
│   versioning │   │ Use modules for      │
└──────────────┘   │ internal structure   │
                   └──────────────────────┘
```

**Key insight**: Module structure within crates prevents coupling better than workspace granularity for most applications. Start with single-crate organization using modules; migrate to workspaces only when truly justified.

### Edition Selection

| Scenario | Edition | Notes |
|----------|---------|-------|
| New project (2025+) | 2024 | Full async closures, new lifetime rules |
| Existing project | Run `cargo fix --edition` | Automatic migration available |
| Maximum compatibility | 2021 | If you must support older toolchains |

### MSRV Selection by Project Type

| Project Type | Recommended MSRV | Rationale |
|--------------|------------------|-----------|
| Library (broad use) | 1.75+ | Async trait support, wide ecosystem compatibility |
| Application | 1.85+ | Edition 2024, async closures, latest features |
| Embedded | 1.75+ | Async trait support, stable embedded ecosystem |
| Enterprise | 1.80+ | Security patches, LTS-style stability |

---

## 2. Edition 2024 & Language Evolution

### Rust 1.85 / Edition 2024 (Stable February 2025)

The 2024 Edition is the largest Rust edition ever released. Key features:

**Async Closures** - The most requested feature:
```rust
// Async closures can borrow from their environment
let mut vec: Vec<String> = vec![];
let closure = async || {
    vec.push(ready(String::from("hello")).await);
};

// New AsyncFn traits for higher-ranked signatures
async fn takes_async_fn(f: impl for<'a> AsyncFn(&'a u8)) {
    f(&42).await;
}
```

**New Lifetime Capture Rules** - Simpler `impl Trait`:
```rust
// Edition 2024: All input lifetimes captured by default
async fn process(data: &str) -> impl Future<Output = ()> {
    // No more + '_ needed!
}

// Opt-out with use<> syntax when needed
fn returns_static() -> impl Trait + use<> {
    // Captures no lifetimes
}
```

**Native Async Traits** - No more `#[async_trait]` macro:
```rust
trait Service {
    async fn call(&self, req: Request) -> Response;  // Native async in traits
}
```

**Let Chains** - Flatten nested conditionals:
```rust
if let Some(user) = get_user()
    && user.is_active
    && let Some(email) = user.email
    && email.contains("@company.com")
{
    send_internal_notification(&email);
}
```

**RPITIT (Return Position Impl Trait in Traits)** - Stable since 1.75:
```rust
trait Container {
    fn iter(&self) -> impl Iterator<Item = &u32>;  // Works in traits
}
```

### Migration from Edition 2021

```bash
# Update your toolchain
rustup update stable

# Run the automatic migration
cargo fix --edition

# Update Cargo.toml: edition = "2021" -> edition = "2024"
```

**Key migration considerations:**

| Change | Impact | Action Required |
|--------|--------|-----------------|
| RPIT lifetime capture | `impl Trait` captures all in-scope lifetimes | Use `use<'a, T>` to be explicit |
| `unsafe extern` blocks | `extern` blocks require `unsafe` keyword | Add `unsafe` to extern blocks |
| `if let` temporary scope | Temporaries drop earlier | Review extended lifetime dependencies |
| Unsafe attributes | `#[no_mangle]` requires `unsafe(...)` | Wrap in `#[unsafe(no_mangle)]` |
| Reserved syntax | `gen` keyword reserved | Rename any `gen` identifiers |

**RPIT Lifetime Changes (Important!):**
```rust
// 2021 Edition - captures only mentioned lifetimes
fn foo<'a>(x: &'a str, y: &str) -> impl Sized { x }
// Only captures 'a, not the lifetime of y

// 2024 Edition - captures ALL in-scope lifetimes
fn foo<'a>(x: &'a str, y: &str) -> impl Sized { x }
// Captures both lifetimes!

// To opt out in 2024, use explicit capture syntax:
fn foo<'a>(x: &'a str, y: &str) -> impl Sized + use<'a> { x }
```

---

## 3. Project Structure Patterns

### Single Crate Structure

For small to medium projects:

```
my-project/
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml
├── .cargo/
│   └── config.toml
├── src/
│   ├── main.rs           # or lib.rs
│   ├── config.rs
│   ├── error.rs
│   ├── domain.rs         # File-based module (Rust 2018+ style)
│   ├── domain/
│   │   ├── user.rs
│   │   └── order.rs
│   ├── services.rs
│   └── services/
│       ├── auth.rs
│       └── payment.rs
├── tests/
│   └── integration_test.rs
└── benches/
    └── benchmark.rs
```

**File-based vs mod.rs modules** - Prefer file-based (Rust 2018+ style):
```
# Preferred (file-based)        # Legacy (mod.rs)
src/                            src/
├── domain.rs                   ├── domain/
├── domain/                     │   ├── mod.rs
│   ├── user.rs                 │   ├── user.rs
│   └── order.rs                │   └── order.rs
```

In `lib.rs`:
```rust
mod domain;
mod services;

pub use domain::{User, Order};
pub use services::{AuthService, PaymentService};
```

In `domain.rs`:
```rust
mod user;
mod order;

pub use user::User;
pub use order::Order;
```

**When single crate is enough:**
- Small to medium libraries
- Single binary applications
- Tightly coupled functionality where splitting adds ceremony without benefit

### Flat Workspace Pattern

Modern large Rust projects standardize on **flat crate layouts**, not nested hierarchies. rust-analyzer (200,000+ lines) exemplifies this approach:

```
my-project/
├── Cargo.toml              # Workspace root
├── Cargo.lock              # Shared lockfile
├── rust-toolchain.toml     # Pin toolchain version
├── .cargo/
│   └── config.toml         # Workspace-wide cargo config
├── crates/
│   ├── core/               # Domain logic, zero/minimal deps
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── domain/     # Business entities
│   │       ├── ports/      # Trait definitions (interfaces)
│   │       └── error.rs
│   ├── app/                # Application/orchestration layer
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── services/   # Use case implementations
│   │       └── config.rs
│   ├── infra/              # Infrastructure adapters
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── db/         # Database implementations
│   │       ├── http/       # HTTP clients
│   │       └── fs/         # File system
│   └── cli/                # or `api/`, `server/`
│       ├── Cargo.toml
│       └── src/
│           └── main.rs
├── tests/                  # Integration tests
│   └── integration/
└── benches/                # Benchmarks
```

**Why flat wins over nested:**

1. Cargo's namespace is flat - you can't have hierarchical crate names like `hir::def`
2. Adding or splitting crates requires zero restructuring
3. Prevents deterioration that happens with hierarchies (catch-all "utils" folders)
4. Until you exceed ~1 million lines of code, all crates fit on one screen
5. No complex hierarchy navigation for developers

### Workspace Cargo.toml Template

```toml
[workspace]
resolver = "2"
members = ["crates/*"]

[workspace.package]
version = "0.1.0"
edition = "2024"
rust-version = "1.85"
license = "MIT OR Apache-2.0"
repository = "https://github.com/org/project"
authors = ["Your Name <your@email.com>"]

[workspace.dependencies]
# Centralize ALL dependency versions here
thiserror = "2.0"
anyhow = "1.0"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["full"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Internal crates (reference by path)
my-core = { path = "crates/core" }
my-app = { path = "crates/app" }
my-infra = { path = "crates/infra" }

[workspace.lints.rust]
unsafe_code = "forbid"
missing_docs = "warn"

[workspace.lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
# Specific overrides
module_name_repetitions = "allow"
must_use_candidate = "allow"
```

---

## 4. Cargo.toml Patterns

### Member Crate Template

```toml
[package]
name = "my-core"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true
repository.workspace = true

[lints]
workspace = true

[dependencies]
thiserror.workspace = true
serde.workspace = true

# Crate-specific dependency with override
tokio = { workspace = true, features = ["rt", "macros"] }

[dev-dependencies]
tokio = { workspace = true, features = ["test-util"] }
```

### Dependency Specification

**Version requirements:**
```toml
[dependencies]
# Caret (default) - compatible updates
serde = "1.0"           # Same as ^1.0, allows 1.x.y where x >= 0
serde = "1.0.100"       # Allows 1.0.100 to 1.x.y

# Tilde - more restrictive
tokio = "~1.0"          # Allows 1.0.x only

# Exact version (avoid unless necessary)
critical-dep = "=1.2.3" # Only this exact version

# Range
some-crate = ">=1.0, <2.0"
```

**Feature selection:**
```toml
[dependencies]
# Specific features
tokio = { version = "1.0", features = ["rt-multi-thread", "macros", "time"] }

# Disable default features
serde = { version = "1.0", default-features = false, features = ["derive"] }

# All features (rarely appropriate)
regex = { version = "1.0", features = ["full"] }
```

**Optional dependencies:**
```toml
[dependencies]
# Optional - only compiled when feature is enabled
opentelemetry = { version = "0.22", optional = true }

[features]
default = []
telemetry = ["dep:opentelemetry"]
```

### Feature Flags Architecture

**The additive-only principle:** Features must only add functionality, never remove it. Enabling a feature should never break code that works without it.

```toml
[features]
# Minimal by default - users opt into what they need
default = []

# Aggregate features for convenience
full = ["runtime", "serialization", "logging"]

# Individual features
runtime = ["tokio/rt-multi-thread"]
serialization = ["serde", "serde_json"]
logging = ["tracing", "tracing-subscriber"]

# Testing feature (not in default)
test-utils = []

[dependencies]
tokio = { version = "1.0", optional = true }
serde = { version = "1.0", optional = true }
serde_json = { version = "1.0", optional = true }
tracing = { version = "0.1", optional = true }
tracing-subscriber = { version = "0.3", optional = true }
```

**Feature organization patterns:**
```toml
[features]
# Backend selection (mutually exclusive in practice)
postgres = ["sqlx/postgres"]
sqlite = ["sqlx/sqlite"]
mysql = ["sqlx/mysql"]

# Capability flags
async = ["tokio"]
sync = []  # Synchronous API always available

# Integration features
serde = ["dep:serde", "uuid/serde", "time/serde"]
```

---

## 5. Build Profiles

### Development Profile

Optimized for fast iteration:

```toml
[profile.dev]
opt-level = 0            # No optimization for your code
debug = true             # Full debug info
incremental = true       # Incremental compilation
codegen-units = 256      # Maximum parallelism (slower final, faster incremental)
lto = false              # No link-time optimization

# Key trick: Optimize dependencies even in dev mode
# This dramatically improves runtime performance during development
[profile.dev.package."*"]
opt-level = 2            # Optimize all dependencies
```

The `[profile.dev.package."*"]` setting is crucial - it means your debug builds run dependencies (like `regex`, `serde`, cryptographic libraries) at near-release speed while your own code compiles fast for iteration.

### Release Profile

```toml
[profile.release]
opt-level = 3            # Maximum optimization
lto = "thin"             # Link-time optimization (good balance)
codegen-units = 1        # Single codegen unit (max optimization)
strip = true             # Remove symbols from binary
panic = "abort"          # Abort on panic (smaller binary)
debug = false            # No debug info
```

**LTO options explained:**

| Setting | Build Time | Binary Size | Runtime Speed |
|---------|-----------|-------------|---------------|
| `lto = false` | Fastest | Largest | Baseline |
| `lto = "thin"` | Moderate | Smaller | Faster |
| `lto = "fat"` | Slowest | Smallest | Fastest |

- Use `"thin"` for most projects (good balance)
- Use `"fat"` only when binary size or maximum performance is critical
- Use `false` during development

**Codegen units:** Setting `codegen-units = 1` enables maximum optimization but increases compile time. Only use in release.

**Strip options:**
```toml
strip = true             # Remove all symbols
strip = "symbols"        # Same as true
strip = "debuginfo"      # Remove debug info only
strip = "none"           # Keep everything
```

### Custom Profiles

**Profiling profile** - release performance with debug symbols:
```toml
[profile.profiling]
inherits = "release"
debug = true             # Keep debug info for profilers
strip = false            # Don't strip symbols
```

Use with: `cargo build --profile profiling`

**Release with debug info** - for debugging release builds:
```toml
[profile.release-debug]
inherits = "release"
debug = 2                # Full debug info
strip = false
lto = "thin"             # Keep thin LTO for reasonable build times
```

**Benchmark profile:**
```toml
[profile.bench]
inherits = "release"
lto = "fat"              # Maximum optimization for accurate benchmarks
codegen-units = 1
```

---

## 6. Compile Time Optimization

### Linker Selection

The linker is often the bottleneck in Rust builds. Modern alternatives are significantly faster.

**.cargo/config.toml:**
```toml
# Linux: Use mold (fastest, 2-5x faster than default)
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

# macOS: Use lld
[target.x86_64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.aarch64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

# Windows: Use lld-link
[target.x86_64-pc-windows-msvc]
linker = "lld-link"
```

**Installing linkers:**
```bash
# Linux - mold
sudo apt install mold          # Debian/Ubuntu
sudo dnf install mold          # Fedora
brew install mold              # macOS (though lld preferred)

# Cross-platform - lld (comes with LLVM)
sudo apt install lld           # Debian/Ubuntu
brew install llvm              # macOS
```

### Cranelift Backend

For development builds, Cranelift provides 25-40% faster compilation at the cost of runtime performance:

```bash
# Install the Cranelift component
rustup component add rustc-codegen-cranelift-preview --toolchain nightly

# Use for development builds
CARGO_PROFILE_DEV_CODEGEN_BACKEND=cranelift cargo +nightly build
```

**When to use:** Development only. Never for release builds or benchmarks.

**In rust-toolchain.toml:**
```toml
[toolchain]
channel = "nightly"
components = ["rustc-codegen-cranelift-preview"]
```

### Incremental Compilation

```toml
# .cargo/config.toml
[build]
incremental = true       # Enable incremental compilation (default for dev)

# Environment variables
[env]
CARGO_INCREMENTAL = "1"
```

**Tradeoffs:**
- Faster rebuilds after small changes
- Uses more disk space (cache files)
- Occasional issues with cache corruption (run `cargo clean` if builds behave oddly)

### Build Tools

**cargo-hakari** - Workspace dependency unification (up to 50% faster builds):

cargo-hakari creates a "workspace-hack" crate that unifies feature resolution across workspace crates, eliminating redundant builds.

```bash
cargo install cargo-hakari

# Initialize in your workspace
cargo hakari init            # Creates workspace-hack crate

# Generate unified dependencies
cargo hakari generate        # Updates workspace-hack/Cargo.toml

# Add workspace-hack as dependency to all crates
cargo hakari manage-deps

# Verify setup
cargo hakari verify
```

Add to CI to ensure it stays in sync:
```yaml
- run: cargo hakari verify
```

**sccache** - Distributed compilation cache:
```bash
cargo install sccache

# Set as Rust compiler wrapper
export RUSTC_WRAPPER=sccache

# For CI with S3 backend
export SCCACHE_BUCKET=my-ci-cache
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

**cargo-machete** - Find unused dependencies:
```bash
cargo install cargo-machete

cargo machete              # Fast regex-based detection
cargo machete --fix        # Remove unused deps automatically
```

**Build time analysis:**
```bash
# Generate HTML timing report
cargo build --timings

# Detailed phase timings (nightly)
cargo +nightly rustc -- -Z time-passes

# Find monomorphization bloat
cargo install cargo-llvm-lines
cargo llvm-lines | head -20
```

### Build Parallelism

```toml
# .cargo/config.toml
[build]
jobs = 8                 # Parallel crate compilation (default: num CPUs)
```

Or via environment:
```bash
export CARGO_BUILD_JOBS=8
```

### Windows Dev Drive

Windows 11 Dev Drive provides 20-30% faster builds by optimizing for development workloads:

```powershell
# Move cargo home and target to Dev Drive (e.g., D:)
$env:CARGO_HOME = "D:\cargo"
$env:CARGO_TARGET_DIR = "D:\target"
```

---

## 7. Toolchain Configuration

### rust-toolchain.toml

Pin your project's toolchain for reproducibility:

```toml
[toolchain]
channel = "1.85.0"       # Specific version for reproducibility
# channel = "stable"     # Or use rolling stable
# channel = "nightly"    # For nightly features

components = [
    "rustfmt",
    "clippy",
    "rust-analyzer",
    "rust-src",          # Required for rust-analyzer go-to-definition
]

targets = [
    "x86_64-unknown-linux-gnu",
    "aarch64-apple-darwin",
    "wasm32-unknown-unknown",  # If targeting WebAssembly
]

profile = "default"      # Or "minimal" for CI
```

**Channel options:**
- `"1.85.0"` - Exact version (recommended for applications)
- `"stable"` - Latest stable (good for libraries)
- `"nightly"` - Latest nightly
- `"nightly-2025-01-15"` - Specific nightly date

### .cargo/config.toml

Project-wide Cargo configuration:

```toml
[build]
jobs = 8                           # Parallel compilation jobs
rustflags = ["-C", "target-cpu=native"]  # Optimize for local CPU

# Faster linker (Linux)
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

# Faster linker (macOS)
[target.x86_64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.aarch64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

# Environment variables for build scripts
[env]
SOME_BUILD_VAR = "value"
DATABASE_URL = { value = "postgres://localhost/dev", force = true }

# Cargo aliases
[alias]
b = "build"
t = "test"
r = "run"
c = "check"
cl = "clippy"
br = "build --release"
rr = "run --release"
w = "watch -x check -x test"
```

**Useful aliases:**
```toml
[alias]
# Development workflow
dev = "watch -x check -x 'test --lib'"
lint = "clippy --all-targets --all-features -- -D warnings"

# Testing
ta = "test --all-features"
tn = "test -- --nocapture"

# Documentation
doc = "doc --no-deps --open"
doca = "doc --all-features --no-deps --open"

# Audit
audit = "audit --deny warnings"
```

---

## 8. Linting Configuration

### Clippy Configuration

**In Cargo.toml (recommended):**
```toml
[lints.clippy]
# Enable lint groups
all = "warn"
pedantic = "warn"
nursery = "warn"

# Deny dangerous patterns
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"

# Allow specific pedantic lints that are too noisy
module_name_repetitions = "allow"
must_use_candidate = "allow"
missing_errors_doc = "allow"
missing_panics_doc = "allow"

# Security-focused
# mem_forget = "deny"      # Uncomment if you want to forbid mem::forget
```

**In workspace root:**
```toml
[workspace.lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
```

Member crates inherit with:
```toml
[lints]
workspace = true
```

**Per-crate overrides:**
```toml
[lints]
workspace = true

[lints.clippy]
# This crate has valid panic reasons
panic = "allow"
```

**Rust lints:**
```toml
[lints.rust]
unsafe_code = "forbid"           # No unsafe anywhere
missing_docs = "warn"            # Require documentation
unused_must_use = "deny"         # Must handle Results
rust_2024_compatibility = "warn" # Migration lints
```

### Rustfmt Configuration

Create `rustfmt.toml` in your project root:

```toml
# Stable options
edition = "2024"
max_width = 100
tab_spaces = 4
newline_style = "Auto"
use_small_heuristics = "Default"

# Unstable options (require nightly rustfmt)
# Uncomment if using nightly
# unstable_features = true
# imports_granularity = "Crate"
# group_imports = "StdExternalCrate"
# format_code_in_doc_comments = true
# wrap_comments = true
```

**Team conventions to document:**

1. Line length: 100 characters (rustfmt default)
2. Imports: Group by std, external, internal (use `group_imports` on nightly)
3. Comments: Keep under line limit, wrap manually if needed

---

## 9. CI/CD Pipeline Templates

### GitHub Actions Workflow

**.github/workflows/ci.yml:**
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always
  RUSTFLAGS: -D warnings

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --all-targets --all-features

  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --all-features

  fmt:
    name: Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt
      - run: cargo fmt --all --check

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo clippy --all-targets --all-features -- -D warnings

  docs:
    name: Docs
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo doc --no-deps --all-features
        env:
          RUSTDOCFLAGS: -D warnings
```

### Matrix Testing (Multiple OS and Rust Versions)

```yaml
test:
  name: Test (${{ matrix.os }}, ${{ matrix.rust }})
  runs-on: ${{ matrix.os }}
  strategy:
    fail-fast: false
    matrix:
      os: [ubuntu-latest, macos-latest, windows-latest]
      rust: [stable, beta]
      include:
        - os: ubuntu-latest
          rust: "1.75"  # MSRV
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@master
      with:
        toolchain: ${{ matrix.rust }}
    - uses: Swatinem/rust-cache@v2
      with:
        key: ${{ matrix.os }}-${{ matrix.rust }}
    - run: cargo test --all-features
```

### Caching Strategies

```yaml
# Using Swatinem/rust-cache (recommended)
- uses: Swatinem/rust-cache@v2
  with:
    # Cache key prefix
    prefix-key: "v1-rust"
    # Additional paths to cache
    cache-directories: |
      ~/.cargo/bin/
      ~/.cargo/registry/index/
      ~/.cargo/registry/cache/
      ~/.cargo/git/db/
    # Shared cache key (useful for workspaces)
    shared-key: "workspace"
    # Save cache even if job fails
    save-if: ${{ github.ref == 'refs/heads/main' }}
```

### Security Scanning

```yaml
security:
  name: Security Audit
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@stable
    - run: cargo install cargo-audit cargo-deny
    - run: cargo audit
    - run: cargo deny check

# Or use the dedicated action
security:
  name: Security Audit
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: rustsec/audit-check@v1
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
```

### Release Automation

**Using cargo-release:**
```bash
cargo install cargo-release

# In Cargo.toml
[package.metadata.release]
allow-branch = ["main"]
sign-commit = true
sign-tag = true
push = true
publish = true

# Dry run
cargo release patch --dry-run

# Actual release
cargo release patch  # or minor, major
```

**.github/workflows/release.yml:**
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    name: Release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo publish
        env:
          CARGO_REGISTRY_TOKEN: ${{ secrets.CARGO_REGISTRY_TOKEN }}
```

---

## 10. Development Environment

### rust-analyzer Configuration

**.vscode/settings.json:**
```json
{
    "rust-analyzer.cargo.features": "all",
    "rust-analyzer.check.command": "clippy",
    "rust-analyzer.check.allTargets": true,
    "rust-analyzer.procMacro.enable": true,
    "rust-analyzer.imports.granularity.group": "crate",
    "rust-analyzer.imports.prefix": "self",
    "rust-analyzer.inlayHints.parameterHints.enable": true,
    "rust-analyzer.inlayHints.typeHints.enable": true,
    "rust-analyzer.lens.enable": true,
    "rust-analyzer.lens.run.enable": true,
    "rust-analyzer.lens.debug.enable": true
}
```

**Project-specific rust-analyzer.json** (alternative to VS Code settings):
```json
{
    "cargo": {
        "features": "all",
        "buildScripts": {
            "enable": true
        }
    },
    "check": {
        "command": "clippy",
        "allTargets": true
    },
    "procMacro": {
        "enable": true
    }
}
```

### VS Code Setup

**Recommended extensions:**
- rust-analyzer (official)
- Even Better TOML
- Error Lens
- CodeLLDB (for debugging)
- crates (dependency version hints)

**.vscode/extensions.json:**
```json
{
    "recommendations": [
        "rust-lang.rust-analyzer",
        "tamasfe.even-better-toml",
        "usernamehw.errorlens",
        "vadimcn.vscode-lldb",
        "serayuzgur.crates"
    ]
}
```

**.vscode/launch.json** (debugging):
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lldb",
            "request": "launch",
            "name": "Debug Binary",
            "cargo": {
                "args": ["build", "--bin=my-app", "--package=my-app"],
                "filter": {
                    "name": "my-app",
                    "kind": "bin"
                }
            },
            "args": [],
            "cwd": "${workspaceFolder}"
        },
        {
            "type": "lldb",
            "request": "launch",
            "name": "Debug Unit Tests",
            "cargo": {
                "args": ["test", "--no-run", "--lib", "--package=my-core"],
                "filter": {
                    "name": "my-core",
                    "kind": "lib"
                }
            },
            "args": [],
            "cwd": "${workspaceFolder}"
        }
    ]
}
```

### Recommended Dev Tools

**Essential tools:**
```bash
# Install via cargo
cargo install cargo-watch      # Auto-rebuild on changes
cargo install cargo-nextest    # Faster test runner (up to 3x)
cargo install cargo-machete    # Find unused dependencies
cargo install cargo-audit      # Security vulnerability scanner
cargo install cargo-deny       # License and advisory checker
cargo install cargo-hakari     # Workspace dependency unification
cargo install cargo-release    # Release automation
cargo install cargo-expand     # Macro expansion viewer
cargo install cargo-udeps      # Find unused dependencies (more thorough)

# Formatting and linting (installed via rustup)
rustup component add rustfmt clippy
```

**Usage examples:**
```bash
# Watch for changes and run checks
cargo watch -x check

# Watch and run tests
cargo watch -x test

# Fast parallel test execution
cargo nextest run

# With retries for flaky tests
cargo nextest run --retries 2

# Find unused dependencies (fast)
cargo machete

# Security audit
cargo audit

# Check licenses and advisories
cargo deny check

# Expand macros to see generated code
cargo expand --lib path::to::module
```

---

## Quick Reference

### New Project Checklist

1. Create project structure (single crate or workspace)
2. Set edition to 2024
3. Configure rust-toolchain.toml with pinned version
4. Set up .cargo/config.toml with fast linker
5. Configure workspace lints in Cargo.toml
6. Create rustfmt.toml
7. Set up CI workflow
8. Install cargo-hakari if using workspace

### Minimal Cargo.toml (Application)

```toml
[package]
name = "my-app"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"

[dependencies]
# Your dependencies

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
all = "warn"
pedantic = "warn"
unwrap_used = "deny"
```

### Minimal rust-toolchain.toml

```toml
[toolchain]
channel = "1.85"
components = ["rustfmt", "clippy", "rust-analyzer"]
```

### Minimal .cargo/config.toml

```toml
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[alias]
lint = "clippy --all-targets --all-features -- -D warnings"
```

---

See also:
- `rust-architecture-patterns.md` for module organization and architectural patterns
- `rust-error-handling.md` for error types and Result patterns
- `rust-async-guide.md` for async runtime configuration
