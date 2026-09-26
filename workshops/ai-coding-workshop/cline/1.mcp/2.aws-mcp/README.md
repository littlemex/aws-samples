# AWS MCP サーバー活用ワークショップ

## はじめに

このワークショップでは、AWS が提供する MCP サーバーを活用して、AWS のベストプラクティスと豊富な情報資源を開発ワークフローに直接統合する方法を学びます。AWS MCP Servers は、AWS の公式ドキュメント、Bedrock ナレッジベース、その他の AWS サービスと AI エージェントを効率的に連携させる革新的なツールです。

## ワークショップの目的

このワークショップを通じて、参加者は以下のスキルを習得できます：

- AWS MCP サーバーの種類と特徴の理解
- AWS ドキュメントや Bedrock ナレッジベースの効率的な活用方法
- 複数の AWS MCP サーバーを連携させる実践的な手法
- AWS MCP サーバーのトラブルシューティング技術
- セキュリティを考慮した AWS MCP サーバーの運用方法

## 前提条件

このワークショップを開始する前に、以下の環境が整っていることを確認してください：

- AWS アカウントへのアクセス権限
- Python 3.10 以上がインストール済み
- uv パッケージ管理ツールがインストール済み
- VSCode と Cline 拡張機能がインストール済み
- 基本的な AWS サービスの知識
- MCP の基本概念の理解

## AWS MCP サーバーの概要

