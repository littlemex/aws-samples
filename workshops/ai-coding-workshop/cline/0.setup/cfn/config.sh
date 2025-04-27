#!/bin/bash
set -e

echo "===== Docker と mise のインストールを開始します ====="

# Docker インストール部分の修正
echo "Docker をインストールしています..."
# 古いバージョンの削除（docker.io のみを対象）
apt-get remove -y docker.io || true

# 必要なパッケージをインストール
apt-get update
apt-get install -y ca-certificates curl gnupg

# Docker の公式GPGキーを追加（--yes オプション使用）
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker のリポジトリを追加
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# パッケージリストの更新とDockerのインストール
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker coder

# .bashrc に Docker グループの設定を追加（正しいインデントで）
cat > /tmp/docker_bashrc << EOF
if ! grep -q docker <(groups); then
  newgrp docker
fi
EOF
cat /tmp/docker_bashrc >> /home/coder/.bashrc
rm /tmp/docker_bashrc

echo "Docker のインストールが完了しました"

# mise のインストール
echo "mise をインストールしています..."
apt update -y && apt install -y gpg sudo wget curl
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --yes --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list
apt update
apt install -y mise

# coder ユーザーの .bashrc に mise の設定を追加
su - coder -c 'echo "eval \"\$(/usr/bin/mise activate bash)\"" >> ~/.bashrc'

# mise のインストールを確実に行うための追加処理
echo "mise の設定を構成しています..."
su - coder -c 'mkdir -p ~/.config/mise'
su - coder -c 'cat > ~/.config/mise/config.toml << EOF
[tools]
uv = "0.6.16"
python = "3.10"
node = "22"

[settings]
python.uv_venv_auto = true
EOF'

# mise install コマンドを実行（ログインシェルで実行して環境変数を適切に設定）
echo "mise でツールをインストールしています..."
su - coder -c 'bash -l -c "/usr/bin/mise install"'

# グローバル設定の適用
su - coder -c 'bash -l -c "/usr/bin/mise use -g node@22 python@3.10 uv@0.6.16"'

# インストール確認
echo "インストールされたツールを確認しています..."
su - coder -c 'bash -l -c "/usr/bin/mise ls"'

# PATH を確認
echo "mise の PATH 設定を確認しています..."
su - coder -c 'bash -l -c "echo \$PATH"'

# シンボリックリンクの作成（オプション）
echo "シンボリックリンクを作成しています..."
su - coder -c 'mkdir -p ~/.local/bin'
su - coder -c 'ln -sf ~/.local/share/mise/shims/uv ~/.local/bin/uv'
su - coder -c 'ln -sf ~/.local/share/mise/shims/python ~/.local/bin/python'
su - coder -c 'ln -sf ~/.local/share/mise/shims/node ~/.local/bin/node'

echo "===== インストール完了 ====="
echo "新しいシェルを開くか、以下のコマンドを実行して環境を更新してください："
echo "source ~/.bashrc"
