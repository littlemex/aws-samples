-- Zero-ETL compatible all users model
-- Uses cross-database references to multitenant_analytics_zeroetl

{{ config(materialized='table', schema='analytics') }}

WITH tenant_users AS (
    SELECT 
        'tenant_a'::varchar(50) as tenant_id,
        user_id,
        email,
        first_name,
        last_name,
        registration_date,
        last_login_date,
        account_status,
        subscription_tier,
        created_at,
        updated_at
    FROM {{ var('zeroetl_database') }}.tenant_a.users
    
    UNION ALL
    
    SELECT 
        'tenant_b'::varchar(50) as tenant_id,
        user_id,
        email,
        first_name,
        last_name,
        registration_date,
        last_login_date,
        account_status,
        subscription_tier,
        created_at,
        updated_at
    FROM {{ var('zeroetl_database') }}.tenant_b.users
    
    UNION ALL
    
    SELECT 
        'tenant_c'::varchar(50) as tenant_id,
        user_id,
        email,
        first_name,
        last_name,
        registration_date,
        last_login_date,
        account_status,
        subscription_tier,
        created_at,
        updated_at
    FROM {{ var('zeroetl_database') }}.tenant_c.users
)

SELECT * FROM tenant_users
ORDER BY tenant_id, user_id
