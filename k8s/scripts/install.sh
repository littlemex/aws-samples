#!/bin/sh

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
. /home/ubuntu/.bashrc
nvm install --lts

# cdk8s
npm install -g cdk8s-cli

# create project
DIR=../cdk8s mkdir $DIR && cd $DIR
