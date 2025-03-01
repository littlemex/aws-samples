# AppSync Long-Running Process Pattern

このプロジェクトは、AWS AppSyncを使用して長時間実行プロセスを処理するパターンを実装したものです。WebSocketを使用したリアルタイムな状態更新機能を備えています。

## アーキテクチャ

- AppSync GraphQL API
- Lambda関数による非同期処理
- WebSocketを使用したリアルタイム通知
- Cognito認証

## セットアップ手順

### 1. 環境構築

```bash
# プロジェクトディレクトリに移動
cd aws-samples/machinelearning/ai-gateway/appsync-pattern

# 依存関係のインストール
cd cdk
npm install
```

### 2. CDKデプロイ

```bash
# CDKスタックをデプロイ
cd cdk
npx cdk deploy --outputs-file ../cdk-outputs.json
```

### 3. テスト環境の準備

```bash
# テストディレクトリに移動
cd ../test

# .env.sampleをコピーして設定
cp .env.sample .env

# .envファイルを編集して以下の値を設定
# - TEST_USER_EMAIL: Cognitoに登録されているテストユーザーのメールアドレス
# - TEST_USER_PASSWORD: テストユーザーのパスワード
#   (8文字以上、大小文字、数字、特殊文字を含む)
```

### 4. テストの実行

```bash
# テストディレクトリで実行
cd ../test
uv run test_graphql_api.py
```

## テストケース

以下のテストケースが実装されています：

1. 正常系テスト
   - Claude v2モデルでの推論
   - Claude Instant v1モデルでの推論

2. 長時間実行テスト
   - 5分間の処理時間を想定したテスト
   - WebSocket接続の維持確認

3. エラーケーステスト
   - 無効なモデル名の指定
   - 必須フィールドの欠落

## ステータス遷移

推論ジョブは以下のステータス遷移をたどります：

```
PENDING → PROCESSING → COMPLETED
                    └→ FAILED
```

## 実装の特徴

- AppSyncのタイムアウト（30秒）を回避するための非同期処理
- WebSocketを使用したリアルタイムな状態更新
- Subscription機能によるイベント通知
- 堅牢なエラーハンドリング
- 詳細なログ出力

## 注意事項

1. テスト実行前に必ずCDKスタックがデプロイされていることを確認
2. テストユーザーの認証情報が正しく設定されていることを確認
3. 長時間実行テストは最大5分程度かかる可能性があります
