#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/init/wren/config.yaml"
POLICY_FILE="$PROJECT_DIR/bedrock-policy.json"

# デフォルト値
POLICY_ONLY=false
SPECIFIED_ROLE=""
SPECIFIED_POLICY_FILE=""

# 使用方法の表示
usage() {
  echo "使用方法: $0 [オプション]"
  echo "オプション:"
  echo "  --policy-only          ポリシーファイルの生成のみを行い、アタッチは行わない"
  echo "  --role ROLE_NAME       特定のIAMロール名を指定（自動検出をスキップ）"
  echo "  --policy-file FILE     既存のポリシーファイルを使用"
  echo "  --help                 このヘルプメッセージを表示"
  exit 1
}

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --policy-only)
      POLICY_ONLY=true
      shift
      ;;
    --role)
      SPECIFIED_ROLE="$2"
      shift 2
      ;;
    --policy-file)
      SPECIFIED_POLICY_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "不明なオプション: $1"
      usage
      ;;
  esac
done

echo -e "${BLUE}=== Amazon Bedrock 権限設定ツール ===${NC}"
echo "実行日時: $(date)"
echo "プロジェクトディレクトリ: $PROJECT_DIR"
echo

# AWS認証情報の検証
echo -e "${BLUE}ステップ 1: AWS 認証情報検証${NC}"
echo "AWS 認証情報を確認中..."
AWS_IDENTITY=$(aws sts get-caller-identity 2>&1)
if [ $? -ne 0 ]; then
  echo -e "${RED}エラー: AWS 認証情報が正しく設定されていません${NC}"
  echo "エラー詳細: $AWS_IDENTITY"
  echo -e "${YELLOW}解決策: 以下のいずれかの方法で AWS 認証情報を設定してください${NC}"
  echo "  - AWS CLI の設定: aws configure"
  echo "  - 環境変数の設定: "
  echo "      export AWS_ACCESS_KEY_ID=<アクセスキー>"
  echo "      export AWS_SECRET_ACCESS_KEY=<シークレットキー>"
  echo "      export AWS_SESSION_TOKEN=<セッショントークン> (必要な場合)"
  exit 1
else
  ACCOUNT_ID=$(echo $AWS_IDENTITY | grep -o '"Account": "[0-9]*"' | cut -d'"' -f4)
  USER_ARN=$(echo $AWS_IDENTITY | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
  echo -e "${GREEN}AWS 認証情報の検証に成功しました${NC}"
  echo "アカウント ID: $ACCOUNT_ID"
  echo "ユーザー ARN: $USER_ARN"
fi
echo

# EC2インスタンスプロファイルに紐づくIAMロールの特定
echo -e "${BLUE}ステップ 2: IAM ロールの特定${NC}"
if [ -n "$SPECIFIED_ROLE" ]; then
  ROLE_NAME=$SPECIFIED_ROLE
  echo "指定された IAM ロール名を使用: $ROLE_NAME"
else
  echo "EC2 インスタンスプロファイルに紐づく IAM ロールを特定中..."
  
  # EC2インスタンスメタデータサービスからトークンを取得（IMDSv2）
  echo "EC2 インスタンスメタデータサービスからトークンを取得中..."
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}警告: EC2 インスタンスメタデータサービスからトークンを取得できません${NC}"
    echo "EC2 インスタンス上で実行されていないか、メタデータサービスにアクセスできない可能性があります"
    echo -e "${YELLOW}IAM ロール名を手動で指定してください:${NC}"
    echo "例: $0 --role <ロール名>"
    exit 1
  fi
  
  # トークンを使用してインスタンスIDを取得
  echo "インスタンス ID を取得中..."
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
  if [ -z "$INSTANCE_ID" ]; then
    echo -e "${YELLOW}警告: EC2 インスタンスメタデータからインスタンス ID を取得できません${NC}"
    echo "EC2 インスタンス上で実行されていないか、メタデータサービスにアクセスできない可能性があります"
    echo -e "${YELLOW}IAM ロール名を手動で指定してください:${NC}"
    echo "例: $0 --role <ロール名>"
    exit 1
  fi
  
  echo "インスタンス ID: $INSTANCE_ID"
  
  # インスタンスプロファイル情報を取得
  INSTANCE_PROFILE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null)
  if [ -z "$INSTANCE_PROFILE" ] || [ "$INSTANCE_PROFILE" == "None" ]; then
    echo -e "${YELLOW}警告: このインスタンスに IAM インスタンスプロファイルがアタッチされていません${NC}"
    echo -e "${YELLOW}IAM ロール名を手動で指定してください:${NC}"
    echo "例: $0 --role <ロール名>"
    exit 1
  fi
  
  # インスタンスプロファイル名を抽出
  PROFILE_NAME=$(echo $INSTANCE_PROFILE | awk -F'/' '{print $2}')
  echo "インスタンスプロファイル名: $PROFILE_NAME"
  
  # インスタンスプロファイルに関連付けられたロールを取得
  ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $PROFILE_NAME --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null)
  if [ -z "$ROLE_NAME" ] || [ "$ROLE_NAME" == "None" ]; then
    echo -e "${RED}エラー: インスタンスプロファイルに関連付けられた IAM ロールが見つかりません${NC}"
    echo -e "${YELLOW}IAM ロール名を手動で指定してください:${NC}"
    echo "例: $0 --role <ロール名>"
    exit 1
  fi
  
  echo -e "${GREEN}IAM ロールを特定しました: $ROLE_NAME${NC}"
