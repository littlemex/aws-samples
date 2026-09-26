-- Verify Zero-ETL Integration Status Template
-- This template will be processed by generate-integration-sql.sh
-- Generated on: 2025-10-19 17:31:03
-- Integration ID: baab0f11-559d-472e-9631-07c61e51bae6

\echo 'Verifying Zero-ETL Integration Status...'
\echo 'Integration ID: baab0f11-559d-472e-9631-07c61e51bae6'
\echo 'Check Date: 2025-10-19'

-- Check integration status in SVV_INTEGRATION
SELECT 
    integration_id,
    integration_name,
    source,
    source_database,
    target_database,
    state,
    total_tables_replicated,
    total_tables_failed,
    creation_time,
    CASE 
        WHEN state = 'CdcRefreshState' AND total_tables_failed = 0 THEN 'HEALTHY'
        WHEN state = 'PendingDbConnectState' THEN 'PENDING_DB_CONNECT'
        WHEN total_tables_failed > 0 THEN 'HAS_FAILURES'
        ELSE 'UNKNOWN'
    END as health_status
FROM SVV_INTEGRATION
WHERE integration_id = 'baab0f11-559d-472e-9631-07c61e51bae6';

-- Check if target database exists
\echo 'Checking target database existence...'
SELECT datname as database_name, 
       datowner,
       encoding,
       datcollate,
       datctype
FROM pg_database 
WHERE datname = 'multitenant_analytics_zeroetl';

-- If database exists, check tenant schemas
\c multitenant_analytics_zeroetl

\echo 'Checking tenant schemas in target database...'
SELECT nspname AS schema_name, 
       nspowner,
       (SELECT rolname FROM pg_roles WHERE oid = nspowner) as owner_name
FROM pg_namespace 
WHERE nspname LIKE 'tenant_%'
ORDER BY nspname;

-- Check table counts per tenant
\echo 'Checking table counts per tenant schema...'
SELECT 
    schemaname,
    COUNT(*) as table_count,
    string_agg(tablename, ', ' ORDER BY tablename) as tables
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%'
GROUP BY schemaname
ORDER BY schemaname;

\echo 'Integration verification completed for: baab0f11-559d-472e-9631-07c61e51bae6'
\echo 'Report generated on: 2025-10-19 17:31:03'
