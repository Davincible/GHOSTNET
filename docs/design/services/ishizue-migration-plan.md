# GHOSTNET Ishizue Migration Plan

**Date:** 2026-02-07  
**Status:** Draft — Architecture Review  
**Companion:** [`ishizue-integration-plan.md`](./ishizue-integration-plan.md) — API contracts, proto definitions

---

## WE BUILD ISHIZUE

**GHOSTNET's team is the team that builds the Ishizue framework.** This is not a third-party dependency — it's our own framework. GHOSTNET is one of the first real-world services built on Ishizue, and it serves as a proof-of-concept to validate the framework and its developer experience.

**What this means in practice:**

- **Never work around framework limitations.** If Ishizue doesn't support something we need, or if the DX is bad, we fix Ishizue. Not later — now. The whole point of building GHOSTNET on Ishizue is to find these gaps.
- **Document every friction point.** If scaffolding is confusing, if code generation produces something unexpected, if testing utilities are missing a feature — log it. These are framework bugs, not application problems.
- **The feedback loop is the product.** Every issue we hit here becomes an improvement in Ishizue that benefits every future user. We are our own first customer.
- **No workarounds, no shims, no "we'll fix the framework later."** If something is wrong, we fix it at the source. The Ishizue source lives at `/Users/tyler/Launchpad/IshizueOrg/ishizue/`.

**Ishizue issue log:** Track framework issues discovered during this migration in `docs/learnings/ishizue-framework-issues.md`. Each entry should include: what we tried, what went wrong, and whether we fixed it upstream or it's pending.

---

## Premise

Ishizue is the foundation. If we were starting GHOSTNET's backend today, we'd run `ishizue init` and build from there. The fact that we wrote some services before Ishizue existed doesn't change what the optimal architecture looks like — it just means we have source code to reference and cherry-pick from.

**What we have that's valuable:**
- Domain types — `Level`, `TokenAmount`, `EthAddress`, `Position`, `Scan`, `Death`, etc.
- Port traits — `PositionStore`, `ScanStore`, `DeathStore`, etc.
- Postgres adapter — TimescaleDB implementation
- Ingestion engine — block processor, event router, reorg handler
- Contract ABIs — Alloy bindings for all GHOSTNET contracts
- Fleet infrastructure — `fleet-core`, `evm-provider`, `megaeth-rpc`
- Action plugin — `ghostnet-actions`
- Existing integration tests — store, reorg detection, full-flow event pipeline

**What we're throwing away:**
- The old workspace layout
- The old `Cargo.toml` structure
- The hand-wired Axum HTTP layer (commented out, incomplete)
- The old `main.rs` wiring

---

## Testing Philosophy

Tests exist to catch real breakage, not to hit coverage numbers. Every test should answer the question: *"If this test fails, what real-world scenario is broken?"*

**Three levels, each with a clear purpose:**

| Level | What it proves | When it runs | Ishizue tooling |
|-------|---------------|-------------|-----------------|
| **Unit** | Domain logic is correct in isolation (math, state transitions, validation) | Every build (`cargo test`) | `TestContext`, `TestRequest` |
| **Integration** | Service handlers + adapters work with real infrastructure | On commit, CI | `TestHarness`, `ContainerFixture` (Postgres), `MockTransport` |
| **End-to-end** | Multiple services collaborate correctly; real HTTP/gRPC calls work | Pre-deploy, CI | `TestHarness` with multiple services on ephemeral ports |

**What we test at each step:**

- After cherry-picking domain types → unit tests prove the types behave correctly (roundtrip conversions, validation, state transitions)
- After wiring a handler → integration test proves the handler returns correct data from a real Postgres
- After wiring ingestion → integration test proves events flow from fake chain data → handler → DB → query
- After wiring service-to-service → e2e test proves fleet can call api and get real position data

**What we don't test:**

- Ishizue framework internals (code generation, routing, context plumbing)
- "Doesn't panic" assertions without checking actual behavior
- Mock-heavy tests that test our mocking, not our logic
- Duplicate coverage between unit and integration (if the integration test covers it, the unit test should test something different)

---

## The Plan

### Step 1: Create the Ishizue Workspace

