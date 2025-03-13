# LiteLLM Server

LiteLLMを使用してBedrock上のClaude (Sonnet 3.7, 3.5) およびHaikuモデルを利用するためのサーバーです。エラーが発生した場合は自動的にフォールバックする機能を備えています。

## 環境要件

- Docker
- Python 3.9以上
- AWS認証情報（Bedrockへのアクセス権限必須）
- AWS IAMロール（SageMaker実行用）

### SageMaker実行ロールの設定

1. AWS Management Consoleで IAM > ロール > ロールの作成 を選択

2. 以下の設定でロールを作成：
   ```
   信頼されたエンティティ: AWS service
   ユースケース: SageMaker
   ポリシー: AmazonSageMakerFullAccess
   ロール名: sagemaker_execution_role
   ```

3. 作成したロールに以下のポリシーを追加：
   - AWSCloudFormationFullAccess
   - IAMFullAccess
   - AmazonS3FullAccess

注意: 本番環境では、より制限された適切な権限設定を行ってください。

## セットアップ手順

1. 環境変数の設定

```bash
# .envファイルを作成
cp .env.example .env
# .envファイルを編集して必要な環境変数を設定
# AWS_ACCESS_KEY_ID=your-access-key-id
# AWS_SECRET_ACCESS_KEY=your-secret-access-key
```

2. 設定ファイルの説明

`default_config.yaml`では以下の設定が可能です：

- モデルの優先順位とフォールバック設定
- 各モデルの最大トークン数
- リトライ設定
- レート制限

詳細な設定例は[設定例](#設定例)セクションを参照してください。

3. サービスの起動

```bash
./start
```

4. 動作確認

```bash
# モデル一覧の取得
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"

# 基本的な補完リクエスト
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
-H 'Content-Type: application/json' \
-H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
-d '{
      "model": "bedrock-claude-3-5",
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
  "model": "bedrock-claude-sonnet-3-5",
  "messages": [
    {
      "role": "user",
      "content": "ping"
    }
  ],
  "mock_testing_fallbacks": true
}'
```

5. SageMaker エンドポイントの構築

Llama 3.3 Swallowモデルを使用するためのSageMakerエンドポイントを構築します。
`scripts/deploy_llama.py`スクリプトを使用してデプロイを行います：

```bash
# 必要なパッケージのインストール
pip install sagemaker boto3

# 実行権限の付与
chmod +x scripts/deploy_llama.py

# エンドポイントのデプロイ（基本設定）
./scripts/deploy_llama.py --endpoint-name llama-swallow

# カスタム設定でのデプロイ
./scripts/deploy_llama.py \
  --endpoint-name llama-swallow \
  --instance-type ml.g5.2xlarge \
  --num-instances 1 \
  --num-gpus 1 \
  --timeout 300 \
  --test \
  --region us-east-1
```

利用可能なオプション：
- `--endpoint-name`: エンドポイント名（必須）
- `--instance-type`: インスタンスタイプ（デフォルト: ml.g5.2xlarge）
- `--num-instances`: デプロイするインスタンス数（デフォルト: 1）
- `--num-gpus`: インスタンスあたりのGPU数（デフォルト: 1）
- `--timeout`: ヘルスチェックタイムアウト（秒）（デフォルト: 300）
- `--test`: デプロイ後にテストリクエストを実行
- `--region`: AWSリージョン（デフォルト: 環境変数または設定ファイルの値）

注意：デプロイには約15-20分かかります。進行状況はログで確認できます。

6. SageMaker設定のカスタマイズ

`sagemaker_config.yaml`にSageMakerエンドポイントのモデルを登録し、以下の手順で動作確認を行います：

1. エンドポイント名の確認
2. configファイルへのモデル設定の追加
3. サーバーの再起動
4. APIを使用した動作確認

## セキュリティ注意事項

**注意**: この環境はローカルでのLiteLLMの動作テスト用です。本番環境での使用は推奨されません。

本番環境で使用する場合は、以下のセキュリティ対策が必須です：

1. アクセス制御
   - 強力なAPIキーの使用（最低32文字以上）
   - HTTPS/TLSの設定
   - 4000ポートへのアクセス制限

2. 環境変数とシークレット管理
   - .envファイルの使用を避け、AWS Secrets Managerなどのシークレット管理サービスの使用
   - APIキーの定期的なローテーション（90日ごとを推奨）
   - 本番認証情報の安全な管理

## 設定例

```yaml
# default_config.yaml
model_list:
  - model_name: bedrock-claude-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-sonnet-20240229-v1:0
      max_tokens: 4096
  - model_name: bedrock-claude-3-5
    litellm_params:
      model: bedrock/anthropic.claude-instant-v1
      max_tokens: 2048
  - model_name: bedrock-haiku
    litellm_params:
      model: bedrock/anthropic.claude-3-haiku-20240307-v1:0
      max_tokens: 1024

fallbacks: [
  {
    "model_name": "bedrock-claude-sonnet",
    "fallback_models": ["bedrock-claude-3-5", "bedrock-haiku"]
  }
]
