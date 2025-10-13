# README-PHASE-3: Zero-ETL統合自動化システム

## 概要
Phase 3では、Aurora PostgreSQLからRedshift Serverlessへの完全自動Zero-ETL統合システムを構築します。Bastion HostとSecrets Managerを活用した安全なデータベース操作により、Aurora PostgreSQLのマルチテナントデータをRedshift Serverlessにリアルタイム同期します。

**注記**: Bastion HostにRedshiftへのセキュリティグループを付与しますが、CDKで実施せずPythonスクリプトで行います。これは、git cloneしてきたAWSサンプルのCDKに手を入れたくないためです。

## 🚀 実行方法

### Phase 3: 3-step ワークフロー

#### Step 1: Zero-ETL CDKインフラのデプロイ
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --step1
```

#### Step 2: Bastion Host設定とデータベース作成
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --step2
```

#### Step 3: データ複製検証と完了
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --step3
```

### 個別SQL実行（高度な使用方法）

#### Zero-ETL統合データベースの作成
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/3-sql-execute.sh config.json sql/redshift/database/create-integration-database.sql"
```

#### テナントデータ同期の検証
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/3-sql-execute.sh config.json sql/redshift/verification/verify-tenant-data-sync.sql"
```

### ファイル転送オプション

#### 通常実行（ファイル転送あり）
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "command"
```

#### ファイル転送スキップ（既存ファイル使用）
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --skip-copy --bastion-command "command"
```
**注意**: `--skip-copy`は開発・デバッグ時のみ使用し、通常は省略してください。

## 📋 前提条件

### 1. Phase 1とPhase 2の完了
- Aurora PostgreSQLクラスターの構築とデータ投入
- テナントマルチテナントデータの準備

### 2. 必要なIAM権限
以下の権限を持つIAMロール/ユーザーが必要：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:*",
        "redshift:*",
        "redshift-serverless:*",
        "redshift-data:*",
        "cloudformation:*",
        "iam:*",
        "ec2:*",
        "secretsmanager:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**注意**: `AdministratorAccess` ポリシーがアタッチされていれば十分です。

### 3. Redshift Serverless Zero-ETL統合データベース作成権限

Zero-ETL統合からデータベースを作成するには、特別な権限設定が必要な場合があります：

#### 権限エラーの解決方法

**症状**: `ERROR: permission denied to create database` エラー

**原因**: Redshift ServerlessでのZero-ETL統合データベース作成には、通常のAdmin権限に加えて特定の権限設定が必要

**解決方法A**: IAM権限の確認・追加
```bash
# 現在の権限確認
aws sts get-caller-identity
aws iam list-attached-role-policies --role-name <your-role-name>

# 必要に応じて権限追加
# AdministratorAccessポリシーがアタッチされていることを確認
```

**解決方法B**: Redshift Serverlessワークグループの権限設定
```bash
# ワークグループの設定確認
aws redshift-serverless get-workgroup --workgroup-name multitenant-analytics-wg

# 必要に応じてワークグループの権限を更新
```

**解決方法C**: 手動データベース作成（緊急時）
1. AWS Console → Amazon Redshift → Zero-ETL integrations
2. `multitenant-analytics-integration` を選択
3. "Create database from integration" をクリック
4. Database名: `multitenant_analytics_zeroetl` で作成

## 🏗️ アーキテクチャ

### Zero-ETL統合フロー
```
Aurora PostgreSQL → Zero-ETL Integration → Redshift Serverless
     ↓                      ↓                    ↓
 テナントデータ         リアルタイム同期      統合データベース
(tenant_a/b/c)              ↓              (multitenant_analytics_zeroetl)
                      データフィルタリング           ↓
                         (users テーブル)        分析・クエリ
