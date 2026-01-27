# Lesson: EVM Rust Guide Alignment

**Date**: 2026-01-20  
**Category**: Architecture / Dependencies  
**Severity**: Critical  
**Documents Affected**: `indexer-architecture.md`

## Problem

The indexer architecture document specified outdated dependency versions that would cause compilation failures or API incompatibilities:

| Dependency | Specified | Current Stable |
|------------|-----------|----------------|
| Alloy | 0.9 | 1.4.x |
| Rust MSRV | 1.85 | 1.88 (for Alloy 1.4) |

Additionally, the document used deprecated import patterns and lacked modern WebSocket subscription patterns.

## Root Cause

The indexer architecture was written before Alloy 1.0 stabilized (May 2025). When the EVM Rust Guide was added with January 2026 current versions, the documents were inconsistent.

## Solution

Performed comprehensive cross-reference between `indexer-architecture.md` and `evm-rust-guide.md`:

### 1. Version Updates
- Updated Alloy from `0.9` to `1.4`
- Updated Rust MSRV from `1.85` to `1.88`
- Updated error handling to use `eyre` (Alloy ecosystem standard)
- Removed separate `alloy-sol-types` and `alloy-primitives` (now re-exported from `alloy`)

### 2. Import Pattern Updates
```rust
// BEFORE
use alloy_primitives::{Address, B256, U256};
use alloy_sol_types::sol;

// AFTER
use alloy::primitives::{Address, B256, U256};
use alloy::sol;
```

### 3. Added Block Processor Implementation
Added comprehensive `BlockProcessor` implementation with:
- Alloy 1.4+ WebSocket subscriptions
- Concurrent log fetching with `futures::join_all`
- Historical backfill support
- Provider factory functions

### 4. Enhanced Reorg Handler
Added confirmation depth pattern from EVM guide:
```rust
const CONFIRMATION_DEPTH: u64 = 12;

pub async fn await_confirmations(&self, block_number: u64) -> Result<()> {
    loop {
        let current = self.provider.get_block_number().await?;
        if current.saturating_sub(block_number) >= CONFIRMATION_DEPTH {
            return Ok(());
        }
        sleep(Duration::from_secs(1)).await;
    }
}
```

### 5. Enhanced Caching
Added block hash cache for reorg detection following EVM guide patterns.

## Key Takeaways

1. **Cross-reference new guides immediately**: When adding new reference documentation (like EVM Rust Guide), immediately cross-reference existing specs.

2. **Pin versions with dates**: Always note when versions were captured. The ecosystem moves fast.

3. **Re-exports matter**: Modern crates re-export their dependencies. Check for unnecessary direct dependencies.

4. **WebSocket first**: For real-time indexers, WebSocket subscriptions are the correct pattern, not polling.

## Verification

After applying these updates:
- All imports use `alloy::` prefix consistently
- Cargo.toml specifies Alloy 1.4+ and Rust 1.88+
- Block processor uses WebSocket subscriptions
- Cache includes block hash storage for reorg detection

## Related Documents
- `docs/architecture/backend/indexer-architecture.md` (v2.3.0)
- `docs/architecture/backend/evm-rust-guide.md`
