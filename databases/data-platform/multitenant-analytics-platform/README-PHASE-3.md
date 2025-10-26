# README-PHASE-3: Zero-ETL統合自動化システム（環境対応版）

## 概要
Phase 3では、Aurora PostgreSQLからRedshift Serverlessへの完全自動Zero-ETL統合システムを構築します。

### 🆕 新機能ハイライト
- **環境自動検出**: ローカル vs リモート環境を自動判定
- **Integration ID自動取得**: .envファイルへの自動書き込み
- **SQLテンプレート生成**: 動的SQL生成システム
- **ローカル開発対応**: Integration ID不要のサンプルデータ環境

## 🚀 実行方法

### Phase 3: 3-step ワークフロー（環境対応版）

#### Step 1: Zero-ETL CDKインフラのデプロイ + Integration ID取得
```bash
```
**新機能**:
- CDKデプロイ後、Integration IDを自動取得
- .envファイルに自動書き込み
- SQLテンプレートから実行用SQLファイルを生成

#### Step 2: 環境対応データベース作成
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --step2
```
**環境別動作**:
- **リモート環境**: Zero-ETL統合からデータベース作成
- **ローカル環境**: サンプルデータ付きテナントスキーマ作成

#### Step 3: データ複製検証と完了
```bash
./3-etl-manager.sh -p aurora-postgresql -c config.json --step3
```

### 🔄 環境自動検出システム

システムは以下の条件で環境を自動判定します：

#### ローカル環境として判定される条件
1. AWS認証情報が利用できない
2. .envファイルにZERO_ETL_INTEGRATION_IDが存在しない
3. docker-compose環境で実行中

#### リモート環境として判定される条件
- 上記以外の場合（AWS認証あり、Integration ID利用可能）

### 📁 SQLファイル構造（新システム）

```
sql/redshift/database/
├── create-integration-database.sql          # ベースファイル
├── create-integration-database.template.sql # テンプレート（{{INTEGRATION_ID}}含む）
├── create-integration-database-generated.sql # リモート用（生成済み）
└── create-integration-database-local.sql    # ローカル用（Integration ID不要）
```

#### ファイル選択ロジック
- **ローカル環境**: `*-local.sql` を使用
- **リモート環境**: `*-generated.sql` を使用（テンプレートから生成）

## 🛠️ 新しいスクリプト・機能

### Integration ID自動取得スクリプト
```bash
# 手動実行も可能
python3 scripts/retrieve-integration-id.py --config config.json
```

**機能**:
- AWS RDS API優先でIntegration ID取得
- Redshift SVV_INTEGRATIONへのフォールバック
- リトライロジック付き
- .envファイル自動更新

### SQLテンプレート生成スクリプト
```bash
# テンプレートからSQLファイル生成
scripts/generate-integration-sql.sh --template sql/redshift/database/create-integration-database.template.sql --output sql/redshift/database/create-integration-database-generated.sql
```

**機能**:
- {{INTEGRATION_ID}}プレースホルダーを実際のIDに置換
- {{TIMESTAMP}}, {{DATE}}の自動挿入
- .envファイルからの設定読み込み

## 🏗️ アーキテクチャ

### 環境別データフロー

#### リモート環境（本番）
```
Aurora PostgreSQL → Zero-ETL Integration → Redshift Serverless
     ↓                      ↓                    ↓
 テナントデータ         リアルタイム同期      統合データベース
(tenant_a/b/c)              ↓              (multitenant_analytics_zeroetl)
                      データフィルタリング           ↓
                         (users テーブル)        分析・クエリ
```

#### ローカル環境（開発）
```
ローカルRedshift → サンプルデータ生成 → 開発用データベース
     ↓                    ↓                ↓
 開発環境            テナントスキーマ    ローカル分析
                   (tenant_a/b/c)    (multitenant_analytics_local)
                        ↓                    ↓
                   サンプルユーザー        dbt開発・テスト
```

## 📊 環境別データ検証

### リモート環境でのデータ確認
```sql
-- Zero-ETL統合後のデータ確認
\c multitenant_analytics_zeroetl
SELECT 'tenant_a' as tenant, COUNT(*) as user_count FROM tenant_a.users
UNION ALL
SELECT 'tenant_b' as tenant, COUNT(*) as user_count FROM tenant_b.users
UNION ALL
SELECT 'tenant_c' as tenant, COUNT(*) as user_count FROM tenant_c.users;
```

### ローカル環境でのデータ確認
```sql
-- ローカル開発データの確認
\c multitenant_analytics_local
SELECT 'tenant_a' as tenant, COUNT(*) as user_count FROM tenant_a.users
UNION ALL
SELECT 'tenant_b' as tenant, COUNT(*) as user_count FROM tenant_b.users
UNION ALL
SELECT 'tenant_c' as tenant, COUNT(*) as user_count FROM tenant_c.users;

