#!/usr/bin/env python3
import os
import logging
import json
import sys
import time
import socket
import traceback
from urllib.parse import urlparse
from langfuse import Langfuse
from langfuse.decorators import observe
from langfuse.openai import openai

# ロギングの設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
# httpcore と httpxのロギングレベルを調整（詳細すぎる場合）
logging.getLogger('httpcore').setLevel(logging.INFO)
logging.getLogger('httpx').setLevel(logging.INFO)

logger = logging.getLogger('litellm_langfuse_test')
logger.debug("スクリプト開始: test_litellm_langfuse.py")

# ネットワーク接続チェック用の関数
def check_host_connection(host, port=None):
    """指定されたホストへの接続をチェックする"""
    if not port:
        parsed_url = urlparse(host)
        host = parsed_url.netloc or parsed_url.path
        port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
        
    try:
        # ホスト名解決のチェック
        logger.debug(f"ホスト名 '{host}' の解決を試みています...")
        ip_address = socket.gethostbyname(host)
        logger.debug(f"ホスト名 '{host}' は IP アドレス {ip_address} に解決されました")
        
        # ポート接続のチェック
        logger.debug(f"{host}:{port} への接続を試みています...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((ip_address, port))
        sock.close()
        
        if result == 0:
            logger.debug(f"{host}:{port} への接続に成功しました")
            return True, f"{host}:{port} への接続に成功しました"
        else:
            logger.error(f"{host}:{port} への接続に失敗しました (エラーコード: {result})")
            return False, f"{host}:{port} への接続に失敗しました (エラーコード: {result})"
            
    except socket.gaierror as e:
        logger.error(f"ホスト名 '{host}' の解決に失敗しました: {e}")
        return False, f"ホスト名 '{host}' の解決に失敗しました: {e}"
    except socket.error as e:
        logger.error(f"{host}:{port} への接続中にエラーが発生しました: {e}")
        return False, f"{host}:{port} への接続中にエラーが発生しました: {e}"
    except Exception as e:
        logger.error(f"接続チェック中に予期しないエラーが発生しました: {e}")
        return False, f"接続チェック中に予期しないエラーが発生しました: {e}"

# .env ファイルから環境変数を読み込む
logger.debug(".env ファイルからの環境変数読み込み開始")
from dotenv import load_dotenv
load_dotenv()
logger.debug(".env ファイルからの環境変数読み込み完了")

# 現在の実行環境の情報を記録
logger.debug(f"Python バージョン: {sys.version}")
logger.debug(f"実行ディレクトリ: {os.getcwd()}")
logger.debug(f"スクリプトパス: {__file__}")

# 環境変数の確認（機密情報は表示しない）
env_vars = {
    "LANGFUSE_PUBLIC_KEY": "設定済み" if os.getenv("LANGFUSE_PUBLIC_KEY") else "未設定",
    "LANGFUSE_SECRET_KEY": "設定済み" if os.getenv("LANGFUSE_SECRET_KEY") else "未設定",
    "LITELLM_MASTER_KEY": "設定済み" if os.getenv("LITELLM_MASTER_KEY") else "未設定"
}
logger.debug(f"環境変数の状態: {json.dumps(env_vars, ensure_ascii=False)}")

# ネットワーク診断情報
logger.debug("ネットワーク診断情報:")
try:
    # 自身のホスト名とIPアドレスを取得
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    logger.debug(f"ホスト名: {hostname}")
    logger.debug(f"ローカルIP: {local_ip}")
    
    # DNS解決テスト
    for test_host in ['localhost', 'langfuse-web', 'google.com']:
        try:
            ip = socket.gethostbyname(test_host)
            logger.debug(f"DNS解決テスト: {test_host} -> {ip}")
        except socket.gaierror as e:
            logger.debug(f"DNS解決テスト失敗: {test_host} -> {e}")
except Exception as e:
    logger.debug(f"ネットワーク診断中にエラーが発生: {e}")

# デバッグログを有効化
os.environ['LITELLM_LOG'] = 'DEBUG'
logger.debug("LiteLLM デバッグログを有効化: LITELLM_LOG=DEBUG")

# /etc/hosts ファイルの内容を確認（DNS解決問題のデバッグ用）
try:
    with open('/etc/hosts', 'r') as hosts_file:
        hosts_content = hosts_file.read()
        logger.debug(f"/etc/hosts ファイルの内容:\n{hosts_content}")
except Exception as e:
    logger.debug(f"/etc/hosts ファイルの読み取りに失敗: {e}")

# LiteLLM Proxy URL
PROXY_URL = "http://localhost:4000"
logger.debug(f"LiteLLM Proxy URL: {PROXY_URL}")

# LiteLLM Proxy の接続チェック
logger.debug("LiteLLM Proxy の接続チェック開始")
litellm_host = urlparse(PROXY_URL).netloc.split(':')[0]
litellm_port = int(urlparse(PROXY_URL).netloc.split(':')[1]) if ':' in urlparse(PROXY_URL).netloc else 80
litellm_status, litellm_message = check_host_connection(litellm_host, litellm_port)
logger.debug(f"LiteLLM Proxy 接続状態: {litellm_message}")

# Langfuse ホスト設定
#LANGFUSE_HOST = "http://localhost:3000"  # EC2ホストからの直接アクセス用に固定
LANGFUSE_HOST = "http://localhost:3000/proxy/3000"
logger.debug("EC2ホストから直接アクセスするため、localhostを使用")

# Langfuse の接続チェック
logger.debug("Langfuse の接続チェック開始")
langfuse_host = "localhost"
langfuse_port = 3000
langfuse_status, langfuse_message = check_host_connection(langfuse_host, langfuse_port)
logger.debug(f"Langfuse 接続状態: {langfuse_message}")

# Langfuse クライアントの初期化（リトライロジック付き）
logger.debug("Langfuse クライアントの初期化開始")
max_retries = 3
retry_delay = 2
langfuse = None

for attempt in range(max_retries):
    try:
        logger.debug(f"Langfuse クライアント初期化試行 {attempt + 1}/{max_retries}")
        langfuse = Langfuse(
            public_key=os.getenv("LANGFUSE_PUBLIC_KEY"),
            secret_key=os.getenv("LANGFUSE_SECRET_KEY"),
            host=LANGFUSE_HOST
        )
        logger.debug("Langfuse クライアントの初期化成功")
        break
    except Exception as e:
        logger.warning(f"Langfuse クライアントの初期化エラー (試行 {attempt + 1}/{max_retries}): {e}")
        if attempt == max_retries - 1:
            logger.error("Langfuse クライアントの初期化に失敗しました")
            logger.error(f"詳細なエラー: {traceback.format_exc()}")
            raise
        else:
            logger.debug(f"{retry_delay}秒後に再試行します...")
            time.sleep(retry_delay)
            retry_delay *= 2  # 指数バックオフ

@observe()
def test_bedrock_claude():
    """Bedrockの各種Claudeモデルをテストする関数"""
    logger.debug("test_bedrock_claude 関数開始")
    
    # OpenAI互換APIを使用してLiteLLMプロキシに接続
    logger.debug("OpenAI クライアントの初期化開始")
    api_key = os.getenv("LITELLM_MASTER_KEY", "sk-litellm-test-key")
    logger.debug(f"API キーの状態: {'設定済み' if api_key != 'sk-litellm-test-key' else 'デフォルト値を使用'}")
    
    try:
        client = openai.OpenAI(
            base_url=PROXY_URL,
            api_key=api_key
        )
        logger.debug("OpenAI クライアントの初期化成功")
        
        # 接続テスト
        try:
            logger.debug("LiteLLM API 接続テスト実行")
            models = client.models.list()
            logger.debug(f"LiteLLM API 接続テスト成功: {len(models.data)} モデルが利用可能")
        except Exception as e:
            logger.warning(f"LiteLLM API 接続テスト失敗: {e}")
    except Exception as e:
        logger.error(f"OpenAI クライアントの初期化エラー: {e}")
        logger.error(f"詳細なエラー: {traceback.format_exc()}")
        raise
    
    print("=== Bedrock Claude モデルテスト ===")
    logger.debug("Bedrock Claude モデルテスト開始")
    
    # Bedrock Claude 3.5 Sonnet テスト
    logger.debug("Bedrock Claude 3.5 Sonnet リクエスト準備")
    messages_3_5 = [
        {"role": "system", "content": "あなたは役立つAIアシスタントです。"},
        {"role": "user", "content": "こんにちは、Langfuse へのログ送信テストです。簡潔に挨拶してください。"}
    ]
    logger.debug(f"リクエストメッセージ: {json.dumps(messages_3_5, ensure_ascii=False)}")
    
    try:
        logger.debug("Bedrock Claude 3.5 Sonnet API リクエスト送信開始")
        start_time = time.time()
        claude_sonnet_response = client.chat.completions.create(
            model="bedrock-us-claude-3-5-sonnet-v2",
            name="bedrock-claude-3-5-sonnet",
            messages=messages_3_5
        )
        elapsed_time = time.time() - start_time
        logger.debug(f"Bedrock Claude 3.5 Sonnet API リクエスト完了 (所要時間: {elapsed_time:.2f}秒)")
        
        # レスポンスの詳細をログに記録
        response_data = {
            "model": claude_sonnet_response.model,
            "id": claude_sonnet_response.id,
            "created": claude_sonnet_response.created,
            "choices_count": len(claude_sonnet_response.choices),
            "usage": {
                "prompt_tokens": claude_sonnet_response.usage.prompt_tokens,
                "completion_tokens": claude_sonnet_response.usage.completion_tokens,
                "total_tokens": claude_sonnet_response.usage.total_tokens
            }
        }
        logger.debug(f"Bedrock Claude 3.5 Sonnet レスポンス詳細: {json.dumps(response_data, ensure_ascii=False)}")
        
        print("\n--- Bedrock Claude 3.5 Sonnet レスポンス ---")
        content = claude_sonnet_response.choices[0].message.content
        print(content)
        logger.debug(f"Bedrock Claude 3.5 Sonnet レスポンス内容: {content}")
    except Exception as e:
        logger.error(f"Bedrock Claude 3.5 Sonnet API エラー: {e}")
        raise
    
    logger.debug("test_bedrock_claude 関数完了")
    return "テスト完了"

if __name__ == "__main__":
    logger.debug("メイン処理開始")
    try:
        # トレースの作成（リトライロジック付き）
        logger.debug("Langfuse トレースの作成開始")
        max_trace_retries = 3
        trace = None
        
        for trace_attempt in range(max_trace_retries):
            try:
                logger.debug(f"Langfuse トレース作成試行 {trace_attempt + 1}/{max_trace_retries}")
                trace = langfuse.trace(name="bedrock-claude-test")
                logger.debug(f"Langfuse トレース作成成功: ID={trace.id}")
                break
            except Exception as e:
                logger.warning(f"Langfuse トレース作成エラー (試行 {trace_attempt + 1}/{max_trace_retries}): {e}")
                if trace_attempt == max_trace_retries - 1:
                    logger.error("Langfuse トレースの作成に失敗しました")
                    logger.error(f"詳細なエラー: {traceback.format_exc()}")
                    raise
                time.sleep(2)
        
        # テスト実行
        logger.debug("Bedrock Claude テスト実行開始")
        start_time = time.time()
        result = test_bedrock_claude()
        elapsed_time = time.time() - start_time
        logger.debug(f"Bedrock Claude テスト実行完了 (所要時間: {elapsed_time:.2f}秒)")
        logger.debug(f"テスト結果: {result}")
        
        print("\nテスト完了: LiteLLM から Langfuse へのログ送信")
        if trace and hasattr(trace, 'id'):
            print(f"トレース ID: {trace.id}")
        print("Langfuse UI (http://localhost:3000) で確認してください")
        
        # トレースを成功として更新（リトライロジック付き）
        if trace:
            logger.debug("Langfuse トレースを成功として更新")
            max_update_retries = 3
            
            for update_attempt in range(max_update_retries):
                try:
                    logger.debug(f"Langfuse トレース更新試行 {update_attempt + 1}/{max_update_retries}")
                    trace.update(status="success")
                    logger.debug("Langfuse トレース更新完了")
                    break
                except Exception as e:
                    logger.warning(f"Langfuse トレース更新エラー (試行 {update_attempt + 1}/{max_update_retries}): {e}")
                    if update_attempt == max_update_retries - 1:
                        logger.error("Langfuse トレースの更新に失敗しました")
                        logger.error(f"詳細なエラー: {traceback.format_exc()}")
                    else:
                        time.sleep(2)
        
    except Exception as e:
        logger.error(f"エラーが発生しました: {e}", exc_info=True)
        print(f"エラーが発生しました: {e}")
        if 'trace' in locals() and trace:
            try:
                logger.debug(f"Langfuse トレースをエラーとして更新: {e}")
                trace.update(status="error", error=str(e))
                logger.debug("Langfuse トレースエラー更新完了")
            except Exception as update_error:
                logger.error(f"エラー状態の更新中に追加のエラーが発生: {update_error}")
                logger.error(f"詳細なエラー: {traceback.format_exc()}")
    finally:
        logger.debug("メイン処理終了")
