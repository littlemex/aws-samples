# CopilotKit Agent UI Infrastructure

AWS CDKとcdklabs/cdk-nextjsライブラリを使用してNext.js 15フロントエンドをAWSにデプロイするためのインフラストラクチャコード。

## 📋 アーキテクチャ概要

### 新しいアーキテクチャ（2025年11月8日移行済み）

**cdklabs/cdk-nextjs NextjsGlobalFunctions**を使用：
- **Lambda Function URL + IAM Auth**: セキュアなLambda関数アクセス
- **CloudFront**: グローバル配信ネットワーク
- **S3**: 静的アセット配信
- **Cognito User Pool**: 認証管理

### 旧アーキテクチャからの改善点

✅ **セキュリティ向上**: Lambda Function URL + IAM AuthでWorld Accessible問題を解決  
✅ **運用性向上**: AWS公式ライブラリによる安定したサポート  
✅ **保守性向上**: 複雑な自前CloudFront設定から公式実装へ移行  
✅ **コスト削減**: シンプルなアーキテクチャで運用コスト削減  

## 🚀 クイックスタート

### 前提条件

- AWS CLI設定済み
- Node.js 20.x以降
- Docker（cdk-nextjsのビルドプロセスで使用）

### 1. セットアップ（初回のみ）

```bash
cd infrastructure
./scripts/setup.sh
```

このスクリプトは以下を自動実行：
- NEXTAUTH_SECRETの自動生成
- .envファイルの作成
- AWS認証情報の確認
- CDKブートストラップ（必要に応じて）
- 依存関係のインストール

### 2. デプロイ実行

```bash
./scripts/deploy.sh
```

このスクリプトは以下を自動実行：
- フロントエンドのビルド
- CDKスタックのデプロイ（Cognito → Next.js）
- デプロイ結果の表示
- Cognito設定手順の案内

### 3. Cognito設定の更新

デプロイ完了後、スクリプトが表示するUser Pool IDとClient IDを使用してAWS Cognitoコンソールで設定更新：

1. AWS Cognito → User Pools → [表示されたUser Pool ID]
2. App integration → App clients → [表示されたClient ID]
3. **Callback URLs**に追加: `https://[NextjsUrl]/api/auth/callback/cognito`
4. **Sign-out URLs**に追加: `https://[NextjsUrl]`
5. 変更を保存

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
│   └── destroy.sh                # 環境削除スクリプト
├── .env                          # 環境変数ファイル
├── .env.example                  # 環境変数テンプレート
├── cdk.json                      # CDK設定
├── tsconfig.json                 # TypeScript設定
└── package.json                  # Node.js依存関係
```

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
npm run synth

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

## 📚 参考資料

- [cdklabs/cdk-nextjs GitHub](https://github.com/cdklabs/cdk-nextjs)
- [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter)
- [Next.js Deployment Guide](https://nextjs.org/docs/deployment)
- [AWS CDK v2 Documentation](https://docs.aws.amazon.com/cdk/v2/guide/)
- [Amazon Cognito Documentation](https://docs.aws.amazon.com/cognito/)

## 📝 変更履歴

### 2025年11月8日 - アーキテクチャ移行

- 複雑な自前実装から`cdklabs/cdk-nextjs`へ移行
- セキュリティ向上（Lambda Function URL + IAM Auth）
- デプロイスクリプトの更新
- ドキュメント全面改訂

---

**注意**: このプロジェクトは開発用設定です。本番環境にデプロイする前に、セキュリティとパフォーマンスの設定を見直してください。
