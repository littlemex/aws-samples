# CopilotKit × Cognito 認証統合アプリケーション

Amazon CognitoとCopilotKitを統合したNext.jsアプリケーションです。NextAuth.js v5を使用してCognito認証を実装し、認証後にCopilotKitのAIチャット機能を提供します。

## 🎯 目的

このアプリケーションは、以下の技術スタックの統合を実証します：

1. ✅ **NextAuth.js v5** - Cognito OAuth 2.0認証
2. ✅ **CloudFront + Lambda Function URL** - グローバル配信
3. ✅ **trustHostバグ回避策** - プロキシ環境での認証フロー
4. ✅ **CopilotKit** - AIアシスタント統合
5. ✅ **JWT管理** - ID Token、Access Token、Refresh Token
6. ✅ **SSM Parameter Store** - 環境変数管理

## 📋 前提条件

- **Cognitoスタック**がデプロイ済み（`infrastructure/scripts/deploy-cognito.sh`）
- **Node.js 20.x以降**
- **AWS CLI設定済み**（SSM Parameter Store アクセス用）

## 🚀 起動方法

### 0. テストユーザー作成

infrastructureディレクトリでCognitoスタックをデプロイ後、テストユーザーを作成します：

```bash
cd ../infrastructure/scripts/
NODE_ENV=dev ./create-test-user.sh
```

ユーザー情報は`test-user-info.txt`に保存されます。

### 1. 依存関係インストール（初回のみ）

```bash
npm install
```

### 2. 開発サーバー起動（推奨）

**ラッパースクリプトを使用**（SSM Parameter Storeから自動取得）：

```bash
# dev環境で起動（デフォルト: CLIENT_SUFFIX=dev, PORT=3001）
./scripts/dev.sh

# prod環境で起動
CLIENT_SUFFIX=prod ./scripts/dev.sh

# ポート番号を変更
PORT=3002 ./scripts/dev.sh

# 組み合わせ
CLIENT_SUFFIX=prod PORT=3003 ./scripts/dev.sh
```

ブラウザで http://localhost:3001 にアクセスします。

**スクリプトの動作**:
1. SSM Parameter StoreからCognito情報を取得（`CLIENT_SUFFIX`で環境指定）
2. NextAuth v5環境変数を自動設定（`AUTH_COGNITO_ID`、`AUTH_COGNITO_ISSUER`など）
3. 開発サーバーを起動

**環境の切り替え**:
- `CLIENT_SUFFIX`環境変数で環境を指定（デフォルト: `dev`）
- `dev` → SSMパス: `/copilotkit-agentcore/dev/cognito/*`
- `prod` → SSMパス: `/copilotkit-agentcore/prod/cognito/*`

**infrastructure側との対応**:
```bash
# 1. infrastructure側でdev環境をセットアップ＆デプロイ
cd ../infrastructure
NODE_ENV=dev ./scripts/setup.sh
NODE_ENV=dev ./scripts/deploy.sh

# 2. frontend-copilotkit側でローカル開発
cd ../frontend-copilotkit
./scripts/dev.sh  # デフォルトでCLIENT_SUFFIX=dev
```

### 3. 手動起動（非推奨）

環境変数を手動で設定する場合：

```bash
# NextAuth v5環境変数を設定
export AUTH_COGNITO_ID="your-client-id"
export AUTH_COGNITO_ISSUER="https://cognito-idp.region.amazonaws.com/pool-id"
export AUTH_SECRET="your-secret"
export AUTH_TRUST_HOST=true

# 開発サーバー起動
npm run dev
```

## 🏗️ アーキテクチャ

### 認証フロー

