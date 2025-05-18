#!/bin/bash
# Performance Insights API キーを取得するスクリプト

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

echo "Performance Insights API キーを取得しています..."
aws docdb describe-db-instances \
  --db-instance-identifier $INSTANCE_ID \
  --query 'DBInstances[0].PerformanceInsightsKeyId' \
  --output text

if [ $? -ne 0 ]; then
  echo ""
  echo "エラー: Performance Insights API キーの取得に失敗しました。"
  echo "Performance Insights が有効化されていることを確認してください。"
  echo "有効化するには以下を実行してください:"
  echo "./scripts/pi-enable.sh $CLUSTER_NAME"
  exit 1
fi
