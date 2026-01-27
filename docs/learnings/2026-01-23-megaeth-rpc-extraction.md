# MegaETH RPC Crate Extraction

**Date**: 2026-01-23  
**Phase**: Ghost Fleet Phase 1  
**Status**: Completed

## Summary

Extracted MegaETH-specific RPC functionality from `ghostnet-indexer` into a standalone, reusable crate `megaeth-rpc` that can be shared across services.

## Key Changes

### New Workspace Structure

Created `services/Cargo.toml` as workspace root with:
- Shared dependencies (alloy, tokio, serde, etc.)
- Workspace-wide lint configuration
- Workspace metadata

```
services/
├── Cargo.toml                    # Workspace root
├── crates/
│   └── megaeth-rpc/              # NEW: Shared MegaETH client
└── ghostnet-indexer/             # Updated to use megaeth-rpc
```

### megaeth-rpc Crate

Created comprehensive MegaETH client crate with:

1. **Cursor-based pagination** (`eth_getLogsWithCursor`)
   - Automatic multi-batch fetching
   - Configurable batch limits
   - Graceful fallback detection

2. **Realtime API** (`realtime_sendRawTransaction`)
   - Instant receipt return (~10ms)
   - No polling required

3. **Well-typed errors** (`MegaEthError`)
   - `is_method_not_supported()` for fallback logic
   - `is_retryable()` for retry decisions
   - Clear categorization (network, protocol, data, usage)

4. **Configuration** (`ClientConfig`)
   - Timeout configuration (1-300s)
   - Max cursor batches (1-10,000)
   - Builder pattern

5. **30 unit tests** covering all functionality

### Indexer Updates

- Added `megaeth-rpc` as workspace dependency
- Updated `BlockProcessor` to use `MegaEthClient` (renamed from `MegaEthRpcClient`)
- Added error conversion from `MegaEthError` to `AppError`
- Removed duplicate code (`src/indexer/megaeth_rpc.rs`)
- All 253 existing tests still pass

## Design Decisions

### 1. Renamed client type

Changed `MegaEthRpcClient` to `MegaEthClient`:
- Cleaner, shorter name
- "RPC" is implied for an RPC client
- Better module path: `megaeth_rpc::MegaEthClient`

### 2. Error type hierarchy

```rust
MegaEthError -> InfraError::MegaEth -> AppError::Infra
```

This allows:
- `?` operator works transparently in indexer code
- Preserves error context
- Easy to add to any service using megaeth-rpc

### 3. Re-export from workspace

The indexer re-exports types for backward compatibility:
```rust
pub use megaeth_rpc::{FetchStats, MegaEthClient};
```

Existing documentation references work without changes.

### 4. Separate hex dependency

Added `hex = "0.4"` to workspace dependencies rather than relying on alloy's hex utilities, for clarity and simpler import paths.

## Testing Notes

- Library tests: `cargo test -p ghostnet-indexer --lib` (253 tests)
- Integration tests require: `cargo test -p ghostnet-indexer --features test-utils`
- megaeth-rpc tests: `cargo test -p megaeth-rpc` (30 tests)

## Files Changed

### Created
- `services/Cargo.toml` (workspace root)
- `services/crates/megaeth-rpc/Cargo.toml`
- `services/crates/megaeth-rpc/README.md`
- `services/crates/megaeth-rpc/src/lib.rs`
- `services/crates/megaeth-rpc/src/client.rs`
- `services/crates/megaeth-rpc/src/config.rs`
- `services/crates/megaeth-rpc/src/error.rs`
- `services/crates/megaeth-rpc/src/types.rs`

### Modified
- `services/ghostnet-indexer/Cargo.toml` (workspace deps, lint inheritance)
- `services/ghostnet-indexer/src/indexer/mod.rs` (removed megaeth_rpc module)
- `services/ghostnet-indexer/src/indexer/block_processor.rs` (use new crate)
- `services/ghostnet-indexer/src/error.rs` (add MegaEthError conversion)

### Deleted
- `services/ghostnet-indexer/src/indexer/megaeth_rpc.rs` (moved to crate)

## Next Steps

Phase 2: Create `evm-provider` crate with chain abstraction traits:
- `ChainProvider` trait for basic operations
- `ExtendedChainProvider` for MegaETH-specific features
- `MegaEthProvider` wrapping megaeth-rpc
- `StandardEvmProvider` using alloy
