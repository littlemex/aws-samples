#!/usr/bin/env python3
import boto3
import json
import argparse
import sys
from botocore.exceptions import ClientError

def create_step_functions_role(stack_name, region=None, role_name=None):
    """
    Step Functions実行用のIAMロールを作成します。
    
    Args:
        stack_name (str): CloudFormationスタック名
        region (str, optional): AWSリージョン
        role_name (str, optional): 作成するロール名
    
    Returns:
        str: 作成したロールのARN
    """
    # IAMクライアントの作成
    iam = boto3.client('iam')
    
    # ロール名の設定
    role_name = role_name or f"{stack_name}-sfn-execution-role"
    
    try:
        # 既存のロールを確認
        try:
            response = iam.get_role(RoleName=role_name)
            print(f"ロール '{role_name}' は既に存在します。")
            return response['Role']['Arn']
        except ClientError as e:
            if e.response['Error']['Code'] != 'NoSuchEntity':
                raise
        
        # 信頼ポリシーの作成
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {
                    "Service": "states.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }]
        }
        
        # ロールの作成
        print(f"ロール '{role_name}' を作成中...")
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description=f"Step Functions execution role for {stack_name}"
        )
        role_arn = response['Role']['Arn']
        
        # Lambda実行権限ポリシーの作成
        lambda_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": [
                    "lambda:InvokeFunction"
                ],
                "Resource": [
                    f"arn:aws:lambda:{region or '*'}:*:function:*"
                ]
            }]
        }
        
        # CloudWatchログ権限ポリシーの作成
        logs_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogDelivery",
                    "logs:GetLogDelivery",
                    "logs:UpdateLogDelivery",
                    "logs:DeleteLogDelivery",
                    "logs:ListLogDeliveries",
                    "logs:PutResourcePolicy",
                    "logs:DescribeResourcePolicies",
                    "logs:DescribeLogGroups"
                ],
                "Resource": "*"
            }]
        }
        
        # インラインポリシーの追加
        print("Lambda実行権限を追加中...")
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName=f"{role_name}-lambda-execution",
            PolicyDocument=json.dumps(lambda_policy)
        )
        
        print("CloudWatchログ権限を追加中...")
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName=f"{role_name}-cloudwatch-logs",
            PolicyDocument=json.dumps(logs_policy)
        )
        
        print(f"ロール '{role_name}' が正常に作成されました。")
        return role_arn
        
    except ClientError as e:
        print(f"エラー: {str(e)}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Step Functions実行用のIAMロールを作成します。')
    parser.add_argument('--stack-name', required=True, help='CloudFormationスタック名')
    parser.add_argument('--region', help='AWSリージョン（デフォルト：環境変数またはデフォルトリージョン）')
    parser.add_argument('--role-name', help='作成するロール名（デフォルト：{stack-name}-sfn-execution-role）')
    
    args = parser.parse_args()
    
    role_arn = create_step_functions_role(args.stack_name, args.region, args.role_name)
    print(f"\nロールARN: {role_arn}")

if __name__ == '__main__':
    main()
