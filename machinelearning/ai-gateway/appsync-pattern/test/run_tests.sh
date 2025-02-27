#!/bin/bash

echo "=== AI Gateway テストの実行 ==="

cd "$(dirname "$0")/.."

echo "1. テストユーザーの作成..."
uv run test/create_test_user.py
if [ $? -ne 0 ]; then
    echo "テストユーザーの作成に失敗しました"
    exit 1
fi

echo -e "\n2. GraphQL APIのテスト..."
uv run test/test_graphql_api.py
if [ $? -ne 0 ]; then
    echo "GraphQL APIのテストに失敗しました"
    exit 1
fi

echo -e "\nすべてのテストが完了しました"