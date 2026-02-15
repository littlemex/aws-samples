-- 動的に全テナントのユーザーデータを統合
-- sources.yml 不要で完全動的

{{ config(materialized='table') }}

{{ union_tenant_tables('users', 
   'user_id,
    email,
    first_name,
    last_name,
    registration_date,
    last_login_date,
    account_status,
    subscription_tier,
    created_at,
    updated_at'
) }}