This is the new `services/` directory. Ishizue owns it.

```bash
# Blow away the old services directory structure
# (keep the code somewhere for reference — a branch, a copy, whatever)
cd /Users/tyler/Launchpad/Crypto/GHOSTNET

# Save old code to a reference branch
git checkout -b archive/pre-ishizue-services
git checkout main

# Create the Ishizue workspace
cd services
# Clear out old workspace manifest (we'll replace it)
```

```bash
ishizue init ghostnet-services --services ghostnet-api,ghostnet-signer
```

Then add fleet:

```bash
cd ghostnet-services  # or wherever ishizue put it
ishizue add ghostnet-fleet --depends-on ghostnet-api
```

The result should look like:

```
services/
├── .ishizue/
│   └── workspace.toml
├── proto/
│   ├── ghostnet-api/v1/        # or indexer/v1/ — see naming decision below
│   ├── ghostnet-signer/v1/
│   ├── ghostnet-fleet/v1/
│   └── common/v1/
├── services/
│   ├── ghostnet-api/
│   │   ├── ishizue.toml
│   │   ├── Cargo.toml
│   │   └── src/
│   ├── ghostnet-signer/
│   │   ├── ishizue.toml
│   │   ├── Cargo.toml
│   │   └── src/
│   └── ghostnet-fleet/
│       ├── ishizue.toml
│       ├── Cargo.toml
│       └── src/
├── Cargo.toml                  # Workspace manifest (Ishizue-generated)
└── Cargo.lock
```

**Important:** We need to see what `ishizue init` actually generates before committing to a specific directory structure. The above is what the handbook describes. Whatever Ishizue scaffolds, we adopt. We don't fight the framework.

### Step 2: Proto Directory Naming Decision

The Ishizue handbook says auto-discovery scopes to `{includes}/{service_name}/`. So if service name is `ghostnet-api`, it looks for `proto/ghostnet-api/`.

**Two options:**

| Option | Proto dirs | Auto-discovery | Package names |
|--------|-----------|----------------|---------------|
| **A. Match service names** | `proto/ghostnet-api/v1/` | ✅ Works | `ghostnet.api.v1` |
| **B. Use domain names** | `proto/indexer/v1/` | ❌ Needs explicit `proto_paths` | `ghostnet.indexer.v1` |

**Decision: Option A.** Match proto directory names to service names. Let auto-discovery work. The package name `ghostnet.api.v1` is fine — it describes what the service *is* (an API), which is more useful to consumers than what it *does internally* (indexing).

Proto structure:

```
proto/
├── common/v1/types.proto              # Shared types
├── ghostnet-api/v1/api.proto          # API service contract
├── ghostnet-signer/v1/signer.proto    # Signer service contract
└── ghostnet-fleet/v1/fleet.proto      # Fleet service contract
```

### Step 3: Write the Proto Definitions

Copy proto content from `ishizue-integration-plan.md` sections 2.1–2.4, adjusting package names to match the new directory structure:

- `proto/common/v1/types.proto` — as-is from integration plan
- `proto/ghostnet-api/v1/api.proto` — rename package to `ghostnet.api.v1`
- `proto/ghostnet-signer/v1/signer.proto` — rename package to `ghostnet.signer.v1`
- `proto/ghostnet-fleet/v1/fleet.proto` — rename package to `ghostnet.fleet.v1`

Add `@http` route directives to all RPCs (per Ishizue handbook Section 10):

```protobuf
// In ghostnet-api/v1/api.proto
service ApiService {
    // @http GET /v1/positions/{address}
    rpc GetPosition(GetPositionRequest) returns (Position);

    // @http GET /v1/positions
    rpc ListPositions(ListPositionsRequest) returns (ListPositionsResponse);

    // ... etc
}
```

### Step 4: Generate and Verify Compilation

```bash
ishizue generate
cargo build --workspace
```

At this point we have three compiling services with placeholder handlers. No business logic yet.

### Step 5: Create the Domain Crate

This is a regular Cargo library — not an Ishizue service. Add it to the workspace.

```bash
cargo new --lib libs/ghostnet-domain
```

