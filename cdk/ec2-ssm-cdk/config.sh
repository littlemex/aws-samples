#!/bin/bash
set -e

# Update package list
apt-get update

# Install basic utilities
apt-get install -y \
    curl \
    wget \
    unzip \
    htop \
    jq

echo "apt-get install done."

# https://github.com/coder/deploy-code-server/blob/main/guides/aws-ec2.md
# install code-server service system-wide
export HOME=/root
pwd
curl -fsSL https://code-server.dev/install.sh | sh

# add our helper server to redirect to the proper URL for --link
git clone https://github.com/bpmct/coder-cloud-redirect-server
cd coder-cloud-redirect-server
cp coder-cloud-redirect.service /etc/systemd/system/
cp coder-cloud-redirect.py /usr/bin/

# create a code-server user
adduser --disabled-password --gecos "" coder
echo "coder ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/coder
usermod -aG sudo coder

# configure code-server to use --link with the "coder" user
mkdir -p /home/coder/.config/code-server
touch /home/coder/.config/code-server/config.yaml
chown -R coder:coder /home/coder/.config
chmod -R 775 /home/coder/.config

# Configure code-server
cat > /home/coder/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: code-server
cert: false
EOF

# start and enable code-server and our helper service
systemctl enable --now code-server@coder
systemctl enable --now coder-cloud-redirect

systemctl restart code-server@coder
systemctl restart coder-cloud-redirect

systemctl status code-server@coder
systemctl status coder-cloud-redirect

echo "Configuration complete"

