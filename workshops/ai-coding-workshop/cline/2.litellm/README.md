# LiteLLM Proxy

LiteLLM を使用して Bedrock 上の Claude (Sonnet 3.7, 3.5) および Haiku モデルを利用するためのサーバーです。エラーが発生した場合は自動的にフォールバックする機能を備えています。

## 環境要件

- Docker
- Python 3.9 以上
- AWS 認証情報（Bedrock へのアクセス権限必須）

## セットアップ手順

1. 環境変数の設定

```bash
# .env ファイルを作成
cp .env.example .env
# .env ファイルを編集して必要な環境変数を設定
# AWS_ACCESS_KEY_ID=your-access-key-id
# AWS_SECRET_ACCESS_KEY=your-secret-access-key
```

2. 設定ファイルの説明

`default_config.yaml` では以下の設定が可能です：

- モデルの優先順位とフォールバック設定
- 各モデルの最大トークン数
- リトライ設定
- レート制限

詳細な設定例は[設定例](#設定例)セクションを参照してください。

3. サービスの起動

```bash
./start.sh
```

4. 動作確認

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

 ## Cline での LiteLLM 設定

作成した LiteLLM Proxy を Cline の API Provider に設定します。これによりエラー時には LiteLLM Proxy を介してフェイルオーバーする構成となります。

API Key: (環境変数 LITELLM_MASTER_KEY で設定した値)

![Cline での LiteLLM 設定](images/cline-litellm.png)
