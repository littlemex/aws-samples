# Amazon DocumentDB トラブルシューティングガイド

## 目次
1. [概要](#概要)
2. [スパイク対策フローチャート](#スパイク対策フローチャート)
3. [スパイク対策の詳細調査フロー](#スパイク対策の詳細調査フロー)
4. [定常的な負荷対策フローチャート](#定常的な負荷対策フローチャート)
5. [定常的な負荷対策の詳細調査フロー](#定常的な負荷対策の詳細調査フロー)
6. [ユーザー診断ガイド](#ユーザー診断ガイド)

## ユーザー診断ガイド

パフォーマンス問題の診断や調査に関する詳細な情報は、[ユーザー診断ガイド](spike-10-diagnostics.md)を参照してください。このガイドでは、以下の内容を提供します：

- システム診断の基本フロー
- キャッシュパフォーマンス分析
- クエリ診断と最適化
- コレクション操作統計の確認
- Elastic Cluster診断
- システム全体のモニタリング

## 概要

このガイドでは、Amazon DocumentDBのパフォーマンス問題に対するトラブルシューティングフローを提供します。
トラブルシューティングは大きく「スパイク対策」と「定常的な負荷対策」の2つに分けられます。

- **スパイク対策**: 突発的な負荷増加や一時的なパフォーマンス低下に対する対応
- **定常的な負荷対策**: 継続的なパフォーマンス最適化と長期的な安定運用のための対策

各フローチャートでは、クラスタータイプ（Instance-based ClusterまたはElastic Cluster）に応じた調査パスを示し、
具体的なメトリクス値に基づいて問題の原因を特定します。

現時点でフローチャートは完全な網羅性を持つわけではないためあくまで参考程度に利用して下さい。

## スパイク対策フローチャート

```mermaid
flowchart TD
    Start([スパイク検知]) --> CheckType{クラスタータイプ?}
    
    CheckType -->|Instance-based Cluster| CheckPI[Performance Insightsで<br>トップクエリ確認]
    CheckType -->|Elastic Cluster| CheckMetrics[CloudWatchメトリクスで<br>負荷状況確認]
    
    CheckPI --> PIResult{問題のクエリ特定?}
    PIResult -->|Yes| QueryIssue[3.クエリ問題]
    PIResult -->|No| CheckResources[リソースメトリクス確認]
    
    CheckMetrics --> MetricsResult{どのメトリクスで<br>スパイク検知?}
    MetricsResult -->|CPU使用率| CPUSpike[1.リソース問題<br>CPU]
    MetricsResult -->|メモリ使用率| MemorySpike[1.リソース問題<br>メモリ]
    MetricsResult -->|接続数| ConnectionSpike[2.接続問題]
    MetricsResult -->|I/O関連| IOSpike[4.I/O問題]
    
    CheckResources --> ResourceResult{どのリソースが<br>ボトルネック?}
    ResourceResult -->|CPU| CPUSpike
    ResourceResult -->|メモリ| MemorySpike
    ResourceResult -->|接続数| ConnectionSpike
    ResourceResult -->|I/O| IOSpike
    ResourceResult -->|その他| IndexCheck[インデックス使用状況確認]
    
    IndexCheck --> IndexResult{インデックス問題?}
    IndexResult -->|Yes| IndexIssue[5.インデックス問題]
    IndexResult -->|No| ConfigCheck[設定確認]
    
    ConfigCheck --> ConfigResult{設定問題?}
    ConfigResult -->|Yes| ConfigIssue[6.設定問題]
    ConfigResult -->|No| UnknownIssue[7.未特定問題]
```

## スパイク対策の詳細調査フロー

### 1. リソース問題（CPU）

```mermaid
flowchart TD
    CPUStart([CPU問題検出]) --> CPUCheck{CPU使用率?}
    
    CPUCheck -->|\>80%| CheckInstance{インスタンスタイプ?}
    CPUCheck -->|<80%| CheckSpike{急激な変動?}
    
    CheckInstance -->|T3/T4g| CheckCredit{CPUクレジット残量?}
    CheckInstance -->|R5/R6g/R7g| CheckLoad{DBLoad内訳?}
    
    CheckCredit -->|少ない/枯渇| Solution1[1.1 インスタンスタイプ変更<br>T系からR系へ]
    CheckCredit -->|十分| CheckLoad
    
    CheckLoad -->|読み取り負荷大| Solution2[1.2 読み取り負荷分散<br>レプリカ追加]
    CheckLoad -->|書き込み負荷大| Solution3[1.3 書き込み最適化<br>バッチ処理見直し<br>Elastic Cluster検討]
    CheckLoad -->|クエリ処理大| Solution4[1.4 クエリ最適化<br>インデックス見直し]
    
    CheckSpike -->|Yes| CheckTiming{タイミング?}
    CheckSpike -->|No| OtherIssue[他の問題を調査]
    
    CheckTiming -->|バッチ処理と一致| Solution5[1.5 バッチ処理最適化<br>時間帯分散]
    CheckTiming -->|定期的| Solution6[1.6 定期処理見直し]
    CheckTiming -->|不規則| Solution7[1.7 アクセスパターン分析]
```

### 2. 接続問題

```mermaid
flowchart TD
    ConnStart([接続問題検出]) --> ConnCheck{接続数?}
    
    ConnCheck -->|急増| CheckPattern{パターン?}
    ConnCheck -->|上限近い| Solution1[2.1 接続数上限引き上げ<br>インスタンスサイズアップ]
    
    CheckPattern -->|短時間で接続/切断繰り返し| Solution2[2.2 コネクションプール設定見直し]
    CheckPattern -->|徐々に増加し続ける| Solution3[2.3 接続リーク調査<br>アプリケーション修正]
    CheckPattern -->|突発的な急増| Solution4[2.4 アクセス集中調査<br>負荷分散検討]
    
    ConnCheck -->|エラー多発| CheckError{エラータイプ?}
    
    CheckError -->|認証エラー| Solution5[2.5 認証情報確認]
    CheckError -->|タイムアウト| Solution6[2.6 ネットワーク調査<br>タイムアウト設定見直し]
    CheckError -->|接続拒否| Solution7[2.7 セキュリティグループ確認]
```

### 3. クエリ問題

```mermaid
flowchart TD
    QueryStart([クエリ問題検出]) --> PICheck{Performance Insights<br>利用可能?}
    
    PICheck -->|Yes| TopQuery[トップクエリ特定]
    PICheck -->|No| SlowQuery[db.adminCommand実行<br>遅いクエリ特定]
    
    TopQuery --> QueryAnalysis[クエリ分析]
    SlowQuery --> QueryAnalysis
    
    QueryAnalysis --> IndexCheck{適切なインデックス<br>使用?}
    
    IndexCheck -->|No| Solution1[3.1 インデックス作成<br>または修正]
    IndexCheck -->|Yes| DataCheck{データ量?}
    
    DataCheck -->|大量| Solution2[3.2 クエリ最適化<br>ページネーション導入]
    DataCheck -->|適切| ComplexCheck{クエリ複雑性?}
    
    ComplexCheck -->|高い| Solution3[3.3 クエリ単純化<br>アプリ側で処理分担]
    ComplexCheck -->|適切| ConcurrencyCheck{同時実行数?}
    
    ConcurrencyCheck -->|多い| Solution4[3.4 同時実行制限<br>キューイング導入]
    ConcurrencyCheck -->|適切| Solution5[3.5 その他の最適化<br>プロジェクション活用]
```

### 4. I/O問題

```mermaid
flowchart TD
    IOStart([I/O問題検出]) --> MetricCheck{どのメトリクスで<br>問題検出?}
    
    MetricCheck -->|ReadLatency/WriteLatency高| LatencyCheck{値?}
    MetricCheck -->|DiskQueueDepth高| Solution1[4.1 I/O最適化ストレージ<br>への変更検討]
    MetricCheck -->|IOPS上限近い| Solution2[4.2 ストレージタイプ変更<br>またはIOPS引き上げ]
    
    LatencyCheck -->|\>20ms| VolumeCheck{4.3 I/O-Optimizedの検討}
    LatencyCheck -->|急激な変動| BurstCheck{バーストバランス?}
    
    BurstCheck -->|低下中| Solution5[4.4 一時的なI/O抑制<br>または容量増強]
    BurstCheck -->|安定| OtherIOCheck[他のI/O要因調査]
    
    OtherIOCheck --> TTLCheck{TTLインデックス<br>使用?}
    
    TTLCheck -->|Yes| Solution6[4.5 TTL設定見直し<br>削除タイミング分散]
    TTLCheck -->|No| Solution7[4.6 I/Oパターン分析<br>アクセス最適化]
```

### 5. インデックス問題

```mermaid
flowchart TD
    IndexStart([インデックス問題検出]) --> IndexStatsCheck[db.collection.aggregate<br>$indexStats実行]
    
    IndexStatsCheck --> UsageCheck{使用状況?}
    
    UsageCheck -->|未使用インデックス多数| Solution1[5.1 未使用インデックス削除]
    UsageCheck -->|インデックス不足| Solution2[5.2 必要なインデックス追加]
    UsageCheck -->|インデックス使用効率低い| CompoundCheck{複合インデックス<br>最適?}
    
    CompoundCheck -->|No| Solution3[5.3 複合インデックス<br>フィールド順序最適化]
    CompoundCheck -->|Yes| SelectivityCheck{選択性?}
    
    SelectivityCheck -->|低い| Solution4[5.4 より選択性の高い<br>フィールドでインデックス作成]
    SelectivityCheck -->|適切| SizeCheck{サイズ?}
    
    SizeCheck -->|大きい| Solution5[5.5 部分インデックス検討<br>またはインデックス圧縮]
    SizeCheck -->|適切| Solution6[5.6 その他のインデックス<br>最適化戦略検討]
```

## 定常的な負荷対策フローチャート

```mermaid
flowchart TD
    Start([定常的な負荷対策]) --> CheckType{クラスタータイプ?}
    
    CheckType -->|Instance-based Cluster| BufferCheck[BufferCacheHitRatio確認]
    CheckType -->|Elastic Cluster| ShardCheck[シャード分散確認]
    
    BufferCheck --> BufferResult{BufferCacheHitRatio?}
    BufferResult -->|<90%| MemoryIssue[1.リソース問題<br>メモリ]
    BufferResult -->|≥90%| CPUCheck[CPU使用率確認]
    
    CPUCheck --> CPUResult{CPU使用率?}
    CPUResult -->|定常的に>70%| CPUIssue[1.リソース問題<br>CPU]
    CPUResult -->|<70%| IOCheck[I/O状況確認]
    
    IOCheck --> IOResult{I/O状況?}
    IOResult -->|レイテンシ高い| IOIssue[4.I/O問題]
    IOResult -->|正常| IndexCheck[インデックス使用状況確認]
    
    ShardCheck --> ShardResult{シャード分散?}
    ShardResult -->|不均衡| ShardIssue[6.シャード分散問題]
    ShardResult -->|均衡| ShardResourceCheck[シャードリソース確認]
    
    ShardResourceCheck --> ShardResourceResult{リソース使用率?}
    ShardResourceResult -->|高い| ShardScaleIssue[7.シャードスケール問題]
    ShardResourceResult -->|正常| ShardIndexCheck[シャードインデックス確認]
    
    IndexCheck --> IndexResult{インデックス最適?}
    IndexResult -->|No| IndexIssue[5.インデックス問題]
    IndexResult -->|Yes| SchemaCheck[スキーマ設計確認]
    
    ShardIndexCheck --> ShardIndexResult{インデックス最適?}
    ShardIndexResult -->|No| IndexIssue
    ShardIndexResult -->|Yes| ShardKeyCheck[シャードキー設計確認]
    
    SchemaCheck --> CommonFlow[クエリパターン確認]
    ShardKeyCheck --> ShardKeyResult{シャードキー設計最適?}
    ShardKeyResult -->|No| ShardKeyIssue[8.シャードキー設計問題]
    ShardKeyResult -->|Yes| CommonFlow
    
    CommonFlow --> QueryResult{クエリ最適?}
    QueryResult -->|No| QueryIssue[3.クエリ問題]
    QueryResult -->|Yes| ConnectionCheck[接続管理確認]
    
    ConnectionCheck --> ConnectionResult{接続管理最適?}
    ConnectionResult -->|No| ConnectionIssue[2.接続問題]
    ConnectionResult -->|Yes| OptimizedState[最適化状態]

```


## スパイク対策ソリューション

### 1. リソース問題ソリューション

詳細は [スパイク対策 - リソース問題ソリューション](spike-01-resources.md) を参照してください。

1.1 **インスタンスタイプ変更（T系からR系へ）**
- T系インスタンスはCPUクレジットを消費するバースト可能なインスタンス
- 本番環境では安定したパフォーマンスを提供するR5やR6gなどのインスタンスタイプを使用
- 実装: インスタンスタイプの変更（ダウンタイムが発生する可能性あり）

1.2 **読み取り負荷分散（レプリカ追加）**
- 読み取りクエリをレプリカに分散させることでプライマリノードの負荷を軽減
- 実装: レプリカの追加とアプリケーションの読み取りルーティング設定

1.3 **書き込み最適化（バッチ処理見直し）**
- 書き込み処理をバッチ化して効率化
- 実装: 小さな書き込みをまとめる、書き込みタイミングを分散させる

1.4 **クエリ最適化（インデックス見直し）**
- クエリパターンに基づいて適切なインデックスを作成
- 実装: `explain()`を使用してクエリプランを分析し、必要なインデックスを作成

1.5 **バッチ処理最適化（時間帯分散）**
- バッチ処理を負荷の少ない時間帯に実行
- 実装: バッチ処理のスケジュール変更、処理の分割

1.6 **定期処理見直し**
- 定期的に実行される処理の最適化
- 実装: 処理頻度の見直し、処理内容の効率化

1.7 **アクセスパターン分析**
- 不規則なスパイクの原因となるアクセスパターンを特定
- 実装: アプリケーションログ分析、CloudWatchメトリクスの詳細分析

### 2. 接続問題ソリューション

詳細は [スパイク対策 - 接続問題ソリューション](spike-02-connections.md) を参照してください。

2.1 **接続数上限引き上げ（インスタンスサイズアップ）**
- インスタンスサイズを大きくして接続数上限を引き上げ
- 実装: インスタンスタイプの変更

2.2 **コネクションプール設定見直し**
- アプリケーション側のコネクションプール設定を最適化
- 実装: プール設定の調整（最小/最大接続数、アイドルタイムアウト）

2.3 **接続リーク調査（アプリケーション修正）**
- 接続がクローズされずに残る原因を特定
- 実装: アプリケーションコードの修正、接続管理の改善

2.4 **アクセス集中調査（負荷分散検討）**
- 突発的なアクセス集中の原因を特定
- 実装: 負荷分散、キャッシング導入

2.5 **認証情報確認**
- 認証エラーの原因を特定
- 実装: 認証情報の更新、権限設定の見直し

2.6 **ネットワーク調査（タイムアウト設定見直し）**
- ネットワーク関連の問題を特定
- 実装: タイムアウト設定の調整、ネットワーク構成の見直し

2.7 **セキュリティグループ確認**
- セキュリティグループの設定を確認
- 実装: 必要なポートの開放、ルールの見直し

### 3. クエリ問題ソリューション

詳細は [スパイク対策 - クエリ問題ソリューション](spike-03-queries.md) を参照してください。クエリの診断と最適化については、[ユーザー診断ガイド](spike-10-diagnostics.md#クエリ診断)も併せて参照してください。

3.1 **インデックス作成または修正**
- クエリパターンに基づいて適切なインデックスを作成
- 実装: 新規インデックス作成、既存インデックスの修正

3.2 **クエリ最適化（ページネーション導入）**
- 大量のデータを返すクエリにページネーションを導入
- 実装: limit/skipの使用、カーソルベースのページネーション

3.3 **クエリ単純化（アプリ側で処理分担）**
- 複雑なクエリをシンプルにし、一部の処理をアプリケーション側で実行
- 実装: クエリの分割、アプリケーションでの後処理

3.4 **同時実行制限（キューイング導入）**
- 同時実行クエリ数を制限
- 実装: アプリケーション側でのキューイング、実行制御

3.5 **その他の最適化（プロジェクション活用）**
- 必要なフィールドのみを取得するようにプロジェクションを設定
- 実装: クエリのプロジェクション設定最適化

### 4. I/O問題ソリューション

詳細は [スパイク対策 - I/O問題ソリューション](spike-04-io.md) を参照してください。

4.1 **I/O最適化ストレージへの変更検討**
- I/O負荷が高い場合、I/O最適化ストレージへの変更を検討
- 実装: ストレージタイプの変更

4.2 **ストレージタイプ変更またはIOPS引き上げ**
- IOPS上限に近づいている場合、ストレージタイプの変更またはIOPSの引き上げを検討
- 実装: ストレージ設定の変更

4.3 **I/O-Optimizedへの変更**
- StandardからI/O-Optimizedへの変更でより予測可能なパフォーマンスを確保
- 実装: ストレージタイプの変更

4.4 **一時的なI/O抑制または容量増強**
- バーストバランスが低下している場合、一時的にI/O負荷を抑制または容量を増強
- 実装: 不要な処理の一時停止、ストレージ容量の増強

4.5 **TTL設定見直し（削除タイミング分散）**
- TTLインデックスによる削除タイミングを分散
- 実装: TTL値の調整、削除処理の分散

4.6 **I/Oパターン分析（アクセス最適化）**
- I/Oパターンを分析し、アクセスを最適化
- 実装: アクセスパターンの見直し、キャッシング導入

### 5. インデックス問題ソリューション

インデックスの使用状況分析と診断については、[ユーザー診断ガイド](spike-10-diagnostics.md#インデックス使用状況の分析)を参照してください。

5.1 **未使用インデックス削除**
- 使用されていないインデックスを特定して削除
- 実装: `db.collection.aggregate([{$indexStats:{}}])`で使用状況を確認し、不要なインデックスを削除

5.2 **必要なインデックス追加**
- クエリパターンに基づいて必要なインデックスを追加
- 実装: 新規インデックスの作成

5.3 **複合インデックスフィールド順序最適化**
- 複合インデックスのフィールド順序を最適化
- 実装: インデックスの再作成（フィールド順序を変更）

5.4 **より選択性の高いフィールドでインデックス作成**
- 選択性の高いフィールド（重複値が1%未満）を優先してインデックス作成
- 実装: インデックス設計の見直し

5.5 **部分インデックス検討またはインデックス圧縮**
- 部分インデックスの使用を検討
- 実装: 条件付きインデックスの作成

5.6 **その他のインデックス最適化戦略検討**
- インデックスの種類や設定を見直し
- 実装: インデックス戦略の総合的な見直し

## 定常的な負荷対策ソリューション

### 6. シャード分散問題ソリューション

詳細は [定常的な負荷対策 - シャード分散問題ソリューション](steady-06-sharding.md) を参照してください。

6.1 **シャード間データ分散の最適化**
- データ分散の均一性を改善
- 実装: シャード間のデータ再分散

6.2 **チャンクサイズの最適化**
- チャンクサイズを調整してデータ分散を改善
- 実装: チャンクサイズの設定変更

6.3 **バランサー設定の調整**
- シャード間のデータ移動を最適化
- 実装: バランサー設定の調整

### 7. シャードスケール問題ソリューション

詳細は [定常的な負荷対策 - シャードスケール問題ソリューション](steady-07-scaling.md) を参照してください。

7.1 **シャード数の増加**
- 負荷を分散するためにシャードを追加
- 実装: シャードの追加、データ再分散

7.2 **シャードリソースの増強**
- 個々のシャードのリソースを増強
- 実装: インスタンスタイプの変更

7.3 **シャード間の負荷分散最適化**
- シャード間の負荷を均等化
- 実装: ルーティング設定の調整

### 8. シャードキー設計問題ソリューション

詳細は [定常的な負荷対策 - シャードキー設計問題ソリューション](steady-08-shardkey.md) を参照してください。

8.1 **シャードキー選択の最適化**
- より均一な分散を実現するシャードキーの選択
- 実装: シャードキーの再設計

8.2 **複合シャードキーの検討**
- 複数フィールドを組み合わせたシャードキーの使用
- 実装: 複合シャードキーの設計と実装

8.3 **ハッシュベースシャードキーの検討**
- ハッシュベースのシャードキーによる均一分散
- 実装: ハッシュシャードキーの実装

### 9. スキーマ設計問題ソリューション

詳細は [定常的な負荷対策 - スキーマ設計問題ソリューション](steady-09-schema.md) を参照してください。

9.1 **データモデルの最適化**
- スキーマ設計を見直し、最適化
- 実装: データモデルの再設計

9.2 **正規化レベルの調整**
- 適切な正規化レベルを選択
- 実装: スキーマの再構築

9.3 **埋め込みドキュメントの最適化**
- 埋め込みドキュメント構造を見直し、最適化
- 実装: ドキュメント構造の再設計
