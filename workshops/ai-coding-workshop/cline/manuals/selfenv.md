# セルフアカウントでの環境セットアップ

このガイドでは、セルフ AWS アカウントを使用してワークショップ環境をセットアップする手順を説明します。
可能であればワークショップ当日までにこのページの準備が完了していることが望ましいです。

## ドキュメント構成

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|企業アカウント| C[manuals/selfenv.md]
    B -->|Workshop Studio| D[manuals/workshop-studio.md]
    
    C --> E{実行環境}
    D --> F{実行環境}
    
    E -->|"Amazon EC2 環境(推奨)"| G[manuals/selfenv-ec2.md]
    E -->|ローカル環境| H[manuals/selfenv-local.md]
    
    F -->|"Amazon EC2 環境(推奨)"| I[manuals/ws-ec2.md]
    F -->|ローカル環境| J[manuals/ws-local.md]
    
    G --> K[manuals/workshops/README.md]
    H --> K
    I --> K
    J --> K
    
    K -->|MCP| L[manuals/workshops/mcp.md]
    K -->|LiteLLM| M[manuals/workshops/litellm.md]
    K -->|Langfuse| N[manuals/workshops/langfuse.md]
    K -->|MLflow| O[manuals/workshops/mlflow.md]
    
    L --> P[1.mcp/README.md]
    M --> Q[2.litellm/README.md]
    N --> R[4.langfuse/README.md]
    O --> S[5.mlflow/README.md]

    click A href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/README.md"
    click D href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshop-studio.md"
    click G href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv-ec2.md"
    click H href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv-local.md"
    click I href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-ec2.md"
    click J href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-local.md"
    click K href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/README.md"
    click L href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mcp.md"
    click M href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/litellm.md"
    click N href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/langfuse.md"
    click O href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mlflow.md"

    style C fill:#f96,stroke:#333,stroke-width:2px
```

## 前提条件

### 最低限必要な権限

このワークショップでは、以下の AWS サービスを利用します。Administrator アクセス権限を保有していることを推奨します。
`aws congigure` もしくは `aws configure sso` で AWS CLI もしくは boto3 をローカル PC 上で適切な権限で実行できることが前提です。
AWS Console にアクセスして AWS CloudShell を利用する必要があります。

- Amazon SageMaker
- Amazon S3
- AWS CloudFormation スタックの作成と管理
- Amazon VPC、サブネット、Internet Gateway、NAT Gateway、ルートテーブルなどのネットワークリソースの作成と管理
- Amazon EC2 インスタンスの作成と管理
- IAM ロールとポリシーの作成と管理
- AWS Systems Manager 関連の権限
- AWS Lambda 関数の作成と実行
- Amazon Bedrock モデルの呼び出し権限
- AWS CloudShell へのアクセス

### AWS アカウントの準備

1. Amazon Bedrock の有効化
   - [Amazon Bedrock コンソール](https://console.aws.amazon.com/bedrock)にアクセス
   - 使用するモデル（Claude 3.7 Sonnet v2 など）へのアクセスを有効化
   - **利用リージョン**: us-east-1, us-east-2, us-west-2

2. IAM 権限の設定
   - Amazon Bedrock へのアクセス権限
   - 必要に応じて Amazon EC2、AWS CloudFormation の権限

3. クオータの確認
   - Amazon Bedrock のクオータを確認
   - 必要に応じてクオータの引き上げをリクエスト

### 必要なツール

| ツール | バージョン | 用途 |
|--------|-----------|------|
| AWS CLI | v2 | AWS 操作 |

## 実行環境の選択

ワークショップの実行環境として、以下の2つのオプションがあります：

### 1. Amazon EC2 環境（推奨）

Amazon EC2 インスタンスを使用してワークショップを実施する場合：

- AWS CloudFormation によって事前設定済みの環境を利用可能
- IAM Role による認証が可能
- セキュアな実行環境

👉 [Amazon EC2 環境のセットアップへ](./selfenv-ec2.md)

### 2. ローカル PC 環境

ローカル PC を使用してワークショップを実施する場合：

- 既存の開発環境を利用可能
- ローカル PC の環境依存によるトラブルシューティングの複雑化
- ワークショップ実施に制限あり

👉 [ローカル PC 環境のセットアップへ](./selfenv-local.md)

---

**[次のステップ]**
- [Amazon EC2 環境のセットアップ](./selfenv-ec2.md)
- [ローカル PC 環境のセットアップ](./selfenv-local.md)
- [ワークショップ一覧に戻る](./README.md)
