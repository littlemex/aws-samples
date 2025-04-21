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
│   └── 1.cline/          # Cline のインストールと設定
├── 1.mcp/                # MCP サーバー実装ワークショップ
├── 2.litellm/            # LiteLLM Proxy の利用
├── 4.langfuse/           # Langfuse による LLM 利用状況の分析
└── 5.mlflow/             # MLflow による LLM モニタリング
```

## 1. 環境要件

### ローカル PC に必要なツール
- Python 3.12 以上
- AWS CLI v2
- Session Manager プラグイン

### 必要な AWS 権限

このワークショップでは、以下の AWS サービスを利用するためのアクセス権限が必要です。
AWS CDK を利用する場合は Administrator 権限が必要となる可能性があります。
aws congigure もしくは aws configure sso 等で AWS CLI もしくは boto3 をローカル PC で実行できる状態にしておくことが前提です。

- Amazon EC2（開発環境用）
- AWS Systems Manager（Remote SSH 接続用）
- Amazon Bedrock（基盤 LLM モデル用）
- Amazon SageMaker（カスタムモデルのデプロイ、Managed MLflow 用）

## 2. ワークショップの進め方

### 2.1 環境セットアップ
1. [環境セットアップガイド](0.setup/README.md)に従って開発環境を構築
   - Amazon EC2 インスタンスのデプロイ
   - Remote SSH または code-server の設定
   - Cline のインストールと設定
   - Amazon Bedrock の設定（モデルアクセスの有効化）

**目的と学習内容**：
このセクションでは、AI コーディングエージェントを効果的に活用するための基盤となる Amazon EC2 開発環境を構築します。AWS のクラウド環境と VSCode の Remote Development 機能を組み合わせることで、安全な開発環境を実現する方法を学びます。また、Amazon Bedrock と Cline の設定を行います。

- [ ] Option 1-1: Amazon EC2 開発環境を構築せずにローカル VSCode を利用する
- [ ] Option 1-2: Amazon EC2 開発環境を構築して code-server を利用する
- [ ] Option 1-3: Amazon EC2 開発環境を構築して VSCode Remote SSH を利用する

Option 1-1 を選択する場合は、ローカル環境依存により Workshop で想定していないエラーが発生する可能性があります。
そして、2.litellm の IAM Role による Amazon Bedrock へのアクセスはローカル想定の実装をしていないため動きません。

### 2.2 MCP サーバー実装
1. [MCP サーバー実装ワークショップ](1.mcp/README.md)
   - TypeScript による MCP サーバーの作成
   - ツールとリソースの実装
   - AI エージェントとの連携方法の学習

**目的と学習内容**：
Model Context Protocol (MCP) は、AI モデルとデータソースやツールを接続するための標準化されたオープンプロトコルです。このセクションでは、MCP の基本概念を理解し、実際に TypeScript を使用して MCP サーバーを実装することで、AI エージェントの機能拡張方法を学びます。

- [ ] Option 2-1: 天気予報 MCP を自作するワークショップを体験します
- [ ] Option 2-2: MCP Marketplace の MCP を体験します
- [ ] Option 2-3: AWS が提供する AWS MCP を体験します

### 2.3 LiteLLM Proxy の設定
1. [LiteLLM Proxy ガイド](2.litellm/README.md)
   - Amazon Bedrock Claude モデルの設定
   - フォールバック機能の設定
   - Cline との統合

**目的と学習内容**：
LiteLLM Proxy は複数の LLM プロバイダーを統一的に扱うためのプロキシサーバーです。このセクションでは、Amazon Bedrock 上の Claude モデルを LiteLLM Proxy を通じて利用する方法を学びます。また、エラー発生時のフォールバック機能の実装を通じて、信頼性の高い AI システムの構築方法を理解できます。

- [ ] Option 3-1: IAM Role を用いた Amazon Bedrock への LiteLLM Proxy 経由アクセス
- [ ] Option 3-2: IAM Access Key を用いた Amazon Bedrock への LiteLLM Proxy 経由アクセス

### 2.4 Amazon SageMaker カスタムモデルの利用

**LiteLLM Proxy 経由の利用時に発生するエラー調査の対応中のためスキップしてください。**

1. [Amazon SageMaker ワークショップ](3.sagemaker/README.md)
   - カスタムモデル（Llama-3.3-Swallow-70B）のデプロイ
   - LiteLLM Proxy との統合
   - Cline からの利用設定

**目的と学習内容**：
Amazon SageMaker を使用して独自の AI モデルをデプロイし、それを LiteLLM と統合する方法を学びます。このプロセスを通じて、カスタム AI モデルのデプロイメントライフサイクルと、それを既存の AI システムに統合する方法について理解を深めることができます。

### 2.5 Langfuse による LLM 利用状況の分析
1. [Langfuse ガイド](4.langfuse/README.md)
   - LLM の利用状況とコスト分析
   - リクエスト・レスポンスの詳細な記録
   - パフォーマンスとレイテンシの監視
   - Langfuse Web UI の利用方法

**目的と学習内容**：
Langfuse は LLM アプリケーションの観察とモニタリングを行うためのオープンソースプラットフォームです。このセクションでは、LLM の利用状況を詳細に分析し、コストやパフォーマンスを最適化する方法を学びます。また、エラーの早期発見と効果的なトラブルシューティング手法についても理解を深めることができます。

*実装が間に合っておらず Role ベースのアクセスに対応していません。

### 2.6 MLflow による LLM 利用状況のモニタリング
1. [MLflow ガイド](5.mlflow/README.md)
   - Amazon SageMaker の Managed MLflow を利用したログ収集
   - LiteLLM Proxy の実行ログの統合管理
   - メトリクス（コスト、レイテンシ、トークン使用量）の可視化
   - タグベースでの検索・フィルタリング
   - MLflow UI による分析とトレンド把握

**目的と学習内容**：
Amazon SageMaker の Managed MLflow を使用して、LiteLLM Proxy のコストやパフォーマンス等をモニタリングする方法を学びます。このセクションでは、MLflow の実験管理機能を活用して、LLM の呼び出し履歴を一元管理し、詳細なメトリクスの追跡とパフォーマンス分析を行う方法を理解できます。

## 3. セキュリティ考慮事項

ワークショップ実施時には必ず開発用 AWS アカウントと IAM ユーザーをご用意ください。
本番環境で使っている AWS アカウントはクォータ影響やセキュリティリスクがあるため利用しないでください。
ワークショップはあくまでサンプルであるため実利用時には以下の確認をお願いします。

- SSH キーと設定ファイルの適切な権限設定
- AWS IAM ロールの最小権限原則の適用
- API キーの安全な管理
- 不要なポート転送の終了
- 開発環境のセキュリティ設定の確認

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [Code Server ドキュメント](https://coder.com/docs/code-server/latest)
- [Amazon Bedrock 開発者ガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)
- [Model Context Protocol Documentation](https://modelcontextprotocol.github.io/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
- [Langfuse Documentation](https://langfuse.com/docs)
