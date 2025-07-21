#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ステップ実行関数
run_step() {
  echo -e "${GREEN}実行: $1${NC}"
  eval $1
  if [ $? -ne 0 ]; then
    echo -e "${RED}エラー: $1 の実行に失敗しました${NC}"
    return 1
  fi
  return 0
}

# 実行権限の付与
chmod +x "$SCRIPT_DIR/verify-env.sh"

echo -e "${GREEN}=== Wren AI + Amazon Bedrock 統合テスト ===${NC}"
echo "テスト開始時刻: $(date)"
echo "プロジェクトディレクトリ: $PROJECT_DIR"
echo

# ステップ 1: 環境変数検証
echo -e "${GREEN}ステップ 1: 環境変数検証${NC}"
if ! run_step "$SCRIPT_DIR/verify-env.sh"; then
  echo -e "${RED}環境変数検証に失敗しました。テストを中止します。${NC}"
  exit 1
fi
echo

# ステップ 2: 設定ファイル検証
echo -e "${GREEN}ステップ 2: 設定ファイル検証${NC}"
if ! run_step "python $SCRIPT_DIR/validate-config.py"; then
  echo -e "${YELLOW}設定ファイル検証に問題がありますが、続行します。${NC}"
fi
echo

# ステップ 3: Docker 環境起動
echo -e "${GREEN}ステップ 3: Docker 環境起動${NC}"
echo "既存の Docker コンテナを停止中..."
run_step "cd $PROJECT_DIR && docker compose down -v"

echo "Docker コンテナを起動中..."
run_step "cd $PROJECT_DIR && docker compose up -d"

# ステップ 4: Bedrock モデルアクセステスト
echo -e "${GREEN}ステップ 6: Bedrock モデルアクセステスト${NC}"
if ! run_step "python3 $SCRIPT_DIR/test-bedrock-models.py"; then
  echo -e "${YELLOW}一部の Bedrock モデルへのアクセスに問題がありますが、続行します。${NC}"
fi
echo

# ステップ 5: Wren AI 接続テスト
echo -e "${GREEN}ステップ 7: Wren AI 接続テスト${NC}"
echo "Wren AI の API エンドポイントをテスト中..."
curl -s http://localhost:8000/health > /dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}Wren AI API への接続に失敗しました${NC}"
  echo "Wren AI コンテナのログを確認してください: docker logs wren-ai"
else
  echo -e "${GREEN}Wren AI API への接続に成功しました${NC}"
fi
echo

# テスト結果サマリー
echo -e "${GREEN}=== テスト結果サマリー ===${NC}"
echo "テスト完了時刻: $(date)"
echo -e "${GREEN}統合テストが完了しました${NC}"
echo
echo "Wren AI UI: http://localhost:3000"
echo "Wren AI API: http://localhost:8000"
echo "PostgreSQL: localhost:5432 (ユーザー: wrenuser, パスワード: wrenpass, DB: wrendb)"
echo "MinIO: http://localhost:9001 (ユーザー: minioadmin, パスワード: minioadmin)"
echo
echo "次のステップ:"
echo "ブラウザで http://localhost:3000 にアクセスして Wren AI を使用"
