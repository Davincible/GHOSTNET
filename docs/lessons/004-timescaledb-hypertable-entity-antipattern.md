# Lesson: Hypertables for Entity Tables is an Antipattern

**Date:** 2026-01-21  
**Category:** Database/TimescaleDB  
**Difficulty:** Architecture review (prevented future pain)

## Problem

The GHOSTNET indexer's `positions` table was implemented as a TimescaleDB hypertable, partitioned by `entry_timestamp`. This caused several architectural issues:

1. **Update performance degradation**: Positions are entities with frequent updates (`amount`, `ghost_streak`, `is_alive`). Hypertables with compression require decompressing chunks to update rows.

2. **Inefficient lookups**: The primary query pattern is "get user's active position by address", but partitioning by time means the position could be in any chunk based on when the user jacked in.

3. **Forced composite primary key**: TimescaleDB requires the partition column in primary keys, leading to `(id, entry_timestamp)` instead of just `id`. This forces awkward query patterns.

4. **Meanwhile, `deaths` was a regular table**: The `deaths` table IS append-only time-series data (perfect for hypertables) but was implemented as a regular table due to a misunderstanding about unique constraints.

## What Was Wrong

### Positions (Incorrectly a Hypertable)

```sql
-- WRONG: Entity table as hypertable
CREATE TABLE positions (
    id UUID,
    entry_timestamp TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, entry_timestamp)  -- Forced composite key
);
SELECT create_hypertable('positions', 'entry_timestamp');
```

Query to find user's position:
```sql
-- Scans potentially many chunks
SELECT * FROM positions 
WHERE user_address = $1 AND is_alive = true
ORDER BY entry_timestamp DESC LIMIT 1;
```

### Deaths (Incorrectly a Regular Table)

```sql
-- WRONG: Time-series data as regular table
CREATE TABLE deaths (
    id UUID PRIMARY KEY,  -- No time partitioning
    created_at TIMESTAMPTZ NOT NULL
);
```

The migration comment said "Deaths are NOT hypertables... they need foreign key integrity" - but this was incorrect. FK to scan UUID doesn't prevent hypertable usage.

## Solution

### Decision Framework: Hypertable vs Regular Table

```
Is it append-mostly? ──NO──> Regular PostgreSQL Table
        │
       YES
        │
        v
Will you query by time ranges? ──NO──> Consider if compression alone helps
        │
       YES
        │
        v
    HYPERTABLE with compression
```

### Corrected Schema

**Positions: Regular Table**
```sql
CREATE TABLE positions (
    id UUID PRIMARY KEY,  -- Simple primary key
    user_address BYTEA NOT NULL,
    ...
);
CREATE UNIQUE INDEX idx_positions_unique_active 
    ON positions(user_address) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;
```

**Deaths: Hypertable**
```sql
CREATE TABLE deaths (
    id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (created_at, id)  -- Time first for partition
);
SELECT create_hypertable('deaths', 'created_at', chunk_time_interval => INTERVAL '1 day');
ALTER TABLE deaths SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'created_at DESC'
);
```

## Why It Works

### Hypertables Are Designed For:
- **Append-only data**: INSERT once, rarely UPDATE
- **Time-range queries**: "Events in last 24 hours"
- **High volume**: Millions of rows per day
- **Compression**: Old data rarely accessed individually

### Regular Tables Are Better For:
- **Entity data**: Users, positions, accounts
- **Frequent updates**: Status changes, balance updates
- **Lookup by ID/key**: "Get user's current position"
- **Foreign key targets**: Referenced by other tables

### The Compression Problem

When a hypertable chunk is compressed:
1. Data is converted to columnar format
2. Rows can't be updated directly
3. UPDATE requires: decompress chunk -> find row -> update -> leave uncompressed

This makes compressed hypertables essentially read-only for practical purposes.

## Prevention

Before making a table a hypertable, ask:

1. **Will this table receive UPDATEs?** If yes -> Regular table
2. **Is the primary query pattern by time range?** If no -> Regular table
3. **Is this an entity (user, position, account)?** If yes -> Regular table
4. **Is this an event log (deaths, transfers, history)?** If yes -> Hypertable

### Quick Reference

| Table Type | Example | Should Be |
|------------|---------|-----------|
| Entity with state | positions, users, accounts | Regular |
| Event log | deaths, transfers, history | Hypertable |
| Audit trail | position_history | Hypertable |
| Config/singleton | indexer_state, global_stats | Regular |

## Related

- TimescaleDB docs: "When to use hypertables"
- Reference: `docs/architecture/references/timescaledb-general.md` Section 2.1
