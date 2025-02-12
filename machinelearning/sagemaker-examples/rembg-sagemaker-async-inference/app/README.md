# SageMaker 非同期推論による背景除去の実装

このディレクトリには、rembgライブラリを使用した背景除去のためのSageMaker非同期推論エンドポイントの実装が含まれています。

## 概要

この実装はSageMaker非同期推論の仕様に従い、以下のファイルで構成されています：

- `inference.py`: 非同期推論リクエストを処理するFastAPIアプリケーション
- `Dockerfile`: 推論エンドポイント用のコンテナ設定
- `serve`: FastAPIアプリケーションを起動するスクリプト
- `build_and_push.sh`: ECRへのイメージビルド・プッシュスクリプト
- `setup_and_deploy.sh`: セットアップとデプロイの自動化スクリプト
- `.env`: 環境変数設定ファイル（gitignore対象）
- `.env.sample`: 環境変数設定ファイルのサンプル（git管理対象）

## 環境変数の設定

1. `.env.sample` を `.env` にコピーします：
```bash
cp .env.sample .env
```

2. `.env` ファイルを編集し、必要な値を設定します：

```bash
# AWS Account and Region
AWS_ACCOUNT_ID=<AWSアカウントID>
AWS_REGION=<リージョン>

# ECR Repository
ECR_REPO=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/rembg-async-app

# SageMaker Configuration
SAGEMAKER_ROLE_ARN=<SageMaker実行ロールのARN>
SAGEMAKER_MODEL_NAME=rembg-async-app
SAGEMAKER_ENDPOINT_NAME=rembg-async-app
SAGEMAKER_INSTANCE_TYPE=ml.g4dn.xlarge

# S3 Buckets
INPUT_BUCKET=<入力用S3バケット名>
OUTPUT_BUCKET=<出力用S3バケット名>

# SNS Topics
SUCCESS_TOPIC_ARN=<成功通知用SNSトピックARN>
ERROR_TOPIC_ARN=<エラー通知用SNSトピックARN>

# Runtime Configuration
USE_GPU=true
MAX_CONCURRENT_INVOCATIONS=4
MODEL_NAME=u2net
MODEL_PATH=/opt/ml/model
```

## API仕様

エンドポイントは以下の形式のリクエストを受け付けます（InvokeEndpointAsync APIに準拠）：

```json
{
    "InputLocation": "s3://input-bucket/input-key",
    "OutputLocation": "s3://output-bucket/output-key"
}
```

### レスポンス形式

成功時のレスポンス：
```json
{
    "status": "success",
    "output_location": "s3://output-bucket/output-key"
}
```

エラー時のレスポンス：
```json
{
    "detail": "エラーメッセージ"
}
```

## エンドポイント

- `/invocations`: 非同期推論用メインエンドポイント
- `/ping`: ヘルスチェック用エンドポイント

## ビルドとデプロイ

1. 環境変数の設定
```bash
cp .env.sample .env
# .envファイルを編集して必要な値を設定
```

2. セットアップとデプロイの実行
```bash
./setup_and_deploy.sh
```

このスクリプトは以下の処理を実行します：
- 環境変数に基づいてDockerイメージをビルド（GPU/CPU対応）
- ECRへのイメージプッシュ
- 依存関係のインストール
- SageMaker非同期推論エンドポイントのデプロイ

## CDKデプロイ後の環境変数設定

CDKデプロイ後に出力されるAWSリソース情報を環境変数として保存するには、以下のスクリプトを実行します：

```bash
# CDKのアウトプットをJSONとして保存
npx cdk deploy --outputs-file cdk-outputs.json

# 環境変数として保存
# FIXME: update_env.py がないので作成してください。既存の .env が存在する場合はその情報を破壊しないように気を付けてください。
python update_env.py
```

これにより、CDKで作成されたリソースの情報が自動的に.envファイルに追加されます。

## ローカルでのテスト

1. Dockerイメージのビルド：
```bash
docker build -t rembg-async --build-arg TARGET_PLATFORM=cpu-base .
```

2. ローカルでの実行：
```bash
docker run -p 8080:8080 rembg-async
```

# FIXME: テストがないので curl コマンドを提供してください。

# FIXME: デプロイしたエンドポイントへのリクエストを行う python スクリプトを作成してください。SNS の情報を確認して S3 の出力画像をローカルに落とす処理も実装してほしいです。

## SageMakerとの統合

この実装は、SageMaker Python SDKまたはAWSコンソールを使用してSageMaker非同期推論エンドポイントとしてデプロイできます。エンドポイントは、S3統合を通じて非同期推論リクエストを自動的に処理します。