Or if Ishizue's workspace uses `services/` for services and doesn't have a `libs/` convention, put it wherever makes sense in the generated workspace structure. The point: it's a library crate, added to the Cargo workspace `members`, with no `ishizue.toml`.

**Contents — cherry-picked from old `ghostnet-indexer`:**

| Old source | New destination | What |
|-----------|----------------|------|
| `ghostnet-indexer/src/types/primitives.rs` | `libs/ghostnet-domain/src/primitives.rs` | `TokenAmount`, `EthAddress`, `BlockNumber`, `GhostStreak` |
| `ghostnet-indexer/src/types/enums.rs` | `libs/ghostnet-domain/src/enums.rs` | `Level`, `RoundType`, `ExitReason`, `BoostType` |
| `ghostnet-indexer/src/types/entities.rs` | `libs/ghostnet-domain/src/entities.rs` | `Position`, `Scan`, `Death`, `Round`, `Bet`, etc. |
| `ghostnet-indexer/src/types/events.rs` | `libs/ghostnet-domain/src/events.rs` | Domain event types |
| `ghostnet-indexer/src/ports/store.rs` | `libs/ghostnet-domain/src/ports/store.rs` | `PositionStore`, `ScanStore`, `DeathStore`, etc. |
| `ghostnet-indexer/src/ports/streaming.rs` | `libs/ghostnet-domain/src/ports/streaming.rs` | `StreamingPort` |
| `ghostnet-indexer/src/ports/cache.rs` | `libs/ghostnet-domain/src/ports/cache.rs` | `CachePort` |
| `ghostnet-indexer/src/ports/clock.rs` | `libs/ghostnet-domain/src/ports/clock.rs` | `Clock` |

**Cleanup during copy:**
- Remove `#[derive(sqlx::Type)]` → use `#[cfg_attr(feature = "sqlx", derive(sqlx::Type))]`
- Remove `#[async_trait]` → use native `async fn in trait` (Rust 1.88, edition 2024)
- Remove any Axum, Iggy, or framework imports
- Keep all existing tests — they're good (roundtrip conversions, death rate ordering, bet outcome logic)

**Tests for the domain crate — what matters:**

The existing old indexer already has solid unit tests for domain types. Cherry-pick those tests along with the types. Then add anything missing:

```rust
// Tests that prove real game mechanics work correctly:

#[test]
fn position_is_active_only_when_alive_and_not_extracted() {
    // A dead position is not active
    // An extracted position is not active  
    // Only alive + not-extracted = active
}

#[test]
fn level_death_rates_are_monotonically_increasing() {
    // Vault < Mainframe < Subnet < Darknet < BlackIce
    // If this fails, the game's risk model is broken
}

#[test]
fn token_amount_arithmetic_never_overflows_on_realistic_values() {
    // MAX_SUPPLY is 1 billion tokens with 18 decimals
    // Addition of two max-supply amounts should not panic
}

#[test]
fn scan_finalization_requires_all_distribution_fields() {
    // A scan can't be finalized without death_count, total_dead, etc.
    // This catches incomplete event processing
}

#[test]
fn bet_winner_determination_matches_round_outcome() {
    // OVER bet + OVER outcome = winner
    // OVER bet + UNDER outcome = loser
    // Unresolved round = None (not false)
}
```

These test real invariants. If `level_death_rates_are_monotonically_increasing` fails, someone changed the game mechanics and everything downstream breaks.

**Cargo.toml — pure Rust only:**

```toml
[package]
name = "ghostnet-domain"
version = "0.1.0"
edition = "2024"
rust-version = "1.88"

[dependencies]
chrono = { version = "0.4", features = ["serde"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
uuid = { version = "1", features = ["v4", "v7", "serde"] }
bigdecimal = { version = "0.4", features = ["serde"] }
hex = "0.4"

[features]
default = []
sqlx = ["dep:sqlx"]

[dependencies.sqlx]
version = "0.8"
features = ["postgres", "chrono", "uuid", "bigdecimal"]
optional = true
```

### Step 6: Bring Over Infrastructure Crates

The existing shared crates are valuable and framework-independent:

