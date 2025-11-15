# Agent UI Infrastructure

AWS CDKとcdklabs/cdk-nextjsライブラリを使用してNext.jsベースのフロントエンドをAWSにデプロイするためのインフラストラクチャコードです。

## アーキテクチャ概要

**cdklabs/cdk-nextjs NextjsGlobalFunctions**を使用して以下を構築しています。
柔軟にフロントエンドアプリケーションのディレクトリを変更してデプロイすることができます。

- **Amazon Lambda Function URL + IAM Auth**: セキュアなLambda関数アクセス
- **Amazon CloudFront**: グローバル配信ネットワーク
- **Amazon S3**: 静的アセット配信
- **Amazon Cognito User Pool**: 認証管理

## クイックスタート

### 前提条件

- AWS CLI設定済み
- Node.js 20.x以降
- Docker（cdk-nextjsのビルドプロセスで使用）
- すでにCognitoのテストユーザーは作成されている状態

### 1. セットアップ

環境ごとに設定ファイルを`.env.example`からコピーして生成できるようにしています。
Cognito作成時に指定したNODE_ENVを指定するとSSMから自動的にCognito関連の必要な情報を取得してデプロイを実施します。

```bash
# prod環境
NODE_ENV=prod ./scripts/setup.sh
```

### 2. デプロイ実行

デプロイは2段階で行います：

#### Step 1: Cognitoスタックのデプロイ

```bash
# Cognitoスタックをデプロイ（SSM Parameter Storeに保存）
NODE_ENV=production ./scripts/deploy-cognito.sh
```

このスクリプトは以下を実行：
- CognitoStackのデプロイ
- SSM Parameter StoreへのCognito情報保存

#### Step 2: フロントエンドのデプロイ

```bash
# フロントエンドをビルドしてデプロイ
NODE_ENV=production ./scripts/deploy-frontend.sh
```

このスクリプトは以下を実行：
- SSMからCognito情報取得
- フロントエンドディレクトリに`.env.production`を一時生成
- CDKによるNext.jsスタックのデプロイ（内部でビルド実行）
- `.env.production`の自動クリーンアップ
- **CustomResourceによるCognito CallbackURLsの自動更新**

**重要**: 
- 初回デプロイ時は必ず**Cognito → フロントエンド**の順で実行
- フロントエンドのみ更新する場合は`deploy-frontend.sh`のみ実行可能
- Cognito設定変更時は`deploy-cognito.sh`を再実行

**注意**: CustomResourceによりCloudFront URLが自動的にCognitoのCallback URLsに追加されるため、手動での設定更新は不要です。

## 📁 プロジェクト構造

```
infrastructure/
├── bin/
│   └── app.ts                    # CDKアプリのエントリーポイント
├── lib/
│   ├── config.ts                 # アプリケーション設定
│   ├── cognito-stack.ts          # Cognito User Pool Stack
│   └── nextjs-stack.ts           # Next.js Frontend Stack (NEW)
├── scripts/
│   ├── setup.sh                  # 初回セットアップスクリプト
│   ├── deploy.sh                 # デプロイスクリプト
│   ├── destroy.sh                # 環境削除スクリプト
│   ├── update-frontend-env.sh    # フロントエンド環境変数更新
│   └── fix-*.sh                  # トラブルシューティング用スクリプト
├── .env                          # 環境変数ファイル
├── .env.example                  # 環境変数テンプレート
├── cdk.json                      # CDK設定
├── tsconfig.json                 # TypeScript設定
└── package.json                  # Node.js依存関係
```

## 🔄 デプロイフローと依存関係

### スタック間の依存関係

```
CognitoStack (先にデプロイ)
    ↓
    │ - User Pool作成
    │ - Client作成（localhostコールバックURL）
    │ - OAuth設定
    ↓
NextjsStack (後にデプロイ)
    │ - Next.jsビルド（Cognito情報を使用）
    │ - CloudFront + Lambda作成
    ↓
    │ CustomResource自動実行:
    │ - UpdateCognitoCallbacks
    │   → CloudFront URLをCognitoに追加
    │ - UpdateEnvironment（オプション）
    │   → Lambda環境変数更新
    ↓
完了
```

