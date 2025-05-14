#!/bin/bash

# AWS CLI v2とSSM Pluginのインストール・管理スクリプト
# このスクリプトはAWS CLI v2とSession Manager Pluginのインストール、更新、アンインストールを自動化します

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# グローバル変数の宣言
DIST_ID=""
DIST_VERSION=""
PKG_MANAGER=""
ARCH=""

# Linuxディストリビューションを確認する関数
check_linux_distribution() {
    log_info "Linuxディストリビューションを確認しています..."
    
    # /etc/os-releaseファイルからディストリビューション情報を取得
    if [ -f /etc/os-release ]; then
        DIST_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
        DIST_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
    fi
    
    # パッケージマネージャの判定
    if [[ "$DIST_ID" == "amzn" && "$DIST_VERSION" == "2" ]]; then
        log_info "Amazon Linux 2が検出されました"
        PKG_MANAGER="yum"
    elif [[ "$DIST_ID" == "amzn" && "$DIST_VERSION" == "2023" ]]; then
        log_info "Amazon Linux 2023が検出されました"
        PKG_MANAGER="dnf"
    elif [[ "$DIST_ID" == "rhel" || "$DIST_ID" == "centos" ]]; then
        if [[ "${DIST_VERSION%%.*}" -lt "8" ]]; then
            log_info "RHEL/CentOS 7が検出されました"
            PKG_MANAGER="yum"
        else
            log_info "RHEL/CentOS 8以上が検出されました"
            PKG_MANAGER="dnf"
        fi
    elif [[ "$DIST_ID" == "ubuntu" || "$DIST_ID" == "debian" ]]; then
        log_info "${DIST_ID^} ${DIST_VERSION}が検出されました"
        PKG_MANAGER="apt"
    else
        log_warning "未対応のディストリビューションです: $DIST_ID $DIST_VERSION"
        PKG_MANAGER="unknown"
    fi
    
    # アーキテクチャの検出
    ARCH=$(uname -m)
    log_info "アーキテクチャ: $ARCH"
}

# AWS CLIがインストールされているか確認する関数
check_aws_cli() {
    log_info "AWS CLIの存在を確認しています..."
    
    if command -v aws &> /dev/null; then
        local version=$(aws --version 2>&1)
        log_success "AWS CLI がインストールされています: $version"
        
        # バージョン2かどうかを確認
        if [[ $version == *"aws-cli/2"* ]]; then
            log_info "AWS CLI v2が検出されました"
            return 0
        else
            log_warning "AWS CLI v1が検出されました。v2へのアップグレードを推奨します"
            return 2
        fi
    else
        log_warning "AWS CLI がインストールされていません"
        return 1
    fi
}

# AWS CLIをインストールする関数（Linux用）
install_aws_cli_linux() {
    log_info "Linux用のAWS CLI v2をインストールしています..."
    
    # 必要なパッケージの確認
    log_info "必要なパッケージを確認しています..."
    check_linux_distribution
    # グローバル変数 DIST_ID, PKG_MANAGER, ARCH を直接使用
    
    # 必要なパッケージのインストール
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        log_info "unzip, curl をインストールしています..."
        sudo apt-get update
        sudo apt-get install -y unzip curl
    elif [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]]; then
        log_info "unzip, curl をインストールしています..."
        sudo $PKG_MANAGER install -y unzip curl
    else
        log_warning "未対応のパッケージマネージャです: $PKG_MANAGER"
        log_warning "unzip と curl が必要です。手動でインストールしてください。"
    fi
    
    # アーキテクチャに応じたダウンロードURLの設定
    local download_url
    if [[ "$ARCH" == "x86_64" ]]; then
        download_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        download_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
        log_error "未対応のアーキテクチャです: $ARCH"
        return 1
    fi
    
    # 一時ディレクトリの作成
    local temp_dir=$(mktemp -d)
    local zip_path="$temp_dir/awscliv2.zip"
    
    # パッケージのダウンロード
    log_info "AWS CLI v2をダウンロードしています: $download_url"
    if ! curl -s "$download_url" -o "$zip_path"; then
        log_error "ダウンロードに失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # zipファイルの展開
    log_info "ダウンロードしたファイルを展開しています..."
    if ! unzip -q "$zip_path" -d "$temp_dir"; then
        log_error "ファイルの展開に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # インストールの実行
    log_info "AWS CLI v2をインストールしています..."
    if ! sudo "$temp_dir/aws/install"; then
        log_error "インストールに失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 一時ディレクトリの削除
    rm -rf "$temp_dir"
    
    # インストールの確認
    log_info "インストールを確認しています..."
    if check_aws_cli; then
        log_success "AWS CLI v2のインストールが完了しました"
        return 0
    else
        log_error "AWS CLI v2のインストールに失敗しました"
        return 1
    fi
}

