# Cognito Hosted UI Authentication Test

Amazon Cognito Hosted UIを使用したNextAuth.js認証のテストアプリケーションです。認証後にCopilotKitを用いたチャット画面に遷移します。

## 🎯 目的

このアプリは、以下を確認するための最小構成のテストアプリケーションです。

1. ✅ Cognito Hosted UIへのリダイレクト
2. ✅ OAuth認証フロー（Authorization Code Flow + PKCE）
3. ✅ JWT取得（id_token, access_token, refresh_token）
4. ✅ JWTのデコードと内容確認
5. ✅ セッション管理
6. ✅ CloudFrontプロキシ環境での動作

## 📋 前提条件

- Cognitoスタックがデプロイ済み
- Node.js 20+

## 🚀 起動方法

### 0. テストユーザー作成

infrastructureディレクトリにてCognitoスタックをデプロイ後に、
`cd ../scripts/ && NODE_ENV=xx create-test-user.sh`でテストユーザーを作成してください。
`test-user-info.txt`にemailとpasswordが保存されます。

### 1. 依存関係インストール（初回のみ）

```bash
npm install
```

### 2. 開発サーバー起動（推奨）

SSM Parameter StoreからCognito情報を動的に取得して開発サーバーを起動するスクリプトを使用します。

```bash
# NODE_ENV=dev で起動（デフォルト）
./scripts/dev.sh

# NODE_ENV=prod で起動
NODE_ENV=prod ./scripts/dev.sh

# ポート番号を変更する場合
PORT=3002 ./scripts/dev.sh
```

このスクリプトは以下を自動実行します。

- SSM Parameter StoreからCognito情報を取得（NODE_ENV で環境を指定）
- 必要な環境変数を自動設定
- 開発サーバーを起動（デフォルトポート: 3001）

**環境の切り替え：**

- `NODE_ENV`環境変数で環境を指定できます
- `prod`を指定するとSSMの `/copilotkit-agentcore/prod/` パスから情報を取得
- 指定なしの場合は `/copilotkit-agentcore/dev/` パスから取得
- `CLIENT_SUFFIX`環境変数で直接SSMパスの環境部分を指定することも可能

ブラウザで http://localhost:3001 にアクセスします。

**重要な注意事項：**

- `NEXTAUTH_SECRET` は本番環境では必ず安全なランダム文字列を使用してください

## アーキテクチャ

```
このフロントエンド
  ├─ NextAuth.js + Cognito認証
  ├─ JWT取得（ID Token + Access Token）
  └─ CopilotKit UI
       ↓ POST /api/copilotkit
       ↓ JWT Bearer Token
[On going] AgentCore Runtime (agent-runtime-3lo)
  └─ AI応答 + MCPツール呼び出し
```