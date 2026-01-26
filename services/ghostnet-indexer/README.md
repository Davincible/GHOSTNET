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

- Rust 1.88+ (Edition 2024)
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
│   │   ├── block_processor.rs     # Standard + cursor-based backfill
│   │   ├── megaeth_rpc.rs         # MegaETH-specific RPC client
│   │   ├── realtime_processor.rs  # WebSocket subscriptions
│   │   └── event_router.rs        # Event dispatch
│   ├── handlers/           # Event handlers
│   ├── store/              # Data persistence
│   ├── streaming/          # Apache Iggy integration
│   └── api/                # REST/WebSocket API
└── tests/                  # Integration tests
```

## MegaETH-Specific Features

MegaETH executes transactions within 10ms and generates 1 year of Ethereum data every 5 days at 1000 TPS. This indexer includes optimizations for MegaETH's unique characteristics.

### Cursor-Based Pagination (`eth_getLogsWithCursor`)

Standard `eth_getLogs` can timeout on large block ranges. The indexer supports MegaETH's `eth_getLogsWithCursor` API for efficient backfill:

```rust
use ghostnet_indexer::indexer::{BlockProcessor, MegaEthRpcClient};

// Create MegaETH-specific client
let megaeth = MegaEthRpcClient::new("https://6343.rpc.thirdweb.com")?;

// Configure block processor with cursor support
let processor = BlockProcessor::new(provider, contracts, tx)?
    .with_megaeth_client(Arc::new(megaeth));

// Use auto-selection for best available method
processor.backfill_auto(1_000_000, 2_000_000).await?;

// Or explicitly use cursor-based pagination
processor.backfill_with_cursor(1_000_000, 2_000_000).await?;
```

### RPC Provider Selection

> **Important**: See [docs/lessons/megaeth-rpc-endpoints.md](../../docs/lessons/megaeth-rpc-endpoints.md) for comprehensive testing results.

#### MAINNET (Chain ID 4326)

| Endpoint | HTTP | WebSocket | miniBlocks | stateChanges |
|----------|------|-----------|------------|--------------|
| `mainnet.megaeth.com/rpc` | **YES** | **YES** | **YES** | **YES** |
| `staging-mainnet.rpc.megaeth.com/rpc` | **YES** | **YES** | **YES** | Untested |

**MAINNET has full Realtime API support!** All WebSocket subscriptions work.

#### TESTNET (Chain ID 6343)

| Endpoint | HTTP | WebSocket | miniBlocks | stateChanges |
|----------|------|-----------|------------|--------------|
| `carrot.megaeth.com/rpc` | Flaky* | **BROKEN** | NO | NO |
| `timothy.megaeth.com/rpc` | Flaky* | **BROKEN** | NO | NO |
| Alchemy | **YES** | NO | N/A | N/A |
| Tatum | **YES** | NO | N/A | N/A |

*Flaky = Frequent 502/504 errors under load

**Critical Finding**: Testnet public WebSocket accepts connections and confirms subscriptions, but **NEVER streams any data**. Only `eth_chainId` works.

**Recommendations**:
- **Testnet HTTP**: Use Alchemy (`megaeth-testnet.g.alchemy.com`) for reliability
- **Testnet Real-time**: Fall back to HTTP polling (WebSocket is broken)
- **Mainnet**: Full Realtime API available at `mainnet.megaeth.com`

### MegaETH Realtime API Features

| Feature | Testnet | Mainnet | Notes |
|---------|---------|---------|-------|
| `eth_getLogsWithCursor` | **YES** | **YES** | Cursor-based log pagination |
| `realtime_sendRawTransaction` | **YES** | **YES** | Send + receipt in one call |
| `logs` (pending) | **BROKEN** | **YES** | Real-time log streaming |
| `miniBlocks` | **BROKEN** | **YES** | Mini blocks every ~10ms with tx + receipts |
| `stateChanges` | **BROKEN** | **YES** | Account state monitoring |
| `newHeads` | **BROKEN** | **YES** | Block header streaming |

### Mini Block Data Structure

**Note**: The actual API response differs from documentation:

```json
{
  "block_number": 6220303,       // EVM block number (integer, not hex)
  "block_timestamp": 1769017314, // Unix seconds (integer, not hex)
  "index": 5,                    // Index within EVM block
  "number": 582850614,           // Mini block number (docs say "mini_block_number")
  "timestamp": 1769017313054,    // Microseconds (docs say "mini_block_timestamp")
  "gas_used": 656348,
  "transactions": [...],
  "receipts": [...]
}
```

### Backfill Performance

| Method | 100 Blocks | 10,000 Blocks |
|--------|------------|---------------|
| Standard batched | ~5 sec | May timeout |
| Cursor pagination | ~2 sec | ~30 sec |

Cursor pagination is **critical** for ranges over 1,000 blocks on MegaETH.

## Documentation

- [Architecture Spec](../../docs/architecture/backend/indexer-architecture.md) - Full technical specification
- [Implementation Plan](../../docs/architecture/backend/indexer-implementation-plan.md) - Implementation progress tracking

## License

MIT
