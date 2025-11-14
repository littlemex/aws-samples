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

### 2. 開発サーバー起動（推奨）

SSM Parameter StoreからCognito情報を動的に取得して開発サーバーを起動するスクリプトを使用します：

```bash
# dev環境で起動（デフォルト）
./scripts/dev.sh

# prod環境で起動
NODE_ENV=prod ./scripts/dev.sh

# カスタム環境で起動
CLIENT_SUFFIX=staging ./scripts/dev.sh

# ポート番号を変更する場合
PORT=3002 ./scripts/dev.sh
```

このスクリプトは以下を自動実行します：
- SSM Parameter StoreからCognito情報を取得（環境別）
- 必要な環境変数を自動設定
- 開発サーバーを起動（デフォルトポート: 3001）

**環境の切り替え：**
- `NODE_ENV`環境変数で環境を指定できます
- `prod` または `production` を指定すると、SSMの `/copilotkit-agentcore/prod/` パスから情報を取得
- 指定なし、またはその他の値の場合は `/copilotkit-agentcore/dev/` パスから取得
- `CLIENT_SUFFIX`環境変数で直接SSMパスの環境部分を指定することも可能

ブラウザで http://localhost:3001 にアクセスします。

### 3. 手動セットアップ（オプション）

環境変数ファイルを使用する場合は、CloudFormationスタックから情報を取得して`.env.local`ファイルを作成できます：

```bash
# セットアップスクリプトを実行（非推奨 - dev.shの使用を推奨）
./scripts/setup-and-run.sh
```

手動セットアップ後は通常のnpmコマンドで起動：

```bash
npm run dev
```

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