| Crate | What it does | Action |
|-------|-------------|--------|
| `crates/megaeth-rpc` | MegaETH-specific RPC client | Copy into workspace as `libs/megaeth-rpc` |
| `crates/evm-provider` | Chain abstraction layer | Copy into workspace as `libs/evm-provider` |
| `crates/fleet-core` | Wallet orchestration, plugins, scheduling | Copy into workspace as `libs/fleet-core` |

These are plain Cargo crates. Add them to the workspace `members`. No Ishizue involvement.

The `ghostnet-actions` plugin crate also comes along — it depends on `fleet-core` and `evm-provider`. Put it in `libs/ghostnet-actions` or keep it as a top-level workspace member, whatever fits the Ishizue workspace layout.

### Step 7: Implement ghostnet-signer (Greenfield)

Start here because it's new, small, and self-contained. Five RPC methods. Uses Alloy for EIP-712 signing.

```rust
// services/ghostnet-signer/src/handlers/signer.rs
use crate::generated::ghostnet_signer_v1::*;
use crate::generated::ghostnet_signer_v1_signer::SignerServiceHandler;
use alloy::signers::local::PrivateKeySigner;
use ishizue::prelude::*;

pub struct SignerImpl {
    signer: PrivateKeySigner,
}

#[ishizue::handler]
impl SignerServiceHandler for SignerImpl {
    async fn sign_daily_claim(&self, _ctx: Context, req: SignDailyClaimRequest) -> Result<SignedClaim, Status> {
        // EIP-712 typed data signing with Alloy
        todo!()
    }

    async fn verify_daily_claim(&self, _ctx: Context, req: VerifyDailyClaimRequest) -> Result<VerificationResult, Status> {
        todo!()
    }

    async fn sign_message(&self, _ctx: Context, req: SignMessageRequest) -> Result<SignedMessage, Status> {
        todo!()
    }

    async fn verify_message(&self, _ctx: Context, req: VerifyMessageRequest) -> Result<VerificationResult, Status> {
        todo!()
    }

    async fn get_public_key(&self, _ctx: Context, _req: ()) -> Result<PublicKeyResponse, Status> {
        Ok(PublicKeyResponse {
            address: self.signer.address().to_string(),
            public_key: hex::encode(self.signer.credential().verifying_key().to_sec1_bytes()),
        })
    }
}
```

**Tests for the signer — what matters:**

Unit tests (handler in isolation, no network):

```rust
use ishizue_core::testing::TestContext;

#[tokio::test]
async fn sign_then_verify_roundtrip() {
    // Sign a daily claim, then verify the same claim.
    // The signature must be valid. If this fails, players can't claim rewards.
    let signer = SignerImpl::new(&test_private_key()).unwrap();
    let ctx = TestContext::new().build();

    let claim = SignDailyClaimRequest {
        player: "0xABCD...".into(),
        day: 1,
        mission_id: "daily_login".into(),
        reward_amount: "1000000000000000000".into(), // 1 DATA
        nonce: 42,
    };

    let signed = signer.sign_daily_claim(ctx.clone(), claim.clone()).await.unwrap();
    
    let verify_req = VerifyDailyClaimRequest {
        player: claim.player,
        day: claim.day,
        mission_id: claim.mission_id,
        reward_amount: claim.reward_amount,
        nonce: claim.nonce,
        signature: signed.signature,
    };

    let result = signer.verify_daily_claim(ctx, verify_req).await.unwrap();
    assert!(result.valid);
}

#[tokio::test]
async fn tampered_signature_is_rejected() {
    // Sign a claim, modify the reward amount, verify should fail.
    // If this passes with a wrong amount, the contract can be drained.
    // ...
}

#[tokio::test]
async fn signature_matches_solidity_contract_expectations() {
    // Hardcode a known-good signature from the Solidity test suite.
    // Sign the same data in Rust. They must match byte-for-byte.
    // This is the critical interop test — if it fails, on-chain
    // verification will reject all claims.
    // ...
}
```

Integration test (real HTTP, real service):

