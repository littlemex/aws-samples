

-- Drop existing Zero-ETL integration database
-- This script removes the manually created database to allow proper integration setup

\echo 'Starting Zero-ETL integration database cleanup...'

-- Show current databases before cleanup
\echo 'Current databases:'
SELECT datname as database_name 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev'
ORDER BY datname;

-- Show current integration status
\echo 'Current Zero-ETL integration status:'
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
    END as health_status
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';

-- Connect to dev database to avoid dropping current database
\c dev

\echo 'Dropping existing multitenant_analytics_zeroetl database...'
-- Force drop to terminate any active connections
-- Note: Redshift doesn't support IF EXISTS for DROP DATABASE
DROP DATABASE multitenant_analytics_zeroetl FORCE;

\echo 'Database cleanup completed successfully!'

-- Verify database has been dropped
\echo 'Remaining databases after cleanup:'
SELECT datname as database_name 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev'
ORDER BY datname;
