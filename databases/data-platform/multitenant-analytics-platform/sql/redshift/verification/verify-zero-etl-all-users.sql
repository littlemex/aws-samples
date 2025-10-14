-- Verify Zero-ETL all users table
-- This query checks the analytics_analytics.zero_etl_all_users table created by dbt

SELECT 
    tenant_id,
    user_id,
    email,
    first_name,
    last_name,
    registration_date,
    account_status,
    subscription_tier,
    created_at
FROM analytics_analytics.zero_etl_all_users 
ORDER BY tenant_id, user_id
LIMIT 10;