fi
echo

# Bedrock 権限チェックの実行
echo -e "${BLUE}ステップ 3: Bedrock 権限チェックの実行${NC}"
if [ -n "$SPECIFIED_POLICY_FILE" ]; then
  echo "指定されたポリシーファイルを使用: $SPECIFIED_POLICY_FILE"
  POLICY_FILE=$SPECIFIED_POLICY_FILE
else
  echo "Bedrock 権限チェックを実行中..."
  
  # config.yaml からモデル情報を抽出
  echo "設定ファイルからモデル情報を抽出中..."
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}エラー: 設定ファイル $CONFIG_FILE が見つかりません${NC}"
    exit 1
  fi
  
  # LLM モデルの抽出
  LLM_MODELS=$(grep -A 50 "model: bedrock/converse/" "$CONFIG_FILE" | grep "model:" | awk '{print $3}' | sed 's/bedrock\/converse\///' | grep -v "^$" | sed 's/^us\.//' | sed 's/^apac\.//')
  
  # エンベディングモデルの抽出
  EMBEDDING_MODELS=$(grep -A 10 "model: bedrock/" "$CONFIG_FILE" | grep -v "converse" | grep "model:" | awk '{print $3}' | sed 's/bedrock\///' | grep -v "^$" | sed 's/^us\.//' | sed 's/^apac\.//')
  
  # モデルIDの確認と修正（bedrock/プレフィックスが残っている場合に対応）
  LLM_MODELS=$(echo "$LLM_MODELS" | sed 's/bedrock\///')
  EMBEDDING_MODELS=$(echo "$EMBEDDING_MODELS" | sed 's/bedrock\///')
  
  # すべてのモデルを一つの変数にまとめて重複を排除
  ALL_MODELS=$(echo "$LLM_MODELS"$'\n'"$EMBEDDING_MODELS" | sort | uniq)
  echo "抽出されたモデル:"
  echo "$ALL_MODELS" | while read model; do
    echo "  - $model"
  done
  
  # AWS リージョンの取得
  if [ -z "$AWS_REGION_NAME" ]; then
    AWS_REGION_NAME="us-east-1"
  fi
  
  # ポリシーJSONの作成
  echo "Bedrock アクセスポリシーを生成中..."
  
  # ポリシーのヘッダー部分
  cat > "$POLICY_FILE" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel"
      ],
      "Resource": "*"
    },
