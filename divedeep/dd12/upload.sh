#!/bin/bash

BUCKET=$(cat .bucket)

aws s3 cp Data/ s3://$BUCKET/Data/ --recursive
aws s3 cp Meta/ s3://$BUCKET/Meta/ --recursive
