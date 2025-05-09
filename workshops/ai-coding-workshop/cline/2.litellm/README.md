# LiteLLM Proxy 実装詳細

本ドキュメントは実装詳細を解説するための資料であり、LiteLLM Proxy の概要やワークショップのマニュアルは [manuals](../manuals/README.md) をご確認ください。
Cline with LIteLLM Proxy ワークショップは[こちら](../manuals/workshops/litellm.md)。

## Amazon Bedrock へのアクセス方法

LiteLLM Proxy を介した Amazon Bedrock へのアクセスには、以下の 3 つの方法があります。実行環境や要件に応じて適切な方法を選択してください。

| 実行環境 | AWS アクセス方法 | LiteLLM 設定ファイル | 認証情報 | .env 作成方法 |
|---------|------------|------------|---------|------------|
| Amazon EC2 | AWS IAM ロール（推奨） | iam_role_config.yml | Amazon EC2 インスタンスプロファイル<br>（AWS CloudFormation で自動設定済み） | `cp .env.example .env` |
| Amazon EC2 |  AWS アクセスキー | access_key_config.yml | `~/.aws/credentials` の<br>[cline] プロファイル | 手動で `.env` に AWS アクセスキー情報を設定 |
| ローカル PC |  AWS アクセスキー | access_key_config.yml | `~/.aws/credentials` の<br>[cline] プロファイル | 手動で `.env` に AWS アクセスキー情報を設定 |

## スクリプト

LiteLLM Proxy の起動等を行うスクリプトです。
詳細な使い方はヘルプを確認してください。
スクリプトの実行には必ず `.env` が必要なため、`.env.example` をコピーしてください。

`../scripts/setup_env.sh` は ~/.aws/credentials の設定を確認して .env を設定するスクリプトです。
説明をせずともコードを見て何をしているのか分かる方のみ利用してください。

```bash
# サービスの起動
./manage-litellm.sh start

# サービスの停止
./manage-litellm.sh stop

# サービスの再起動
./manage-litellm.sh restart

# ヘルプの表示
./manage-litellm.sh --help
```

## LiteLLM Proxy 動作確認

```bash
export LITELLM_MASTER_KEY=sk-litellm-test-key
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"
```

## 設定ファイルの切り替え

スクリプトでは `-c` オプションを使用して異なる設定ファイルを指定できます。

```bash
# 例
./manage-litellm.sh -c prompt_caching.yml start
```

## 動作確認

```bash
export LITELLM_MASTER_KEY=sk-litellm-test-key

# モデル一覧の取得
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"

# 基本的な補完リクエスト
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
-H 'Content-Type: application/json' \
-H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
-d '{
      "model": "bedrock-converse-us-claude-3-7-sonnet-v1",
      "messages": [
        {
          "role": "user",
          "content": "what llm are you"
        }
      ]
    }'

# フォールバックのテスト
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
-H 'Content-Type: application/json' \
-H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
-d '{
  "model": "bedrock-converse-us-claude-3-7-sonnet-v1",
  "messages": [
    {
      "role": "user",
      "content": "ping"
    }
  ],
  "mock_testing_fallbacks": true
}'
```