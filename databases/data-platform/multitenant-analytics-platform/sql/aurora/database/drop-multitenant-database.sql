-- =============================================================================
-- Aurora PostgreSQL - Database Deletion
-- =============================================================================
-- Safely drops the multitenant_analytics database for Aurora PostgreSQL
-- Note: This script should be executed while connected to the 'postgres' database

-- Display current database connections before deletion
\echo 'Current connections to multitenant_analytics database:'
SELECT pid, usename, application_name, client_addr, state, query_start
FROM pg_stat_activity 
WHERE datname = 'multitenant_analytics';

-- Terminate all existing connections to the database (except current session)
\echo 'Terminating existing connections to multitenant_analytics...'
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'multitenant_analytics' 
  AND pid <> pg_backend_pid();

-- Drop the database if it exists
\echo 'Dropping multitenant_analytics database...'
DROP DATABASE IF EXISTS multitenant_analytics;

-- Verify deletion
\echo 'Verifying database deletion:'
SELECT datname 
FROM pg_database 
WHERE datname = 'multitenant_analytics';

\echo 'Database deletion completed!'
