# SageMaker 非同期推論による背景除去の実装

このディレクトリには、rembgライブラリを使用した背景除去のためのSageMaker非同期推論エンドポイントの実装が含まれています。

## 概要

この実装はSageMaker非同期推論の仕様に従い、以下のファイルで構成されています：

- `inference.py`: 非同期推論リクエストを処理するFastAPIアプリケーション
- `update_env.py`: CDKデプロイ後の環境変数を.envファイルに反映するスクリプト
- `Dockerfile`: 推論エンドポイント用のコンテナ設定
- `serve`: FastAPIアプリケーションを起動するスクリプト
- `build_and_push.sh`: ECRへのイメージビルド・プッシュスクリプト
- `setup_and_deploy.sh`: セットアップとデプロイの自動化スクリプト
- `.env`: 環境変数設定ファイル（.gitignore対象）

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

1. CDK デプロイ

```bash
# cdk-outputs.jsonの名前を変えないでください, .env作成のためにこのjsonを利用します
cd cdk && npx npm install && npx cdk deploy --outputs-file cdk-outputs.json
```

2. 環境変数の設定

これにより、CDKで作成されたリソースの情報が自動的に.envファイルに追加されます。

```bash
uv sync && cd app && uv run update_env.py
```

## ローカルでのテスト

1. Dockerイメージのビルド：

```bash
# CPU 推論
bash -x build_and_push.sh
# GPU 推論 (USE_GPU=true) で設定してもよい
bash -x build_and_push.sh --gpu
```

2. ローカルでの実行：
```bash
# モデルのダウンロード
uv run download_models.py

# CPU 推論
docker run -p 8080:8080 -e USE_AWS=false \
  -v $(pwd)/local-bucket:/opt/ml/code/local-bucket \
  -v $(pwd)/models:/opt/ml/model rembg-async-app:cpu

# GPU 推論
docker run --gpus all -p 8080:8080 -e USE_AWS=false \
  -v $(pwd)/local-bucket:/opt/ml/code/local-bucket \
  -v $(pwd)/models:/opt/ml/model rembg-async-app:gpu
```

3. ローカルでのテスト:

```bash
 USE_AWS=false uv run request_endpoint.py examples/anime-girl-3.jpg --output-dir ./outputs
```

## SageMaker エンドポイントのデプロイ

3. セットアップとデプロイの実行

```bash
bash -x ./setup_and_deploy.sh
```

このスクリプトは以下の処理を実行します：
- 環境変数に基づいてDockerイメージをビルド（GPU/CPU対応）
- ECRへのイメージプッシュ
- 依存関係のインストール
- SageMaker非同期推論エンドポイントのデプロイ


### ローカルテスト

1. ローカルディレクトリの準備：
```bash
mkdir -p test/input test/output
```

2. テスト画像の配置：
```bash
# テスト用の画像をinputディレクトリに配置
cp your-image.jpg test/input/
```

3. ローカルテスト用のcurlコマンド：
```bash
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{
    "InputLocation": "file://test/input/your-image.jpg",
    "OutputLocation": "file://test/output/result.png"
  }'
```

### SageMaker非同期推論エンドポイントのテスト

```bash
# 環境変数の設定
ENDPOINT_NAME=$(aws sagemaker list-endpoints --query "Endpoints[?EndpointName.contains(@, 'rembg-async')].EndpointName" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

# テスト用の画像をS3にアップロード
aws s3 cp your-image.jpg s3://${INPUT_BUCKET}/test/input/

# 非同期推論リクエストの実行
aws sagemaker-runtime invoke-endpoint-async \
  --endpoint-name ${ENDPOINT_NAME} \
  --input-location s3://${INPUT_BUCKET}/test/input/your-image.jpg \
  --output-location s3://${OUTPUT_BUCKET}/test/output/result.png \
  --content-type application/json \
  output.json

# 結果の確認
cat output.json
```

# FIXME: デプロイしたエンドポイントへのリクエストを行う python スクリプトを作成してください。SNS の情報を確認して S3 の出力画像をローカルに落とす処理も実装してほしいです。