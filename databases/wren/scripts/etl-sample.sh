#!/bin/bash

# 環境変数読み込み
source .env

# 一時ディレクトリ作成
mkdir -p tmp_data

# PostgreSQL接続情報を環境変数から取得（設定されていない場合はデフォルト値を使用）
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-15432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-postgres}

# PostgreSQL からデータ取得
echo "Extracting data from PostgreSQL..."
echo "PostgreSQL接続情報: host=$POSTGRES_HOST, port=$POSTGRES_PORT, user=$POSTGRES_USER, database=$POSTGRES_DB"
docker exec wrenai-postgres-1 sh -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"COPY (SELECT * FROM customers ORDER BY id DESC LIMIT 100) TO STDOUT WITH CSV HEADER\"" > tmp_data/customers.csv
docker exec wrenai-postgres-1 sh -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"COPY (SELECT * FROM orders ORDER BY id DESC LIMIT 100) TO STDOUT WITH CSV HEADER\"" > tmp_data/orders.csv
docker exec wrenai-postgres-1 sh -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"COPY (SELECT * FROM products ORDER BY id DESC LIMIT 100) TO STDOUT WITH CSV HEADER\"" > tmp_data/products.csv
docker exec wrenai-postgres-1 sh -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"COPY (SELECT * FROM order_items ORDER BY id DESC LIMIT 100) TO STDOUT WITH CSV HEADER\"" > tmp_data/order_items.csv

# S3 にアップロード
echo "Loading data to S3..."
aws s3 cp tmp_data/customers.csv s3://$BUCKET_NAME/data/customers.csv
aws s3 cp tmp_data/orders.csv s3://$BUCKET_NAME/data/orders.csv
aws s3 cp tmp_data/products.csv s3://$BUCKET_NAME/data/products.csv
aws s3 cp tmp_data/order_items.csv s3://$BUCKET_NAME/data/order_items.csv

# 一時ファイル削除
rm -rf tmp_data

echo "ETL process completed successfully!"
echo "Data uploaded to s3://$BUCKET_NAME/data/"
