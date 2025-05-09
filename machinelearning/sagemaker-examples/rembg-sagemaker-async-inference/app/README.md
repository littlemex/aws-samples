# SageMaker 非同期推論による背景除去の実装

このディレクトリには、rembgライブラリを使用した背景除去のためのSageMaker非同期推論エンドポイントの実装が含まれています。
GPU を利用する場合は CUDA Version, NVCC Version を適切なものにして下さい。

## 概要

この実装はSageMaker非同期推論の仕様に従い、以下のファイルで構成されています：

- `inference.py`: 非同期推論リクエストを処理するFastAPIアプリケーション
  - `inference_processor.py`
  - `cloudwatch_metrics.py`
  - `rembg_handler.py`
- `Dockerfile`: 推論エンドポイント用のコンテナ設定
- `serve`: FastAPIアプリケーションを起動するスクリプト
- `update_env.py`: CDKデプロイ後の環境変数を.envファイルに反映するスクリプト
- `download_models.py`: モデルをダウンロードするスクリプト
- `build_and_push.sh`: ECRへのイメージビルド・プッシュスクリプト
- `setup_and_deploy.sh`: セットアップとデプロイの自動化スクリプト
- `request_endpoint.py`: 推論リクエスト用のスクリプト
- `.env`: 環境変数設定ファイル（.gitignore対象）

## API仕様

エンドポイントは以下の形式のリクエストを受け付けます（[InvokeEndpointAsync API](https://boto3.amazonaws.com/v1/documentation/api/1.26.83/reference/services/sagemaker-runtime/client/invoke_endpoint_async.html)に準拠）：

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
docker run --rm -p 8080:8080 -e USE_AWS=false \
  -v $(pwd)/local-bucket:/opt/ml/code/local-bucket \
  -v $(pwd)/models:/opt/ml/model rembg-async-app:cpu

# GPU 推論
docker run --rm --gpus all -p 8080:8080 -e USE_AWS=false \
  -v $(pwd)/local-bucket:/opt/ml/code/local-bucket \
  -v $(pwd)/models:/opt/ml/model rembg-async-app:gpu

# デバッグモード
docker run --rm --gpus all -p 8080:8080 -e USE_AWS=false -e DEBUG=true \
  -v $(pwd):/opt/ml/code \
  -v $(pwd)/models:/opt/ml/model rembg-async-app:gpu
```

3. ローカルでのテスト:

```bash
USE_AWS=false uv run request_endpoint.py local-bucket/examples/anime-girl-3.jpg --output-dir local-bucket/outputs
```

## SageMaker エンドポイントのデプロイ

4. セットアップとデプロイの実行

```bash
bash -x ./setup_and_deploy.sh

# model upload と image ビルドをスキップ
bash -x setup_and_deploy.sh --skip-model-upload --skip-image-build
```

このスクリプトは以下の処理を実行します：
- 環境変数に基づいてDockerイメージをビルド（GPU/CPU対応）
- ECRへのイメージプッシュ
- 依存関係のインストール
- SageMaker非同期推論エンドポイントのデプロイ

5. SageMaker 非同期推論エンドポイントへのテスト:

```bash
USE_AWS=true uv run request_endpoint.py local-bucket/examples/anime-girl-3.jpg --output-dir local-bucket/outputs
```

```bash
$ time USE_AWS=true uv run request_endpoint.py local-bucket/examples/anime-girl-3.jpg --output-dir local-bucket/outputs
2025-02-20 05:51:22,998 - INFO - Mode: AWS
2025-02-20 05:51:23,152 - INFO - Output path prepared: local-bucket/outputs/anime-girl-3_output.png
2025-02-20 05:51:23,152 - INFO - Processing input file: local-bucket/examples/anime-girl-3.jpg
2025-02-20 05:51:23,152 - INFO - Input key prepared: input/anime-girl-3.jpg
2025-02-20 05:51:23,152 - INFO - Output key prepared: output/anime-girl-3_output.png
2025-02-20 05:51:23,152 - INFO - Uploading input file to S3: バケット名/input/anime-girl-3.jpg
2025-02-20 05:51:24,155 - INFO - Input location prepared: s3://バケット名/input/anime-girl-3.jpg
2025-02-20 05:51:24,155 - INFO - Local output location prepared: local-bucket/outputs/anime-girl-3_output.png
2025-02-20 05:51:24,155 - INFO - Sending async inference request to endpoint: rembg-async-app
2025-02-20 05:51:24,155 - INFO - Output will be saved to: s3://バケット名/output/anime-girl-3_output.png
2025-02-20 05:51:24,979 - INFO - Waiting for processing completion. Inference ID: 1739998284.1555774
2025-02-20 05:51:24,979 - INFO - Checking output file existence (attempt 1/30)
2025-02-20 05:51:25,624 - INFO - Output file found in S3
2025-02-20 05:51:25,624 - INFO - Downloading result from S3: バケット名/output/anime-girl-3_output.png
2025-02-20 05:51:26,778 - INFO - Output image saved to: local-bucket/outputs/anime-girl-3_output.png

real    0m4.163s
user    0m0.571s
sys     0m0.114s
```