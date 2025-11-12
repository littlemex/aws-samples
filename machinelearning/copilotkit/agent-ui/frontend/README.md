# Cognito Hosted UI Authentication Test

Amazon Cognito Hosted UIを使用したNextAuth.js認証のテストアプリケーションです。

## 🎯 目的

このアプリは、以下を確認するための最小構成のテストアプリケーションです：

1. ✅ Cognito Hosted UIへのリダイレクト
2. ✅ OAuth認証フロー（Authorization Code Flow + PKCE）
3. ✅ JWT取得（id_token, access_token, refresh_token）
4. ✅ JWTのデコードと内容確認
5. ✅ セッション管理
6. ✅ CloudFrontプロキシ環境での動作

## 📋 前提条件

- Cognitoスタックがデプロイ済み
- テストユーザーが作成済み
- Node.js 20+

## 🚀 起動方法

### 1. 依存関係インストール（初回のみ）

```bash
npm install
```

### 2. 環境変数の自動セットアップ（推奨）

CloudFormationスタックから自動的に環境変数を取得して`.env.local`ファイルを作成するスクリプトを使用します：

```bash
# セットアップスクリプトを実行
./scripts/setup.sh
```

このスクリプトは以下を自動実行します：
- CloudFormationスタック `CopilotKitCognitoStack` から情報を取得
- `NEXTAUTH_SECRET` の安全な生成（OpenSSL使用）
- `.env.local` ファイルの作成

### 3. 開発サーバー起動

```bash
npm run dev
```

ブラウザで http://localhost:3000 にアクセスします。

## 🔧 設定

### 環境変数（`.env.local`）

`.env.local`ファイルは自動生成されます。手動で作成する場合は以下の形式で設定してください：

```env
# Cognito設定
COGNITO_CLIENT_ID=your-client-id
COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/your-pool-id

# NextAuth.js設定
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-key

# AWS設定
AWS_REGION=us-east-1
```

**重要な注意事項：**
- `NEXTAUTH_SECRET` は本番環境では必ず安全なランダム文字列を使用してください
- `.env.local` はGit管理対象外です（`.gitignore`に含まれています）