# AWS CLIをアンインストールする関数（Linux用）
uninstall_aws_cli_linux() {
    log_info "AWS CLI v2をアンインストールしています..."
    
    # AWS CLIのインストールパスを確認
    if [ -d "/usr/local/aws-cli" ]; then
        log_info "AWS CLIインストールディレクトリを削除しています..."
        if ! sudo rm -rf /usr/local/aws-cli; then
            log_error "インストールディレクトリの削除に失敗しました"
            return 1
        fi
        
        # シンボリックリンクの削除
        log_info "シンボリックリンクを削除しています..."
        if [ -L "/usr/local/bin/aws" ]; then
            if ! sudo rm -f /usr/local/bin/aws; then
                log_warning "aws シンボリックリンクの削除に失敗しました"
            fi
        fi
        
        if [ -L "/usr/local/bin/aws_completer" ]; then
            if ! sudo rm -f /usr/local/bin/aws_completer; then
                log_warning "aws_completer シンボリックリンクの削除に失敗しました"
            fi
        fi
        
        log_success "AWS CLI v2のアンインストールが完了しました"
        return 0
    else
        log_warning "AWS CLIのインストールディレクトリが見つかりません"
        return 1
    fi
}

# AWS CLIを更新する関数（Linux用）
update_aws_cli_linux() {
    log_info "AWS CLI v2を更新しています..."
    
    # 現在のバージョンを確認
    local current_version=""
    if command -v aws &> /dev/null; then
        current_version=$(aws --version 2>&1)
        log_info "現在のバージョン: $current_version"
    fi
    
    # アンインストールと再インストールを実行
    if ! uninstall_aws_cli_linux; then
        log_error "アンインストールに失敗したため、更新を中止します"
        return 1
    fi
    
    if ! install_aws_cli_linux; then
        log_error "再インストールに失敗しました"
        return 1
    fi
    
    # 新しいバージョンを確認
    local new_version=""
    if command -v aws &> /dev/null; then
        new_version=$(aws --version 2>&1)
        log_success "AWS CLI v2を更新しました: $current_version → $new_version"
        return 0
    else
        log_error "更新後のバージョン確認に失敗しました"
        return 1
    fi
}

# SSM Pluginがインストールされているか確認する関数
check_ssm_plugin() {
    log_info "SSM Pluginの存在を確認しています..."
    
    if command -v session-manager-plugin &> /dev/null; then
        local version=$(session-manager-plugin --version 2>&1)
        log_success "SSM Plugin がインストールされています: $version"
        return 0
    else
        log_warning "SSM Plugin がインストールされていません"
        return 1
    fi
}

