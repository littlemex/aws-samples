# Phase 2: マルチテナント分析プラットフォーム - データベースセットアップ

## 🎯 概要

Bastion Host経由でAurora PostgreSQLにマルチテナント分析プラットフォームのデータベース構造を構築します。本フェーズでは、自動化されたファイル転送とSSM実行により、セキュアで効率的なデータベースセットアップを実現します。

## 🚀 実行手順

Aurora PostgreSQLとローカルのDocker上のPostgresのどちらに対してもクエリを実行することが可能です。

### リモート実行（Aurora PostgreSQL）

#### 基本的な4ステップ実行

```bash
# 1. データベース作成（postgresデータベースに接続してmultitenant_analyticsを作成）
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/database/create-multitenant-database.sql"

# 2. スキーマ・テーブル作成（multitenant_analyticsデータベースに接続）
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/schema/create-tenant-schemas.sql"

# 3. サンプルデータ投入
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/data/insert-sample-data.sql"

# 4. セットアップ検証
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"

---
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/database/drop-multitenant-database.sql"
```

### ローカル実行（Docker PostgreSQL）

#### 開発・テスト用ローカル実行

```bash
# 1. データベース作成（postgresデータベースに接続してmultitenant_analyticsを作成）
./2-etl-manager.sh -p aurora-postgresql -c config.json --local --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/database/create-multitenant-database.sql"

# 2. スキーマ・テーブル作成（multitenant_analyticsデータベースに接続）
./2-etl-manager.sh -p aurora-postgresql -c config.json --local --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/schema/create-tenant-schemas.sql"

# 3. サンプルデータ投入
./2-etl-manager.sh -p aurora-postgresql -c config.json --local --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/data/insert-sample-data.sql"

# 4. セットアップ検証
./2-etl-manager.sh -p aurora-postgresql -c config.json --local --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"

---
# データベース削除
./2-etl-manager.sh -p aurora-postgresql -c config.json --local --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/database/drop-multitenant-database.sql"
```

#### ローカル実行の特徴
- **Docker Compose**: PostgreSQLコンテナを自動起動
- **自動ファイル転送**: config.jsonの設定に基づいてDockerコンテナにファイルをコピー
- **dbt統合**: 動的テナント処理マクロのテスト実行が可能
- **開発効率**: AWSリソース不要で高速な開発・テストサイクル

### ⚡ 高速実行（--skip-copyオプション）

2回目以降の実行では、ファイル転送をスキップして実行時間を大幅短縮できます：

```bash
# ファイル転送をスキップして検証のみ実行（約10-15秒短縮）
./2-etl-manager.sh -p aurora-postgresql -c config.json --skip-copy --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"
```

**注意**: `--skip-copy`は既にファイルがBastion Hostに転送済みの場合のみ使用してください。

## 🏗️ システム構成図

### リモート実行（Aurora PostgreSQL）
```mermaid
graph TB
    A[2-etl-manager.sh] --> B{--skip-copy?}
    B -->|No| C[config.json読込]
    B -->|Yes| H[既存/tmp/workspace使用]
    C --> D[bastion.phase2.autoTransfer設定確認]
    D --> E[sql/aurora + scripts/aurora-sql-execute.sh]
    E --> F[tar.gz圧縮 + Base64エンコード]
    F --> G[SSM経由でBastion Hostに転送]
    G --> I[ディレクトリ/tmp/workspace/に展開]
    I --> J[Aurora接続情報取得]
    J --> K[CloudFormation + Secrets Manager]
    K --> L[環境変数設定]
    L --> M[SSM経由コマンド実行]
    H --> N[workspace存在確認]
    N --> L
    M --> O[scripts/aurora-sql-execute.sh]
    O --> P[SQLファイルパス解析]
    P --> Q[フェーズ自動検出]
    Q --> R{接続先データベース決定}
    R -->|database| S[postgres DB接続]
    R -->|schema/data/verification| T[multitenant_analytics DB接続]
    S --> U[psql実行]
    T --> U
    U --> V[SQL実行結果]
    
    style A fill:#e1f5fe
    style O fill:#f3e5f5
    style V fill:#e8f5e8
    style D fill:#fff3e0
    style K fill:#f1f8e9
```

