#!/bin/bash
# Performance Insights を有効化し、必要な IAM 権限を設定するスクリプト

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

echo "Performance Insights for DocumentDB インスタンスを有効化しています..."
echo "ステップ 1: Performance Insights の有効化..."
aws docdb modify-db-instance \
  --db-instance-identifier $INSTANCE_ID \
  --enable-performance-insights

echo ""
echo "ステップ 2: 必要な IAM 権限の設定..."
echo ""

# 現在のユーザー/ロールの取得
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "現在の実行アイデンティティ: $CURRENT_USER"
echo ""

# 既存のポリシーの確認と削除
echo "IAM ポリシーの設定..."
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`DocumentDBPerformanceInsightsPolicy`].Arn' --output text)

if [ -n "$POLICY_ARN" ]; then
  echo "既存のポリシーを削除しています（ARN: $POLICY_ARN）..."
  
  # 現在のユーザー/ロールからポリシーをデタッチ
  if echo $CURRENT_USER | grep -q "assumed-role"; then
    ROLE_NAME=$(echo $CURRENT_USER | sed -n 's/.*assumed-role\/\([^/]*\)\/.*/\1/p')
    echo "ロール $ROLE_NAME からポリシーをデタッチしています..."
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN" || true
  else
    USER_NAME=$(echo $CURRENT_USER | sed -n 's/.*user\/\([^/]*\).*/\1/p')
    if [ -n "$USER_NAME" ]; then
      echo "ユーザー $USER_NAME からポリシーをデタッチしています..."
      aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN" || true
    fi
  fi

  # すべてのポリシーバージョンを取得して削除
  echo "ポリシーバージョンを削除しています..."
  VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?!IsDefaultVersion].VersionId' --output text)
  if [ -n "$VERSIONS" ]; then
    for VERSION in $VERSIONS; do
      echo "- バージョン $VERSION を削除"
      aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$VERSION"
    done
  fi
  
  # ポリシーを削除
  echo "ポリシーを削除しています..."
  aws iam delete-policy --policy-arn "$POLICY_ARN"
  
  # 削除の確認
  sleep 5  # 削除が反映されるまで少し待機
  NEW_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`DocumentDBPerformanceInsightsPolicy`].Arn' --output text)
  if [ -n "$NEW_POLICY_ARN" ]; then
    echo "エラー: 既存のポリシーの削除に失敗しました。"
    exit 1
  fi
  echo "既存のポリシーを正常に削除しました。"
fi

# 新しいポリシーを作成
echo "新しいポリシーを作成しています..."
POLICY_ARN=$(aws iam create-policy --policy-name DocumentDBPerformanceInsightsPolicy --policy-document file://pi-policy.json --query 'Policy.Arn' --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "エラー: IAM ポリシーの作成に失敗しました。"
  exit 1
fi

echo "ポリシーを作成しました（ARN: $POLICY_ARN）"

# ポリシーをアタッチ
if echo $CURRENT_USER | grep -q "assumed-role"; then
  echo "IAM ロールを検出しました。ロールにポリシーをアタッチしています..."
  ROLE_NAME=$(echo $CURRENT_USER | sed -n 's/.*assumed-role\/\([^/]*\)\/.*/\1/p')
  echo "ロール名: $ROLE_NAME"
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN" || \
    (echo "エラー: ロールへのポリシーのアタッチに失敗しました。"; exit 1)
  echo "ポリシーをロール $ROLE_NAME にアタッチしました。"
else
  echo "IAM ユーザーを検出しました。ユーザーにポリシーをアタッチしています..."
  USER_NAME=$(echo $CURRENT_USER | sed -n 's/.*user\/\([^/]*\).*/\1/p')
  echo "ユーザー名: $USER_NAME"
  if [ -n "$USER_NAME" ]; then
    aws iam attach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN" || \
      (echo "エラー: ユーザーへのポリシーのアタッチに失敗しました。"; exit 1)
    echo "ポリシーをユーザー $USER_NAME にアタッチしました。"
  else
    echo "エラー: ユーザー名を特定できませんでした。"
    exit 1
  fi
fi

echo ""
echo "Performance Insights が有効化され、必要な権限が設定されました。"
echo "データの収集が開始されるまで数分お待ちください。"