```rust
use ishizue_testing::TestHarness;

#[tokio::test]
async fn signer_http_endpoint_returns_public_key() {
    let harness = TestHarness::builder()
        .service("ghostnet-signer", |listener, shutdown| async move {
            ghostnet_signer::run(listener, shutdown).await;
        })
        .build().await.unwrap();

    let url = harness.base_url("ghostnet-signer").unwrap();
    let resp = reqwest::get(format!("{url}/v1/public-key")).await.unwrap();
    
    assert!(resp.status().is_success());
    let body: serde_json::Value = resp.json().await.unwrap();
    assert!(body["address"].as_str().unwrap().starts_with("0x"));
    assert!(body["public_key"].as_str().unwrap().len() > 0);
}
```

Run it:

```bash
ishizue run ghostnet-signer
ishizue call ghostnet-signer GetPublicKey
curl http://localhost:8082/v1/public-key
```

### Step 8: Implement ghostnet-api

This is the big one. The service has two jobs:

1. **Ingestion** — Process MegaETH chain events, persist to TimescaleDB, publish to Iggy
2. **Query API** — REST + gRPC + WebSocket for position/scan/stats data

**Internal structure:**

```
services/ghostnet-api/src/
├── main.rs                     # ServiceBuilder wiring
├── generated/                  # DO NOT EDIT
├── handlers/
│   └── api.rs                  # Implements ApiServiceHandler (thin — delegates to domain)
├── domain/                     # Business logic (uses ghostnet-domain types + ports)
│   ├── position_service.rs
│   ├── scan_service.rs
│   └── stats_service.rs
├── adapters/                   # Port implementations
│   ├── postgres_store.rs       # Cherry-picked from old ghostnet-indexer/src/store/postgres.rs
│   ├── iggy_publisher.rs       # Cherry-picked from old ghostnet-indexer/src/streaming/
│   └── moka_cache.rs           # Cherry-picked from old ghostnet-indexer/src/store/cache.rs
├── ingestion/                  # Cherry-picked from old ghostnet-indexer/src/indexer/
│   ├── block_processor.rs      # Registered as Ishizue Component
│   ├── realtime_processor.rs   # Registered as Ishizue Component
│   ├── event_router.rs
│   ├── reorg_handler.rs
│   └── checkpoint.rs
└── abi/                        # Cherry-picked from old ghostnet-indexer/src/abi/
    ├── ghost_core.rs
    ├── trace_scan.rs
    ├── data_token.rs
    ├── dead_pool.rs
    ├── fee_router.rs
    └── rewards_distributor.rs
```

The key Ishizue patterns:

- **Handlers** implement the generated `ApiServiceHandler` trait. They're thin — parse request, call domain service, map to response.
- **Ingestion** components implement Ishizue's `Component` trait for lifecycle management (start/stop/health).
- **Adapters** implement the port traits from `ghostnet-domain`.

**Tests for ghostnet-api — what matters:**

This is where the bulk of testing effort goes. The API service has the most complex behavior: event ingestion, data persistence, query serving, and WebSocket streaming.

**Unit tests** (handler logic, domain services):

```rust
use ishizue_core::testing::TestContext;

#[tokio::test]
async fn get_position_returns_not_found_for_unknown_address() {
    // A user who never jacked in should get a clean 404,
    // not a 500 or an empty position object.
    let handler = ApiImpl::new(mock_position_service_empty());
    let ctx = TestContext::new().build();
    
    let result = handler.get_position(ctx, GetPositionRequest {
        address: "0x0000000000000000000000000000000000000000".into(),
    }).await;

    assert!(matches!(result, Err(status) if status.code() == StatusCode::NotFound));
}

#[tokio::test]
async fn get_position_returns_correct_data_shape() {
    // The proto Position must include all fields the frontend needs:
    // address, level, amount, ghost_streak, is_alive, entry_timestamp.
    // If any field is missing or zero when it shouldn't be, the UI breaks.
    let handler = ApiImpl::new(mock_position_service_with(test_position()));
    let ctx = TestContext::new().build();

    let position = handler.get_position(ctx, GetPositionRequest {
        address: "0x1234...".into(),
    }).await.unwrap();

    assert_eq!(position.level, Level::Subnet as i32);
    assert!(!position.amount.is_empty());
    assert!(position.is_alive);
}
```

