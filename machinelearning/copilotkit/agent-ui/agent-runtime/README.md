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
