-- Phase 4: 作成したViewの検証
-- analytics.all_users_view の動作確認 (Late binding view for Zero-ETL data)

-- 1. テナント別ユーザー数確認
SELECT 
    tenant_id,
    COUNT(*) as user_count,
    COUNT(DISTINCT email) as unique_emails,
    COUNT(CASE WHEN account_status = 'ACTIVE' THEN 1 END) as active_users,
    COUNT(CASE WHEN subscription_tier = 'premium' THEN 1 END) as premium_users
FROM analytics.all_users_view 
GROUP BY tenant_id 
ORDER BY tenant_id;

-- 2. 全体統計
SELECT 
    COUNT(*) as total_users,
    COUNT(DISTINCT tenant_id) as total_tenants,
    COUNT(DISTINCT email) as unique_emails_across_tenants,
    MIN(registration_date) as earliest_registration,
    MAX(registration_date) as latest_registration
FROM analytics.all_users_view;

-- 3. サンプルデータ表示 (各テナントから1件ずつ)
SELECT 
    tenant_id,
    user_id,
    email,
    first_name,
    last_name,
    account_status,
    subscription_tier,
    registration_date
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY tenant_id ORDER BY user_id) as rn
    FROM analytics.all_users_view
) ranked
WHERE rn = 1
ORDER BY tenant_id;

-- 4. View存在確認
SELECT 
    schemaname,
    viewname,
    'Late binding view definition' as view_type
FROM pg_views 
WHERE schemaname = 'analytics' 
  AND viewname = 'all_users_view';

-- 5. Zero-ETL統合データベースへの直接アクセス確認
SELECT 
    'Zero-ETL Direct Access Test' as test_name,
    COUNT(*) as total_records_in_zeroetl
FROM multitenant_analytics_zeroetl.tenant_a.users 
UNION ALL
SELECT 
    'tenant_b records' as test_name,
    COUNT(*) as total_records_in_zeroetl
FROM multitenant_analytics_zeroetl.tenant_b.users
UNION ALL  
SELECT 
    'tenant_c records' as test_name,
    COUNT(*) as total_records_in_zeroetl
FROM multitenant_analytics_zeroetl.tenant_c.users;
