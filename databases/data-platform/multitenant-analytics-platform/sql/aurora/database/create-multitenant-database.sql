-- =============================================================================
-- Aurora PostgreSQL - Database Creation
-- =============================================================================
-- Creates the multitenant_analytics database for Aurora PostgreSQL
-- Note: This script should be executed while connected to the 'postgres' database

-- Create the multitenant_analytics database if it doesn't exist
CREATE DATABASE multitenant_analytics
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8' 
    LC_CTYPE = 'en_US.UTF-8'
    CONNECTION LIMIT = -1;

-- Add comment to document the database purpose
COMMENT ON DATABASE multitenant_analytics IS 'Multitenant Analytics Platform - Main database for storing tenant data and analytics';
