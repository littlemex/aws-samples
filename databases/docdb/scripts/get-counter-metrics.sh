#!/bin/bash
# Performance Insights からカウンターメトリクスを取得するスクリプト

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

echo "インスタンスのカウンターメトリクスを取得しています..."
echo "注意: この操作には Performance Insights が有効化されており、適切な IAM 権限が必要です。"
echo "権限エラーが発生した場合は、'./scripts/pi-enable.sh $CLUSTER_NAME' を実行してください。"
echo ""

aws pi get-resource-metrics \
  --service-type DOCDB \
  --identifier $INSTANCE_ID \
  --start-time $(date -u --date="1 hour ago" "+%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u "+%Y-%m-%dT%H:%M:%SZ") \
  --period-in-seconds 60 \
  --metric-queries '[{"Metric": "blks_read.avg"}, {"Metric": "blks_hit.avg"}, {"Metric": "xact_commit.avg"}]'

if [ $? -ne 0 ]; then
  echo ""
  echo "エラー: カウンターメトリクスの取得に失敗しました。"
  echo "以下の理由が考えられます:"
  echo "1. Performance Insights がこのインスタンスで有効化されていない"
  echo "2. IAM ユーザー/ロールに必要な権限がない"
  echo "3. インスタンスが Performance Insights をサポートしていない"
  echo ""
  echo "Performance Insights を有効化し、必要な権限を設定するには、以下を実行してください:"
  echo "./scripts/pi-enable.sh $CLUSTER_NAME"
  exit 1
fi