```
ブラウザ
  ↓ [1] サインインボタンクリック
Next.js (localhost:3001)
  ↓ [2] Cognito認証ページへリダイレクト
  │     authorization.params.redirect_uri を動的設定
Cognito Hosted UI
  ↓ [3] ユーザー認証
  ↓ [4] コールバック: /api/auth/callback/cognito?code=xxx
Next.js Route Handler
  ├─ [5] reqWithTrustedOrigin() でリクエスト書き換え
  │     （GitHub Issue #12176 回避策）
  ├─ [6] トークン交換
  │     token.params.redirect_uri を動的設定
  └─ [7] セッション確立
App
  └─ CopilotKit UI表示
```

### システム構成（本番環境）

```
CloudFront Distribution
  ├─ X-Forwarded-Host: d123.cloudfront.net
  ├─ X-Forwarded-Proto: https
  ↓
Lambda Function URL
  ├─ Next.js App (Standalone)
  ├─ NextAuth.js v5
  │   ├─ trustHost: true
  │   └─ reqWithTrustedOrigin() 回避策
  └─ CopilotKit Integration
       ↓
[On going] AgentCore Runtime
  └─ AI応答 + MCPツール
```

## 🔐 NextAuth.js v5 設定

### 主要な実装ポイント

#### 1. `src/auth.ts` - NextAuth設定

```typescript
export const { auth, handlers, signIn, signOut } = NextAuth({
  providers: [
    Cognito({
      client: {
        token_endpoint_auth_method: 'none',  // Public Client
      },
    }),
  ],
  callbacks: {
    jwt: async ({ token, account }) => {
      // Cognitoトークンを保存
      if (account) {
        token.idToken = account.id_token;
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
      }
      return token;
    },
    session: async ({ session, token }) => {
      // セッションにトークンを含める
      session.idToken = token.idToken;
      session.accessToken = token.accessToken;
      return session;
    },
  },
  debug: process.env.NODE_ENV === 'development',
  trustHost: true,  // CloudFront対応
});
```

#### 2. `src/app/api/auth/[...nextauth]/route.ts` - trustHostバグ回避策

**問題**: NextAuth v5 beta版では`trustHost: true`が正しく動作しない（GitHub Issue #12176）

**解決策**: リクエストオブジェクトを手動で書き換え

```typescript
const reqWithTrustedOrigin = (req: NextRequest): NextRequest => {
  if (process.env.AUTH_TRUST_HOST !== 'true') return req;
  
  const proto = req.headers.get('x-forwarded-proto');
  const host = req.headers.get('x-forwarded-host');
  
  if (!proto || !host) return req;
  
  const trustedOrigin = `${proto}://${host}`;
  const { href, origin } = req.nextUrl;
  
  // オリジンを書き換えた新しいリクエストを作成
  return new NextRequest(href.replace(origin, trustedOrigin), req);
};

export const GET = (req: NextRequest) => 
  handlers.GET(reqWithTrustedOrigin(req));
export const POST = (req: NextRequest) => 
  handlers.POST(reqWithTrustedOrigin(req));
