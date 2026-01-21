-- Enable TimescaleDB extension
-- This migration enables TimescaleDB for time-series data storage.
-- TimescaleDB provides automatic time-based partitioning for efficient queries.

-- Enable the extension (requires superuser or extension already installed)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Verify installation
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
        RAISE EXCEPTION 'TimescaleDB extension is not installed';
    END IF;
END $$;
