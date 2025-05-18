# Performance Insights を使用したモニタリング

## 参考URL
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-concepts.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-dashboard-overview.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-analyzing-db-load.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-top-queries.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-zoom-db-load.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-metrics.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-cloudwatch.html
- https://docs.aws.amazon.com/ja_jp/documentdb/latest/developerguide/performance-insights-counter-metrics.html

Performance Insights は、既存の Amazon DocumentDB モニタリング機能を拡張して、クラスターのパフォーマンスを明確にし、これに影響を与えるあらゆる問題を分析しやすくします。Performance Insights ダッシュボードを使用してデータベースロードを視覚化したり、ロードを待機、クエリステートメント、ホスト、アプリケーションでフィルタリングしたりできます。

**重要な特徴として、Performance Insights はメトリクスを Amazon CloudWatch に自動的に発行します。これにより、データベースのパフォーマンス指標に基づいた CloudWatch アラームを簡単に設定できます。例えば、データベースロード（DB Load）や CPU 使用率が特定のしきい値を超えた場合に通知を受け取るようなアラームを設定することが可能です。また、既存の CloudWatch ダッシュボードに Performance Insights のメトリクスを統合することで、包括的なモニタリング環境を構築できます。**

Performance Insights の有効化は、インスタンスの再起動、ダウンタイム、フェイルオーバーを必要としない非破壊的な操作です。Performance Insights エージェントは、DB ホストの限られた CPU とメモリリソースのみを使用し、DB のロードが高い場合には自動的にデータ収集の頻度を下げることで、パフォーマンスへの影響を最小限に抑えます。これにより、本番環境でも安全に有効化して使用することができます。

Performance Insights は以下の方法で有効化できます：

1. クラスター作成時の有効化
   - AWS Management Console で新しい Amazon DocumentDB クラスターを作成する際に、[パフォーマンスインサイト] セクションで [パフォーマンスインサイトを有効化する] を選択します。
   - データ保持期間は 7 日間で固定されています。
   - AWS KMS キーを指定して、機密データの暗号化を設定できます。

2. 既存のインスタンスでの有効化/無効化
   - AWS Management Console または aws docdb modify-db-instance コマンドを使用して設定を変更できます。
   - 変更はすぐに適用され、インスタンスの再起動は不要です。
   - AWS CLI を使用する場合は、--enable-performance-insights（有効化）または --no-enable-performance-insights（無効化）オプションを指定します。

###### 注記

Performance Insights は Amazon DocumentDB 3.6、4.0、5.0 インスタンスベースのクラスターでのみ使用できます。

**これはどのように役立ちますか?**

* データベースのパフォーマンスを視覚化: ロードを視覚化して、データベースのロードがいつどこにあるかを判断します
* データベースのロードの原因を特定: インスタンスのロードの原因となっているクエリ、ホスト、アプリケーションを特定します
* データベースにロードがかかるタイミングを特定: Performance Insights ダッシュボードを拡大して特定のイベントに注目したり、縮小して長期間にわたる傾向を確認したりできます
* データベースロードに関するアラート: CloudWatch から新しいデータベースロードメトリクスに自動的にアクセスし、DB ロードメトリクスを他の Amazon DocumentDB メトリクスと一緒にモニタリングし、アラートを設定できます

**Amazon DocumentDB Performance Insights にはどのような制限がありますか?**

* AWS GovCloud (米国東部) および AWS GovCloud (米国西部) リージョンの Performance Insights は利用できません
* Amazon DocumentDB の パフォーマンスインサイトが保持するパフォーマンスデータは 7 日間までとなります
* 1,024 バイトを超えるクエリは Performance Insights に集約されません

# Performance Insights の概念

## 平均アクティブセッション

データベース内のデータベースロード (DB ロード)アクティビティのレベルを測定します。毎秒収集されるPerformance Insights のキーメトリクスは `DB Load` です。`DBLoad` メトリクスの単位は、Amazon DocumentDB インスタンスの_平均アクティブセッション数 (AAS)_です。

_アクティブな_セッションとは、Amazon DocumentDB インスタンスにワークロードを送信し、レスポンスを待っている状態の接続です。例えば、Amazon DocumentDB インスタンスにクエリを送信すると、インスタンスでのクエリの処理中は、そのデータベースセッションは「アクティブな」状態となります。

平均アクティブセッションを取得するために、Performance Insights は、クエリを同時に実行するセッションの数をサンプリングします。AAS は、セッションの総数をサンプルの総数で割った値です。次の表は、実行中のクエリの連続する 5 つのサンプルを示しています。

