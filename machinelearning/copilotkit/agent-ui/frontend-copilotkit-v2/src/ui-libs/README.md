# UI Libs

プロジェクト固有の依存関係を持たない、再利用可能なUIコンポーネントライブラリです。

## 概要

このライブラリは、以下の特徴を持っています：

- ✅ **Pure React**: Next.js やその他のフレームワークに依存しない
- ✅ **TypeScript**: 完全な型安全性
- ✅ **Tailwind CSS**: ユーティリティファーストのスタイリング
- ✅ **疎結合**: プロジェクト固有のロジックを持たない
- ✅ **再利用可能**: 複数のプロジェクトで使用可能

## ディレクトリ構造

```
ui-libs/
├── components/
│   ├── ui/              # 基本UIコンポーネント
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   └── index.ts
│   ├── auth/            # 認証関連コンポーネント
│   │   ├── LoginScreen.tsx
│   │   └── index.ts
│   └── index.ts
├── lib/
│   └── utils.ts         # ユーティリティ関数
├── index.ts             # メインエントリーポイント
└── README.md
```

## 使用方法

### 基本的なインポート

```tsx
// 個別インポート
import { Button, Card, LoginScreen } from '@/ui-libs'

// または特定のコンポーネントのみ
import { Button } from '@/ui-libs/components/ui'
import { LoginScreen } from '@/ui-libs/components/auth'
```

### Button コンポーネント

```tsx
import { Button } from '@/ui-libs'

function MyComponent() {
  return (
    <>
      <Button variant="default">デフォルト</Button>
      <Button variant="outline">アウトライン</Button>
      <Button variant="ghost">ゴースト</Button>
      <Button size="sm">小</Button>
      <Button size="lg">大</Button>
    </>
  )
}
```

**Props:**
- `variant`: "default" | "destructive" | "outline" | "secondary" | "ghost" | "link"
- `size`: "default" | "sm" | "lg" | "icon"
- `asChild`: boolean (Radix UI Slotを使用する場合)

### Card コンポーネント

```tsx
import { Card, CardHeader, CardTitle, CardContent } from '@/ui-libs'

function MyComponent() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>タイトル</CardTitle>
      </CardHeader>
      <CardContent>
        コンテンツ
      </CardContent>
    </Card>
  )
}
```

### LoginScreen コンポーネント

```tsx
import { LoginScreen } from '@/ui-libs'

function MyPage() {
  return (
    <LoginScreen
      appName="MyApp"
      onLogin={() => console.log('Login clicked')}
      onSignup={() => console.log('Signup clicked')}
      navigationLinks={[
        { label: '特徴', href: '#features' },
        { label: '料金', href: '#pricing' },
      ]}
    />
  )
}
```

**Props:**
- `appName`: string (アプリケーション名)
- `onLogin`: () => void (ログインボタンのハンドラー)
- `onSignup`: () => void (サインアップボタンのハンドラー)
- `navigationLinks`: Array<{ label: string; href: string }> (ナビゲーションリンク)

## 依存関係

このライブラリは以下のパッケージに依存しています（peerDependenciesとして扱う）：

- `react` (^18.0.0 || ^19.0.0)
- `react-dom` (^18.0.0 || ^19.0.0)
- `@radix-ui/react-slot`
- `class-variance-authority`
- `clsx`
- `tailwind-merge`
- `lucide-react`

## Tailwind CSS設定

このライブラリを使用するプロジェクトでは、以下のTailwind CSS変数が定義されている必要があります：

```css
:root {
  --background: ...;
  --foreground: ...;
  --primary: ...;
  --primary-foreground: ...;
  --secondary: ...;
  --secondary-foreground: ...;
  --muted: ...;
  --muted-foreground: ...;
  --accent: ...;
  --accent-foreground: ...;
  --destructive: ...;
  --destructive-foreground: ...;
  --border: ...;
  --input: ...;
  --ring: ...;
  --card: ...;
  --card-foreground: ...;
}
```

## 今後の拡張

将来的には、以下のような拡張が可能です：

1. **別パッケージ化**: npmパッケージとして公開
2. **モノレポ化**: pnpm workspaceなどで管理
3. **Storybook統合**: コンポーネントカタログの作成
4. **テストの追加**: Jest/React Testing Libraryでのテスト

## ライセンス

このプロジェクトのライセンスに従います。
