#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ロギング関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 使用方法の表示
show_usage() {
    echo "使用方法: $0 [プロジェクトディレクトリ]"
    echo "例:"
    echo "  $0                  # カレントディレクトリの .env を設定"
    echo "  $0 ../5.mlflow     # 指定ディレクトリの .env を設定"
}

# AWS認証情報の取得
get_aws_credentials() {
    local credentials_file="$HOME/.aws/credentials"
    if [ ! -f "$credentials_file" ]; then
        log_error "AWS認証情報ファイルが見つかりません: $credentials_file"
        return 1
    fi

    # [default]セクションから認証情報を取得
    local access_key=$(grep -A2 '^\[default\]' "$credentials_file" | grep 'aws_access_key_id' | cut -d'=' -f2 | tr -d ' ')
    local secret_key=$(grep -A2 '^\[default\]' "$credentials_file" | grep 'aws_secret_access_key' | cut -d'=' -f2 | tr -d ' ')

    if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
        log_error "AWS認証情報が見つかりません。[default]プロファイルを確認してください。"
        return 1
    fi

    echo "$access_key|$secret_key"
}

# uvコマンドのパスを取得
get_uv_path() {
    local uv_path=$(which uv)
    if [ -z "$uv_path" ]; then
        log_error "uv コマンドが見つかりません。インストールされているか確認してください。"
        return 1
    fi
    echo "$uv_path"
}

# 環境変数ファイルの更新
update_env_file() {
    local target_dir="$1"
    local env_example="$target_dir/.env.example"
    local env_file="$target_dir/.env"
    local aws_creds="$2"
    local uv_path="$3"

    # .env.example の存在確認
    if [ ! -f "$env_example" ]; then
        log_error ".env.example ファイルが見つかりません: $env_example"
        return 1
    fi

    # .env ファイルが存在しない場合は .env.example をコピー
    if [ ! -f "$env_file" ]; then
        log_info ".env ファイルを作成します"
        cp "$env_example" "$env_file"
    fi

    # AWS認証情報の分割
    IFS='|' read -r access_key secret_key <<< "$aws_creds"

    # バックアップの作成
    cp "$env_file" "${env_file}.bak"

    # AWS認証情報の更新
    log_info "AWS認証情報を更新しています..."
    sed -i "/^AWS_ACCESS_KEY_ID=/c\AWS_ACCESS_KEY_ID=\"$access_key\"" "$env_file"
    sed -i "/^AWS_SECRET_ACCESS_KEY=/c\AWS_SECRET_ACCESS_KEY=\"$secret_key\"" "$env_file"

    # AWSリージョンの設定（存在しない場合のみ）
    if ! grep -q "^AWS_REGION_NAME=" "$env_file"; then
        echo "AWS_REGION_NAME=\"us-east-1\"" >> "$env_file"
    fi

    # uvコマンドのパスを追加/更新
    log_info "uvコマンドのパスを更新しています..."
    if grep -q "^UV_COMMAND_PATH=" "$env_file"; then
        sed -i "/^UV_COMMAND_PATH=/c\UV_COMMAND_PATH=\"$uv_path\"" "$env_file"
    else
        echo "UV_COMMAND_PATH=\"$uv_path\"" >> "$env_file"
    fi

    log_info "環境変数ファイルを更新しました: $env_file"
    log_info "バックアップを作成しました: ${env_file}.bak"
    
    # env.sh ファイルを生成
    generate_env_sh "$target_dir" "$env_file" "$uv_path"
}

# env.sh ファイルの生成
generate_env_sh() {
    local target_dir="$1"
    local env_file="$2"
    local uv_path="$3"
    
    log_info "env.sh ファイルを生成しています..."
    
    # 現在のディレクトリを保存
    local current_dir="$(pwd)"
    
    # スクリプトディレクトリのパスを取得
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 入力ファイルの絶対パスを取得
    local abs_env_file="$(cd "$(dirname "$env_file")" && pwd)/$(basename "$env_file")"
    
    # convert_env.py スクリプトを実行
    (cd "$script_dir" && \
     source .venv/bin/activate && \
     cd "$current_dir" && \
     "$uv_path" run "$script_dir/convert_env.py" "$abs_env_file")
    
    if [ $? -ne 0 ]; then
        log_error "env.sh ファイルの生成に失敗しました"
        return 1
    fi
    
    local env_sh_file="$(dirname "$env_file")/env.sh"
    if [ ! -f "$env_sh_file" ]; then
        log_error "env.sh ファイルが生成されませんでした"
        return 1
    fi
    
    log_info "env.sh ファイルを生成しました: $env_sh_file"
    return 0
}

# メイン処理
main() {
    # 引数の処理
    local target_dir
    if [ $# -eq 0 ]; then
        target_dir="."
    else
        target_dir="$1"
    fi

    # ディレクトリの存在確認
    if [ ! -d "$target_dir" ]; then
        log_error "指定されたディレクトリが見つかりません: $target_dir"
        show_usage
        exit 1
    fi

    # AWS認証情報の取得
    local aws_creds
    aws_creds=$(get_aws_credentials)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # uvコマンドのパスを取得
    local uv_path
    uv_path=$(get_uv_path)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # 環境変数ファイルの更新
    update_env_file "$target_dir" "$aws_creds" "$uv_path"
    if [ $? -ne 0 ]; then
        exit 1
    fi

    log_info "セットアップが完了しました"
}

# スクリプトの実行
main "$@"
