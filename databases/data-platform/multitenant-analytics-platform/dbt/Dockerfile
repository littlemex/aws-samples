# dbt-glue Docker環境
FROM python:3.11-slim

# 作業ディレクトリ設定
WORKDIR /usr/app/dbt

# システムパッケージの更新とインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Python依存関係のインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# dbtプロジェクトをコピー
COPY . .

# dbtプロファイルディレクトリの作成
RUN mkdir -p /root/.dbt

# ポート番号（Interactive Sessions用）
EXPOSE 8998

# エントリーポイント
ENTRYPOINT ["dbt"]
