-- Phase 4: 簡単なマルチテナント統合View作成
-- 通常のRedshiftデータベースからZero-ETL統合データベースをクロス参照
-- Late binding view with NO SCHEMA BINDING for external Zero-ETL tables

-- analytics スキーマの作成（存在しない場合）
CREATE SCHEMA IF NOT EXISTS analytics;

-- 全テナントユーザーの統合View作成（Late binding view for Zero-ETL external tables）
CREATE OR REPLACE VIEW analytics.all_users_view AS
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
FROM multitenant_analytics_zeroetl.tenant_a.users

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
FROM multitenant_analytics_zeroetl.tenant_b.users

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
FROM multitenant_analytics_zeroetl.tenant_c.users
WITH NO SCHEMA BINDING;

-- View作成の確認
SELECT 'Late binding cross-database View created successfully' as status;
