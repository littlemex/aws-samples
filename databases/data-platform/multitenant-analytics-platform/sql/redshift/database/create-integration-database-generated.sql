-- Create Zero-ETL integration database template
-- This template will be processed by generate-integration-sql.sh
-- baab0f11-559d-472e-9631-07c61e51bae6 will be replaced with actual integration ID from .env

\echo 'Starting Zero-ETL integration database creation from integration...'

-- Show current integration status before database creation
\echo 'Current Zero-ETL integration status:'
SELECT 
    integration_id, 
    source,
    source_database,
    target_database,
    state, 
    total_tables_replicated, 
    total_tables_failed,
    creation_time,
    CASE 
        WHEN total_tables_failed > 0 THEN 'HAS_FAILURES'
        WHEN state != 'CdcRefreshState' THEN 'NOT_ACTIVE'
        ELSE 'HEALTHY'
    END as health_status
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';

-- Connect to dev database for database creation
\c dev

\echo 'Creating database from Zero-ETL integration...'
\echo 'Using integration ID: baab0f11-559d-472e-9631-07c61e51bae6'

-- Create database from integration with actual integration ID
-- baab0f11-559d-472e-9631-07c61e51bae6 will be replaced by generate-integration-sql.sh
CREATE DATABASE multitenant_analytics_zeroetl 
FROM INTEGRATION 'baab0f11-559d-472e-9631-07c61e51bae6';

\echo 'Database creation completed!'

-- Verify database creation
\echo 'Databases after creation:'
SELECT datname as database_name 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev'
ORDER BY datname;

-- Check updated integration status
\echo 'Updated Zero-ETL integration status:'
SELECT 
    integration_id, 
    source,
    source_database,
    target_database,
    state, 
    total_tables_replicated, 
    total_tables_failed,
    current_lag,
    CASE 
        WHEN total_tables_failed > 0 THEN 'HAS_FAILURES'
        WHEN state != 'CdcRefreshState' THEN 'NOT_ACTIVE'
        ELSE 'HEALTHY'
    END as health_status
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';

-- Connect to the new database to verify it's working
\echo 'Connecting to newly created integration database...'
\c multitenant_analytics_zeroetl

-- Verify tenant schemas exist
\echo 'Tenant schemas in integration database:'
SELECT nspname AS schema_name, nspowner
FROM pg_namespace 
WHERE nspname LIKE 'tenant_%' OR nspname = 'public'
ORDER BY nspname;

-- Verify tables exist
\echo 'Tables in integration database:'
SELECT 
    schemaname, 
    tablename, 
    tableowner
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%'
ORDER BY schemaname, tablename;

\echo 'Zero-ETL integration database creation completed successfully!'
\echo 'Expected result: state should be CdcRefreshState and target_database should show multitenant_analytics_zeroetl'