### 依存関係の詳細

#### 1. CognitoStack → NextjsStack
**NextjsStackの依存**:
```typescript
// bin/app.ts
nextjsStack.addDependency(cognitoStack);
```

**理由**:
- Next.jsビルド時に`COGNITO_CLIENT_ID`と`COGNITO_ISSUER`が必要
- これらの値はCognitoStack作成後に確定

#### 2. Next.jsビルドに必要な環境変数

**必須（ビルド時）**:
```bash
COGNITO_CLIENT_ID=xxx        # CognitoStackから取得
COGNITO_ISSUER=https://...   # CognitoStackから取得
NEXTAUTH_SECRET=xxx          # 固定値（セキュアに生成）
```

**不要（実行時に動的設定）**:
```bash
NEXTAUTH_URL  # リクエストヘッダーから自動取得
```

#### 3. CloudFront URL確定後の処理

Next.jsビルド時にはCloudFront URLは存在しないため、CustomResourceで後処理：

**UpdateCognitoCallbacks**:
- CloudFront URL確定後に実行
- Cognitoのコールバック URLにCloudFront URLを追加
- 自動実行（手動操作不要）

**UpdateEnvironment**（オプション）:
- Lambda環境変数をCustomResourceで更新
- Next.js .envファイルで設定済みの場合は不要

### 重要な設計上の注意点

#### ✅ 一貫した依存関係
1. **Cognitoスタックが先**: localhost URLのみで作成
2. **Next.jsビルド**: Cognito情報（CLIENT_ID、ISSUER）を使用
3. **CloudFront作成**: ビルド済みのNext.jsをデプロイ
4. **CustomResource**: CloudFront URLをCognitoに追加

#### ✅ 動的NEXTAUTH_URL
- リクエスト時にホストヘッダーから自動取得
- localhost、ポートフォワーディング、CloudFrontすべてに対応
- ビルド時の静的な値は不要

#### ❌ 避けるべきパターン
- CloudFront URL事前設定への依存
- ビルド時のNEXTAUTH_URL固定値設定
- CognitoStackでのCloudFront URL参照

## 📊 環境変数管理

### .envファイル構成

プロジェクトでは環境ごとに.envファイルを管理します：

```
infrastructure/
├── .env.example          # テンプレート（Git管理、コミット可）
├── .env.production      # 本番環境設定（.gitignore、コミット不可）
├── .env.local           # ローカル開発用（.gitignore、コミット不可）
├── .env.staging         # ステージング環境用（.gitignore、コミット不可）
└── .env                 # フォールバック用（後方互換性のため）
```

**ファイルの役割**:
- **`.env.example`**: テンプレートファイル。必要な環境変数の一覧と説明を含む
- **`.env.{環境名}`**: 各環境の実際の設定（`./scripts/setup.sh --env={環境名}`で自動生成）
- **`.env`**: フォールバック用（後方互換性のため、非推奨）

**環境ファイルの選択ロジック**:
1. `NODE_ENV`環境変数で指定された環境名に対応する`.env.{環境名}`を読み込み
2. 該当ファイルがない場合は`.env`をフォールバックとして使用
3. どちらもない場合は警告を表示

### Infrastructure環境変数 (.env.{環境名})

`./scripts/setup.sh --env={環境名}`を実行すると`.env.example`をベースに`.env.{環境名}`が自動生成されます：

