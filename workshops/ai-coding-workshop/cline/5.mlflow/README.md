# LiteLLM と Langfuse/MLflow を用いた LLM 利用状況の分析

本セクションでは、Cline VSCode Plugin で LiteLLM を API Provider として使用する際の詳細な利用状況を分析するための Langfuse と MLflow の統合について説明します。この構成により、以下のような情報を詳細に把握することが可能になります：

- LLM の利用状況とコスト分析（Langfuse）
- リクエスト・レスポンスの詳細な記録（Langfuse）
- パフォーマンスとレイテンシの監視（Langfuse/MLflow）
- エラー発生時のトラブルシューティング（Langfuse/MLflow）
- モデルのパフォーマンス指標の追跡（MLflow）
- 実験管理と比較分析（MLflow）

## 前提条件

このディレクトリは以下のコンポーネントが既に設定・実行されていることを前提としています：

1. LiteLLM Proxy（`2.litellm/`）
   - LiteLLM サーバーが実行中
   - 設定ファイルが適切に構成済み

2. Langfuse（`4.langfuse/`）
   - Langfuse サーバーが実行中
   - 必要な認証情報が設定済み

## ファイル構成

```
.
├── .env.example                # 環境変数のテンプレート
├── docker-compose.yml          # MLflow の Docker Compose 設定
├── litellm_config.yml         # LiteLLM の設定ファイル（MLflow 連携用）
├── mlflow_callback.py         # MLflow コールバック実装
├── detect_sagemaker_mlflow.py # SageMaker MLflow エンドポイント検出スクリプト
├── manage-mlflow.sh          # MLflow 管理スクリプト
└── test_litellm_mlflow.py    # テストスクリプト
```

## アーキテクチャ

```mermaid
graph TB
    subgraph "Local Development"
        direction LR
        CP[Cline Plugin] --> LL[LiteLLM Proxy<br/>(2.litellm)]
        LL --> LF[Langfuse<br/>(4.langfuse)]
        LL --> MF[MLflow Server<br/>(5.mlflow)]
        
        subgraph "Docker Networks"
            subgraph "langfuse_default"
                LF
            end
            subgraph "mlflow-network"
                MF
                DB[(PostgreSQL)]
                MF --> DB
                VOL[Artifacts<br/>Volume]
                MF --> VOL
            end
        end
    end
    
    subgraph "AWS Deployment"
        direction LR
        CP2[Cline Plugin] --> LL2[LiteLLM Proxy]
        LL2 --> LF2[Langfuse]
        LL2 --> SM[SageMaker MLflow]
    end
```

## コンポーネント構成

1. **MLflow Server**
   - バックエンドストア: PostgreSQL
   - アーティファクトストア: ローカルファイルシステム（Docker ボリューム）
   - デバッグログ有効化
   - Gunicorn ワーカー設定

2. **PostgreSQL**
   - MLflow のメタデータ保存
   - 実験、パラメータ、メトリクスの管理
   - データの永続化（Docker ボリューム）

3. **Docker ボリューム**
   - `postgres-data`: PostgreSQL データの永続化
   - `mlflow-artifacts`: MLflow アーティファクトの永続化

## セットアップ手順

1. 環境変数の設定
   ```bash
   cp .env.example .env
   ```
   以下の環境変数を設定します：
   - MLflow 関連の設定
   - AWS 認証情報（SageMaker MLflow 使用時）

2. MLflow サーバーの起動
   ```bash
   # MLflow コンテナの起動
   ./manage-mlflow.sh start
   
   # LiteLLM の設定を MLflow 用に更新（既存の LiteLLM を MLflow に接続）
   ./manage-mlflow.sh update-config
   ```

3. 動作確認
   ```bash
   # ポートフォワーディングの設定 (Local PC で実行してください)
   ../scripts/port_forward.py
   
   # ブラウザで MLflow UI にアクセス
   # MLflow: http://localhost:5000
   ```

## MLflow の利用方法

