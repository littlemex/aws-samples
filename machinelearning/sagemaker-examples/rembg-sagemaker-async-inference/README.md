# Rembg SageMaker Async Inference

このプロジェクトは、[rembg](https://github.com/danielgatis/rembg)を使用して画像から背景を削除するSageMaker Async Inferenceエンドポイントを提供します。

## 機能

- SageMaker Async Inferenceによる非同期推論
- CPU/GPU切り替え対応
- S3を使用した入出力
- CDKによるインフラストラクチャのデプロイ

## 前提条件

- Python 3.9以上
- AWS CLI
- AWS CDK
- Docker

## セットアップ手順

1. CDKを使用してS3バケットを作成

```bash
cd cdk
cdk deploy
```

デプロイ後、以下の情報が出力されます：
- 入力用S3バケット名
- 出力用S3バケット名
- SageMaker実行ロールARN

2. Dockerイメージのビルドとプッシュ

```bash
cd ../container
# CPUイメージのビルド
docker build --build-arg CUDA_ENABLED=0 -t rembg-async-cpu .
# GPUイメージのビルド
docker build --build-arg CUDA_ENABLED=1 -t rembg-async-gpu .

# ECRにプッシュ
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
aws ecr create-repository --repository-name rembg-async
docker tag rembg-async-cpu:latest <account>.dkr.ecr.<region>.amazonaws.com/rembg-async:cpu
docker tag rembg-async-gpu:latest <account>.dkr.ecr.<region>.amazonaws.com/rembg-async:gpu
docker push <account>.dkr.ecr.<region>.amazonaws.com/rembg-async:cpu
docker push <account>.dkr.ecr.<region>.amazonaws.com/rembg-async:gpu
```

## ローカルでの動作確認

```bash
export MODEL_PATH=../models
uvicorn inference:app --host 0.0.0.0 --port 8080
```

1. コンテナの起動

```bash
# CPUバージョンの場合
docker run -p 8080:8080 --rm rembg-async:cpu -v $(pwd)/models/u2net.onnx:/opt/ml/model/u2net.onnx

# GPUバージョンの場合（GPUが利用可能な環境で）
docker run -p 8080:8080 --gpus all --rm rembg-async:gpu
```

2. 動作確認

別のターミナルで以下のコマンドを実行して動作確認ができます：

```bash
# テスト用の画像を用意
curl -o test.jpg https://example.com/sample.jpg  # テスト用画像のURLを指定

# curlでリクエストを送信
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{
    "bucket": "local-test",
    "key": "test.jpg"
  }' \
  --data-binary @test.jpg
```

正常に動作している場合、背景が削除された画像データがレスポンスとして返されます。

3. コンテナの停止

Ctrl+Cでコンテナを停止できます。

## エンドポイントのデプロイ

```bash
python deploy_endpoint.py \
    --role-arn <SageMaker実行ロールARN> \
    --image-uri <ECRイメージURI> \
    --input-bucket <入力バケット名> \
    --output-bucket <出力バケット名> \
    --use-gpu  # GPUを使用する場合
```

## 使用方法

1. 画像を入力バケットにアップロード

```bash
aws s3 cp image.jpg s3://<input-bucket>/input/image.jpg
```

2. 非同期推論の実行

```python
import boto3
import json

runtime = boto3.client('sagemaker-runtime')

input_location = f"s3://<input-bucket>/input/image.jpg"
response = runtime.invoke_endpoint_async(
    EndpointName='rembg-async',
    InputLocation=input_location,
    ContentType='application/json',
    Body=json.dumps({
        "bucket": "<input-bucket>",
        "key": "input/image.jpg"
    })
)

# 出力は自動的にoutput_bucketの指定されたパスに保存されます
```

## 環境変数

- `CUDA_ENABLED`: GPUを使用する場合は"1"、CPUを使用する場合は"0"
- `MODEL_NAME`: 使用するモデル名（デフォルト: "u2net"）

## 注意事項

- GPUインスタンスを使用する場合でも、GPUが利用できない場合は自動的にCPUにフォールバックします
- 非同期推論の結果は指定された出力バケットに保存されます
- 処理状態は CloudWatch Logs で確認できます

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。