```

この回避策により：
- Authorization Request時の`redirect_uri`が正しく設定される
- Token Exchange時の`redirect_uri`も一致する
- CloudFront、localhost、ポートフォワーディングすべてに対応

### 環境変数（NextAuth v5）

**ビルド時に必要**:
```bash
AUTH_COGNITO_ID=xxx              # Cognito Client ID
AUTH_COGNITO_ISSUER=https://...  # Cognito Issuer URL
AUTH_SECRET=xxx                  # セッション暗号化キー
AUTH_TRUST_HOST=true             # プロキシ対応
```

**重要**: NextAuth v5では環境変数の命名規則が変更されています：
- v4: `COGNITO_CLIENT_ID` → v5: `AUTH_COGNITO_ID`
- v4: `COGNITO_ISSUER` → v5: `AUTH_COGNITO_ISSUER`
- v4: `NEXTAUTH_SECRET` → v5: `AUTH_SECRET`
- v4: `NEXTAUTH_URL`（不要） → v5: `AUTH_TRUST_HOST=true`

## 📁 プロジェクト構造

```
frontend-copilotkit/
├── src/
│   ├── auth.ts                           # NextAuth v5設定
│   ├── app/
│   │   ├── layout.tsx                    # ルートレイアウト
│   │   ├── page.tsx                      # メインページ（CopilotKit UI）
│   │   ├── providers.tsx                 # SessionProvider
│   │   └── api/
│   │       ├── auth/[...nextauth]/
│   │       │   └── route.ts              # NextAuth Route Handler（バグ回避策含む）
│   │       └── copilotkit/
│   │           └── route.ts              # CopilotKit API
│   ├── components/
│   │   └── CopilotKitWrapper.tsx         # CopilotKitプロバイダー
│   └── types/
│       └── next-auth.d.ts                # NextAuth型定義拡張
├── scripts/
│   └── dev.sh                            # 開発サーバー起動スクリプト
├── package.json
├── next.config.ts
└── README.md
```

## 🔧 開発のヒント

### デバッグログの有効化

`src/auth.ts`で`debug: true`を設定：

```typescript
export const { auth, handlers, signIn, signOut } = NextAuth({
  // ...
  debug: true,  // または process.env.NODE_ENV === 'development'
});
```

### Lambda CloudWatchログの確認（本番環境）

```bash
# Lambda関数の特定
aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `CopilotKitNextjsStack`)].FunctionName'

# ログのストリーミング
aws logs tail /aws/lambda/[関数名] --follow
```

### ローカル環境でのCognito設定確認

```bash
# SSM Parameter Storeから確認
aws ssm get-parameter \
  --name "/copilotkit-agentcore/dev/cognito/client-id" \
  --query "Parameter.Value" \
  --output text
```

## 🐛 トラブルシューティング

### `redirect_mismatch`エラー

**原因**: `redirect_uri`がCognitoに登録されていない

**解決**:
1. Cognitoコールバック URLを確認:
   ```bash
   aws cognito-idp describe-user-pool-client \
     --user-pool-id [pool-id] \
     --client-id [client-id]
   ```
2. `trustHost`バグ回避策が実装されているか確認
3. CloudFrontデプロイ後、CustomResourceが自動的にURLを追加

### 認証後にエラーページに遷移

**原因**: セッションコールバックの問題

**確認**:
- `src/auth.ts`の`callbacks`が正しく実装されているか
- トークンが正しく保存されているか

### 環境変数が読み込まれない

**原因**: `.env`ファイルの配置またはNext.jsの環境変数読み込み順序

**解決**:
- `scripts/dev.sh`を使用（推奨）
- または環境変数を明示的にエクスポート

## 📚 関連ドキュメント

- **[NextAuth.js v5 Documentation](https://authjs.dev/)** - NextAuth.js公式ドキュメント
- **[GitHub Issue #12176](https://github.com/nextauthjs/next-auth/issues/12176)** - trustHostバグと回避策
- **[CopilotKit Documentation](https://docs.copilotkit.ai/)** - CopilotKit統合ガイド
- **infrastructure/TROUBLESHOOTING_COGNITO_AUTH.md** - 詳細なトラブルシューティング記録

## 🔒 セキュリティ上の注意

### 本番環境での推奨事項

1. **`AUTH_SECRET`の安全な生成**:
   ```bash
   openssl rand -base64 32
   ```

2. **環境変数の保護**:
   - `.env.production`をGit管理しない
   - AWS Secrets Managerまたはパラメータストアを使用

3. **HTTPSの強制**:
   - 本番環境では必ずHTTPSを使用
   - CloudFrontで強制リダイレクト設定

4. **トークンの適切な管理**:
   - セッションタイムアウトの設定
   - リフレッシュトークンのローテーション

## 🚀 デプロイ

このアプリケーションは`infrastructure/scripts/deploy-frontend.sh`を使用してAWSにデプロイされます。

詳細は`infrastructure/README.md`を参照してください。

---

**開発**: このアプリケーションはNextAuth.js v5とCognitoの統合検証用です。本番環境への適用前に、セキュリティとパフォーマンスの要件を確認してください。
