{% macro get_tenant_schemas() %}
  {# マクロ: 環境に応じて tenant_ で始まるスキーマを動的に取得 #}
  {# 本番(Glue/Redshift): INFORMATION_SCHEMA から取得 #}
  {# ローカル(PostgreSQL): INFORMATION_SCHEMA から取得 #}
  
  {% if target.type == 'postgres' %}
    {# PostgreSQL用のクエリ（ローカル開発環境） #}
    {% set tenant_query %}
      select distinct schema_name 
      from information_schema.schemata 
      where lower(schema_name) like 'tenant_%'
      order by schema_name
    {% endset %}
  {% elif target.type == 'redshift' %}
    {# Redshift用のクエリ（本番・テスト環境） #}
    {% set tenant_query %}
      select distinct schemaname as schema_name
      from pg_namespace_info
      where lower(schemaname) like 'tenant_%'
      order by schemaname
    {% endset %}
  {% else %}
    {# その他のデータベース用フォールバック #}
    {% set tenant_query %}
      select distinct schema_name 
      from information_schema.schemata 
      where lower(schema_name) like 'tenant_%'
      order by schema_name
    {% endset %}
  {% endif %}
  
  {% if execute %}
    {% set results = run_query(tenant_query) %}
    {% if results %}
      {% set tenant_schemas = results.columns[0].values() %}
      {{ return(tenant_schemas) }}
    {% else %}
      {# フォールバック: 実行時にスキーマが見つからない場合のデフォルト値 #}
      {{ return(['tenant_a', 'tenant_b', 'tenant_c']) }}
    {% endif %}
  {% else %}
    {# コンパイル時のデフォルト値 #}
    {{ return(['tenant_a', 'tenant_b', 'tenant_c']) }}
  {% endif %}
{% endmacro %}
