{{ config(materialized='view') }}

-- Dynamic staging model for ALL tenant users from Aurora zero-ETL replication
-- This model automatically detects and processes ALL tenant schemas using INFORMATION_SCHEMA
-- No manual configuration needed - supports unlimited tenants dynamically

{% set tenant_schemas = get_tenant_schemas() %}

with
{% for tenant_schema in tenant_schemas %}
{{ tenant_schema }}_data as (
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
        '{{ tenant_schema }}' as tenant_id,
        current_timestamp as dbt_loaded_at
    from {{ tenant_schema }}.users
    where email is not null
        and user_id is not null
){% if not loop.last %},{% endif %}
{% endfor %}

select * from {{ tenant_schemas[0] }}_data
{% for tenant_schema in tenant_schemas[1:] %}
union all
select * from {{ tenant_schema }}_data
{% endfor %}
