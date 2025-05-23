# スクリプト集

このディレクトリには、ワークショップで使用する様々なユーティリティスクリプトが含まれています。
ただし、このディレクトリのスクリプトの詳細を説明せずとも何をやっているのかコードから理解できる方のみ利用してください。
このディレクトリのスクリプトを使わずともワークショップは実施できるようになっています。

## 共通のセットアップ手順

このディレクトリのスクリプトは主に Python で実装されています。実行前に以下の手順で Python 環境をセットアップしてください：

```bash
# mise で事前に uv を入れている前提
uv venv && source .venv/bin/activate && uv sync
```

この手順は、仮想環境の作成、アクティベート、依存パッケージのインストールを行います。

## 目次

- [SSM ポートフォワーディングスクリプト](#ssmポートフォワーディングスクリプト)
- [環境変数設定スクリプト](#環境変数設定スクリプト)

## SSM ポートフォワーディングスクリプト

このスクリプトは、AWS Systems Manager を使用して Amazon Elastic Compute Cloud (Amazon EC2) インスタンスへの複数のポートフォワーディングを一括で行います。

> **重要**: このスクリプトはローカル PC で実行する必要があります。AWS CloudShell や Amazon EC2 インスタンス上では実行するものではありません。

### 必要なライブラリ

以下のライブラリが必要です（uv を使用して管理）：

```
pyyaml
boto3
```

### 設定ファイル

`config.yml`ファイルに以下の設定を記述します：

```yaml
# SSMポートフォワーディング設定
instance_id: i-0XXXXXXXXXX  # Amazon EC2 インスタンスID（フォールバック値）
region: us-east-1           # AWSリージョン

# ポートマッピング設定
ports:
  - local: 8080    # ローカルポート番号
    remote: 8080   # リモート（Amazon EC2）ポート番号
  - local: 4000
    remote: 4000
  - local: 2222
    remote: 22
```

### 使用方法

#### 基本的な使用方法

```bash
uv run port_forward.py
```

これにより、設定ファイル（`config.yml`）に定義されたポートフォワーディングが開始されます。

#### コマンドラインオプション

```bash
uv run port_forward.py -i <instance-id> -r <region> -c <config-file>
```

- `-i`, `--instance-id`: Amazon EC2 インスタンスID（環境変数 `EC2_INSTANCE_ID` より優先）
- `-r`, `--region`: AWSリージョン（環境変数 `AWS_REGION` より優先）
- `-c`, `--config`: 設定ファイルのパス（デフォルト: `config.yml`）

#### 環境変数

以下の環境変数を設定することもできます：

- `EC2_INSTANCE_ID`: Amazon EC2 インスタンスID
- `AWS_REGION`: AWSリージョン

### インスタンスIDの優先順位

インスタンスIDは以下の優先順位で取得されます：

1. コマンドライン引数 (`-i`, `--instance-id`)
2. 環境変数 (`EC2_INSTANCE_ID`)
3. 設定ファイルの値

### リージョンの優先順位

リージョンは以下の優先順位で取得されます：

1. コマンドライン引数 (`-r`, `--region`)
2. 環境変数 (`AWS_REGION`)
3. 設定ファイルの値
4. デフォルト値 (`us-east-1`)

### 注意事項

- このスクリプトを実行するには、AWS CLI と Session Manager プラグインがインストールされている必要があります。
- 適切な AWS Identity and Access Management (IAM) 権限が必要です（`AmazonSSMManagedInstanceCore`など）。
- Ctrl+C でスクリプトを終了すると、すべてのポートフォワーディングセッションが終了します。

## 環境変数設定スクリプト

`setup_env.sh` は、AWS アクセスキーを `~/.aws/credentials` から読み取って `.env` に環境変数として設定するためのスクリプトです。すでに値が設定されている場合に上書きはしません。

### 使用場面

このスクリプトは以下のディレクトリで使用されます：

- `2.litellm/`: LiteLLM Proxy のアクセスキーと設定
- `4.langfuse/`: Langfuse のアクセスキーと設定
- `5.mlflow/`: MLflow のアクセスキーと設定

### 使用方法

1. 各ディレクトリの `.env.example` を参考に、必要な環境変数を設定します
2. Python 環境をセットアップします：
   ```bash
   uv venv && source .venv/bin/activate && uv sync
   ```
3. スクリプトを実行して環境変数を設定します：
   ```bash
   ./setup_env.sh
   ```

### 注意事項

- このスクリプトは Amazon EC2 インスタンス上で実行します
