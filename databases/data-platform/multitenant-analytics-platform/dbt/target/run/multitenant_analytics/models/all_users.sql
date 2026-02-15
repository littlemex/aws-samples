
  
    

  create  table "multitenant_analytics"."public"."all_users__dbt_tmp"
  
  
    as
  
  (
    -- 動的に全テナントのユーザーデータを統合
-- sources.yml 不要で完全動的




  
  
  
  
  
  
  
  
  
  
    
    
  
  
  
    
    
      SELECT 
        'tenant_a' as tenant_id,
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
      FROM tenant_a.users
      
      UNION ALL
      
    
      SELECT 
        'tenant_b' as tenant_id,
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
      FROM tenant_b.users
      
      UNION ALL
      
    
      SELECT 
        'tenant_c' as tenant_id,
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
      FROM tenant_c.users
      
    
  
  

  );
  