[MLflow](https://mlflow.org/) は機械学習のライフサイクル管理のためのオープンソースプラットフォームです。本プロジェクトでは、LLM の実験管理とメトリクス追跡に使用します。

### MLflow の主要機能

1. **実験管理**：
   - 各 LLM リクエストを実験として記録
   - パラメータ（モデル、温度など）の追跡
   - メトリクス（レイテンシ、トークン数、コストなど）の記録

2. **メトリクス可視化**：
   - リアルタイムなメトリクス追跡
   - カスタムチャートとダッシュボード
   - 実験間の比較分析

3. **アーティファクト管理**：
   - プロンプトとレスポンスのテキスト保存
   - エラーログの保存
   - カスタムデータの保存

### MLflow Web UI の利用方法

#### ローカル環境

1. ブラウザで http://localhost:5000 にアクセス
2. 実験一覧から "litellm-monitoring" を選択
3. 各実行の詳細を確認：
   - パラメータ（モデル、設定など）
   - メトリクス（レイテンシ、トークン数など）
   - アーティファクト（プロンプト、レスポンス）

#### AWS SageMaker MLflow

AWS SageMaker MLflow は CDK を使用してインフラストラクチャをコードとして管理します。

#### CDK による MLflow インフラストラクチャの定義

`cdk/` ディレクトリには以下のコンポーネントが含まれています：

1. **MLflow スタック（`lib/mlflow-stack.ts`）**
   - S3 バケット: MLflow アーティファクトストア用
   - IAM ロール: SageMaker サービス用
   - MLflow トラッキングサーバー
   - スタック出力:
     - サーバー ARN
     - バケット名
     - ロール ARN

2. **デプロイ手順**
   ```bash
   # 環境変数の設定
   cp .env.example .env
   # 必要に応じて CDK_COMMAND を設定（デフォルトは "npx cdk"）
   # export CDK_COMMAND="cdk"  # システムにグローバルインストールされている場合
   
   # デプロイの実行
   cd cdk
   ${CDK_COMMAND:-npx cdk} deploy
   ```

#### MLflow トラッキングサーバーへのアクセス

1. **presigned URL の取得**
   ```bash
   ./manage-mlflow.sh get-url
   ```
   - URL の有効期限: 30分（AWS の制限により）
   - セッション有効期限: 30分（最小値）
   - 一度のみ使用可能

2. **エンドポイントの検出**
   ```bash
   ./manage-mlflow.sh detect-aws
   ```

3. **環境変数の更新を確認**
   ```bash
   cat .env
   ```

4. **MLflow UI からの実験データ確認**
   - 取得した presigned URL を使用してアクセス
   - 実験データの閲覧と分析
   - メトリクスの可視化

#### 注意事項
- AWS CLI のインストールが必要
- 適切な AWS 認証情報の設定が必要
- CDK スタックのデプロイが必要
- presigned URL は一度のみ使用可能で、有効期限は 30 分

### カスタムメトリクスの追加

`mlflow_callback.py` を編集することで、追加のメトリクスを記録できます：

```python
# メトリクスの例
metrics = {
    "latency_ms": latency,
    "prompt_tokens": usage.get("prompt_tokens", 0),
    "completion_tokens": usage.get("completion_tokens", 0),
    "total_tokens": usage.get("total_tokens", 0),
    "cost_usd": cost,
    # カスタムメトリクスを追加
    "your_metric": value
}
```

## トラブルシューティング

### MLflow 関連の問題

1. **接続エラー**
   ```bash
   # MLflow サービスのステータス確認
   ./manage-mlflow.sh status
   
   # ログの確認
   ./manage-mlflow.sh logs
   ```

2. **SageMaker エンドポイント検出の問題**
   ```bash
   # AWS 認証情報の確認
   aws configure list
   
   # エンドポイント再検出
   ./manage-mlflow.sh detect-aws
   ```

3. **メトリクス記録の問題**
   ```bash
   # テストの実行
   ./manage-mlflow.sh test
   ```

## 参考リンク

- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [AWS SageMaker MLflow](https://docs.aws.amazon.com/sagemaker/latest/dg/mlflow.html)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Langfuse Documentation](https://langfuse.com/docs)