# SSM Pluginをインストールする関数（Linux用）
install_ssm_plugin_linux() {
    log_info "Linux用のSSM Pluginをインストールしています..."
    
    # ディストリビューション情報の取得
    check_linux_distribution
    # グローバル変数 DIST_ID, DIST_VERSION, PKG_MANAGER, ARCH を直接使用
    
    # アーキテクチャとディストリビューションに応じたインストール方法の選択
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Debian/Ubuntu系
        local download_url
        
        if [[ "$ARCH" == "x86_64" ]]; then
            download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
        elif [[ "$ARCH" == "x86" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
            download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_32bit/session-manager-plugin.deb"
        elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb"
        else
            log_error "未対応のアーキテクチャです: $ARCH"
            return 1
        fi
        
        # 一時ディレクトリの作成
        local temp_dir=$(mktemp -d)
        local deb_path="$temp_dir/session-manager-plugin.deb"
        
        # パッケージのダウンロード
        log_info "SSM Pluginをダウンロードしています: $download_url"
        if ! curl -s "$download_url" -o "$deb_path"; then
            log_error "ダウンロードに失敗しました"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # パッケージのインストール
        log_info "SSM Pluginをインストールしています..."
        if ! sudo dpkg -i "$deb_path"; then
            log_error "インストールに失敗しました"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # 一時ディレクトリの削除
        rm -rf "$temp_dir"
        
    elif [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]]; then
        # RHEL系
        local download_url
        
        if [[ "$ARCH" == "x86_64" ]]; then
            if [[ "$DIST_ID" == "amzn" && "$DIST_VERSION" == "2023" ]] || [[ "$DIST_ID" == "rhel" && "${DIST_VERSION%%.*}" -ge "8" ]]; then
                log_info "dnfを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
                if ! sudo dnf install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            else
                log_info "yumを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
                if ! sudo yum install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            fi
        elif [[ "$ARCH" == "x86" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
            if [[ "$DIST_ID" == "rhel" && "${DIST_VERSION%%.*}" -ge "8" ]]; then
                log_info "dnfを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_32bit/session-manager-plugin.rpm"
                if ! sudo dnf install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            else
                log_info "yumを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_32bit/session-manager-plugin.rpm"
                if ! sudo yum install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            fi
        elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            if [[ "$DIST_ID" == "amzn" && "$DIST_VERSION" == "2023" ]] || [[ "$DIST_ID" == "rhel" && "${DIST_VERSION%%.*}" -ge "8" ]]; then
                log_info "dnfを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
                if ! sudo dnf install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            else
                log_info "yumを使用してインストールします"
                download_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
                if ! sudo yum install -y "$download_url"; then
                    log_error "インストールに失敗しました"
                    return 1
                fi
            fi
        else
            log_error "未対応のアーキテクチャです: $ARCH"
            return 1
        fi
    else
        log_error "未対応のパッケージマネージャです: $PKG_MANAGER"
        return 1
    fi
    
    # インストールの確認
    if check_ssm_plugin; then
        log_success "SSM Pluginのインストールが完了しました"
        return 0
    else
        log_error "SSM Pluginのインストールに失敗しました"
        return 1
    fi
}

# SSM Pluginをアンインストールする関数（Linux用）
uninstall_ssm_plugin_linux() {
    log_info "SSM Pluginをアンインストールしています..."
    
    # ディストリビューション情報の取得
    check_linux_distribution
    # グローバル変数 DIST_ID, PKG_MANAGER を直接使用
    
    # パッケージマネージャに応じたアンインストール
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        log_info "apt を使用してSSM Pluginをアンインストールしています..."
        if ! sudo apt-get remove -y session-manager-plugin; then
            log_error "アンインストールに失敗しました"
            return 1
        fi
    elif [[ "$PKG_MANAGER" == "yum" ]]; then
        log_info "yum を使用してSSM Pluginをアンインストールしています..."
        if ! sudo yum erase -y session-manager-plugin; then
            log_error "アンインストールに失敗しました"
            return 1
        fi
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        log_info "dnf を使用してSSM Pluginをアンインストールしています..."
        if ! sudo dnf remove -y session-manager-plugin; then
            log_error "アンインストールに失敗しました"
            return 1
        fi
    else
        log_error "未対応のパッケージマネージャです: $PKG_MANAGER"
        return 1
    fi
    
    # アンインストールの確認
    if ! command -v session-manager-plugin &> /dev/null; then
        log_success "SSM Pluginのアンインストールが完了しました"
        return 0
    else
        log_error "SSM Pluginのアンインストールに失敗しました"
        return 1
    fi
}

# SSM Pluginを更新する関数（Linux用）
update_ssm_plugin_linux() {
    log_info "SSM Pluginを更新しています..."
    
    # 現在のバージョンを確認
    local current_version=""
    if command -v session-manager-plugin &> /dev/null; then
        current_version=$(session-manager-plugin --version 2>&1)
        log_info "現在のバージョン: $current_version"
    fi
    
    # アンインストールと再インストールを実行
    if ! uninstall_ssm_plugin_linux; then
        log_error "アンインストールに失敗したため、更新を中止します"
        return 1
    fi
    
    if ! install_ssm_plugin_linux; then
        log_error "再インストールに失敗しました"
        return 1
    fi
    
    # 新しいバージョンを確認
    local new_version=""
    if command -v session-manager-plugin &> /dev/null; then
        new_version=$(session-manager-plugin --version 2>&1)
        log_success "SSM Pluginを更新しました: $current_version → $new_version"
        return 0
    else
        log_error "更新後のバージョン確認に失敗しました"
        return 1
    fi
}

# 使用方法を表示する関数
show_usage() {
    echo "使用方法: $0 [オプション]"
    echo "オプション:"
    echo "  --check-only       インストール状況の確認のみを行います"
    echo "  --install          AWS CLI v2とSSM Pluginの両方をインストールします"
    echo "  --install-cli      AWS CLI v2のみをインストールします"
    echo "  --install-plugin   SSM Pluginのみをインストールします"
    echo "  --update           AWS CLI v2とSSM Pluginの両方を更新します"
    echo "  --update-cli       AWS CLI v2のみを更新します"
    echo "  --update-plugin    SSM Pluginのみを更新します"
    echo "  --uninstall-cli    AWS CLI v2をアンインストールします"
    echo "  --uninstall-plugin SSM Pluginをアンインストールします"
    echo "  --port-forward     ポートフォワーディングを開始します"
    echo "    --username       AWS Cloudformation 実行時に export USERNAME で指定した、ユーザー名を指定します（必須）"
    echo "    --remote-port    リモートポート番号（デフォルト: 8080）"
    echo "    --local-port     ローカルポート番号（デフォルト: 18080）"
    echo "  --help             このヘルプメッセージを表示します"
    echo
    echo "引数なしで実行した場合、ヘルプメッセージを表示します"
}

# 両方のツールをインストールする関数（Linux用）
install_all_tools_linux() {
    log_info "AWS CLI v2とSSM Pluginをインストールしています..."
    
    local cli_installed=false
    local plugin_installed=false
    
    # AWS CLIのインストール
    if ! check_aws_cli; then
        if install_aws_cli_linux; then
            cli_installed=true
        else
            log_error "AWS CLI v2のインストールに失敗しました"
        fi
    else
        log_info "AWS CLI v2は既にインストールされています"
        cli_installed=true
    fi
    
    # SSM Pluginのインストール
    if ! check_ssm_plugin; then
        if install_ssm_plugin_linux; then
            plugin_installed=true
        else
            log_error "SSM Pluginのインストールに失敗しました"
        fi
    else
        log_info "SSM Pluginは既にインストールされています"
        plugin_installed=true
    fi
    
    # 結果の表示
    if $cli_installed && $plugin_installed; then
        log_success "AWS CLI v2とSSM Pluginのインストールが完了しました"
        return 0
    elif $cli_installed; then
        log_warning "AWS CLI v2のインストールは成功しましたが、SSM Pluginのインストールに失敗しました"
        return 1
    elif $plugin_installed; then
        log_warning "SSM Pluginのインストールは成功しましたが、AWS CLI v2のインストールに失敗しました"
        return 1
    else
        log_error "AWS CLI v2とSSM Pluginのインストールに失敗しました"
        return 1
    fi
}

# 両方のツールを更新する関数（Linux用）
update_all_tools_linux() {
    log_info "AWS CLI v2とSSM Pluginを更新しています..."
    
    local cli_updated=false
    local plugin_updated=false
    
    # AWS CLIの更新
    if update_aws_cli_linux; then
        cli_updated=true
    else
        log_error "AWS CLI v2の更新に失敗しました"
    fi
    
    # SSM Pluginの更新
    if update_ssm_plugin_linux; then
        plugin_updated=true
    else
        log_error "SSM Pluginの更新に失敗しました"
    fi
    
    # 結果の表示
    if $cli_updated && $plugin_updated; then
        log_success "AWS CLI v2とSSM Pluginの更新が完了しました"
        return 0
    elif $cli_updated; then
        log_warning "AWS CLI v2の更新は成功しましたが、SSM Pluginの更新に失敗しました"
        return 1
    elif $plugin_updated; then
        log_warning "SSM Pluginの更新は成功しましたが、AWS CLI v2の更新に失敗しました"
        return 1
    else
        log_error "AWS CLI v2とSSM Pluginの更新に失敗しました"
        return 1
    fi
}

# インスタンスIDを取得する関数
get_instance_id() {
    local username="$1"
    local stack_name="ai-workshop-${username}"
    
    # CloudFormationスタックからインスタンスIDを取得
    local instance_id=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --profile cline \
        --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
        --output text)
    
    if [ -n "$instance_id" ]; then
        echo "$instance_id"
        return 0
    else
        return 1
    fi
}

# ポートフォワーディングを開始する関数
start_port_forward() {
    local username="$1"
    local remote_port="${2:-8080}"
    local local_port="${3:-18080}"
    
    log_info "ポートフォワーディングを開始します..."
    
    # インスタンスIDの取得
    local instance_id=$(get_instance_id "$username")
    if [ -z "$instance_id" ]; then
        log_error "インスタンスIDの取得に失敗しました"
        return 1
    fi
    
    log_info "インスタンスID: $instance_id"
    log_info "リモートポート: $remote_port → ローカルポート: $local_port"
    
    # ポートフォワーディングの実行
    aws ssm start-session \
        --target "$instance_id" \
        --document-name AWS-StartPortForwardingSession \
        --parameters "{\"portNumber\":[\"$remote_port\"],\"localPortNumber\":[\"$local_port\"]}" \
        --profile cline
}

# AWS認証情報が設定されているか確認する関数
check_aws_credentials() {
    log_info "AWS 認証情報を確認しています..."
    
    # AWS CLIがインストールされているか確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI がインストールされていません"
        return 1
    fi
    
    local default_profile_ok=false
    local cline_profile_ok=false
    
    # デフォルトプロファイルの認証情報を確認
    log_info "デフォルトプロファイルの認証情報を確認しています..."
    if aws sts get-caller-identity &> /dev/null; then
        local identity=$(aws sts get-caller-identity --output json)
        local account=$(echo $identity | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
        local arn=$(echo $identity | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)
        log_success "デフォルトプロファイルの認証情報が設定されています"
        log_info "アカウント ID: $account"
        log_info "ユーザー ARN: $arn"
        default_profile_ok=true
    else
        log_warning "デフォルトプロファイルの認証情報が設定されていないか、無効です"
    fi
    
    # clineプロファイルの認証情報を確認
    log_info "cline プロファイルの認証情報を確認しています..."
    if aws sts get-caller-identity --profile cline &> /dev/null; then
        local identity=$(aws sts get-caller-identity --profile cline --output json)
        local account=$(echo $identity | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
        local arn=$(echo $identity | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)
        log_success "cline プロファイルの認証情報が設定されています"
        log_info "アカウント ID: $account"
        log_info "ユーザー ARN: $arn"
        cline_profile_ok=true
    else
        log_warning "cline プロファイルの認証情報が設定されていないか、無効です"
    fi
    
    # 結果の返却
    if $cline_profile_ok; then
        # clineプロファイルが設定されていれば成功とする
        return 0
    elif $default_profile_ok; then
        # デフォルトプロファイルのみ設定されている場合は警告を表示
        log_warning "デフォルトプロファイルは設定されていますが、cline プロファイルが設定されていません"
        log_warning "ポートフォワーディングには cline プロファイルが必要です"
        return 2
    else
        # どちらも設定されていない場合はエラー
        log_error "AWS 認証情報が設定されていません"
        return 1
    fi
}

# SSM start-sessionコマンドが実行可能か確認する関数
check_ssm_session() {
    log_info "SSM start-sessionコマンドの実行可能性を確認しています..."
    
    # AWS CLIとSSM Pluginがインストールされているか確認
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLIがインストールされていません"
        return 1
    fi
    
    if ! command -v session-manager-plugin &> /dev/null; then
        log_warning "SSM Pluginがインストールされていません"
        return 1
    fi
    
    # AWS認証情報が設定されているか確認
    if ! aws sts get-caller-identity --profile cline &> /dev/null; then
        log_warning "AWS認証情報が設定されていないか、無効です"
        return 1
    fi
    
    log_success "SSM start-sessionコマンドは実行可能です"
    return 0
}

# チェック結果を表形式で表示する関数
display_check_summary() {
    local aws_cli_status=$1
    local ssm_plugin_status=$2
    local aws_auth_status=$3
    local ssm_session_status=$4
    
    # ステータスを記号に変換
    local aws_cli_text="❌ 未インストール"
    local ssm_plugin_text="❌ 未インストール"
    local aws_auth_text="❌ 未設定"
    local ssm_session_text="❌ 実行不可"
    
    if [ "$aws_cli_status" -eq 0 ]; then
        aws_cli_text="✅ インストール済み"
    elif [ "$aws_cli_status" -eq 2 ]; then
        aws_cli_text="⚠️ v1 インストール済み"
    fi
    
    if [ "$ssm_plugin_status" -eq 0 ]; then
        ssm_plugin_text="✅ インストール済み"
    fi
    
    if [ "$aws_auth_status" -eq 0 ]; then
        aws_auth_text="✅ cline プロファイル設定済み"
    elif [ "$aws_auth_status" -eq 2 ]; then
        aws_auth_text="⚠️ デフォルトのみ設定済み"
    fi
    
    if [ "$ssm_session_status" -eq 0 ]; then
        ssm_session_text="✅ 実行可能"
    fi
    
    # 表の区切り線
    local line="+-----------------------+------------------+"
    
    # 表の表示
    echo ""
    echo "システム状態の概要:"
    echo "$line"
    echo "| 項目                  | 状態             |"
    echo "$line"
    echo "| AWS CLI               | $aws_cli_text |"
    echo "| SSM Plugin            | $ssm_plugin_text |"
    echo "| AWS 認証情報          | $aws_auth_text |"
    echo "| SSM Session 実行      | $ssm_session_text |"
    echo "$line"
    echo ""
    
    # 総合判定
    if [ "$aws_cli_status" -eq 0 ] && [ "$ssm_plugin_status" -eq 0 ] && [ "$aws_auth_status" -eq 0 ] && [ "$ssm_session_status" -eq 0 ]; then
        log_success "すべての項目が正常です。システムは完全に設定されています。"
    else
        log_warning "一部の項目に問題があります。上記の表を確認して必要な対応を行ってください。"
    fi
}

# 総合チェックを行う関数
check_all() {
    log_info "システム全体の状態を確認しています..."
    
    # 各コンポーネントのチェック
    check_aws_cli
    local aws_cli_status=$?
    
    check_ssm_plugin
    local ssm_plugin_status=$?
    
    check_aws_credentials
    local aws_auth_status=$?
    
    check_ssm_session
    local ssm_session_status=$?
    
    # 結果の表示
    display_check_summary $aws_cli_status $ssm_plugin_status $aws_auth_status $ssm_session_status
    
    # 総合結果の返却
    if [ "$aws_cli_status" -eq 0 ] && [ "$ssm_plugin_status" -eq 0 ] && [ "$aws_auth_status" -eq 0 ] && [ "$ssm_session_status" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# メイン処理
main() {
    local check_only=false
    local install_all=false
    local install_cli=false
    local install_plugin=false
    local update_all=false
    local update_cli=false
    local update_plugin=false
    local uninstall_cli=false
    local uninstall_plugin=false
    local port_forward=false
    local username=""
    local remote_port="8080"
    local local_port="18080"
    
    # 引数がない場合はヘルプを表示
    if [[ "$#" -eq 0 ]]; then
        show_usage
        return 0
    fi
    
    # 引数の解析
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --check-only) check_only=true ;;
            --install) install_all=true ;;
            --install-cli) install_cli=true ;;
            --install-plugin) install_plugin=true ;;
            --update) update_all=true ;;
            --update-cli) update_cli=true ;;
            --update-plugin) update_plugin=true ;;
            --uninstall-cli) uninstall_cli=true ;;
            --uninstall-plugin) uninstall_plugin=true ;;
            --port-forward) port_forward=true ;;
            --username) shift; username="$1" ;;
            --remote-port) shift; remote_port="$1" ;;
            --local-port) shift; local_port="$1" ;;
            --help) show_usage; return 0 ;;
            *) log_error "不明な引数: $1"; show_usage; return 1 ;;
        esac
        shift
    done
    
    # OSの検出
    local os_type=$(uname -s)
    
    if [[ "$os_type" != "Linux" ]]; then
        log_error "現在このスクリプトはLinuxのみサポートしています"
        return 1
    fi
    
    log_info "Linuxを検出しました"
    
    if $check_only; then
        check_all
    elif $install_all; then
        install_all_tools_linux
    elif $install_cli; then
        install_aws_cli_linux
    elif $install_plugin; then
        install_ssm_plugin_linux
    elif $update_all; then
        update_all_tools_linux
    elif $update_cli; then
        update_aws_cli_linux
    elif $update_plugin; then
        update_ssm_plugin_linux
    elif $uninstall_cli; then
        uninstall_aws_cli_linux
    elif $uninstall_plugin; then
        uninstall_ssm_plugin_linux
    elif $port_forward; then
        if [ -z "$username" ]; then
            log_error "--username オプションが必要です"
            show_usage
            return 1
        fi
        start_port_forward "$username" "$remote_port" "$local_port"
    fi
}

# スクリプトの実行
main "$@"
