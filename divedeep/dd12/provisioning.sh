#!/bin/bash

BUCKET=$(cat .bucket)
echo $BUCKET
STACK=$(cat .stackname)
echo $STACK

aws cloudformation create-stack --stack-name $STACK --template-body file://kendratemplate.yaml --parameters ParameterKey=S3DataSourceBucket,ParameterValue=$BUCKET --capabilities CAPABILITY_NAMED_IAM
