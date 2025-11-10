# AgentCore Runtime 簡単なエージェント実装

## 概要

Amazon Bedrock AgentCore Runtimeを使用して、簡単なAIエージェントを実装・デプロイしました。このエージェントはスクリプトから呼び出して結果を得ることができます。

## 実装した機能

### エージェント機能
- **計算機能**: 基本的な数学計算（加算、減算、乗算、除算）
- **天気情報**: ダミーの天気情報を返す
- **挨拶機能**: 親切な挨拶と応答

### 技術スタック
- **言語**: Python 3
- **フレームワーク**: Strands Agents
- **モデル**: Amazon Bedrock Claude 3.7 Sonnet (`us.anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **デプロイ**: Amazon Bedrock AgentCore Runtime
- **呼び出し**: boto3を使用したスクリプト

## ファイル構成

```
agent-runtime/
├── runtime_agent.py           # AgentCore Runtime対応エージェント
├── simple_agent.py          # ローカルテスト用エージェント  
├── test_agent_caller.py     # boto3呼び出しテストスクリプト
├── deploy_agentcore.py      # デプロイメントスクリプト
├── requirements.txt         # Python依存関係
├── runtime_info.txt         # デプロイ済みRuntime情報
├── .bedrock_agentcore.yaml  # AgentCore設定ファイル
├── Dockerfile               # 自動生成されたDockerfile
└── README.md               # このファイル
```

## デプロイ済みAgentCore Runtime情報

デプロイ後、`runtime_info.txt`ファイルに以下の情報が保存されます：

- **Agent ARN**: デプロイ時に自動生成
- **Agent ID**: デプロイ時に自動生成
- **Region**: AWS_REGION環境変数またはAWS設定から取得
- **Status**: デプロイ完了時に`READY`

実際の値は`runtime_info.txt`を参照してください。

## 使用方法

### 1. スクリプトからの呼び出し

```bash
python3 test_agent_caller.py <AGENT_ARN> [REGION]
```

例（runtime_info.txtから実際のARNを取得して使用）:
```bash
# runtime_info.txtからAgent ARNを取得
AGENT_ARN=$(grep 'agent_arn:' runtime_info.txt | cut -d' ' -f2)
AWS_REGION=${AWS_REGION:-us-east-1}

python3 test_agent_caller.py $AGENT_ARN $AWS_REGION
```

### 2. boto3を使用したプログラム呼び出し

```python
import boto3
import json
import os

# 環境変数またはruntime_info.txtから取得
region = os.getenv('AWS_REGION', 'us-east-1')
agent_arn = '<YOUR_AGENT_ARN>'  # runtime_info.txtから取得

agentcore_client = boto3.client('bedrock-agentcore', region_name=region)

response = agentcore_client.invoke_agent_runtime(
    agentRuntimeArn=agent_arn,
    qualifier="DEFAULT",
    payload=json.dumps({"prompt": "こんにちは"})
)
```

## テスト結果

統合テストを実行した結果、すべての機能が正常に動作することを確認しました：

✅ **挨拶テスト**: 「こんにちは」→ 適切な挨拶を返答  
✅ **天気情報テスト**: 「今日の天気は？」→ 天気情報を提供  
✅ **計算テスト1**: 「2 + 3」→ 正確な計算結果（5）  
✅ **計算テスト2**: 「10 × 15」→ 正確な計算結果（150）  
✅ **機能説明テスト**: エージェントの機能を詳細に説明

## 監視・ログ

### CloudWatch Logs
```bash
# runtime_info.txtからAgent IDを取得
AGENT_ID=$(grep 'agent_id:' runtime_info.txt | cut -d' ' -f2)
LOG_GROUP="/aws/bedrock-agentcore/runtimes/${AGENT_ID}-DEFAULT"

# ログの確認
aws logs tail $LOG_GROUP \
  --log-stream-name-prefix "$(date +%Y/%m/%d)/[runtime-logs]" --follow

# 過去1時間のログ
aws logs tail $LOG_GROUP \
  --log-stream-name-prefix "$(date +%Y/%m/%d)/[runtime-logs]" --since 1h
```

### GenAI Observability Dashboard
```bash
# 環境変数からリージョンを取得
REGION=${AWS_REGION:-us-east-1}
echo "https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#gen-ai-observability/agent-core"
```

## 次のステップ（今後の拡張）

1. **フロントエンド統合**: CopilotKitとの統合
2. **ストリーミング対応**: リアルタイムレスポンス実装
3. **認証機能**: JWT Propagationによる権限管理
4. **カスタムツール**: より高度な機能の追加
5. **CDK統合**: インフラストラクチャのコード化

## 注意事項

- エージェントはARM64環境で動作するため、ローカルビルドはx86_64環境では実行できません
- CodeBuildを使用してクロスプラットフォームビルドを実行しています
- Bedrock Claude 3.7 Sonnetモデルへのアクセス権限が必要です

## トラブルシューティング

### よくあるエラー
1. **AccessDeniedException**: Bedrock model accessの権限確認
2. **ValidationException**: Agent ARNの形式確認
3. **ResourceNotFoundException**: Agent statusの確認

### デバッグ方法
- CloudWatch Logsでエラーログを確認
- Agent statusをboto3で確認
- X-Rayトレースで実行フローを確認

# 環境変数設定ガイド

## 概要

このプロジェクトでは、機密情報やアカウント固有の設定を環境変数で管理しています。本ドキュメントでは、各環境変数の説明と設定方法を記載します。

## 必須環境変数

### AWS設定

#### AWS_REGION
- **説明**: AWSリージョン
- **デフォルト値**: `us-east-1`
- **設定例**: `export AWS_REGION=us-east-1`
- **使用箇所**: 全スクリプト、Dockerfile

#### BEDROCK_MODEL_ID
- **説明**: 使用するBedrock モデルのID
- **デフォルト値**: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`
- **設定例**: `export BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0`
- **使用箇所**: runtime_agent.py, simple_agent.py, Dockerfile

#### AGENT_NAME
- **説明**: AgentCore Runtimeのエージェント名
- **デフォルト値**: `simple_agent_copilotkit`
- **設定例**: `export AGENT_NAME=my_custom_agent`
- **使用箇所**: deploy_agentcore.py

### Cognito設定（フロントエンド統合時に必要）

#### COGNITO_USER_POOL_ID
- **説明**: Cognito User Pool ID
- **デフォルト値**: なし（必須）
- **取得方法**: CloudFormationスタックの出力から取得
- **設定例**: `export COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX`

#### COGNITO_CLIENT_ID
- **説明**: Cognito Client ID
- **デフォルト値**: なし（必須）
- **取得方法**: CloudFormationスタックの出力から取得
- **設定例**: `export COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXX`

#### COGNITO_ISSUER
- **説明**: Cognito Issuer URL
- **デフォルト値**: なし（必須）
- **取得方法**: CloudFormationスタックの出力から取得
- **設定例**: `export COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX`

## 設定方法

### 方法1: .envファイル使用

```bash
# 1. .env.exampleをコピー
cp .env.example .env

# 2. .envファイルを編集
vim .env

# 3. 内容例
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0
AGENT_NAME=my_agent
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXX
```

### 方法2: 環境変数を直接エクスポート

```bash
export AWS_REGION=us-east-1
export BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0
export AGENT_NAME=my_agent
export COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
export COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXX
```

### 方法3: スクリプト実行時に設定

```bash
AWS_REGION=us-west-2 AGENT_NAME=west_agent python3 deploy_agentcore.py
```

## Cognito情報の取得方法

### CloudFormationスタックから取得

```bash
# User Pool ID取得
export COGNITO_USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name copilotkit-agentcore-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

# Client ID取得
export COGNITO_CLIENT_ID=$(aws cloudformation describe-stacks \
  --stack-name copilotkit-agentcore-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
  --output text)

# Issuer URL取得
export COGNITO_ISSUER=$(aws cloudformation describe-stacks \
  --stack-name copilotkit-agentcore-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`IssuerUrl`].OutputValue' \
  --output text)
```

## Docker ビルド時の設定

Dockerfileでビルド時引数を使用する場合：

```bash
docker build \
  --build-arg AWS_REGION=us-west-2 \
  --build-arg BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0 \
  -t my-agent:latest .
```

または実行時に環境変数を渡す：

```bash
docker run \
  -e AWS_REGION=us-east-1 \
  -e BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0 \
  my-agent:latest
```

## トラブルシューティング

### 環境変数が設定されていない場合

```bash
# 設定済み環境変数を確認
env | grep -E "(AWS_REGION|BEDROCK_MODEL_ID|AGENT_NAME|COGNITO)"

# 特定の環境変数を確認
echo $AWS_REGION
echo $BEDROCK_MODEL_ID
```

### デフォルト値の確認

各スクリプトはデフォルト値を持っているため、環境変数未設定でも動作します：

- **AWS_REGION**: `us-east-1`
- **BEDROCK_MODEL_ID**: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`
- **AGENT_NAME**: `simple_agent_copilotkit`

## セキュリティ注意事項

### ⚠️ 絶対にしてはいけないこと

1. **固定値のハードコード**: コード内に機密情報を直接記述
2. **.envファイルのコミット**: Gitに機密情報を含むファイルをコミット
3. **公開リポジトリでの共有**: 機密情報を含むファイルの公開

### ✅ 推奨事項

1. **.env.exampleの活用**: サンプルファイルのみをコミット
2. **.gitignoreの設定**: 機密情報ファイルを除外
3. **環境ごとの管理**: dev/staging/prod用の設定を分離
4. **Secrets Managerの活用**: 本番環境ではAWS Secrets Managerを検討

## CI/CD環境での設定

### GitHub Actions

```yaml
env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  BEDROCK_MODEL_ID: ${{ secrets.BEDROCK_MODEL_ID }}
  COGNITO_USER_POOL_ID: ${{ secrets.COGNITO_USER_POOL_ID }}
  COGNITO_CLIENT_ID: ${{ secrets.COGNITO_CLIENT_ID }}
```

### AWS CodeBuild

buildspec.ymlで環境変数を設定：

```yaml
env:
  variables:
    AWS_REGION: us-east-1
  parameter-store:
    COGNITO_USER_POOL_ID: /copilotkit/cognito/pool-id
    COGNITO_CLIENT_ID: /copilotkit/cognito/client-id
```

## 環境別設定例

### 開発環境

```bash
# .env.development
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0
AGENT_NAME=dev_agent
```

### 本番環境

```bash
# .env.production
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0
AGENT_NAME=prod_agent
# Cognito情報はSecrets Managerから取得
```

## まとめ

環境変数を適切に設定することで：
- ✅ セキュリティが向上
- ✅ 複数環境での管理が容易
- ✅ コードの再利用性が向上
- ✅ デプロイの柔軟性が向上
