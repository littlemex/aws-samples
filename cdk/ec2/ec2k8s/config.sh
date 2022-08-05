#!/bin/sh -x

sudo apt-get update -y
sudo apt-get install -y python3.8-venv g++ awscli jq gettext bash-completion moreutils

aws --version

cd /home/ubuntu
sudo -u ubuntu python3.8 -m venv pytorch_venv

. ./pytorch_venv/bin/activate

pip3 install -U pip
pip3 install ipykernel environment_kernels

sudo -u ubuntu mkdir -p /home/ubuntu/.aws

sudo -u ubuntu cat <<'EOL' > /home/ubuntu/.aws/credentials
[default]
aws_access_key_id=
aws_secret_access_key=
region = us-west-1
EOL

sudo -u ubuntu cat <<'EOL' > /tmp/env.hcl
CDK_DEFAULT_REGION="us-west-1"
CDK_DEFAULT_ACCOUNT=""
REGION="us-west-1"
ACCOUNT_ID=""
EOL

# install k8s tools

# kubectl
curl --silent --location -o /usr/local/bin/kubectl \
   https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.5/2022-01-21/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl

for command in kubectl jq envsubst aws
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done

echo 'export LBC_VERSION="v2.4.1"' >> /home/ubuntu/.bash_profile
echo 'export LBC_CHART_VERSION="1.4.1"' >> /home/ubuntu/.bash_profile

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account) && echo "export ACCOUNT_ID=${ACCOUNT_ID}" >> /home/ubuntu/.bash_profile
AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region') && echo "export AWS_REGION=${AWS_REGION}" >> /home/ubuntu/.bash_profile
AZS=$(sudo -u ubuntu aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION) && echo "export AZS=(${AZS})" >> /home/ubuntu/.bash_profile

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv -v /tmp/eksctl /usr/local/bin

sudo -u ubuntu aws kms create-alias --alias-name alias/eksworkshop --target-key-id $(sudo -u ubuntu aws kms create-key --query KeyMetadata.Arn --output text)
MASTER_ARN=$(sudo -u ubuntu aws kms describe-key --key-id alias/eksworkshop --query KeyMetadata.Arn --output text) && echo "export MASTER_ARN=${MASTER_ARN}" >> /home/ubuntu/.bash_profile

. /home/ubuntu/.bash_profile

echo "Done"