| 例 | クエリを実行しているセッション数 | AAS | 計算              |
| - | ---------------- | --- | --------------- |
| 1 | 2                | 2   | 2 セッション/1 サンプル  |
| 2 | 0                | 1   | 2 セッション/2 サンプル  |
| 3 | 4                | 2   | 6 セッション/3 サンプル  |
| 4 | 0                | 1.5 | 6 セッション/4 サンプル  |
| 5 | 4                | 2   | 10 セッション/5 サンプル |

前の例では、1～5 の時間間隔の DB ロードは 2 AAS です。DB ロードの増加は、データベースで実行されているセッションが平均して増えることを意味します。

## ディメンション

この `DB Load` メトリクスは、ディメンションと呼ばれるサブコンポーネントに分割できるため、他の時系列メトリクスとは異なります。ディメンションは、`DB Load` メトリクスのさまざまな特性のカテゴリと考えることができます。パフォーマンスの問題を診断する場合、最も有用なディメンションは**待機状態**と**上位のクエリ**です。

######  待機状態 

待機状態を指定すると、クエリステートメントは、特定のイベントが発生するまで待機してから、実行を継続できます。例えば、クエリステートメントは、ロック済みのリソースのロックが解除されるまで待機することがあります。`DB Load` と待機イベントを組み合わせると、セッションの状態の全体像を得ることができます。Amazon DocumentDB には次のようなさまざまな待機状態があります。

