# AI Coding Agent ワークショップ

このワークショップでは、AI coding agent である Cline を使用して、効率的なコーディング体験を学びます。

## ワークショップの構成

このワークショップは以下のディレクトリで構成されています：

```
cline/
├── 0.setup/          # 環境セットアップガイド
│   ├── 1.cline/     # Clineのインストールと設定
│   └── 2.roocode/   # Roo Codeの設定
├── 1.cline-sample/   # MCPサーバー実装ワークショップ
│   ├── step1/       # 天気予報MCPサーバーの作成
│   └── step2/       # 実装の解説とアーキテクチャ
└── 2.claude-code-sample/ # その他のサンプル実装
```

## 1. 環境構築

### 必要な AWS 権限

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

1. [環境セットアップ](0.setup/README.md)
   - Clineのインストールと設定
   - Roo Codeの設定
   - Amazon Bedrockの設定

2. [MCPサーバー実装ワークショップ](1.cline-sample/README.md)
   - 天気予報MCPサーバーの作成
   - 実装の解説とアーキテクチャの理解

3. [その他のサンプル実装](2.claude-code-sample/README.md)
   - 追加のコーディング例と実践的な使用方法

## 3. ワークショップアンケート

ワークショップにご参加いただき、ありがとうございました。
以下のアンケートにご回答いただけますと幸いです。

### アンケート項目

1. ワークショップの難易度はいかがでしたか？
   - とても簡単
   - 適度
   - やや難しい
   - とても難しい

2. AI coding agent の利用価値をどのように感じましたか？
   - とても有用
   - まあまあ有用
   - あまり有用でない
   - 有用でない

3. 最も印象に残った機能は何ですか？
   - Roo Code の基本機能
   - Three.js デモの作成
   - MCP の活用
   - その他（自由記述）

4. 実務での活用をイメージできましたか？
   - はい
   - いいえ
   理由：（自由記述）

5. 改善点や追加して欲しい機能はありますか？
   （自由記述）

6. その他、ご意見・ご感想をお聞かせください。
   （自由記述）

ご協力ありがとうございました。