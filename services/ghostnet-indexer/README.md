# GHOSTNET Event Indexer

A high-performance Rust-based backend service that indexes blockchain events from the GHOSTNET protocol on MegaETH.

## Features

- **Event Indexing** - Listens to all GHOSTNET smart contract events
- **Data Persistence** - Stores events in TimescaleDB with time-series optimizations
- **Real-time Streaming** - Broadcasts events via Apache Iggy for instant client updates
- **API Layer** - RESTful endpoints for positions, scans, markets, analytics
- **WebSocket Gateway** - Real-time event streaming to connected clients
- **Analytics Engine** - Pre-computed aggregates for dashboards and leaderboards

## Architecture

```
MegaETH RPC
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INDEXER CORE (Rust)                        │
│                                                                 │
│   Block Processor ─▶ Log Decoder ─▶ Event Router ─▶ Handlers   │
│                                                                 │
│              │                │                │                │
│              ▼                ▼                ▼                │
│        TimescaleDB      Apache Iggy      In-Memory Cache       │
│                              │                                  │
│                              ▼                                  │
│                       API Layer (Axum)                          │
│                    REST + WebSocket                             │
└─────────────────────────────────────────────────────────────────┘
```

## Requirements

- Rust 1.85+ (Edition 2024)
- TimescaleDB 2.22+
- Apache Iggy 0.6+
- MegaETH RPC access

## Quick Start

### 1. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your configuration
vim .env
```

### 2. Start Dependencies (Docker)

```bash
docker-compose up -d
```

### 3. Run Migrations

```bash
sqlx migrate run
```

### 4. Start the Indexer

```bash
cargo run -- run
```

## Commands

```bash
# Development
cargo run -- run              # Start indexer
cargo run -- migrate          # Run migrations
cargo run -- backfill --from 0 --to 1000  # Backfill historical data
cargo run -- version          # Show version

# Build
cargo build                   # Debug build
cargo build --release         # Release build

# Test
cargo nextest run             # Run tests (fast)
cargo test                    # Run tests (standard)

# Lint
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --check             # Check formatting
cargo deny check              # Check dependencies
```

## Configuration

Configuration is loaded in layers:
1. `config/default.toml` - Base defaults
2. `config/{APP_ENV}.toml` - Environment-specific (development, staging, production)
3. Environment variables - Final overrides (prefix: `GHOSTNET__`)

### Key Environment Variables

| Variable | Description |
|----------|-------------|
| `APP_ENV` | Environment name (development, staging, production) |
| `DATABASE_URL` | TimescaleDB connection string |
| `GHOSTNET__RPC__URL` | MegaETH HTTP RPC endpoint |
| `GHOSTNET__RPC__WS_URL` | MegaETH WebSocket RPC endpoint |
| `GHOSTNET__INDEXER__CONTRACTS__*` | Contract addresses |

## Project Structure

```
ghostnet-indexer/
├── Cargo.toml              # Dependencies and build config
├── rust-toolchain.toml     # Rust version pinning
├── config/                 # Configuration files
│   ├── default.toml
│   └── development.toml
├── migrations/             # SQL migrations
├── src/
│   ├── main.rs             # CLI entry point
│   ├── lib.rs              # Library root
│   ├── config/             # Configuration loading
│   ├── types/              # Domain types
│   ├── abi/                # Contract ABI bindings
│   ├── indexer/            # Core indexing logic
│   ├── handlers/           # Event handlers
│   ├── store/              # Data persistence
│   ├── streaming/          # Apache Iggy integration
│   └── api/                # REST/WebSocket API
└── tests/                  # Integration tests
```

## Documentation

- [Architecture Spec](../../docs/architecture/backend/indexer-architecture.md) - Full technical specification
- [Implementation Plan](../../docs/architecture/backend/indexer-implementation-plan.md) - Implementation progress tracking

## License

MIT
