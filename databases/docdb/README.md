# DocumentDB Investigation Tools

このリポジトリには、Amazon DocumentDB クラスターのパフォーマンス分析と問題診断のための一連のコマンドが含まれています。これらのコマンドは、Performance Insights、CloudWatch メトリクス、およびネイティブデータベースコマンドを使用して、包括的な調査を可能にします。

## 前提条件

- AWS CloudShell 環境での実行を推奨（AWS CLI と MongoDB シェル（mongosh）が事前にインストールされています）
- または、以下のツールが必要です：
  - AWS CLI がインストールされ、適切に設定されていること
  - MongoDB シェル（mongosh）がインストールされていること
- DocumentDB クラスターが作成され、アクセス可能であること

## 使用方法

すべてのコマンドは、DocumentDB クラスター名を環境変数として受け取ります：

```bash
CLUSTER_NAME=docdb-2025-05-17-08-21-41 make <command>
```

インデックスやコレクション関連のコマンドでは、データベース名とコレクション名も必要です：

```bash
CLUSTER_NAME=docdb-2025-05-17-08-21-41 make show-index-stats db_name=mydb collection_name=users
```

## コマンドの詳細

### 接続コマンド

DocumentDBに接続するには、以下のコマンドを使用します：

```bash
# 環境変数を使用してDocumentDBに接続
DOCDB_USERNAME=littlemex \
DOCDB_PASSWORD=your_password \
CLUSTER_NAME=docdb-2025-05-17-08-21-41 \
make connect
```

このコマンドは以下の処理を行います：
1. 環境変数からユーザー名とパスワードを安全に取得
2. SSL証明書（global-bundle.pem）を自動的にダウンロード
3. クラスター名からエンドポイントを構築
4. mongoshを使用してDocumentDBに安全に接続

セキュリティ上の利点：
- パスワードがコマンドライン履歴に残らない
- 証明書は一時ディレクトリで管理され、使用後に自動的に削除
- 接続情報はクラスター名から動的に構築

#### 接続のカスタマイズ

接続設定をカスタマイズするには、以下の環境変数を使用できます：

```bash
# カスタム接続設定の例
DOCDB_USERNAME=littlemex \
DOCDB_PASSWORD=your_password \
DOCDB_DOMAIN=custom-domain.docdb.amazonaws.com \
DOCDB_PORT=27017 \
DOCDB_DEBUG=true \
CLUSTER_NAME=docdb-2025-05-17-08-21-41 \
make connect
```

| 環境変数 | 説明 | デフォルト値 |
|----------|------|-------------|
| DOCDB_USERNAME | 接続ユーザー名 | (必須) |
| DOCDB_PASSWORD | 接続パスワード | (必須) |
| CLUSTER_NAME | クラスター名 | (必須) |
| DOCDB_DOMAIN | DocumentDBのドメイン部分 | czgdzfkc9hwn.us-east-1.docdb.amazonaws.com |
| DOCDB_PORT | 接続ポート | 27017 |
| DOCDB_DEBUG | デバッグモードの有効化 | false |

#### 接続のトラブルシューティング

接続に問題がある場合は、以下の点を確認してください：

1. **ネットワークアクセス**
   - DocumentDBクラスターはVPC内にあり、直接インターネットからアクセスできない場合があります
   - EC2インスタンスやCloud9環境など、同じVPC内からアクセスしているか確認
   - 必要に応じてSSHトンネルやVPN接続を設定

2. **セキュリティグループ**
   - クラスターのセキュリティグループで、接続元のIPアドレスからのアクセスが許可されているか確認
   - インバウンドルールでポート27017が開放されているか確認

3. **認証情報**
   - ユーザー名とパスワードが正しいか確認
   - ユーザーがクラスターへのアクセス権限を持っているか確認

4. **デバッグモード**
   - `DOCDB_DEBUG=true` を設定して詳細情報を表示
   ```bash
   DOCDB_USERNAME=littlemex \
   DOCDB_PASSWORD=your_password \
   DOCDB_DEBUG=true \
   CLUSTER_NAME=docdb-2025-05-17-08-21-41 \
   make connect
   ```

### Performance Insights コマンド

Performance Insights は、データベースのパフォーマンスを可視化し、問題を分析するための強力なツールです。これらのコマンドを使用するには、以下の前提条件を満たす必要があります：

