#!/bin/bash

# S3 バケット名（一意である必要があります）
BUCKET_NAME="wren-ai-demo-$(date +%s)"
REGION="us-east-1"  # リージョンは必要に応じて変更

# バケット作成
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION

# バケットのパブリックアクセスをブロック
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# CORS 設定（Wren AI からのアクセスを許可）
cat > cors.json << EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors --bucket $BUCKET_NAME --cors-configuration file://cors.json
rm cors.json

# バケット名を設定ファイルに保存
echo "BUCKET_NAME=$BUCKET_NAME" >> .env

echo "S3 bucket created successfully: $BUCKET_NAME"
echo "Bucket name saved to .env file"