-- サンプルデータの内容確認
SELECT email, first_name, last_name, account_status 
FROM tenant_a.users 
LIMIT 3;
```

## 🔧 トラブルシューティング

### 環境検出関連の問題

#### 1. 環境が正しく検出されない
```bash
# 環境検出状況の確認
./3-etl-manager.sh -p aurora-postgresql -c config.json --step2 --dry-run | grep "Detected environment"
```

**対処法**:
- AWS認証情報の確認: `aws sts get-caller-identity`
- .envファイルの確認: `cat .env`
- docker-compose環境の確認: `echo $COMPOSE_PROJECT_NAME`

#### 2. SQLファイルが見つからない
```bash
# 利用可能なSQLファイルの確認
ls -la sql/redshift/database/create-integration-database*.sql
```

**対処法**:
- ローカル用ファイルの存在確認
- テンプレートからの生成実行: `scripts/generate-integration-sql.sh`

### Integration ID関連の問題

#### 3. Integration ID取得に失敗
```bash
# 手動でIntegration ID取得を試行
python3 scripts/retrieve-integration-id.py --config config.json --dry-run
```

**対処法**:
- AWS RDS権限の確認
- Zero-ETL統合の作成状況確認
- Redshift接続の確認

#### 4. .envファイルが更新されない
**症状**: Integration IDが.envに書き込まれない

**対処法**:
```bash
# ファイル権限の確認
ls -la .env

# 手動での.env更新
echo "ZERO_ETL_INTEGRATION_ID=your-integration-id" >> .env
```

### SQLテンプレート関連の問題

#### 5. テンプレート生成に失敗
**症状**: `*-generated.sql`ファイルが作成されない

**対処法**:
```bash
# テンプレートファイルの存在確認
ls -la sql/redshift/database/*.template.sql

# 手動でのテンプレート処理
scripts/generate-integration-sql.sh --template sql/redshift/database/create-integration-database.template.sql --output sql/redshift/database/create-integration-database-generated.sql
```

## 📈 期待される結果

### リモート環境（Phase 3完了後）
1. **Zero-ETL統合**: Active状態
2. **統合データベース**: `multitenant_analytics_zeroetl` 作成済み
3. **データ複製**: 各テナントのusersテーブルデータが同期
4. **リアルタイム同期**: Aurora更新がRedshiftに自動反映

### ローカル環境（Phase 3完了後）
1. **開発データベース**: `multitenant_analytics_local` 作成済み
2. **テナントスキーマ**: tenant_a, tenant_b, tenant_c 作成済み
3. **サンプルデータ**: 各テナントに3名ずつのユーザーデータ
4. **dbt開発準備**: ローカル分析・テスト環境完備

## 🔒 セキュリティ考慮事項

### リモート環境
1. **暗号化**: Zero-ETL統合は自動的にAWS KMSで暗号化
2. **アクセス制御**: IAMロールベースのアクセス制御
3. **ネットワークセキュリティ**: VPC内でのプライベート通信

### ローカル環境
1. **データ分離**: 本番データとは完全に分離
2. **サンプルデータ**: 個人情報を含まない架空データ
3. **開発専用**: 本番環境への影響なし

## 📚 関連リソース

- [AWS Aurora Zero-ETL統合ドキュメント](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/zero-etl.html)
- [Amazon Redshift Zero-ETL統合ドキュメント](https://docs.aws.amazon.com/redshift/latest/mgmt/zero-etl-using.html)
- [Phase 1 README](README-PHASE-1.md)
- [Phase 2 README](README-PHASE-2.md)

---

## 🏃‍♂️ クイックスタート

### リモート環境での実行
```bash
# Phase 3の完全実行（リモート）
./3-etl-manager.sh -p aurora-postgresql -c config.json --step1
./3-etl-manager.sh -p aurora-postgresql -c config.json --step2
./3-etl-manager.sh -p aurora-postgresql -c config.json --step3

# 成功時の出力例
[INFO] Detected environment: remote
[SUCCESS] Integration ID retrieved and .env updated
[SUCCESS] Zero-ETL integration is active
[SUCCESS] Database created: multitenant_analytics_zeroetl
```

### ローカル環境での実行
```bash
# Phase 3の完全実行（ローカル）
./3-etl-manager.sh -p aurora-postgresql -c config.json --step1
./3-etl-manager.sh -p aurora-postgresql -c config.json --step2

# 成功時の出力例
[INFO] Detected environment: local
[INFO] Local environment detected - using pre-built local SQL files
[SUCCESS] Database created: multitenant_analytics_local
[SUCCESS] Sample data inserted for local development
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
