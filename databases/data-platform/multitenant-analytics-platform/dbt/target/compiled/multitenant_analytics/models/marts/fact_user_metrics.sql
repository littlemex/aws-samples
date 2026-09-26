

-- Fact table for user metrics aggregated by tenant and date
-- This model provides daily metrics for cross-tenant analytics and reporting

with daily_user_metrics as (
    select
        tenant_id,
        date_trunc('day', dbt_loaded_at) as metric_date,
        
        -- User counts
        count(*) as total_users,
        count(case when account_status = 'ACTIVE' then 1 end) as active_users,
        count(case when subscription_tier = 'premium' then 1 end) as premium_users,
        count(case when subscription_tier = 'free' then 1 end) as free_users,
        
        -- Activity metrics  
        count(case when last_login_date >= current_date - interval '7' day then 1 end) as active_users_7d,
        count(case when last_login_date >= current_date - interval '30' day then 1 end) as active_users_30d,
        
        -- Registration metrics
        count(case when registration_date = current_date then 1 end) as new_registrations_today,
        count(case when registration_date >= current_date - interval '7' day then 1 end) as new_registrations_7d,
        count(case when registration_date >= current_date - interval '30' day then 1 end) as new_registrations_30d,
        
        -- Tenure segments (PostgreSQL syntax)
        count(case when (current_date - registration_date) <= 30 then 1 end) as users_new_segment,
        count(case when (current_date - registration_date) between 31 and 90 then 1 end) as users_growing_segment,
        count(case when (current_date - registration_date) between 91 and 365 then 1 end) as users_established_segment,
        count(case when (current_date - registration_date) > 365 then 1 end) as users_mature_segment,
        
        -- Average metrics (PostgreSQL syntax)
        avg(current_date - registration_date) as avg_user_tenure_days,
        avg(case when last_login_date is not null then (current_date - last_login_date) end) as avg_days_since_last_login,
        
        current_timestamp as fact_created_at
        
    from "multitenant_analytics"."public"."dim_users"
    group by 
        tenant_id,
        date_trunc('day', dbt_loaded_at)
),

cross_tenant_metrics as (
    select
        'all_tenants' as tenant_id,
        metric_date,
        
        -- Aggregated cross-tenant metrics
        sum(total_users) as total_users,
        sum(active_users) as active_users,
        sum(premium_users) as premium_users,
        sum(free_users) as free_users,
        sum(active_users_7d) as active_users_7d,
        sum(active_users_30d) as active_users_30d,
        sum(new_registrations_today) as new_registrations_today,
        sum(new_registrations_7d) as new_registrations_7d,
        sum(new_registrations_30d) as new_registrations_30d,
        sum(users_new_segment) as users_new_segment,
        sum(users_growing_segment) as users_growing_segment,
        sum(users_established_segment) as users_established_segment,
        sum(users_mature_segment) as users_mature_segment,
        
        -- Weighted averages for cross-tenant metrics
        sum(avg_user_tenure_days * total_users) / sum(total_users) as avg_user_tenure_days,
        sum(avg_days_since_last_login * total_users) / sum(total_users) as avg_days_since_last_login,
        
        current_timestamp as fact_created_at
        
    from daily_user_metrics
    group by metric_date
),

combined_metrics as (
    select * from daily_user_metrics
    
    union all
    
    select * from cross_tenant_metrics
)

select 
    -- Generate surrogate key
    concat(tenant_id, '_', cast(metric_date as text)) as fact_user_metrics_key,
    *
from combined_metrics
order by tenant_id, metric_date desc