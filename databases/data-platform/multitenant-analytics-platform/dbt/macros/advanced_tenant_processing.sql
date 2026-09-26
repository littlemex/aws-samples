{% macro get_filtered_tenant_schemas(tenant_filter_enabled=none) %}
  {# 設定に基づいてフィルタリングされたテナントスキーマを取得 #}
  
  {% if tenant_filter_enabled is none %}
    {% set tenant_filter_enabled = var('tenant_processing', {}).get('enable_tenant_filter', false) %}
  {% endif %}
  
  {% set base_tenant_schemas = get_tenant_schemas() %}
  {% set max_tenant_limit = var('tenant_processing', {}).get('max_tenant_limit', 2000) %}
  
  {# 安全装置：最大テナント数制限 #}
  {% if base_tenant_schemas|length > max_tenant_limit %}
    {{ log("WARNING: Tenant count (" ~ base_tenant_schemas|length ~ ") exceeds limit (" ~ max_tenant_limit ~ "). Processing will be limited.", info=true) }}
    {% set base_tenant_schemas = base_tenant_schemas[:max_tenant_limit] %}
  {% endif %}
  
  {# テナントフィルタリング（開発時用） #}
  {% if tenant_filter_enabled %}
    {% set filtered_tenants = var('tenant_processing', {}).get('filtered_tenants', []) %}
    {% if filtered_tenants|length > 0 %}
      {% set result_schemas = [] %}
      {% for tenant in base_tenant_schemas %}
        {% if tenant in filtered_tenants %}
          {% do result_schemas.append(tenant) %}
        {% endif %}
      {% endfor %}
      {{ log("Tenant filtering enabled. Processing " ~ result_schemas|length ~ " of " ~ base_tenant_schemas|length ~ " tenants", info=true) }}
      {{ return(result_schemas) }}
    {% endif %}
  {% endif %}
  
  {{ return(base_tenant_schemas) }}
{% endmacro %}

{% macro log_tenant_processing_stats(tenant_count, table_name, batch_size=none) %}
  {# テナント処理統計をログ出力 #}
  
  {% set show_stats = var('logging', {}).get('show_performance_stats', true) %}
  {% set show_progress = var('logging', {}).get('show_tenant_progress', true) %}
  
  {% if show_stats or show_progress %}
    {% if batch_size %}
      {% set batch_count = (tenant_count / batch_size)|round(0, 'ceil')|int %}
      {{ log("=== Tenant Processing Stats ===", info=true) }}
      {{ log("Table: " ~ table_name, info=true) }}
      {{ log("Total Tenants: " ~ tenant_count, info=true) }}
      {{ log("Batch Size: " ~ batch_size, info=true) }}
      {{ log("Batch Count: " ~ batch_count, info=true) }}
      {{ log("===============================", info=true) }}
    {% else %}
      {{ log("Processing " ~ tenant_count ~ " tenants for table: " ~ table_name, info=true) }}
    {% endif %}
  {% endif %}
{% endmacro %}

{% macro union_tenant_tables_optimized(table_name, select_columns='*', custom_batch_size=none) %}
  {# 最適化された全テナントテーブルUNIONマクロ #}
  
  {% set tenant_schemas = get_filtered_tenant_schemas() %}
  {% set total_tenants = tenant_schemas|length %}
  
  {% if custom_batch_size %}
    {% set batch_size = custom_batch_size %}
  {% else %}
    {% set batch_size = var('tenant_processing', {}).get('batch_size', 50) %}
  {% endif %}
  
  {# 統計ログ出力 #}
  {{ log_tenant_processing_stats(total_tenants, table_name, batch_size) }}
  
  {# テナントが存在しない場合の処理 #}
  {% if total_tenants == 0 %}
    {{ log("No tenants found. Returning empty result set.", info=true) }}
    SELECT 
      null::varchar(50) as tenant_id,
      {{ select_columns }}
    WHERE 1=0
  {% else %}
    {# 既存のunion_tenant_tablesマクロを呼び出し #}
    {{ union_tenant_tables(table_name, select_columns, batch_size) }}
  {% endif %}
{% endmacro %}

{% macro union_zero_etl_tenant_tables_optimized(table_name, select_columns='*', zeroetl_database=none, custom_batch_size=none) %}
  {# 最適化されたZero-ETL全テナントテーブルUNIONマクロ #}
  
  {% if zeroetl_database is none %}
    {% set zeroetl_database = var('zeroetl_database', 'multitenant_analytics_zeroetl') %}
  {% endif %}
  
  {% if custom_batch_size %}
    {% set batch_size = custom_batch_size %}
  {% else %}
    {% set batch_size = var('tenant_processing', {}).get('batch_size', 50) %}
  {% endif %}
  
  {# フィルタリングされたテナント一覧を取得 #}
  {% set tenant_filter_enabled = var('tenant_processing', {}).get('enable_tenant_filter', false) %}
  
  {% if tenant_filter_enabled %}
    {# フィルタリング有効時：通常のget_tenant_schemasを使用 #}
    {% set tenant_schemas = get_filtered_tenant_schemas() %}
    {{ log("Using filtered tenant list for Zero-ETL processing", info=true) }}
  {% else %}
    {# フィルタリング無効時：Zero-ETL専用の検出を使用 #}
    {% set tenant_schemas = get_zero_etl_tenant_schemas(zeroetl_database) %}
  {% endif %}
  
  {% set total_tenants = tenant_schemas|length %}
  
  {# 統計ログ出力 #}
  {{ log_tenant_processing_stats(total_tenants, table_name, batch_size) }}
  
  {% if total_tenants == 0 %}
    {{ log("No tenant schemas found in Zero-ETL database. Returning empty result set.", info=true) }}
    SELECT 
      null::varchar(50) as tenant_id,
      {{ select_columns }}
    WHERE 1=0
  {% else %}
    {# バッチ処理 #}
    {% set batches = [] %}
    {% for i in range(0, total_tenants, batch_size) %}
      {% set batch_tenants = tenant_schemas[i:i+batch_size] %}
      {% do batches.append(batch_tenants) %}
    {% endfor %}
    
    {% if batches|length > 1 %}
      {# 複数バッチの場合はCTEを使用 #}
      WITH
      {% for batch in batches %}
      batch_{{ loop.index0 }} AS (
        {% for tenant_schema in batch %}
          {% set table_ref = zeroetl_database ~ '.' ~ tenant_schema ~ '.' ~ table_name %}
          
          SELECT 
            '{{ tenant_schema }}'::varchar(50) as tenant_id,
            {{ select_columns }}
          FROM {{ table_ref }}
          
          {% if not loop.last %}
          UNION ALL
          {% endif %}
        {% endfor %}
      ){% if not loop.last %},{% endif %}
      {% endfor %}
      
      {% for batch in batches %}
      SELECT * FROM batch_{{ loop.index0 }}
      {% if not loop.last %}
      UNION ALL
      {% endif %}
      {% endfor %}
    {% else %}
      {# 単一バッチの場合は直接UNION #}
      {% for tenant_schema in tenant_schemas %}
        {% set table_ref = zeroetl_database ~ '.' ~ tenant_schema ~ '.' ~ table_name %}
        
        SELECT 
          '{{ tenant_schema }}'::varchar(50) as tenant_id,
          {{ select_columns }}
        FROM {{ table_ref }}
        
        {% if not loop.last %}
        UNION ALL
        {% endif %}
      {% endfor %}
    {% endif %}
  {% endif %}
{% endmacro %}

{% macro create_incremental_tenant_model(table_name, unique_key='user_id', updated_at_column='updated_at') %}
  {# インクリメンタルモデル作成用マクロ #}
  
  {% set enable_incremental = var('performance', {}).get('enable_incremental', true) %}
  
  {% if enable_incremental and is_incremental() %}
    {# インクリメンタル処理 #}
    {{ log("Running incremental update for " ~ table_name, info=true) }}
    
    {% set max_updated_at_query %}
      select coalesce(max({{ updated_at_column }}), '1900-01-01'::timestamp) as max_updated_at
      from {{ this }}
    {% endset %}
    
    {% if execute %}
      {% set result = run_query(max_updated_at_query) %}
      {% set max_updated_at = result.columns[0].values()[0] %}
      {{ log("Processing records updated after: " ~ max_updated_at, info=true) }}
    {% endif %}
    
    where {{ updated_at_column }} > (
      select coalesce(max({{ updated_at_column }}), '1900-01-01'::timestamp)
      from {{ this }}
    )
  {% else %}
    {# フル処理 #}
    {{ log("Running full refresh for " ~ table_name, info=true) }}
  {% endif %}
{% endmacro %}
