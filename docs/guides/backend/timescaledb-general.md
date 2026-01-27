# TimescaleDB Master Guide 2026
## Complete Best Practices, Tips, and Hard-Won Wisdom

*Last Updated: January 2026 | TimescaleDB 2.24.x / PostgreSQL 15-18*

---

## Table of Contents

1. [Understanding TimescaleDB's Architecture](#1-understanding-timescaledbs-architecture)
2. [Installation and Initial Setup](#2-installation-and-initial-setup)
3. [The Chunk Sizing Masterclass](#3-the-chunk-sizing-masterclass)
4. [Hypertable Design Patterns](#4-hypertable-design-patterns)
5. [Hypercore: The Hybrid Row-Columnar Engine](#5-hypercore-the-hybrid-row-columnar-engine)
6. [Compression Deep Dive](#6-compression-deep-dive)
7. [Indexing Strategies That Actually Work](#7-indexing-strategies-that-actually-work)
8. [Continuous Aggregates Mastery](#8-continuous-aggregates-mastery)
9. [Data Retention and Tiered Storage](#9-data-retention-and-tiered-storage)
10. [Hyperfunctions and Analytics](#10-hyperfunctions-and-analytics)
11. [PostgreSQL Configuration Tuning](#11-postgresql-configuration-tuning)
12. [UUIDv7 as a Partitioning Key](#12-uuidv7-as-a-partitioning-key)
13. [Common Pitfalls and How to Avoid Them](#13-common-pitfalls-and-how-to-avoid-them)
14. [Monitoring and Maintenance](#14-monitoring-and-maintenance)
15. [Migration and Upgrade Strategies](#15-migration-and-upgrade-strategies)

---

## 1. Understanding TimescaleDB's Architecture

### What Makes TimescaleDB Different

TimescaleDB is a PostgreSQL extension that transforms standard PostgreSQL tables into **hypertables**—automatically partitioned tables optimized for time-series workloads. The key insight is that it provides:

- **Full SQL compatibility**: Every PostgreSQL feature, tool, and driver works
- **Automatic partitioning**: Data is split into "chunks" by time (and optionally space)
- **Hypercore storage engine**: Hybrid row-columnar storage for optimal read/write performance
- **Compression**: Up to 90%+ storage reduction with columnar compression
- **Native analytics**: Hyperfunctions, continuous aggregates, and time-based operations

### The Chunk Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        HYPERTABLE                               │
│                    (Virtual unified view)                       │
├─────────────┬─────────────┬─────────────┬─────────────┬────────┤
│   Chunk 1   │   Chunk 2   │   Chunk 3   │   Chunk 4   │  ...   │
│  (Week 1)   │  (Week 2)   │  (Week 3)   │  (Week 4)   │        │
│  Rowstore   │ Columnstore │ Columnstore │ Columnstore │        │
│ (Hot data)  │(Compressed) │(Compressed) │(Compressed) │        │
└─────────────┴─────────────┴─────────────┴─────────────┴────────┘
```

Each chunk is a standard PostgreSQL table with its own indexes, constraints, and storage settings.

### Key Terminology Changes (2024-2026)

| Old Term | New Term (2025+) | Notes |
|----------|------------------|-------|
| Compression | Columnstore | Data converted to columnar format |
| Compressed chunk | Chunk in columnstore | |
| Timescale Cloud | Tiger Cloud | Rebranding in 2025 |
| compress_chunk() | convert_to_columnstore() | New API available |

---

## 2. Installation and Initial Setup

### Quick Start with Docker (PostgreSQL 17/18)

```bash
# Latest stable with PostgreSQL 17
docker run -d --name timescaledb \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=tsdb \
  timescale/timescaledb-ha:pg17

# Connect
psql -h localhost -U postgres -d tsdb
```

### Enable the Extension

```sql
-- Create the extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Verify installation
SELECT default_version, installed_version 
FROM pg_available_extensions 
WHERE name = 'timescaledb';

-- Check version details
SELECT * FROM timescaledb_information.version;
```

### First-Time Configuration

Run `timescaledb-tune` immediately after installation:

```bash
# Automatic tuning based on system resources
timescaledb-tune --quiet --yes

# Or with specific parameters
timescaledb-tune --memory=64GB --cpus=16

# Preview changes without applying
timescaledb-tune --dry-run
```

---

## 3. The Chunk Sizing Masterclass

### The Updated 25% Rule (2025)

> **CRITICAL UPDATE**: The old "25% rule" based on total chunk size is outdated. The new guidance is to size chunks so that **chunk indexes fit within 25% of main memory**, not the total chunk size.

#### Why This Matters

PostgreSQL builds indexes on-the-fly during ingestion. When an index doesn't fit in memory:
1. It gets constantly flushed to disk
2. Read back for each row insertion
3. Causes massive I/O overhead
4. Destroys write performance

#### Calculating Optimal Chunk Interval

```sql
-- Step 1: Check current chunk sizes and index sizes
SELECT 
    h.table_name,
    c.chunk_name,
    pg_size_pretty(c.total_bytes) as total_size,
    pg_size_pretty(c.index_bytes) as index_size,
    c.range_start,
    c.range_end
FROM timescaledb_information.chunks c
JOIN timescaledb_information.hypertables h 
    ON c.hypertable_name = h.table_name
WHERE h.table_name = 'your_table'
ORDER BY c.range_start DESC
LIMIT 10;

-- Step 2: Calculate index growth rate
SELECT 
    time_bucket('1 day', range_start) as day,
    SUM(index_bytes) / (1024*1024*1024.0) as index_gb_per_day
FROM timescaledb_information.chunks
WHERE hypertable_name = 'your_table'
GROUP BY 1
ORDER BY 1 DESC
LIMIT 7;
```

#### Chunk Interval Guidelines

| System Memory | Index Growth/Day | Recommended Interval |
|---------------|------------------|---------------------|
| 8 GB (2GB for indexes) | ~200 MB | 7-10 days |
| 16 GB (4GB for indexes) | ~500 MB | 7-8 days |
| 32 GB (8GB for indexes) | ~1 GB | 7 days |
| 64 GB (16GB for indexes) | ~2 GB | 7 days |
| 64 GB (16GB for indexes) | ~10 GB | 1-2 days |

#### Setting Chunk Interval

```sql
-- When creating a hypertable
SELECT create_hypertable(
    'sensor_data',
    'time',
    chunk_time_interval => INTERVAL '1 day'
);

-- Modern CREATE TABLE syntax (2025+)
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '1 day'
);

-- Modify existing hypertable (affects future chunks only)
SELECT set_chunk_time_interval('sensor_data', INTERVAL '1 day');
```

### When to Use Space Partitioning

Space partitioning (`add_dimension()`) was designed primarily for **distributed hypertables**, which were sunsetted in v2.14. For single-node deployments:

**Avoid space partitioning in most cases.** Instead, use `segmentby` in compression settings to achieve similar query optimization.

```sql
-- DON'T do this for single-node (usually)
SELECT add_dimension('sensor_data', 'device_id', number_partitions => 8);

-- DO this instead - use segmentby in columnstore settings
ALTER TABLE sensor_data SET (
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);
```

---

## 4. Hypertable Design Patterns

### The Ideal Time-Series Schema

```sql
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,           -- ALWAYS use TIMESTAMPTZ, not TIMESTAMP
    device_id TEXT NOT NULL,             -- Your primary filter dimension
    metric_name TEXT NOT NULL,           -- For multi-metric tables
    value DOUBLE PRECISION NOT NULL,
    tags JSONB,                          -- Flexible metadata
    quality_score SMALLINT DEFAULT 100
);

-- Convert to hypertable with optimal settings
SELECT create_hypertable(
    'metrics',
    'time',
    chunk_time_interval => INTERVAL '1 day',
    create_default_indexes => TRUE       -- Creates index on (time DESC)
);

-- Add your primary access pattern index
CREATE INDEX idx_metrics_device_time 
ON metrics (device_id, time DESC);
```

### Modern CREATE TABLE Syntax (TimescaleDB 2.20+)

```sql
CREATE TABLE conditions (
    time TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '7 days',
    timescaledb.segmentby = 'location'   -- For columnstore optimization
);
```

This syntax automatically:
- Creates the hypertable
- Enables columnstore (compression)
- Creates a columnstore policy after one chunk interval

### Wide Tables vs. Narrow Tables

**Narrow Table Pattern** (Recommended for flexibility):
```sql
CREATE TABLE metrics_narrow (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL
);
```

**Wide Table Pattern** (Better for analytics):
```sql
CREATE TABLE metrics_wide (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    disk_io DOUBLE PRECISION,
    network_in BIGINT,
    network_out BIGINT
);
```

**When to use which:**
- **Narrow**: Unknown metrics at design time, flexible schema, sparse data
- **Wide**: Known metrics, dense data, better compression, faster aggregations

---

## 5. Hypercore: The Hybrid Row-Columnar Engine

### Understanding Hypercore (2024+)

Hypercore is TimescaleDB's storage engine that provides:

1. **Rowstore**: For recent/hot data - optimized for fast inserts and updates
2. **Columnstore**: For historical/cold data - optimized for analytics and storage

```
┌────────────────────────────────────────────────────────────────┐
│                        DATA LIFECYCLE                          │
│                                                                │
│   INSERT → ROWSTORE → [Policy runs] → COLUMNSTORE             │
│              │                            │                    │
│         Fast writes                  Fast analytics           │
│         Full mutability              90%+ compression         │
│         Point lookups                Vectorized queries       │
└────────────────────────────────────────────────────────────────┘
```

### Important: Hypercore TAM is Sunset

> ⚠️ **Warning**: The Hypercore Table Access Method (TAM) was deprecated in 2.21 and removed in 2.22. If you used `SET ACCESS METHOD hypercore`, migrate away immediately.

```sql
-- Migration from TAM to standard heap + columnstore
DO $$
DECLARE
    relid regclass;
BEGIN
    FOR relid IN 
        SELECT cl.oid 
        FROM pg_class cl 
        JOIN pg_am am ON (am.oid = cl.relam) 
        WHERE am.amname = 'hypercore'
    LOOP
        RAISE NOTICE 'converting % to heap', relid::regclass;
        EXECUTE format('ALTER TABLE %s SET ACCESS METHOD heap', relid);
    END LOOP;
END $$;
```

### Enabling Columnstore

```sql
-- Method 1: Modern CREATE TABLE (automatic)
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.segmentby = 'device_id'
);

-- Method 2: ALTER TABLE for existing hypertables
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Add automatic columnstore policy
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');
-- Or the new API:
SELECT add_columnstore_policy('sensor_data', compress_after => INTERVAL '7 days');
```

---

## 6. Compression Deep Dive

### Segmentby vs Orderby: The Critical Decision

#### Segmentby
- Creates separate compressed segments for each unique value combination
- Enables fast filtering on segmentby columns
- Too many segments = poor compression
- **Rule: Each segment should have at least 100 rows per chunk**

#### Orderby
- Determines sort order within each segment
- Enables range queries and min/max sparse indexes
- First orderby column gets automatic min/max metadata
- Affects compression ratio (similar values together = better compression)

### Compression Configuration Patterns

**Pattern 1: Device-centric queries**
```sql
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);
```

**Pattern 2: Multi-tenant with device**
```sql
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, device_id',
    timescaledb.compress_orderby = 'time DESC'
);
```

**Pattern 3: No segmentby (high cardinality dimensions)**
```sql
-- When segmentby would create too-small segments
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'device_id, time DESC'
);
-- This still enables efficient device queries via orderby!
```

**Pattern 4: With Bloom Filters (2.20+)**
```sql
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id',
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_index = 'bloom("device_id"), minmax("value")'
);
```

### Configurable Sparse Indexes (2.22+)

```sql
-- Configure which columns get sparse indexes
ALTER TABLE metrics SET (
    timescaledb.compress_index = 'bloom("uuid_column"), minmax("timestamp_col", "numeric_col")'
);
```

Index types:
- **minmax**: Best for range queries on numeric/timestamp columns
- **bloom**: Best for equality queries on high-cardinality columns (UUIDs, etc.)

### Checking Compression Effectiveness

```sql
-- Compression statistics per chunk
SELECT 
    chunk_name,
    pg_size_pretty(before_compression_total_bytes) AS before,
    pg_size_pretty(after_compression_total_bytes) AS after,
    ROUND(100.0 * (1 - after_compression_total_bytes::numeric / 
        NULLIF(before_compression_total_bytes, 0)), 2) AS compression_ratio_pct
FROM chunk_compression_stats('metrics')
ORDER BY chunk_name DESC
LIMIT 10;

-- Warning: If compression ratio is poor (< 50%), you'll see warnings
-- Check for issues with:
SELECT * FROM timescaledb_information.hypertable_columnstore_settings 
WHERE hypertable = 'metrics';
```

### Manual Compression Operations

```sql
-- Compress a specific chunk
SELECT compress_chunk('_timescaledb_internal._hyper_1_1_chunk');

-- Decompress (needed before certain modifications)
SELECT decompress_chunk('_timescaledb_internal._hyper_1_1_chunk');

-- Recompress with in-memory optimization (2.24+)
SELECT convert_to_columnstore(
    '_timescaledb_internal._hyper_1_1_chunk',
    recompress => true  -- 4-5x faster than decompress/compress
);
```

---

## 7. Indexing Strategies That Actually Work

### Default Indexes

When you create a hypertable, TimescaleDB automatically creates:
- Index on `(time DESC)` for time-based queries

### Essential Index Patterns

**Pattern 1: Time + Identifier (Most Common)**
```sql
-- For queries: WHERE device_id = 'x' AND time > now() - interval '1 day'
CREATE INDEX idx_device_time ON metrics (device_id, time DESC);
```

**Pattern 2: Composite for Multi-Dimensional Filters**
```sql
-- For queries with equality on multiple columns + time range
CREATE INDEX idx_tenant_device_time 
ON metrics (tenant_id, device_id, time DESC);
```

**Pattern 3: JSONB Index**
```sql
-- For JSONB metadata queries
CREATE INDEX idx_tags ON metrics USING GIN (tags);

-- For specific JSONB paths
CREATE INDEX idx_tags_region ON metrics ((tags->>'region'));
```

### Index Column Order Rule

> **Critical**: Put **equality** columns BEFORE **inequality** columns in composite indexes.

```sql
-- GOOD: Equality columns first
CREATE INDEX idx_good ON metrics (device_id, metric_type, time DESC);
-- For: WHERE device_id = 'x' AND metric_type = 'cpu' AND time > '2025-01-01'

-- BAD: Time (inequality) first
CREATE INDEX idx_bad ON metrics (time DESC, device_id);
-- This can only use time for narrowing, then scans all devices
```

### Unique Constraints

Unique constraints MUST include the partition column:

```sql
-- This works
CREATE UNIQUE INDEX ON metrics (device_id, time);

-- This FAILS
CREATE UNIQUE INDEX ON metrics (device_id);  -- Error: must include time
```

### Chunk Skipping for Non-Partition Columns

```sql
-- Enable chunk skipping on a column
SELECT enable_chunk_skipping('metrics', 'device_id');

-- TimescaleDB will now track min/max values per chunk for device_id
-- Queries filtering on device_id can skip irrelevant chunks
```

### Indexes in Columnstore (2.20+)

The columnstore uses specialized sparse indexes, not standard B-tree indexes:

- **MinMax indexes**: Created automatically on orderby columns
- **Bloom filter indexes**: For high-cardinality equality queries (2.20+)

```sql
-- Bloom filters are enabled by default in 2.20+
-- To disable if needed:
SET timescaledb.enable_sparse_index_bloom = off;
```

---

## 8. Continuous Aggregates Mastery

### What Are Continuous Aggregates?

Continuous aggregates are automatically refreshed materialized views optimized for time-series data. They:
- Pre-compute aggregations
- Refresh incrementally (only changed data)
- Support real-time queries (combine materialized + live data)

### Creating a Continuous Aggregate

```sql
-- Basic continuous aggregate
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS sample_count
FROM metrics
GROUP BY bucket, device_id
WITH NO DATA;  -- Don't populate immediately

-- Add refresh policy
SELECT add_continuous_aggregate_policy(
    'metrics_hourly',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
```

### Real-Time vs Materialized-Only

```sql
-- Real-time (default): Combines materialized data with live data
ALTER MATERIALIZED VIEW metrics_hourly SET (
    timescaledb.materialized_only = false
);

-- Materialized-only: Only shows pre-computed data
ALTER MATERIALIZED VIEW metrics_hourly SET (
    timescaledb.materialized_only = true
);
```

### Hierarchical Continuous Aggregates

```sql
-- Level 1: Minute aggregates
CREATE MATERIALIZED VIEW metrics_minute
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', time) AS bucket,
    device_id,
    AVG(value) AS avg_value,
    COUNT(*) AS samples
FROM metrics
GROUP BY bucket, device_id;

-- Level 2: Hourly from minute (more efficient!)
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', bucket) AS bucket,
    device_id,
    AVG(avg_value) AS avg_value,  -- Note: This is avg of avgs
    SUM(samples) AS total_samples
FROM metrics_minute
GROUP BY 1, device_id;
```

### Continuous Aggregate Best Practices

1. **Use `WITH NO DATA` for large tables** - Populate incrementally via refresh policy

2. **Set appropriate refresh windows**:
```sql
SELECT add_continuous_aggregate_policy(
    'metrics_hourly',
    start_offset => INTERVAL '3 days',   -- How far back to look
    end_offset => INTERVAL '1 hour',     -- Leave recent data for real-time
    schedule_interval => INTERVAL '1 hour'
);
```

3. **Manual refresh for backfill**:
```sql
CALL refresh_continuous_aggregate(
    'metrics_hourly', 
    '2024-01-01'::timestamptz, 
    '2025-01-01'::timestamptz
);
```

4. **Compress continuous aggregates** (2.6+):
```sql
ALTER MATERIALIZED VIEW metrics_hourly SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('metrics_hourly', INTERVAL '30 days');
```

5. **WAL-based invalidation for performance** (2.22+):
```sql
-- Enable faster invalidation tracking
ALTER MATERIALIZED VIEW metrics_hourly SET (
    timescaledb.invalidate_using = 'wal'
);
```

### Supported Aggregates

Most PostgreSQL aggregate functions work, including:
- `AVG`, `SUM`, `COUNT`, `MIN`, `MAX`
- `STDDEV`, `VARIANCE`
- `FIRST`, `LAST` (TimescaleDB hyperfunctions)
- `percentile_agg` (from toolkit)

**Not supported**:
- `DISTINCT` inside aggregates
- `ORDER BY` inside aggregates
- `FILTER` clause (may be added in future)

### JOINs in Continuous Aggregates (2.10+)

```sql
CREATE MATERIALIZED VIEW device_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', m.time) AS bucket,
    m.device_id,
    d.device_name,
    d.location,
    AVG(m.value) AS avg_value
FROM metrics m
JOIN devices d ON m.device_id = d.id
GROUP BY bucket, m.device_id, d.device_name, d.location;
```

---

## 9. Data Retention and Tiered Storage

### Retention Policies

```sql
-- Add retention policy - drops chunks older than 90 days
SELECT add_retention_policy('metrics', INTERVAL '90 days');

-- Remove retention policy
SELECT remove_retention_policy('metrics');

-- View scheduled jobs
SELECT * FROM timescaledb_information.jobs 
WHERE proc_name = 'policy_retention';
```

### Manual Chunk Management

```sql
-- View chunks
SELECT * FROM timescaledb_information.chunks 
WHERE hypertable_name = 'metrics'
ORDER BY range_start DESC;

-- Drop specific chunks
SELECT drop_chunks('metrics', older_than => INTERVAL '90 days');

-- Drop chunks before a specific date
SELECT drop_chunks('metrics', older_than => '2024-01-01'::timestamptz);
```

### Tiered Storage (Tiger Cloud)

Tiger Cloud offers automatic data tiering to S3:

```sql
-- Enable tiering for a hypertable
SELECT enable_tiering('metrics');

-- Add tiering policy (moves to S3 after 30 days)
SELECT add_tiering_policy('metrics', INTERVAL '30 days');

-- Query tiered data (transparent to user)
SELECT * FROM metrics WHERE time > '2024-01-01';

-- Move a chunk back from S3
CALL untier_chunk('_timescaledb_internal._hyper_1_1_chunk');

-- View tiered chunks
SELECT * FROM timescaledb_osm.tiered_chunks;
```

### Self-Hosted Tiering Strategy

For self-hosted deployments, use tablespaces:

```sql
-- Create tablespace on cheaper storage
CREATE TABLESPACE archive_space LOCATION '/mnt/archive_ssd';

-- Move old chunks to archive tablespace
SELECT move_chunk(
    chunk => c.chunk_name,
    destination_tablespace => 'archive_space'
)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'metrics'
  AND c.range_end < now() - INTERVAL '90 days';
```

### Combining Retention with Continuous Aggregates

```sql
-- Keep raw data for 7 days
SELECT add_retention_policy('metrics', INTERVAL '7 days');

-- Keep hourly aggregates for 90 days
SELECT add_retention_policy('metrics_hourly', INTERVAL '90 days');

-- Keep daily aggregates forever (or much longer)
SELECT add_retention_policy('metrics_daily', INTERVAL '5 years');
```

---

## 10. Hyperfunctions and Analytics

### Time Bucketing

```sql
-- Basic time bucket
SELECT 
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(value) AS avg_value
FROM metrics
WHERE time > now() - INTERVAL '1 day'
GROUP BY hour, device_id
ORDER BY hour DESC;

-- Time bucket with origin alignment
SELECT 
    time_bucket('1 day', time, origin => '2024-01-01'::timestamptz) AS day,
    COUNT(*)
FROM metrics
GROUP BY day;

-- Time bucket with timezone
SELECT 
    time_bucket('1 day', time, 'America/New_York') AS day,
    COUNT(*)
FROM metrics
GROUP BY day;
```

### Gap Filling

```sql
-- Fill gaps with NULL
SELECT 
    time_bucket_gapfill('1 hour', time) AS hour,
    device_id,
    AVG(value) AS avg_value
FROM metrics
WHERE time BETWEEN '2025-01-01' AND '2025-01-02'
  AND device_id = 'sensor_1'
GROUP BY hour, device_id;

-- Fill gaps with LOCF (last observation carried forward)
SELECT 
    time_bucket_gapfill('1 hour', time) AS hour,
    device_id,
    locf(AVG(value)) AS avg_value
FROM metrics
WHERE time BETWEEN '2025-01-01' AND '2025-01-02'
  AND device_id = 'sensor_1'
GROUP BY hour, device_id;

-- Fill gaps with interpolation
SELECT 
    time_bucket_gapfill('1 hour', time) AS hour,
    device_id,
    interpolate(AVG(value)) AS avg_value
FROM metrics
WHERE time BETWEEN '2025-01-01' AND '2025-01-02'
  AND device_id = 'sensor_1'
GROUP BY hour, device_id;
```

### First/Last Aggregates

```sql
-- Get first and last values in time order
SELECT 
    device_id,
    first(value, time) AS first_value,
    last(value, time) AS last_value,
    last(time, time) AS last_timestamp
FROM metrics
WHERE time > now() - INTERVAL '1 hour'
GROUP BY device_id;
```

### TimescaleDB Toolkit (Advanced Analytics)

```sql
-- Install toolkit extension
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;

-- Approximate percentiles with uddsketch
SELECT 
    device_id,
    approx_percentile(0.50, percentile_agg(value)) AS median,
    approx_percentile(0.95, percentile_agg(value)) AS p95,
    approx_percentile(0.99, percentile_agg(value)) AS p99
FROM metrics
WHERE time > now() - INTERVAL '1 day'
GROUP BY device_id;

-- Candlestick aggregation for financial data
SELECT 
    time_bucket('1 hour', time) AS bucket,
    symbol,
    open(candlestick_agg(time, price, volume)),
    high(candlestick_agg(time, price, volume)),
    low(candlestick_agg(time, price, volume)),
    close(candlestick_agg(time, price, volume)),
    vwap(candlestick_agg(time, price, volume))
FROM trades
GROUP BY bucket, symbol;

-- State aggregates (uptime/downtime tracking)
SELECT 
    device_id,
    duration_in(state_agg(time, status), 'online') AS online_duration,
    duration_in(state_agg(time, status), 'offline') AS offline_duration
FROM device_status
GROUP BY device_id;
```

### SkipScan for DISTINCT (2.20+)

```sql
-- SkipScan dramatically accelerates DISTINCT queries
-- Up to 2000-2500x faster in columnstore

SELECT DISTINCT device_id 
FROM metrics
WHERE time > now() - INTERVAL '30 days';

-- Works with multiple columns (2.22+)
SELECT DISTINCT tenant_id, device_id
FROM metrics
WHERE time > now() - INTERVAL '30 days';
```

---

## 11. PostgreSQL Configuration Tuning

### Use timescaledb-tune First

```bash
# Run the tuning tool
timescaledb-tune

# For production with specific resources
timescaledb-tune --memory=64GB --cpus=32 --yes
```

### Essential Parameters

```ini
# postgresql.conf

# Memory Settings (adjust based on total RAM)
shared_buffers = 8GB              # 25% of RAM for dedicated server
effective_cache_size = 24GB        # 75% of RAM
maintenance_work_mem = 2GB         # For VACUUM, CREATE INDEX
work_mem = 64MB                    # Per-operation sort memory (be careful!)

# WAL Settings
wal_buffers = 64MB                 # Increase for write-heavy workloads
max_wal_size = 4GB                 # Increase for batch inserts
min_wal_size = 1GB
checkpoint_timeout = 15min         # Balance between recovery time and I/O

# Parallelism
max_parallel_workers = 8           # Match CPU cores
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4

# TimescaleDB Specific
shared_preload_libraries = 'timescaledb'
timescaledb.max_background_workers = 16  # 1 + num_dbs + concurrent_jobs

# Background Workers
max_worker_processes = 32          # >= 3 + max_bg_workers + parallel_workers
```

### Worker Configuration Deep Dive

```ini
# Formula for max_worker_processes:
# max_worker_processes = 3 + timescaledb.max_background_workers + max_parallel_workers

# Example for 8 databases with 2 concurrent compression jobs each:
timescaledb.max_background_workers = 24  # 8 dbs + 16 concurrent jobs
max_parallel_workers = 16
max_worker_processes = 43                 # 3 + 24 + 16
```

### Memory Tuning for Different Workloads

**Heavy Write Workload:**
```ini
shared_buffers = 4GB        # Lower - writes flush buffers
work_mem = 32MB             # Conservative
wal_buffers = 64MB          # Higher for write throughput
synchronous_commit = off    # Risky but faster (use with caution!)
```

**Heavy Read/Analytics Workload:**
```ini
shared_buffers = 12GB       # Higher - more caching
work_mem = 256MB            # Higher for sorts/joins
effective_cache_size = 48GB # Tell planner about OS cache
max_parallel_workers_per_gather = 8
```

### TimescaleDB-Specific GUCs

```sql
-- View all TimescaleDB settings
SHOW ALL;
-- Or filter:
SELECT name, setting, short_desc 
FROM pg_settings 
WHERE name LIKE 'timescaledb%';
```

Key settings:
```ini
# Enable/disable features
timescaledb.enable_columnstore = on
timescaledb.enable_sparse_index_bloom = on
timescaledb.enable_uuid_compression = on  # For UUIDv7

# Continuous aggregate tuning
timescaledb.cagg_processing_low_work_mem = 38.4MB
timescaledb.cagg_processing_high_work_mem = 51.2MB

# Direct compress (2.21+)
timescaledb.enable_direct_compress_copy = on
```

---

## 12. UUIDv7 as a Partitioning Key

### Why UUIDv7?

UUIDv7 embeds a timestamp in the high-order bits, providing:
- Global uniqueness across distributed systems
- Time-sortable (improves B-tree locality)
- No need for a separate timestamp column
- Works as a natural partition key

### UUIDv7 Support Timeline

| Version | Feature |
|---------|---------|
| 2.22 | UUIDv7 compression, partitioning |
| 2.23 | UUIDv7 enabled by default, PostgreSQL 18 support |
| 2.24 | `time_bucket()` for UUIDv7, continuous aggregates on UUIDv7 |

### Creating UUIDv7-Partitioned Hypertables

```sql
-- PostgreSQL 18 has native UUIDv7 support
-- For earlier versions, use pg_uuidv7 extension

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    event_type TEXT NOT NULL,
    payload JSONB
);

-- Create hypertable with UUIDv7 partitioning
SELECT create_hypertable(
    'events',
    by_range('id', INTERVAL '1 day'),  -- Uses UUIDv7 timestamp component
    create_default_indexes => FALSE
);

-- Or with the modern syntax (2.22+)
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    event_type TEXT NOT NULL,
    payload JSONB
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'id',
    timescaledb.chunk_time_interval = '1 day'
);
```

### Querying UUIDv7 Hypertables

```sql
-- Use boundary functions for efficient range queries
SELECT * FROM events
WHERE id >= to_uuidv7_boundary('2025-01-01'::timestamptz, true)
  AND id < to_uuidv7_boundary('2025-01-02'::timestamptz, true)
ORDER BY id;

-- Extract timestamp from UUIDv7
SELECT 
    id,
    uuid_timestamp(id) AS event_time,
    event_type
FROM events
LIMIT 10;

-- DON'T do this (slow - can't use chunk exclusion):
SELECT * FROM events
WHERE uuid_timestamp(id) >= '2025-01-01'
  AND uuid_timestamp(id) < '2025-01-02';
```

### Time Bucketing with UUIDv7 (2.24+)

```sql
-- Time bucket on UUIDv7 columns
SELECT 
    time_bucket('1 hour', id) AS bucket,  -- Returns timestamptz
    COUNT(*) AS event_count
FROM events
WHERE id >= to_uuidv7_boundary('2025-01-01'::timestamptz, true)
GROUP BY bucket
ORDER BY bucket;
```

### Continuous Aggregates on UUIDv7 (2.24+)

```sql
CREATE MATERIALIZED VIEW events_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', id) AS bucket,
    event_type,
    COUNT(*) AS event_count
FROM events
GROUP BY bucket, event_type;
```

---

## 13. Common Pitfalls and How to Avoid Them

### Pitfall 1: Using TIMESTAMP Instead of TIMESTAMPTZ

```sql
-- WRONG: Loses timezone information
CREATE TABLE bad_metrics (
    time TIMESTAMP NOT NULL,  -- Don't do this!
    value DOUBLE PRECISION
);

-- RIGHT: Always use TIMESTAMPTZ
CREATE TABLE good_metrics (
    time TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION
);
```

### Pitfall 2: Forgetting Time Constraints in Queries

```sql
-- SLOW: Scans all chunks
SELECT * FROM metrics WHERE device_id = 'sensor_1';

-- FAST: Only scans relevant chunks
SELECT * FROM metrics 
WHERE device_id = 'sensor_1' 
  AND time > now() - INTERVAL '1 day';
```

### Pitfall 3: Too Many Small Segments in Compression

```sql
-- Problem: High-cardinality segmentby creates tiny segments
ALTER TABLE metrics SET (
    timescaledb.compress_segmentby = 'user_id'  -- 1M users = 1M segments!
);

-- Solution: Move high-cardinality columns to orderby
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'user_id, time DESC'  -- Much better!
);
```

### Pitfall 4: Not Running ANALYZE After Bulk Inserts

```sql
-- After large data loads
ANALYZE metrics;

-- Check statistics
SELECT schemaname, tablename, last_analyze 
FROM pg_stat_user_tables 
WHERE tablename = 'metrics';
```

### Pitfall 5: Blocking Operations on Compressed Chunks

Some operations require decompression. Plan for this:

```sql
-- Check if a chunk is compressed before modifying
SELECT chunk_name, is_compressed 
FROM timescaledb_information.chunks 
WHERE hypertable_name = 'metrics';

-- Decompress if needed (this takes time and space!)
SELECT decompress_chunk('_timescaledb_internal._hyper_1_1_chunk');
```

### Pitfall 6: Ignoring Background Worker Limits

```sql
-- Check if jobs are stuck
SELECT * FROM timescaledb_information.job_stats
WHERE job_status = 'Scheduled' 
  AND next_start < now() - INTERVAL '1 hour';

-- Check background worker count
SHOW timescaledb.max_background_workers;
SHOW max_worker_processes;
```

### Pitfall 7: Using add_dimension for Single-Node Deployments

```sql
-- Usually unnecessary and adds complexity
SELECT add_dimension('metrics', 'device_id', number_partitions => 8);

-- Instead, use segmentby in compression
ALTER TABLE metrics SET (
    timescaledb.compress_segmentby = 'device_id'
);
```

### Pitfall 8: Not Setting Chunk Interval Based on Index Size

Remember: Target **index size** fitting in 25% of memory, not total chunk size.

```sql
-- Monitor index sizes
SELECT 
    chunk_name,
    pg_size_pretty(index_bytes) as index_size,
    pg_size_pretty(total_bytes) as total_size
FROM chunks_detailed_size('metrics')
ORDER BY range_start DESC;
```

---

## 14. Monitoring and Maintenance

### Essential Monitoring Queries

```sql
-- Hypertable sizes
SELECT 
    hypertable_name,
    pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name))) as total_size,
    num_chunks
FROM timescaledb_information.hypertables;

-- Chunk details
SELECT 
    hypertable_name,
    chunk_name,
    range_start,
    range_end,
    is_compressed,
    pg_size_pretty(total_bytes) as size
FROM timescaledb_information.chunks c
JOIN chunks_detailed_size(c.hypertable_name) s 
    ON c.chunk_name = s.chunk_name
ORDER BY range_start DESC
LIMIT 20;

-- Compression statistics
SELECT 
    hypertable_name,
    SUM(before_compression_total_bytes) as uncompressed,
    SUM(after_compression_total_bytes) as compressed,
    ROUND(100.0 * (1 - SUM(after_compression_total_bytes)::numeric / 
        NULLIF(SUM(before_compression_total_bytes), 0)), 2) as ratio_pct
FROM hypertable_compression_stats(NULL)
GROUP BY hypertable_name;

-- Job status
SELECT 
    job_id,
    application_name,
    schedule_interval,
    last_run_status,
    last_successful_finish,
    next_start,
    total_runs,
    total_failures
FROM timescaledb_information.job_stats
ORDER BY next_start;

-- Continuous aggregate status
SELECT 
    view_name,
    materialization_hypertable_name,
    view_definition
FROM timescaledb_information.continuous_aggregates;
```

### Maintenance Tasks

```sql
-- Manual compression of old chunks
SELECT compress_chunk(c.chunk_name)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'metrics'
  AND NOT c.is_compressed
  AND c.range_end < now() - INTERVAL '7 days';

-- Reindex after heavy deletes
REINDEX TABLE metrics;

-- Update statistics
ANALYZE metrics;

-- Check for bloat in compressed chunks
SELECT 
    chunk_name,
    pg_size_pretty(pg_total_relation_size(chunk_name::regclass)) as size
FROM timescaledb_information.chunks
WHERE is_compressed
ORDER BY pg_total_relation_size(chunk_name::regclass) DESC
LIMIT 10;
```

### Health Checks Script

```sql
-- Comprehensive health check
WITH job_health AS (
    SELECT 
        COUNT(*) FILTER (WHERE last_run_status = 'Success') as successful_jobs,
        COUNT(*) FILTER (WHERE last_run_status != 'Success') as failed_jobs,
        COUNT(*) FILTER (WHERE next_start < now()) as overdue_jobs
    FROM timescaledb_information.job_stats
),
compression_health AS (
    SELECT 
        COUNT(*) FILTER (WHERE is_compressed) as compressed_chunks,
        COUNT(*) FILTER (WHERE NOT is_compressed AND range_end < now() - INTERVAL '7 days') as uncompressed_old_chunks
    FROM timescaledb_information.chunks
)
SELECT 
    jh.successful_jobs,
    jh.failed_jobs,
    jh.overdue_jobs,
    ch.compressed_chunks,
    ch.uncompressed_old_chunks,
    CASE 
        WHEN jh.failed_jobs > 0 OR jh.overdue_jobs > 0 OR ch.uncompressed_old_chunks > 10 
        THEN 'ATTENTION NEEDED'
        ELSE 'HEALTHY'
    END as status
FROM job_health jh, compression_health ch;
```

---

## 15. Migration and Upgrade Strategies

### Upgrading TimescaleDB

```sql
-- Check current version
SELECT * FROM timescaledb_information.version;

-- Basic upgrade (after installing new package)
ALTER EXTENSION timescaledb UPDATE;

-- Check for migration issues
SELECT * FROM _timescaledb_functions.migration_status();
```

### Version-Specific Migration Notes

**2.22+ (Hypercore TAM Removal):**
```sql
-- Check for TAM usage
SELECT cl.oid::regclass 
FROM pg_class cl 
JOIN pg_am am ON am.oid = cl.relam 
WHERE am.amname = 'hypercore';

-- Migrate to heap before upgrading
ALTER TABLE affected_table SET ACCESS METHOD heap;
```

**2.24 (Bloom Filter Changes):**
```sql
-- After upgrade, bloom filters on old chunks are disabled
-- Recompress to re-enable:
SELECT decompress_chunk(chunk_name), compress_chunk(chunk_name)
FROM timescaledb_information.chunks
WHERE is_compressed AND range_end < now() - INTERVAL '30 days';

-- Or use in-memory recompression:
SELECT convert_to_columnstore(chunk_name, recompress => true)
FROM timescaledb_information.chunks
WHERE is_compressed;
```

### Migrating from Regular PostgreSQL Table

```sql
-- Step 1: Create new hypertable with identical schema
CREATE TABLE metrics_new (LIKE metrics INCLUDING ALL);

-- Step 2: Convert to hypertable
SELECT create_hypertable(
    'metrics_new',
    'time',
    chunk_time_interval => INTERVAL '1 day',
    migrate_data => FALSE
);

-- Step 3: Copy data in batches
INSERT INTO metrics_new
SELECT * FROM metrics
WHERE time >= '2024-01-01' AND time < '2024-02-01';

-- Repeat for other time ranges...

-- Step 4: Rename tables
BEGIN;
ALTER TABLE metrics RENAME TO metrics_old;
ALTER TABLE metrics_new RENAME TO metrics;
COMMIT;

-- Step 5: Drop old table after verification
DROP TABLE metrics_old;
```

### Parallel Copy for Large Migrations

```bash
# Use timescaledb-parallel-copy for fast data loading
timescaledb-parallel-copy \
    --connection "host=localhost dbname=mydb" \
    --table metrics \
    --file metrics_export.csv \
    --workers 8 \
    --batch-size 10000
```

---

## Quick Reference Card

### Most Important Settings

```sql
-- Chunk sizing: Target index size < 25% of memory
SELECT set_chunk_time_interval('table', INTERVAL '1 day');

-- Compression with optimal settings
ALTER TABLE t SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'low_cardinality_col',
    timescaledb.compress_orderby = 'time DESC'
);

-- Automatic compression after 7 days
SELECT add_compression_policy('table', INTERVAL '7 days');

-- Data retention
SELECT add_retention_policy('table', INTERVAL '90 days');
```

### Essential Indexes

```sql
-- Primary access pattern: device + time
CREATE INDEX ON metrics (device_id, time DESC);

-- Multi-tenant
CREATE INDEX ON metrics (tenant_id, device_id, time DESC);
```

### Must-Have Continuous Aggregate Pattern

```sql
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(value) AS avg_value,
    COUNT(*) AS samples
FROM metrics
GROUP BY bucket, device_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('metrics_hourly',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
```

### Health Check Query

```sql
SELECT 
    (SELECT COUNT(*) FROM timescaledb_information.chunks) as total_chunks,
    (SELECT COUNT(*) FROM timescaledb_information.chunks WHERE is_compressed) as compressed_chunks,
    (SELECT COUNT(*) FROM timescaledb_information.job_stats WHERE last_run_status = 'Failed') as failed_jobs,
    (SELECT installed_version FROM pg_available_extensions WHERE name = 'timescaledb') as version;
```

---

## Resources

- **Official Docs**: https://docs.tigerdata.com
- **GitHub**: https://github.com/timescale/timescaledb
- **Community Forum**: https://forum.tigerdata.com
- **timescaledb-tune**: https://github.com/timescale/timescaledb-tune
- **Toolkit Extension**: https://github.com/timescale/timescaledb-toolkit

---

*This guide reflects best practices as of January 2026 with TimescaleDB 2.24.x. Always check the official documentation for the most current information.*