1. Performance Insights が有効化されていること（`make pi-enable` で有効化）
2. 適切な IAM 権限が付与されていること（`make pi-enable` で自動設定）

#### セットアップコマンド

- `make pi-enable`: Performance Insights を有効化し、必要な IAM 権限を設定します。
  - DB インスタンスのダウンタイム、再起動、フェイルオーバーは発生しません
  - Performance Insights エージェントは DB ホストの限られた CPU とメモリを消費
  - DB のロードが高い場合はデータ収集の頻度を下げることでパフォーマンスへの影響を抑えます
  - 必要な IAM ポリシーを作成または更新し、現在のユーザー/ロールにアタッチします
  - 注意: このコマンドは、DocumentDBに対してRDSのPerformance Insightsリソースへのアクセスを許可します

- `make pi-disable`: Performance Insights を無効化します。

#### メトリクス取得コマンド

- `make get-pi-key`: Performance Insights API キーを取得します。

- `make get-counter-metrics`: データベースの重要なカウンターメトリクスを取得します：(TBD)
  - ブロック読み取り数（blks_read.avg）
  - キャッシュヒット数（blks_hit.avg）
  - トランザクションコミット数（xact_commit.avg）

- `make get-detailed-metrics`: 詳細なパフォーマンスメトリクスを取得します：
  - メモリ使用状況（アクティブ、空き、合計）
  - CPU使用率の詳細（nice、system）
  - その他のシステムレベルのメトリクス

- `make get-resource-metrics`: インスタンスのリソースメトリクスを取得します：
  - CPU 使用率（ユーザーおよびアイドル）

- `make get-top-wait-states`: 上位の待機状態を取得します：
  - パフォーマンスのボトルネックとなっている要因を特定

#### ディメンション分析コマンド

- `make list-available-dimensions`: Performance Insights で利用可能なディメンションの一覧を表示します。主なディメンションには以下があります：
  - db.wait_state: 待機状態によるロードの分析
  - db.user: データベースユーザー別の分析
  - db.host: クライアントホスト別の分析
  - db.query: SQLクエリ別の分析
  - db.application: アプリケーション別の分析
  - db.session_type: セッションタイプ別の分析

- `make get-dimension-metrics dimension=<dimension_name>`: 指定したディメンションでメトリクスを集計します。例：
  ```bash
  # 利用可能なディメンションの確認
  CLUSTER_NAME=your-cluster make list-available-dimensions
  
  # ユーザー別のメトリクス取得
  CLUSTER_NAME=your-cluster make get-dimension-metrics dimension=db.user
  
  # 待機状態別のメトリクス取得
  CLUSTER_NAME=your-cluster make get-dimension-metrics dimension=db.wait_state
  ```

#### トラブルシューティング

Performance Insights APIを使用するコマンドが権限エラー（NotAuthorizedException）で失敗する場合は、以下を確認してください：

1. Performance Insights が有効化されているか
   ```bash
   # インスタンスの状態を確認
   aws docdb describe-db-instances --db-instance-identifier <instance-id> --query 'DBInstances[0].PerformanceInsightsEnabled'
   ```

2. IAM ユーザー/ロールに必要な権限が付与されているか
   ```bash
   # 権限を設定
   CLUSTER_NAME=your-cluster make pi-enable
   ```

3. 対象のインスタンスが Performance Insights をサポートしているか
   - DocumentDB 4.0 以降のインスタンスが必要です
   - インスタンスタイプによっては Performance Insights をサポートしていない場合があります

4. IAMポリシーが正しく設定されているか
   - `pi-policy.json`ファイルの内容を確認し、RDSのPerformance Insightsリソースへのアクセスが許可されていることを確認してください

### スクリプトの使用

Performance Insights 関連のコマンドは、`scripts/` ディレクトリ内のシェルスクリプトを使用して実行されます。これらのスクリプトは、Makefile から呼び出されますが、必要に応じて直接実行することもできます。

例：
```bash
./scripts/pi-enable.sh your-cluster-name
./scripts/get-counter-metrics.sh your-cluster-name
```

各スクリプトは、クラスター名を引数として受け取ります。スクリプトを直接実行する場合は、適切な権限があることを確認してください。