```

### 主要コンポーネント
1. **Aurora PostgreSQL**: ソースデータベース
2. **Zero-ETL統合**: `multitenant-analytics-integration`
3. **Redshift Serverless**: ターゲットデータウェアハウス
   - Namespace: `multitenant-analytics-ns`
   - Workgroup: `multitenant-analytics-wg`

## 📊 データ検証

### テナントデータ確認
```sql
-- Auroraでのデータ確認
SELECT 'tenant_a' as tenant, COUNT(*) as user_count FROM tenant_a.users
UNION ALL
SELECT 'tenant_b' as tenant, COUNT(*) as user_count FROM tenant_b.users
UNION ALL  
SELECT 'tenant_c' as tenant, COUNT(*) as user_count FROM tenant_c.users;
```

### Redshiftでのデータ確認
```sql
-- Zero-ETL統合後のデータ確認
SELECT 'tenant_a' as tenant, COUNT(*) as user_count FROM tenant_a.users
UNION ALL
SELECT 'tenant_b' as tenant, COUNT(*) as user_count FROM tenant_b.users
UNION ALL
SELECT 'tenant_c' as tenant, COUNT(*) as user_count FROM tenant_c.users;
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. Zero-ETL統合が作成されない
- Aurora PostgreSQLのパラメータグループ設定を確認
- Redshift Serverlessのケースセンシティビティ設定を確認
- リソースポリシーの設定を確認

#### 2. データベース作成権限エラー
- IAM権限（AdministratorAccess）の確認
- Redshift Serverlessワークグループ権限の確認
- 統合IDの正確性を確認

#### 3. データが複製されない
- Zero-ETL統合がActiveステータスかどうか確認
- データフィルター設定の確認
- Aurora側のデータ存在確認

### デバッグコマンド
```bash
# Zero-ETL統合ステータス確認
aws rds describe-integrations --region us-east-1

# Redshiftデータベース一覧確認
./3-etl-manager.sh -p aurora-postgresql -c config.json --verify-data

# Aurora側データ確認
./2-etl-manager.sh -p aurora-postgresql -c config.json --verify-data
```

## 📈 期待される結果

### Phase 3完了後の状態
1. **Zero-ETL統合**: Active状態
2. **統合データベース**: `multitenant_analytics_zeroetl` 作成済み
3. **データ複製**: 各テナントのusersテーブルデータが同期
4. **リアルタイム同期**: Aurora更新がRedshiftに自動反映

### パフォーマンス指標
- **同期遅延**: 通常数秒〜数分
- **データ整合性**: 100%
- **可用性**: 99.9%+

## 🔒 セキュリティ考慮事項

1. **暗号化**: Zero-ETL統合は自動的にAWS KMSで暗号化
2. **アクセス制御**: IAMロールベースのアクセス制御
3. **ネットワークセキュリティ**: VPC内でのプライベート通信
4. **監査**: CloudTrailによるAPI呼び出しログ記録

## 📚 関連リソース

