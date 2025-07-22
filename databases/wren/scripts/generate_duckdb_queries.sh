#!/bin/bash

# スクリプト名: generate_duckdb_queries.sh
# 説明: S3バケット内のCSVファイルを読み込むためのDuckDBクエリを生成する

# https://duckdb.org/docs/stable/core_extensions/httpfs/s3api.html

# 現在のディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# .envファイルを読み込む
source "$PROJECT_DIR/.env"

# 出力ファイル
OUTPUT_FILE="$SCRIPT_DIR/duckdb_import_queries.sql"

# 環境変数の確認
if [ -z "$BUCKET_NAME" ]; then
  echo "エラー: BUCKET_NAME環境変数が設定されていません"
  exit 1
fi

if [ -z "$AWS_REGION_NAME" ]; then
  echo "警告: AWS_REGION_NAME環境変数が設定されていません。デフォルト値 'us-east-1' を使用します"
  AWS_REGION_NAME="us-east-1"
fi

echo "S3バケット内のCSVファイルをリストアップしています..."
# S3バケット内のCSVファイルをリストアップ
CSV_FILES=$(aws s3 ls "s3://$BUCKET_NAME/data/" --recursive | grep "\.csv$" | awk '{print $4}')

if [ -z "$CSV_FILES" ]; then
  echo "警告: S3バケット内にCSVファイルが見つかりませんでした"
  # デフォルトのファイルリストを使用
  CSV_FILES="data/customers.csv data/orders.csv data/products.csv data/order_items.csv"
fi

# DuckDBクエリの生成
echo "DuckDBクエリを生成しています..."

# ファイルの先頭にシークレット作成クエリを書き込む
cat > "$OUTPUT_FILE" << EOF
-- DuckDBのS3インポートクエリ
-- 生成日時: $(date)

-- S3シークレットの作成
CREATE OR REPLACE SECRET s3_secret (
    TYPE s3,
    PROVIDER config,
    KEY_ID '${AWS_ACCESS_KEY_ID}',
    SECRET '${AWS_SECRET_ACCESS_KEY}',
    REGION '${AWS_REGION_NAME}'
);

EOF

# 各CSVファイルに対するCREATE TABLE文を生成
for CSV_FILE in $CSV_FILES; do
  # ファイル名からテーブル名を抽出（パスとファイル拡張子を除去）
  TABLE_NAME=$(basename "$CSV_FILE" .csv)
  
  # CREATE TABLE文を生成
  cat >> "$OUTPUT_FILE" << EOF
-- ${TABLE_NAME}テーブルの作成
CREATE TABLE ${TABLE_NAME} AS 
SELECT * FROM 's3://${BUCKET_NAME}/${CSV_FILE}';

EOF
done

echo "scripts/duckdb_import_queries.sql を確認してください。"