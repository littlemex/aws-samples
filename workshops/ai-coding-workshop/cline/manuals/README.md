# AI コーディングワークショップ

このワークショップでは、AI エージェントを活用したコーディング支援の実践的なハンズオンを行います。

## ドキュメント構成

ワークショップは実施環境の違いを考慮した複数のドキュメントから構成されます。
以下の図をご確認の上で、ご自身の環境に合わせて作業を進めてください。
AWS アカウント選択として、セルフアカウント、もしくは Workshop Studio アカウント、を利用してください。
そして、VS Code の実行環境としてローカル PC もしくは、Amazon EC2、を利用してください。

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|企業アカウント| C[manuals/selfenv.md]
    B -->|Workshop Studio| D[manuals/workshop-studio.md]
    
    C --> E{実行環境}
    D --> F{実行環境}
    
    E -->|"EC2環境(推奨)"| G[manuals/selfenv-ec2.md]
    E -->|ローカル環境| H[manuals/selfenv-local.md]
    
    F -->|"EC2環境(推奨)"| I[manuals/ws-ec2.md]
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

    click C href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv.md"
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

    style A fill:#f96,stroke:#333,stroke-width:2px
```

フローチャートの各ノードをクリックすると、対応するドキュメントにジャンプできます。
例えば、「manuals/selfenv.md」をクリックするとセルフアカウントのセットアップガイドに移動します。

## ワークショップの概要

本ワークショップで用いる Cline、LiteLLM Proxy、Langufuse などの説明や組み合わせ方については [ブログ](../blog/README.md) を参照してください。

このワークショップでは以下の内容を学びます：

1. **MCP（Model Context Protocol）**
   - 自作の MCP Server の構築
   - AWS ドキュメント検索 MCP 等の公開されている MCP の利用

2. **LiteLLM**
   - Amazon Bedrock との連携
   - 複数モデルの統合管理

3. **Langfuse/MLflow**
   - コストやレイテンシー、トレースログの分析

## 環境選択

ワークショップを開始する前に、使用する AWS アカウントを選択してください：

### 1. 企業の AWS アカウントを使用

自社の AWS アカウントを使用してワークショップを実施する場合：

- Amazon Bedrock の有効化が必要
- 適切な IAM 権限の設定が必要
- クオータの確認と調整が必要

👉 [企業アカウントでの環境セットアップへ](./selfenv.md)

### 2. Workshop Studio を使用

AWS が提供する Workshop Studio 環境を使用する場合：

- 事前に設定された環境を利用可能
- 追加の権限設定不要
- 制限時間内での利用

👉 [Workshop Studio 環境セットアップへ](./workshop-studio.md)

## 前提知識

- AWS の基本的な知識
- コマンドラインの基本操作
- Git の基本的な使用方法

## 所要時間

- 環境セットアップ：約 30 分
- 各ワークショップ：約 0.5-1 時間

## サポート

問題が発生した場合は、以下を確認してください：
- 各セクションのトラブルシューティングガイド

---

**[次のステップ]**
- [企業アカウントでの環境セットアップ](./selfenv.md)
- [Workshop Studio 環境セットアップ](./workshop-studio.md)
