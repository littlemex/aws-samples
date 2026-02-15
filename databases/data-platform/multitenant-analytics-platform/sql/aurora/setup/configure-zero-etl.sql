-- Configure Aurora PostgreSQL for Zero-ETL integration
\echo 'Configuring Aurora PostgreSQL for Zero-ETL integration...'

-- Grant rds_replication role to postgres user
\echo 'Granting rds_replication role to postgres user...'
GRANT rds_replication TO postgres;

-- Create publication for Zero-ETL integration
\echo 'Creating publication for tenant tables...'
CREATE PUBLICATION zero_etl_publication FOR TABLE 
    tenant_a.users,
    tenant_b.users,
    tenant_c.users;

-- Verify publication creation
\echo 'Verifying publication creation:'
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate
FROM pg_publication
WHERE pubname = 'zero_etl_publication';

-- Show tables in the publication
\echo 'Tables in zero_etl_publication:'
SELECT p.pubname, n.nspname, c.relname
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class c ON pr.prrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE p.pubname = 'zero_etl_publication'
ORDER BY n.nspname, c.relname;

-- Verify rds_replication role assignment
\echo 'Verifying rds_replication role assignment:'
SELECT 
    r.rolname,
    r.rolreplication,
    CASE 
        WHEN pg_has_role('postgres', r.oid, 'member') THEN 'YES'
        ELSE 'NO'
    END as postgres_has_role
FROM pg_roles r 
WHERE r.rolname = 'rds_replication';

-- Check updated replication privileges
\echo 'Updated replication status for postgres user:'
SELECT 
    usename as username,
    usesuper as is_superuser,
    userepl as has_replication_privilege
FROM pg_user 
WHERE usename = 'postgres';

\echo 'Zero-ETL configuration completed!'
\echo 'Next steps:'
\echo '1. Delete existing Zero-ETL integration'
\echo '2. Create new Zero-ETL integration'
\echo '3. Wait for integration to reach CdcRefreshState'
