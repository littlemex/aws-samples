-- Check Zero-ETL integration setup requirements
\echo 'Checking Zero-ETL integration setup for Aurora PostgreSQL...'

-- Check existing publications
\echo 'Existing publications:'
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate
FROM pg_publication;

-- Check publication tables if any exist
\echo 'Tables in publications:'
SELECT p.pubname, n.nspname, c.relname
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class c ON pr.prrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
ORDER BY p.pubname, n.nspname, c.relname;

-- Check if rds_replication role exists and current user has it
\echo 'Checking rds_replication role:'
SELECT 
    r.rolname,
    r.rolreplication,
    CASE 
        WHEN pg_has_role(current_user, r.oid, 'member') THEN 'YES'
        ELSE 'NO'
    END as current_user_has_role
FROM pg_roles r 
WHERE r.rolname = 'rds_replication';

-- Check current user's replication privileges
\echo 'Current user replication status:'
SELECT 
    current_user as username,
    usesuper as is_superuser,
    userepl as has_replication_privilege
FROM pg_user 
WHERE usename = current_user;

-- Check tenant tables that should be replicated
\echo 'Tenant tables available for replication:'
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%'
ORDER BY schemaname, tablename;

\echo 'Zero-ETL setup check completed.'
