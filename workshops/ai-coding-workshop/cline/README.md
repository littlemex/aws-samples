# AI Coding Agent ワークショップ

このワークショップでは、AI coding agent である Cline を使用して、効率的なコーディング体験を学びます。

## ワークショップの構成

このワークショップは以下のディレクトリで構成されています：

```
cline/
├── scripts/              # スクリプト
├── 0.setup/              # 環境セットアップガイド
│   ├── README.md         # メインセットアップガイド
│   ├── 0.remotessh/      # Remote Development using SSH 設定
│   ├── 1.cline/          # cline のインストールと設定
│   └── 2.roocode/        # Roo Code の設定
├── 1.mcp/                # MCP サーバー実装ワークショップ
├── 2.litellm/            # LiteLLM Proxy の利用
└── 3.sagemaker/          # Amazon SageMaker AI, Inference 機能の利用
```

## 1. 環境要件

### 必要なツール
- AWS CLI
- AWS CDK v2.x 以上
- Node.js v14.x 以上
- npm v6.x 以上
- Python 3.9 以上（LiteLLM, SageMaker 利用時）
- Docker（LiteLLM, SageMaker 利用時）
- Session Manager プラグイン

### 必要な AWS 権限

#### EC2/Systems Manager 関連の権限
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

- AWS Systems Manager 関連の権限
  - ssm:StartSession
  - ssm:TerminateSession
  - ssm:DescribeSessions
  - ssm:GetConnectionStatus
  - ssmmessages:CreateControlChannel
  - ssmmessages:CreateDataChannel
  - ssmmessages:OpenControlChannel
  - ssmmessages:OpenDataChannel

#### AI/ML サービス関連の権限
- Amazon Bedrock 関連の権限
  - bedrock:InvokeModel
  - bedrock:ListFoundationModels

- Amazon SageMaker 関連の権限（SageMaker ワークショップ実施時）
  - sagemaker:CreateEndpoint
  - sagemaker:CreateEndpointConfig
  - sagemaker:CreateModel
  - sagemaker:DeleteEndpoint
  - sagemaker:DeleteEndpointConfig
  - sagemaker:DeleteModel
  - sagemaker:DescribeEndpoint
  - sagemaker:InvokeEndpoint
  - iam:CreateRole
  - iam:AttachRolePolicy

## 2. ワークショップの進め方

### 2.1 環境セットアップ
1. [環境セットアップガイド](0.setup/README.md)に従って開発環境を構築
   - EC2 インスタンスのデプロイ
   - Remote SSH または code-server の設定
   - Cline のインストールと設定
   - Amazon Bedrock の設定（モデルアクセスの有効化）

### 2.2 MCP サーバー実装
1. [MCP サーバー実装ワークショップ](1.mcp/README.md)
   - TypeScript による MCP サーバーの作成
   - ツールとリソースの実装
   - AI エージェントとの連携方法の学習

### 2.3 LiteLLM Proxy の設定
1. [LiteLLM Proxy ガイド](2.litellm/README.md)
   - Bedrock 上の Claude モデルの利用設定
   - フォールバック機能の設定
   - Cline との統合

### 2.4 SageMaker カスタムモデルの利用
1. [SageMaker ワークショップ](3.sagemaker/README.md)
   - カスタムモデル（Llama-3.3-Swallow-70B）のデプロイ
   - LiteLLM Proxy との統合
   - Cline からの利用設定

## 3. セキュリティ考慮事項

- SSH キーと設定ファイルの適切な権限設定
- AWS IAM ロールの最小権限原則の適用
- API キーの安全な管理
- 不要なポート転送の終了
- 開発環境のセキュリティ設定の確認

## 4. トラブルシューティング

各コンポーネントの詳細なトラブルシューティング手順については、それぞれのディレクトリの README を参照してください：

- [Remote SSH 接続の問題](0.setup/0.remotessh/README.md#トラブルシューティング)
- [Cline の設定問題](0.setup/1.cline/README.md)
- [LiteLLM Proxy の問題](2.litellm/README.md)
- [SageMaker エンドポイントの問題](3.sagemaker/README.md)

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [Code Server ドキュメント](https://coder.com/docs/code-server/latest)
- [Amazon Bedrock 開発者ガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)
- [Model Context Protocol Documentation](https://modelcontextprotocol.github.io/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
