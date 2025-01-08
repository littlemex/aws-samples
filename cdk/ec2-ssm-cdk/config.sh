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

# Configure SSM agent service to start on boot (in case it's not already configured)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Print SSM agent status
systemctl status amazon-ssm-agent --no-pager

# https://github.com/coder/deploy-code-server/blob/main/guides/aws-ec2.md
# install code-server service system-wide
export HOME=/root
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

# copy ssh keys from root
cp -r /root/.ssh /home/coder/.ssh
chown -R coder:coder /home/coder/.ssh

# configure code-server to use --link with the "coder" user
mkdir -p /home/coder/.config/code-server
touch /home/coder/.config/code-server/config.yaml
echo "link: true" > /home/coder/.config/code-server/config.yaml
chown -R coder:coder /home/coder/.config

# Configure code-server
cat > /home/coder/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: coder-server
cert: false
EOF

# start and enable code-server and our helper service
systemctl enable --now code-server@coder
systemctl enable --now coder-cloud-redirect

echo "Configuration complete"