```bash
# NextAuth.js v5 Secret (自動生成)
# v5では AUTH_SECRET を使用します
AUTH_SECRET=xxx

# AWS Settings (自動検出)
AWS_REGION=us-east-1
CDK_DEFAULT_REGION=us-east-1
CDK_DEFAULT_ACCOUNT=123456789012

# Cognito Client Suffix（SSMパラメータのパスに使用）
COGNITO_CLIENT_SUFFIX=copilotkit

# デプロイするフロントエンドディレクトリ
DEPLOY_FRONTEND_DIR=frontend-copilotkit

# 環境識別
ENVIRONMENT=production
DEBUG_MODE=false

# オプション: Cognitoコールバック URLをカスタマイズ
# COGNITO_CALLBACK_URLS=url1,url2,url3
# COGNITO_LOGOUT_URLS=url1,url2,url3
```

**注意**: NextAuth v5では環境変数の命名規則が変更されています：
- `NEXTAUTH_SECRET` → `AUTH_SECRET`
- フロントエンド側では `COGNITO_CLIENT_ID` → `AUTH_COGNITO_ID`, `COGNITO_ISSUER` → `AUTH_COGNITO_ISSUER`
- スクリプトは後方互換性のため、両方の命名をサポートしています

**複数環境のセットアップとデプロイ**:

```bash
# 1. 本番環境用の設定を生成
./scripts/setup.sh --env=production
# COGNITO_CLIENT_SUFFIX: production (デフォルト)
# DEPLOY_FRONTEND_DIR: frontend-copilotkit

# 2. ローカル開発環境用の設定を生成
./scripts/setup.sh --env=local
# COGNITO_CLIENT_SUFFIX: local (デフォルト)
# DEPLOY_FRONTEND_DIR: frontend

# 3. 各環境にデプロイ
NODE_ENV=prod ./scripts/deploy.sh  # 本番環境
NODE_ENV=local ./scripts/deploy.sh       # ローカル開発環境
```

**重要**: `NODE_ENV`環境変数を指定すると、対応する`.env.{環境名}`ファイルが読み込まれます。
- `NODE_ENV=production` → `.env.production`を読み込み
- `NODE_ENV=local` → `.env.local`を読み込み
- 指定なし → デフォルトで`.env.production`を読み込み

**異なるフロントエンドのデプロイ**:

環境変数で設定を上書き可能：

```bash
# frontendをデプロイ（本番環境設定を使用）
NODE_ENV=production DEPLOY_FRONTEND_DIR=frontend ./scripts/deploy.sh

# frontend-copilotkitをデプロイ（ローカル環境設定を使用）
NODE_ENV=local DEPLOY_FRONTEND_DIR=frontend-copilotkit ./scripts/deploy.sh

# カスタム設定でデプロイ
COGNITO_CLIENT_SUFFIX=custom DEPLOY_FRONTEND_DIR=frontend NODE_ENV=production ./scripts/deploy.sh
```

**npm scriptsでのデプロイ**:

```bash
# package.jsonの deploy コマンドを使用
NODE_ENV=production npm run deploy

# または直接CDKコマンドを使用
NODE_ENV=production npm run cdk deploy --all
```

### SSM Parameter Store統合

Cognito設定値はSSM Parameter Storeに自動的に保存されます：

**保存されるパラメータ**:
```
/copilotkit-agentcore/{client-suffix}/cognito/user-pool-id
/copilotkit-agentcore/{client-suffix}/cognito/client-id
/copilotkit-agentcore/{client-suffix}/cognito/issuer-url
/copilotkit-agentcore/{client-suffix}/cognito/domain
```

**メリット**:
- ✅ シンプルなアクセス: `aws ssm get-parameter --name /path/to/param`
- ✅ スタック名非依存: プロジェクト名ベースのパス構造
- ✅ 再利用性: 他のサービスやスクリプトから簡単に参照
- ✅ バージョン管理: パラメータの変更履歴を追跡可能

**使用例**:
```bash
# Cognito Client IDを取得
aws ssm get-parameter \
  --name "/copilotkit-agentcore/copilotkit/cognito/client-id" \
  --query "Parameter.Value" \
  --output text

# フロントエンドの環境変数を自動更新
cd infrastructure/scripts
./update-frontend-env.sh
```