| Amazon DocumentDB の待機状態 | 待機状態の説明                                                                                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ラッチ                     | ラッチ待機状態は、セッションがバッファープールのページングを待っているときに発生します。システムによる大規模なクエリの処理やコレクションのスキャンが頻繁に行われる場合や、バッファープールが小さすぎてワーキングセットを処理できない場合に、バッファープールのページインとページアウトが頻繁に起こる可能性があります。                                                                                         |
| CPU                     | CPU 待機状態は、セッションが CPU 上で待機しているときに発生します。                                                                                                                                                                                                              |
| CollectionLock          | CollectionLock 待機状態は、セッションがコレクションのロック取得を待機中の場合に発生します。これらのイベントは、コレクションに対して DDL 操作が行われたときに発生します。                                                                                                                                                      |
| DocumentLock            | DocumentLock 待機状態は、セッションがドキュメントのロック取得を待機中の場合に発生します。同じドキュメントへの同時書き込みの数が多いと、そのドキュメントの DocumentLock 待機状態が増えます。                                                                                                                                         |
| SystemLock              | SystemLock 待機状態は、セッションがシステムで待機しているときに発生します。これは、実行時間の長いクエリ、実行時間の長いトランザクション、またはシステムの高い同時実行性が頻繁に場合に発生する可能性があります。                                                                                                                                       |
| IO                      | IO 待機状態は、セッションが IO の完了を待っているときに発生します。                                                                                                                                                                                                               |
| BufferLock              | BufferLock 待機状態は、セッションがバッファーの共有ページのロック取得を待機中の場合に発生します。BufferLock 待機状態は、他のプロセスが要求されたページのオープンカーソルを保持していると、長くなる可能性があります。                                                                                                                               |
| LowMemThrottle          | LowMemThrottle 待機状態は、Amazon DocumentDB インスタンスに大量のメモリロードがかかってセッションが待機しているときに発生します。この状態が長時間続く場合は、インスタンスをスケールアップしてメモリを追加することを検討してください。詳細については、「[リソースガバナー](https://docs.aws.amazon.com/documentdb/latest/developerguide/how-it-works.html)」を参照してください。   |
| BackgroundActivity      | BackgroundActivity 待機状態は、セッションが内部システムプロセスを待機しているときに発生します。                                                                                                                                                                                           |
| その他                     | その他の待機状態は内部待機状態です。この状態が長時間続く場合は、このクエリを終了することを検討してください。詳細については、「[長時間実行されているクエリやブロックされているクエリを見つけて終了する方法](https://docs.aws.amazon.com/documentdb/latest/developerguide/user%5Fdiagnostics.html#user%5Fdiagnostics-query%5Fterminating.html)」を参照してください。 |

###### 上位のクエリ

待機状態はボトルネックを示しますが、上位のクエリは、どのクエリが DB ロードの最も大きな原因になっているかを示します。例えば、多くのクエリが現在データベースで実行されている可能性がありますが、1 つのクエリが DB ロードの 99% を占めている可能性もあります。この場合、ロードが高いと、クエリに問題がある可能性があります。

## 最大 vCPU

ダッシュボードの \[**データベースロード**\] グラフで、セッション情報が収集、集計、表示されます。アクティブなセッションが最大 CPU 容量を超えているかどうかを確認するには、**最大 vCPU** ラインとの関係を調べます。**最大 vCPU** 値は、お使いの Amazon DocumentDB インスタンスの vCPU (仮想 CPU) のコア数によって決まります。

DB ロードが \[**Max vCPU (最大 vCPU)**\] ラインをしばしば超過し、プライマリ待機状態が CPU である場合、CPU が過ロードになっています。この場合、インスタンスへの接続を抑制したり、CPU ロードの高いクエリを調整したり、より大きなインスタンスクラスを検討する必要があります。待機状態の高い一貫したインスタンスは、解決するボトルネックまたはリソースの競合問題がある可能性があることを示します。これは、DB ロードが**最大 vCPU** ラインを超えていない場合にも該当します。

# 待機状態によるデータベースロードの分析

**データベースロード (DB ロード)** のグラフにボトルネックが表示される場合、ロードの発生源を確認できます。これを実行するには、**データベースロード**グラフ下にある\[上位ロード項目\] テーブルを参照してください。クエリやアプリケーションのような特定の項目を選択すると、その項目をドリルダウンして詳細を表示できます。

待機および上位クエリによってグループ分けされた DB ロードは、通常、パフォーマンス問題に関する最も正しい情報を提供します。待機でグループ化された DB ロードは、データベースにリソースまたは同時のボトルネックがあるかどうかを示します。この場合、上位ロード項目のテーブルの **\[上位のクエリ\]** タブには、どのクエリがそのロードをかけているかが表示されます。

パフォーマンスの問題を診断するための一般的なワークフローは次のとおりです。

1. 「**データベースロード**」 グラフを確認し、**最大 CPU** ラインを超えているデータベースロードのインシデントがあるかどうかを確認します。
2. ある場合は、「**データベースロード**」 グラフを確認して、どの待機状態 (複数) が主に原因であるかを特定します。
3. 上位のロード項目テーブルの **\[上位のクエリ\]** タブが待機状態に最も影響しているクエリを確認することによって、ロードを引き起こすダイジェストクエリを特定します。これらは **\[待機別ロード (AAS)\]** 列で識別できます。
4. **\[上位のクエリ\]** タブでこれらのダイジェストクエリの 1 つを選択して展開し、構成されている子クエリを確認します。

また、**\[上位のホスト\]** または **\[上位のアプリケーション\]** をそれぞれ選択することで、どのホストまたはアプリケーションが最もロードを発生させているかを確認することもできます。アプリケーション名は Amazon DocumentDB インスタンスへの接続文字列で指定されます。`Unknown` は、アプリケーションフィールドが指定されなかったことを示します。

# カウンターメトリクス用の Performance Insights

Performance Insights ダッシュボードには、データベースのパフォーマンスに関する追加情報を提供するカウンターメトリクスが含まれています。

## カウンターメトリクス

カウンターメトリクスは、Performance Insights ダッシュボードの **カウンターメトリクス** チャートに表示されるオペレーティングシステムおよびデータベースのパフォーマンスメトリクスです。

| カウンター | 型 | 単位 | 説明 |
|------------|------|------|------------|
| active_transactions | データベース | 件数 | 現在アクティブなトランザクションの数 |
| buffer_cache_hit_ratio | データベース | パーセント | バッファキャッシュから処理されたリクエストの割合 |
| cpu_usage_user | OS | パーセント | CPU 使用率（ユーザー） |
| cpu_usage_system | OS | パーセント | CPU 使用率（システム） |
| cpu_usage_idle | OS | パーセント | CPU 使用率（アイドル） |
| cpu_usage_iowait | OS | パーセント | CPU 使用率（I/O 待ち） |
| cpu_usage_nice | OS | パーセント | CPU 使用率（nice） |
| cpu_usage_irq | OS | パーセント | CPU 使用率（IRQ） |
| cpu_usage_softirq | OS | パーセント | CPU 使用率（ソフト IRQ） |
| db_connections | データベース | 件数 | データベース接続数 |
| memory_total | OS | バイト | 合計メモリ |
| memory_free | OS | バイト | 空きメモリ |
| memory_cached | OS | バイト | キャッシュメモリ |
| memory_swap_total | OS | バイト | 合計スワップメモリ |
| memory_swap_free | OS | バイト | 空きスワップメモリ |
| network_bytes_in | OS | バイト/秒 | ネットワーク受信バイト数 |
| network_bytes_out | OS | バイト/秒 | ネットワーク送信バイト数 |
| network_num_connections | OS | 件数 | ネットワーク接続数 |
| v_cpu_used | OS | 件数 | 使用中の vCPU 数 |
| v_cpu_total | OS | 件数 | 合計 vCPU 数 |
| volume_bytes_used | OS | バイト | 使用中のボリュームバイト数 |
| volume_bytes_total | OS | バイト | 合計ボリュームバイト数 |
| volume_iops_read | OS | 件数/秒 | ボリューム読み取り IOPS |
| volume_iops_write | OS | 件数/秒 | ボリューム書き込み IOPS |
| volume_throughput_read | OS | バイト/秒 | ボリューム読み取りスループット |
| volume_throughput_write | OS | バイト/秒 | ボリューム書き込みスループット |
| volume_queue_length | OS | 件数 | ボリューム待ち行列長 |

これらのカウンターメトリクスを使用することで、データベースのパフォーマンスをより詳細に分析し、潜在的な問題を特定することができます。

# Performance Insights API によるメトリクスの取得

Performance Insights が有効になっている場合、API はインスタンスのパフォーマンスを可視化します。Amazon CloudWatch Logs は、 AWS サービスの供給モニタリングメトリクスの信頼できるソースを提供します。

Performance Insightsは、平均アクティブ・セッション(AAS)として測定されるデータベースロードのドメイン固有のビューを提供します。このメトリクスはAPI利用者には2次元時系列データセットのように見えます。データの時間ディメンションは、クエリされた時間範囲内の各時点のDBロード・データを提供します。各時点で、その時点で計測された `Query`、`Wait-state`、`Application`、`Host` などのリクエストされたディメンションに関するロード全体が分解されます。

Amazon DocumentDB Performance Insights では、Amazon DocumentDB DB インスタンスをモニタリングし、データベースパフォーマンスの分析とトラブルシューティングを行うことができます。Performance Insights は、 AWS Management Consoleで表示することができます。また、Performance Insights では独自のデータをクエリできるように、パブリック API も提供されています。API を使用して、次を実行できます。

* データベースにデータをオフロードする
* Performance Insights データを既存のモニタリングダッシュボードに追加する
* モニタリングツールを構築する

Performance Insights API を使用するには、いずれかの Amazon DocumentDB インスタンスで Performance Insights を有効にします。Performance Insights の有効化については、「[Performance Insights の有効化と無効化](./performance-insights-enabling.html)」を参照してください。Performance Insights API の詳細については、「[ Performance Insights API リファレンス](https://docs.aws.amazon.com/performance-insights/latest/APIReference/Welcome.html)」を参照してください。

Performance Insights API は、以下のオペレーションを提供します。

| Performance Insights でのアクション                                                                                                                       | AWS CLI コマンド                                                                                                                             | 説明                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [DescribeDimensionKeys](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FDescribeDimensionKeys.html)                     | [aws pi describe-dimension-keys](https://docs.aws.amazon.com/cli/latest/reference/pi/describe-dimension-keys.html)                       | 特定の期間に、メトリクスの上位 N 個のディメンションキーを取得します。                                                                                                                                                                                                                        |
| [GetDimensionKeyDetails](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FGetDimensionKeyDetails.html)                   | [aws pi get-dimension-key-details](https://docs.aws.amazon.com/cli/latest/reference/pi/get-dimension-key-details.html)                   | DB インスタンスまたはデータソースの指定されたディメンショングループの属性を取得します。例えば、クエリ ID を指定し、ディメンションの詳細が使用可能な場合、GetDimensionKeyDetails は、この ID に関連付けられているディメンション db.query.statement の全文を取得します。このオペレーションは、GetResourceMetrics および DescribeDimensionKeys が大きなクエリステートメントテキストの取得をサポートしないため、便利です。 |
| [GetResourceMetadata](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FGetResourceMetadata.html)                         | [aws pi get-resource-metadata](https://docs.aws.amazon.com/cli/latest/reference/pi/get-resource-metadata.html)                           | さまざまな機能に関するメタデータを取得します。例えば、メタデータにより、特定の DB インスタンスで何等かの機能が有効化されているか無効化されているかを、示すことができます。                                                                                                                                                                     |
| [GetResourceMetrics](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FGetResourceMetrics.html)                           | [aws pi get-resource-metrics](https://docs.aws.amazon.com/cli/latest/reference/pi/get-resource-metrics.html)                             | 期間中、データソースのセットに Performance Insights のメトリクスを取得します。特定のディメンショングループおよびディメンションを提供し、各グループの集約とフィルタリング条件を提供することができます。                                                                                                                                              |
| [ListAvailableResourceDimensions](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FListAvailableResourceDimensions.html) | [aws pi list-available-resource-dimensions](https://docs.aws.amazon.com/cli/latest/reference/pi/list-available-resource-dimensions.html) | 指定したインスタンスで、指定したメトリクスタイプごとにクエリできるディメンションを取得します。                                                                                                                                                                                                             |
| [ListAvailableResourceMetrics](https://docs.aws.amazon.com/performance-insights/latest/APIReference/API%5FListAvailableResourceMetrics.html)       | [aws pi list-available-resource-metrics](https://docs.aws.amazon.com/cli/latest/reference/pi/list-available-resource-metrics.html)       | DB インスタンスを指定しながら、指定されたメトリクスタイプでクエリが可能なメトリクスをすべて取得します。                                                                                                                                                                                                       |

## AWS CLI Performance Insights の

Performance Insights は、 AWS CLIを使用して表示することができます。Performance Insights の AWS CLI コマンドのヘルプを表示するには、コマンドラインで次のように入力します。

`aws pi help`

 AWS CLI がインストールされていない場合は、[「 ユーザーガイド」の AWS 「 コマンドラインインターフェイス](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)のインストール」を参照してください。 _AWS CLI_ 

## 時系列メトリクスの取得

`GetResourceMetrics` オペレーションでは、1 つ以上の時系列メトリクスを Performance Insights データから取得します。`GetResourceMetrics` には、メトリクスおよび期間が必要であり、データポイントのリストを含むレスポンスが返ります。

例えば、次の図に示すように、 AWS Management Console は `GetResourceMetrics`を使用して**カウンターメトリクス**チャートと**データベースロード**チャートにデータを入力します。

`GetResourceMetrics` によって返るメトリクスはすべて、`db.load` の例外を除き、スタンダードの時系列メトリクスです。このメトリクスは、\[**データベースロード**\] グラフに表示されます。この `db.load` メトリクスは、_ディメンション_と呼ばれるサブコンポーネントに分割できるため、他の時系列メトリクスとは異なります。前のイメージでは、`db.load` は分割され、`db.load` を構成する待機状態によってグループ化されています。

###### 注記

`GetResourceMetrics` は、`db.sampleload` メトリクスを返すこともできますが、通常 `db.load` メトリクスが適切です。

`GetResourceMetrics` により返されるカウンターメトリクスに関する情報は、「[カウンターメトリクス用の Performance Insights](./performance-insights-counter-metrics.html)」を参照してください。

以下の計算は、メトリクスにサポートされています。

* 平均 - 期間中のメトリクスの平均値。`.avg` をメトリクス名に追加します。
* 最小 - 期間中のメトリクスの最小値。`.min` をメトリクス名に追加します。
* 最大 - 期間中のメトリクスの最大値。`.max` をメトリクス名に追加します。
* 合計 - 期間中のメトリクス値の合計。`.sum` をメトリクス名に追加します。
* サンプル数 - 期間中にメトリクスが収集された回数。`.sample_count` をメトリクス名に追加します。

例えば、メトリクスが 300 秒 (5 分) 収集され、メトリクスが 1 分に 1 回収集されたものと見なします。毎分の値は、1、2、3、4、5 です。この場合、以下の計算が返されます。

* 平均 - 3
* 最小 - 1
* 最大 - 5
* 合計 - 15
* サンプル数 - 5

`get-resource-metrics` AWS CLI コマンドの使用の詳細については、「」を参照してください[get-resource-metrics](https://docs.aws.amazon.com/cli/latest/reference/pi/get-resource-metrics.html)。

`--metric-queries` オプションでは、結果を取得する 1 つ以上のクエリを指定します。各クエリは、必須の `Metric` と、オプションの `GroupBy` および `Filter` パラメータから構成されます。`--metric-queries` オプションの指定の例を次に示します。

`{
   "Metric": "string",
   "GroupBy": {
     "Group": "string",
     "Dimensions": ["string", ...],
     "Limit": integer
   },
   "Filter": {"string": "string"
     ...}`

## AWS CLI Performance Insights の例

次の例は、Performance Insights AWS CLI に を使用する方法を示しています。

### カウンターメトリクスの取得

以下の例では、2 つのカウンターメトリクスグラフを生成するために AWS Management Console で使用するデータと同じデータを生成する方法を示します。

Linux、macOS、Unix の場合:

`` aws pi get-resource-metrics \
   --service-type DOCDB \
   --identifier db-`ID` \
   --start-time `2022-03-13T8:00:00Z` \
   --end-time   `2022-03-13T9:00:00Z` \
   --period-in-seconds `60` \
   --metric-queries '[{"Metric": "os.cpuUtilization.user.avg"  },
                      {"Metric": "os.cpuUtilization.idle.avg"}]' ``

Windows の場合:

`` aws pi get-resource-metrics ^
   --service-type DOCDB ^
   --identifier db-`ID` ^
   --start-time `2022-03-13T8:00:00Z` ^
   --end-time   `2022-03-13T9:00:00Z` ^
   --period-in-seconds `60` ^
   --metric-queries '[{"Metric": "os.cpuUtilization.user.avg"  },
                      {"Metric": "os.cpuUtilization.idle.avg"}]' ``

また、コマンドを作成しやすくするために、`--metrics-query` オプションにファイルを指定します。以下の例では、このオプション用に query.json と呼ばれるファイルを使用します。ファイルの内容は次のとおりです。

`[
    {
        "Metric": "os.cpuUtilization.user.avg"
    },
    {
        "Metric": "os.cpuUtilization.idle.avg"
    }
]`

ファイルを使用するには、次のコマンドを実行します。

Linux、macOS、Unix の場合:

`` aws pi get-resource-metrics \
   --service-type DOCDB \
   --identifier db-`ID` \
   --start-time `2022-03-13T8:00:00Z` \
   --end-time   `2022-03-13T9:00:00Z` \
   --period-in-seconds `60` \
   --metric-queries file://`query.json` ``

Windows の場合:

`` aws pi get-resource-metrics ^
   --service-type DOCDB ^
   --identifier db-`ID` ^
   --start-time `2022-03-13T8:00:00Z` ^
   --end-time   `2022-03-13T9:00:00Z` ^
   --period-in-seconds `60` ^
   --metric-queries file://`query.json` ``

前述の例では、各オプションに次の値を指定します。

* `--service-type`: Amazon DocumentDB の `DOCDB`
* `--identifier` \- DB インスタンスのリソース ID
* `--start-time` および `--end-time` \- クエリを実行する期間の ISO 8601 `DateTime` 値 (サポートされている複数の形式)

クエリは 1 時間の範囲で実行されます。

* `--period-in-seconds` \- `60` (1 分ごとのクエリ)
* `--metric-queries` \- 2 つのクエリの配列。それぞれ 1 つのメトリクスに対して使用されます。  
メトリクス名ではドットを使用してメトリクスを有用なカテゴリに分類します。最終の要素は関数になります。この例では、関数は、クエリの `avg` です。Amazon CloudWatch と同様に、サポートされている関数は、`min`、`max`、`total`、および `avg` です。

レスポンスは次の例のようになります。

`{
    "AlignedStartTime": "2022-03-13T08:00:00+00:00",
    "AlignedEndTime": "2022-03-13T09:00:00+00:00",
    "Identifier": "db-NQF3TTMFQ3GTOKIMJODMC3KQQ4",
    "MetricList": [
        {
            "Key": {
                "Metric": "os.cpuUtilization.user.avg"
            },
            "DataPoints": [
                {
                    "Timestamp": "2022-03-13T08:01:00+00:00", //Minute1
                    "Value": 3.6
                },
                {
                    "Timestamp": "2022-03-13T08:02:00+00:00", //Minute2
                    "Value": 2.6
                },
                //.... 60 datapoints for the os.cpuUtilization.user.avg metric
        {
            "Key": {
                "Metric": "os.cpuUtilization.idle.avg"
            },
            "DataPoints": [
                {
                    "Timestamp": "2022-03-13T08:01:00+00:00",
                    "Value": 92.7
                },
                {
                    "Timestamp": "2022-03-13T08:02:00+00:00",
                    "Value": 93.7
                },
                //.... 60 datapoints for the os.cpuUtilization.user.avg metric 
            ]
        }
    ] //end of MetricList
} //end of response`

レスポンスには、`Identifier`、`AlignedStartTime`、`AlignedEndTime` があります。`--period-in-seconds` 値が `60` の場合、スタート時間および終了時間は、時間 (分) に調整されます。`--period-in-seconds` が `3600` の場合、スタート時間および終了時間は、時
