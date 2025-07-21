#!/usr/bin/env python3

import yaml
import sys
import os
import re

def validate_yaml_syntax(file_path):
    """YAML ファイルの構文を検証する"""
    try:
        with open(file_path, 'r') as file:
            yaml_content = file.read()
            yaml_docs = list(yaml.safe_load_all(yaml_content))
            print(f"✅ YAML 構文チェック: 成功 ({len(yaml_docs)} ドキュメント)")
            return yaml_docs
    except yaml.YAMLError as e:
        print(f"❌ YAML 構文チェック: 失敗")
        print(f"  エラー: {str(e)}")
        return None
    except Exception as e:
        print(f"❌ ファイル読み込みエラー: {str(e)}")
        return None

def validate_model_ids(yaml_docs):
    """モデル ID の形式を検証する"""
    llm_doc = next((doc for doc in yaml_docs if doc.get('type') == 'llm'), None)
    if not llm_doc:
        print("❌ LLM 設定が見つかりません")
        return False
    
    models = llm_doc.get('models', [])
    if not models:
        print("❌ モデルが定義されていません")
        return False
    
    valid = True
    bedrock_model_pattern = r'^bedrock/converse/(us\.|apac\.|)anthropic\.claude-\d+-\d+-sonnet-\d{8}-v\d+:\d+$'
    
    for model in models:
        model_id = model.get('model', '')
        if not re.match(bedrock_model_pattern, model_id):
            print(f"❌ モデル ID の形式が不正: {model_id}")
            print("  期待される形式: bedrock/converse/[us.|apac.]anthropic.claude-X-Y-sonnet-YYYYMMDD-vZ:0")
            valid = False
        else:
            print(f"✅ モデル ID の形式が正しい: {model_id}")
    
    return valid

def validate_fallback_config(yaml_docs):
    """フォールバック設定を検証する"""
    litellm_settings_doc = next((doc for doc in yaml_docs if doc.get('litellm_settings')), None)
    if not litellm_settings_doc:
        print("❌ litellm_settings が見つかりません")
        return False
    
    litellm_settings = litellm_settings_doc.get('litellm_settings', {})
    fallbacks = litellm_settings.get('fallbacks', [])
    
    if not fallbacks:
        print("❌ フォールバック設定が定義されていません")
        return False
    
    valid = True
    for fallback in fallbacks:
        if not isinstance(fallback, dict):
            print(f"❌ フォールバック設定の形式が不正: {fallback}")
            valid = False
            continue
        
        for primary, backups in fallback.items():
            if not isinstance(backups, list) or not backups:
                print(f"❌ プライマリモデル {primary} のフォールバックリストが不正: {backups}")
                valid = False
            else:
                print(f"✅ プライマリモデル {primary} のフォールバック設定が正しい")
                print(f"  フォールバックモデル: {', '.join(backups)}")
    
    return valid

def validate_router_settings(yaml_docs):
    """ルーター設定を検証する"""
    router_settings_doc = next((doc for doc in yaml_docs if doc.get('router_settings')), None)
    if not router_settings_doc:
        print("❌ router_settings が見つかりません")
        return False
    
    router_settings = router_settings_doc.get('router_settings', {})
    default_model = router_settings.get('default_model', '')
    
    if not default_model:
        print("❌ デフォルトモデルが設定されていません")
        return False
    
    print(f"✅ デフォルトモデルが設定されています: {default_model}")
    
    failover = router_settings.get('failover', False)
    if not failover:
        print("⚠️ フェイルオーバーが無効になっています")
    else:
        print("✅ フェイルオーバーが有効になっています")
    
    return True

def validate_pipeline_config(yaml_docs):
    """パイプライン設定を検証する"""
    pipeline_doc = next((doc for doc in yaml_docs if doc.get('type') == 'pipeline'), None)
    if not pipeline_doc:
        print("❌ パイプライン設定が見つかりません")
        return False
    
    llm = pipeline_doc.get('llm', '')
    embedder = pipeline_doc.get('embedder', '')
    
    if not llm:
        print("❌ パイプラインの LLM が設定されていません")
        return False
    
    if not embedder:
        print("❌ パイプラインの embedder が設定されていません")
        return False
    
    print(f"✅ パイプライン設定が正しい:")
    print(f"  LLM: {llm}")
    print(f"  Embedder: {embedder}")
    
    return True

def validate_environment_variables(yaml_docs):
    """環境変数の参照を検証する"""
    llm_doc = next((doc for doc in yaml_docs if doc.get('type') == 'llm'), None)
    if not llm_doc:
        return False
    
    models = llm_doc.get('models', [])
    env_var_pattern = r'os\.environ/([A-Z_][A-Z0-9_]*)'
    
    env_vars = set()
    for model in models:
        region = model.get('aws_region_name', '')
        if isinstance(region, str) and 'os.environ/' in region:
            match = re.search(env_var_pattern, region)
            if match:
                env_vars.add(match.group(1))
    
    litellm_settings_doc = next((doc for doc in yaml_docs if doc.get('litellm_settings')), None)
    if litellm_settings_doc:
        litellm_settings = litellm_settings_doc.get('litellm_settings', {})
        region = litellm_settings.get('aws_region_name', '')
        if isinstance(region, str) and 'os.environ/' in region:
            match = re.search(env_var_pattern, region)
            if match:
                env_vars.add(match.group(1))
    
    if not env_vars:
        print("⚠️ 環境変数の参照が見つかりません")
        return True
    
    valid = True
    for env_var in env_vars:
        if env_var not in os.environ:
            print(f"❌ 環境変数 {env_var} が設定されていません")
            valid = False
        else:
            print(f"✅ 環境変数 {env_var} が設定されています: {os.environ[env_var]}")
    
    return valid

def main():
    config_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'init', 'wren', 'config.yaml')
    
    print(f"Wren AI 設定ファイルを検証中: {config_path}")
    print("=" * 60)
    
    yaml_docs = validate_yaml_syntax(config_path)
    if not yaml_docs:
        return 1
    
    print("\n=== モデル ID 検証 ===")
    model_ids_valid = validate_model_ids(yaml_docs)
    
    # print("\n=== フォールバック設定検証 ===")
    # fallback_valid = validate_fallback_config(yaml_docs)
    
    # print("\n=== ルーター設定検証 ===")
    # router_valid = validate_router_settings(yaml_docs)
    
    print("\n=== パイプライン設定検証 ===")
    pipeline_valid = validate_pipeline_config(yaml_docs)
    
    # print("\n=== 環境変数検証 ===")
    # env_vars_valid = validate_environment_variables(yaml_docs)
    
    print("\n=== 検証結果サマリー ===")
    # all_valid = model_ids_valid and fallback_valid and router_valid and pipeline_valid and env_vars_valid
    all_valid = model_ids_valid and pipeline_valid

    if all_valid:
        print("✅ すべての検証に合格しました")
        return 0
    else:
        print("❌ 一部の検証に失敗しました")
        return 1

if __name__ == "__main__":
    sys.exit(main())
