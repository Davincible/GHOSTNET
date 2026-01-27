# TimescaleDB for Blockchain Event Indexers

## A Comprehensive Guide for the GHOSTNET Indexer Architecture

**Version**: 1.0.0  
**Date**: January 2026  
**Author**: Technical Architecture Guide

---

## Executive Summary

This guide provides an in-depth analysis of TimescaleDB for blockchain event indexing, specifically tailored to the GHOSTNET protocol's Rust-based indexer. Based on the latest TimescaleDB features (v2.22-2.24) and industry patterns for crypto data management, this document covers architecture decisions, implementation patterns, and production best practices.

**Key Recommendation**: For your GHOSTNET indexer, adopt a **hybrid approach**—use TimescaleDB hypertables for high-volume, time-ordered event data while keeping entity tables as standard PostgreSQL tables. This provides optimal performance without over-engineering.

---

## Table of Contents

1. [TimescaleDB 2024-2025 Feature Overview](#1-timescaledb-2024-2025-feature-overview)
2. [Architectural Decision Framework](#2-architectural-decision-framework)
3. [Schema Design for Blockchain Data](#3-schema-design-for-blockchain-data)
4. [Compression & Columnstore Configuration](#4-compression--columnstore-configuration)
5. [Continuous Aggregates for Analytics](#5-continuous-aggregates-for-analytics)
6. [Data Retention Strategies](#6-data-retention-strategies)
7. [Reorg Handling with TimescaleDB](#7-reorg-handling-with-timescaledb)
8. [Rust/SQLx Integration](#8-rustsqlx-integration)
9. [Performance Optimization](#9-performance-optimization)
10. [Production Deployment](#10-production-deployment)
11. [Complete Schema Implementation](#11-complete-schema-implementation)

---

## 1. TimescaleDB 2024-2025 Feature Overview

### 1.1 Latest Release Highlights (v2.20 - v2.24)

TimescaleDB has undergone significant evolution. Here are the features most relevant to blockchain indexing:

#### Columnstore Improvements (v2.20+)

| Feature | Benefit for Indexers |
|---------|---------------------|
| **Bloom Filter Indexes** | 6x faster point queries on high-cardinality columns (addresses, tx hashes) |
| **SkipScan Support** | 90x faster DISTINCT queries—perfect for "unique addresses" analytics |
| **10x Faster Backfills** | Critical for historical sync and reprocessing after reorgs |
| **Direct-to-Columnstore Inserts** | 40x faster COPY operations, 80% reduced disk I/O |

#### Zero-Config Hypertables (v2.23)

```sql
-- New simplified syntax with automatic columnstore policy
CREATE TABLE events (
    time TIMESTAMPTZ NOT NULL,
    event_type TEXT,
    data JSONB
);

-- Single command creates hypertable + enables columnstore + adds compression policy
SELECT create_hypertable('events', 'time');
```

#### UUIDv7 Support (v2.22)

For blockchain data, UUIDv7 offers an interesting alternative to composite primary keys:

```sql
-- UUIDv7 encodes timestamp + randomness
-- Allows time-based partitioning on UUID columns
SELECT time_bucket('1 hour', uuid_timestamp(event_id)) AS bucket
FROM events
WHERE uuid_timestamp(event_id) >= '2025-01-01';
```

#### PostgreSQL 18 Compatibility (v2.23)

Full support for async I/O improvements and latest PostgreSQL features.

### 1.2 Hypercore: The Hybrid Row-Columnar Engine

TimescaleDB's storage architecture uniquely suits blockchain data:

```
┌─────────────────────────────────────────────────────────────────┐
│                     HYPERTABLE (events)                         │
├─────────────────────────────────────────────────────────────────┤
│  Recent Chunks (Rowstore)          │  Older Chunks (Columnstore)│
│  ┌─────────────────────────────┐   │  ┌─────────────────────────┐
│  │ Fast INSERT/UPDATE          │   │  │ 90%+ compression        │
│  │ Real-time queries           │   │  │ Vectorized analytics    │
│  │ Last 1-24 hours             │   │  │ Sparse indexes          │
│  └─────────────────────────────┘   │  └─────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight**: Data automatically transitions from rowstore (optimized for writes) to columnstore (optimized for reads/compression) based on your configured policy.

---

## 2. Architectural Decision Framework

### 2.1 When to Use Hypertables vs. Regular Tables

Based on your GHOSTNET schema, here's the classification:

#### Convert to Hypertables ✅

| Table | Reasoning |
|-------|-----------|
| `token_transfers` | High volume, append-only, time-range queries for analytics |
| `position_history` | Audit trail, append-only, time-based lookups |
| `deaths` | Event log, time-ordered, scan correlation |
| `scans` | Time-series scan history, analytics queries |
| `bets` | Time-ordered betting activity |
| `buybacks` | Infrequent but pure time-series |
| `block_history` | Perfect fit—time-ordered, auto-pruned after 128 blocks |

#### Keep as Regular Tables ❌

| Table | Reasoning |
|-------|-----------|
| `positions` | Entity table with frequent updates, queried by address |
| `rounds` | Small dataset, active state lookups by ID |
| `boosts` | Few rows, queried by user address and expiry |
| `level_stats` | 5 rows, singleton aggregates |
| `global_stats` | 1 row, singleton |
| `leaderboard_cache` | Periodically refreshed, not time-series |
| `indexer_state` | Configuration table, 1 row per chain |

### 2.2 Decision Flowchart

```
                    ┌─────────────────────────┐
                    │ Is it append-mostly?    │
                    └───────────┬─────────────┘
                               │
              ┌────────────────┼────────────────┐
              │ YES            │                │ NO
              ▼                │                ▼
    ┌─────────────────┐        │      ┌─────────────────┐
    │ Will you query  │        │      │ Regular         │
    │ by time ranges? │        │      │ PostgreSQL      │
    └────────┬────────┘        │      │ Table           │
             │                 │      └─────────────────┘
    ┌────────┼────────┐        │
    │ YES    │        │ NO     │
    ▼        │        ▼        │
┌────────────┴───┐  ┌─────────────────┐
│ HYPERTABLE     │  │ Consider if     │
│ with           │  │ compression     │
│ compression    │  │ alone helps     │
└────────────────┘  └─────────────────┘
```

---

## 3. Schema Design for Blockchain Data

### 3.1 Hypertable Configuration Principles

#### Chunk Interval Selection

The chunk interval determines partition size. For blockchain indexers:

```sql
-- Events table: 6-hour chunks
-- Rationale: ~10k-100k events per chunk on active chains
SELECT create_hypertable(
    'token_transfers',
    'created_at',
    chunk_time_interval => INTERVAL '6 hours'
);

-- Block history: 1-hour chunks (auto-pruned, small)
SELECT create_hypertable(
    'block_history',
    'timestamp',
    chunk_time_interval => INTERVAL '1 hour'
);

-- Deaths: 1-day chunks (lower volume)
SELECT create_hypertable(
    'deaths',
    'created_at',
    chunk_time_interval => INTERVAL '1 day'
);
```

**Rule of Thumb**: Aim for chunks containing 100K-10M rows for optimal compression and query performance.

#### Segmentby and Orderby Strategy

These settings dramatically impact compression ratios and query performance:

```sql
-- Token transfers: segment by address for efficient wallet queries
ALTER TABLE token_transfers SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'from_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

-- Deaths: segment by level for level-specific analytics
ALTER TABLE deaths SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'created_at DESC, scan_id'
);

-- Scans: segment by level (primary query dimension)
ALTER TABLE scans SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'executed_at DESC'
);
```

**Critical**: Choose `segmentby` based on your most common WHERE clause filters.

### 3.2 Optimized GHOSTNET Schema

Here's the complete optimized schema:

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- EXTENSION SETUP
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXER STATE (Regular Table - Configuration)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE indexer_state (
    id SERIAL PRIMARY KEY,
    chain_id BIGINT NOT NULL UNIQUE,
    last_block BIGINT NOT NULL DEFAULT 0,
    last_block_hash BYTEA,
    last_block_timestamp TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCK HISTORY (Hypertable - Auto-pruned)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE block_history (
    block_number BIGINT NOT NULL,
    block_hash BYTEA NOT NULL,
    parent_hash BYTEA NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (timestamp, block_number)
);

SELECT create_hypertable('block_history', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour');

-- Auto-prune after 128 blocks (~25 minutes on MegaETH)
SELECT add_retention_policy('block_history', INTERVAL '30 minutes');

-- ═══════════════════════════════════════════════════════════════════════════
-- POSITIONS (Regular Table - Entity with Updates)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_address BYTEA NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
    amount NUMERIC(78, 0) NOT NULL,
    reward_debt NUMERIC(78, 0) NOT NULL DEFAULT 0,
    entry_timestamp TIMESTAMPTZ NOT NULL,
    last_add_timestamp TIMESTAMPTZ,
    ghost_streak INTEGER NOT NULL DEFAULT 0,
    is_alive BOOLEAN NOT NULL DEFAULT TRUE,
    is_extracted BOOLEAN NOT NULL DEFAULT FALSE,
    extracted_at TIMESTAMPTZ,
    extracted_amount NUMERIC(78, 0),
    extracted_rewards NUMERIC(78, 0),
    created_at_block BIGINT NOT NULL,
    created_at_tx BYTEA NOT NULL,
    updated_at_block BIGINT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_positions_user ON positions(user_address);
CREATE INDEX idx_positions_level_alive ON positions(level) WHERE is_alive = TRUE;
CREATE INDEX idx_positions_ghost_streak ON positions(ghost_streak DESC) WHERE is_alive = TRUE;
CREATE INDEX idx_positions_level_amount ON positions(level, amount ASC) WHERE is_alive = TRUE;

-- Partial unique constraint for active positions
CREATE UNIQUE INDEX idx_positions_unique_active 
    ON positions(user_address) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- ═══════════════════════════════════════════════════════════════════════════
-- POSITION HISTORY (Hypertable - Append-only Audit)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE position_history (
    id UUID DEFAULT gen_random_uuid(),
    position_id UUID NOT NULL,
    user_address BYTEA NOT NULL,  -- Denormalized for efficient queries
    action VARCHAR(20) NOT NULL,
    amount_change NUMERIC(78, 0),
    new_total NUMERIC(78, 0),
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('position_history', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE position_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('position_history', INTERVAL '1 day');

CREATE INDEX idx_position_history_user ON position_history(user_address, created_at DESC);
CREATE INDEX idx_position_history_position ON position_history(position_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- SCANS (Hypertable - Time-series)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE scans (
    id UUID DEFAULT gen_random_uuid(),
    scan_id NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
    seed NUMERIC(78, 0) NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL,
    finalized_at TIMESTAMPTZ,
    death_count INTEGER,
    total_dead NUMERIC(78, 0),
    burned NUMERIC(78, 0),
    distributed_same_level NUMERIC(78, 0),
    distributed_upstream NUMERIC(78, 0),
    protocol_fee NUMERIC(78, 0),
    survivor_count INTEGER,
    executed_block BIGINT NOT NULL,
    executed_tx BYTEA NOT NULL,
    finalized_block BIGINT,
    finalized_tx BYTEA,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (executed_at, id),
    UNIQUE (level, scan_id)
);

SELECT create_hypertable('scans', 'executed_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE scans SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'executed_at DESC'
);

SELECT add_compression_policy('scans', INTERVAL '7 days');

CREATE INDEX idx_scans_level_time ON scans(level, executed_at DESC);
CREATE INDEX idx_scans_pending ON scans(level, executed_at) WHERE finalized_at IS NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- DEATHS (Hypertable - High volume events)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE deaths (
    id UUID DEFAULT gen_random_uuid(),
    scan_id UUID,  -- Reference to scans table (manual, not FK for performance)
    user_address BYTEA NOT NULL,
    position_id UUID,
    amount_lost NUMERIC(78, 0) NOT NULL,
    level SMALLINT NOT NULL,
    ghost_streak_at_death INTEGER,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('deaths', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE deaths SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'created_at DESC, user_address'
);

SELECT add_compression_policy('deaths', INTERVAL '3 days');

CREATE INDEX idx_deaths_user ON deaths(user_address, created_at DESC);
CREATE INDEX idx_deaths_level ON deaths(level, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKEN TRANSFERS (Hypertable - Very high volume)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE token_transfers (
    id UUID DEFAULT gen_random_uuid(),
    from_address BYTEA NOT NULL,
    to_address BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    tax_burned NUMERIC(78, 0),
    tax_collected NUMERIC(78, 0),
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    log_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('token_transfers', 'created_at',
    chunk_time_interval => INTERVAL '6 hours');

ALTER TABLE token_transfers SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'from_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('token_transfers', INTERVAL '1 day');

-- Index only large transfers for whale tracking
CREATE INDEX idx_transfers_large ON token_transfers(created_at DESC) 
    WHERE amount > 1000000000000000000000;  -- > 1000 DATA

CREATE INDEX idx_transfers_from ON token_transfers(from_address, created_at DESC);
CREATE INDEX idx_transfers_to ON token_transfers(to_address, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- PREDICTION MARKETS (Regular + Hypertable)
-- ═══════════════════════════════════════════════════════════════════════════

-- Rounds: Regular table (entity, few rows, status lookups)
CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id NUMERIC(78, 0) NOT NULL UNIQUE,
    round_type SMALLINT NOT NULL,
    target_level SMALLINT CHECK (target_level IS NULL OR target_level BETWEEN 1 AND 5),
    line NUMERIC(78, 0) NOT NULL,
    deadline TIMESTAMPTZ NOT NULL,
    over_pool NUMERIC(78, 0) NOT NULL DEFAULT 0,
    under_pool NUMERIC(78, 0) NOT NULL DEFAULT 0,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    outcome BOOLEAN,
    resolve_time TIMESTAMPTZ,
    total_burned NUMERIC(78, 0),
    created_block BIGINT NOT NULL,
    created_tx BYTEA NOT NULL,
    resolved_block BIGINT,
    resolved_tx BYTEA,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rounds_active ON rounds(deadline) WHERE is_resolved = FALSE;
CREATE INDEX idx_rounds_type ON rounds(round_type, created_at DESC);

-- Bets: Hypertable (high volume, time-ordered)
CREATE TABLE bets (
    id UUID DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL,
    round_id_numeric NUMERIC(78, 0) NOT NULL,
    user_address BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    is_over BOOLEAN NOT NULL,
    is_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    winnings NUMERIC(78, 0),
    claimed_at TIMESTAMPTZ,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id),
    UNIQUE (round_id, user_address)
);

SELECT create_hypertable('bets', 'created_at',
    chunk_time_interval => INTERVAL '1 day');

ALTER TABLE bets SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_address',
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('bets', INTERVAL '7 days');

CREATE INDEX idx_bets_user ON bets(user_address, created_at DESC);
CREATE INDEX idx_bets_round ON bets(round_id);
CREATE INDEX idx_bets_unclaimed ON bets(round_id) WHERE is_claimed = FALSE;

-- ═══════════════════════════════════════════════════════════════════════════
-- BUYBACKS (Hypertable - Low volume but pure time-series)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE buybacks (
    id UUID DEFAULT gen_random_uuid(),
    eth_spent NUMERIC(78, 0) NOT NULL,
    data_received NUMERIC(78, 0) NOT NULL,
    data_burned NUMERIC(78, 0) NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id)
);

SELECT create_hypertable('buybacks', 'created_at',
    chunk_time_interval => INTERVAL '7 days');

ALTER TABLE buybacks SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'created_at DESC'
);

SELECT add_compression_policy('buybacks', INTERVAL '30 days');

-- ═══════════════════════════════════════════════════════════════════════════
-- STATISTICS (Regular Tables - Aggregates)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE level_stats (
    level SMALLINT PRIMARY KEY CHECK (level BETWEEN 1 AND 5),
    total_staked NUMERIC(78, 0) NOT NULL DEFAULT 0,
    alive_count INTEGER NOT NULL DEFAULT 0,
    total_deaths INTEGER NOT NULL DEFAULT 0,
    total_extracted INTEGER NOT NULL DEFAULT 0,
    total_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_distributed NUMERIC(78, 0) NOT NULL DEFAULT 0,
    highest_ghost_streak INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO level_stats (level) VALUES (1), (2), (3), (4), (5);

CREATE TABLE global_stats (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    total_value_locked NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_positions INTEGER NOT NULL DEFAULT 0,
    total_deaths INTEGER NOT NULL DEFAULT 0,
    total_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_emissions_distributed NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_toll_collected NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_buyback_burned NUMERIC(78, 0) NOT NULL DEFAULT 0,
    system_reset_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO global_stats DEFAULT VALUES;
```

---

## 4. Compression & Columnstore Configuration

### 4.1 How Compression Works

TimescaleDB's compression achieves 90%+ size reduction through:

1. **Column-oriented storage**: Each column stored separately
2. **Dictionary encoding**: High-cardinality values mapped to integers
3. **Delta encoding**: Timestamps stored as deltas
4. **LZ compression**: Final compression pass

```
Before Compression (Row-oriented):
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ timestamp    │ user_address │ amount       │ level        │
├──────────────┼──────────────┼──────────────┼──────────────┤
│ 2025-01-20   │ 0xabc...     │ 1000000      │ 3            │
│ 2025-01-20   │ 0xdef...     │ 2000000      │ 3            │
│ 2025-01-20   │ 0xabc...     │ 500000       │ 2            │
└──────────────┴──────────────┴──────────────┴──────────────┘

After Compression (Column-oriented):
┌─────────────────────────────────────────────────────────────┐
│ timestamps: [delta_encoded: +0, +1s, +2s, ...]             │
│ addresses:  [dictionary: {1: 0xabc, 2: 0xdef}, refs: 1,2,1]│
│ amounts:    [gorilla_encoded: 1000000, 2000000, 500000]    │
│ levels:     [run_length: 3,3,2]                            │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Segmentby Selection Guide

| Query Pattern | Segmentby Choice | Rationale |
|--------------|------------------|-----------|
| `WHERE user_address = ?` | `user_address` | All user's data in same segment |
| `WHERE level = ?` | `level` | Level-specific queries scan 1/5 of data |
| `WHERE token = ? AND time > ?` | `token` | Token-specific analytics |
| No specific filter | (none) | Pure time-series aggregates |

**Critical Rule**: Only ONE segment per query is decompressed. Multi-segment queries decompress all segments.

### 4.3 Orderby Optimization

```sql
-- GOOD: Query pattern matches orderby
ALTER TABLE deaths SET (
    timescaledb.compress_orderby = 'created_at DESC'
);

-- Query benefits from ordering
SELECT * FROM deaths 
WHERE level = 3 
ORDER BY created_at DESC 
LIMIT 100;  -- Very fast: reads first 100 from ordered segment

-- BAD: Query pattern doesn't match
SELECT * FROM deaths 
WHERE level = 3 
ORDER BY amount_lost DESC 
LIMIT 100;  -- Slow: must decompress entire segment to sort
```

### 4.4 Compression Policies

```sql
-- View current compression settings
SELECT * FROM timescaledb_information.compression_settings;

-- Check compression status
SELECT 
    hypertable_name,
    compression_status,
    COUNT(*) as chunk_count,
    pg_size_pretty(SUM(before_compression_total_bytes)) as uncompressed,
    pg_size_pretty(SUM(after_compression_total_bytes)) as compressed,
    ROUND(AVG(compression_ratio), 2) as avg_ratio
FROM timescaledb_information.compressed_chunk_stats
GROUP BY hypertable_name, compression_status;

-- Manual compression of specific chunks (useful during reorg recovery)
SELECT compress_chunk(c.chunk_schema || '.' || c.chunk_name)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'token_transfers'
  AND c.is_compressed = false
  AND c.range_end < NOW() - INTERVAL '1 day';
```

### 4.5 Bloom Filter Indexes (v2.20+)

For high-cardinality columns like addresses and tx hashes:

```sql
-- Enable bloom filter sparse indexes (on by default in 2.20+)
SET timescaledb.enable_sparse_index_bloom = on;

-- Bloom filters automatically created during compression
-- They enable fast filtering on non-segmentby columns

-- Query pattern that benefits:
SELECT * FROM token_transfers
WHERE created_at > NOW() - INTERVAL '7 days'
  AND tx_hash = '\x1234...';  -- Bloom filter filters batches before decompression
```

---

## 5. Continuous Aggregates for Analytics

### 5.1 Core Concept

Continuous aggregates are incrementally-updated materialized views that TimescaleDB refreshes automatically:

```
Raw Events (millions of rows)
         │
         ▼
┌─────────────────────────────────────┐
│     Continuous Aggregate            │
│     (pre-computed summaries)        │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Materialized data           │   │  Watermark
│  │ (chunks from past)          │   │     │
│  ├─────────────────────────────┤◀──┼─────┘
│  │ Real-time query             │   │
│  │ (combines with raw data)    │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
         │
         ▼
    Fast queries (milliseconds)
```

### 5.2 GHOSTNET Analytics Aggregates

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- TVL BY LEVEL (Hourly)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW tvl_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    action,
    SUM(CASE WHEN action IN ('created', 'stake_added') THEN amount_change ELSE 0 END) as deposits,
    SUM(CASE WHEN action = 'extracted' THEN amount_change ELSE 0 END) as withdrawals,
    COUNT(*) as event_count
FROM position_history
GROUP BY bucket, action
WITH NO DATA;

-- Refresh policy: last 24 hours, every 5 minutes
SELECT add_continuous_aggregate_policy('tvl_hourly',
    start_offset => INTERVAL '24 hours',
    end_offset => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- DEATH STATISTICS (Hourly per Level)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW death_stats_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    level,
    COUNT(*) as death_count,
    SUM(amount_lost) as total_lost,
    AVG(amount_lost) as avg_lost,
    MAX(amount_lost) as max_lost,
    AVG(ghost_streak_at_death) as avg_streak_at_death
FROM deaths
GROUP BY bucket, level
WITH NO DATA;

SELECT add_continuous_aggregate_policy('death_stats_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Enable compression on the continuous aggregate itself!
ALTER MATERIALIZED VIEW death_stats_hourly SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('death_stats_hourly', INTERVAL '7 days');

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN METRICS (Per Scan)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW scan_metrics
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', executed_at) AS bucket,
    level,
    COUNT(*) as scan_count,
    SUM(death_count) as total_deaths,
    SUM(total_dead) as total_lost,
    SUM(burned) as total_burned,
    AVG(death_count) as avg_deaths_per_scan
FROM scans
WHERE finalized_at IS NOT NULL
GROUP BY bucket, level
WITH NO DATA;

SELECT add_continuous_aggregate_policy('scan_metrics',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TRANSFER VOLUME (Hourly)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW transfer_volume_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    COUNT(*) as transfer_count,
    SUM(amount) as total_volume,
    SUM(tax_burned) as total_tax_burned,
    SUM(tax_collected) as total_tax_collected,
    COUNT(DISTINCT from_address) as unique_senders,
    COUNT(DISTINCT to_address) as unique_receivers
FROM token_transfers
GROUP BY bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('transfer_volume_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- HIERARCHICAL AGGREGATE: Daily from Hourly
-- ═══════════════════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW transfer_volume_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', bucket) AS bucket,
    SUM(transfer_count) as transfer_count,
    SUM(total_volume) as total_volume,
    SUM(total_tax_burned) as total_tax_burned
FROM transfer_volume_hourly
GROUP BY time_bucket('1 day', bucket)
WITH NO DATA;

SELECT add_continuous_aggregate_policy('transfer_volume_daily',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);
```

### 5.3 Real-Time vs Materialized-Only

```sql
-- Real-time (default): Combines materialized data with fresh raw data
CREATE MATERIALIZED VIEW stats_realtime
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
...

-- Materialized-only: Only shows pre-computed data (faster, but potentially stale)
CREATE MATERIALIZED VIEW stats_materialized
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
...

-- Toggle at runtime
ALTER MATERIALIZED VIEW stats_realtime SET (timescaledb.materialized_only = true);
```

### 5.4 Query Patterns

```sql
-- API endpoint: GET /api/v1/stats/tvl/history
SELECT 
    bucket,
    SUM(deposits) - SUM(withdrawals) as net_tvl_change
FROM tvl_hourly
WHERE bucket >= NOW() - INTERVAL '7 days'
GROUP BY bucket
ORDER BY bucket;

-- API endpoint: GET /api/v1/stats/deaths/by-level
SELECT 
    level,
    SUM(death_count) as total_deaths,
    SUM(total_lost) as total_lost,
    AVG(avg_streak_at_death) as avg_streak
FROM death_stats_hourly
WHERE bucket >= NOW() - INTERVAL '30 days'
GROUP BY level
ORDER BY level;
```

---

## 6. Data Retention Strategies

### 6.1 Tiered Retention Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA LIFECYCLE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Hot Data          Warm Data              Cold Data           Archived      │
│  (0-24h)           (1-7 days)             (7-90 days)         (90+ days)    │
│  ┌─────────┐       ┌─────────┐           ┌─────────┐         ┌─────────┐   │
│  │ Rowstore│──────▶│Columnstr│──────────▶│Columnstr│────────▶│ Dropped │   │
│  │Uncompres│       │Compressd│           │Compressd│         │or S3    │   │
│  └─────────┘       └─────────┘           └─────────┘         └─────────┘   │
│                                                                             │
│  Full indexes      Sparse indexes        Sparse indexes      Aggregates    │
│  Real-time         Real-time queries     Analytics only      only remain   │
│  queries           still fast            Time-range req'd                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 GHOSTNET Retention Policies

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- RETENTION POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Block history: Keep only recent for reorg detection (30 minutes)
SELECT add_retention_policy('block_history', INTERVAL '30 minutes');

-- Token transfers: Keep 90 days of raw data
-- (Continuous aggregates retain summarized data indefinitely)
SELECT add_retention_policy('token_transfers', INTERVAL '90 days');

-- Deaths: Keep 1 year (important for historical analysis)
SELECT add_retention_policy('deaths', INTERVAL '365 days');

-- Position history: Keep 1 year
SELECT add_retention_policy('position_history', INTERVAL '365 days');

-- Bets: Keep 90 days
SELECT add_retention_policy('bets', INTERVAL '90 days');

-- Scans: Keep indefinitely (low volume, important history)
-- No retention policy

-- Buybacks: Keep indefinitely (very low volume)
-- No retention policy

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTINUOUS AGGREGATE RETENTION
-- ═══════════════════════════════════════════════════════════════════════════

-- Keep daily aggregates for 2 years even after raw data is dropped
SELECT add_retention_policy('transfer_volume_daily', INTERVAL '730 days');
SELECT add_retention_policy('death_stats_hourly', INTERVAL '365 days');
SELECT add_retention_policy('scan_metrics', INTERVAL '730 days');
```

### 6.3 Coordinating Retention with Continuous Aggregates

**Critical**: Ensure continuous aggregate refresh windows don't overlap with retention windows.

```sql
-- WRONG: Data will disappear from aggregate
SELECT add_continuous_aggregate_policy('my_agg',
    start_offset => INTERVAL '7 days',   -- Refreshes 7 days back
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
SELECT add_retention_policy('source_table', INTERVAL '3 days');  -- Deletes after 3 days!
-- Result: Aggregate loses data from days 4-7

-- CORRECT: Retention > Refresh window
SELECT add_continuous_aggregate_policy('my_agg',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
SELECT add_retention_policy('source_table', INTERVAL '14 days');  -- Safe margin
```

---

## 7. Reorg Handling with TimescaleDB

### 7.1 Blockchain Reorg Fundamentals

```
Block 100 ─── Block 101 ─── Block 102 ─── Block 103 (your head)
                  │
                  └─── Block 101' ─── Block 102' ─── Block 103' ─── Block 104' (new canonical)
                       
Reorg detected at block 101:
1. Delete all data from blocks 101-103
2. Re-index blocks 101'-104'
```

### 7.2 Efficient Reorg Handling in TimescaleDB

The key insight: TimescaleDB chunks make bulk deletes very fast when they align with time boundaries.

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- REORG HANDLING FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_reorg(reorg_block BIGINT)
RETURNS void AS $$
DECLARE
    reorg_timestamp TIMESTAMPTZ;
BEGIN
    -- Get the timestamp of the reorg block
    SELECT timestamp INTO reorg_timestamp
    FROM block_history
    WHERE block_number = reorg_block;
    
    IF reorg_timestamp IS NULL THEN
        -- Block not found, use current time minus safety margin
        reorg_timestamp := NOW() - INTERVAL '1 minute';
    END IF;
    
    -- Delete from all hypertables where block_number >= reorg_block
    -- TimescaleDB will handle chunk-level optimization
    
    DELETE FROM token_transfers 
    WHERE block_number >= reorg_block;
    
    DELETE FROM deaths 
    WHERE block_number >= reorg_block;
    
    DELETE FROM position_history 
    WHERE block_number >= reorg_block;
    
    DELETE FROM bets 
    WHERE block_number >= reorg_block;
    
    DELETE FROM block_history 
    WHERE block_number >= reorg_block;
    
    -- Update positions that were modified in reorged blocks
    -- This is trickier - you need to rebuild state from history
    -- Or maintain a separate "pending" state for recent blocks
    
    -- Update indexer state
    UPDATE indexer_state 
    SET last_block = reorg_block - 1,
        last_block_hash = (
            SELECT block_hash FROM block_history 
            WHERE block_number = reorg_block - 1
        ),
        updated_at = NOW()
    WHERE chain_id = 6342;  -- MegaETH
    
    -- Invalidate continuous aggregates for affected time range
    -- (They will be refreshed on next policy run)
    CALL refresh_continuous_aggregate('tvl_hourly', reorg_timestamp, NOW());
    CALL refresh_continuous_aggregate('death_stats_hourly', reorg_timestamp, NOW());
    
    RAISE NOTICE 'Reorg handled: rolled back to block %', reorg_block - 1;
END;
$$ LANGUAGE plpgsql;

-- Usage in Rust
-- sqlx::query!("SELECT handle_reorg($1)", reorg_block).execute(&pool).await?;
```

### 7.3 Block History for Reorg Detection

```sql
-- Fast parent hash lookup for reorg detection
CREATE OR REPLACE FUNCTION check_for_reorg(
    new_block_number BIGINT,
    new_parent_hash BYTEA
) RETURNS BIGINT AS $$
DECLARE
    stored_hash BYTEA;
    check_block BIGINT;
BEGIN
    check_block := new_block_number - 1;
    
    -- Get the hash we have stored for the parent block
    SELECT block_hash INTO stored_hash
    FROM block_history
    WHERE block_number = check_block;
    
    -- If we don't have the parent or hashes match, no reorg
    IF stored_hash IS NULL OR stored_hash = new_parent_hash THEN
        RETURN NULL;
    END IF;
    
    -- Reorg detected! Find the fork point
    -- Walk back until we find matching hashes
    FOR check_block IN REVERSE (new_block_number - 1)..1 LOOP
        EXIT WHEN check_block < new_block_number - 64;  -- Max reorg depth
        
        -- This would require querying the RPC for the actual chain
        -- In practice, you'd do this in application code
    END LOOP;
    
    RETURN check_block;  -- Fork point
END;
$$ LANGUAGE plpgsql;
```

### 7.4 Pending State Pattern

For data that requires state tracking (like `positions`), use a pending/confirmed pattern:

```sql
-- Add confirmation tracking to positions
ALTER TABLE positions ADD COLUMN confirmed_at_block BIGINT;
ALTER TABLE positions ADD COLUMN is_confirmed BOOLEAN DEFAULT FALSE;

-- Index for finding unconfirmed positions
CREATE INDEX idx_positions_unconfirmed ON positions(created_at_block) 
WHERE is_confirmed = FALSE;

-- Confirmation function (call after N block confirmations)
CREATE OR REPLACE FUNCTION confirm_positions(confirmed_block BIGINT)
RETURNS INTEGER AS $$
DECLARE
    confirmed_count INTEGER;
BEGIN
    UPDATE positions
    SET is_confirmed = TRUE,
        confirmed_at_block = confirmed_block
    WHERE created_at_block <= confirmed_block - 64  -- 64 block confirmations
      AND is_confirmed = FALSE;
    
    GET DIAGNOSTICS confirmed_count = ROW_COUNT;
    RETURN confirmed_count;
END;
$$ LANGUAGE plpgsql;
```

---

## 8. Rust/SQLx Integration

### 8.1 SQLx Configuration for TimescaleDB

```toml
# Cargo.toml
[dependencies]
sqlx = { version = "0.8", features = [
    "runtime-tokio",
    "postgres",
    "chrono",
    "uuid",
    "bigdecimal",
    "migrate",
] }
```

```rust
// src/store/postgres.rs
use sqlx::postgres::{PgPoolOptions, PgPool};
use std::time::Duration;

pub async fn create_pool(database_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(20)
        .min_connections(5)
        .acquire_timeout(Duration::from_secs(30))
        .idle_timeout(Duration::from_secs(600))
        .max_lifetime(Duration::from_secs(1800))
        // Important for TimescaleDB: allow longer statements for compression
        .after_connect(|conn, _meta| {
            Box::pin(async move {
                sqlx::query("SET statement_timeout = '300s'")
                    .execute(conn)
                    .await?;
                Ok(())
            })
        })
        .connect(database_url)
        .await
}
```

### 8.2 Type Mappings for Blockchain Data

```rust
// src/types/primitives.rs
use sqlx::Type;
use serde::{Deserialize, Serialize};

/// Wrapper for blockchain addresses (20 bytes)
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[sqlx(transparent)]
pub struct Address(pub Vec<u8>);

impl Address {
    pub fn from_slice(bytes: &[u8]) -> Self {
        assert_eq!(bytes.len(), 20, "Address must be 20 bytes");
        Self(bytes.to_vec())
    }
    
    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}

/// Wrapper for U256 values (stored as NUMERIC(78,0) in Postgres)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct U256Wrapper(pub bigdecimal::BigDecimal);

impl From<alloy_primitives::U256> for U256Wrapper {
    fn from(value: alloy_primitives::U256) -> Self {
        Self(bigdecimal::BigDecimal::from_str(&value.to_string()).unwrap())
    }
}

impl sqlx::Type<sqlx::Postgres> for U256Wrapper {
    fn type_info() -> sqlx::postgres::PgTypeInfo {
        <bigdecimal::BigDecimal as sqlx::Type<sqlx::Postgres>>::type_info()
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Postgres> for U256Wrapper {
    fn decode(value: sqlx::postgres::PgValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let bd = <bigdecimal::BigDecimal as sqlx::Decode<sqlx::Postgres>>::decode(value)?;
        Ok(Self(bd))
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Postgres> for U256Wrapper {
    fn encode_by_ref(&self, buf: &mut sqlx::postgres::PgArgumentBuffer) -> sqlx::encode::IsNull {
        self.0.encode_by_ref(buf)
    }
}
```

### 8.3 Repository Pattern with TimescaleDB

```rust
// src/store/transfers.rs
use sqlx::PgPool;
use chrono::{DateTime, Utc};
use uuid::Uuid;

pub struct TransferRepository {
    pool: PgPool,
}

impl TransferRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    /// Batch insert transfers using COPY for maximum performance
    pub async fn insert_batch(&self, transfers: &[TokenTransfer]) -> Result<u64, sqlx::Error> {
        // For very high throughput, use COPY
        let mut copy_in = self.pool
            .copy_in_raw("COPY token_transfers (from_address, to_address, amount, tax_burned, tax_collected, block_number, tx_hash, log_index, created_at) FROM STDIN WITH (FORMAT binary)")
            .await?;
        
        for transfer in transfers {
            // Write binary format...
            // (In practice, you'd use a library like `pg_copy` or build the binary format)
        }
        
        let rows = copy_in.finish().await?;
        Ok(rows)
    }
    
    /// Insert single transfer (for low-volume scenarios)
    pub async fn insert(&self, transfer: &TokenTransfer) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query_scalar!(
            r#"
            INSERT INTO token_transfers 
                (from_address, to_address, amount, tax_burned, tax_collected, 
                 block_number, tx_hash, log_index, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id
            "#,
            &transfer.from_address,
            &transfer.to_address,
            &transfer.amount,
            transfer.tax_burned.as_ref(),
            transfer.tax_collected.as_ref(),
            transfer.block_number as i64,
            &transfer.tx_hash,
            transfer.log_index,
            transfer.created_at
        )
        .fetch_one(&self.pool)
        .await?;
        
        Ok(id)
    }
    
    /// Query recent transfers with pagination
    pub async fn get_recent(
        &self,
        limit: i64,
        before: Option<DateTime<Utc>>,
    ) -> Result<Vec<TokenTransfer>, sqlx::Error> {
        let transfers = sqlx::query_as!(
            TokenTransfer,
            r#"
            SELECT 
                id, from_address, to_address, amount, 
                tax_burned, tax_collected, 
                block_number, tx_hash, log_index, created_at
            FROM token_transfers
            WHERE ($1::timestamptz IS NULL OR created_at < $1)
            ORDER BY created_at DESC
            LIMIT $2
            "#,
            before,
            limit
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(transfers)
    }
    
    /// Query transfers by address with time range (leverages compression segmentby)
    pub async fn get_by_address(
        &self,
        address: &[u8],
        from: DateTime<Utc>,
        to: DateTime<Utc>,
    ) -> Result<Vec<TokenTransfer>, sqlx::Error> {
        // This query is optimized because:
        // 1. from_address is the segmentby column
        // 2. created_at range enables chunk exclusion
        let transfers = sqlx::query_as!(
            TokenTransfer,
            r#"
            SELECT 
                id, from_address, to_address, amount, 
                tax_burned, tax_collected, 
                block_number, tx_hash, log_index, created_at
            FROM token_transfers
            WHERE from_address = $1
              AND created_at >= $2 
              AND created_at < $3
            ORDER BY created_at DESC
            "#,
            address,
            from,
            to
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(transfers)
    }
    
    /// Delete transfers for reorg handling
    pub async fn delete_from_block(&self, block_number: i64) -> Result<u64, sqlx::Error> {
        let result = sqlx::query!(
            "DELETE FROM token_transfers WHERE block_number >= $1",
            block_number
        )
        .execute(&self.pool)
        .await?;
        
        Ok(result.rows_affected())
    }
}
```

### 8.4 Querying Continuous Aggregates

```rust
// src/store/analytics.rs
use sqlx::PgPool;
use chrono::{DateTime, Utc};

#[derive(Debug, sqlx::FromRow)]
pub struct HourlyStats {
    pub bucket: DateTime<Utc>,
    pub transfer_count: i64,
    pub total_volume: bigdecimal::BigDecimal,
    pub unique_senders: i64,
}

pub struct AnalyticsRepository {
    pool: PgPool,
}

impl AnalyticsRepository {
    /// Get transfer volume from continuous aggregate
    pub async fn get_transfer_volume(
        &self,
        from: DateTime<Utc>,
        to: DateTime<Utc>,
    ) -> Result<Vec<HourlyStats>, sqlx::Error> {
        // Queries the continuous aggregate, not raw data
        let stats = sqlx::query_as!(
            HourlyStats,
            r#"
            SELECT 
                bucket,
                transfer_count,
                total_volume,
                unique_senders
            FROM transfer_volume_hourly
            WHERE bucket >= $1 AND bucket < $2
            ORDER BY bucket
            "#,
            from,
            to
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(stats)
    }
    
    /// Force refresh of continuous aggregate (useful after reorg)
    pub async fn refresh_aggregate(
        &self,
        aggregate_name: &str,
        from: DateTime<Utc>,
        to: DateTime<Utc>,
    ) -> Result<(), sqlx::Error> {
        // Note: CALL syntax for procedures
        sqlx::query(&format!(
            "CALL refresh_continuous_aggregate('{}', $1, $2)",
            aggregate_name
        ))
        .bind(from)
        .bind(to)
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }
}
```

### 8.5 Migration with TimescaleDB Extensions

```sql
-- migrations/20260120000001_enable_timescaledb.sql

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Verify installation
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'
    ) THEN
        RAISE EXCEPTION 'TimescaleDB extension not installed';
    END IF;
END $$;

-- Set recommended settings for indexer workload
ALTER SYSTEM SET timescaledb.max_background_workers = 8;
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
ALTER SYSTEM SET max_parallel_workers = 8;

-- Reload configuration
SELECT pg_reload_conf();
```

### 8.6 Testing with TimescaleDB

```rust
// tests/common/mod.rs
use sqlx::PgPool;
use testcontainers::{clients::Cli, images::postgres::Postgres, Container};

pub struct TestDb {
    _container: Container<'static, Postgres>,
    pub pool: PgPool,
}

impl TestDb {
    pub async fn new() -> Self {
        let docker = Cli::default();
        
        // Use TimescaleDB image
        let postgres = Postgres::default()
            .with_env_var("POSTGRES_DB", "test")
            .with_env_var("POSTGRES_USER", "test")
            .with_env_var("POSTGRES_PASSWORD", "test");
        
        let container = docker.run(postgres);
        let port = container.get_host_port_ipv4(5432);
        
        let database_url = format!(
            "postgres://test:test@localhost:{}/test",
            port
        );
        
        let pool = PgPool::connect(&database_url).await.unwrap();
        
        // Run migrations
        sqlx::migrate!("./migrations")
            .run(&pool)
            .await
            .unwrap();
        
        Self {
            _container: container,
            pool,
        }
    }
}

#[tokio::test]
async fn test_transfer_insert_and_query() {
    let db = TestDb::new().await;
    let repo = TransferRepository::new(db.pool.clone());
    
    // Insert test data
    let transfer = TokenTransfer {
        from_address: vec![0u8; 20],
        to_address: vec![1u8; 20],
        amount: BigDecimal::from(1000),
        // ...
    };
    
    repo.insert(&transfer).await.unwrap();
    
    // Query and verify
    let results = repo.get_recent(10, None).await.unwrap();
    assert_eq!(results.len(), 1);
}
```

---

## 9. Performance Optimization

### 9.1 Ingestion Optimization

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HIGH-THROUGHPUT INGESTION SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════

-- Session-level settings for bulk loads
SET synchronous_commit = off;  -- For non-critical data
SET work_mem = '256MB';
SET maintenance_work_mem = '1GB';

-- For COPY operations (fastest ingestion method)
-- Use binary format for ~30% speed improvement
COPY token_transfers FROM STDIN WITH (FORMAT binary);

-- Batch size recommendations:
-- - COPY: 10,000-100,000 rows per batch
-- - Multi-row INSERT: 1,000-5,000 rows per statement
-- - Single INSERT: Avoid for high-throughput
```

### 9.2 Query Optimization

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- EXPLAIN ANALYZE FOR TIMESCALEDB QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Check if chunk exclusion is working
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM token_transfers
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND from_address = '\x1234...';

-- Look for:
-- "Chunk Append" with limited chunks scanned
-- "Index Scan" or "Bitmap Index Scan" within chunks
-- "DecompressChunk" showing columnstore decompression

-- Check compression stats
SELECT 
    chunk_name,
    before_compression_total_bytes,
    after_compression_total_bytes,
    compression_ratio
FROM timescaledb_information.compressed_chunk_stats
WHERE hypertable_name = 'token_transfers'
ORDER BY range_start DESC
LIMIT 10;
```

### 9.3 Index Strategy

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- OPTIMIZED INDEXES FOR BLOCKCHAIN QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- For hypertables, indexes are created per-chunk
-- Keep indexes minimal on high-volume tables

-- GOOD: Selective partial index
CREATE INDEX idx_large_transfers ON token_transfers(from_address, created_at DESC)
WHERE amount > 1000000000000000000000;  -- Only index large transfers

-- GOOD: Covering index for common query
CREATE INDEX idx_deaths_level_time ON deaths(level, created_at DESC)
INCLUDE (amount_lost, user_address);  -- Avoid heap lookup

-- BAD: Too many indexes on high-write table
-- Each index adds write overhead
-- CREATE INDEX idx_1 ON transfers(from_address);
-- CREATE INDEX idx_2 ON transfers(to_address);
-- CREATE INDEX idx_3 ON transfers(amount);
-- CREATE INDEX idx_4 ON transfers(tx_hash);

-- Instead, rely on columnstore sparse indexes for analytics
-- and selective B-tree indexes for specific query patterns
```

### 9.4 Background Worker Tuning

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- TIMESCALEDB BACKGROUND WORKER CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

-- View current jobs
SELECT * FROM timescaledb_information.jobs;

-- View job statistics
SELECT 
    job_id,
    application_name,
    total_runs,
    total_successes,
    total_failures,
    last_run_duration
FROM timescaledb_information.job_stats
ORDER BY last_run_started_at DESC;

-- Adjust compression policy schedule (reduce I/O during peak hours)
SELECT alter_job(
    (SELECT job_id FROM timescaledb_information.jobs 
     WHERE hypertable_name = 'token_transfers' 
     AND proc_name = 'policy_compression'),
    schedule_interval => INTERVAL '2 hours',
    scheduled => true
);

-- Pause jobs during initial sync
SELECT alter_job(job_id, scheduled => false)
FROM timescaledb_information.jobs
WHERE proc_name IN ('policy_compression', 'policy_retention');

-- Resume after sync
SELECT alter_job(job_id, scheduled => true)
FROM timescaledb_information.jobs;
```

---

## 10. Production Deployment

### 10.1 Docker Compose Setup

```yaml
# docker-compose.yml
version: '3.8'

services:
  timescaledb:
    image: timescale/timescaledb:latest-pg16
    environment:
      POSTGRES_USER: ghostnet
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ghostnet_indexer
    volumes:
      - timescale_data:/var/lib/postgresql/data
      - ./postgresql.conf:/etc/postgresql/postgresql.conf:ro
    ports:
      - "5432:5432"
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ghostnet -d ghostnet_indexer"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes

  indexer:
    build: .
    environment:
      DATABASE_URL: postgres://ghostnet:${DB_PASSWORD}@timescaledb:5432/ghostnet_indexer
      REDIS_URL: redis://redis:6379
      RPC_URL: ${RPC_URL}
    depends_on:
      timescaledb:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped

volumes:
  timescale_data:
  redis_data:
```

### 10.2 PostgreSQL Configuration

```ini
# postgresql.conf - Optimized for blockchain indexer workload

# Memory
shared_buffers = 2GB                    # 25% of RAM
effective_cache_size = 6GB              # 75% of RAM
work_mem = 256MB                        # For complex queries
maintenance_work_mem = 1GB              # For VACUUM, CREATE INDEX

# Write-Ahead Log
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB
checkpoint_completion_target = 0.9

# Query Planner
random_page_cost = 1.1                  # SSD optimization
effective_io_concurrency = 200          # SSD optimization
default_statistics_target = 200

# Parallelism
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
parallel_tuple_cost = 0.01
parallel_setup_cost = 100

# TimescaleDB Specific
timescaledb.max_background_workers = 8
timescaledb.telemetry_level = off

# Connection Handling
max_connections = 100
superuser_reserved_connections = 3

# Logging
log_min_duration_statement = 1000       # Log queries > 1s
log_checkpoints = on
log_lock_waits = on
```

### 10.3 Monitoring Queries

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- HEALTH CHECK QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Overall hypertable sizes
SELECT 
    hypertable_name,
    pg_size_pretty(total_bytes) as total,
    pg_size_pretty(table_bytes) as table,
    pg_size_pretty(index_bytes) as index,
    pg_size_pretty(toast_bytes) as toast,
    num_chunks
FROM (
    SELECT 
        hypertable_name,
        SUM(total_bytes) as total_bytes,
        SUM(table_bytes) as table_bytes,
        SUM(index_bytes) as index_bytes,
        SUM(toast_bytes) as toast_bytes,
        COUNT(*) as num_chunks
    FROM timescaledb_information.hypertable_details()
    GROUP BY hypertable_name
) sub
ORDER BY total_bytes DESC;

-- Compression efficiency
SELECT 
    hypertable_name,
    COUNT(*) FILTER (WHERE compression_status = 'Compressed') as compressed_chunks,
    COUNT(*) FILTER (WHERE compression_status = 'Uncompressed') as uncompressed_chunks,
    pg_size_pretty(SUM(before_compression_total_bytes)) as before_compression,
    pg_size_pretty(SUM(after_compression_total_bytes)) as after_compression,
    ROUND(AVG(compression_ratio)::numeric, 2) as avg_compression_ratio
FROM timescaledb_information.compressed_chunk_stats
GROUP BY hypertable_name;

-- Job health
SELECT 
    j.job_id,
    j.application_name,
    j.schedule_interval,
    js.last_run_status,
    js.last_run_started_at,
    js.last_run_duration,
    js.total_failures,
    j.next_start
FROM timescaledb_information.jobs j
LEFT JOIN timescaledb_information.job_stats js USING (job_id)
ORDER BY j.next_start;

-- Continuous aggregate freshness
SELECT 
    view_name,
    completed_threshold as watermark,
    NOW() - completed_threshold as lag
FROM timescaledb_information.continuous_aggregate_stats;

-- Indexer lag (custom)
SELECT 
    chain_id,
    last_block,
    last_block_timestamp,
    NOW() - last_block_timestamp as lag
FROM indexer_state;
```

### 10.4 Alerting Rules (Prometheus)

```yaml
# prometheus/rules/timescaledb.yml
groups:
  - name: timescaledb
    rules:
      - alert: CompressionBacklog
        expr: timescaledb_uncompressed_chunks > 100
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Compression backlog building up"
          description: "{{ $value }} uncompressed chunks waiting"
      
      - alert: ContinuousAggregateLag
        expr: timescaledb_continuous_aggregate_lag_seconds > 3600
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Continuous aggregate refresh falling behind"
      
      - alert: JobFailures
        expr: increase(timescaledb_job_failures_total[1h]) > 3
        labels:
          severity: critical
        annotations:
          summary: "TimescaleDB background jobs failing"
```

---

## 11. Complete Schema Implementation

### 11.1 Full Migration Script

The complete migration incorporating all recommendations:

```sql
-- migrations/20260120000001_complete_timescaledb_schema.sql

-- ═══════════════════════════════════════════════════════════════════════════
-- ENABLE EXTENSIONS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXER STATE (Regular Table)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE indexer_state (
    id SERIAL PRIMARY KEY,
    chain_id BIGINT NOT NULL UNIQUE,
    last_block BIGINT NOT NULL DEFAULT 0,
    last_block_hash BYTEA,
    last_block_timestamp TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER indexer_state_updated_at
    BEFORE UPDATE ON indexer_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCK HISTORY (Hypertable - Short retention)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE block_history (
    block_number BIGINT NOT NULL,
    block_hash BYTEA NOT NULL,
    parent_hash BYTEA NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (timestamp, block_number)
);

SELECT create_hypertable('block_history', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour');

SELECT add_retention_policy('block_history', INTERVAL '30 minutes');

CREATE INDEX idx_block_history_number ON block_history(block_number DESC);

-- [Continue with all other tables from Section 3.2...]

-- ═══════════════════════════════════════════════════════════════════════════
-- REORG HANDLING FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_reorg(reorg_block BIGINT)
RETURNS void AS $$
DECLARE
    reorg_timestamp TIMESTAMPTZ;
BEGIN
    SELECT timestamp INTO reorg_timestamp
    FROM block_history
    WHERE block_number = reorg_block;
    
    IF reorg_timestamp IS NULL THEN
        reorg_timestamp := NOW() - INTERVAL '1 minute';
    END IF;
    
    -- Delete from all affected tables
    DELETE FROM token_transfers WHERE block_number >= reorg_block;
    DELETE FROM deaths WHERE block_number >= reorg_block;
    DELETE FROM position_history WHERE block_number >= reorg_block;
    DELETE FROM bets WHERE block_number >= reorg_block;
    DELETE FROM block_history WHERE block_number >= reorg_block;
    
    -- Update indexer state
    UPDATE indexer_state 
    SET last_block = reorg_block - 1,
        last_block_hash = (
            SELECT block_hash FROM block_history 
            WHERE block_number = reorg_block - 1
        ),
        updated_at = NOW()
    WHERE chain_id = 6342;
    
    -- Refresh continuous aggregates
    CALL refresh_continuous_aggregate('tvl_hourly', reorg_timestamp, NOW());
    CALL refresh_continuous_aggregate('death_stats_hourly', reorg_timestamp, NOW());
    CALL refresh_continuous_aggregate('transfer_volume_hourly', reorg_timestamp, NOW());
    
    RAISE NOTICE 'Reorg handled: rolled back to block %', reorg_block - 1;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- GRANT PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Create application role
CREATE ROLE ghostnet_app WITH LOGIN PASSWORD 'changeme';

-- Grant necessary permissions
GRANT CONNECT ON DATABASE ghostnet_indexer TO ghostnet_app;
GRANT USAGE ON SCHEMA public TO ghostnet_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ghostnet_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ghostnet_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ghostnet_app;

-- Grant TimescaleDB-specific permissions
GRANT USAGE ON SCHEMA _timescaledb_internal TO ghostnet_app;
GRANT SELECT ON ALL TABLES IN SCHEMA _timescaledb_internal TO ghostnet_app;
GRANT SELECT ON ALL TABLES IN SCHEMA timescaledb_information TO ghostnet_app;
```

---

## Summary

### Key Recommendations for GHOSTNET Indexer

1. **Adopt Hybrid Architecture**: Use hypertables for time-series event data, regular tables for entities
2. **Configure Compression Wisely**: Choose `segmentby` based on your most common WHERE clauses
3. **Leverage Continuous Aggregates**: Pre-compute analytics to eliminate expensive full-table scans
4. **Plan for Reorgs**: Keep recent data in a queryable state, use block_number tracking
5. **Monitor Background Jobs**: Ensure compression and retention policies keep pace with ingestion
6. **Start Simple**: Begin with basic hypertables, add complexity as needed

### Expected Benefits

| Metric | Without TimescaleDB | With TimescaleDB |
|--------|--------------------|--------------------|
| Storage (90 days) | ~500GB | ~50GB (90% compression) |
| TVL query (1 year) | 30-60s | <100ms (continuous aggregate) |
| Address lookup | 1-5s | <50ms (segmentby optimization) |
| Reorg handling | Complex custom | Native chunk operations |

### Next Steps

1. Set up a test environment with TimescaleDB 2.24+
2. Migrate the schema using the provided migrations
3. Benchmark with realistic data volumes
4. Tune chunk intervals and compression settings based on actual patterns
5. Monitor and adjust background job schedules

---

## References

- [TimescaleDB Documentation](https://docs.timescale.com)
- [TimescaleDB 2.22-2.24 Release Notes](https://github.com/timescale/timescaledb/releases)
- [Cloudflare's TimescaleDB Case Study](https://blog.cloudflare.com/timescaledb-art/)
- [SQLx Rust Documentation](https://docs.rs/sqlx)
- [Blockchain Indexer Patterns](https://www.alchemy.com/overviews/blockchain-indexer)
