-- ============================================================================
-- Heating Design Database Initialization Script
-- ============================================================================
-- This script runs automatically when the PostgreSQL container first starts

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For indexing

-- Create custom types
CREATE TYPE project_status AS ENUM ('draft', 'in_progress', 'completed', 'archived');
CREATE TYPE room_type AS ENUM ('living_room', 'bedroom', 'kitchen', 'bathroom', 'hallway', 'office', 'other');
CREATE TYPE calculation_status AS ENUM ('pending', 'running', 'completed', 'failed');

-- Set timezone
SET timezone = 'UTC';

-- Performance settings
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE heating_design TO heating_admin;

-- Create schema for versioning
CREATE SCHEMA IF NOT EXISTS migrations;

-- Create migration tracking table
CREATE TABLE IF NOT EXISTS migrations.schema_versions (
    version INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    applied_by TEXT DEFAULT CURRENT_USER
);

-- Insert initial version
INSERT INTO migrations.schema_versions (version, description)
VALUES (1, 'Initial database setup')
ON CONFLICT (version) DO NOTHING;

-- Create audit trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Heating Design database initialized successfully';
    RAISE NOTICE 'Database: heating_design';
    RAISE NOTICE 'User: heating_admin';
    RAISE NOTICE 'Timezone: %', current_setting('TIMEZONE');
END $$;
