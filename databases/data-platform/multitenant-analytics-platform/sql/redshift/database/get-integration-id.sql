-- Get Zero-ETL integration ID for database creation
-- This script outputs the integration_id that can be used in subsequent commands

\echo 'Getting Zero-ETL integration ID...'

-- Show current integration status
\echo 'Current Zero-ETL integration status:'
SELECT 
    integration_id, 
    source,
    source_database,
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

-- Output just the integration_id for use in scripts
\echo 'Integration ID for database creation:'
\echo '======================================='
SELECT integration_id
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' 
  AND source_database = 'multitenant_analytics';
\echo '======================================='

\echo 'Use this integration_id in the CREATE DATABASE FROM INTEGRATION command'