### ローカル実行（Docker PostgreSQL）
```mermaid
graph TB
    A[2-etl-manager.sh --local] --> B{--skip-copy?}
    B -->|No| C[config.json読込]
    B -->|Yes| H[既存ファイル使用]
    C --> D[Docker Compose PostgreSQL起動]
    D --> E[bastion.phase2.autoTransfer設定確認]
    E --> F[multitenant-analytics-platform-dbt-local-1コンテナ]
    F --> G[ディレクトリ/usr/appにファイルコピー]
    G --> I[LOCAL_EXECUTION=true設定]
    I --> J[ローカルコマンド実行]
    H --> J
    J --> K[scripts/aurora-sql-execute.sh]
    K --> L[LOCAL_EXECUTION検出]
    L --> M[ローカル設定読込]
    M --> N[localhost:5432 + dbt_user認証]
    N --> O[フェーズ自動検出]
    O --> P{接続先データベース決定}
    P -->|database| Q[postgres DB接続]
    P -->|schema/data/verification| R[multitenant_analytics DB接続]
    Q --> S[psql実行]
    R --> S
    S --> T[SQL実行結果]
    
    style A fill:#e8f5e8
    style K fill:#f3e5f5
    style T fill:#e8f5e8
    style E fill:#fff3e0
    style M fill:#f1f8e9
```

## 📁 ディレクトリ構造

```
multitenant-analytics-platform/
├── 2-etl-manager.sh              # メインオーケストレーションスクリプト
├── config.json                   # 統合設定ファイル
├── scripts/
│   └── aurora-sql-execute.sh         # SQL実行エンジン（フェーズ対応）
└── sql/
    ├── aurora/                   # Aurora PostgreSQL用SQL
    │   ├── database/
    │   │   └── create-multitenant-database.sql    # DB作成
    │   ├── schema/
    │   │   └── create-tenant-schemas.sql           # スキーマ・テーブル作成
    │   ├── data/
    │   │   └── insert-sample-data.sql              # サンプルデータ
    │   └── verification/
    │       └── verify-setup.sql                    # 検証クエリ
    └── redshift/                 # Redshift用（Phase 3で使用）
```

## ⚙️ コンポーネントの役割

### 1. `2-etl-manager.sh` - オーケストレーション層
- **ファイル転送管理**: `config.json`の`bastion.phase2.autoTransfer`設定に基づく自動転送
- **SSM実行制御**: Session Managerを通じたセキュアなコマンド実行
- **Aurora接続情報取得**: CloudFormationとSecrets Managerからの動的取得
- **エラーハンドリング**: 実行結果の監視と適切なエラー報告

### 2. `scripts/aurora-sql-execute.sh` - SQL実行エンジン
- **フェーズ自動検出**: SQLファイルパスから実行フェーズを判定
- **接続先DB切替**: フェーズに応じた適切なデータベース選択
- **環境変数管理**: Aurora接続情報の安全な受け渡し
- **実行結果報告**: 詳細なログ出力とエラー情報

### 3. `config.json` - 統合設定管理
```json
{
  "aurora": {
    "phases": {
      "database": {
        "connection_db": "postgres",
        "description": "Database creation phase"
      },
      "schema": {
        "connection_db": "multitenant_analytics", 
        "description": "Schema creation phase"
      },
      "data": {
        "connection_db": "multitenant_analytics",
        "description": "Data insertion phase"
      },
      "verification": {
        "connection_db": "multitenant_analytics",
        "description": "Verification phase"
      }
    }
  },
  "bastion": {
    "phase2": {
      "autoTransfer": {
        "enabled": true,
        "directories": ["sql/aurora"],
        "files": ["config.json", "scripts/aurora-sql-execute.sh"],
        "excludePatterns": ["*.log", "*.tmp", "target/", "*.pyc", "__pycache__/", ".venv/", "dbt_packages/", "logs/"],
        "compressionLevel": 6
      }
    }
  }
}
```

