# AI コーディングワークショップ

このワークショップでは、AI エージェントを活用したコーディング支援の実践的なハンズオンを行います。

## ドキュメント構成

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|企業アカウント| C[manuals/selfenv.md]
    B -->|Workshop Studio| D[manuals/workshop-studio.md]
    
    C --> E{実行環境}
    D --> F{実行環境}
    
    E -->|EC2環境| G[manuals/selfenv-ec2.md]
    E -->|ローカル環境| H[manuals/selfenv-local.md]
    
    F -->|EC2環境| I[manuals/ws-ec2.md]
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

    click C href "./selfenv.md"
    click D href "./workshop-studio.md"
    click G href "./selfenv-ec2.md"
    click H href "./selfenv-local.md"
    click I href "./ws-ec2.md"
    click J href "./ws-local.md"
    click K href "./workshops/README.md"
    click L href "./workshops/mcp.md"
    click M href "./workshops/litellm.md"
    click N href "./workshops/langfuse.md"
    click O href "./workshops/mlflow.md"
    click P href "../1.mcp/README.md"
    click Q href "../2.litellm/README.md"
    click R href "../4.langfuse/README.md"
    click S href "../5.mlflow/README.md"

    style A fill:#f96,stroke:#333,stroke-width:2px
```

フローチャートの各ノードをクリックすると、対応するドキュメントにジャンプできます。例えば、「企業アカウント」をクリックすると企業アカウントのセットアップガイドに移動します。

## ワークショップの概要

```mermaid
flowchart TD
    A[AI コーディング支援] --> B[MCP]
    A --> C[LiteLLM]
    A --> D[Langfuse]
    A --> E[MLflow]
    
    B -->|拡張機能| F[Weather API]
    B -->|拡張機能| G[AWS Documentation]
    
    C -->|統合| H[Amazon Bedrock]
    
    D -->|分析| I[プロンプト効果測定]
    D -->|分析| J[キャッシュ管理]
    
    E -->|モニタリング| K[コスト追跡]
    E -->|モニタリング| L[品質管理]

    click B href "./workshops/mcp.md"
    click C href "./workshops/litellm.md"
    click D href "./workshops/langfuse.md"
    click E href "./workshops/mlflow.md"
```

フローチャートの各ワークショップ名（MCP、LiteLLM、Langfuse、MLflow）をクリックすると、対応するワークショップのガイドにジャンプできます。

このワークショップでは以下の内容を学びます：

1. **MCP（Model Context Protocol）**
   - AI エージェントの機能拡張
   - 外部 API との連携
   - AWS ドキュメント検索との統合

2. **LiteLLM**
   - Amazon Bedrock との連携
   - プロンプトのキャッシュ管理
   - 複数モデルの統合管理

3. **Langfuse**
   - プロンプトの効果測定
   - 応答品質の分析
   - コスト最適化の分析

4. **MLflow**
   - AI 応答のモニタリング
   - コストと品質の追跡
   - 継続的な改善プロセス

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

- 環境セットアップ：約30分
- 各ワークショップ：約1-2時間

## サポート

問題が発生した場合は、以下を確認してください：
- 各セクションのトラブルシューティングガイド
- ワークショップ中の質問チャンネル
- [AWS Support](https://aws.amazon.com/jp/support/)

---

**[次のステップ]**
- [企業アカウントでの環境セットアップ](./selfenv.md)
- [Workshop Studio 環境セットアップ](./workshop-studio.md)