注意: `pi-enable.sh`スクリプトは、DocumentDBクラスターに対してRDSのPerformance Insightsリソースへのアクセスを許可するIAMポリシーを設定します。これは、DocumentDBがRDSと同じPerformance Insights APIを使用するためです。

### CloudWatch メトリクスコマンド

CloudWatch メトリクスは、クラスターの運用状態を長期的に監視するために使用されます。

- `make get-db-load`: DBLoad メトリクスを取得します。このメトリクスは Amazon DocumentDB のアクティブセッション数を示し、通常、アクティブセッションの平均数に関するデータを提供します。

- `make get-cpu-metrics`: CPU 使用率メトリクスを取得します。これにより、インスタンスの計算リソースの使用状況を監視できます。

### データベース操作分析コマンド

これらのコマンドは、データベースの現在の状態とパフォーマンスを分析するために使用されます。

- `make show-current-ops`: 現在実行中のすべての操作を表示します。これにより、データベースで実行されているすべてのクエリとオペレーションを確認できます。

- `make show-slow-ops`: 10秒以上実行されている操作やブロックされている操作を表示します。長時間実行されているクエリを特定し、パフォーマンスの問題を診断するのに役立ちます。

- `make show-ops-by-namespace`: 名前空間ごとの操作の集計を表示します。これには内部システムタスクと、名前空間ごとの固有の待機状態の数も含まれます。

### インデックス分析コマンド

インデックスの効率性を評価し、最適化するためのコマンドです。

- `make show-index-stats`: インデックスの統計情報を表示します。これにより、インデックスの使用状況と効率性を分析できます。

- `make show-collection-stats`: コレクションの統計情報を表示します。これには、実行された挿入、更新、削除の操作量や、インデックススキャンとコレクションのフルスキャンの量が含まれます。

### リソースメトリクスコマンド

Performance Insights API を使用して詳細なリソース使用状況を分析します。

- `make get-resource-metrics`: インスタンスのリソースメトリクスを取得します。CPU 使用率（ユーザーおよびアイドル）などの詳細な情報を提供します。

- `make get-top-wait-states`: 上位の待機状態を取得します。これにより、パフォーマンスのボトルネックとなっている要因を特定できます。

## 本番環境への影響

これらのコマンドを実行する際は、以下の点に注意してください：

- Performance Insights の有効化/無効化はダウンタイムを引き起こしませんが、わずかなリソース消費が発生します。
- CloudWatch メトリクスの取得は読み取り専用操作で、本番環境への影響はありません。
- データベース操作分析コマンドは読み取り専用ですが、大規模なクラスターでの実行時には注意が必要です。
- インデックス分析は読み取り専用操作ですが、大きなコレクションでは実行時間が長くなる可能性があります。

## 実行環境

これらのコマンドは **AWS CloudShell** での実行を想定しています。CloudShell には AWS CLI と MongoDB シェル（mongosh）が事前にインストールされており、AWS 認証情報も自動的に設定されています。

CloudShell を使用するには：
1. AWS マネジメントコンソールにログイン
2. 画面上部のナビゲーションバーにある CloudShell アイコンをクリック
3. CloudShell が起動したら、このリポジトリのコマンドを実行

## トラブルシューティング

コマンドが失敗した場合は、以下を確認してください：

1. CLUSTER_NAME 環境変数が正しく設定されているか
2. AWS CLI の認証情報が正しく設定されているか（CloudShell 以外の環境で実行する場合）
3. 指定したクラスターが存在し、アクセス可能か
4. 必要な IAM 権限が付与されているか
5. CloudShell 以外の環境で実行する場合は、mongosh がインストールされているか

詳細なエラーメッセージは、各コマンドの出力を確認してください。

## 使用例

基本的な使用例：
```bash
# DocumentDBへの接続（環境変数を使用）
DOCDB_USERNAME=littlemex \
DOCDB_PASSWORD=your_password \
CLUSTER_NAME=docdb-2025-05-17-08-21-41 \
make connect

# CPU メトリクスの取得
CLUSTER_NAME=docdb-2025-05-17-08-21-41 make get-cpu-metrics

# 現在の操作の表示
CLUSTER_NAME=docdb-2025-05-17-08-21-41 make show-current-ops

# インデックス統計情報の表示
CLUSTER_NAME=docdb-2025-05-17-08-21-41 make show-index-stats db_name=mydb collection_name=users
```

ヘルプの表示：
```bash
make help
```
