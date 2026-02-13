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
```

このスクリプトは以下を自動実行します：
- SSM Parameter StoreからCognito情報を取得（環境別）
- 必要な環境変数を自動設定
- 開発サーバーを起動

**環境の切り替え：**

- `NODE_ENV`環境変数で環境を指定できます
- `prod` を指定すると、SSMの `/copilotkit-agentcore/prod/` パスから情報を取得
- 指定なしの場合は `/copilotkit-agentcore/dev/` パスから取得
- `CLIENT_SUFFIX`環境変数で直接SSMパスの環境部分を指定することも可能

ブラウザで http://localhost:3000 にアクセスします。

**重要な注意事項：**
- `NEXTAUTH_SECRET` は本番環境では必ず安全なランダム文字列を使用してください