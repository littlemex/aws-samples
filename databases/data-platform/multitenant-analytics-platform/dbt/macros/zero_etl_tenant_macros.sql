{% macro get_zero_etl_tenant_schemas(zeroetl_database=none) %}
  {# Zero-ETL データベースから tenant_ で始まるスキーマを動的に取得 #}
  
  {% if zeroetl_database is none %}
    {% set zeroetl_database = var('zeroetl_database', 'multitenant_analytics_zeroetl') %}
  {% endif %}
  
  {% if target.type == 'redshift' %}
    {# Redshift用のクロスデータベースクエリ #}
    {% set tenant_query %}
      select distinct schemaname as schema_name
      from {{ zeroetl_database }}.information_schema.schemata
      where lower(schemaname) like 'tenant_%'
      order by schemaname
    {% endset %}
  {% else %}
    {# その他のデータベース用フォールバック #}
    {% set tenant_query %}
      select distinct schema_name 
      from {{ zeroetl_database }}.information_schema.schemata 
      where lower(schema_name) like 'tenant_%'
      order by schema_name
    {% endset %}
  {% endif %}
  
  {% if execute %}
    {% set results = run_query(tenant_query) %}
    {% if results and results.rows|length > 0 %}
      {% set tenant_schemas = results.columns[0].values() %}
      {{ log("Found " ~ tenant_schemas|length ~ " tenant schemas in Zero-ETL database", info=true) }}
      {{ return(tenant_schemas) }}
    {% else %}
      {# フォールバック: 実行時にスキーマが見つからない場合 #}
      {{ log("No tenant schemas found, using fallback defaults", info=true) }}
      {{ return(['tenant_a', 'tenant_b', 'tenant_c']) }}
    {% endif %}
  {% else %}
    {# コンパイル時のデフォルト値 #}
    {{ return(['tenant_a', 'tenant_b', 'tenant_c']) }}
  {% endif %}
{% endmacro %}

{% macro union_zero_etl_tenant_tables(table_name, select_columns='*', zeroetl_database=none, batch_size=50) %}
  {# Zero-ETL データベースの全テナントテーブルを動的にUNIONするマクロ #}
  {# batch_size: 大量テナント処理のためのバッチサイズ（デフォルト50） #}
  
  {% if zeroetl_database is none %}
    {% set zeroetl_database = var('zeroetl_database', 'multitenant_analytics_zeroetl') %}
  {% endif %}
  
  {% set tenant_schemas = get_zero_etl_tenant_schemas(zeroetl_database) %}
  {% set total_tenants = tenant_schemas|length %}
  
  {{ log("Processing " ~ total_tenants ~ " tenants for table: " ~ table_name, info=true) }}
  
  {# 大量テナント用のバッチ処理 #}
  {% set batches = [] %}
  {% for i in range(0, total_tenants, batch_size) %}
    {% set batch_tenants = tenant_schemas[i:i+batch_size] %}
    {% do batches.append(batch_tenants) %}
  {% endfor %}
  
  {% for batch in batches %}
    {% if batches|length > 1 %}
      {# バッチ処理時のCTEとして処理 #}
      batch_{{ loop.index0 }} AS (
    {% endif %}
    
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
    
    {% if batches|length > 1 %}
      ){% if not loop.last %},{% endif %}
    {% endif %}
  {% endfor %}
  
  {# バッチが複数ある場合は最終的にUNION #}
  {% if batches|length > 1 %}
    {% for batch in batches %}
    SELECT * FROM batch_{{ loop.index0 }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
  {% endif %}
  
{% endmacro %}

{% macro validate_tenant_table_exists(table_name, zeroetl_database=none) %}
  {# テナントテーブルの存在確認マクロ #}
  
  {% if zeroetl_database is none %}
    {% set zeroetl_database = var('zeroetl_database', 'multitenant_analytics_zeroetl') %}
  {% endif %}
  
  {% set tenant_schemas = get_zero_etl_tenant_schemas(zeroetl_database) %}
  {% set missing_tables = [] %}
  
  {% for tenant_schema in tenant_schemas %}
    {% set check_query %}
      select count(*) as table_count
      from {{ zeroetl_database }}.information_schema.tables
      where lower(table_schema) = lower('{{ tenant_schema }}')
        and lower(table_name) = lower('{{ table_name }}')
    {% endset %}
    
    {% if execute %}
      {% set result = run_query(check_query) %}
      {% if result.columns[0].values()[0] == 0 %}
        {% do missing_tables.append(tenant_schema ~ '.' ~ table_name) %}
      {% endif %}
    {% endif %}
  {% endfor %}
  
  {% if missing_tables|length > 0 %}
    {{ log("Warning: Missing tables detected: " ~ missing_tables|join(', '), info=true) }}
  {% endif %}
  
  {{ return(missing_tables) }}
{% endmacro %}

{% macro get_tenant_table_columns(table_name, zeroetl_database=none, sample_tenant=none) %}
  {# テーブルのカラム情報を動的に取得するマクロ #}
  
  {% if zeroetl_database is none %}
    {% set zeroetl_database = var('zeroetl_database', 'multitenant_analytics_zeroetl') %}
  {% endif %}
  
  {% if sample_tenant is none %}
    {% set tenant_schemas = get_zero_etl_tenant_schemas(zeroetl_database) %}
    {% set sample_tenant = tenant_schemas[0] %}
  {% endif %}
  
  {% set columns_query %}
    select column_name, data_type
    from {{ zeroetl_database }}.information_schema.columns
    where lower(table_schema) = lower('{{ sample_tenant }}')
      and lower(table_name) = lower('{{ table_name }}')
    order by ordinal_position
  {% endset %}
  
  {% if execute %}
    {% set results = run_query(columns_query) %}
    {% if results %}
      {% set columns = [] %}
      {% for row in results.rows %}
        {% do columns.append({
          'name': row[0],
          'type': row[1]
        }) %}
      {% endfor %}
      {{ return(columns) }}
    {% endif %}
  {% endif %}
  
  {{ return([]) }}
{% endmacro %}
