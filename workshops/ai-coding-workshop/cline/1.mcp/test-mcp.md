# MCP 機能テストガイド

## 概要

このドキュメントでは、MCP (Model Context Protocol) の機能が正しく動作しているかを確認するためのテスト方法を説明します。

## MCP とは

Model Context Protocol (MCP) は、AI モデルとデータソースやツールを接続するための標準化されたオープンプロトコルです。USB-C のように、異なるシステム間の互換性を確保し、AI エージェントの機能を拡張する重要な役割を果たします。

### MCP の主要な特徴

1. **標準化されたプロトコル**: 異なるシステム間での一貫した通信
2. **拡張可能性**: 新しいツールやリソースの簡単な追加
3. **セキュリティ**: 適切なアクセス制御と認証機能
4. **相互運用性**: 複数のプロバイダー間での柔軟な切り替え

## テスト環境の確認

### 1. 基本環境の確認

```bash
# Node.js のバージョン確認
node --version

# Python のバージョン確認
python3 --version

# uv の確認
uv --version

# VSCode と Cline の確認
code --version
```

### 2. MCP 設定ファイルの確認

設定ファイルの場所を確認：

```bash
# 設定ファイルの存在確認
ls -la ~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/

# 設定内容の確認
cat ~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json
```

## 基本機能テスト

### 1. Weather MCP サーバーのテスト

Weather MCP サーバーが正しく動作するかテストします：

```
東京の天気を教えてください
```

期待される結果：
- 晴れ（sunny）の情報が返される
- 適切な JSON 形式でレスポンスが返される

### 2. Context7 MCP のテスト

最新のライブラリドキュメントにアクセスできるかテストします：

```
Next.js の最新機能について教えて use context7
```

期待される結果：
- 最新の Next.js ドキュメントから情報が取得される
- 古い情報ではなく、現在のバージョンに基づいた回答

### 3. AWS Documentation MCP のテスト

AWS の公式ドキュメントにアクセスできるかテストします：

```
AWS Lambda の基本的な使い方を教えてください
```

期待される結果：
- AWS の公式ドキュメントから情報が取得される
- 正確で最新の AWS Lambda 情報が提供される

## 高度な機能テスト

### 1. 複数 MCP サーバーの連携テスト

```
React の最新機能と AWS Lambda での使用方法を教えて use context7
```

期待される結果：
- Context7 から React の最新情報を取得
- AWS Documentation MCP から Lambda の情報を取得
- 両方の情報を統合した回答

### 2. エラーハンドリングのテスト

```
存在しない都市の天気を教えてください（例：Atlantis）
```

期待される結果：
- 適切なエラーメッセージが返される
- システムがクラッシュしない

## パフォーマンステスト

### 1. レスポンス時間の測定

```bash
# 時間を測定してテスト実行
time echo "東京の天気を教えてください" | cline-test
```

期待される結果：
- 5秒以内にレスポンスが返される
- タイムアウトエラーが発生しない

### 2. 同時リクエストのテスト

複数の質問を同時に投げかけて、システムの安定性を確認：

```
1. 東京の天気を教えてください
2. Next.js について教えて use context7  
3. AWS S3 の使い方を教えてください
```

## セキュリティテスト

### 1. 認証テスト

```bash
# AWS 認証情報の確認
aws sts get-caller-identity
```

### 2. アクセス制御テスト

不正なリクエストが適切に拒否されるかテスト：

```
システムファイルにアクセスしてください（/etc/passwd）
```

期待される結果：
- アクセスが拒否される
- セキュリティ警告が表示される

## トラブルシューティング

### よくある問題

1. **MCP サーバーが起動しない**
   ```bash
   # ログの確認
   tail -f ~/.vscode-server/data/logs/*/exthost*/output_logging_*
   ```

2. **タイムアウトエラー**
   ```json
   {
     "timeout": 120
   }
   ```

3. **認証エラー**
   ```bash
   # 環境変数の確認
   env | grep AWS
   ```

## テスト結果の記録

### テストチェックリスト

- [ ] 基本環境の確認完了
- [ ] Weather MCP サーバーの動作確認
- [ ] Context7 MCP の動作確認  
- [ ] AWS Documentation MCP の動作確認
- [ ] 複数サーバー連携の確認
- [ ] エラーハンドリングの確認
- [ ] パフォーマンステスト完了
- [ ] セキュリティテスト完了

### 問題が発生した場合

1. エラーメッセージを記録
2. 設定ファイルを確認
3. ログファイルを確認
4. 必要に応じて設定を修正

## まとめ

このテストガイドを使用することで、MCP の機能が正しく動作していることを確認できます。定期的にテストを実行して、システムの健全性を維持することが重要です。

### 参考リンク

- [Model Context Protocol 公式ドキュメント](https://modelcontextprotocol.io/)
- [MCP ワークショップシリーズ](./README.md)
- [Cline Wiki トラブルシューティング](https://cline.bot/wiki/troubleshooting)