-- GHOSTNET Indexer Schema v2: Optimized TimescaleDB Design
-- 
-- This migration replaces the original schema with an optimized design based on
-- TimescaleDB best practices. Key changes:
--
-- 1. `positions` is now a REGULAR TABLE (was hypertable) - entities with updates
-- 2. `deaths` is now a HYPERTABLE (was regular) - append-only time-series
-- 3. `block_hashes` is now a HYPERTABLE with retention - auto-pruned
-- 4. Compression policies added for all hypertables
-- 5. Continuous aggregates for analytics
-- 6. Fixed timestamp types (TIMESTAMPTZ instead of BIGINT)
--
-- Reference: docs/learnings/004-timescaledb-hypertable-entity-antipattern.md

-- ═══════════════════════════════════════════════════════════════════════════════
-- STEP 1: DROP OLD TABLES IF THEY EXIST (for clean migrations)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Drop continuous aggregates first (they depend on hypertables)
DROP MATERIALIZED VIEW IF EXISTS death_stats_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS position_activity_hourly CASCADE;

-- Drop tables (in dependency order)
DROP TABLE IF EXISTS deaths CASCADE;
DROP TABLE IF EXISTS position_history CASCADE;
DROP TABLE IF EXISTS positions CASCADE;
DROP TABLE IF EXISTS scans CASCADE;
DROP TABLE IF EXISTS level_stats CASCADE;
DROP TABLE IF EXISTS global_stats CASCADE;
DROP TABLE IF EXISTS block_hashes CASCADE;
DROP TABLE IF EXISTS block_history CASCADE;
DROP TABLE IF EXISTS indexer_state CASCADE;