### フロントエンド環境変数（.envファイル不要）

**重要な設計方針**: フロントエンドディレクトリには`.env`ファイルを配置しません。

#### なぜ.envファイルが不要なのか？

1. **設定の一元管理**: `infrastructure/.env.{環境名}`が唯一のマスター
2. **Next.jsの自動読み込み問題の回避**: 複数の`.env.*`ファイルが存在すると、Next.jsが自動的にマージして読み込む
3. **SSM Parameter Storeの活用**: Cognito情報は既にSSMに保存済み

#### デプロイ時の動作

`infrastructure/scripts/deploy-frontend.sh`は以下を実行：
1. `infrastructure/.env.{環境名}`から設定を読み込み
2. SSM Parameter StoreからCognito情報を取得
3. フロントエンドディレクトリに`.env.production`を一時生成
4. CDKが内部でNext.jsをビルド（`.env.production`から環境変数を読み込み）
5. デプロイ完了後、`.env.production`を自動削除（セキュリティのため）

**重要な設計ポイント**:
- CDKの`cdk-nextjs`ライブラリが内部でNext.jsをビルドするため、事前のビルドは不要
- `.env.production`は一時的にのみ存在し、デプロイ後は自動的に削除される
- エラー発生時も`trap`によってクリーンアップが確実に実行される

```bash
# deploy-frontend.shでの.env.production生成（抜粋）
cat > .env.production << EOF
COGNITO_CLIENT_ID=${COGNITO_CLIENT_ID}
COGNITO_ISSUER=${COGNITO_ISSUER}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
AWS_REGION=${CURRENT_REGION}
EOF

# CDKデプロイ（CDKが内部でビルド時に.env.productionを読み込む）
npx cdk deploy CopilotKitNextjsStack

# 自動クリーンアップ（trap EXIT）
rm -f .env.production
```

#### ローカル開発時の動作

ラッパースクリプト`scripts/dev.sh`を使用：

```bash
# デフォルト（CLIENT_SUFFIX=dev、PORT=3000）
cd frontend
./scripts/dev.sh

# frontend-copilotkitの場合（PORT=3001）
cd frontend-copilotkit
./scripts/dev.sh

# 異なるClient Suffixを使用
CLIENT_SUFFIX=production ./scripts/dev.sh
CLIENT_SUFFIX=copilotkit ./scripts/dev.sh

# ポート指定
PORT=3002 ./scripts/dev.sh

# 組み合わせ
CLIENT_SUFFIX=production PORT=3003 ./scripts/dev.sh
```

**重要**: 
- `CLIENT_SUFFIX`のデフォルト値は`dev`です
- ローカル開発用には、`infrastructure`側で`./scripts/setup.sh --env=dev`を実行してCognitoスタックをデプロイしておく必要があります
- デプロイ時の`NODE_ENV`と開発時の`CLIENT_SUFFIX`を合わせることで、同じCognito設定を使用できます

**infrastructure側との対応関係**:
```bash
# 1. infrastructure側でdev環境をセットアップ＆デプロイ
cd infrastructure
./scripts/setup.sh --env=dev        # .env.dev を生成
NODE_ENV=dev ./scripts/deploy.sh    # CLIENT_SUFFIX=dev でデプロイ

# 2. frontend側でローカル開発
cd ../frontend
./scripts/dev.sh                    # デフォルトでCLIENT_SUFFIX=dev を使用

# または、異なる環境のCognitoを使用
CLIENT_SUFFIX=production ./scripts/dev.sh
```

**スクリプトの動作**:
1. SSM Parameter StoreからCognito情報を動的取得
2. 環境変数として設定
3. 開発サーバーを起動

## ⚙️ デプロイされるリソース

### CopilotKitCognitoStack

- **Cognito User Pool**: 新規作成されるユーザープール
- **User Pool Client**: 認証クライアント（Public Client設定）
- **User Pool Domain**: OAuth エンドポイント用ドメイン