**Integration tests** (handler + real Postgres — the critical layer):

Cherry-pick the test patterns from old `tests/store_integration.rs` and `tests/full_flow_integration.rs`, but wire them through Ishizue handlers instead of calling store traits directly:

```rust
use ishizue_testing::TestHarness;

// Feature-gated: only runs when Docker is available
#[cfg(feature = "integration-tests")]
mod integration {
    use ishizue_testing::ContainerFixture;

    #[tokio::test]
    async fn full_ingestion_pipeline_persists_to_postgres() {
        // This is the most important integration test.
        // It proves: chain event → event router → handler → Postgres → query returns data.
        //
        // 1. Start a real Postgres container
        // 2. Run migrations
        // 3. Feed a JackedIn event through the event router
        // 4. Query GetPosition via the handler
        // 5. Verify the position matches the event data
        
        let pg = PostgresFixture::start().await.unwrap();
        // ... run migrations ...
        
        let store = PostgresStore::new(pg.connection_string()).await.unwrap();
        let router = EventRouter::new(/* handlers wired to store */);
        
        // Create a realistic JackedIn event
        let log = create_jacked_in_log(
            test_address(),
            U256::from(1_000_000_000_000_000_000u128), // 1 DATA
            3, // Subnet
            U256::from(1_000_000_000_000_000_000u128),
        );
        
        router.route_log(&log, &create_metadata(100)).await.unwrap();
        
        // Now query through the handler
        let handler = ApiImpl::new(PositionService::new(store.clone()));
        let ctx = TestContext::new().build();
        let position = handler.get_position(ctx, GetPositionRequest {
            address: test_address().to_string(),
        }).await.unwrap();
        
        assert_eq!(position.level, 3); // Subnet
        assert!(position.is_alive);
    }

    #[tokio::test]
    async fn reorg_rollback_removes_orphaned_positions() {
        // Chain reorgs are real on MegaETH. When a reorg happens:
        // 1. Detect parent hash mismatch
        // 2. Find fork point
        // 3. Roll back all data after fork point
        // 4. Reprocess from fork point
        //
        // If this test fails, reorgs corrupt the database.
        
        let pg = PostgresFixture::start().await.unwrap();
        let store = PostgresStore::new(pg.connection_string()).await.unwrap();
        
        // Index blocks 100-105
        // ... ingest events at blocks 103-105 ...
        
        // Simulate reorg: block 103 has different parent hash
        let reorg_handler = ReorgHandler::new(store.clone());
        let result = reorg_handler.check_for_reorg(
            BlockNumber::new(103),
            B256::from([0xFF; 32]), // wrong parent
        ).await.unwrap();
        
        assert!(matches!(result, ReorgCheckResult::ReorgDetected { fork_point, .. } if fork_point == BlockNumber::new(102)));
        
        // After rollback, positions from blocks 103-105 should be gone
        reorg_handler.execute_rollback(BlockNumber::new(102)).await.unwrap();
        // ... verify positions are gone ...
    }

    #[tokio::test]
    async fn scan_lifecycle_two_phase_commit() {
        // Scans have two phases: ScanExecuted → ScanFinalized.
        // Between phases, the scan exists but is not finalized.
        // After finalization, death counts and distributions are recorded.
        //
        // If this test fails, the game's core scan mechanic is broken.
        
        let pg = PostgresFixture::start().await.unwrap();
        let store = PostgresStore::new(pg.connection_string()).await.unwrap();
        
        // Phase 1: ScanExecuted
        // ... route ScanExecuted event ...
        let scan = store.get_scan_by_id("1").await.unwrap().unwrap();
        assert!(!scan.is_finalized());
        
        // Phase 2: ScanFinalized
        // ... route ScanFinalized event with death_count=5, etc. ...
        let scan = store.get_scan_by_id("1").await.unwrap().unwrap();
        assert!(scan.is_finalized());
        assert_eq!(scan.death_count, Some(5));
    }
}
```

**End-to-end test** (real HTTP service on ephemeral port):

