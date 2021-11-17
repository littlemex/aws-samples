#!/bin/bash

STACK=$(cat .stackname)

indexid=$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='KendraIndexID'].OutputValue" --output text)
dsid=$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='KendraDatasourceID'].OutputValue" --output text)
echo "Kendra index ID is: $indexid. Kendra data source id is: $dsid"
# Sync the data source 
aws kendra start-data-source-sync-job --id $dsid --index-id $indexid
aws kendra list-data-source-sync-jobs --id $dsid --index-id $indexid
