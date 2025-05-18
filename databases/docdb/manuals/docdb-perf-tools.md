# Amazon DocumentDB パフォーマンス分析ツールガイド

## 目次
1. [概要](#概要)
2. [パフォーマンス分析ツール](#パフォーマンス分析ツール)
   - [インデックス分析（index-review）](#インデックス分析index-review)
   - [メトリクス収集（metric-collector）](#メトリクス収集metric-collector)
   - [データ圧縮分析（compression-review）](#データ圧縮分析compression-review)
   - [デプロイメントスキャン（deployment-scanner）](#デプロイメントスキャンdeployment-scanner)
   - [インデックスカーディナリティ検出（index-cardinality-detection）](#インデックスカーディナリティ検出index-cardinality-detection)
3. [モニタリングツール](#モニタリングツール)
   - [リアルタイムコレクション監視（documentdb-top）](#リアルタイムコレクション監視documentdb-top)
   - [インスタンス統計表示（docdb-stat）](#インスタンス統計表示docdb-stat)
   - [ダッシュボード作成（docdb-dashboarder）](#ダッシュボード作成docdb-dashboarder)
   - [GC監視（gc-watchdog）](#gc監視gc-watchdog)
   - [カスタムメトリクス収集](#カスタムメトリクス収集)
4. [スパイク対策での活用方法](#スパイク対策での活用方法)
5. [定常的な負荷対策での活用方法](#定常的な負荷対策での活用方法)
6. [トラブルシューティングのベストプラクティス](#トラブルシューティングのベストプラクティス)
7. [よくある問題と解決方法](#よくある問題と解決方法)

## 概要

Amazon DocumentDBのパフォーマンス分析と監視のための公式ツールセットは、[amazon-documentdb-tools](https://github.com/awslabs/amazon-documentdb-tools)リポジトリで提供されています。これらのツールは、パフォーマンス問題の診断、最適化、継続的なモニタリングに役立ちます。

このガイドでは、各ツールの機能、インストール方法、使用例、およびスパイク対策や定常的な負荷対策での活用方法について説明します。

## パフォーマンス分析ツール

### インデックス分析（index-review）

#### 機能
- コレクションとインデックスの構造・使用状況を包括的に分析
- 未使用インデックスや冗長なインデックスを特定
- コレクションとインデックスの詳細情報をCSVファイルとして出力

#### 要件
- Python 3.7以上
- PyMongoライブラリ

#### 使用方法
```bash
python3 index-review.py --server-alias <サーバー別名> --uri <mongodb-uri>
```

#### 実行例
```bash
python3 index-review.py --server-alias prod-cluster1 --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false"
```

#### 出力の解釈
- JSON形式の詳細レポート
- 未使用/冗長インデックスのリスト
- コレクションとインデックスの詳細を含むCSVファイル

#### スパイク対策での活用
- インデックス問題の特定と最適化
- 不要なインデックスの削除によるリソース効率化
- クエリパフォーマンス向上のためのインデックス戦略の改善

### メトリクス収集（metric-collector）

#### 機能
- 指定したリージョン内のすべてのDocumentDBクラスターのメトリクスを収集
- クラスター名、エンジンバージョン、マルチAZ構成、TLSステータス、インスタンスタイプなどのメタデータを含む
- 指定した期間のメトリクスの最小値、最大値、平均値、p99値、標準偏差を計算

#### 要件
- Python 3.9以上
- boto3 1.24.49以上
- pandas 2.2.1以上

#### 使用方法
```bash
python3 metric-collector.py --region <aws-region-name> --log-file-name <output-file-name> --start-date <YYYYMMDD> --end-date <YYYYMMDD>
```

#### 実行例
```bash
python3 metric-collector.py --region ap-northeast-1 --log-file-name metrics-report.csv --start-date 20250501 --end-date 20250518
```

#### 出力の解釈
- CSVファイルにメトリクスデータが出力される
- [ベストプラクティス](https://docs.aws.amazon.com/documentdb/latest/developerguide/best_practices.html)と比較して分析可能

#### スパイク対策での活用
- パフォーマンス、耐障害性、コストの観点からクラスターとインスタンスのサイジングが適切かを評価
- スパイクの発生パターンを特定し、予測可能なスパイクに対する事前対策を計画
- リソース使用率の傾向分析による将来のキャパシティプランニング

### データ圧縮分析（compression-review）

#### 機能
- 各コレクションから1000件（デフォルト）のドキュメントをサンプリングしてデータ圧縮率を計算
- 様々な圧縮アルゴリズムとレベルでの圧縮効率を比較

#### 要件
- Python 3.7以上
- PyMongoライブラリ
- lz4 Pythonパッケージ
- zstandard Pythonパッケージ

#### 使用方法
```bash
python3 compression-review.py --uri <server-uri> --server-alias <server-alias> [--compressor <compression-type>]
```

#### 実行例
```bash
python3 compression-review.py --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false" --server-alias prod-cluster1 --compressor lz4-fast
```

#### 出力の解釈
- CSVファイルに各コレクションの圧縮率データが出力される
- 圧縮前後のサイズ比較
- 圧縮効率の統計

#### スパイク対策での活用
- ストレージ効率化によるコスト削減
- I/Oパフォーマンスの向上可能性評価
- 大量データ処理時のI/Oボトルネック軽減戦略の立案

### デプロイメントスキャン（deployment-scanner）

#### 機能
- 1つのアカウント/リージョン内のすべてのクラスターをスキャン
- 潜在的なコスト削減の提案を提供
- リソース使用率に基づく最適化推奨

#### 要件
- Python 3.7以上
- boto3ライブラリ
- PyMongoライブラリ

#### 使用方法
```bash
python3 deployment-scanner.py --region <aws-region> --output-file <output-file-name>
```

#### 実行例
```bash
python3 deployment-scanner.py --region ap-northeast-1 --output-file deployment-scan.json
```

#### 出力の解釈
- JSONファイルに最適化推奨事項が出力される
- クラスター構成の詳細
- コスト最適化の機会

#### スパイク対策での活用
- リソース使用率に基づくインスタンスサイズの最適化
- 過剰プロビジョニングの特定と修正
- コスト効率の向上

### インデックスカーディナリティ検出（index-cardinality-detection）

#### 機能
- ランダムなドキュメントをサンプリングしてインデックスのカーディナリティと選択性を推定
- インデックスの効率性を評価

#### 要件
- Python 3.7以上
- PyMongoライブラリ

#### 使用方法
```bash
python3 index-cardinality-detection.py --uri <mongodb-uri> --database <database-name> --collection <collection-name> [--sample-size <sample-size>]
```

#### 実行例
```bash
python3 index-cardinality-detection.py --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false" --database mydb --collection mycollection --sample-size 5000
```

#### 出力の解釈
- 各インデックスのカーディナリティと選択性の推定値
- インデックスの効率性評価

#### スパイク対策での活用
- クエリパフォーマンスの最適化
- 選択性の低いインデックスの特定と改善
- インデックス戦略の最適化

## モニタリングツール

### リアルタイムコレクション監視（documentdb-top）

#### 機能
- DocumentDBインスタンスに接続し、コレクションレベルのメトリクスをリアルタイムで継続的に取得
- `db.<collection>.stats()`を設定可能な間隔（デフォルト60秒）でポーリング

#### 要件
- Python 3.x
- PyMongoライブラリ
- Amazon DocumentDB証明書（CA）

#### 使用方法
```bash
python3 documentdb-top.py --uri <uri> --database <database> [--update-frequency-seconds <seconds>] [--must-crud] --log-file-name <log-file>
```

#### 実行例
```bash
python3 documentdb-top.py --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false&directConnection=true" --database mydb --update-frequency-seconds 15 --log-file-name collection-stats.log --must-crud
```

#### 出力の解釈
- リアルタイムのコレクション統計情報
- 挿入/更新/削除操作の発生状況
- 秒間操作数（オプション）

#### スパイク対策での活用
- スパイク発生時にリアルタイムでどのコレクションが影響を受けているかを特定
- 書き込み/更新/削除操作の発生を監視し、異常なアクティビティを検出
- 秒間操作数を表示することで、スパイクの強度と影響を定量的に評価

### インスタンス統計表示（docdb-stat）

#### 機能
- DocumentDBインスタンスの高レベル統計情報を表示
- サーバーステータス、接続情報、リソース使用率などを提供

#### 要件
- Python 3.x
- PyMongoライブラリ

#### 使用方法
```bash
python3 docdb-stat.py --uri <mongodb-uri> [--interval <seconds>]
```

#### 実行例
```bash
python3 docdb-stat.py --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false" --interval 5
```

#### 出力の解釈
- インスタンスレベルの統計情報
- 接続数、メモリ使用率、操作カウンターなど

#### スパイク対策での活用
- インスタンスレベルのパフォーマンス問題を迅速に特定
- リソース使用率の変化を監視し、スパイクの前兆を検出
- システム全体の健全性評価

### ダッシュボード作成（docdb-dashboarder）

#### 機能
- DocumentDBクラスター用の「スターター」ダッシュボードを作成
- 主要メトリクスを視覚的に表示

#### 要件
- Python 3.x
- boto3ライブラリ

#### 使用方法
```bash
python3 docdb-dashboarder.py --cluster-id <cluster-id> --region <aws-region>
```

#### 実行例
```bash
python3 docdb-dashboarder.py --cluster-id docdb-cluster-1 --region ap-northeast-1
```

#### 出力の解釈
- CloudWatchダッシュボード
- 視覚化されたメトリクス

#### スパイク対策での活用
- 主要メトリクスを視覚的に監視し、スパイクの早期検出
- カスタムアラートの設定基盤として活用
- パフォーマンストレンドの分析

### GC監視（gc-watchdog）

#### 機能
- ガベージコレクションのアクティビティを追跡
- ファイルまたはCloudWatchメトリクスに記録

#### 要件
- Python 3.x
- PyMongoライブラリ
- boto3ライブラリ（CloudWatchメトリクス使用時）

#### 使用方法
```bash
python3 gc-watchdog.py --uri <mongodb-uri> [--cloudwatch] [--region <aws-region>] [--namespace <namespace>]
```

#### 実行例
```bash
python3 gc-watchdog.py --uri "mongodb://user:password@docdb-instance-endpoint:27017/?tls=true&tlsCAFile=global-bundle.pem&retryWrites=false" --cloudwatch --region ap-northeast-1 --namespace DocumentDB/GC
```

#### 出力の解釈
- GCアクティビティのログまたはメトリクス
- GCの頻度と期間

#### スパイク対策での活用
- メモリ関連のスパイクの根本原因としてのGCアクティビティを監視
- GCによるパフォーマンス低下を検出し、メモリ設定の最適化機会を特定
- メモリ使用パターンの分析

### カスタムメトリクス収集

#### 機能
- DocumentDBクラスターのメトリクスを収集し、CloudWatchにカスタムメトリクスとして送信
- 標準メトリクス以外の詳細な情報を監視

#### 要件
- シェルスクリプト環境
- AWS CLI
- jqユーティリティ

#### 使用方法
```bash
./docdb-metric-collection.sh <cluster-identifier> <region> [namespace]
```

#### 実行例
```bash
./docdb-metric-collection.sh docdb-cluster-1 ap-northeast-1 DocumentDB/Custom
```

#### 出力の解釈
- CloudWatchカスタムメトリクス
- カスタムダッシュボードとアラーム

#### スパイク対策での活用
- 詳細なパフォーマンスモニタリング
- カスタムアラートの設定
- 特定のメトリクスに基づく自動スケーリングの設定

## スパイク対策での活用方法

### 事前分析と最適化

1. **インデックス構造の最適化**
   - `index-review`ツールを使用してインデックス構造を分析
   - 未使用インデックスを特定して削除
   - クエリパターンに基づいて必要なインデックスを追加

2. **データ圧縮の可能性評価**
   - `compression-review`ツールでデータ圧縮率を分析
   - 圧縮効率の高いコレクションを特定
   - ストレージ効率とI/Oパフォーマンスの向上

3. **過去のパフォーマンスパターン分析**
   - `metric-collector`ツールで過去のメトリクスを収集・分析
   - スパイクの発生パターンを特定
   - 予測可能なスパイクに対する事前対策を計画

4. **リソース使用率の最適化**
   - `deployment-scanner`ツールでリソース使用率を分析
   - 過剰プロビジョニングを特定して修正
   - コスト効率の向上

### リアルタイム監視

1. **コレクションレベルの異常検出**
   - `documentdb-top`ツールでコレクションレベルのメトリクスをリアルタイムで監視
   - 異常なアクティビティを検出
   - スパイクの影響を受けているコレクションを特定

2. **インスタンスレベルの問題監視**
   - `docdb-stat`ツールでインスタンスレベルの統計情報を監視
   - リソース使用率の変化を追跡
   - システム全体の健全性を評価

3. **視覚的なモニタリング**
   - `docdb-dashboarder`ツールで作成したダッシュボードで主要メトリクスを視覚的に監視
   - スパイクの早期検出
   - パフォーマンストレンドの分析

4. **メモリ関連の問題監視**
   - `gc-watchdog`ツールでガベージコレクションのアクティビティを監視
   - メモリ関連のスパイクの根本原因を特定
   - メモリ設定の最適化機会を特定

### スパイク発生時の診断

1. **影響を受けているコレクションの特定**
   - `documentdb-top`ツールでリアルタイムのコレクション統計情報を確認
   - スパイクの影響を受けているコレクションを特定
   - 問題の範囲を把握

2. **リソース使用率のボトルネック特定**
   - `docdb-stat`ツールでインスタンスレベルの統計情報を確認
   - CPU、メモリ、I/Oのボトルネックを特定
   - リソース使用率の変化を追跡

3. **GCアクティビティの確認**
   - `gc-watchdog`ツールでガベージコレクションのアクティビティを確認
   - GCがスパイクに関連しているかを判断
   - メモリ使用パターンを分析

4. **インデックス使用状況の確認**
   - `index-review`ツールでインデックス使用状況を確認
   - インデックス問題がスパイクに関連しているかを判断
   - インデックス戦略の最適化機会を特定

## 定常的な負荷対策での活用方法

### 継続的なモニタリングと最適化

1. **定期的なインデックス分析**
   - `index-review`ツールを定期的に実行してインデックス使用状況を分析
   - インデックス戦略を継続的に最適化
   - 未使用インデックスを定期的に削除

2. **リソース使用率の継続的な監視**
   - `metric-collector`ツールで定期的にメトリクスを収集・分析
   - リソース使用率の傾向を把握
   - 将来のキャパシティプランニングに活用

3. **コスト最適化の定期的な評価**
   - `deployment-scanner`ツールを定期的に実行してコスト最適化の機会を特定
   - リソース使用率に基づいてインスタンスサイズを最適化
   - コスト効率を継続的に向上

4. **パフォーマンスベースラインの確立**
   - 各ツールの出力を定期的に収集して正常時のパフォーマンスベースラインを確立
   - 異常を早期に検出するための基準を設定
   - パフォーマンス劣化の傾向を把握

### 長期的な最適化戦略

1. **データモデルの最適化**
   - `compression-review`ツールの結果を活用してデータモデルを最適化
   - ストレージ効率とI/Oパフォーマンスを向上
   - 長期的なコスト削減

2. **インデックス戦略の継続的な改善**
   - `index-cardinality-detection`ツールを活用してインデックスの選択性を評価
   - クエリパターンの変化に応じてインデックス戦略を調整
   - クエリパフォーマンスを継続的に向上

3. **リソースプロビジョニングの最適化**
   - `metric-collector`と`deployment-scanner`の結果を組み合わせてリソースプロビジョニングを最適化
   - 使用パターンに基づいてインスタンスタイプを選択
   - コスト効率と性能のバランスを最適化

4. **監視戦略の継続的な改善**
   - 各モニタリングツールの組み合わせを最適化
   - カスタムメトリクスとアラートを設定
   - 問題の早期検出と迅速な対応を実現

## トラブルシューティングのベストプラクティス

### ツールの組み合わせによる包括的な分析

1. **複数のツールを組み合わせた分析**
   - 単一のツールだけでなく、複数のツールを組み合わせて包括的な分析を行う
   - 例: `index-review`と`documentdb-top`を組み合わせてインデックス問題とクエリパフォーマンスの関連を分析

2. **定期的な分析の自動化**
   - ツールの実行を自動化して定期的に分析を行う
   - 結果を時系列で保存して傾向分析を可能にする

3. **ベースラインとの比較分析**
   - 正常時のパフォーマンスベースラインを確立し、異常時との比較分析を行う
   - 変化点を特定して根本原因の分析に活用

### 効果的なツール使用のためのヒント

1. **適切なサンプルサイズの選択**
   - データ量に応じて適切なサンプルサイズを選択する
   - 大規模なコレクションでは、サンプルサイズを増やして精度を向上させる

2. **実行タイミングの最適化**
   - 負荷の少ない時間帯にリソース集約型のツールを実行する
   - 本番環境への影響を最小限に抑える

3. **結果の定期的な保存と比較**
   - ツールの実行結果を定期的に保存し、時系列での比較を可能にする
   - パフォーマンス変化の傾向を把握する

## よくある問題と解決方法

### ツール実行時の問題

1. **接続エラー**
   - **問題**: ツールがDocumentDBインスタンスに接続できない
   - **解決策**: 
     - URIの形式が正しいか確認
     - TLS設定とCA証明書の場所を確認
     - セキュリティグループの設定を確認
     - ネットワーク接続を確認

2. **権限エラー**
   - **問題**: 必要な権限がないためツールが実行できない
   - **解決策**:
     - 必要な権限を持つユーザーを使用
     - 各ツールの必要権限を確認して付与

3. **メモリ不足エラー**
   - **問題**: 大規模なコレクションでツールを実行するとメモリ不足になる
   - **解決策**:
     - サンプルサイズを小さくする
     - より多くのメモリを持つ環境で実行
     - バッチ処理を導入

### 結果の解釈に関する問題

1. **不正確なサンプリング結果**
   - **問題**: サンプリングベースのツールの結果が不正確
   - **解決策**:
     - サンプルサイズを増やす
     - 複数回実行して結果を平均化
     - データ分布を考慮したサンプリング戦略を採用

2. **メトリクスの解釈が難しい**
   - **問題**: 収集したメトリクスの意味や重要性が不明確
   - **解決策**:
     - [DocumentDBのメトリクスリファレンス](https://docs.aws.amazon.com/documentdb/latest/developerguide/monitoring.html)を参照
     - ベースラインと比較して相対的な変化を分析
     - 複数のメトリクスを組み合わせて包括的に分析

3. **最適化推奨事項の適用が難しい**
   - **問題**: ツールが提案する最適化推奨事項の適用方法が不明確
   - **解決策**:
     - 推奨事項を段階的に適用して効果を測定
     - テスト環境で先に検証
     - AWS Support または専門家に相談
