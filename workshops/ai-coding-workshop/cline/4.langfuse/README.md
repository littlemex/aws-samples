# LiteLLM と Langfuse を用いた LLM 利用状況の分析

Cline VSCode Plugin で LiteLLM を API Provider として使用する際の詳細な利用状況を分析するため、Langfuse を統合しました。

## ファイル構成

```
.
├── .env.example          # 環境変数のテンプレート
├── debug_langfuse.sh     # デバッグ用スクリプト
├── litellm_config.yml    # LiteLLM の設定ファイル
├── manage-langfuse.sh    # Langfuse 管理スクリプト
├── network-architecture.md # ネットワーク構成の詳細
├── requirements.txt      # Python 依存パッケージ
└── test_litellm_langfuse.py # テストスクリプト
```

## アーキテクチャ

```mermaid
graph TB
    subgraph "Local PC"
        MB[Local PC]
    end

    subgraph "Amazon EC2 Instance"
        subgraph "Host OS"
            CS[code-server<br/>:8080]
            VSC[VSCode Server]
            PF1[":3000 Port Forward"]
            PF2[":8080 Port Forward"]
            PF3[":4000 Port Forward"]
        end

        subgraph "Docker Network: langfuse_default"
            direction LR
            LF[Langfuse Web<br/>langfuse-web:3000]
            PG1[Postgres<br/>postgres:5432]
            CH[Clickhouse<br/>clickhouse:8123]
            RD[Redis<br/>redis:6379]
            MN[MinIO<br/>minio:9090]
            LL[LiteLLM Proxy<br/>localhost:4000]
            PG2[Postgres<br/>postgres:5432]
            
            LF --- PG1
            LF --- CH
            LF --- RD
            LF --- MN
            LL --- PG2
        end

        CS -- "Proxy" --> LF
        CS -- "Proxy" --> LL
        VSC -- "Direct" --> LF
        VSC -- "Direct" --> LL
    end

    MB -- "SSH Port Forward" --> PF1
    MB -- "SSH Port Forward" --> PF2
    MB -- "SSH Port Forward" --> PF3
```

## ネットワーク構成

### コンテナネットワーク
- すべてのサービスは `langfuse_default` ネットワーク内で実行
- コンテナ間通信には Docker DNS 名を使用（例：`langfuse-web`, `postgres`）
- 内部ポートはネットワーク内で公開

### 重要な注意点
- コンテナ内では `localhost` は自身のコンテナを指すため、使用を避ける
- 代わりに Docker サービス名を使用（例：`http://langfuse-web:3000`）
- MinIO は内部で 9000 ポートを使用（外部からは 9090）

## セットアップ手順

1. 環境変数の設定
```bash
cp .env.example .env
# .env ファイルを編集
```

2. 依存パッケージのインストール
```bash
pip install -r requirements.txt
```

3. サービスの起動
```bash
./manage-langfuse.sh start
```

## 設定ファイル

### litellm_config.yml
- モデルの設定（Bedrock Claude など）
- フォールバックとリトライの設定
- Langfuse コールバックの設定

### 環境変数の設定例
```env
# データベース設定
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/postgres

# Langfuse 設定
LANGFUSE_HOST=http://langfuse-web:3000
NEXTAUTH_URL=http://localhost:3000

# MinIO 設定
LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT=http://minio:9000
```

## デバッグツール

`debug_langfuse.sh` スクリプトを使用してトラブルシューティングを行えます：

```bash
./debug_langfuse.sh
```

このスクリプトは以下を確認します：
- Langfuse と LiteLLM コンテナの状態
- 環境変数の設定
- コンテナのログ
- ネットワーク接続状態

## トラブルシューティング

### 一般的な問題

1. コンテナ間の接続エラー
   - Docker DNS 名が正しく使用されているか確認
   - 環境変数内の `localhost` 参照を修正
   - `debug_langfuse.sh` でログを確認

2. MinIO 接続エラー
   - エンドポイントが `minio:9000` を使用しているか確認
   - バケットが正しく作成されているか確認

