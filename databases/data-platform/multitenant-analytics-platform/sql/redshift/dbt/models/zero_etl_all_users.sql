-- 動的Zero-ETL全ユーザーモデル - 1000+テナント対応
-- クロスデータベース参照でmultitenant_analytics_zeroetlを使用
-- 完全スケーラブル - テナント数に制限なし

{{ config(materialized='table', schema='analytics') }}

-- テーブル存在確認（オプション - 開発時のデバッグ用）
{%- set missing_tables = validate_tenant_table_exists('users') -%}

-- 動的に全テナントのusersテーブルをUNION
WITH tenant_users AS (
{{ union_zero_etl_tenant_tables('users', 
   'user_id,
    email,
    first_name,
    last_name,
    registration_date,
    last_login_date,
    account_status,
    subscription_tier,
    created_at,
    updated_at',
   batch_size=100
) }}
)

SELECT 
    tenant_id,
    user_id,
    lower(trim(email)) as email,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    registration_date,
    last_login_date,
    upper(trim(account_status)) as account_status,
    lower(trim(subscription_tier)) as subscription_tier,
    created_at,
    updated_at,
    current_timestamp as dbt_loaded_at
FROM tenant_users
WHERE user_id IS NOT NULL
  AND email IS NOT NULL
ORDER BY tenant_id, user_id
