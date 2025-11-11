# CopilotKit統合ガイド（frontend-copilotkit）

このディレクトリは、frontendディレクトリをベースにCopilotKitを統合したバージョンです。

## 概要

Next.js 15 + NextAuth.js + Cognito認証に加えて、CopilotKitを統合し、AgentCore Runtime（agent-runtime-3lo）経由でAIチャット機能を提供します。

## アーキテクチャ

```
このフロントエンド (localhost:3000)
  ├─ NextAuth.js + Cognito認証
  ├─ JWT取得（ID Token + Access Token）
  └─ CopilotKit UI
       ↓ POST /api/copilotkit
       ↓ JWT Bearer Token
AgentCore Runtime (agent-runtime-3lo)
  └─ AI応答 + MCPツール呼び出し
```

## 必要な実装

### 1. CopilotKitパッケージ追加

```bash
npm install @copilotkit/react-core@1.10.6 \
            @copilotkit/react-ui@1.10.6 \
            @copilotkit/runtime@1.10.6
```

### 2. API Route実装

**ファイル**: `src/app/api/copilotkit/route.ts`

```typescript
import { NextRequest } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

const AWS_REGION = process.env.AWS_REGION || 'us-east-1';
const AGENTCORE_RUNTIME_ARN = process.env.AGENTCORE_RUNTIME_ARN;

export async function POST(req: NextRequest) {
  try {
    // Cognito認証確認
    const session = await getServerSession(authOptions);
    if (!session?.idToken) {
      return new Response('Unauthorized', { status: 401 });
    }

    const { message } = await req.json();

    if (!AGENTCORE_RUNTIME_ARN) {
      throw new Error('AGENTCORE_RUNTIME_ARN not configured');
    }

    // AgentCore Runtime呼び出し
    const encodedArn = encodeURIComponent(AGENTCORE_RUNTIME_ARN);
    const url = `https://bedrock-agentcore.${AWS_REGION}.amazonaws.com/runtimes/${encodedArn}/invocations?qualifier=DEFAULT`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.idToken}`,
      },
      body: JSON.stringify({ prompt: message }),
    });

    if (!response.ok) {
      throw new Error(`AgentCore error: ${response.statusText}`);
    }

    // ストリーミングレスポンス
    const stream = new ReadableStream({
      async start(controller) {
        const reader = response.body!.getReader();
        const decoder = new TextDecoder();

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const text = decoder.decode(value, { stream: true });
            const lines = text.split('\n');

            for (const line of lines) {
              if (line.startsWith('data: ')) {
                const data = line.slice(6).trim();
                if (data) {
                  controller.enqueue(new TextEncoder().encode(`data: ${data}\n\n`));
                }
              }
            }
          }
          controller.close();
        } catch (error) {
          console.error('Streaming error:', error);
          controller.error(error);
        }
      },
    });

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
  } catch (error) {
    console.error('CopilotKit API error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}
```

### 3. CopilotKit Wrapper Component

**ファイル**: `src/components/CopilotChatWrapper.tsx`

```typescript
'use client';

import { CopilotKit } from '@copilotkit/react-core';
import { CopilotSidebar } from '@copilotkit/react-ui';
import '@copilotkit/react-ui/styles.css';

export function CopilotChatWrapper({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <CopilotKit runtimeUrl="/api/copilotkit">
      <CopilotSidebar
        instructions="あなたはAmazon Bedrockで動作するAIアシスタントです。日本語で回答してください。利用可能なツールを積極的に使用してください。"
        defaultOpen={true}
        labels={{
          title: "AI アシスタント",
          initial: "何をお手伝いしましょうか？",
        }}
      >
        {children}
      </CopilotSidebar>
    </CopilotKit>
  );
}
```

### 4. メインページ更新

**ファイル**: `src/app/page.tsx`

```typescript
import { CopilotChatWrapper } from '@/components/CopilotChatWrapper';

export default function Home() {
  return (
    <CopilotChatWrapper>
      <main className="flex min-h-screen flex-col items-center justify-center p-24">
        <h1 className="text-4xl font-bold mb-8">
          CopilotKit × AgentCore × Cognito
        </h1>
        <p className="text-lg text-gray-600 mb-4">
          右側のチャットサイドバーからAIと会話できます →
        </p>
        <div className="text-sm text-gray-500">
          <p>✅ Cognito 3LO認証</p>
          <p>✅ JWT Propagation</p>
          <p>✅ スコープベース権限管理</p>
        </div>
      </main>
    </CopilotChatWrapper>
  );
}
```

### 5. CopilotKit CSSインポート

**ファイル**: `src/app/globals.css` または `src/app/layout.tsx`

CopilotKitのスタイルを追加：

```typescript
// layout.tsxに追加
import '@copilotkit/react-ui/styles.css';
```

## 環境変数設定

**ファイル**: `.env.local`

```bash
# 既存のfrontend/.env.localをコピー後、以下を追加

# AgentCore Runtime ARN（agent-runtime-3loデプロイ後に取得）
AGENTCORE_RUNTIME_ARN=arn:aws:bedrock-agentcore:us-east-1:776010787911:runtime/agent_3lo-XXXXX

# AWS Region
AWS_REGION=us-east-1
```

## 起動方法

```bash
# 依存関係インストール
npm install

# 開発サーバー起動
npm run dev

# ブラウザでアクセス
# http://localhost:3000
```

## テスト手順

### 1. 認証テスト
1. ブラウザで `http://localhost:3000` にアクセス
2. Cognito認証画面でログイン
3. ホーム画面が表示されることを確認

### 2. チャット機能テスト
1. 右側のチャットサイドバーを開く
2. メッセージを送信
3. AIからの応答を確認

### 3. ツール呼び出しテスト
以下のメッセージでMCPツールが呼び出されることを確認:

```
# 検索ツール（全ユーザー可）
"ノートパソコンを検索してください"

# 注文作成（書き込み権限必要）
"製品IDが1の商品を2個注文してください"

# 監査ログ（管理者のみ）
"2025年11月の監査ログを表示してください"
```

### 4. 権限テスト

ユーザーグループを変更してアクセス制御を確認:

```bash
# 一般ユーザーに変更
aws cognito-idp admin-add-user-to-group \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --username your-email@example.com \
    --group-name Users

# フロントエンドでログアウト→ログイン
# 書き込みツールを試す → エラーメッセージ確認
```

## デバッグ

### ブラウザ DevTools

```javascript
// JWT トークン確認
console.log(document.cookie);

// Network タブで以下を確認:
// - POST /api/copilotkit
// - Authorization ヘッダー
// - レスポンス
```

### サーバーログ

```bash
# Next.js開発サーバーのログを確認
# ターミナルに表示される
```

### AgentCore Runtime ログ

```bash
# CloudWatch Logs
aws logs tail /aws/bedrock-agentcore/runtime/<runtime-id> \
    --follow \
    --region us-east-1
```

## トラブルシューティング

### エラー: Unauthorized

**原因**: JWT取得失敗またはセッション切れ

**解決策**:
1. ログアウト→ログインで新JWT取得
2. `.env.local`のCognito設定確認
3. NextAuth.jsの設定確認

### エラー: AgentCore Runtime not found

**原因**: Runtime ARN未設定またはデプロイ失敗

**解決策**:
1. `.env.local`のAGENTCORE_RUNTIME_ARN確認
2. agent-runtime-3loのデプロイ状態確認

### エラー: 403 Forbidden (MCP Tool)

**原因**: スコープ不足

**解決策**:
1. ユーザーのグループを確認
2. 必要なグループに追加
3. ログアウト→ログインで新JWT取得

## 参考資料

- [CopilotKit Documentation](https://docs.copilotkit.ai/)
- [NextAuth.js Documentation](https://next-auth.js.org/)
- [agent-runtime-3lo README](../agent-runtime-3lo/README.md)
- [mcp-gateway README](../mcp-gateway/README.md)
