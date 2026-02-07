# GHOSTNET Service Architecture Plan
## Ishizue Framework Integration

**Date:** 2026-02-07  
**Status:** Draft - Ready for Review  
**Author:** Architecture Team  

---

## Introduction

### Context and Motivation

GHOSTNET is a real-time survival game on MegaETH with a multi-component architecture: a SvelteKit web application, Solidity smart contracts, and Rust backend services. As the project has evolved, we've identified the need for a unified microservices framework to manage our growing backend infrastructure.

Currently, our services are:
- **`ghostnet-indexer`** - An event indexer with TimescaleDB persistence and Apache Iggy streaming, but its HTTP API layer is commented out and incomplete
- **`ghost-fleet`** - A CLI-based wallet orchestrator that manages autonomous wallets but lacks HTTP management interfaces
- **`ghostnet-actions`** - A library crate implementing the ActionPlugin trait, consumed by ghost-fleet
- **New requirements** - We need a dedicated signing service for EIP-712 mission verification

### Why Ishizue?

This plan is based on the [**Ishizue Service Developer Handbook**](file:///Users/tyler/Launchpad/IshizueOrg/ishizue/docs/handbook/README.md), a comprehensive Rust microservices framework developed by IshizueOrg. Ishizue provides:

- **Proto-first API design** - Single source of truth for HTTP, gRPC, and WebSocket contracts
- **Handler invariance** - Business logic remains transport-agnostic (HTTP, gRPC, Connect)
- **Zero-cost abstractions** - Compile-time middleware composition without runtime overhead
- **Workspace model** - Multi-service orchestration with shared proto definitions
- **Built-in observability** - OpenTelemetry tracing, metrics, and structured logging
- **Production patterns** - Graceful shutdown, health checks, circuit breakers, and rate limiting

### Related Documentation

| Document | Purpose |
|----------|---------|
| [`/Users/tyler/Launchpad/IshizueOrg/ishizue/docs/handbook/README.md`](file:///Users/tyler/Launchpad/IshizueOrg/ishizue/docs/handbook/README.md) | Complete Ishizue framework handbook - the authoritative source for service patterns |
| [`docs/CODEBASE.md`](../../CODEBASE.md) | GHOSTNET codebase overview - understanding current architecture |
| [`docs/blueprint/architecture.md`](../../blueprint/architecture.md) | System architecture - component relationships and data flows |
| [`services/README.md`](../../../services/README.md) | Service development guide - current Rust service patterns |
| [`AGENTS.md`](../../../AGENTS.md) | AI assistant instructions - monorepo navigation and commands |

### What This Plan Covers

This document provides:
1. **Service inventory** - Current state analysis and Ishizue migration strategy
2. **Proto definitions** - Complete API contracts for all three services
3. **Workspace structure** - Recommended directory layout and configuration
4. **Implementation roadmap** - Phased approach over 7 weeks
5. **API surface** - All REST, gRPC, and WebSocket endpoints
6. **Security, observability, and configuration** - Production-ready considerations

---

## Executive Summary

This document outlines the complete service architecture plan for migrating GHOSTNET's backend services to the Ishizue microservices framework. The plan identifies **four primary services** that require Ishizue integration, defines their API contracts, and establishes a workspace-based development approach.

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| **Ishizue Workspace Model** | GHOSTNET requires 4+ services with shared proto definitions; workspace provides unified tooling |
| **Proto-First API Design** | Contract-first ensures consistency across HTTP/gRPC/WebSocket boundaries |
| **Indexer as Core Service** | The ghostnet-indexer becomes the primary data provider for all queries |
| **Fleet as Orchestrator** | ghost-fleet manages autonomous wallets; exposes admin APIs via Ishizue |
| **Signature Service** | New dedicated service for EIP-712 mission signing and verification |

---

## 1. Service Inventory

### Current Services Analysis

| Service | Current State | Ishizue Role | Priority |
|---------|--------------|--------------|----------|
| **ghostnet-indexer** | Rust service with Axum (commented out), TimescaleDB, Iggy | **Primary API Service** - REST + WebSocket + gRPC | P0 |
| **ghost-fleet** | Rust CLI app with plugin architecture | **Admin + Control Service** - HTTP management API | P1 |
| **ghostnet-actions** | Library crate (ActionPlugin impl) | **Keep as library**, expose via fleet service | P2 |
| **Signature Service** | Does not exist | **New Service** - EIP-712 signing for missions | P0 |

### Service Architecture Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GHOSTNET ISHIZUE WORKSPACE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │  ghostnet-api   │    │  ghostnet-fleet │    │ ghostnet-signer │         │
│  │   (Indexer)     │    │  (Orchestrator) │    │  (Signature)    │         │
│  │                 │    │                 │    │                 │         │
│  │  HTTP :8080     │◄──►│  HTTP :8083     │    │  HTTP :8082     │         │
│  │  gRPC :9090     │    │  gRPC :9093     │    │  gRPC :9092     │         │
│  │  WS   :8080/ws  │    │  Admin :9193    │    │  Admin :9192    │         │
│  │  Admin :9190    │    │                 │    │                 │         │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘         │
│           │                      │                      │                  │
│           │                      │                      │                  │
│           ▼                      ▼                      ▼                  │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │                     SHARED INFRASTRUCTURE                        │      │
│  │  TimescaleDB  │  Apache Iggy  │  Redis  │  MegaETH RPC         │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLIENTS                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │
│  │   Web App   │  │   Keeper    │  │   Admin     │  │  Other Services │    │
│  │  (SvelteKit)│  │    Bots     │  │   Tools     │  │                 │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Proto Contract Definitions

### 2.1 Common Types (`proto/common/v1/types.proto`)

```protobuf
syntax = "proto3";

package ghostnet.common.v1;

// Risk levels in GHOSTNET
enum Level {
  LEVEL_UNSPECIFIED = 0;
  LEVEL_VAULT = 1;      // 0% death rate
  LEVEL_MAINFRAME = 2;  // 2% death rate
  LEVEL_SUBNET = 3;     // 15% death rate
  LEVEL_DARKNET = 4;    // 40% death rate
  LEVEL_BLACK_ICE = 5;  // 90% death rate
}

// Ethereum address wrapper
message Address {
  string value = 1;  // 0x-prefixed hex string
}

// Token amount (uint256 as string)
message Amount {
  string value = 1;  // Decimal string for precision
  uint32 decimals = 2;  // Token decimals (18 for DATA)
}

// Timestamp wrapper
message Timestamp {
  int64 seconds = 1;
  int32 nanos = 2;
}

// Pagination parameters
message Pagination {
  uint32 limit = 1;
  string cursor = 2;  // Opaque cursor for next page
}

message PaginationInfo {
  uint32 total = 1;
  bool has_more = 2;
  string next_cursor = 3;
}

// Standard error details
message ErrorDetail {
  string field = 1;
  string message = 2;
  string code = 3;
}
```

### 2.2 Indexer Service (`proto/indexer/v1/indexer.proto`)

```protobuf
syntax = "proto3";

package ghostnet.indexer.v1;

import "common/v1/types.proto";
import "google/protobuf/empty.proto";

// Primary indexer service for querying GHOSTNET state
service IndexerService {
  // Positions
  rpc GetPosition(GetPositionRequest) returns (Position);
  rpc ListPositions(ListPositionsRequest) returns (ListPositionsResponse);
  rpc GetPositionHistory(GetPositionHistoryRequest) returns (GetPositionHistoryResponse);
  
  // Scans
  rpc GetScan(GetScanRequest) returns (Scan);
  rpc ListScans(ListScansRequest) returns (ListScansResponse);
  rpc GetPendingScans(google.protobuf.Empty) returns (ListScansResponse);
  
  // Deaths
  rpc GetDeath(GetDeathRequest) returns (Death);
  rpc ListDeaths(ListDeathsRequest) returns (ListDeathsResponse);
  
  // DeadPool
  rpc GetRound(GetRoundRequest) returns (Round);
  rpc ListRounds(ListRoundsRequest) returns (ListRoundsResponse);
  rpc GetActiveRounds(google.protobuf.Empty) returns (ListRoundsResponse);
  
  // Statistics
  rpc GetGlobalStats(google.protobuf.Empty) returns (GlobalStats);
  rpc GetLevelStats(GetLevelStatsRequest) returns (LevelStats);
  rpc GetAllLevelStats(google.protobuf.Empty) returns (GetAllLevelStatsResponse);
  
  // Leaderboards
  rpc GetLeaderboard(GetLeaderboardRequest) returns (GetLeaderboardResponse);
  
  // Streaming
  rpc SubscribeEvents(SubscribeEventsRequest) returns (stream Event);
  rpc SubscribeUserEvents(SubscribeUserEventsRequest) returns (stream Event);
}

// Position represents a user's staking position
message Position {
  string id = 1;
  string user_address = 2;
  ghostnet.common.v1.Level level = 3;
  string amount = 4;           // Amount staked (wei)
  string reward_debt = 5;      // For yield calculation
  ghostnet.common.v1.Timestamp entry_time = 6;
  optional ghostnet.common.v1.Timestamp last_add_time = 7;
  uint32 ghost_streak = 8;
  bool is_alive = 9;
  bool is_extracted = 10;
  optional string exit_reason = 11;
  optional ghostnet.common.v1.Timestamp exit_time = 12;
  optional string extracted_amount = 13;
  optional string extracted_rewards = 14;
  uint64 created_at_block = 15;
  ghostnet.common.v1.Timestamp updated_at = 16;
}

message GetPositionRequest {
  string address = 1;
}

message ListPositionsRequest {
  optional ghostnet.common.v1.Level level = 1;
  optional bool is_alive = 2;
  ghostnet.common.v1.Pagination pagination = 3;
}

message ListPositionsResponse {
  repeated Position positions = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

message GetPositionHistoryRequest {
  string address = 1;
  ghostnet.common.v1.Pagination pagination = 2;
}

message PositionHistoryEntry {
  string id = 1;
  string position_id = 2;
  string action = 3;  // JACK_IN, ADD_STAKE, EXTRACT, etc.
  string amount_before = 4;
  string amount_after = 5;
  uint64 block_number = 6;
  ghostnet.common.v1.Timestamp timestamp = 7;
}

message GetPositionHistoryResponse {
  repeated PositionHistoryEntry entries = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

// Scan represents a trace scan execution
message Scan {
  string id = 1;
  string scan_id = 2;          // On-chain U256
  ghostnet.common.v1.Level level = 3;
  string seed = 4;             // Randomness seed
  ghostnet.common.v1.Timestamp executed_at = 5;
  optional ghostnet.common.v1.Timestamp finalized_at = 6;
  optional uint32 death_count = 7;
  optional string total_dead = 8;
  optional string burned = 9;
  optional string distributed_same_level = 10;
  optional string distributed_upstream = 11;
  optional string protocol_fee = 12;
  optional uint32 survivor_count = 13;
}

message GetScanRequest {
  string scan_id = 1;
}

message ListScansRequest {
  optional ghostnet.common.v1.Level level = 1;
  optional bool finalized_only = 2;
  ghostnet.common.v1.Pagination pagination = 3;
}

message ListScansResponse {
  repeated Scan scans = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

// Death represents an individual death record
message Death {
  string id = 1;
  optional string scan_id = 2;
  string user_address = 3;
  optional string position_id = 4;
  string amount_lost = 5;
  ghostnet.common.v1.Level level = 6;
  optional uint32 ghost_streak_at_death = 7;
  ghostnet.common.v1.Timestamp created_at = 8;
}

message GetDeathRequest {
  string id = 1;
}

message ListDeathsRequest {
  optional ghostnet.common.v1.Level level = 1;
  optional string scan_id = 2;
  ghostnet.common.v1.Pagination pagination = 3;
}

message ListDeathsResponse {
  repeated Death deaths = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

// DeadPool round
message Round {
  string id = 1;
  string round_id = 2;
  RoundType round_type = 3;
  optional ghostnet.common.v1.Level target_level = 4;
  string line = 5;
  ghostnet.common.v1.Timestamp deadline = 6;
  string over_pool = 7;
  string under_pool = 8;
  bool is_resolved = 9;
  optional bool outcome = 10;  // true=OVER, false=UNDER
  optional ghostnet.common.v1.Timestamp resolve_time = 11;
  optional string total_burned = 12;
}

enum RoundType {
  ROUND_TYPE_UNSPECIFIED = 0;
  ROUND_TYPE_DEATH_COUNT = 1;
  ROUND_TYPE_WHALE_DEATH = 2;
  ROUND_TYPE_STREAK_RECORD = 3;
  ROUND_TYPE_SYSTEM_RESET = 4;
}

message GetRoundRequest {
  string round_id = 1;
}

message ListRoundsRequest {
  optional bool active_only = 1;
  optional RoundType round_type = 2;
  ghostnet.common.v1.Pagination pagination = 3;
}

message ListRoundsResponse {
  repeated Round rounds = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

// Statistics
message GlobalStats {
  string total_value_locked = 1;
  uint64 total_positions = 2;
  uint64 total_deaths = 3;
  string total_burned = 4;
  string total_emissions_distributed = 5;
  string total_toll_collected = 6;
  string total_buyback_burned = 7;
  uint32 system_reset_count = 8;
  ghostnet.common.v1.Timestamp updated_at = 9;
}

message LevelStats {
  ghostnet.common.v1.Level level = 1;
  string total_staked = 2;
  uint64 alive_count = 3;
  uint64 total_deaths = 4;
  uint64 total_extracted = 5;
  string total_burned = 6;
  string total_distributed = 7;
  uint32 highest_ghost_streak = 8;
  ghostnet.common.v1.Timestamp updated_at = 9;
}

message GetLevelStatsRequest {
  ghostnet.common.v1.Level level = 1;
}

message GetAllLevelStatsResponse {
  repeated LevelStats stats = 1;
}

// Leaderboard
message LeaderboardEntry {
  uint32 rank = 1;
  string user_address = 2;
  string score = 3;
  optional string metadata = 4;  // JSON string
}

enum LeaderboardType {
  LEADERBOARD_TYPE_UNSPECIFIED = 0;
  LEADERBOARD_TYPE_GHOST_STREAK = 1;
  LEADERBOARD_TYPE_VALUE = 2;
  LEADERBOARD_TYPE_EXTRACTED = 3;
  LEADERBOARD_TYPE_REFERRALS = 4;
}

message GetLeaderboardRequest {
  LeaderboardType type = 1;
  uint32 limit = 2;
}

message GetLeaderboardResponse {
  repeated LeaderboardEntry entries = 1;
}

// Events for streaming
message Event {
  string id = 1;
  string topic = 2;
  string event_type = 3;
  bytes payload = 4;  // JSON-encoded event data
  ghostnet.common.v1.Timestamp timestamp = 5;
  uint64 block_number = 6;
}

enum Topic {
  TOPIC_UNSPECIFIED = 0;
  TOPIC_POSITIONS = 1;
  TOPIC_SCANS = 2;
  TOPIC_DEATHS = 3;
  TOPIC_MARKET = 4;
  TOPIC_SYSTEM = 5;
  TOPIC_TOKEN = 6;
  TOPIC_FEES = 7;
}

message SubscribeEventsRequest {
  repeated Topic topics = 1;
}

message SubscribeUserEventsRequest {
  string address = 1;
  repeated Topic topics = 2;
}
```

### 2.3 Fleet Service (`proto/fleet/v1/fleet.proto`)

```protobuf
syntax = "proto3";

package ghostnet.fleet.v1;

import "common/v1/types.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/duration.proto";

// Fleet orchestrator service for managing autonomous wallets
service FleetService {
  // Wallet management
  rpc ListWallets(google.protobuf.Empty) returns (ListWalletsResponse);
  rpc GetWallet(GetWalletRequest) returns (Wallet);
  rpc AddWallet(AddWalletRequest) returns (Wallet);
  rpc RemoveWallet(RemoveWalletRequest) returns (google.protobuf.Empty);
  rpc UpdateWalletProfile(UpdateWalletProfileRequest) returns (Wallet);
  
  // Action management
  rpc ListActions(ListActionsRequest) returns (ListActionsResponse);
  rpc ExecuteAction(ExecuteActionRequest) returns (ActionResult);
  rpc SimulateAction(SimulateActionRequest) returns (SimulateActionResponse);
  
  // Service control
  rpc GetStatus(google.protobuf.Empty) returns (ServiceStatus);
  rpc PauseService(google.protobuf.Empty) returns (google.protobuf.Empty);
  rpc ResumeService(google.protobuf.Empty) returns (google.protobuf.Empty);
  rpc ResetCircuitBreaker(ResetCircuitBreakerRequest) returns (google.protobuf.Empty);
  
  // Streaming
  rpc StreamWalletEvents(StreamWalletEventsRequest) returns (stream WalletEvent);
}

message Wallet {
  string id = 1;
  string address = 2;
  string profile = 3;
  WalletStatus status = 4;
  ghostnet.common.v1.Timestamp created_at = 5;
  ghostnet.common.v1.Timestamp last_action_at = 6;
  uint64 total_actions = 7;
  uint64 failed_actions = 8;
  string current_state = 9;  // JSON-encoded plugin state
}

enum WalletStatus {
  WALLET_STATUS_UNSPECIFIED = 0;
  WALLET_STATUS_ACTIVE = 1;
  WALLET_STATUS_PAUSED = 2;
  WALLET_STATUS_ERROR = 3;
  WALLET_STATUS_CIRCUIT_OPEN = 4;
}

message ListWalletsResponse {
  repeated Wallet wallets = 1;
}

message GetWalletRequest {
  string wallet_id = 1;
}

message AddWalletRequest {
  string address = 1;
  string profile = 2;
  optional string private_key = 3;  // Or use keyfile
  optional string keyfile_path = 4;
}

message RemoveWalletRequest {
  string wallet_id = 1;
}

message UpdateWalletProfileRequest {
  string wallet_id = 1;
  string profile = 2;
}

message Action {
  string id = 1;
  string wallet_id = 2;
  string action_type = 3;
  string status = 4;
  optional string error = 5;
  ghostnet.common.v1.Timestamp created_at = 6;
  optional ghostnet.common.v1.Timestamp executed_at = 7;
  string tx_hash = 8;
}

message ListActionsRequest {
  optional string wallet_id = 1;
  optional string status = 2;
  ghostnet.common.v1.Pagination pagination = 3;
}

message ListActionsResponse {
  repeated Action actions = 1;
  ghostnet.common.v1.PaginationInfo pagination = 2;
}

message ExecuteActionRequest {
  string wallet_id = 1;
  string action_type = 2;
  bytes params = 3;  // JSON-encoded action parameters
}

message ActionResult {
  bool success = 1;
  optional string error = 2;
  optional string tx_hash = 3;
}

message SimulateActionRequest {
  string wallet_id = 1;
  string action_type = 2;
  bytes params = 3;
}

message SimulateActionResponse {
  bool would_execute = 1;
  string reasoning = 2;
  optional bytes transaction_data = 3;
}

message ServiceStatus {
  bool is_running = 1;
  bool is_paused = 2;
  uint64 active_wallets = 3;
  uint64 total_actions_last_hour = 4;
  repeated string active_plugins = 5;
  map<string, uint64> circuit_breaker_states = 6;
}

message ResetCircuitBreakerRequest {
  string wallet_id = 1;
}

message WalletEvent {
  string wallet_id = 1;
  string event_type = 2;
  bytes payload = 3;
  ghostnet.common.v1.Timestamp timestamp = 4;
}

message StreamWalletEventsRequest {
  repeated string wallet_ids = 1;
}
```

### 2.4 Signer Service (`proto/signer/v1/signer.proto`)

```protobuf
syntax = "proto3";

package ghostnet.signer.v1;

import "common/v1/types.proto";

// Mission signer service for EIP-712 attestations
service SignerService {
  // Daily mission signing
  rpc SignDailyClaim(SignDailyClaimRequest) returns (SignedClaim);
  rpc VerifyDailyClaim(VerifyDailyClaimRequest) returns (VerificationResult);
  
  // Generic message signing
  rpc SignMessage(SignMessageRequest) returns (SignedMessage);
  rpc VerifyMessage(VerifyMessageRequest) returns (VerificationResult);
  
  // Admin
  rpc GetPublicKey(google.protobuf.Empty) returns (PublicKeyResponse);
}

message SignDailyClaimRequest {
  string player = 1;
  uint64 day = 2;
  string mission_id = 3;
  string reward_amount = 4;
  string nonce = 5;
}

message SignedClaim {
  uint64 day = 1;
  string mission_id = 2;
  string reward_amount = 3;
  string nonce = 4;
  bytes signature = 5;
  string signer = 6;
}

message VerifyDailyClaimRequest {
  SignedClaim claim = 1;
  string player = 2;
}

message SignMessageRequest {
  bytes message = 1;
  string signer_type = 2;  // "eip712", "raw", etc.
}

message SignedMessage {
  bytes message = 1;
  bytes signature = 2;
  string signer = 3;
}

message VerifyMessageRequest {
  bytes message = 1;
  bytes signature = 2;
  string expected_signer = 3;
}

message VerificationResult {
  bool valid = 1;
  optional string error = 2;
  string recovered_signer = 3;
}

message PublicKeyResponse {
  string address = 1;
  string public_key = 2;
}
```

---

## 3. Workspace Structure

### 3.1 Directory Layout

The Ishizue workspace is the foundation. The exact layout comes from `ishizue init`. Library crates (domain types, infrastructure) are added as non-Ishizue workspace members.

```
services/
├── .ishizue/
│   └── workspace.toml          # Workspace configuration
├── proto/                      # Shared proto definitions
│   ├── common/v1/types.proto
│   ├── ghostnet-api/v1/api.proto
│   ├── ghostnet-fleet/v1/fleet.proto
│   └── ghostnet-signer/v1/signer.proto
├── services/                   # Ishizue-managed services
│   ├── ghostnet-api/           # Ishizue service: indexer + API
│   │   ├── Cargo.toml
│   │   ├── ishizue.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── generated/      # ishizue generate output
│   │       ├── handlers/       # Ishizue handler impls (thin adapters)
│   │       ├── domain/         # Domain services (orchestrate ports)
│   │       ├── adapters/       # DB, Iggy, RPC adapters
│   │       ├── ingestion/      # Block processing, event routing
│   │       └── abi/            # Contract ABIs
│   ├── ghostnet-fleet/         # Ishizue service: wallet orchestrator
│   │   ├── Cargo.toml
│   │   ├── ishizue.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── generated/
│   │       └── handlers/
│   └── ghostnet-signer/        # Ishizue service: mission signer
│       ├── Cargo.toml
│       ├── ishizue.toml
│       └── src/
│           ├── main.rs
│           ├── generated/
│           └── handlers/
├── libs/                       # Non-Ishizue library crates
│   ├── ghostnet-domain/        # Pure domain types, traits, business logic
│   ├── megaeth-rpc/            # MegaETH-specific RPC client
│   ├── evm-provider/           # Chain abstraction layer
│   ├── fleet-core/             # Wallet orchestration primitives
│   └── ghostnet-actions/       # Protocol-specific action plugin
├── Cargo.toml                  # Workspace manifest
└── Cargo.lock
```

**Note:** Proto directory names match service names (`ghostnet-api/`, `ghostnet-signer/`, `ghostnet-fleet/`) so Ishizue's auto-discovery works without explicit `proto_paths`. The actual layout may differ based on what `ishizue init` generates — we adopt the framework's conventions.

### 3.2 Workspace Configuration (`.ishizue/workspace.toml`)

```toml
[workspace]
name = "ghostnet-services"
version = "0.1.0"
description = "GHOSTNET backend services"

[services]
# Order matters for startup
ghostnet-api = { path = "services/ghostnet-api", depends_on = [] }
ghostnet-signer = { path = "services/ghostnet-signer", depends_on = [] }
ghostnet-fleet = { path = "services/ghostnet-fleet", depends_on = ["ghostnet-api"] }

[codegen]
includes = ["proto/"]

[deploy]
registry = "ghcr.io/ghostnet"
namespace = "ghostnet"
```

**Note:** The `depends_on` for `ghostnet-fleet` lists only `ghostnet-api` (not `ghostnet-signer`). Fleet calls the API service for position data; it does not call the signer.

### 3.3 Service Configuration Templates

#### ghostnet-api/ishizue.toml

```toml
[service]
name = "ghostnet-api"
version = "0.1.0"

[codegen]
includes = ["../../proto/"]
grpc = true
http = true
client = false
serde = true
# Auto-discovery finds proto/ghostnet-api/v1/*.proto

[entrypoints]
public_http = { port = 8080, protocol = "http" }
public_grpc = { port = 9090, protocol = "grpc" }
admin = { port = 9190, protocol = "http" }
```

#### ghostnet-signer/ishizue.toml

```toml
[service]
name = "ghostnet-signer"
version = "0.1.0"

[codegen]
includes = ["../../proto/"]
grpc = true
http = true
client = false
serde = true
# Auto-discovery finds proto/ghostnet-signer/v1/*.proto

[entrypoints]
internal_http = { port = 8082, protocol = "http" }
internal_grpc = { port = 9092, protocol = "grpc" }
admin = { port = 9192, protocol = "http" }
```

#### ghostnet-fleet/ishizue.toml

```toml
[service]
name = "ghostnet-fleet"
version = "0.1.0"

[codegen]
includes = ["../../proto/"]
grpc = true
http = true
client = true  # Needs ghostnet-api client
serde = true
# Auto-discovery finds proto/ghostnet-fleet/v1/*.proto

[entrypoints]
admin_http = { port = 8083, protocol = "http" }
internal_grpc = { port = 9093, protocol = "grpc" }
admin = { port = 9193, protocol = "http" }

[dependencies]
ghostnet-api = { client = true }
```

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

| Task | Owner | Dependencies |
|------|-------|--------------|
| Initialize Ishizue workspace | Backend | None |
| Define all proto contracts | Architecture | None |
| Set up workspace CI/CD | DevOps | None |
| Migrate existing indexer logic to domain layer | Backend | Proto definitions |

### Phase 2: ghostnet-api Service (Week 3-4)

| Task | Owner | Dependencies |
|------|-------|--------------|
| Create ghostnet-api service scaffold | Backend | Workspace init |
| Implement Position handlers | Backend | Domain layer |
| Implement Scan handlers | Backend | Domain layer |
| Implement Stats handlers | Backend | Domain layer |
| Add REST entrypoint (HTTP) | Backend | Handlers |
| Add gRPC entrypoint | Backend | Handlers |
| Add WebSocket streaming | Backend | Iggy integration |
| Integration tests | QA | All handlers |

### Phase 3: ghostnet-signer Service (Week 4-5)

| Task | Owner | Dependencies |
|------|-------|--------------|
| Create ghostnet-signer service | Backend | Workspace init |
| Implement EIP-712 signing | Backend | None |
| Implement verification | Backend | Signing |
| Add HTTP entrypoint | Backend | Handlers |
| Security audit | Security | All features |

### Phase 4: ghostnet-fleet Service (Week 5-6)

| Task | Owner | Dependencies |
|------|-------|--------------|
| Create ghostnet-fleet service | Backend | ghostnet-api client |
| Migrate ghostnet-actions to domain | Backend | None |
| Implement wallet management handlers | Backend | Domain |
| Implement action handlers | Backend | Domain |
| Add HTTP admin API | Backend | Handlers |
| Add gRPC internal API | Backend | Handlers |

### Phase 5: Integration (Week 7)

| Task | Owner | Dependencies |
|------|-------|--------------|
| Web app integration | Frontend | All services |
| End-to-end testing | QA | All services |
| Performance testing | QA | All services |
| Documentation | Docs | All services |

---

## 5. API Endpoint Summary

### 5.1 ghostnet-api Endpoints

#### HTTP REST

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| GET | /api/v1/positions | ListPositions | List all positions |
| GET | /api/v1/positions/:address | GetPosition | Get single position |
| GET | /api/v1/positions/:address/history | GetPositionHistory | Position history |
| GET | /api/v1/scans | ListScans | List scans |
| GET | /api/v1/scans/:scan_id | GetScan | Get scan details |
| GET | /api/v1/scans/pending | GetPendingScans | Pending scans |
| GET | /api/v1/deaths | ListDeaths | List deaths |
| GET | /api/v1/rounds | ListRounds | List DeadPool rounds |
| GET | /api/v1/rounds/active | GetActiveRounds | Active rounds |
| GET | /api/v1/stats/global | GetGlobalStats | Global statistics |
| GET | /api/v1/stats/levels | GetAllLevelStats | All level stats |
| GET | /api/v1/leaderboard | GetLeaderboard | Leaderboard entries |

#### WebSocket

| Endpoint | Handler | Description |
|----------|---------|-------------|
| /ws/events | SubscribeEvents | Real-time event stream |
| /ws/user/:address | SubscribeUserEvents | User-specific events |

#### gRPC

All methods from `indexer.v1.IndexerService`

### 5.2 ghostnet-fleet Endpoints

#### HTTP REST (Admin)

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| GET | /admin/wallets | ListWallets | List all wallets |
| GET | /admin/wallets/:id | GetWallet | Get wallet details |
| POST | /admin/wallets | AddWallet | Add new wallet |
| DELETE | /admin/wallets/:id | RemoveWallet | Remove wallet |
| PATCH | /admin/wallets/:id/profile | UpdateWalletProfile | Update profile |
| GET | /admin/actions | ListActions | List actions |
| POST | /admin/actions/:id/execute | ExecuteAction | Execute action |
| POST | /admin/actions/simulate | SimulateAction | Simulate action |
| GET | /admin/status | GetStatus | Service status |
| POST | /admin/pause | PauseService | Pause service |
| POST | /admin/resume | ResumeService | Resume service |

### 5.3 ghostnet-signer Endpoints

#### HTTP REST

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| POST | /v1/sign/daily | SignDailyClaim | Sign daily mission |
| POST | /v1/verify/daily | VerifyDailyClaim | Verify daily claim |
| POST | /v1/sign/message | SignMessage | Sign generic message |
| POST | /v1/verify/message | VerifyMessage | Verify signature |
| GET | /v1/public-key | GetPublicKey | Get signer public key |

---

## 6. Data Flow Architecture

### 6.1 Event Ingestion Flow

```
MegaETH Chain
     │
     │ Logs
     ▼
┌─────────────────────────────────────────┐
│        ghostnet-api (Indexer)           │
│  ┌──────────────┐    ┌──────────────┐  │
│  │BlockProcessor│───▶│EventRouter   │  │
│  │(Alloy RPC)   │    │(27 events)   │  │
│  └──────────────┘    └──────┬───────┘  │
│                             │          │
│         ┌───────────────────┼─────┐    │
│         │                   │     │    │
│         ▼                   ▼     ▼    │
│  ┌─────────────┐    ┌─────────────┐    │
│  │TimescaleDB  │    │Apache Iggy  │    │
│  │(Persistence)│    │(Streaming)  │    │
│  └─────────────┘    └──────┬──────┘    │
│                            │           │
└────────────────────────────┼───────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ WebSocket Server │
                    │  (Ishizue HTTP)  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │    Web App       │
                    │  (SvelteKit)     │
                    └──────────────────┘
```

### 6.2 Query Flow

```
Web App
   │
   │ HTTP GET /api/v1/positions/:address
   ▼
┌────────────────────────┐
│   Ishizue HTTP         │
│   Entrypoint (:8080)   │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   Core Middleware      │
│   (Tracing, Rate Limit)│
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   Generated Bridge     │
│   (Proto → Rust)       │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   Handler              │
│   GetPosition::handler │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   Domain Layer         │
│   PositionService      │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   Adapter (StorePort)  │
│   PostgresStore        │
└───────────┬────────────┘
            │
            ▼
     TimescaleDB
```

---

## 7. Configuration Strategy

### 7.1 Service Configuration Hierarchy

```
config/
├── base.toml              # Default values (checked in)
├── development.toml       # Local dev overrides
├── staging.toml           # Staging environment
└── production.toml        # Production environment

# Environment variables (highest priority)
# GHOSTNET_API_DATABASE__URL
# GHOSTNET_API_RPC__URL
# GHOSTNET_SIGNER__PRIVATE_KEY
```

### 7.2 Configuration Schema

```toml
# base.toml
[service]
name = "ghostnet-api"
version = "0.1.0"

[server]
http_port = 8080
grpc_port = 9090
admin_port = 8081

[rpc]
url = "https://carrot.megaeth.com/rpc"
ws_url = "wss://carrot.megaeth.com/rpc"
chain_id = 6343

[database]
url = "postgres://localhost:5432/ghostnet"
max_connections = 10

[iggy]
url = "tcp://localhost:8090"
stream_name = "ghostnet"

[cache]
positions_ttl_ms = 5000
max_capacity = 100000

[middleware]
tracing_enabled = true
rate_limit_requests_per_minute = 100
```

---

## 8. Security Considerations

### 8.1 Entrypoint Security

See also: [`ishizue-migration-plan.md` § Port Allocation](./ishizue-migration-plan.md#port-allocation) for the canonical port table.

| Entrypoint | Port | Exposure | TLS | Auth | Rate Limit |
|------------|------|----------|-----|------|------------|
| ghostnet-api HTTP (public) | 8080 | Public | Required | None (read-only) | 100 req/min |
| ghostnet-api gRPC (mesh) | 9090 | Internal | Required | mTLS | 1000 req/min |
| ghostnet-api Admin | 9190 | Internal (localhost) | Required | API Key | 10 req/min |
| ghostnet-signer HTTP | 8082 | Internal | Required | mTLS + API Key | 20 req/min |
| ghostnet-signer gRPC | 9092 | Internal | Required | mTLS | 100 req/min |
| ghostnet-signer Admin | 9192 | Internal (localhost) | Required | API Key | 10 req/min |
| ghostnet-fleet HTTP (admin) | 8083 | Internal | Required | JWT | 50 req/min |
| ghostnet-fleet gRPC (mesh) | 9093 | Internal | Required | mTLS | 500 req/min |
| ghostnet-fleet Admin | 9193 | Internal (localhost) | Required | API Key | 10 req/min |

### 8.2 Secrets Management

| Secret | Location | Rotation |
|--------|----------|----------|
| Database URL | Environment | On credential rotation |
| RPC API Keys | Environment | Quarterly |
| Signer Private Key | HSM/Vault | Monthly |
| API Keys | Vault | Quarterly |

---

## 9. Observability Plan

### 9.1 Metrics

| Metric | Type | Labels |
|--------|------|--------|
| `indexer_events_processed_total` | Counter | event_type, contract |
| `indexer_block_lag_seconds` | Gauge | - |
| `api_requests_total` | Counter | method, path, status |
| `api_request_duration_seconds` | Histogram | method, path |
| `fleet_wallets_active` | Gauge | profile |
| `fleet_actions_total` | Counter | action_type, status |
| `signer_signatures_total` | Counter | type |

### 9.2 Distributed Tracing

Trace context propagation through:
1. Web App → API (HTTP headers)
2. API → Database (query comments)
3. API → Iggy (message metadata)
4. Fleet → API (gRPC metadata)

---

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Ishizue CLI incompatible with hybrid workspace | Medium | High | Scaffold in temp dir first; adapt manually if needed |
| Ishizue framework gaps | Medium | High | Keep old services as reference; revert if needed |
| Proto auto-discovery fails (names don't match) | High | Low | Use explicit `proto_paths` in each `ishizue.toml` |
| Performance regression | Low | Medium | Load testing; framework overhead target < 5% |
| WebSocket/SSE mapping unclear in Ishizue HTTP | Medium | Medium | Implement as custom handler if framework doesn't support |
| Team learning curve | Medium | Low | Documentation; start with greenfield signer service |

See also: [`ishizue-migration-plan.md` § Risk Assessment](./ishizue-migration-plan.md#risk-assessment) for additional risks.

---

## 11. Appendices

### Appendix A: Migration Checklist

- [ ] Proto definitions reviewed and approved
- [ ] Ishizue workspace initialized
- [ ] ghostnet-api service scaffolded
- [ ] Domain logic migrated from existing indexer
- [ ] Database adapters implemented
- [ ] REST endpoints tested
- [ ] gRPC endpoints tested
- [ ] WebSocket streaming tested
- [ ] ghostnet-signer service implemented
- [ ] ghostnet-fleet service implemented
- [ ] Web app migrated to new APIs
- [ ] Integration tests passing
- [ ] Performance benchmarks met
- [ ] Security audit passed
- [ ] Documentation complete
- [ ] Production deployment plan approved

### Appendix B: Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-07 | Adopt Ishizue workspace model | Multiple services need unified tooling and shared protos |
| 2026-02-07 | Ishizue workspace is the foundation | Optimal architecture from first principles; cherry-pick old code, don't migrate |
| 2026-02-07 | Keep ghostnet-actions as library | Service boundary is at fleet orchestrator, not individual protocols |
| 2026-02-07 | Create dedicated signer service | Signing keys need isolated security boundary |
| 2026-02-07 | HTTP + gRPC for all services | HTTP for web clients, gRPC for inter-service |
| 2026-02-07 | Match proto dirs to service names | Let Ishizue auto-discovery work; `proto/ghostnet-api/` not `proto/indexer/` |
| 2026-02-07 | Use Alloy (not ethers-rs) for signer | ethers-rs is deprecated; existing codebase uses Alloy 1.4 |
| 2026-02-07 | Port convention: 808x / 909x / 919x | Public HTTP, mesh gRPC, admin ports separated by convention |
| 2026-02-07 | Domain crate as library in `libs/` | Pure types/traits; not an Ishizue service; optional `sqlx` feature |
| 2026-02-07 | Native `async fn in trait` (edition 2024) | Rust 1.88; avoid `async_trait` macro overhead |

---

*This document is a living specification. Updates should be tracked via ADRs in `docs/decisions/`.*
