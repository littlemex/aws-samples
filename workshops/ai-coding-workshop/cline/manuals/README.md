# Cline ショップ

このワークショップでは、AI コーディング支援エージェント Cline を活用した実践的なハンズオンを行います。

## ワークショップの概要

このワークショップでは Cline に加えて組織利用を想定した以下の内容を学びます：

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

## ドキュメント構成

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|セルフアカウント| C[manuals/selfenv.md]
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
```

フローチャートの各ノードをクリックすると、対応するドキュメントにジャンプできます。例えば、「セルフアカウント」をクリックするとセルフアカウントのセットアップガイドに移動します。

このドキュメント構成に従って、環境のセットアップからワークショップの実施まで段階的に進めることができます。

## 環境選択

ワークショップを開始する前に、ワークショップで使用する AWS アカウントを選択してください：

### 1. 企業の AWS アカウントを使用

自社の AWS アカウントを使用してワークショップを実施する場合：

- Amazon Bedrock の有効化が必要
- 適切な IAM 権限の設定が必要
- クオータの確認と調整が必要

👉 [企業アカウントでの環境セットアップへ](./selfenv.md)

### 2. Workshop Studio を使用

AWS が提供する Workshop Studio 環境を使用する場合：

- 事前に設定された環境を利用可能
- 制限時間内での利用

👉 [Workshop Studio 環境セットアップへ](./workshop-studio.md)

## 前提知識

ワークショップ実施のために以下の前提知識を必要とします。

- AWS の基本的な知識
- コマンドラインの基本操作
- Git の基本的な使用方法
- Docker の基本的な操作

## 所要時間

- 環境セットアップ：約 20-30 分
- 各ワークショップ：約 0.5-1 時間

## サポート

問題が発生した場合は、以下を確認してください：
- 各セクションのトラブルシューティングガイド

---

**[次のステップ]**
- [企業アカウントでの環境セットアップ](./selfenv.md)
- [Workshop Studio 環境セットアップ](./workshop-studio.md)