### 4. SQL資産（`sql/aurora/`）
- **フェーズベース分類**: 実行順序と依存関係を明確化
- **単一責任原則**: 各SQLファイルは特定の目的に特化
- **再利用性**: テナント追加時もスクリプト変更不要

## 🔄 ファイル転送メカニズム

### 自動転送プロセス
1. **アーカイブ作成**: `sql/aurora/`, `scripts/aurora-sql-execute.sh`, `config.json`をtar.gz形式で圧縮
2. **Base64エンコード**: SSM経由での安全な転送のため（1MB制限対応）
3. **Bastion Host展開**: `/tmp/workspace/`ディレクトリに展開
4. **実行権限付与**: スクリプトファイルに自動で実行権限設定
5. **除外パターン適用**: ログファイル、一時ファイル、キャッシュディレクトリを除外

### 相対パス使用が可能な理由
```bash
# Bastion Host上での実行例
cd /tmp/workspace
export AURORA_ENDPOINT='...' AURORA_USER='...' AURORA_PASSWORD='...'
scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql
```
ワーキングディレクトリを`/tmp/workspace`に変更するため、相対パスでファイル参照が可能です。

## 🔧 フェーズベース実行システム

### フェーズ検出ロジック
```bash
# SQLファイルパスからフェーズを自動検出
sql/aurora/database/create-multitenant-database.sql  → database フェーズ
sql/aurora/schema/create-tenant-schemas.sql          → schema フェーズ  
sql/aurora/data/insert-sample-data.sql               → data フェーズ
sql/aurora/verification/verify-setup.sql             → verification フェーズ
```

### 接続データベース切替
| フェーズ | 接続先DB | 理由 |
|----------|----------|------|
| `database` | `postgres` | 新データベース作成のため既存DBに接続 |
| `schema` | `multitenant_analytics` | 作成済みDBに対してスキーマ作成 |
| `data` | `multitenant_analytics` | テーブルが存在するDBに接続 |
| `verification` | `multitenant_analytics` | データ確認のため対象DBに接続 |

## 🆚 自動化 vs 手動運用

検証作業時にはどちらをお使いいたでいても構いません。

### 🤖 自動化実行
```bash
# ワンコマンドでセキュアな実行
./2-etl-manager.sh -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"
```

**メリット:**
- ✅ セキュアなSSM Session Manager経由実行
- ✅ 自動ファイル転送とクリーンアップ  
- ✅ 実行ログの詳細記録
- ✅ エラー時の適切な情報出力

### 🔧 手動実行
```bash
# Bastion Hostに手動ログイン
aws ssm start-session --target i-04c3d030b10847eab

# 手動でファイル配置とSQL実行
sudo -u ec2-user -i
mkdir -p /tmp/manual-workspace
# ファイルを手動でコピー...
psql -h aurora-endpoint -U postgres -d multitenant_analytics -f verify-setup.sql
```

## ✅ 実行結果の確認

### データベース構造確認
```bash
./2-etl-manager.sh -p aurora-postgresql -c config.json --skip-copy --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"
```

**期待される出力例:**
```
 schemaname
------------
 tenant_a
 tenant_b  
 tenant_c
(3 rows)

 schemaname | tablename | tableowner
------------+-----------+------------
 tenant_a   | users     | postgres
 tenant_b   | users     | postgres
 tenant_c   | users     | postgres
(3 rows)

  tenant  | user_count
----------+------------
 tenant_a |          5
 tenant_b |          5
 tenant_c |          5
(3 rows)
```

## 🎯 次フェーズ準備

Phase 3（Zero-ETL Integration）進行の前提条件、

### ✅ 必須完了項目
- [x] `multitenant_analytics` データベース作成済み
- [x] 3つのテナントスキーマ（`tenant_a`, `tenant_b`, `tenant_c`）存在
- [x] 各スキーマに`users`テーブル作成済み
- [x] 各テナントに5件のサンプルデータ投入済み
- [x] Zero-ETL Data Filter準備完了:
  ```
  include: multitenant_analytics.tenant_a.users
  include: multitenant_analytics.tenant_b.users
  include: multitenant_analytics.tenant_c.users
  ```

詳細は `README-PHASE-3.md` を参照してください。
