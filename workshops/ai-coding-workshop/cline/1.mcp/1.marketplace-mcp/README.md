# MCP Marketplace 活用ワークショップ

## はじめに

このワークショップでは、[MCP Marketplace](https://cline.bot/mcp-marketplace) を活用して、AI エージェントの機能を大幅に拡張する方法を学びます。MCP Marketplace は、様々な開発者が作成した MCP サーバーを簡単に発見・インストール・管理できるプラットフォームです。

## ワークショップの目的

このワークショップを通じて、参加者は以下のスキルを習得できます：

- MCP Marketplace の効果的な活用方法
- 様々な MCP サーバーの機能と特徴の理解
- MCP サーバーの安全なインストールと管理方法
- AI エージェントの能力拡張のベストプラクティス
- セキュリティを考慮した MCP サーバーの選択と運用

## 前提条件

このワークショップを開始する前に、以下の環境が整っていることを確認してください：

- VSCode と Cline 拡張機能がインストール済み
- Node.js 18.x 以上がインストール済み
- Python 3.10 以上がインストール済み（一部の MCP サーバー用）
- 基本的な MCP の概念を理解していること

## MCP Marketplace の概要

MCP Marketplace は、AI エージェントの機能を拡張するための豊富なツールとリソースを提供するプラットフォームです。開発者コミュニティによって作成された様々な MCP サーバーを、簡単に検索・インストール・管理することができます。

### Marketplace の主な特徴

1. **豊富なサーバーライブラリ**
   - Web 検索、ドキュメント処理、API 統合など多様な機能
   - コミュニティによる継続的な新機能追加
   - 品質とセキュリティの検証済みサーバー

2. **簡単なインストール**
   - ワンクリックでのインストール
   - 自動的な依存関係の解決
   - 設定ファイルの自動生成

3. **統合管理機能**
   - インストール済みサーバーの一覧表示
   - 有効/無効の切り替え
   - 設定の変更とカスタマイズ

## MCP Marketplace へのアクセス

### 1. Marketplace の開き方

VS Code で Cline 拡張機能を開き、以下の手順でアクセスします：

1. 左側のサイドバーから「MCP Servers」を選択
2. 画面上部の「Marketplace」タブをクリック
3. 検索バーを使用して必要なツールを検索

![MCP Marketplace の画面](../images/mcp-marketplace.png)

### 2. サーバーの検索と発見

Marketplace では、以下の方法でサーバーを見つけることができます：

- **キーワード検索**: 機能や用途に基づいた検索
- **カテゴリ別表示**: Web、データベース、API などのカテゴリ
- **人気順表示**: コミュニティで人気の高いサーバー
- **最新順表示**: 最近追加されたサーバー

## 実践演習 1: Context7 MCP の活用

### Context7 MCP とは

Context7 MCP は、AI エージェントが最新のライブラリドキュメントにアクセスできるようにする強力なツールです。従来の LLM が抱える以下の問題を解決します：

❌ **従来の問題**：
- 古いトレーニングデータに基づく古いコード例
- 実在しない API の誤った生成
- 古いパッケージバージョンに基づく一般的な回答

✅ **Context7 の解決策**：
- ソースから直接、最新のバージョン固有のドキュメントとコード例を取得
- プロンプトに直接、最新の情報を組み込み
- 常に最新の API 仕様に基づいた正確な回答

### インストール手順

1. **Marketplace からのインストール**
   ```
   MCP Marketplace で "Context7" を検索し、"Install" をクリック
   ```

2. **Cline による自動インストール**
   
   Cline がインストールのための新しいタスクを開始します。以下のような手順で進行されます：

   ```bash
   # プロジェクトディレクトリの作成
   mkdir -p /home/coder/Cline/MCP/context7-mcp
   cd /home/coder/Cline/MCP/context7-mcp
   
   # パッケージのインストール
   npm install -g @upstash/context7-mcp@latest
   ```

3. **設定ファイルの更新**

   MCP Setting ファイルが自動的に更新されます：
   
   ファイル: `/home/coder/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`

   ```json
   {
     "mcpServers": {
       "github.com/upstash/context7-mcp": {
         "autoApprove": [],
         "disabled": false,
         "timeout": 60,
         "command": "/home/coder/.local/share/mise/shims/npx",
         "args": [
           "-y",
           "@upstash/context7-mcp@latest"
         ],
         "transportType": "stdio"
       }
     }
   }
   ```

### 使用方法

Context7 を使用するには、質問に `use context7` を追加するだけです：

```
Next.js の `after` 関数の使い方を教えて use context7
React Query でクエリを無効化する方法は？ use context7
NextAuth でルートを保護する方法は？ use context7
```

### 実践演習

以下の質問を Cline に投げかけて、Context7 MCP の効果を体験してみましょう：

1. **最新の Next.js 機能について**
   ```
   Next.js 15 の新機能について教えて use context7
   ```

2. **React の最新パターン**
   ```
   React 19 の新しい hooks について説明して use context7
   ```

3. **TypeScript の最新機能**
   ```
   TypeScript 5.6 の新機能を教えて use context7
   ```

## 実践演習 2: Web Research MCP の活用

### Web Research MCP とは

Web Research MCP は、AI エージェントがリアルタイムでウェブ検索を行い、最新の情報を取得できるようにするツールです。

### 主な機能

- **リアルタイム検索**: Google、Bing などの検索エンジンを活用
- **コンテンツ抽出**: ウェブページから関連情報を自動抽出
- **情報統合**: 複数のソースからの情報を統合して回答生成

### インストールと設定

1. **Marketplace からのインストール**
   ```
   MCP Marketplace で "Web Research" を検索してインストール
   ```

2. **API キーの設定**
   
   環境変数として検索エンジンの API キーを設定：
   
   ```bash
   export GOOGLE_API_KEY="your-google-api-key"
   export GOOGLE_CSE_ID="your-custom-search-engine-id"
   ```

### 使用例

```
最新の AI 技術のトレンドについて調べて use websearch
2024年のプログラミング言語の人気ランキングは？ use websearch
```

## 実践演習 3: Markdownify MCP の活用

### Markdownify MCP とは

Markdownify MCP は、ウェブページや PDF ファイルを Markdown 形式に変換し、AI エージェントが処理しやすい形式で情報を提供するツールです。

### 主な機能

- **ウェブページの変換**: HTML を構造化された Markdown に変換
- **PDF 処理**: PDF ファイルのテキスト抽出と Markdown 変換
- **画像処理**: 画像内のテキスト抽出（OCR）

### 実践演習

1. **ウェブページの変換**
   ```
   https://example.com のコンテンツを Markdown で取得して
   ```

2. **PDF ファイルの処理**
   ```
   この PDF ファイルの内容を要約して（ファイルをアップロード）
   ```

## MCP サーバーの管理

### サーバーの有効/無効切り替え

VS Code の Cline 拡張機能の「MCP Servers」セクションで：

1. インストール済みサーバーの一覧を確認
2. トグルスイッチで有効/無効を切り替え
3. 設定アイコンから詳細設定を変更

![MCP サーバーの管理方法](../images/mcp-management-page.png)

### 設定のカスタマイズ

各サーバーの設定は以下の項目をカスタマイズできます：

- **timeout**: タイムアウト時間の調整
- **autoApprove**: 自動承認するツールの指定
- **env**: 環境変数の設定
- **disabled**: サーバーの無効化

### パフォーマンス監視

MCP サーバーのパフォーマンスを監視するポイント：

1. **応答時間**: サーバーの応答速度
2. **エラー率**: 失敗したリクエストの割合
3. **リソース使用量**: CPU とメモリの使用状況

## セキュリティ考慮事項

### 信頼できるサーバーの選択

MCP サーバーを選択する際の基準：

1. **開発者の信頼性**
   - 知名度の高い開発者や組織
   - オープンソースでコードが公開されている
   - コミュニティでの評価が高い

2. **セキュリティ対策**
   - 定期的なセキュリティ更新
   - 脆弱性の迅速な修正
   - セキュリティ監査の実施

3. **データ保護**
   - データの暗号化
   - プライバシーポリシーの明確化
   - データの適切な取り扱い

### アクセス制御

1. **最小権限の原則**
   - 必要最小限の権限のみを付与
   - 定期的な権限の見直し

2. **autoApprove の慎重な使用**
   - 信頼できるツールのみに設定
   - 定期的な設定の見直し

3. **監査とログ**
   - MCP サーバーの動作ログを記録
   - 不審な活動の監視

## トラブルシューティング

### よくある問題と解決方法

1. **インストールエラー**
   ```
   問題: npm install でエラーが発生
   解決: Node.js のバージョンを確認し、必要に応じて更新
   ```

2. **接続エラー**
   ```
   問題: MCP サーバーに接続できない
   解決: 設定ファイルのパスとコマンドを確認
   ```

3. **タイムアウトエラー**
   ```
   問題: サーバーの応答が遅い
   解決: timeout 値を増加させる
   ```

### デバッグ方法

1. **ログの確認**
   ```bash
   # Cline のログを確認
   tail -f ~/.vscode-server/data/logs/*/exthost*/output_logging_*
   ```

2. **設定の検証**
   ```bash
   # 設定ファイルの構文チェック
   cat ~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json | jq .
   ```

## まとめ

このワークショップでは、MCP Marketplace を活用して AI エージェントの機能を拡張する方法を学びました。主なポイント：

1. **Marketplace の活用**: 豊富なサーバーライブラリから適切なツールを選択
2. **実践的な使用**: Context7、Web Research、Markdownify などの具体例
3. **管理とセキュリティ**: 安全で効率的なサーバー運用
4. **トラブルシューティング**: 問題解決のための実践的な手法

### 次のステップ

- [AWS MCP サーバー活用ワークショップ](../2.aws-mcp/README.md)に進む
- より高度な MCP サーバーの開発に挑戦
- 独自の MCP サーバーの作成を検討

### 参考リンク

- [MCP Marketplace](https://cline.bot/mcp-marketplace)
- [Context7 ライブラリページ](https://context7.com/libraries)
- [Model Context Protocol 公式ドキュメント](https://modelcontextprotocol.io/)
- [Cline Wiki トラブルシューティング](https://cline.bot/wiki/troubleshooting)