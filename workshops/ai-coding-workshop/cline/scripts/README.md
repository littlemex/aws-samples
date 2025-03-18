# SSMポートフォワーディングスクリプト

このスクリプトは、AWS SSMを使用してEC2インスタンスへの複数のポートフォワーディングを一括で行います。

## 必要なライブラリ

以下のライブラリが必要です（uvを使用して管理）：

```
pyyaml
boto3
```

## 設定ファイル

`config.yaml`ファイルに以下の設定を記述します：

```yaml
# SSMポートフォワーディング設定
instance_id: i-0XXXXXXXXXX  # EC2インスタンスID（フォールバック値）
region: us-east-1           # AWSリージョン

# ポートマッピング設定
ports:
  - local: 8080    # ローカルポート番号
    remote: 8080   # リモート（EC2）ポート番号
  - local: 4000
    remote: 4000
  - local: 2222
    remote: 22
```

## 使用方法

### 基本的な使用方法

```bash
python port_forward.py
```

これにより、設定ファイル（`config.yaml`）に定義されたポートフォワーディングが開始されます。

### コマンドラインオプション

```bash
python port_forward.py -i <instance-id> -r <region> -c <config-file>
```

- `-i`, `--instance-id`: EC2インスタンスID（環境変数 `EC2_INSTANCE_ID` より優先）
- `-r`, `--region`: AWSリージョン（環境変数 `AWS_REGION` より優先）
- `-c`, `--config`: 設定ファイルのパス（デフォルト: `config.yaml`）

### 環境変数

以下の環境変数を設定することもできます：

- `EC2_INSTANCE_ID`: EC2インスタンスID
- `AWS_REGION`: AWSリージョン

## インスタンスIDの優先順位

インスタンスIDは以下の優先順位で取得されます：

1. コマンドライン引数 (`-i`, `--instance-id`)
2. 環境変数 (`EC2_INSTANCE_ID`)
3. 設定ファイルの値

## リージョンの優先順位

リージョンは以下の優先順位で取得されます：

1. コマンドライン引数 (`-r`, `--region`)
2. 環境変数 (`AWS_REGION`)
3. 設定ファイルの値
4. デフォルト値 (`us-east-1`)

## 注意事項

- このスクリプトを実行するには、AWS CLIとSession Managerプラグインがインストールされている必要があります。
- 適切なIAM権限が必要です（`AmazonSSMManagedInstanceCore`など）。
- Ctrl+Cでスクリプトを終了すると、すべてのポートフォワーディングセッションが終了します。