```rust
#[tokio::test]
async fn api_serves_positions_over_http() {
    // Start the real ghostnet-api service, hit the REST endpoint,
    // verify the response is valid JSON with correct structure.
    
    let harness = TestHarness::builder()
        .service("ghostnet-api", |listener, shutdown| async move {
            ghostnet_api::run(listener, shutdown).await;
        })
        .build().await.unwrap();

    let url = harness.base_url("ghostnet-api").unwrap();
    
    // GET /v1/positions/0x... should return 404 (no data yet)
    let resp = reqwest::get(format!("{url}/v1/positions/0x0000000000000000000000000000000000000000"))
        .await.unwrap();
    assert_eq!(resp.status(), 404);
    
    // GET /v1/stats/global should return zeroed stats (empty DB)
    let resp = reqwest::get(format!("{url}/v1/stats/global")).await.unwrap();
    assert!(resp.status().is_success());
    let stats: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(stats["total_positions"], 0);
}
```

### Step 9: Implement ghostnet-fleet

Wire client dependency:

```bash
ishizue client wire ghostnet-fleet --to ghostnet-api
ishizue generate
```

Bring in `fleet-core`, `evm-provider`, `ghostnet-actions` as Cargo dependencies. Implement `FleetServiceHandler`. Register the wallet scheduling engine as an Ishizue `Component`.

**Tests for ghostnet-fleet — what matters:**

Unit tests (fleet handler with mocked API client):

```rust
use ishizue_testing::MockTransport;
use ishizue_core::testing::TestContext;

#[tokio::test]
async fn execute_action_calls_api_for_position_check() {
    // When fleet executes a "jackIn" action, it should first
    // check the user's current position via the API service.
    // If the API is down, the action should fail gracefully.
    
    let transport = MockTransport::new();
    transport
        .when("ghostnet.api.v1.ApiService/GetPosition")
        .returns(test_position_proto());

    let handler = FleetImpl::new(
        mock_wallet_manager(),
        mock_plugin_registry(),
        api_client_with_transport(transport.clone()),
    );

    let ctx = TestContext::new().build();
    let result = handler.execute_action(ctx, ExecuteActionRequest {
        wallet_id: "wallet-1".into(),
        action_type: "jackIn".into(),
        params: Default::default(),
    }).await;

    assert!(result.is_ok());
    transport.assert_called("ghostnet.api.v1.ApiService/GetPosition");
}

#[tokio::test]
async fn execute_action_fails_when_api_unavailable() {
    // If the API service is down, fleet should return a clear error,
    // not hang or panic. This tests the retry/failure path.
    
    let transport = MockTransport::new();
    transport
        .when("ghostnet.api.v1.ApiService/GetPosition")
        .returns_error(Status::unavailable("service down"));

    let handler = FleetImpl::new(/* ... */);
    let ctx = TestContext::new().build();
    let result = handler.execute_action(ctx, /* ... */).await;

    assert!(result.is_err());
    // Error should indicate upstream failure, not mask it
}
```

End-to-end test (fleet + api, real services):

```rust
#[tokio::test]
async fn fleet_can_call_api_for_position_data() {
    // Start both services. Fleet calls API. This proves the
    // client wiring, proto compatibility, and network path all work.
    
    let harness = TestHarness::builder()
        .service("ghostnet-api", |listener, shutdown| async move {
            ghostnet_api::run(listener, shutdown).await;
        })
        .service("ghostnet-fleet", |listener, shutdown| async move {
            ghostnet_fleet::run(listener, shutdown).await;
        })
        .build().await.unwrap();

    let fleet_url = harness.base_url("ghostnet-fleet").unwrap();
    
    // Hit fleet's admin endpoint, which internally calls api
    let resp = reqwest::get(format!("{fleet_url}/admin/status"))
        .await.unwrap();
    assert!(resp.status().is_success());
}
```

### Step 10: Delete the Reference Code

Once all three services compile, pass tests, and serve correct data:

```bash
# The old code is on the archive/pre-ishizue-services branch
# Nothing to delete from this workspace — it was built clean
```

---

## Port Allocation