-- Drop old functions
DROP FUNCTION IF EXISTS handle_reorg CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXER STATE (Regular Table - Configuration)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tracks indexer progress per chain. Single row per chain_id.
CREATE TABLE indexer_state (
    chain_id            BIGINT PRIMARY KEY,           -- MegaETH = 6342
    last_block          BIGINT NOT NULL DEFAULT 0,
    last_block_hash     BYTEA,
    last_block_timestamp TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE indexer_state IS 'Indexer progress tracking, one row per chain';
COMMENT ON COLUMN indexer_state.chain_id IS 'Chain ID (6342 = MegaETH)';

-- Initialize MegaETH chain
INSERT INTO indexer_state (chain_id) VALUES (6342) ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCK HISTORY (Hypertable - Auto-pruned for reorg detection)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Stores recent block hashes for detecting chain reorganizations.
-- Auto-pruned after 30 minutes (~128 blocks on MegaETH's ~15s block time).
CREATE TABLE block_history (
    block_number        BIGINT NOT NULL,
    block_hash          BYTEA NOT NULL,
    parent_hash         BYTEA NOT NULL,
    timestamp           TIMESTAMPTZ NOT NULL,         -- TIMESTAMPTZ not BIGINT!
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (timestamp, block_number)
);

SELECT create_hypertable('block_history', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

-- Auto-prune after 30 minutes (plenty of margin for ~128 block reorgs)
SELECT add_retention_policy('block_history', INTERVAL '30 minutes',
    if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_block_history_number ON block_history(block_number);
CREATE INDEX IF NOT EXISTS idx_block_history_parent ON block_history(parent_hash);

COMMENT ON TABLE block_history IS 'Recent block hashes for reorg detection (auto-pruned)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITIONS (Regular Table - Entity with Updates)
-- ═══════════════════════════════════════════════════════════════════════════════

-- CRITICAL: This is a REGULAR TABLE, not a hypertable!
-- Positions are entities with frequent updates (amount, ghost_streak, is_alive).
-- Hypertables with compression are effectively read-only.
CREATE TABLE positions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_address        BYTEA NOT NULL,               -- 20-byte Ethereum address
    level               SMALLINT NOT NULL,            -- Risk level (0-5)
    amount              NUMERIC(78, 0) NOT NULL,      -- Current staked amount (wei)
    reward_debt         NUMERIC(78, 0) NOT NULL DEFAULT 0,
    entry_timestamp     TIMESTAMPTZ NOT NULL,
    last_add_timestamp  TIMESTAMPTZ,
    ghost_streak        INTEGER NOT NULL DEFAULT 0,
    is_alive            BOOLEAN NOT NULL DEFAULT TRUE,
    is_extracted        BOOLEAN NOT NULL DEFAULT FALSE,
    exit_reason         VARCHAR(32),                  -- 'Extracted', 'Traced', 'Culled'
    exit_timestamp      TIMESTAMPTZ,
    extracted_amount    NUMERIC(78, 0),
    extracted_rewards   NUMERIC(78, 0),
    created_at_block    BIGINT NOT NULL,
    updated_at_block    BIGINT NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT chk_level CHECK (level >= 0 AND level <= 5),
    CONSTRAINT chk_amount_non_negative CHECK (amount >= 0),
    CONSTRAINT chk_ghost_streak_non_negative CHECK (ghost_streak >= 0)
);

-- Primary access pattern: user's active position
CREATE INDEX idx_positions_user ON positions(user_address);

-- Unique constraint: only one active position per user
CREATE UNIQUE INDEX idx_positions_unique_active 
    ON positions(user_address) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Query by level for scan processing
CREATE INDEX idx_positions_level_alive 
    ON positions(level) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Find oldest positions in level (for culling)
CREATE INDEX idx_positions_level_entry 
    ON positions(level, entry_timestamp ASC) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Ghost streak leaderboard
CREATE INDEX idx_positions_ghost_streak 
    ON positions(ghost_streak DESC) 
    WHERE is_alive = TRUE;

-- Reorg handling
CREATE INDEX idx_positions_block ON positions(created_at_block);
CREATE INDEX idx_positions_updated_block ON positions(updated_at_block);

COMMENT ON TABLE positions IS 'User staking positions (REGULAR table - has updates)';
COMMENT ON COLUMN positions.level IS '0=None, 1=Vault, 2=Mainframe, 3=Subnet, 4=Darknet, 5=BlackIce';
COMMENT ON COLUMN positions.ghost_streak IS 'Consecutive scan survivals';
COMMENT ON COLUMN positions.reward_debt IS 'MasterChef-style reward tracking';

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITION HISTORY (Hypertable - Append-only Audit Trail)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE position_history (
    id                  UUID DEFAULT gen_random_uuid(),
    position_id         UUID NOT NULL,
    user_address        BYTEA NOT NULL,               -- Denormalized for efficient queries
    action              VARCHAR(32) NOT NULL,         -- 'JackedIn', 'StakeAdded', etc.
    amount_change       NUMERIC(78, 0) NOT NULL,      -- Delta (can be negative)
    new_total           NUMERIC(78, 0) NOT NULL,
    block_number        BIGINT NOT NULL,
    tx_hash             BYTEA,
    timestamp           TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (timestamp, id)
);

SELECT create_hypertable('position_history', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE);

-- Compression: segment by user for efficient history queries
ALTER TABLE position_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_address',
    timescaledb.compress_orderby = 'timestamp DESC'
);

SELECT add_compression_policy('position_history', INTERVAL '1 day',
    if_not_exists => TRUE);

-- Retention: keep 1 year of history
SELECT add_retention_policy('position_history', INTERVAL '365 days',
    if_not_exists => TRUE);

CREATE INDEX idx_position_history_position ON position_history(position_id, timestamp DESC);
CREATE INDEX idx_position_history_user ON position_history(user_address, timestamp DESC);
CREATE INDEX idx_position_history_block ON position_history(block_number);

COMMENT ON TABLE position_history IS 'Audit trail of position changes (hypertable)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCANS (Regular Table - Low volume, needs unique constraint)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Scans remain a regular table because:
-- 1. Low volume (a few per hour at most)
-- 2. Need globally unique constraint on scan_id
-- 3. Referenced by deaths table
CREATE TABLE scans (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id                 VARCHAR(78) NOT NULL UNIQUE,  -- On-chain U256 as string
    level                   SMALLINT NOT NULL,
    seed                    VARCHAR(78) NOT NULL,
    executed_at             TIMESTAMPTZ NOT NULL,
    finalized_at            TIMESTAMPTZ,
    death_count             INTEGER,
    total_dead              NUMERIC(78, 0),
    burned                  NUMERIC(78, 0),
    distributed_same_level  NUMERIC(78, 0),
    distributed_upstream    NUMERIC(78, 0),
    protocol_fee            NUMERIC(78, 0),
    survivor_count          INTEGER,
    executed_block          BIGINT,            -- TODO: Make NOT NULL after entity update
    executed_tx             BYTEA,             -- TODO: Make NOT NULL after entity update
    finalized_block         BIGINT,
    finalized_tx            BYTEA,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT chk_scan_level CHECK (level >= 1 AND level <= 5)
);

CREATE INDEX idx_scans_level_time ON scans(level, executed_at DESC);
CREATE INDEX idx_scans_pending ON scans(executed_at ASC) WHERE finalized_at IS NULL;
CREATE INDEX idx_scans_executed_at ON scans(executed_at DESC);
CREATE INDEX idx_scans_block ON scans(executed_block);

COMMENT ON TABLE scans IS 'Trace scan events (regular table - low volume, unique constraint)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEATHS (Hypertable - High volume, append-only)
-- ═══════════════════════════════════════════════════════════════════════════════

-- CRITICAL: This IS a hypertable!
-- Deaths are append-only, time-ordered, high-volume events.
CREATE TABLE deaths (
    id                      UUID DEFAULT gen_random_uuid(),
    scan_id                 UUID,                         -- NULL for culling deaths
    user_address            BYTEA NOT NULL,
    position_id             UUID,
    amount_lost             NUMERIC(78, 0) NOT NULL,
    level                   SMALLINT NOT NULL,
    ghost_streak_at_death   INTEGER,
    block_number            BIGINT,            -- TODO: Make NOT NULL after entity update
    tx_hash                 BYTEA,             -- TODO: Make NOT NULL after entity update
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (created_at, id),
    
    CONSTRAINT chk_death_level CHECK (level >= 1 AND level <= 5),
    CONSTRAINT chk_amount_lost_positive CHECK (amount_lost >= 0)
);

-- Note: We don't use FK to scans because:
-- 1. Deaths may occur before scan is finalized
-- 2. FK across hypertable/regular table has performance implications
-- We maintain referential integrity at application level.

SELECT create_hypertable('deaths', 'created_at',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE);

-- Compression: segment by level for level-based analytics
ALTER TABLE deaths SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'level',
    timescaledb.compress_orderby = 'created_at DESC, user_address'
);

SELECT add_compression_policy('deaths', INTERVAL '3 days',
    if_not_exists => TRUE);

-- Retention: keep 1 year (use continuous aggregates for long-term stats)
SELECT add_retention_policy('deaths', INTERVAL '365 days',
    if_not_exists => TRUE);

CREATE INDEX idx_deaths_user ON deaths(user_address, created_at DESC);
CREATE INDEX idx_deaths_level ON deaths(level, created_at DESC);
CREATE INDEX idx_deaths_scan ON deaths(scan_id) WHERE scan_id IS NOT NULL;
CREATE INDEX idx_deaths_position ON deaths(position_id) WHERE position_id IS NOT NULL;
CREATE INDEX idx_deaths_block ON deaths(block_number);

COMMENT ON TABLE deaths IS 'Death records from scans/culling (hypertable)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- STATISTICS (Regular Tables - Singleton aggregates)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE level_stats (
    level               SMALLINT PRIMARY KEY,
    total_staked        NUMERIC(78, 0) NOT NULL DEFAULT 0,
    alive_count         INTEGER NOT NULL DEFAULT 0,
    total_deaths        INTEGER NOT NULL DEFAULT 0,
    total_extracted     INTEGER NOT NULL DEFAULT 0,
    total_burned        NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_distributed   NUMERIC(78, 0) NOT NULL DEFAULT 0,
    highest_ghost_streak INTEGER NOT NULL DEFAULT 0,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT chk_stats_level CHECK (level >= 0 AND level <= 5)
);

