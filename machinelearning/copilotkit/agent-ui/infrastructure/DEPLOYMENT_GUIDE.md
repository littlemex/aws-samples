# フロントエンド デプロイメントガイド

このガイドでは、異なるフロントエンドディレクトリを選択してAWSにデプロイする方法を説明します。

## 利用可能なフロントエンド

- **`frontend`** (デフォルト): NextAuth.js + Cognito統合、修正済み認証機能
- **`hostedui`**: Cognito Hosted UI実装

## デプロイ手順

### 1. 環境変数の設定

`.env`ファイルを作成または編集：

```bash
cd /home/coder/aws-samples/machinelearning/copilotkit/agent-ui/infrastructure
cp .env.example .env
```

`.env`ファイル内容：
```env
# デフォルト（frontendディレクトリをデプロイ）
DEPLOY_FRONTEND_DIR=frontend

# または hosteduiディレクトリをデプロイする場合
DEPLOY_FRONTEND_DIR=hostedui
```

### 2. デプロイ実行

```bash
cd /home/coder/aws-samples/machinelearning/copilotkit/agent-ui/infrastructure

# 依存関係のインストール
npm install

# デプロイの実行
npm run deploy

# または直接CDKコマンド
npx cdk deploy --all
```

## 使用例

### frontendディレクトリをデプロイ（デフォルト）

```bash
# .env ファイル
DEPLOY_FRONTEND_DIR=frontend

# または環境変数を直接指定
DEPLOY_FRONTEND_DIR=frontend npx cdk deploy --all
```

### hosteduiディレクトリをデプロイ

```bash
# .env ファイル
DEPLOY_FRONTEND_DIR=hostedui

# または環境変数を直接指定
DEPLOY_FRONTEND_DIR=hostedui npx cdk deploy --all
```

## ディレクトリ要件

デプロイするディレクトリには以下が必要です：

### 必須ファイル
- `package.json` - npm依存関係定義
- `next.config.js` または `next.config.ts` - Next.js設定
- `src/` - アプリケーションソースコード

### Next.js設定要件
`next.config.js`に以下の設定が必要：

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',  // Lambda展開用
  trailingSlash: false,
  images: {
    unoptimized: true,   // Lambda環境用
  },
};

module.exports = nextConfig;
```

## デプロイされるリソース

### AWS リソース
- **Lambda関数**: Next.js Standalone実行環境
- **API Gateway**: HTTP API v2でLambda統合
- **CloudFront**: グローバルCDN配信
- **S3バケット**: 静的アセットストレージ

### 自動設定項目
- Cognito認証情報の自動注入
- CloudFront URLの自動設定
- コールバック URLの自動登録

## 出力値

デプロイ完了後に表示される重要な値：

```
CopilotKitFrontendStack.CloudFrontURL = https://d1ygv8zbqtq0qy.cloudfront.net
CopilotKitFrontendStack.NextAuthCallbackUrl = https://d1ygv8zbqtq0qy.cloudfront.net/api/auth/callback/cognito
CopilotKitFrontendStack.ApiGatewayUrl = https://xxxxxxxx.execute-api.us-east-1.amazonaws.com
```

## 事前チェック

デプロイ前に以下を確認：

1. **Cognitoスタックのデプロイ**: `CopilotKitCognitoStack`が存在すること
2. **Next.js設定**: `output: 'standalone'`が設定されていること
3. **依存関係**: 対象ディレクトリで`npm ci`が正常実行できること

## トラブルシューティング

### よくある問題

1. **ディレクトリが存在しない**
   ```
   Error: ENOENT: no such file or directory
   ```
   - 解決: `DEPLOY_FRONTEND_DIR`の値を確認

2. **Next.js設定不足**
   ```
   Module not found: Can't resolve 'next'
   ```
   - 解決: 対象ディレクトリで`npm install`実行

3. **Standalone設定不足**
   - 解決: `next.config.js`に`output: 'standalone'`追加

---

**重要:** デプロイ後は、新しいCloudFront URLをCognitoクライアントのコールバック URLに追加してください。
