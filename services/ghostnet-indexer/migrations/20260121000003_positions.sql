-- Positions table for tracking user stakes
-- This is the core entity of the GHOSTNET indexer.

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS positions (
    id                  UUID NOT NULL,
    user_address        BYTEA NOT NULL,              -- 20-byte Ethereum address
    level               SMALLINT NOT NULL,            -- Risk level (0-5)
    amount              NUMERIC NOT NULL,             -- Current staked amount
    reward_debt         NUMERIC NOT NULL DEFAULT 0,   -- For reward calculations
    entry_timestamp     TIMESTAMPTZ NOT NULL,
    last_add_timestamp  TIMESTAMPTZ,                  -- When stake was last added
    ghost_streak        INTEGER NOT NULL DEFAULT 0,   -- Consecutive scan survivals
    is_alive            BOOLEAN NOT NULL DEFAULT TRUE,
    is_extracted        BOOLEAN NOT NULL DEFAULT FALSE,
    exit_reason         VARCHAR(32),                  -- 'Extracted', 'Traced', 'Culled', etc.
    exit_timestamp      TIMESTAMPTZ,
    extracted_amount    NUMERIC,                      -- Amount returned on extraction
    extracted_rewards   NUMERIC,                      -- Rewards received on extraction
    created_at_block    BIGINT NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- TimescaleDB requires partitioning column in primary key
    PRIMARY KEY (id, entry_timestamp),
    
    -- Constraints
    CONSTRAINT chk_level CHECK (level >= 0 AND level <= 5),
    CONSTRAINT chk_amount_non_negative CHECK (amount >= 0),
    CONSTRAINT chk_ghost_streak_non_negative CHECK (ghost_streak >= 0)
);

-- Convert to TimescaleDB hypertable for efficient time-series queries
-- Partitioned by entry_timestamp with 1-day chunks
SELECT create_hypertable('positions', 'entry_timestamp', 
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Fast lookup of active position by user (most common query)
CREATE INDEX IF NOT EXISTS idx_positions_user_active 
    ON positions(user_address) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Query positions by level for scan processing
CREATE INDEX IF NOT EXISTS idx_positions_level_alive 
    ON positions(level, entry_timestamp) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Find oldest positions in a level (for culling)
CREATE INDEX IF NOT EXISTS idx_positions_level_entry 
    ON positions(level, entry_timestamp ASC) 
    WHERE is_alive = TRUE AND is_extracted = FALSE;

-- Lookup by ID (needed since id is not sole primary key anymore)
-- Note: Cannot have UNIQUE on id alone in TimescaleDB hypertables.
-- The (id, entry_timestamp) composite primary key already ensures uniqueness.
-- This index enables fast id lookups across time partitions.
CREATE INDEX IF NOT EXISTS idx_positions_id ON positions(id);

-- Block number for reorg handling
CREATE INDEX IF NOT EXISTS idx_positions_block ON positions(created_at_block);

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITION HISTORY
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS position_history (
    id              UUID NOT NULL,
    position_id     UUID NOT NULL,
    user_address    BYTEA NOT NULL,
    action          VARCHAR(32) NOT NULL,             -- 'Jacked In', 'Stake Added', etc.
    amount_change   NUMERIC NOT NULL,                 -- Delta (positive or negative)
    new_total       NUMERIC NOT NULL,                 -- New amount after action
    block_number    BIGINT NOT NULL,
    timestamp       TIMESTAMPTZ NOT NULL,
    
    -- TimescaleDB requires partitioning column in primary key
    PRIMARY KEY (id, timestamp)
);

-- Convert to hypertable
SELECT create_hypertable('position_history', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Indexes for position history
CREATE INDEX IF NOT EXISTS idx_position_history_position 
    ON position_history(position_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_position_history_user 
    ON position_history(user_address, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_position_history_block 
    ON position_history(block_number);

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE positions IS 'User staking positions in GHOSTNET';
COMMENT ON COLUMN positions.level IS '0=None, 1=Vault, 2=Mainframe, 3=Subnet, 4=Darknet, 5=BlackIce';
COMMENT ON COLUMN positions.ghost_streak IS 'Number of consecutive scan survivals';
COMMENT ON COLUMN positions.reward_debt IS 'Used for reward calculations (MasterChef pattern)';

COMMENT ON TABLE position_history IS 'Audit trail of all position changes';
