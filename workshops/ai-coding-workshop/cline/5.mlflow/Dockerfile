FROM ghcr.io/berriai/litellm:main-latest

# 必要なパッケージのインストール（Alpine Linux用、最小限に）
RUN apk add --no-cache \
    curl \
    build-base

# ワーキングディレクトリを設定
WORKDIR /app

# 必要なファイルをコピー
COPY mlflow_callback.py .

# uv のインストール
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 依存関係をインストール（必要最小限の依存関係）
RUN uv pip install --system \
    boto3 \
    requests \
    mlflow \
    mlflow-skinny \
    sagemaker-mlflow

# インストールされたパッケージを確認
RUN uv pip list --system
