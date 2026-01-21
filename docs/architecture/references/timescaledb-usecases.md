# TimescaleDB Real-World Guide 2026
## Decision Frameworks, Use Cases, and Edge Cases

*Companion to the TimescaleDB Master Guide | January 2026*

---

## Table of Contents

1. [The Hypertable Decision Framework](#1-the-hypertable-decision-framework)
2. [When NOT to Use Hypertables](#2-when-not-to-use-hypertables)
3. [Real-World Use Cases](#3-real-world-use-cases)
4. [Tricky Hybrid Scenarios](#4-tricky-hybrid-scenarios)
5. [Multi-Tenant Architecture Patterns](#5-multi-tenant-architecture-patterns)
6. [TimescaleDB vs Alternatives Decision Guide](#6-timescaledb-vs-alternatives-decision-guide)
7. [Migration Decision Trees](#7-migration-decision-trees)
8. [Performance Optimization Decision Framework](#8-performance-optimization-decision-framework)

---

## 1. The Hypertable Decision Framework

### Master Decision Diagram

```
                    ┌─────────────────────────────┐
                    │   Do you have timestamped   │
                    │          data?              │
                    └─────────────┬───────────────┘
                                  │
                    ┌─────────────┴───────────────┐
                    │                             │
                   YES                           NO
                    │                             │
                    ▼                             ▼
    ┌───────────────────────────────┐    ┌──────────────────────┐
    │  Is data primarily appended   │    │ Use regular Postgres │
    │  (not frequently updated)?    │    │       tables         │
    └───────────────┬───────────────┘    └──────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
       YES                     NO
        │                       │
        ▼                       ▼
┌───────────────────┐   ┌────────────────────────────┐
│ Expected rows >   │   │ Consider regular tables    │
│ 10 million?       │   │ with UPDATE/DELETE support │
└───────┬───────────┘   │ OR carefully plan for      │
        │               │ decompression overhead     │
  ┌─────┴─────┐         └────────────────────────────┘
  │           │
 YES         NO
  │           │
  ▼           ▼
┌─────────┐  ┌──────────────────────────────────────┐
│ USE     │  │  Still consider hypertables if:      │
│HYPER-   │  │  • Need compression (>90% savings)   │
│TABLE    │  │  • Need time-based retention         │
└─────────┘  │  • Need continuous aggregates        │
             │  • Data will grow over time          │
             │  Otherwise: regular Postgres tables  │
             └──────────────────────────────────────┘
```

### The 5-Question Hypertable Test

Answer these questions about your data:

| Question | Yes → Points | No → Points |
|----------|--------------|-------------|
| 1. Is time (or UUIDv7) a natural query filter? | +3 | -1 |
| 2. Will you have >10 million rows? | +2 | 0 |
| 3. Is data mostly append-only? | +2 | -1 |
| 4. Do you need time-based data retention? | +2 | 0 |
| 5. Are you doing time-range aggregations? | +2 | 0 |

**Scoring:**
- **7+ points**: Definitely use hypertables
- **4-6 points**: Hypertables likely beneficial
- **1-3 points**: Evaluate carefully, could go either way
- **0 or negative**: Stick with regular PostgreSQL tables

### Feature-Based Decision Matrix

```
┌──────────────────────────────────┬───────────┬───────────────┐
│           Feature Need           │Hypertable │ Regular Table │
├──────────────────────────────────┼───────────┼───────────────┤
│ Automatic time partitioning      │    ✅     │      ❌       │
│ Columnar compression (90%+)      │    ✅     │      ❌       │
│ Continuous aggregates            │    ✅     │      ❌       │
│ Automatic chunk retention        │    ✅     │      ❌       │
│ Time-bucket queries              │    ✅     │   🟡 Manual   │
│ Tiered storage (hot/cold)        │    ✅     │      ❌       │
│ SkipScan for DISTINCT            │    ✅     │      ❌       │
│ Foreign key TO this table        │    ❌     │      ✅       │
│ Frequent single-row UPDATEs      │    🟡     │      ✅       │
│ Cross-partition UPSERTs          │    ❌     │      ✅       │
│ Table inheritance                │    ❌     │      ✅       │
│ Very small datasets (<1M rows)   │    🟡     │      ✅       │
└──────────────────────────────────┴───────────┴───────────────┘

✅ = Excellent support  🟡 = Possible with caveats  ❌ = Not supported
```

---

## 2. When NOT to Use Hypertables

### Hard Constraints (Never Use Hypertables If...)

#### 1. Foreign Key References TO the Table

```sql
-- ❌ THIS WILL NOT WORK
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL,
    data JSONB
);
SELECT create_hypertable('events', 'event_time');

-- This fails or misbehaves:
CREATE TABLE event_comments (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES events(id)  -- ❌ FK to hypertable!
);
```

**Solution Pattern**: Use a regular table for the "referenced" entity, hypertable for time-series data:

```sql
-- ✅ CORRECT PATTERN
-- Regular table for entities
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    metadata JSONB
);

-- Hypertable for time-series (FK FROM hypertable is OK)
CREATE TABLE device_metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id INT REFERENCES devices(id),  -- ✅ FK from hypertable is fine
    cpu_usage FLOAT,
    memory_usage FLOAT
);
SELECT create_hypertable('device_metrics', 'time');
```

#### 2. Cross-Chunk UPDATE/UPSERT Operations

```sql
-- ❌ NOT SUPPORTED: UPDATE that moves data between chunks
UPDATE metrics 
SET time = time + INTERVAL '30 days'  -- Changes partition!
WHERE device_id = 'sensor-1';

-- Error: UPDATE statements that move values between 
-- partitions (chunks) are not supported.
```

**Solution**: Delete and re-insert, or design schema to avoid cross-chunk moves.

#### 3. Unique Constraints Without Time Column

```sql
-- ❌ THIS WILL FAIL
CREATE TABLE events (
    event_id UUID PRIMARY KEY,  -- Must include time!
    time TIMESTAMPTZ NOT NULL,
    data JSONB
);
SELECT create_hypertable('events', 'time');

-- Error: Cannot create unique index without partition column
```

**Solution**: Include time in the unique constraint:

```sql
-- ✅ CORRECT: Include partition column
CREATE TABLE events (
    event_id UUID NOT NULL,
    time TIMESTAMPTZ NOT NULL,
    data JSONB,
    PRIMARY KEY (event_id, time)  -- Time included
);
SELECT create_hypertable('events', 'time');
```

### Soft Constraints (Carefully Evaluate)

#### Small Datasets (<1 Million Rows)

For small datasets, hypertable overhead may not be justified:

```
Dataset Size        Recommendation
─────────────────────────────────────────────────
< 100K rows         Regular table (unless growth expected)
100K - 1M rows      Consider compression benefits
1M - 10M rows       Hypertables beneficial
> 10M rows          Hypertables strongly recommended
```

**Exception**: Even small datasets benefit from hypertables if you need:
- Automatic data retention (e.g., delete data older than 90 days)
- Continuous aggregates for dashboard performance
- Future growth is expected

#### High-Frequency Single-Row Lookups

```sql
-- If 90%+ of queries are point lookups like this:
SELECT * FROM events WHERE event_id = 'abc-123';

-- Regular tables with proper indexes may be faster
-- Hypertables optimize for time-range scans, not point lookups
```

**Benchmark first**: The Hypercore engine has improved point-query performance significantly in 2.20+, but always test your specific workload.

#### Heavily UPDATE-Heavy Workloads

```sql
-- If you're doing this millions of times:
UPDATE metrics SET status = 'processed' WHERE id = 123;
```

Compressed chunks require decompression for updates. Consider:
- Keeping a longer compression delay (7+ days)
- Separating mutable and immutable data into different tables
- Using an "events" pattern instead of mutable state

### The "Partial Fit" Decision Tree

```
          ┌──────────────────────────────────────────┐
          │  Your data partially fits TimescaleDB    │
          └─────────────────┬────────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
     Some data is              All data has timestamps
     non-time-series           but mixed access patterns
          │                                   │
          ▼                                   ▼
┌─────────────────────┐        ┌─────────────────────────────┐
│ HYBRID APPROACH:    │        │ SINGLE-TABLE WITH CAREFUL   │
│ • Regular tables    │        │ COMPRESSION SETTINGS:       │
│   for entities      │        │ • Longer compress_after     │
│ • Hypertables for   │        │ • Strategic segmentby       │
│   time-series data  │        │ • Consider separate tables  │
│ • Join as needed    │        │   for "hot" mutable data    │
└─────────────────────┘        └─────────────────────────────┘
```

---

## 3. Real-World Use Cases

### Use Case 1: IoT Sensor Monitoring

**Scenario**: 10,000 sensors sending data every second, 90-day retention, real-time dashboards.

```sql
-- Metadata table (regular PostgreSQL)
CREATE TABLE sensors (
    sensor_id TEXT PRIMARY KEY,
    location TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    installed_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

-- Time-series data (hypertable)
CREATE TABLE sensor_readings (
    time TIMESTAMPTZ NOT NULL,
    sensor_id TEXT NOT NULL REFERENCES sensors(sensor_id),
    temperature FLOAT,
    humidity FLOAT,
    pressure FLOAT,
    battery_level FLOAT
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '1 day',
    timescaledb.segmentby = 'sensor_id',
    timescaledb.orderby = 'time DESC',
    timescaledb.compress_after = '7 days'
);

-- Essential indexes
CREATE INDEX ON sensor_readings (sensor_id, time DESC);

-- Retention policy
SELECT add_retention_policy('sensor_readings', INTERVAL '90 days');

-- Continuous aggregate for dashboards
CREATE MATERIALIZED VIEW sensor_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    AVG(temperature) AS avg_temp,
    MIN(temperature) AS min_temp,
    MAX(temperature) AS max_temp,
    AVG(humidity) AS avg_humidity,
    COUNT(*) AS reading_count
FROM sensor_readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('sensor_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
```

**Architecture Diagram**:
```
┌─────────────┐     ┌─────────────────────────────────────────────┐
│   Sensors   │────▶│           TimescaleDB                       │
│  (10,000)   │     │  ┌─────────────┐    ┌──────────────────┐   │
└─────────────┘     │  │   sensors   │◄───│ sensor_readings  │   │
                    │  │  (regular)  │ FK │   (hypertable)   │   │
                    │  └─────────────┘    └────────┬─────────┘   │
                    │                              │              │
                    │                     ┌────────▼─────────┐   │
                    │                     │  sensor_hourly   │   │
                    │                     │ (continuous agg) │   │
                    │                     └──────────────────┘   │
                    └─────────────────────────────────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────┐
                    │                       │                   │
                    ▼                       ▼                   ▼
             ┌──────────┐           ┌──────────┐        ┌──────────┐
             │ Grafana  │           │  Alerts  │        │   API    │
             │Dashboard │           │ (recent) │        │(raw data)│
             └──────────┘           └──────────┘        └──────────┘
```

### Use Case 2: Financial Tick Data & OHLC Candles

**Scenario**: High-frequency trading data, 10M+ ticks/day, need OHLC candles at multiple timeframes.

```sql
-- Raw tick data
CREATE TABLE ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL,
    price NUMERIC(20,8) NOT NULL,
    volume NUMERIC(20,8) NOT NULL
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '4 hours',
    timescaledb.segmentby = 'symbol',
    timescaledb.orderby = 'time ASC',
    timescaledb.compress_after = '1 day'
);

-- Index for symbol queries
CREATE INDEX ON ticks (symbol, time DESC);

-- 1-minute OHLC candles (continuous aggregate)
CREATE MATERIALIZED VIEW ohlc_1m
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', time) AS bucket,
    symbol,
    FIRST(price, time) AS open,
    MAX(price) AS high,
    MIN(price) AS low,
    LAST(price, time) AS close,
    SUM(volume) AS volume
FROM ticks
GROUP BY bucket, symbol
WITH NO DATA;

SELECT add_continuous_aggregate_policy('ohlc_1m',
    start_offset => INTERVAL '10 minutes',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute'
);

-- Hierarchical aggregation: 1-hour OHLC from 1-minute
CREATE MATERIALIZED VIEW ohlc_1h
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', bucket) AS bucket,
    symbol,
    FIRST(open, bucket) AS open,
    MAX(high) AS high,
    MIN(low) AS low,
    LAST(close, bucket) AS close,
    SUM(volume) AS volume
FROM ohlc_1m
GROUP BY time_bucket('1 hour', bucket), symbol
WITH NO DATA;

SELECT add_continuous_aggregate_policy('ohlc_1h',
    start_offset => INTERVAL '4 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Daily OHLC from hourly
CREATE MATERIALIZED VIEW ohlc_1d
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', bucket) AS bucket,
    symbol,
    FIRST(open, bucket) AS open,
    MAX(high) AS high,
    MIN(low) AS low,
    LAST(close, bucket) AS close,
    SUM(volume) AS volume
FROM ohlc_1h
GROUP BY time_bucket('1 day', bucket), symbol
WITH NO DATA;
```

**Retention Strategy**:
```sql
-- Raw ticks: 7 days
SELECT add_retention_policy('ticks', INTERVAL '7 days');

-- 1-minute: 30 days
SELECT add_retention_policy('ohlc_1m', INTERVAL '30 days');

-- 1-hour: 1 year
SELECT add_retention_policy('ohlc_1h', INTERVAL '1 year');

-- 1-day: Forever (no retention policy)
```

### Use Case 3: Application Metrics & Observability

**Scenario**: Prometheus-like metrics storage with labels, long-term retention, downsampling.

```sql
-- Metrics with labels (tags)
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    metric_name TEXT NOT NULL,
    labels JSONB NOT NULL,  -- {"service": "api", "instance": "host1"}
    value DOUBLE PRECISION NOT NULL
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '1 day',
    timescaledb.compress_after = '2 days'
);

-- Compression settings for high-cardinality labels
ALTER TABLE metrics SET (
    timescaledb.compress_segmentby = 'metric_name',
    timescaledb.compress_orderby = 'time DESC'
);

-- GIN index for label queries
CREATE INDEX ON metrics USING GIN (labels);

-- Composite index for metric + time
CREATE INDEX ON metrics (metric_name, time DESC);

-- 5-minute rollup for dashboards
CREATE MATERIALIZED VIEW metrics_5m
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('5 minutes', time) AS bucket,
    metric_name,
    labels,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS sample_count
FROM metrics
GROUP BY bucket, metric_name, labels
WITH NO DATA;

-- Query patterns
-- Recent data with specific labels:
SELECT time, value 
FROM metrics 
WHERE metric_name = 'http_requests_total'
  AND labels @> '{"service": "api"}'
  AND time > NOW() - INTERVAL '1 hour'
ORDER BY time DESC;

-- Aggregated dashboard data:
SELECT bucket, avg_value
FROM metrics_5m
WHERE metric_name = 'cpu_usage'
  AND labels @> '{"host": "web-01"}'
  AND bucket > NOW() - INTERVAL '24 hours';
```

### Use Case 4: Event Sourcing / Audit Log

**Scenario**: Immutable event log for compliance, need to query events by entity and time.

```sql
-- Event store (hypertable)
CREATE TABLE events (
    event_id UUID NOT NULL DEFAULT gen_random_uuid(),
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type TEXT NOT NULL,
    aggregate_type TEXT NOT NULL,  -- 'Order', 'User', etc.
    aggregate_id UUID NOT NULL,
    payload JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    PRIMARY KEY (event_id, event_time)  -- Must include time!
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'event_time',
    timescaledb.chunk_time_interval = '1 week'
);

-- Compression (events are immutable - compress aggressively)
ALTER TABLE events SET (
    timescaledb.compress_segmentby = 'aggregate_type',
    timescaledb.compress_orderby = 'event_time DESC',
    timescaledb.compress_after = '1 day'
);

-- Index for aggregate queries
CREATE INDEX ON events (aggregate_type, aggregate_id, event_time DESC);

-- Index for event type queries
CREATE INDEX ON events (event_type, event_time DESC);

-- Query: Get all events for an order
SELECT * FROM events
WHERE aggregate_type = 'Order'
  AND aggregate_id = 'order-uuid-here'
ORDER BY event_time ASC;

-- Query: Get recent events of a type
SELECT * FROM events
WHERE event_type = 'OrderCreated'
  AND event_time > NOW() - INTERVAL '24 hours'
ORDER BY event_time DESC;

-- Retention: Keep raw events for 2 years
SELECT add_retention_policy('events', INTERVAL '2 years');
```

**Gotcha**: Events are immutable, but you can't have a simple `event_id PRIMARY KEY`. You must include the partition column.

### Use Case 5: Multi-Tenant SaaS Analytics

**Scenario**: B2B SaaS with 1000s of tenants, each tenant's data must be isolated, varying data volumes per tenant.

```sql
-- Tenant metadata (regular table)
CREATE TABLE tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    plan TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Per-tenant analytics (hypertable)
CREATE TABLE tenant_events (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    event_type TEXT NOT NULL,
    user_id UUID,
    properties JSONB,
    PRIMARY KEY (tenant_id, time, event_type)
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.chunk_time_interval = '1 day'
);

-- CRITICAL: Segmentby tenant for compression
ALTER TABLE tenant_events SET (
    timescaledb.compress_segmentby = 'tenant_id',
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_after = '7 days'
);

-- Index for tenant isolation
CREATE INDEX ON tenant_events (tenant_id, time DESC);
CREATE INDEX ON tenant_events (tenant_id, event_type, time DESC);

-- Row-Level Security for tenant isolation
ALTER TABLE tenant_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant_events
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Usage: Set tenant context before queries
SET app.current_tenant = 'tenant-uuid-here';
SELECT * FROM tenant_events WHERE time > NOW() - INTERVAL '7 days';

-- Per-tenant continuous aggregates (with tenant_id in GROUP BY)
CREATE MATERIALIZED VIEW tenant_daily_stats
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', time) AS day,
    tenant_id,
    event_type,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM tenant_events
GROUP BY day, tenant_id, event_type
WITH NO DATA;
```

**Multi-Tenant Decision Points**:

```
┌─────────────────────────────────────────────────────────────────┐
│              Multi-Tenant Isolation Strategy                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐     ┌───────────────────────────────────┐ │
│  │ How many        │     │ < 100 tenants + high isolation:   │ │
│  │ tenants?        │────▶│ Consider database-per-tenant      │ │
│  │                 │     │                                   │ │
│  └────────┬────────┘     │ > 100 tenants:                    │ │
│           │              │ Shared database + RLS             │ │
│           ▼              └───────────────────────────────────┘ │
│  ┌─────────────────┐                                           │
│  │ Data volume     │     ┌───────────────────────────────────┐ │
│  │ varies greatly? │────▶│ Yes: Use tenant_id as segmentby   │ │
│  │                 │     │ (each tenant compressed separately)│ │
│  └────────┬────────┘     └───────────────────────────────────┘ │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐     ┌───────────────────────────────────┐ │
│  │ Need per-tenant │     │ Add retention policies per-tenant │ │
│  │ retention?      │────▶│ (requires custom job or filtering)│ │
│  └─────────────────┘     └───────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Tricky Hybrid Scenarios

### Scenario A: Mixed Time-Series and Transactional Data

**Problem**: Application needs both fast transactional updates AND time-series analytics.

**Solution**: Hybrid architecture with separate tables

```sql
-- Transactional data (regular table)
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order status changes (hypertable for analytics)
CREATE TABLE order_events (
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    order_id UUID NOT NULL,
    event_type TEXT NOT NULL,  -- 'created', 'paid', 'shipped', 'delivered'
    previous_status TEXT,
    new_status TEXT,
    metadata JSONB
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time'
);

-- Trigger to capture status changes
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO order_events (order_id, event_type, previous_status, new_status)
        VALUES (NEW.order_id, 'status_change', OLD.status, NEW.status);
    END IF;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_change
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_status_change();
```

### Scenario B: High-Cardinality Tags Problem

**Problem**: Metrics with millions of unique tag combinations.

**Anti-pattern** (causes tiny compressed segments):
```sql
-- ❌ DON'T DO THIS
ALTER TABLE metrics SET (
    timescaledb.compress_segmentby = 'metric_name, host, container_id, pod_name'
);
-- Results in millions of tiny segments with poor compression
```

**Solution**: Use orderby instead of segmentby for high-cardinality columns:

```sql
-- ✅ CORRECT APPROACH
ALTER TABLE metrics SET (
    timescaledb.compress_segmentby = 'metric_name',  -- Low cardinality
    timescaledb.compress_orderby = 'host, time DESC'  -- High cardinality in orderby
);

-- Also enable bloom filters for point queries on high-cardinality columns
ALTER TABLE metrics SET (
    timescaledb.compress_index = 'bloom("container_id"), minmax("time")'
);
```

### Scenario C: Querying Without Time Filter

**Problem**: Need to query all data for a specific entity without time bounds.

```sql
-- This query scans ALL chunks:
SELECT * FROM metrics WHERE device_id = 'sensor-42';  -- 😱 Full scan!
```

**Solutions**:

1. **Enable chunk skipping** (requires index on device_id):
```sql
-- Enable skip scan for non-time columns
SELECT enable_chunk_skipping('metrics', 'device_id');
```

2. **Space partitioning** (for very large single-entity datasets):
```sql
SELECT add_dimension('metrics', 'device_id', number_partitions => 16);
```

3. **Materialized view** (for dashboard queries):
```sql
CREATE MATERIALIZED VIEW latest_by_device AS
SELECT DISTINCT ON (device_id) *
FROM metrics
ORDER BY device_id, time DESC;
```

### Scenario D: Late-Arriving Data

**Problem**: Data arrives days or weeks late, after chunks are compressed.

```sql
-- This will decompress, insert, then compress again:
INSERT INTO metrics (time, device_id, value)
VALUES ('2024-01-01', 'sensor-1', 42.0);  -- Old data
```

**Solutions**:

1. **Backfill window in compression policy**:
```sql
ALTER TABLE metrics SET (
    timescaledb.compress_after = '7 days'  -- Give time for late data
);
```

2. **Manual chunk management for large backfills**:
```sql
-- Decompress specific chunks before bulk insert
SELECT decompress_chunk(c.chunk_schema || '.' || c.chunk_name)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'metrics'
  AND c.range_start >= '2024-01-01'
  AND c.range_end < '2024-01-08';

-- Bulk insert
\copy metrics FROM 'late_data.csv' CSV HEADER;

-- Recompress
SELECT compress_chunk(c.chunk_schema || '.' || c.chunk_name)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'metrics'
  AND c.range_start >= '2024-01-01'
  AND c.range_end < '2024-01-08'
  AND NOT c.is_compressed;
```

### Scenario E: Data That's Almost Time-Series

**Problem**: Data has timestamps but primary access pattern is not time-based.

Examples:
- User session data (query by user_id mostly)
- Product catalog with price history (query by product_id)
- Document versions (query by document_id)

**Decision Framework**:

```
┌─────────────────────────────────────────────────────────────┐
│  Primary query pattern?                                      │
├───────────────────────────────┬─────────────────────────────┤
│                               │                             │
│  By entity (user, product)    │    By time range            │
│                               │                             │
│           │                   │          │                  │
│           ▼                   │          ▼                  │
│  ┌────────────────────┐       │  ┌────────────────────┐     │
│  │  Consider regular  │       │  │   Use hypertable   │     │
│  │  table with time   │       │  │   with entity in   │     │
│  │  column indexed    │       │  │   segmentby        │     │
│  └────────────────────┘       │  └────────────────────┘     │
│                               │                             │
│  UNLESS you need:             │                             │
│  • Automatic retention        │                             │
│  • Compression (>90%)         │                             │
│  • Time-range analytics       │                             │
│                               │                             │
│  Then: hypertable with        │                             │
│  entity_id as segmentby       │                             │
└───────────────────────────────┴─────────────────────────────┘
```

---

## 5. Multi-Tenant Architecture Patterns

### Pattern 1: Shared Database, Tenant Column + RLS

**Best for**: Many tenants (100+), similar data volumes, cost-sensitive

```sql
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION
) WITH (
    timescaledb.hypertable,
    timescaledb.partition_column = 'time',
    timescaledb.segmentby = 'tenant_id'  -- Critical!
);

-- Row-Level Security
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_policy ON metrics
    USING (tenant_id = current_setting('app.tenant_id')::UUID);

-- Application sets context:
-- SET app.tenant_id = 'tenant-uuid';
```

### Pattern 2: Schema-Per-Tenant

**Best for**: Moderate tenants (10-100), need logical separation, different retention needs

```sql
-- Create schema per tenant
CREATE SCHEMA tenant_acme;

CREATE TABLE tenant_acme.metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION
);
SELECT create_hypertable('tenant_acme.metrics', 'time');

-- Repeat for each tenant, or automate:
CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_name TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', tenant_name);
    EXECUTE format('
        CREATE TABLE %I.metrics (
            time TIMESTAMPTZ NOT NULL,
            device_id TEXT NOT NULL,
            value DOUBLE PRECISION
        )', tenant_name);
    EXECUTE format('SELECT create_hypertable(''%I.metrics'', ''time'')', tenant_name);
END;
$$ LANGUAGE plpgsql;
```

### Pattern 3: Database-Per-Tenant

**Best for**: Enterprise tenants, strict isolation requirements, compliance needs

```
┌─────────────────────────────────────────────────────────────┐
│                     PostgreSQL Cluster                       │
├─────────────────┬─────────────────┬─────────────────────────┤
│   db_tenant_a   │   db_tenant_b   │      db_tenant_c        │
│   (TimescaleDB) │   (TimescaleDB) │      (TimescaleDB)      │
│   ┌──────────┐  │   ┌──────────┐  │      ┌──────────┐       │
│   │ metrics  │  │   │ metrics  │  │      │ metrics  │       │
│   └──────────┘  │   └──────────┘  │      └──────────┘       │
└─────────────────┴─────────────────┴─────────────────────────┘
```

Application routes connections based on tenant.

### Comparison Matrix

| Factor | Shared + RLS | Schema-Per-Tenant | DB-Per-Tenant |
|--------|--------------|-------------------|---------------|
| Number of tenants | 100s-1000s | 10s-100s | 1s-10s |
| Isolation level | Logical | Logical | Physical |
| Resource sharing | Maximum | Moderate | None |
| Management overhead | Low | Moderate | High |
| Per-tenant backup | Difficult | Moderate | Easy |
| Per-tenant retention | Via policy | Native | Native |
| Compliance (HIPAA, etc.) | Possible | Better | Best |
| Cost efficiency | Best | Good | Expensive |

---

## 6. TimescaleDB vs Alternatives Decision Guide

### When to Choose TimescaleDB

```
✅ CHOOSE TIMESCALEDB IF:

┌─────────────────────────────────────────────────────────────┐
│ • You're already using PostgreSQL                           │
│ • You need relational features (JOINs, FK, transactions)    │
│ • You have mixed workload (OLTP + time-series)             │
│ • Team knows SQL (don't want new query language)           │
│ • Data requires updates/deletes (mutable time-series)      │
│ • You need PostGIS for geospatial + time-series            │
│ • Moderate write throughput (<1M rows/sec sustained)       │
│ • You value PostgreSQL ecosystem (tools, extensions)        │
└─────────────────────────────────────────────────────────────┘
```

### When to Consider ClickHouse Instead

```
⚡ CONSIDER CLICKHOUSE IF:

┌─────────────────────────────────────────────────────────────┐
│ • Purely analytical workload (no transactions needed)       │
│ • Massive write throughput (10M+ rows/sec)                 │
│ • Petabyte-scale data                                      │
│ • Complex aggregations over billions of rows               │
│ • Data is immutable (no updates/deletes)                   │
│ • Willing to learn ClickHouse SQL dialect                  │
│ • Don't need relational features                           │
└─────────────────────────────────────────────────────────────┘
```

### When to Consider InfluxDB Instead

```
📊 CONSIDER INFLUXDB IF:

┌─────────────────────────────────────────────────────────────┐
│ • Pure metrics/monitoring use case                          │
│ • High-frequency individual writes (not batched)           │
│ • Native Flux language is acceptable                        │
│ • Need built-in downsampling out of box                    │
│ • Integrating with Telegraf ecosystem                      │
│ • Don't need relational features at all                    │
└─────────────────────────────────────────────────────────────┘
```

### Hybrid Architecture Pattern

The "smart factory" pattern combines multiple databases for their strengths:

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA PIPELINE                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┐     ┌─────────┐     ┌─────────────────────┐   │
│  │ Sensors │────▶│  Kafka  │────▶│                     │   │
│  └─────────┘     └────┬────┘     │                     │   │
│                       │          │                     │   │
│       ┌───────────────┼──────────┤                     │   │
│       │               │          │                     │   │
│       ▼               ▼          ▼                     │   │
│  ┌─────────┐    ┌───────────┐   ┌───────────────────┐  │   │
│  │InfluxDB │    │TimescaleDB│   │    ClickHouse     │  │   │
│  │(alerts) │    │(OLTP+OLAP)│   │ (historical OLAP) │  │   │
│  │<1 hour  │    │<30 days   │   │    >30 days       │  │   │
│  └─────────┘    └───────────┘   └───────────────────┘  │   │
│       │               │                  │              │   │
│       └───────────────┼──────────────────┘              │   │
│                       ▼                                 │   │
│               ┌──────────────┐                          │   │
│               │   Grafana    │                          │   │
│               └──────────────┘                          │   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Migration Decision Trees

### Migrating FROM PostgreSQL to TimescaleDB

```
┌─────────────────────────────────────────────────────────────┐
│          PostgreSQL → TimescaleDB Migration                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
      Table is empty               Table has data
            │                               │
            ▼                               ▼
    ┌───────────────┐             ┌─────────────────────┐
    │CREATE TABLE   │             │ How much data?      │
    │WITH (tsdb..)  │             └─────────┬───────────┘
    └───────────────┘                       │
                              ┌─────────────┴─────────────┐
                              │                           │
                         < 100GB                       > 100GB
                              │                           │
                              ▼                           ▼
                    ┌─────────────────┐        ┌─────────────────────┐
                    │create_hypertable│        │ Staged migration:   │
                    │migrate_data=true│        │ 1. Create new table │
                    └─────────────────┘        │ 2. Copy in chunks   │
                                               │ 3. Rename tables    │
                                               └─────────────────────┘
```

### Migrating FROM InfluxDB to TimescaleDB

```sql
-- 1. Create equivalent schema
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    measurement TEXT NOT NULL,  -- InfluxDB measurement name
    tags JSONB NOT NULL,        -- InfluxDB tags as JSONB
    fields JSONB NOT NULL       -- InfluxDB fields as JSONB
);
SELECT create_hypertable('metrics', 'time');

-- 2. Or normalized schema (better for querying):
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    metric_name TEXT NOT NULL,
    host TEXT,
    region TEXT,
    value DOUBLE PRECISION
);
SELECT create_hypertable('metrics', 'time');

-- 3. Export from InfluxDB using influx CLI, import via COPY
```

---

## 8. Performance Optimization Decision Framework

### Query Performance Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│                 Query is slow. What to do?                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │ Does query have time  │
                │ filter/constraint?    │
                └───────────┬───────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
           NO                              YES
            │                               │
            ▼                               ▼
   ┌────────────────────┐      ┌────────────────────────────┐
   │ADD TIME FILTER!    │      │ Check EXPLAIN ANALYZE      │
   │This is #1 mistake  │      │ Is it scanning all chunks? │
   └────────────────────┘      └─────────────┬──────────────┘
                                             │
                               ┌─────────────┴─────────────┐
                               │                           │
                         Scanning all            Only relevant chunks
                               │                           │
                               ▼                           ▼
                   ┌────────────────────┐     ┌────────────────────────┐
                   │ Missing index?     │     │ Need better index?     │
                   │ • Add (col, time)  │     │ • Check column order   │
                   │ • Enable chunk skip│     │ • Consider BRIN        │
                   └────────────────────┘     │ • Partial index        │
                                              └────────────────────────┘
```

### Compression Decision Framework

```
┌─────────────────────────────────────────────────────────────┐
│              Compression not working well?                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────────┐
                │ Check compression ratio   │
                │ SELECT * FROM             │
                │ chunk_compression_stats   │
                └───────────────┬───────────┘
                                │
            ┌───────────────────┴───────────────────┐
            │                                       │
        < 50%                                    > 70%
    (poor compression)                      (good compression)
            │                                       │
            ▼                                       ▼
   ┌─────────────────────────┐          ┌─────────────────────┐
   │ Check segmentby config  │          │ ✅ Compression OK   │
   │                         │          │ Consider:           │
   │ High cardinality in     │          │ • More aggressive   │
   │ segmentby?              │          │   compress_after    │
   │                         │          │ • Bloom filters     │
   │ Move high-cardinality   │          └─────────────────────┘
   │ to orderby instead      │
   └─────────────────────────┘
```

### Chunk Sizing Decision

```
┌─────────────────────────────────────────────────────────────┐
│             What chunk interval should I use?                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  RULE: Chunk indexes should fit in 25% of RAM              │
│                                                             │
│  Formula:                                                   │
│  Index growth per day × chunk_days ≤ 25% of RAM            │
│                                                             │
│  Example: 64GB RAM → 16GB for chunk indexes                 │
│           10GB index growth/day → use 1-day chunks          │
│           2GB index growth/day → use 7-day chunks           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Typical starting points by use case:                       │
│                                                             │
│  IoT (high volume):         4 hours - 1 day                │
│  Metrics/Observability:     1 day - 1 week                 │
│  Financial tick data:       1 hour - 4 hours               │
│  Event logs:                1 day - 1 week                 │
│  Slow-moving data:          1 week - 1 month               │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Cards

### Hypertable Checklist

```
Before creating a hypertable:

□ Time column is TIMESTAMPTZ (not TIMESTAMP)
□ Time column cannot be NULL
□ Unique constraints include time column
□ Foreign keys FROM hypertable (not TO) are planned
□ Chunk interval calculated based on index size + RAM
□ segmentby columns have reasonable cardinality (<10K values)
□ No plans for cross-chunk UPDATEs
```

### Compression Checklist

```
Before enabling compression:

□ segmentby: Low cardinality columns used for filtering
□ orderby: Time column + high-cardinality columns
□ compress_after: Long enough for late-arriving data
□ Bloom filters considered for high-cardinality lookups
□ Tested that INSERT/UPDATE patterns work with compression
```

### Continuous Aggregate Checklist

```
Before creating continuous aggregates:

□ WITH NO DATA for large existing datasets
□ Appropriate bucket size for query patterns
□ Refresh policy matches data freshness needs
□ Consider hierarchical aggregates (minute → hour → day)
□ Include all GROUP BY columns needed for RLS
```

---

*This guide is a companion to the TimescaleDB Master Guide 2026. For detailed technical reference, consult the Master Guide and official documentation.*
