# Wren AI + PostgreSQL + S3 + Amazon Bedrock デモ

このプロジェクトは、Wren AI、PostgreSQL、S3、Amazon Bedrock を使用したデータ分析環境のデモです。PostgreSQL のデータを S3 に ETL し、Wren AI と Amazon Bedrock の Claude モデルで分析する流れを実装しています。

## プロジェクト構成

- **PostgreSQL**: ダミーデータを格納するデータベース
- **S3/MinIO**: ETL 後のデータ保存先
- **Wren AI**: S3 のデータを DuckDB 経由で分析するツール
- **Amazon Bedrock**: 高性能な Claude LLM モデルを提供するサービス
- **Bootstrap**: 初期化用のサービス
- **Wren Engine**: Wren AI のコアエンジン
- **Ibis Server**: データ処理サーバー
- **Qdrant**: ベクトルデータベース

## セットアップ手順

### 前提条件
- Docker と Docker Compose がインストールされていること
- AWS CLI がインストールされ、適切に設定されていること
- Amazon Bedrock へのアクセス権限を持つ IAM ロールが設定されていること
- AWS_REGION_NAME 環境変数が設定されていること（デフォルト: us-east-1）
docker system prune -a

### 1. セットアップスクリプトの実行

このリポジトリには、Wren AI と Amazon Bedrock の連携環境を簡単にセットアップするための `setup-wren.sh` スクリプトが含まれています。このスクリプトは以下の処理を行います：

- 公式リポジトリから最新の `docker-compose.yaml` をダウンロード
- 公式リポジトリから最新の `.env.example` をダウンロード
- AWS Bedrock 用の `.env.example.dev` ファイルを作成
- 既存の `config.yaml` ファイルをルートディレクトリにコピー
- データファイル用の `data` ディレクトリを作成
- `.env.example.dev` を `.env` にコピー

```bash
# セットアップスクリプトを実行
./scripts/setup-wren.sh

# S3 バケットを作成
# 必要に応じて export AWS_PROFILE=xx を設定してください。
./scripts/setup-s3.sh

# Docker コンテナを起動
./scripts/start-wren.sh

# 統合テストを実行（オプション）
./scripts/integration-test.sh
```

> **注意**: OPENAI_API_KEY は不要になりました。Amazon Bedrock の Claude モデルを使用するため、AWS の認証情報のみが必要です。

### 2. ETL サンプル実行

```bash
./scripts/etl-sample.sh
```

### 3. Wren AI へのアクセス

ブラウザで http://localhost:3000 にアクセスし、以下の手順で DuckDB 接続を設定します：

1. "Connect Data Source" を選択
2. "DuckDB" を選択
3. 以下の SQL を "Initial SQL Statements" に入力：

```sql
-- S3 拡張機能のインストール
INSTALL httpfs;
LOAD httpfs;

-- AWS 認証情報の設定（AWS CLI の認証情報を使用）
SET s3_region='us-east-1';

-- データの読み込み
CREATE TABLE customers AS SELECT * FROM read_csv_auto('s3://<BUCKET_NAME>/data/customers.csv');
CREATE TABLE orders AS SELECT * FROM read_csv_auto('s3://<BUCKET_NAME>/data/orders.csv');
CREATE TABLE products AS SELECT * FROM read_csv_auto('s3://<BUCKET_NAME>/data/products.csv');
CREATE TABLE order_items AS SELECT * FROM read_csv_auto('s3://<BUCKET_NAME>/data/order_items.csv');
```

※ `<BUCKET_NAME>` は `.env` ファイルに保存されたバケット名に置き換えてください。

## 使用方法

Wren AI の UI から自然言語クエリを使用してデータを分析できます。例：

- "顧客ごとの注文合計金額を表示して"
- "最も購入金額が多い顧客トップ10を表示して"
- "カテゴリ別の売上合計を円グラフで表示して"

### Amazon Bedrock Claude モデルについて

