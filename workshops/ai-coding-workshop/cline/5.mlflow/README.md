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
├── manage-mlflow.sh          # MLflow 管理スクリプト
└── test_litellm_mlflow.py    # テストスクリプト
```

## コンポーネント構成

1. **AWS SageMaker MLflow**
   - バックエンドストア: AWS RDS (PostgreSQL)
   - アーティファクトストア: Amazon S3
   - セキュアなアクセス制御
   - スケーラブルなインフラストラクチャ

## セットアップ手順

1. 環境変数の設定
   ```bash
   # 環境変数の設定
   ../scripts/setup_env.sh .
   ```
   以下の環境変数が設定されます：
   - AWS 認証情報（AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY）
   - AWS リージョン（AWS_REGION_NAME）
   - MLflow トラッキングサーバー名（MLFLOW_TRACKING_SERVER_NAME）
   - MLflow 実験名（MLFLOW_EXPERIMENT_NAME）

2. MLflow サーバーの起動と設定
   ```bash
   # MLflow トラッキングサーバーの起動
   sudo ./manage-mlflow.sh start
   
   # LiteLLM の設定を MLflow 用に更新
   sudo ./manage-mlflow.sh update-config
   ```

git3. 動作確認
   ```bash
   # トラッキングサーバーの情報を取得
   sudo ./manage-mlflow.sh get-tracking-info
   
   # presigned URL を取得して MLflow UI にアクセス
   sudo ./manage-mlflow.sh get-url
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

AWS SageMaker MLflow の Web UI にアクセスするには、以下の手順を実行します：

1. presigned URL の取得
   ```bash
   sudo ./manage-mlflow.sh get-url
   ```
   - URL の有効期限: 5分（AWS の制限により）
   - セッション有効期限: 約5.5時間
   - 一度のみ使用可能

2. ブラウザでアクセス
   - 取得した presigned URL を使用
   - 実験一覧から "litellm-monitoring" を選択
   - 各実行の詳細を確認：
     - パラメータ（モデル、設定など）
     - メトリクス（レイテンシ、トークン数など）
     - アーティファクト（プロンプト、レスポンス）

### AWS SageMaker MLflow の管理

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
   # 環境変数が設定されていることを確認
   env | grep -E "AWS_|MLFLOW_"
   
   # CDKのデプロイ
   cd cdk
   npm install
   npx cdk deploy
   ```

#### MLflow トラッキングサーバーへのアクセス

1. **presigned URL の取得**
   ```bash
   sudo ./manage-mlflow.sh get-url
   ```
   - URL の有効期限: 5分（AWS の制限により）
   - セッション有効期限: 約5.5時間（20,000秒）
   - 一度のみ使用可能（セキュリティのため）

2. **環境変数の確認**
   ```bash
   # 環境変数が正しく設定されているか確認
   env | grep -E "AWS_|MLFLOW_"
   ```

3. **MLflow UI からの実験データ確認**
   - 取得した presigned URL を使用してアクセス
   - 実験データの閲覧と分析
   - メトリクスの可視化

#### 注意事項
- AWS CLI のインストールが必要
- 適切な AWS 認証情報の設定が必要
- CDK スタックのデプロイが必要
- presigned URL は一度のみ使用可能で、有効期限は 30 分に設定している

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
   # AWS 認証情報の確認
   aws configure list
   aws sts get-caller-identity
   
   # トラッキングサーバーの情報を再取得
   sudo ./manage-mlflow.sh get-tracking-info
   ```

2. **presigned URL の問題**
   ```bash
   # 新しい presigned URL を取得
   sudo ./manage-mlflow.sh get-url
   ```

3. **メトリクス記録の問題**
   ```bash
   # テストの実行
   sudo ./manage-mlflow.sh test
   ```

## 参考リンク

- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [AWS SageMaker MLflow](https://docs.aws.amazon.com/sagemaker/latest/dg/mlflow.html)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Langfuse Documentation](https://langfuse.com/docs)