### CopilotKitNextjsStack

- **NextjsGlobalFunctions**: cdk-nextjsによるNext.jsアプリケーション
  - Lambda関数（Node.js 20.x runtime）
  - Lambda Function URL（IAM Auth）
  - CloudFront Distribution
  - S3 Bucket（静的アセット用）

## 🔧 手動操作コマンド

### CDK基本コマンド

```bash
cd infrastructure

# TypeScriptビルド
npm run build

# CloudFormationテンプレート生成
npm run synth -- CopilotKitNextjsStack

# デプロイ前の差分確認
npm run diff

# 個別スタックデプロイ
npm run deploy -- CopilotKitCognitoStack
npm run deploy -- CopilotKitNextjsStack

# 全スタック削除
npm run destroy
```

### フロントエンド関連

```bash
cd ../frontend

# 依存関係インストール
npm install

# ローカル開発サーバー起動
npm run dev

# プロダクションビルド
npm run build
```

## 📊 デプロイ後の出力値

デプロイ完了時に以下の値が表示されます：

| 出力名 | 説明 | 用途 |
|--------|------|------|
| `NextjsUrl` | Next.jsアプリケーションURL | ブラウザでアクセスするURL |
| `NextAuthCallbackUrl` | NextAuth用コールバックURL | Cognito設定で使用 |
| `UserPoolId` | Cognito User Pool ID | AWS Console確認用 |
| `UserPoolClientId` | User Pool Client ID | AWS Console確認用 |
| `IssuerUrl` | OIDC Issuer URL | NextAuth.js設定で自動使用 |

## 🐛 トラブルシューティング

### Lambda関数のログ確認

```bash
# CloudWatchでログを確認
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/CopilotKitNextjsStack"
aws logs tail /aws/lambda/[関数名] --follow
```

### Next.jsビルドエラー

```bash
cd frontend
rm -rf .next node_modules
npm install
npm run build
```

### CDK Synthesis警告について

以下の警告は正常な動作です：

```
[Warning] Ignoring Egress rule since 'allowAllOutbound' is set to true
```

これはcdk-nextjsライブラリ内部でLambda関数のセキュリティグループが適切に設定されていることを示しています。

### デプロイエラー

1. **AWS認証エラー**: `aws sts get-caller-identity`で認証状況確認
2. **Docker エラー**: Dockerデーモンが起動していることを確認
3. **権限エラー**: IAMユーザー/ロールにCDK実行権限があることを確認

## 🔒 セキュリティ

### 実装済みセキュリティ機能

- **Lambda Function URL + IAM Auth**: World Accessibleを防止
- **CloudFront HTTPS**: 通信の暗号化
- **Cognito Integration**: セキュアな認証フロー
- **VPC内Lambda**: プライベートネットワーク内実行

### セキュリティ推奨事項

- 本番環境では独自ドメインを設定
- CloudFrontアクセスログの有効化
- VPC Flow Logsの設定
- ECRスキャンの有効化（コンテナ使用時）

## 🚀 本番環境への移行

開発環境から本番環境へ移行する際の推奨変更：

### 1. キャッシュ設定の最適化

現在は開発用にキャッシュが無効化されています。本番環境では：

```typescript
// lib/nextjs-stack.ts で設定可能
// NextjsGlobalFunctions のキャッシュポリシーを調整
```

### 2. Lambda設定の最適化

```typescript
// config.ts でメモリサイズやタイムアウトを調整
lambda: {
  memorySize: 1024,  // 本番環境では増加を検討
  timeout: 30,       // 要件に応じて調整
}
```

### 3. カスタムドメイン設定

Route 53とACMを使用してカスタムドメインを設定することを推奨。



**注意**: このプロジェクトは開発用設定です。本番環境にデプロイする前に、セキュリティとパフォーマンスの設定を見直してください。