このデモでは、以下の Amazon Bedrock Claude モデルを使用しています：

1. **Claude 3.7 Sonnet (US)** - プライマリモデル
   - 最新の高性能モデル
   - 複雑なデータ分析タスクに最適

2. **Claude 3.5 Sonnet (US)** - フォールバックモデル
   - 米国リージョンでのバックアップモデル

3. **Claude 3.5 Sonnet (APAC)** - リージョン最適化モデル
   - 日本語処理に最適化された東京リージョン (ap-northeast-1) のモデル
   - 日本語クエリに対して低レイテンシで応答

4. **Claude 3.5 Sonnet v1** - 安定性重視モデル
   - 長期サポート版モデル

フォールバック機能により、プライマリモデルが利用できない場合は自動的に代替モデルを使用します。

## バージョン管理

`setup-wren.sh` スクリプトは、GitHub から最新バージョンの Wren AI コンポーネントを自動的に取得します。バージョン情報は `.env.example` ファイルから抽出され、`.env.example.dev` ファイルに反映されます。

これにより、Wren AI の公式リポジトリがアップデートされた場合でも、スクリプトを再実行するだけで最新バージョンを取得できます。

```bash
# バージョン情報の例
WREN_PRODUCT_VERSION=0.25.0
WREN_ENGINE_VERSION=0.17.1
WREN_AI_SERVICE_VERSION=0.24.3
IBIS_SERVER_VERSION=0.17.1
WREN_UI_VERSION=0.30.0
WREN_BOOTSTRAP_VERSION=0.1.5
```

## Docker Compose 構成

新しい `docker-compose.yaml` ファイルには、以下のサービスが含まれています：

1. **bootstrap**: 初期化用のサービス
2. **wren-engine**: Wren AI のコアエンジン
3. **ibis-server**: データ処理サービス
4. **wren-ai-service**: AI サービス（Amazon Bedrock と連携）
5. **qdrant**: ベクトルデータベース
6. **wren-ui**: ユーザーインターフェース

これらのサービスは環境変数を使用して設定され、`.env` ファイルで管理されます。

## 次のステップ

このデモでは ETL プロセスを手動で実行していますが、次のステップとして以下の拡張が考えられます：

1. MCP サーバーを実装して ETL プロセスを自動化
2. Amazon Bedrock の特定のユースケース向けにカスタマイズされたプロンプトの作成
3. 複数のデータソースを統合した高度な分析パイプラインの構築
4. 定期的なバージョン更新の自動化

## トラブルシューティング

- **S3 接続エラー**: AWS CLI の認証情報が正しく設定されているか確認してください
- **DuckDB S3 接続エラー**: S3 バケットの CORS 設定を確認してください
- **Wren AI 接続エラー**: Docker コンテナが正常に起動しているか確認してください
- **Amazon Bedrock 接続エラー**: 以下を確認してください
  - AWS_REGION_NAME 環境変数が正しく設定されているか
  - IAM ロールに Amazon Bedrock へのアクセス権限があるか
  - 使用しようとしているモデルが指定したリージョンで利用可能か
  - クロスリージョン推論の場合、適切な設定がされているか
  - Amazon EC2 のインスタンスプロファイルにアタッチしている IAM ロールに適切な Amazon Bedrock の利用権限がついているかご確認ください（重要!!!）。

### Amazon Bedrock モデルのアクセス権限設定

Amazon Bedrock のモデルを使用するには、AWS コンソールで以下の設定が必要です：

1. AWS コンソールにログイン
2. Amazon Bedrock サービスに移動
3. 「Model access」を選択
4. 使用したいモデル（Claude 3.7 Sonnet、Claude 3.5 Sonnet など）にチェックを入れる
5. 「Request model access」をクリック
6. アクセス権が付与されるまで待つ（通常は数分以内）

詳細は [Amazon Bedrock ドキュメント](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) を参照してください。