-- Initialize all levels
INSERT INTO level_stats (level) VALUES (0), (1), (2), (3), (4), (5)
ON CONFLICT (level) DO NOTHING;

COMMENT ON TABLE level_stats IS 'Pre-computed statistics per risk level';

CREATE TABLE global_stats (
    id                          INTEGER PRIMARY KEY DEFAULT 1,
    total_value_locked          NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_positions             INTEGER NOT NULL DEFAULT 0,
    total_deaths                INTEGER NOT NULL DEFAULT 0,
    total_burned                NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_emissions_distributed NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_toll_collected        NUMERIC(78, 0) NOT NULL DEFAULT 0,
    total_buyback_burned        NUMERIC(78, 0) NOT NULL DEFAULT 0,
    system_reset_count          INTEGER NOT NULL DEFAULT 0,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT single_row CHECK (id = 1)
);

INSERT INTO global_stats (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE global_stats IS 'Protocol-wide statistics (single row)';

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONTINUOUS AGGREGATES (For Analytics)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Death statistics aggregated by hour and level
CREATE MATERIALIZED VIEW death_stats_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', created_at) AS bucket,
    level,
    COUNT(*) AS death_count,
    SUM(amount_lost) AS total_lost,
    AVG(amount_lost) AS avg_lost,
    MAX(amount_lost) AS max_lost,
    AVG(ghost_streak_at_death) AS avg_streak_at_death
FROM deaths
GROUP BY bucket, level
WITH NO DATA;

SELECT add_continuous_aggregate_policy('death_stats_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

-- Enable compression on continuous aggregate
ALTER MATERIALIZED VIEW death_stats_hourly SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('death_stats_hourly', INTERVAL '7 days',
    if_not_exists => TRUE);

-- Note: COMMENT ON MATERIALIZED VIEW doesn't work on continuous aggregates

-- Position activity aggregated by hour
CREATE MATERIALIZED VIEW position_activity_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', timestamp) AS bucket,
    action,
    COUNT(*) AS event_count,
    SUM(amount_change) AS total_amount_change,
    COUNT(DISTINCT user_address) AS unique_users
FROM position_history
GROUP BY bucket, action
WITH NO DATA;

SELECT add_continuous_aggregate_policy('position_activity_hourly',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

ALTER MATERIALIZED VIEW position_activity_hourly SET (
    timescaledb.compress = true
);

SELECT add_compression_policy('position_activity_hourly', INTERVAL '7 days',
    if_not_exists => TRUE);

-- Note: COMMENT ON MATERIALIZED VIEW doesn't work on continuous aggregates

-- ═══════════════════════════════════════════════════════════════════════════════
-- REORG HANDLING FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_reorg(fork_block BIGINT)
RETURNS void AS $$
BEGIN
    -- Delete from hypertables where block_number > fork_block
    DELETE FROM deaths WHERE block_number > fork_block;
    DELETE FROM position_history WHERE block_number > fork_block;
    DELETE FROM block_history WHERE block_number > fork_block;
    
    -- Delete from regular tables
    DELETE FROM scans WHERE executed_block > fork_block;
    DELETE FROM positions WHERE created_at_block > fork_block;
    
    -- Revert positions modified after fork
    -- Note: This is complex - may need to reconstruct from history
    -- For now, mark as needing re-sync
    UPDATE positions 
    SET updated_at = NOW()
    WHERE updated_at_block > fork_block;
    
    -- Update indexer state
    UPDATE indexer_state 
    SET last_block = fork_block,
        last_block_hash = (
            SELECT block_hash FROM block_history 
            WHERE block_number = fork_block
            LIMIT 1
        ),
        updated_at = NOW()
    WHERE chain_id = 6342;
    
    -- Refresh continuous aggregates for affected time range
    -- (They will be refreshed on next policy run)
    
    RAISE NOTICE 'Reorg handled: rolled back to block %', fork_block;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION handle_reorg IS 'Rollback database state after chain reorganization';

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════════

-- Verify hypertables are created correctly
DO $$
DECLARE
    hypertable_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO hypertable_count
    FROM timescaledb_information.hypertables
    WHERE hypertable_name IN ('block_history', 'position_history', 'deaths');
    
    IF hypertable_count != 3 THEN
        RAISE EXCEPTION 'Expected 3 hypertables, found %', hypertable_count;
    END IF;
    
    RAISE NOTICE 'Schema v2 migration complete: % hypertables created', hypertable_count;
END $$;
