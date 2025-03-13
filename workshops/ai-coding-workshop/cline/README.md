# AI Coding Agent ワークショップ

このワークショップでは、AI coding agent である cline を使用して、効率的なコーディング体験を学びます。

## ワークショップの構成

このワークショップは以下のディレクトリで構成されています：

```
cline/
├── 0.setup/              # 環境セットアップガイド
│   ├── README.md
│   ├── 0.remotessh/      # Remote Development using SSH 設定
│   ├── 1.cline/          # cline のインストールと設定
├── 1.mcp/                # MCP サーバー実装ワークショップ
│   ├── 0.mcp             # 天気予報 MCP サーバーの作成
│   ├── 1.litellm         # LiteLLM Proxy の利用
│   └── 2.sagemaker       # Amazon SageMaker AI, Inference 機能の利用
└── 2.claude-code-sample/ # その他のサンプル実装 (TBD)
```

## 1. 環境構築

### 必要な AWS 権限

# FIXME: ディレクトリを見直して必要な権限を 1.cline-sample の step ごとに分けて整理してください。

ワークショップを実施するには以下の AWS 権限が必要です：

#### EC2 インスタンス作成用の権限
- Amazon EC2 関連の権限
  - ec2:RunInstances
  - ec2:DescribeInstances
  - ec2:TerminateInstances
  - ec2:CreateSecurityGroup
  - ec2:AuthorizeSecurityGroupIngress
  - ec2:CreateTags
  - ec2:DescribeImages
  - ec2:CreateVpc
  - ec2:CreateSubnet
  - ec2:CreateRouteTable
  - ec2:CreateRoute
  - ec2:AttachInternetGateway

#### AWS Systems Manager (SSM) 関連の権限
- AWS Systems Manager 関連の権限
  - ssm:StartSession
  - ssm:TerminateSession
  - ssm:DescribeSessions
  - ssm:GetConnectionStatus
  - ssmmessages:CreateControlChannel
  - ssmmessages:CreateDataChannel
  - ssmmessages:OpenControlChannel
  - ssmmessages:OpenDataChannel

#### Amazon Bedrock 利用権限
- Amazon Bedrock 関連の権限
  - bedrock:InvokeModel
  - bedrock:ListFoundationModels

## 2. ワークショップの進め方

# FIXME: 最新情報に修正してください

1. [環境セットアップ](0.setup/README.md)
   - EC2, cline のインストールと設定
   - Amazon Bedrock の設定

2. [MCP サーバー実装ワークショップ](1.cline-sample/README.md)
   - 天気予報 MCP サーバーの作成
   - 実装の解説とアーキテクチャの理解

3. [TBD: その他のサンプル実装](2.claude-code-sample/README.md)
   - 追加のコーディング例と実践的な使用方法