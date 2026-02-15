{% macro get_tenant_table_ref(table_name) %}
  {# 動的にテナントテーブルの参照を生成するマクロ #}
  
  {% set tenant_schemas = get_tenant_schemas() %}
  {% set tenant_refs = [] %}
  
  {% for tenant_schema in tenant_schemas %}
    {% if target.type == 'postgres' %}
      {# PostgreSQL用（ローカル開発環境） schema.table 形式 #}
      {% set table_ref = tenant_schema ~ '.' ~ table_name %}
    {% elif target.type == 'redshift' %}
      {# Redshift用（本番環境） database.schema.table 形式 #}
      {% set table_ref = target.database ~ '.' ~ tenant_schema ~ '.' ~ table_name %}
    {% else %}
      {# フォールバック #}
      {% set table_ref = tenant_schema ~ '.' ~ table_name %}
    {% endif %}
    
    {% do tenant_refs.append({
      'tenant_schema': tenant_schema,
      'table_ref': table_ref,
      'full_name': tenant_schema ~ '_' ~ table_name
    }) %}
  {% endfor %}
  
  {{ return(tenant_refs) }}
{% endmacro %}

{% macro union_tenant_tables(table_name, select_columns='*', batch_size=50) %}
  {# 全テナントのテーブルをUNIONするマクロ - 1000+テナント対応 #}
  
  {% set tenant_refs = get_tenant_table_ref(table_name) %}
  {% set total_tenants = tenant_refs|length %}
  
  {{ log("Processing " ~ total_tenants ~ " tenants for table: " ~ table_name, info=true) }}
  
  {# 大量テナント用のバッチ処理 #}
  {% set batches = [] %}
  {% for i in range(0, total_tenants, batch_size) %}
    {% set batch_refs = tenant_refs[i:i+batch_size] %}
    {% do batches.append(batch_refs) %}
  {% endfor %}
  
  {% if batches|length > 1 %}
    {# 複数バッチの場合はCTEを使用 #}
    WITH
    {% for batch in batches %}
    batch_{{ loop.index0 }} AS (
      {% for tenant_ref in batch %}
        SELECT 
          '{{ tenant_ref.tenant_schema }}' as tenant_id,
          {{ select_columns }}
        FROM {{ tenant_ref.table_ref }}
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
    {% for tenant_ref in tenant_refs %}
      SELECT 
        '{{ tenant_ref.tenant_schema }}' as tenant_id,
        {{ select_columns }}
      FROM {{ tenant_ref.table_ref }}
      {% if not loop.last %}
      UNION ALL
      {% endif %}
    {% endfor %}
  {% endif %}
  
{% endmacro %}
