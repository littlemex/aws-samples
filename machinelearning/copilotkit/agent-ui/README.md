# CopilotKit AgentCore with Cognito Authentication

Amazon Bedrock AgentCore RuntimeとCognito認証を統合したCopilotKitプロジェクトです。

## 📋 プロジェクト概要

このプロジェクトは、TypeScript/Mastraベースのエージェントを Amazon Bedrock AgentCore Runtime にデプロイし、Amazon Cognito 認証を統合した CopilotKit (React) フロントエンドから安全にアクセスできるシステムです。

## 🏗️ アーキテクチャ

```
[ユーザー] 
    ↓
[Cognito Hosted UI] ← 認証（JWT発行）
    ↓ (JWT Token)
[Next.js Frontend + CopilotKit]
    ↓ (HTTPS + JWT Bearer Token)
[Amazon Bedrock AgentCore Runtime]
    ↓
[Amazon Bedrock Models]
```

## 🚀 クイックスタート

### 前提条件

- AWS CLI がインストール・設定済み
- AWS アカウントに適切な権限がある
- Node.js 20+ (後のフェーズで必要)
- Docker (後のフェーズで必要)

### ステップ1: Cognito環境のセットアップ

```bash
cd copilotkit

# Cognitoスタックをデプロイ
./scripts/setup-cognito.sh
```

このスクリプトは以下を実行します：
- Cognito User Pool の作成
- User Pool Client の作成（SPA用、Public Client）
- User Pool Domain の作成
- 環境変数ファイルの生成（`agent/.env`, `frontend/.env.local`）

### ステップ2: テストユーザーの作成

```bash
# テストユーザーを作成
./scripts/create-test-user.sh
```

プロンプトに従って：
1. メールアドレスを入力
2. パスワードを入力（要件を満たす必要があります）
3. ユーザーが作成され、`test-user-info.txt` に情報が保存されます

### ステップ3: Cognito Hosted UI でテスト

スクリプト実行後に表示される Hosted UI URL にアクセス：

```
https://copilotkit-agentcore-{ACCOUNT_ID}.auth.{REGION}.amazoncognito.com/login?...
```

作成したテストユーザーでログインできることを確認します。

## 📁 プロジェクト構造

```
copilotkit/
├── README.md                          # このファイル
├── .gitignore                         # Git除外設定
├── cloudformation/
│   ├── cognito.yml                    # Cognito CloudFormationテンプレート
│   └── parameters/                    # パラメータファイル（将来用）
├── scripts/
│   ├── setup-cognito.sh               # Cognitoセットアップスクリプト
│   ├── create-test-user.sh            # テストユーザー作成スクリプト
│   └── cleanup.sh                     # クリーンアップスクリプト
├── agent/                             # バックエンドエージェント（後で作成）
└── frontend/                          # Next.jsフロントエンド（後で作成）
```

## 🔧 生成されるファイル

デプロイ後、以下のファイルが自動生成されます：

### `agent/.env`
```env
COGNITO_USER_POOL_ID=us-east-1_xxxxxxxxx
COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxx
COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
AWS_REGION=us-east-1
```

### `frontend/.env.local`
```env
COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxx
COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
```

### `cognito-setup-summary.txt`
デプロイの詳細情報が記録されます。

## 📝 CloudFormation スタック情報

### Stack Name
`copilotkit-agentcore-cognito`

### 主なリソース

1. **User Pool**: ユーザー認証の基盤
   - Email認証
   - パスワードポリシー設定済み
   - MFA: OFF（開発用）

2. **User Pool Client**: SPA用Public Client
   - GenerateSecret: false
   - OAuth Flow: code + implicit
   - Scopes: openid, email, profile

3. **User Pool Domain**: OAuth エンドポイント
   - Format: `{ProjectName}-{AccountId}.auth.{Region}.amazoncognito.com`

### スタック出力値

- `UserPoolId`: Cognito User Pool ID
- `UserPoolClientId`: Client ID
- `IssuerUrl`: NextAuth.js用のIssuer URL
- `DiscoveryUrl`: AgentCore Runtime用のOIDC Discovery URL
- `HostedUIUrl`: テスト用のHosted UI URL

## 🧪 テスト方法

### 1. Cognito Hosted UI でのテスト

```bash
# Hosted UI URLを取得
aws cloudformation describe-stacks \
  --stack-name copilotkit-agentcore-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`HostedUIUrl`].OutputValue' \
  --output text
```

ブラウザでURLを開き、作成したユーザーでログイン。

### 2. AWS CLIでのユーザー確認

```bash
# ユーザーリストを表示
aws cognito-idp list-users \
  --user-pool-id {USER_POOL_ID}
```

## 🗑️ クリーンアップ

全てのリソースを削除する場合：

```bash
./scripts/cleanup.sh
```

このスクリプトは以下を削除します：
- Cognito User Pool（全ユーザー含む）
- CloudFormationスタック
- ローカルの設定ファイル

## 📚 次のステップ

Cognito環境のセットアップが完了したら：

1. **AgentCore Runtime のデプロイ**
   - Dockerイメージのビルド
   - ECRへのプッシュ
   - AgentCore Runtimeの作成

2. **フロントエンドの実装**
   - Next.js + CopilotKit
   - NextAuth.js統合
   - AgentCore呼び出し

詳細は `/home/coder/aws-samples/machinelearning/copilotkit/PROJECT.md` を参照してください。

## 🔒 セキュリティに関する注意

- **本番環境では**:
  - MFAを有効化
  - より強固なパスワードポリシー
  - カスタムドメインの使用
  - WAFの設定

- **認証情報の管理**:
  - `.env` ファイルは `.gitignore` に含まれています
  - `test-user-info.txt` はテスト後に削除してください
  - 本番環境では Secrets Manager を使用

## 🛠️ トラブルシューティング

### スタックのデプロイに失敗する

```bash
# スタックの状態を確認
aws cloudformation describe-stacks \
  --stack-name copilotkit-agentcore-cognito

# エラーイベントを確認
aws cloudformation describe-stack-events \
  --stack-name copilotkit-agentcore-cognito \
  --max-items 10
```

### User Pool Domainが既に存在する

User Pool Domainはグローバルにユニークである必要があります。`cloudformation/cognito.yml`の`ProjectName`パラメータを変更してください。

### AWS CLIの認証エラー

```bash
# 現在の認証情報を確認
aws sts get-caller-identity

# 必要に応じて再設定
aws configure
```

## 📖 参考資料

- [Amazon Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [Amazon Bedrock AgentCore Documentation](https://docs.aws.amazon.com/bedrock-agentcore/)
- [CopilotKit Documentation](https://docs.copilotkit.ai/)
- [NextAuth.js with Cognito](https://next-auth.js.org/providers/cognito)

## 📄 ライセンス

このプロジェクトはサンプルコードです。

## 🤝 コントリビューション

改善提案やバグ報告は Issue または Pull Request でお願いします。
