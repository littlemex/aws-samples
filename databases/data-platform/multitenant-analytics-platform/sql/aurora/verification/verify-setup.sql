-- =============================================================================
-- Aurora PostgreSQL - Setup Verification
-- =============================================================================
-- Verifies that the multitenant database setup was successful

-- Show created schemas
SELECT nspname as schemaname 
FROM pg_namespace 
WHERE nspname LIKE 'tenant_%' 
ORDER BY nspname;

-- Show created tables
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname LIKE 'tenant_%' 
ORDER BY schemaname, tablename;

-- Show row counts
SELECT 
    'tenant_a' as tenant,
    COUNT(*) as user_count 
FROM tenant_a.users
UNION ALL
SELECT 
    'tenant_b' as tenant,
    COUNT(*) as user_count 
FROM tenant_b.users  
UNION ALL
SELECT 
    'tenant_c' as tenant,
    COUNT(*) as user_count 
FROM tenant_c.users
ORDER BY tenant;

-- Show sample data from each tenant
(SELECT 'tenant_a' as tenant, email, account_status, subscription_tier 
FROM tenant_a.users 
ORDER BY user_id 
LIMIT 3)
UNION ALL
(SELECT 'tenant_b' as tenant, email, account_status, subscription_tier 
FROM tenant_b.users 
ORDER BY user_id 
LIMIT 3)
UNION ALL
(SELECT 'tenant_c' as tenant, email, account_status, subscription_tier 
FROM tenant_c.users 
ORDER BY user_id 
LIMIT 3)
ORDER BY tenant;

-- Show Zero-ETL ready filter information
SELECT 'Zero-ETL Data Filter Configuration:' as info
UNION ALL
SELECT 'include: multitenant_analytics.tenant_a.users' as info
UNION ALL
SELECT 'include: multitenant_analytics.tenant_b.users' as info
UNION ALL
SELECT 'include: multitenant_analytics.tenant_c.users' as info;
