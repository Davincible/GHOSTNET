-- Scans and Deaths tables
-- Scans are periodic events that determine position deaths.

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCANS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Note: Scans are NOT hypertables because:
-- 1. They need a globally unique constraint on scan_id (on-chain ID)
-- 2. They're discrete events, not continuous time-series data
-- 3. TimescaleDB hypertables cannot have unique indexes without the partition column

CREATE TABLE IF NOT EXISTS scans (
    id                      UUID PRIMARY KEY,
    scan_id                 VARCHAR(78) NOT NULL UNIQUE,   -- On-chain U256 as string
    level                   SMALLINT NOT NULL,
    seed                    VARCHAR(78) NOT NULL,          -- Random seed (U256)
    executed_at             TIMESTAMPTZ NOT NULL,
    finalized_at            TIMESTAMPTZ,                   -- NULL until finalized
    death_count             INTEGER,
    total_dead              NUMERIC,                       -- Total DATA lost
    burned                  NUMERIC,
    distributed_same_level  NUMERIC,
    distributed_upstream    NUMERIC,
    protocol_fee            NUMERIC,
    survivor_count          INTEGER,
    
    CONSTRAINT chk_scan_level CHECK (level >= 1 AND level <= 5)
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_scans_level ON scans(level, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_scans_pending ON scans(executed_at ASC) 
    WHERE finalized_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_scans_executed_at ON scans(executed_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEATHS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Note: Deaths are NOT hypertables for the same reasons as scans.
-- Also, we need foreign key integrity with scans table.

CREATE TABLE IF NOT EXISTS deaths (
    id                      UUID PRIMARY KEY,
    scan_id                 UUID REFERENCES scans(id),     -- May be NULL for culling deaths
    user_address            BYTEA NOT NULL,
    position_id             UUID,                          -- Link to position (if known)
    amount_lost             NUMERIC NOT NULL,
    level                   SMALLINT NOT NULL,
    ghost_streak_at_death   INTEGER,
    created_at              TIMESTAMPTZ NOT NULL,
    
    CONSTRAINT chk_death_level CHECK (level >= 1 AND level <= 5),
    CONSTRAINT chk_amount_lost_positive CHECK (amount_lost >= 0)
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_deaths_scan ON deaths(scan_id) WHERE scan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deaths_user ON deaths(user_address, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deaths_level ON deaths(level, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deaths_position ON deaths(position_id) WHERE position_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deaths_created_at ON deaths(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- LEVEL STATISTICS (materialized for fast queries)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS level_stats (
    level               SMALLINT PRIMARY KEY,
    total_staked        NUMERIC NOT NULL DEFAULT 0,
    alive_count         INTEGER NOT NULL DEFAULT 0,
    total_deaths        INTEGER NOT NULL DEFAULT 0,
    total_extracted     INTEGER NOT NULL DEFAULT 0,
    total_burned        NUMERIC NOT NULL DEFAULT 0,
    total_distributed   NUMERIC NOT NULL DEFAULT 0,
    highest_ghost_streak INTEGER NOT NULL DEFAULT 0,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT chk_stats_level CHECK (level >= 0 AND level <= 5)
);

-- Initialize stats for all levels
INSERT INTO level_stats (level) 
VALUES (0), (1), (2), (3), (4), (5)
ON CONFLICT (level) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- GLOBAL STATISTICS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS global_stats (
    id                          INTEGER PRIMARY KEY DEFAULT 1,
    total_value_locked          NUMERIC NOT NULL DEFAULT 0,
    total_positions             INTEGER NOT NULL DEFAULT 0,
    total_deaths                INTEGER NOT NULL DEFAULT 0,
    total_burned                NUMERIC NOT NULL DEFAULT 0,
    total_emissions_distributed NUMERIC NOT NULL DEFAULT 0,
    total_toll_collected        NUMERIC NOT NULL DEFAULT 0,
    total_buyback_burned        NUMERIC NOT NULL DEFAULT 0,
    system_reset_count          INTEGER NOT NULL DEFAULT 0,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT single_row CHECK (id = 1)
);

-- Initialize single row
INSERT INTO global_stats (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE scans IS 'Trace scan events that determine position deaths';
COMMENT ON COLUMN scans.scan_id IS 'On-chain scan ID (U256 as string for precision)';
COMMENT ON COLUMN scans.seed IS 'Random seed used for death selection';

COMMENT ON TABLE deaths IS 'Individual death records from scans or culling';
COMMENT ON COLUMN deaths.ghost_streak_at_death IS 'Ghost streak at time of death (for analytics)';

-- Note: scans and deaths are regular tables (not hypertables) to support:
-- 1. Unique constraints on natural keys (scan_id on-chain ID)
-- 2. Foreign key constraints (deaths → scans)
-- Positions remain hypertables for time-series query optimization.

COMMENT ON TABLE level_stats IS 'Pre-computed statistics per risk level';
COMMENT ON TABLE global_stats IS 'Protocol-wide statistics (single row)';
