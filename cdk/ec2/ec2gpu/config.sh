#!/bin/sh -x

# Please see the neuron docs
#   https://awsdocs-neuron.readthedocs-hosted.com/en/latest/neuron-intro/pytorch-setup/pytorch-install.html
sudo apt-get update -y

export PATH=/opt/aws/neuron/bin:$PATH

sudo apt-get install -y python3.7-venv g++

sudo dd if=/dev/zero of=/var/swpfile8G bs=1M count=8192
sudo mkswap /var/swpfile8G
sudo chmod 600 /var/swpfile8G
sudo swapon /var/swpfile8G
free
sudo echo "/var/swpfile8G swap swap defaults 0 0" >> /etc/fstab

cd /home/ubuntu
sudo -u ubuntu python3.7 -m venv pytorch_venv

. ./pytorch_venv/bin/activate

pip3 install -U pip
pip3 install ipykernel
pip3 install jupyter notebook
pip3 install environment_kernels
pip3 config set global.extra-index-url https://pip.repos.neuron.amazonaws.com
pip3 install torch-neuron==1.10.2.* neuron-cc[tensorflow] "protobuf<4" torchvision
pip3 install transformers==4.19.2 fugashi==1.1.2 ipadic==1.0.0

mkdir -p /home/ubuntu/.aws

cat <<'EOL' > /home/ubuntu/.aws/credentials
[default]
aws_access_key_id = XXX
aws_secret_access_key = XXX
region = XXX
EOL

cat <<'EOL' > /tmp/env.hcl
CDK_DEFAULT_REGION="us-west-1"
CDK_DEFAULT_ACCOUNT="XXX"
REGION="us-west-1"
ACCOUNT_ID="XXX"
EOL