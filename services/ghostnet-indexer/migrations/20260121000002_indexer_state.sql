-- Indexer state tables for tracking progress and handling reorgs
-- These tables are critical for reliable indexing across restarts.

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXER STATE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tracks the last successfully indexed block
CREATE TABLE IF NOT EXISTS indexer_state (
    block_number    BIGINT PRIMARY KEY,
    block_hash      BYTEA NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for finding latest block quickly
CREATE INDEX IF NOT EXISTS idx_indexer_state_updated 
    ON indexer_state(updated_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCK HASHES (for reorg detection)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Stores recent block hashes for detecting chain reorganizations
-- We keep a sliding window of ~256 blocks
CREATE TABLE IF NOT EXISTS block_hashes (
    block_number    BIGINT PRIMARY KEY,
    block_hash      BYTEA NOT NULL,
    parent_hash     BYTEA NOT NULL,
    timestamp       BIGINT NOT NULL
);

-- Index for parent hash lookups during reorg detection
CREATE INDEX IF NOT EXISTS idx_block_hashes_parent 
    ON block_hashes(parent_hash);

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE indexer_state IS 'Tracks the last successfully indexed block for resume capability';
COMMENT ON TABLE block_hashes IS 'Recent block hashes for chain reorg detection';
COMMENT ON COLUMN block_hashes.parent_hash IS 'Parent block hash for reorg validation';
