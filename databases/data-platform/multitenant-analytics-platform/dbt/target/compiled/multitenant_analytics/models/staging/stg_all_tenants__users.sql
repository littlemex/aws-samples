

-- Dynamic staging model for ALL tenant users from Aurora zero-ETL replication
-- This model automatically detects and processes ALL tenant schemas using INFORMATION_SCHEMA
-- No manual configuration needed - supports unlimited tenants dynamically



with

tenant_a_data as (
    select
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
        'tenant_a' as tenant_id,
        current_timestamp as dbt_loaded_at
    from tenant_a.users
    where email is not null
        and user_id is not null
),

tenant_b_data as (
    select
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
        'tenant_b' as tenant_id,
        current_timestamp as dbt_loaded_at
    from tenant_b.users
    where email is not null
        and user_id is not null
),

tenant_c_data as (
    select
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
        'tenant_c' as tenant_id,
        current_timestamp as dbt_loaded_at
    from tenant_c.users
    where email is not null
        and user_id is not null
)


select * from tenant_a_data

union all
select * from tenant_b_data

union all
select * from tenant_c_data
