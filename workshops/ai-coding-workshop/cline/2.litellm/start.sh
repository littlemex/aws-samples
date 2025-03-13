#!/bin/bash

# デフォルト設定
CONFIG_FILE="default_config.yaml"

# 引数の処理
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--config) CONFIG_FILE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# 設定ファイルの存在確認
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found!"
    exit 1
fi

# 環境変数を設定して Docker Compose を起動
export CONFIG_FILE
docker compose up -d
