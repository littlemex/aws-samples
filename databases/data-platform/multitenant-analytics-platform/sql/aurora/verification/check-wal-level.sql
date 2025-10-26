-- Check WAL level for Zero-ETL integration
\echo 'Checking Aurora PostgreSQL WAL level for Zero-ETL integration...'

-- Show current wal_level setting
SHOW wal_level;

-- Show replication related parameters
\echo 'Replication parameters:'
SELECT name, setting, unit, context 
FROM pg_settings 
WHERE name IN ('wal_level', 'max_replication_slots', 'max_wal_senders')
ORDER BY name;

-- Check if logical replication is enabled
\echo 'Checking logical replication capability:'
SELECT 
    CASE 
        WHEN setting = 'logical' THEN 'ENABLED - Zero-ETL compatible'
        WHEN setting = 'replica' THEN 'PARTIAL - Only physical replication'
        ELSE 'DISABLED - Zero-ETL not supported'
    END as wal_level_status
FROM pg_settings 
WHERE name = 'wal_level';

\echo 'WAL level check completed.'