| Service | Entrypoint | Port | Exposure |
|---------|------------|------|----------|
| ghostnet-api | HTTP (public) | 8080 | Public (read-only) |
| ghostnet-api | gRPC (mesh) | 9090 | Internal |
| ghostnet-api | Admin | 9190 | Localhost only |
| ghostnet-signer | HTTP | 8082 | Internal (mTLS + API key) |
| ghostnet-signer | gRPC | 9092 | Internal (mTLS) |
| ghostnet-signer | Admin | 9192 | Localhost only |
| ghostnet-fleet | HTTP (admin) | 8083 | Internal (JWT) |
| ghostnet-fleet | gRPC | 9093 | Internal (mTLS) |
| ghostnet-fleet | Admin | 9193 | Localhost only |

Convention: `808x` public/service HTTP, `909x` mesh gRPC, `919x` admin.

---

## Open Questions

These need answers during Step 1 (when we actually run `ishizue init`):

1. **What exact directory structure does `ishizue init` generate?** The handbook shows `services/` subdirectory for services and `proto/` at workspace root. We adopt whatever it generates.

2. **Where do library crates go?** The handbook mentions `libs/` in the monorepo layout example. If Ishizue's generated workspace has a different convention, we follow it.

3. **Does `ishizue generate` handle `google.protobuf.Empty` and `google.protobuf.Duration`?** The fleet proto imports these. Ishizue's prost-based codegen should bundle well-known types, but we need to verify.

4. **How does Ishizue handle server-streaming RPCs over HTTP?** `SubscribeEvents` returns `stream Event`. Over gRPC this is native. Over HTTP we need SSE or WebSocket. Does Ishizue handle this, or do we need a custom entrypoint?

5. **Workspace lint configuration.** Our existing workspace has strict Clippy lints (`unwrap_used = "deny"`, `panic = "deny"`, `unsafe_code = "forbid"`). We need to configure these in the new workspace's `Cargo.toml`.

6. **Container test infrastructure.** Does Ishizue's `ContainerFixture` for Postgres include TimescaleDB? We need the `timescaledb` extension for hypertables. We may need a custom container fixture or our own `testcontainers` setup (we already have this in the old `tests/common/containers.rs`).

---

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Ishizue workspace is the foundation, not an addition | Optimal architecture, not backward compatibility |
| 2 | Match proto dirs to service names | Let auto-discovery work; don't fight the framework |
| 3 | Use Alloy for signing (not ethers-rs) | ethers-rs is deprecated; existing code uses Alloy |
| 4 | Domain crate with optional `sqlx` feature | Pure types by default; DB compat opt-in |
| 5 | Native `async fn in trait` (edition 2024) | Rust 1.88; avoid `async_trait` macro |
| 6 | Start with signer (greenfield) | Learn Ishizue patterns with lowest risk |
| 7 | Cherry-pick code, don't migrate | Take what's valuable, leave the scaffolding |
| 8 | Test real scenarios, not coverage | Every test answers "what breaks if this fails?" |
| 9 | Use Ishizue testing infrastructure | `TestContext`, `TestHarness`, `MockTransport`, `ContainerFixture` |
| 10 | Integration tests gate on `integration-tests` feature | Container tests need Docker; don't break `cargo test` on machines without it |

---

## Test Summary by Service

| Service | Unit tests | Integration tests | E2E tests |
|---------|-----------|-------------------|-----------|
| **ghostnet-domain** | Type roundtrips, game mechanic invariants, arithmetic safety | — | — |
| **ghostnet-signer** | Sign/verify roundtrip, tampered data rejection, Solidity interop | HTTP endpoint serves public key | — |
| **ghostnet-api** | Handler returns correct status codes, data shape validation | Full ingestion pipeline (event → DB → query), reorg rollback, scan two-phase lifecycle | REST endpoint returns correct JSON |
| **ghostnet-fleet** | Action execution calls API client, failure when API unavailable | — | Fleet → API cross-service call works |

**Test command convention:**

```bash
# Unit tests only (fast, no Docker needed)
cargo test --workspace

# Integration tests (needs Docker for Postgres)
cargo test --workspace --features integration-tests

# Single service
cargo test -p ghostnet-api
cargo test -p ghostnet-api --features integration-tests
```

---

*This document is a living specification. Update it as the migration progresses.*