[AWS MCP Servers](https://github.com/awslabs/mcp) は、AWS Labs によって開発された MCP サーバー群で、AWS のベストプラクティスと豊富な情報資源を開発ワークフローに直接統合することを目的としています。

### AWS MCP サーバーの主な特徴

1. **公式サポート**
   - AWS Labs による開発と保守
   - AWS サービスとの深い統合
   - 継続的なアップデートとセキュリティ対応

2. **豊富な機能**
   - AWS ドキュメントの効率的な検索と取得
   - Bedrock ナレッジベースとの統合
   - AWS サービス情報の自動取得

3. **エンタープライズ対応**
   - セキュリティベストプラクティスの実装
   - スケーラブルなアーキテクチャ
   - 監査とログ機能

## AWS MCP サーバーの種類

AWS は、開発者の生産性向上と AWS サービスの効果的な活用を支援するために、複数の MCP サーバーを提供しています：

### 1. Core MCP Server

**概要**: AWS Labs MCP サーバー群の中心的な役割を担うサーバー

**主な機能**:
- 他の MCP サーバーの管理や調整
- 設定の一元化
- サーバー間の連携制御

**使用場面**:
- 複数の AWS MCP サーバーを統合管理する場合
- AWS MCP エコシステム全体の制御が必要な場合

### 2. AWS Documentation MCP Server

**概要**: AWS の公式ドキュメントを効率的に検索、探索、活用するためのサーバー

**主な機能**:
- AWS ドキュメントの全文検索
- マークダウン形式での情報提供
- 関連ドキュメントの自動提案
- バージョン管理されたドキュメントへのアクセス

**使用場面**:
- AWS サービスの使用方法を調べる場合
- ベストプラクティスを確認する場合
- API リファレンスを参照する場合

### 3. Amazon Bedrock Knowledge Bases Retrieval MCP Server

**概要**: Amazon Bedrock の知識ベースを効率的に活用するためのサーバー

**主な機能**:
- 自然言語クエリによる情報検索
- 結果のフィルタリングやリランキング
- コンテキストに応じた情報抽出
- 複数の知識ベースからの統合検索

**使用場面**:
- 企業固有の知識ベースから情報を取得する場合
- 複雑な技術文書から特定の情報を抽出する場合
- AI による知識ベースの効率的な活用が必要な場合

## 開発環境の準備

### Python 環境の確認

まず、Python 3.10 以上がインストールされていることを確認します：

```bash
python3 --version
# または
python --version
```

### uv パッケージ管理ツールの確認

uv がインストールされていることを確認します：

```bash
uv --version
```

Amazon EC2 環境では uv は既にインストールされています。ローカル環境の場合は以下でインストールできます：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### AWS 認証の設定

AWS MCP サーバーを使用するには、適切な AWS 認証が必要です：

#### 方法 1: AWS CLI の設定

```bash
aws configure
```

#### 方法 2: 環境変数の設定

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

#### 方法 3: IAM ロール（EC2 環境推奨）

EC2 インスタンスに適切な IAM ロールを割り当てることで、認証情報を自動的に取得できます。

## 実践演習 1: AWS Documentation MCP Server

### インストール手順

#### 1. Marketplace からのインストール

VS Code の Cline 拡張機能から：

1. 左側のサイドバーから「MCP Servers」を選択
2. 画面上部の「Marketplace」タブをクリック
3. 検索バーに「AWS」と入力して検索
4. 「AWS Documentation MCP Server」の「Install」ボタンをクリック

#### 2. 手動インストール

```bash
# プロジェクトディレクトリの作成
mkdir -p /home/coder/Cline/MCP/aws-documentation-mcp-server
cd /home/coder/Cline/MCP/aws-documentation-mcp-server

# パッケージのインストール
uvx awslabs.aws-documentation-mcp-server@latest
```

#### 3. MCP 設定ファイルの更新

設定ファイル: `/home/coder/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`

```json
{
  "mcpServers": {
    "github.com/awslabs/mcp/tree/main/src/aws-documentation-mcp-server": {
      "command": "/home/coder/.local/share/mise/shims/uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 使用方法と実践例

#### 基本的な使用方法

AWS Documentation MCP Server は、以下のツールを提供します：

1. **search_documentation**: AWS ドキュメントの検索
2. **read_documentation**: 特定のドキュメントの読み取り

#### 実践例 1: S3 バケット命名規則の調査

Cline に以下のように質問してみましょう：

```
AWS S3 バケットの命名規則について調べてください
```

内部的に以下のような処理が行われます：

1. **ドキュメント検索**:
   ```json
   {
     "name": "search_documentation",
     "arguments": {
       "query": "S3 bucket naming rules"
     }
   }
   ```

2. **関連ドキュメントの取得**:
   ```json
   {
     "name": "read_documentation", 
     "arguments": {
       "url": "https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html"
     }
   }
   ```

#### 実践例 2: Lambda 関数のベストプラクティス

```
AWS Lambda 関数の開発におけるベストプラクティスを教えてください
```

#### 実践例 3: VPC セキュリティグループの設定

```
VPC セキュリティグループの適切な設定方法について調べてください
```

### 取得できる情報の例

AWS Documentation MCP Server から取得できる情報には以下のようなものがあります：

- **S3 バケット命名規則**:
  - バケット名は 3 文字以上 63 文字以下
  - 小文字、数字、ピリオド (.)、ハイフン (-) のみ使用可能
  - 文字または数字で始まり、文字または数字で終わる必要がある

- **Lambda のベストプラクティス**:
  - 関数のタイムアウト設定
  - メモリ配分の最適化
  - 環境変数の適切な使用方法

- **セキュリティグループの設定**:
  - インバウンドルールの最小権限原則
  - アウトバウンドルールの適切な制限
  - ポート範囲の最適化

## 実践演習 2: Amazon Bedrock Knowledge Bases MCP Server

### 前提条件

このサーバーを使用するには、以下が必要です：

- Amazon Bedrock へのアクセス権限
- 事前に作成された Knowledge Base
- 適切な IAM ロールまたはアクセスキー

### インストールと設定

#### 1. インストール

```bash
# プロジェクトディレクトリの作成
mkdir -p /home/coder/Cline/MCP/bedrock-kb-mcp-server
cd /home/coder/Cline/MCP/bedrock-kb-mcp-server

# パッケージのインストール
uvx awslabs.bedrock-knowledge-bases-mcp-server@latest
```

#### 2. 設定ファイルの更新

```json
{
  "mcpServers": {
    "github.com/awslabs/mcp/tree/main/src/bedrock-knowledge-bases-mcp-server": {
      "command": "/home/coder/.local/share/mise/shims/uvx",
      "args": ["awslabs.bedrock-knowledge-bases-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "KNOWLEDGE_BASE_ID": "your-knowledge-base-id"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 使用例

#### Knowledge Base からの情報検索

```
社内の技術ドキュメントから、マイクロサービスアーキテクチャのベストプラクティスを教えてください
```

#### 複合的な情報検索

```
プロジェクトの過去の障害事例から、同様の問題を防ぐための対策を提案してください
```

## 実践演習 3: 複数 AWS MCP サーバーの連携

### 連携のメリット

複数の AWS MCP サーバーを組み合わせることで、より包括的な情報収集と分析が可能になります：

1. **AWS Documentation + Bedrock Knowledge Base**:
   - 公式ドキュメントと社内ナレッジの統合
   - より具体的で実践的な回答の生成

2. **段階的な情報収集**:
   - 基本情報の取得 → 詳細情報の検索 → 実装例の提供

### 連携設定例

```json
{
  "mcpServers": {
    "aws-documentation": {
      "command": "/home/coder/.local/share/mise/shims/uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "autoApprove": []
    },
    "bedrock-knowledge-bases": {
      "command": "/home/coder/.local/share/mise/shims/uvx", 
      "args": ["awslabs.bedrock-knowledge-bases-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "KNOWLEDGE_BASE_ID": "your-knowledge-base-id"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 連携活用例

#### 例 1: 包括的なアーキテクチャ設計支援

```
新しいマイクロサービスアーキテクチャを設計したいです。
AWS の公式ベストプラクティスと、社内の過去の実装例を参考に、
具体的な設計案を提案してください。
```

この質問に対して、AI エージェントは：
1. AWS Documentation から公式のベストプラクティスを取得
2. Bedrock Knowledge Base から社内の実装例を検索
3. 両方の情報を統合して具体的な設計案を提案

#### 例 2: トラブルシューティング支援

```
Lambda 関数でタイムアウトエラーが頻発しています。
AWS の公式トラブルシューティングガイドと、
社内の過去の解決事例を参考に対策を教えてください。
```

## セキュリティとベストプラクティス

### AWS MCP サーバーのセキュリティ考慮事項

#### 1. 認証と認可

**IAM ロールの使用（推奨）**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:RetrieveAndGenerate",
        "bedrock:Retrieve"
      ],
      "Resource": "arn:aws:bedrock:*:*:knowledge-base/*"
    }
  ]
}
```

**最小権限の原則**:
- 必要最小限の AWS サービスへのアクセス権限のみを付与
- 定期的な権限の見直しと更新

#### 2. データ保護

**暗号化**:
- 転送中のデータ暗号化（TLS）
- 保存時のデータ暗号化（KMS）

**ログ管理**:
- CloudTrail による API 呼び出しの記録
- CloudWatch Logs による詳細なログ管理

#### 3. ネットワークセキュリティ

**VPC エンドポイント**:
- プライベートネットワーク経由での AWS サービスアクセス
- インターネットゲートウェイを経由しない通信

### 運用のベストプラクティス

#### 1. 監視とアラート

**CloudWatch メトリクス**:
- API 呼び出し回数の監視
- エラー率の追跡
- レスポンス時間の測定

**アラート設定**:
```json
{
  "AlarmName": "MCP-Server-High-Error-Rate",
  "MetricName": "ErrorRate",
  "Threshold": 5.0,
  "ComparisonOperator": "GreaterThanThreshold"
}
```

#### 2. コスト管理

**使用量の監視**:
- Bedrock の API 呼び出し回数
- データ転送量
- ストレージ使用量

**コスト最適化**:
- 不要なリクエストの削減
- キャッシュの活用
- 適切なタイムアウト設定

## トラブルシューティング

### よくある問題と解決方法

#### 1. 認証エラー

**問題**: `AccessDenied` エラーが発生する

**解決方法**:
```bash
# AWS 認証情報の確認
aws sts get-caller-identity

# IAM ロールの権限確認
aws iam get-role-policy --role-name your-role-name --policy-name your-policy-name
```

#### 2. タイムアウトエラー

**問題**: MCP サーバーの応答が遅い

**解決方法**:
```json
{
  "mcpServers": {
    "aws-documentation": {
      "timeout": 120,
      "env": {
        "FASTMCP_LOG_LEVEL": "DEBUG"
      }
    }
  }
}
```

#### 3. Knowledge Base 接続エラー

**問題**: Bedrock Knowledge Base に接続できない

**解決方法**:
```bash
# Knowledge Base の存在確認
aws bedrock-agent get-knowledge-base --knowledge-base-id your-kb-id

# リージョンの確認
aws configure get region
```

### デバッグ手法

#### 1. ログレベルの調整

```json
{
  "env": {
    "FASTMCP_LOG_LEVEL": "DEBUG",
    "AWS_LOG_LEVEL": "DEBUG"
  }
}
```

#### 2. AWS CLI での動作確認

```bash
# Bedrock の動作確認
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --body '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":100}' \
  output.json

# Knowledge Base の動作確認
aws bedrock-agent retrieve \
  --knowledge-base-id your-kb-id \
  --retrieval-query '{"text":"test query"}'
```

#### 3. ネットワーク接続の確認

```bash
# AWS エンドポイントへの接続確認
curl -I https://bedrock-runtime.us-east-1.amazonaws.com

# DNS 解決の確認
nslookup bedrock-runtime.us-east-1.amazonaws.com
```

## パフォーマンス最適化

### 1. キャッシュ戦略

**ローカルキャッシュ**:
- 頻繁にアクセスされるドキュメントのキャッシュ
- TTL（Time To Live）の適切な設定

**分散キャッシュ**:
- ElastiCache を使用した共有キャッシュ
- 複数のインスタンス間でのキャッシュ共有

### 2. 並列処理

**非同期処理**:
```python
import asyncio
import aiohttp

async def fetch_multiple_documents(urls):
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_document(session, url) for url in urls]
        return await asyncio.gather(*tasks)
```

### 3. リクエスト最適化

**バッチ処理**:
- 複数のクエリをまとめて処理
- API 呼び出し回数の削減

**フィルタリング**:
- 不要な情報の事前除外
- レスポンスサイズの最適化

## 高度な活用例

### 1. CI/CD パイプラインとの統合

**GitHub Actions での活用**:
```yaml
name: AWS Best Practices Check
on: [push, pull_request]

jobs:
  check-best-practices:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check AWS Best Practices
        run: |
          # MCP サーバーを使用してベストプラクティスをチェック
          python check_aws_practices.py
```

### 2. 自動ドキュメント生成

**アーキテクチャ図の自動生成**:
```python
def generate_architecture_doc(service_config):
    # AWS Documentation MCP から関連情報を取得
    best_practices = get_aws_best_practices(service_config)
    
    # Bedrock Knowledge Base から社内事例を取得
    internal_examples = get_internal_examples(service_config)
    
    # 統合してドキュメント生成
    return generate_document(best_practices, internal_examples)
```

### 3. 自動コードレビュー

**AWS リソース設定のレビュー**:
```python
def review_terraform_config(config_file):
    # Terraform 設定を解析
    config = parse_terraform(config_file)
    
    # AWS MCP サーバーからベストプラクティスを取得
    recommendations = get_aws_recommendations(config)
    
    # レビューコメントを生成
    return generate_review_comments(recommendations)
```

## まとめ

このワークショップでは、AWS MCP サーバーを活用して AWS のベストプラクティスを開発ワークフローに統合する方法を学びました。

### 主要なポイント

1. **AWS MCP サーバーの種類と特徴**:
   - Documentation MCP Server による公式ドキュメントの活用
   - Bedrock Knowledge Bases MCP Server による社内ナレッジの統合

2. **実践的な活用方法**:
   - 単体での使用から複数サーバーの連携まで
   - セキュリティとパフォーマンスを考慮した運用

3. **トラブルシューティング**:
   - 一般的な問題の解決方法
   - デバッグとパフォーマンス最適化の手法

### 次のステップ

- より高度な AWS MCP サーバーの開発
- 独自の AWS 統合 MCP サーバーの作成
- エンタープライズ環境での大規模運用

### 参考リンク

- [AWS MCP GitHub リポジトリ](https://github.com/awslabs/mcp)
- [Amazon Bedrock ドキュメント](https://docs.aws.amazon.com/bedrock/)
- [AWS IAM ベストプラクティス](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Model Context Protocol 公式ドキュメント](https://modelcontextprotocol.io/)

---

**[前のワークショップ]**
- [MCP Marketplace 活用ワークショップ](../1.marketplace-mcp/README.md)

**[ワークショップ一覧に戻る]**
- [MCP ワークショップシリーズ](../README.md)