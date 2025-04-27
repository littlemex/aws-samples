#!/bin/bash
set -e

echo "===== Docker と mise のリセットを開始します ====="

# Docker の削除
echo "Docker を削除しています..."
systemctl stop docker || true
apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
apt-get autoremove -y
rm -rf /var/lib/docker
rm -rf /etc/docker
rm -rf /etc/apt/keyrings/docker.gpg
rm -f /etc/apt/sources.list.d/docker.list

# mise の削除
echo "mise を削除しています..."
apt-get remove -y mise || true
rm -rf /etc/apt/keyrings/mise-archive-keyring.gpg
rm -f /etc/apt/sources.list.d/mise.list

# coder ユーザーの設定リセット
echo "coder ユーザーの設定をリセットしています..."
# .bashrc から Docker と mise の設定を削除
sed -i "/newgrp docker/d" /home/coder/.bashrc
sed -i "/mise activate/d" /home/coder/.bashrc

# mise の設定を削除
rm -rf /home/coder/.config/mise
rm -rf /home/coder/.local/share/mise

echo "===== リセット完了 ====="
echo "検証用スクリプトを実行するには："
echo "sudo /tmp/config.sh"
