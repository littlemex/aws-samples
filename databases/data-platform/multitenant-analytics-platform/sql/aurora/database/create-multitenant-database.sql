-- =============================================================================
-- Aurora PostgreSQL - Database Creation
-- =============================================================================
-- Creates the multitenant_analytics database for Aurora PostgreSQL
-- Note: This script should be executed while connected to the 'postgres' database

-- Create the multitenant_analytics database
-- Note: PostgreSQL does not support "IF NOT EXISTS" for CREATE DATABASE
-- Error handling for "database already exists" is implemented at the script execution level
-- DATABASE_OWNER variable is set by the execution script based on environment (local/remote)
CREATE DATABASE multitenant_analytics
    WITH 
    OWNER = :DATABASE_OWNER
    ENCODING = 'UTF8'
    TEMPLATE = template0
    LC_COLLATE = 'en_US.UTF-8' 
    LC_CTYPE = 'en_US.UTF-8'
    CONNECTION LIMIT = -1;

-- Add comment to document the database purpose
COMMENT ON DATABASE multitenant_analytics IS 'Multitenant Analytics Platform - Main database for storing tenant data and analytics';