- [AWS Aurora Zero-ETL統合ドキュメント](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/zero-etl.html)
- [Amazon Redshift Zero-ETL統合ドキュメント](https://docs.aws.amazon.com/redshift/latest/mgmt/zero-etl-using.html)
- [Phase 1 README](README-PHASE-1.md)
- [Phase 2 README](README-PHASE-2.md)

---

## 🏃‍♂️ クイックスタート

```bash
# Phase 3の完全実行
./3-etl-manager.sh -p aurora-postgresql -c config.json --deploy
./3-etl-manager.sh -p aurora-postgresql -c config.json --verify-data

# 成功時の出力例
[SUCCESS] Zero-ETL integration is active
[SUCCESS] Database created: multitenant_analytics_zeroetl
[SUCCESS] Data replication verified for all tenants
```

## 🐍 Redshift Data API Python スクリプト

Phase 3では、Redshift Data APIを使用してデータ分析を実行するPythonスクリプトが含まれています。

### 📋 スクリプト概要

`scripts/redshift-data-api.py` は以下の機能を提供します：

#### ✅ 主な機能
- **カスタムSQLクエリ実行**
- **テナント別サマリーレポート**
- **クロステナント分析**
- **データ品質チェック**
- **メタデータ取得（データベース・テーブル一覧）**
- **JSON形式出力対応**

#### ✅ 技術特徴
- **非同期クエリ処理**
- **包括的エラーハンドリング**
- **詳細ログ出力**
- **設定ファイル連携**
- **環境別対応（dev/prod/test）**

### 🔧 使用方法

#### 基本的なクエリ実行
```bash
# カスタムクエリ実行
uv run scripts/redshift-data-api.py --query "SELECT CURRENT_DATABASE(), CURRENT_USER"

# JSON形式で出力
uv run scripts/redshift-data-api.py --query "SELECT COUNT(*) FROM information_schema.tables" --output-json
```

#### メタデータ取得
```bash
# データベース一覧
uv run scripts/redshift-data-api.py --list-databases

# テーブル一覧
uv run scripts/redshift-data-api.py --list-tables

# スキーマパターンでフィルタ
uv run scripts/redshift-data-api.py --list-tables information_schema
```

#### マルチテナント分析（Zero-ETL対応時）
```bash
# テナント別サマリー
uv run scripts/redshift-data-api.py --tenant-summary

# クロステナント分析
uv run scripts/redshift-data-api.py --cross-tenant-analysis --output-json

# データ品質チェック
uv run scripts/redshift-data-api.py --data-quality-check
```

#### 環境指定
```bash
# 本番環境での実行
uv run scripts/redshift-data-api.py --env prod --query "SELECT 1"

# テスト環境での実行
uv run scripts/redshift-data-api.py --env test --list-databases
```

### 📊 出力例

#### テーブル形式（デフォルト）
```
📊 Custom Query Results
current_database | current_user
----------------------------------------------------------------------------------------
dev              | IAMR:vscode-server-cloudshell--CodeServerInstanceBootstr-5lmnRw4W8idc

Total rows: 1
```

#### JSON形式
```json
{
  "query": "SELECT 'test' AS message, 42 AS number",
  "columns": ["message", "number"],
  "results": [["test", 42]],
  "row_count": 1
}
```

### ⚙️ 設定

#### 前提条件
- **AWS認証設定**: `aws configure` または IAM Role
- **必要な権限**: `redshift-data:*` 権限
- **Pythonライブラリ**: `boto3` (uv環境で自動管理)

#### Zero-ETL統合対応
Zero-ETL統合が完了している場合、スクリプト内で以下のようにデータベース名を変更：
```python
self.database = 'multitenant_analytics_zeroetl'  # Zero-ETL統合データベース
```

### 🔍 コマンドラインオプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--config` | 設定ファイルパス | `--config config.json` |
| `--env` | 実行環境 | `--env prod` |
| `--query` | SQLクエリ | `--query "SELECT 1"` |
| `--tenant-summary` | テナントサマリー | `--tenant-summary` |
| `--cross-tenant-analysis` | クロステナント分析 | `--cross-tenant-analysis` |
| `--data-quality-check` | データ品質チェック | `--data-quality-check` |
| `--list-databases` | データベース一覧 | `--list-databases` |
| `--list-tables` | テーブル一覧 | `--list-tables` |
| `--output-json` | JSON形式出力 | `--output-json` |

### 🚨 動作確認済み機能

#### ✅ 基本動作テスト済み
- データベース一覧取得: **成功** (189テーブル確認)
- カスタムクエリ実行: **成功** (CURRENT_DATABASE, CURRENT_USER取得)
- JSON形式出力: **成功** (完全なJSON構造出力)
- テーブル形式出力: **成功** (整形された表示)
- 詳細ログ出力: **成功** (実行ステップの追跡可能)

#### 🔄 Zero-ETL統合データベース対応
Zero-ETL統合が完了すると、以下の高度な分析機能が利用可能になります：
- テナント横断分析
- データ品質監視
- リアルタイムレポート生成