EOF
  
  # モデルごとのInvokeModel権限を追加
  echo "    {" >> "$POLICY_FILE"
  echo "      \"Effect\": \"Allow\"," >> "$POLICY_FILE"
  echo "      \"Action\": \"bedrock:InvokeModel\"," >> "$POLICY_FILE"
  echo "      \"Resource\": [" >> "$POLICY_FILE"
  
  # すべてのモデルのリソースARNを追加（重複排除済み）
  FIRST=true
  for MODEL in $ALL_MODELS; do
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      echo "," >> "$POLICY_FILE"
    fi
    echo "        \"arn:aws:bedrock:$AWS_REGION_NAME:$ACCOUNT_ID:foundation-model/$MODEL\"" >> "$POLICY_FILE"
  done
  
  # Titan Embedding モデルへのアクセスを固定で追加（すべてのリージョン、すべてのバージョン）
  echo "," >> "$POLICY_FILE"
  echo "        \"arn:aws:bedrock:*::foundation-model/amazon.titan-embed-text-*\"" >> "$POLICY_FILE"
  
  # ポリシーのフッター部分
  cat >> "$POLICY_FILE" << EOF
      ]
    }
  ]
}
EOF
  
  echo -e "${GREEN}Bedrock アクセスポリシーを生成しました: $POLICY_FILE${NC}"
fi
echo

# ポリシーの内容を表示
echo -e "${BLUE}ステップ 4: 生成されたポリシーの確認${NC}"
echo "ポリシーファイル: $POLICY_FILE"
echo "ポリシーの内容:"
cat "$POLICY_FILE" | sed 's/^/  /'
echo

# ポリシーのアタッチ
if [ "$POLICY_ONLY" = true ]; then
  echo -e "${YELLOW}ポリシーのみモードが指定されたため、ポリシーのアタッチはスキップします${NC}"
else
  echo -e "${BLUE}ステップ 5: IAM ロールへのポリシーアタッチ${NC}"
  echo "IAM ロール '$ROLE_NAME' にポリシーをアタッチしますか？ (y/n)"
  read -p "> " CONFIRM
  
  if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    echo "ポリシーをアタッチ中..."
    
    # ポリシー名を生成（タイムスタンプを含む）
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    POLICY_NAME="BedrockAccess-$TIMESTAMP"
    
    # ポリシーを作成
    POLICY_ARN=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://"$POLICY_FILE" --query 'Policy.Arn' --output text)
    if [ $? -ne 0 ]; then
      echo -e "${RED}エラー: ポリシーの作成に失敗しました${NC}"
      exit 1
    fi
    
    echo "作成されたポリシー ARN: $POLICY_ARN"
    
    # ポリシーをロールにアタッチ
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
    if [ $? -ne 0 ]; then
      echo -e "${RED}エラー: ポリシーのアタッチに失敗しました${NC}"
      exit 1
    fi
    
    echo -e "${GREEN}ポリシーを IAM ロール '$ROLE_NAME' に正常にアタッチしました${NC}"
  else
    echo "ポリシーのアタッチをキャンセルしました"
  fi
fi
echo

# 完了メッセージ
echo -e "${BLUE}=== セットアップ完了 ===${NC}"
echo "完了時刻: $(date)"
echo
echo -e "${GREEN}Amazon Bedrock アクセス権限の設定が完了しました${NC}"
echo "ポリシーファイル: $POLICY_FILE"
if [ "$POLICY_ONLY" != true ] && [[ $CONFIRM =~ ^[Yy]$ ]]; then
  echo "アタッチされたポリシー: $POLICY_NAME"
  echo "IAM ロール: $ROLE_NAME"
fi
echo
echo "変更が反映されるまで数分かかる場合があります"
echo "問題が解決しない場合は、AWS コンソールで IAM ロールの権限を確認してください"
