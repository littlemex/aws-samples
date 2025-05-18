#!/bin/bash
# Performance Insights からリソースメトリクスを取得するスクリプト

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

echo "インスタンスのリソースメトリクスを取得しています..."
aws pi get-resource-metrics \
  --service-type DOCDB \
  --identifier $INSTANCE_ID \
  --start-time $(date -u --date="1 hour ago" "+%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u "+%Y-%m-%dT%H:%M:%SZ") \
  --period-in-seconds 60 \
  --metric-queries '[{"Metric": "os.cpuUtilization.user.avg"}, {"Metric": "os.cpuUtilization.idle.avg"}]'

if [ $? -ne 0 ]; then
  echo ""
  echo "エラー: リソースメトリクスの取得に失敗しました。"
  echo "Performance Insights が有効化されており、適切な権限があることを確認してください。"
  echo "セットアップするには以下を実行してください:"
  echo "./scripts/pi-enable.sh $CLUSTER_NAME"
  exit 1
fi