3. データベース接続エラー
   - PostgreSQL 接続文字列が Docker サービス名を使用しているか確認
   - データベースが初期化されているか確認

### デバッグ手順

1. サービスの状態確認
```bash
./debug_langfuse.sh
```

2. 個別のログ確認
```bash
docker logs langfuse-langfuse-web-1 --tail 50
docker logs 2litellm-litellm-1 --tail 50
```

3. ネットワーク設定の確認
```bash
docker network inspect langfuse_default
```

## テストの実行

```bash
python test_litellm_langfuse.py
```

テストスクリプトは以下を実行します：
- LiteLLM を通じた Bedrock Claude の呼び出し
- Langfuse へのログ送信
- 接続テストとデバッグ情報の出力

## 企業での利用に関する推奨事項

本リポジトリは開発環境での利用を想定しています。本番環境では以下を推奨します：

- Amazon Elastic Container Service (Amazon ECS)/AWS Fargate でのコンテナ化デプロイ
- Amazon Relational Database Service (Amazon RDS)/Amazon Aurora PostgreSQL の使用
- AWS Secrets Manager での認証情報管理
- 適切なセキュリティ、スケーラビリティ設定

## Langfuse の利用方法

Langfuse は LLM アプリケーションの観察とモニタリングを行うためのオープンソースプラットフォームです。

### 基本概念

1. **トレース (Trace)**
   - LLM アプリケーションの1回の実行単位
   - ユーザーリクエストから応答までの一連の処理を追跡
   - 複数のスパンやイベントを含むことが可能

2. **スパン (Span)**
   - トレース内の個別の処理単位
   - LLM の推論、プロンプトの生成、外部APIコールなど
   - 処理時間、入出力、メタデータを記録

3. **イベント (Event)**
   - トレースやスパン内で発生する重要な出来事
   - エラー、警告、状態変更などを記録

### 主な機能

1. **LLM 利用状況の分析**
   - モデルごとの使用量とコスト
   - レイテンシと応答時間の分布
   - エラー率とその原因分析

2. **プロンプトの評価**
   - プロンプトのバージョン管理
   - A/Bテストの実施と結果分析
   - プロンプトの効果測定

3. **品質管理**
   - 応答品質のモニタリング
   - ユーザーフィードバックの収集
   - カスタム評価指標の設定

### 実装手順

1. **Python SDK のインストール**
```python
pip install langfuse
```

2. **Langfuse クライアントの初期化**
```python
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="your-public-key",
    secret_key="your-secret-key",
    host="http://langfuse-web:3000"  # Docker 環境の場合
)
```

3. **トレースの作成と管理**
```python
# トレースの開始
trace = langfuse.trace(name="my-llm-request")

# スパンの記録
with trace.span(name="llm-inference") as span:
    response = llm.generate(prompt)
    span.update(
        input={"prompt": prompt},
        output={"response": response},
        metadata={"model": "claude-3"}
    )

# イベントの記録
trace.event(
    name="user-feedback",
    metadata={"rating": 5}
)

# トレースの完了
trace.update(status="success")
```

### 分析とモニタリング

1. **ダッシュボード**
   - Langfuse UI (http://localhost:3000) にアクセス
   - プロジェクトの概要を確認
   - 詳細な利用統計を表示

2. **トレース検索**
   - 特定のトレースを検索
   - フィルタリングと並び替え
   - 詳細な実行ログの確認

3. **メトリクスの確認**
   - レイテンシグラフ
   - エラー率の推移
   - コスト分析

### カスタマイズと拡張

1. **カスタムメトリクス**
   - 独自の評価指標を定義
   - スコアリングルールの設定
   - ダッシュボードのカスタマイズ

2. **通知設定**
   - エラー発生時の通知
   - しきい値超過のアラート
   - 定期レポートの設定

3. **データエクスポート**
   - Amazon Simple Storage Service (Amazon S3) へのデータエクスポート
   - カスタム分析の実施
   - 外部システムとの連携
