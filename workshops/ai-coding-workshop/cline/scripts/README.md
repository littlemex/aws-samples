# スクリプト集

このディレクトリには、ワークショップで使用する様々なユーティリティスクリプトが含まれています。

## 目次

- [SSMポートフォワーディングスクリプト](#ssmポートフォワーディングスクリプト)

## SSMポートフォワーディングスクリプト

このスクリプトは、AWS Systems Manager を使用して Amazon Elastic Compute Cloud (Amazon EC2) インスタンスへの複数のポートフォワーディングを一括で行います。

### 必要なライブラリ

以下のライブラリが必要です（uvを使用して管理）：

```
pyyaml
boto3
```

### 設定ファイル

`config.yaml`ファイルに以下の設定を記述します：

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
uv venv && source .venv/bin/activate && uv sync
uv run port_forward.py
```

これにより、設定ファイル（`config.yaml`）に定義されたポートフォワーディングが開始されます。

#### コマンドラインオプション

```bash
uv run port_forward.py -i <instance-id> -r <region> -c <config-file>
```

- `-i`, `--instance-id`: Amazon EC2 インスタンスID（環境変数 `EC2_INSTANCE_ID` より優先）
- `-r`, `--region`: AWSリージョン（環境変数 `AWS_REGION` より優先）
- `-c`, `--config`: 設定ファイルのパス（デフォルト: `config.yaml`）

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

- このスクリプトを実行するには、AWS CLIとSession Managerプラグインがインストールされている必要があります。
- 適切な AWS Identity and Access Management (IAM) 権限が必要です（`AmazonSSMManagedInstanceCore`など）。
- Ctrl+Cでスクリプトを終了すると、すべてのポートフォワーディングセッションが終了します。
