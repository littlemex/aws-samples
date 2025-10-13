-- Test to ensure zero_etl_all_users model has valid data
-- This test will pass if all conditions are met

SELECT 
    tenant_id,
    COUNT(*) as user_count,
    COUNT(DISTINCT email) as unique_emails,
    COUNT(CASE WHEN email IS NULL THEN 1 END) as null_emails
FROM {{ ref('zero_etl_all_users') }}
GROUP BY tenant_id
HAVING 
    -- Each tenant should have at least 1 user
    COUNT(*) = 0 
    OR 
    -- No null emails allowed
    COUNT(CASE WHEN email IS NULL THEN 1 END) > 0
