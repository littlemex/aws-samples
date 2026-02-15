

-- Dimension table combining all tenant users for cross-tenant analytics
-- This model provides a unified view of users across all tenants

with all_users as (
    select * from "multitenant_analytics"."public"."stg_all_tenants__users"
),

enriched_users as (
    select
        -- Primary key
        concat(tenant_id, '_', user_id) as dim_user_key,
        
        -- User attributes
        user_id,
        tenant_id,
        email,
        first_name,
        last_name,
        concat(first_name, ' ', last_name) as full_name,
        
        -- Dates
        registration_date,
        last_login_date,
        
        -- Status and tier
        account_status,
        subscription_tier,
        
        -- Derived attributes
        case 
            when account_status = 'ACTIVE' then 1 
            else 0 
        end as is_active,
        
        case 
            when subscription_tier = 'premium' then 1 
            else 0 
        end as is_premium,
        
        case 
            when last_login_date >= current_date - interval '30' day then 1 
            else 0 
        end as is_active_last_30_days,
        
        case 
            when last_login_date >= current_date - interval '7' day then 1 
            else 0 
        end as is_active_last_7_days,
        
        -- Tenure calculation (PostgreSQL syntax)
        (current_date - registration_date) as days_since_registration,
        
        case 
            when (current_date - registration_date) <= 30 then 'New (0-30 days)'
            when (current_date - registration_date) <= 90 then 'Growing (31-90 days)'
            when (current_date - registration_date) <= 365 then 'Established (91-365 days)'
            else 'Mature (365+ days)'
        end as user_tenure_segment,
        
        -- Timestamps
        created_at,
        updated_at,
        dbt_loaded_at,
        current_timestamp as dim_created_at
    from all_users
)

select * from enriched_users