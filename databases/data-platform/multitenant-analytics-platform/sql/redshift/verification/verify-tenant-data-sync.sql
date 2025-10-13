-- =============================================================================
-- Redshift Serverless - Zero-ETL Tenant Data Synchronization Verification
-- =============================================================================
-- Verifies that tenant data has been properly synchronized from Aurora PostgreSQL to Redshift

\echo 'Starting Zero-ETL tenant data synchronization verification...'

-- Step 1: Check Zero-ETL integration status
\echo 'Zero-ETL Integration Status:'
SELECT 
    integration_id, 
    source, 
    source_database, 
    target_database,
    state, 
    total_tables_replicated, 
    total_tables_failed, 
    current_lag,
    creation_time
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';

-- Step 2: Check available databases
\echo 'Available databases:'
SELECT datname as database_name 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev'
ORDER BY datname;

-- Step 3: Connect to Zero-ETL database
\echo 'Connecting to Zero-ETL database: multitenant_analytics_zeroetl'
\c multitenant_analytics_zeroetl

-- Step 4: Check tenant schemas
\echo 'Tenant schemas in Zero-ETL database:'
SELECT nspname AS schema_name, nspowner
FROM pg_namespace 
WHERE nspname LIKE 'tenant_%' OR nspname = 'public'
ORDER BY nspname;

-- Step 5: Check replicated tables for each tenant
\echo 'Replicated tables per tenant schema:'
SELECT 
    schemaname, 
    tablename, 
    tableowner,
    CASE 
        WHEN schemaname LIKE 'tenant_%' THEN 'TENANT_TABLE'
        ELSE 'OTHER_TABLE'
    END as table_type
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%' OR schemaname = 'public'
ORDER BY schemaname, tablename;

-- Step 6: Verify tenant data counts
\echo 'Tenant data verification - User counts per tenant:'

-- Check tenant_a users
\echo 'Tenant A users:'
SELECT 
    'tenant_a' as tenant,
    COUNT(*) as user_count,
    MIN(created_at) as earliest_user,
    MAX(created_at) as latest_user
FROM tenant_a.users;

-- Check tenant_b users  
\echo 'Tenant B users:'
SELECT 
    'tenant_b' as tenant,
    COUNT(*) as user_count,
    MIN(created_at) as earliest_user,
    MAX(created_at) as latest_user
FROM tenant_b.users;

-- Check tenant_c users
\echo 'Tenant C users:'
SELECT 
    'tenant_c' as tenant,
    COUNT(*) as user_count,
    MIN(created_at) as earliest_user,
    MAX(created_at) as latest_user
FROM tenant_c.users;

-- Step 7: Aggregate summary across all tenants
\echo 'Summary: Total users across all tenants:'
SELECT 
    (SELECT COUNT(*) FROM tenant_a.users) as tenant_a_users,
    (SELECT COUNT(*) FROM tenant_b.users) as tenant_b_users, 
    (SELECT COUNT(*) FROM tenant_c.users) as tenant_c_users,
    (SELECT COUNT(*) FROM tenant_a.users) + 
    (SELECT COUNT(*) FROM tenant_b.users) + 
    (SELECT COUNT(*) FROM tenant_c.users) as total_users;

-- Step 8: Sample data verification from each tenant
\echo 'Sample user data from tenant_a (first 3 users):'
SELECT 
    email, 
    first_name, 
    last_name, 
    account_status, 
    created_at::date as created_date
FROM tenant_a.users 
ORDER BY created_at 
LIMIT 3;

\echo 'Sample user data from tenant_b (first 3 users):'
SELECT 
    email, 
    first_name, 
    last_name, 
    account_status, 
    created_at::date as created_date
FROM tenant_b.users 
ORDER BY created_at 
LIMIT 3;

\echo 'Sample user data from tenant_c (first 3 users):'
SELECT 
    email, 
    first_name, 
    last_name, 
    account_status, 
    created_at::date as created_date
FROM tenant_c.users 
ORDER BY created_at 
LIMIT 3;

-- Step 9: Data freshness check
\echo 'Data freshness verification:'
SELECT 
    'tenant_a' as tenant,
    MAX(created_at) as latest_record_time,
    DATEDIFF(minute, MAX(created_at), GETDATE()) as minutes_since_latest
FROM tenant_a.users
UNION ALL
SELECT 
    'tenant_b' as tenant,
    MAX(created_at) as latest_record_time,
    DATEDIFF(minute, MAX(created_at), GETDATE()) as minutes_since_latest
FROM tenant_b.users
UNION ALL
SELECT 
    'tenant_c' as tenant,
    MAX(created_at) as latest_record_time,
    DATEDIFF(minute, MAX(created_at), GETDATE()) as minutes_since_latest
FROM tenant_c.users
ORDER BY tenant;

-- Step 10: Basic table information (Redshift compatible)
\echo 'Table information:'
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%'
ORDER BY schemaname, tablename;

-- Step 11: Check for any replication issues
\echo 'Checking for any Zero-ETL replication issues:'
SELECT 
    integration_id,
    target_database,
    state,
    total_tables_replicated,
    total_tables_failed,
    CASE 
        WHEN total_tables_failed > 0 THEN 'HAS_FAILURES'
        WHEN state != 'CdcRefreshState' THEN 'NOT_ACTIVE'
        ELSE 'HEALTHY'
    END as health_status,
    current_lag
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';

\echo 'Zero-ETL tenant data synchronization verification completed!'
\echo ''
\echo 'Expected results:'
\echo '- All 3 tenant schemas should exist (tenant_a, tenant_b, tenant_c)'
\echo '- Each tenant should have a users table with data'
\echo '- Total users should match source Aurora database'
\echo '- Integration state should be CdcRefreshState'
\echo '- No failed tables (total_tables_failed = 0)'

-- Return to dev database
\c dev
