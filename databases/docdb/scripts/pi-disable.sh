#!/bin/bash
# Performance Insights を無効化するスクリプト

# 引数チェック
if [ -z "$1" ]; then
  echo "使用方法: $0 <cluster-name>"
  echo "例: $0 docdb-2025-05-17-08-21-41"
  exit 1
fi

CLUSTER_NAME=$1

# インスタンスIDの取得
get_instance_id() {
  aws docdb describe-db-clusters --db-cluster-identifier $CLUSTER_NAME \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text
}

INSTANCE_ID=$(get_instance_id)

if [ -z "$INSTANCE_ID" ]; then
  echo "エラー: クラスター $CLUSTER_NAME のインスタンスIDを取得できませんでした。"
  exit 1
fi

echo "Performance Insights for DocumentDB インスタンスを無効化しています..."
aws docdb modify-db-instance \
  --db-instance-identifier $INSTANCE_ID \
  --no-enable-performance-insights

echo "Performance Insights が無効化されました。"
