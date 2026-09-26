# Agent Runtime Mastra

TypeScript MastraフレームワークベースのAIエージェントをAmazon Bedrock AgentCore Runtimeにデプロイするための実装です。ローカル開発環境と本番環境の両方に対応し、CopilotKitからのリモートエージェント接続をサポートします。

## アーキテクチャ

### ローカル開発環境
```
Frontend (localhost:3001) → Agent Runtime (localhost:8080) → Bedrock Claude
```

### 本番環境
```
Frontend (Cognito JWT) → AgentCore Runtime → Mastra Agent → Bedrock Claude
                                            ↓
                                        MCP Gateway → Lambda Tools
```

### 主要機能

- **Weather Agent**: 天気情報を提供するAIエージェント（weatherTool統合）
- **AgentCore Runtime互換**: HTTPプロトコル、必須エンドポイント実装
- **JWT対応**: 開発環境（ログのみ）、本番環境（AgentCore Identity検証）
- **リモート接続**: CopilotKitからのHTTP接続対応

## ファイル構成

```
agent-runtime-mastra/
├── src/
│   └── index.ts              # Mastraエージェント実装
├── deploy.py                 # カスタムデプロイスクリプト
├── package.json              # Node.js依存関係
├── tsconfig.json            # TypeScript設定
├── Dockerfile               # マルチステージビルド
├── requirements.txt         # Python依存関係（デプロイ用）
├── .env.example             # 環境変数テンプレート
├── .gitignore              # Git除外設定
└── README.md               # このファイル
```

## 前提条件

### 1. AWS設定
- AWS CLIが設定済み
- Bedrock AgentCore アクセス権限
- ECR リポジトリ作成権限

### 2. 既存リソース
- Cognito User Pool (us-east-1_ffZoNvXkr)
- Cognito App Client (6eq6tm4qeeumto15jbv3pnarg0)
- MCP Gateway (デプロイ済み)

### 3. 開発環境
- Node.js 20+
- Docker (マルチプラットフォームビルド対応)
- Python 3.10+ (デプロイスクリプト用)

## デプロイ手順

### 1. 環境変数設定

```bash
# 必要な環境変数を設定
export AWS_REGION=us-east-1
export COGNITO_USER_POOL_ID=us-east-1_ffZoNvXkr
export COGNITO_CLIENT_ID=6eq6tm4qeeumto15jbv3pnarg0
export MCP_GATEWAY_URL=https://mcp-gateway-dev-elxd7xtd1f.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp
export AGENT_NAME=mastra-customer-support
```

### 2. Python依存関係インストール

```bash
pip install -r requirements.txt
```

### 3. 完全自動デプロイ実行

```bash
# 全ステップを自動実行（OAuth認証付き）
python deploy.py --all

# SigV4認証で実行する場合
python deploy.py --all --no-oauth
```

### 4. 個別ステップ実行（必要に応じて）

```bash
python deploy.py --step1  # Cognito設定確認とJWT Token取得
python deploy.py --step2  # IAM ロール作成/更新  
python deploy.py --step4  # Docker ビルド＆ECRプッシュ＆Agent Runtime作成
python deploy.py --step5  # 設定をSSM/Secrets Managerに保存
python deploy.py --status # 現在の設定状態表示
```

## AgentCore Runtime 要件対応

### 1. 必須エンドポイント
- `POST /invocations`: メインのエージェント処理
- `GET /ping`: ヘルスチェック

### 2. ネットワーク設定
- Host: `0.0.0.0`
- Port: `8080`

### 3. プロトコル
- HTTPプロトコル（Agent Runtime）
- ストリーミング対応（Server-Sent Events）

### 4. 認証
- OAuth (JWT Bearer Token): デフォルト
- SigV4: オプション

## JWT Propagation実装

### フロー
1. フロントエンド: Cognito認証でJWTトークン取得
2. AgentCore Runtime: JWTトークンを検証
3. Mastra Agent: Authorizationヘッダーを取得
4. MCP Gateway: JWTトークンを伝播してツールアクセス

### コード例
```typescript
// JWT認証ヘッダーを取得
const authHeaders = getAuthHeaders(c.req.raw);

// MCP Gatewayリクエストに伝播
const mcpHeaders = {
  'Content-Type': 'application/json',
  ...authHeaders  // JWT認証ヘッダーを伝播
};
```

## テスト

### 1. ローカルテスト
```bash
npm install
npm run dev
```

### 2. ヘルスチェック
```bash
curl http://localhost:8080/ping
```

### 3. エージェントテスト
```bash
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "こんにちは"}'
```

### 4. デバッグ情報取得
```bash
curl http://localhost:8080/debug
```

## トラブルシューティング

### Docker ビルドエラー
```bash
# ビルダー確認
docker buildx ls

# ビルダー再作成
docker buildx create --use

# 手動ビルド
docker buildx build --platform linux/arm64 -t test .
```

### JWT認証エラー
```bash
# トークン確認
python deploy.py --decode-jwt <JWT_TOKEN>

# 認証テスト
python deploy.py --test-auth
```

### Agent Runtime ステータス確認
```bash
python deploy.py --check-status
```

## セキュリティ

### 1. JWT検証
- AgentCore RuntimeでJWT署名検証
- Audience/Issuer検証
- スコープベースアクセス制御

### 2. Docker セキュリティ
- 非rootユーザー実行
- 最小権限の原則
- セキュリティスキャン有効

### 3. IAM権限
- 最小権限ロール
- Bedrock/ECR/CloudWatchアクセス限定

## 統合

### フロントエンド統合
```bash
# frontend-copilotkit/.env.local に追加
AGENTCORE_RUNTIME_ARN=<デプロイ後のARN>
```

### MCP Tools統合
- MCP Gateway経由でツールアクセス
- JWT認証情報の自動伝播
- スコープベースアクセス制御

## 参考資料

- [Mastra Framework](https://mastra.ai/)
- [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock/latest/devguide/agentcore.html)
- [Chapter21 実装サンプル](./samples/mcp_security_book/chapter21/)
- [JWT Propagation実装ガイド](../JWT_PROPAGATION_IMPLEMENTATION.md)
