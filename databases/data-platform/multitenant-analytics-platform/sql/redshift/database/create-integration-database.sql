-- =============================================================================
-- Redshift Serverless - Zero-ETL Integration Database Creation (Simplified)
-- =============================================================================
-- Creates database from Zero-ETL integration for analytics
-- Based on AWS Official Documentation

\echo 'Starting Zero-ETL integration database creation...'

-- Step 1: Display available integrations
\echo 'Available Zero-ETL integrations:'
SELECT integration_id, source, source_database, state, target_database, creation_time 
FROM SVV_INTEGRATION;

-- Step 2: Get integration ID for Aurora PostgreSQL
\echo 'Getting Aurora PostgreSQL integration ID:'
SELECT integration_id, source_database 
FROM SVV_INTEGRATION 
WHERE source = 'AuroraPostgreSQL' AND source_database = 'multitenant_analytics'
LIMIT 1;

-- Step 3: Show the CREATE DATABASE command
\echo 'CREATE DATABASE command for Aurora PostgreSQL Zero-ETL:'
SELECT 'CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION ''' || integration_id || ''' DATABASE ''multitenant_analytics'';' as create_db_command
FROM SVV_INTEGRATION 
WHERE source = 'AuroraPostgreSQL' AND source_database = 'multitenant_analytics'
LIMIT 1;

-- Step 4: Get integration ID and create database from Zero-ETL integration
\echo 'Getting integration ID for database creation...'
SELECT integration_id FROM SVV_INTEGRATION 
WHERE source = 'AuroraPostgreSQL' AND source_database = 'multitenant_analytics'
LIMIT 1 \gset

\echo 'Creating database from Zero-ETL integration...'
\echo 'Using integration ID: ' :integration_id

CREATE DATABASE "multitenant_analytics_zeroetl" 
FROM INTEGRATION :'integration_id' 
DATABASE "multitenant_analytics";

-- Step 5: Verify database creation
\echo 'Verifying database creation:'
SELECT datname as database_name, datdba, datacl 
FROM pg_database 
WHERE datname LIKE '%multitenant%' OR datname = 'dev';

-- Step 6: Show integration status
\echo 'Integration status after database creation:'
SELECT integration_id, target_database, source, state, total_tables_replicated, total_tables_failed, current_lag
FROM SVV_INTEGRATION
WHERE source = 'AuroraPostgreSQL' AND source_database = 'multitenant_analytics';

\echo 'Zero-ETL database creation completed!'
\echo 'Database name: multitenant_analytics_zeroetl'
\echo 'Next steps:'
\echo '1. Wait for initial data synchronization to complete'
\echo '2. Connect to the new database: \c multitenant_analytics_zeroetl'
\echo '3. Verify tenant schemas exist: \dn'
\echo '4. Check replicated tables: \dt tenant_a.*'
