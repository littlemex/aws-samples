#!/bin/bash

# DocumentDBに接続するためのスクリプト
# 使用方法: DOCDB_USERNAME=username DOCDB_PASSWORD=password ./connect-docdb.sh <cluster-name>

# エラーが発生した場合に終了
set -e

# クラスター名を引数から取得
CLUSTER_NAME=$1

if [ -z "$CLUSTER_NAME" ]; then
  echo "エラー: クラスター名が指定されていません"
  echo "使用方法: DOCDB_USERNAME=username DOCDB_PASSWORD=password ./connect-docdb.sh <cluster-name>"
  exit 1
fi

# 環境変数からユーザー名とパスワードを取得
if [ -z "$DOCDB_USERNAME" ]; then
  echo "エラー: DOCDB_USERNAME 環境変数が設定されていません"
  echo "使用方法: DOCDB_USERNAME=username DOCDB_PASSWORD=password ./connect-docdb.sh <cluster-name>"
  exit 1
fi

if [ -z "$DOCDB_PASSWORD" ]; then
  echo "エラー: DOCDB_PASSWORD 環境変数が設定されていません"
  echo "使用方法: DOCDB_USERNAME=username DOCDB_PASSWORD=password ./connect-docdb.sh <cluster-name>"
  exit 1
fi

# 作業ディレクトリを作成
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

echo "証明書ファイルをダウンロード中..."
wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# クラスター名とドメインからエンドポイントを構築
echo "接続情報を準備中..."
# ドメインが環境変数で指定されていない場合はデフォルト値を使用
DOCDB_DOMAIN=${DOCDB_DOMAIN:-"czgdzfkc9hwn.us-east-1.docdb.amazonaws.com"}
CLUSTER_ENDPOINT="${CLUSTER_NAME}.${DOCDB_DOMAIN}"
CLUSTER_PORT=${DOCDB_PORT:-"27017"}

echo "DocumentDBに接続中..."
echo "エンドポイント: $CLUSTER_ENDPOINT"
echo "ポート: $CLUSTER_PORT"
echo "ユーザー名: $DOCDB_USERNAME"

# デバッグモードが有効な場合は詳細情報を表示
if [ "${DOCDB_DEBUG}" = "true" ]; then
  echo "デバッグモード: 有効"
  echo "接続文字列: mongodb://${DOCDB_USERNAME}:***@${CLUSTER_ENDPOINT}:${CLUSTER_PORT}/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false"
  
  # ネットワーク接続をテスト
  echo "ネットワーク接続をテスト中..."
  if ping -c 1 -W 5 ${CLUSTER_ENDPOINT} &> /dev/null; then
    echo "ホストに到達可能です"
  else
    echo "警告: ホストに到達できません。VPC内からのアクセスが必要な可能性があります。"
  fi
fi

# mongoshを使用して接続
echo "mongoshで接続を試みています..."
mongosh "$CLUSTER_ENDPOINT:$CLUSTER_PORT" --tls --tlsCAFile global-bundle.pem --retryWrites=false --username "$DOCDB_USERNAME" --password "$DOCDB_PASSWORD"

# 一時ディレクトリを削除
cd - > /dev/null
rm -rf "$WORK_DIR"
