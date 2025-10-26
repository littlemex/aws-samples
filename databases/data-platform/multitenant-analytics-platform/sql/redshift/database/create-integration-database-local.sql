-- =============================================================================
-- Redshift Serverless - Local Development Database Creation (No Zero-ETL)
-- =============================================================================
-- Creates a local development database without Zero-ETL integration
-- For local testing and development purposes

\echo 'Starting local development database creation...'

-- Step 1: Check current databases
\echo 'Current databases:'
SELECT datname as database_name, datdba, datacl 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev'
ORDER BY datname;

-- Step 2: Create local development database (without Zero-ETL integration)
\echo 'Creating local development database...'
CREATE DATABASE "multitenant_analytics_local";

-- Step 3: Connect to the new database
\echo 'Connecting to local development database...'
\c multitenant_analytics_local

-- Step 4: Create tenant schemas manually for local development
\echo 'Creating tenant schemas for local development...'

CREATE SCHEMA IF NOT EXISTS tenant_a;
CREATE SCHEMA IF NOT EXISTS tenant_b;
CREATE SCHEMA IF NOT EXISTS tenant_c;

-- Step 5: Create sample tables in each tenant schema
\echo 'Creating sample tables in tenant schemas...'

-- Tenant A tables
CREATE TABLE IF NOT EXISTS tenant_a.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    account_status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tenant B tables
CREATE TABLE IF NOT EXISTS tenant_b.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    account_status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tenant C tables
CREATE TABLE IF NOT EXISTS tenant_c.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    account_status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 6: Insert sample data for local development
\echo 'Inserting sample data for local development...'

-- Sample data for tenant_a
INSERT INTO tenant_a.users (email, first_name, last_name, account_status) VALUES
('alice@tenant-a.com', 'Alice', 'Johnson', 'active'),
('bob@tenant-a.com', 'Bob', 'Smith', 'active'),
('charlie@tenant-a.com', 'Charlie', 'Brown', 'inactive')
ON CONFLICT (email) DO NOTHING;

-- Sample data for tenant_b
INSERT INTO tenant_b.users (email, first_name, last_name, account_status) VALUES
('david@tenant-b.com', 'David', 'Wilson', 'active'),
('eve@tenant-b.com', 'Eve', 'Davis', 'active'),
('frank@tenant-b.com', 'Frank', 'Miller', 'active')
ON CONFLICT (email) DO NOTHING;

-- Sample data for tenant_c
INSERT INTO tenant_c.users (email, first_name, last_name, account_status) VALUES
('grace@tenant-c.com', 'Grace', 'Taylor', 'active'),
('henry@tenant-c.com', 'Henry', 'Anderson', 'inactive'),
('iris@tenant-c.com', 'Iris', 'Thomas', 'active')
ON CONFLICT (email) DO NOTHING;

-- Step 7: Verify local database setup
\echo 'Verifying local database setup:'

\echo 'Available schemas:'
SELECT nspname AS schema_name, nspowner
FROM pg_namespace 
WHERE nspname LIKE 'tenant_%' OR nspname = 'public'
ORDER BY nspname;

\echo 'Tables in tenant schemas:'
SELECT 
    schemaname, 
    tablename, 
    tableowner
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%'
ORDER BY schemaname, tablename;

\echo 'Sample data counts:'
SELECT 'tenant_a' as tenant, COUNT(*) as user_count FROM tenant_a.users
UNION ALL
SELECT 'tenant_b' as tenant, COUNT(*) as user_count FROM tenant_b.users
UNION ALL
SELECT 'tenant_c' as tenant, COUNT(*) as user_count FROM tenant_c.users
ORDER BY tenant;

\echo 'Local development database creation completed!'
\echo 'Database name: multitenant_analytics_local'
\echo 'Available tenant schemas: tenant_a, tenant_b, tenant_c'
\echo 'Sample data has been inserted for local development and testing'
\echo ''
\echo 'Next steps for local development:'
\echo '1. Use this database for dbt model development'
\echo '2. Test analytics queries against sample data'
\echo '3. Validate multitenant data processing logic'
