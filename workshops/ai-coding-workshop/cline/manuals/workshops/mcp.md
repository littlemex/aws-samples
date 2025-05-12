# MCP（Model Context Protocol）ワークショップ

このワークショップでは、[Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) を使用して AI エージェントの機能を拡張し、外部 API やサービスと連携する方法を学びます。

## ドキュメント構成

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|セルフアカウント| C[manuals/selfenv.md]
    B -->|Workshop Studio| D[manuals/workshop-studio.md]
    
    C --> E{実行環境}
    D --> F{実行環境}
    
    E -->|"Amazon EC2 環境(推奨)"| G[manuals/selfenv-ec2.md]
    E -->|ローカル環境| H[manuals/selfenv-local.md]
    
    F -->|"Amazon EC2 環境(推奨)"| I[manuals/ws-ec2.md]
    F -->|ローカル環境| J[manuals/ws-local.md]
    
    G --> K[manuals/workshops/README.md]
    H --> K
    I --> K
    J --> K
    
    K -->|Cline| CL[manuals/workshops/cline.md]
    K -->|MCP| L[manuals/workshops/mcp.md]
    K -->|LiteLLM| M[manuals/workshops/litellm.md]
    K -->|Langfuse| N[manuals/workshops/langfuse.md]
    K -->|MLflow| O[manuals/workshops/mlflow.md]
    
    L --> P[1.mcp/README.md]
    M --> Q[2.litellm/README.md]
    N --> R[4.langfuse/README.md]
    O --> S[5.mlflow/README.md]

    click A href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/README.md"
    click C href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv.md"
    click D href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshop-studio.md"
    click G href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv-ec2.md"
    click H href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv-local.md"
    click I href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-ec2.md"
    click J href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-local.md"
    click K href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/README.md"
    click M href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/litellm.md"
    click N href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/langfuse.md"
    click CL href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/cline.md"
    click O href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mlflow.md"

    style L fill:#f96,stroke:#333,stroke-width:2px
```

## MCP の基本概念

MCP は、AI モデルとデータソースやツールを接続するための標準化されたオープンプロトコルです。USB-C のように、異なるシステム間の互換性を確保する役割を果たします。

### MCP の本質と基本コンポーネント

MCP は以下の主要コンポーネントで構成されています：

```mermaid
flowchart TD
    subgraph AIModel["AI モデル"]
        LLM[大規模言語モデル]
    end
    
    subgraph MCPServer["MCP サーバー"]
        Protocol[MCP プロトコル]
        
        subgraph Components["コンポーネント"]
            Tools[ツール]
            Resources[リソース]
        end
    end
    
    subgraph DataSources["データソース"]
        LocalData[ローカルデータ]
        RemoteData[リモートデータ]
        APIs[外部 API]
    end
    
    %% 接続
    AIModel <--> Protocol
    Protocol <--> Tools
    Protocol <--> Resources
    Resources --> LocalData
    Resources --> RemoteData
    Tools --> APIs
    
    %% スタイル設定
    style AIModel fill:#f9f0ff,stroke:#6600cc,stroke-width:2px
    style MCPServer fill:#e6ffe6,stroke:#006600,stroke-width:2px
    style Components fill:#e6f7ff,stroke:#0066cc,stroke-width:1px
    style DataSources fill:#fff0e6,stroke:#cc3300,stroke-width:1px
    style LLM fill:#d4bbff,stroke:#333333,stroke-width:1px
    style Protocol fill:#b3ffb3,stroke:#333333,stroke-width:1px
    style Tools fill:#b3e6ff,stroke:#333333,stroke-width:1px
    style Resources fill:#b3e6ff,stroke:#333333,stroke-width:1px
    style LocalData fill:#ffccb3,stroke:#333333,stroke-width:1px
    style RemoteData fill:#ffccb3,stroke:#333333,stroke-width:1px
    style APIs fill:#ffccb3,stroke:#333333,stroke-width:1px
```

1. **ツール（Tools）**
   MCP におけるツールは、サーバーが実行可能な機能をクライアントに公開するための強力な基本要素です。[ツールの詳細な仕様](https://modelcontextprotocol.io/docs/concepts/tools)は公式ドキュメントで確認できます。

   ツールは **モデル制御型** の設計となっており、AI モデルが（人間の承認を得た上で）自動的に呼び出すことを意図してサーバーからクライアントに公開されます。これにより、LLM は外部システムとの対話、計算の実行、実世界でのアクションの実行などが可能になります。

   各ツールは以下の要素で定義されます：
   - 名前：ツールを一意に識別する識別子
   - 説明：ツールの使用方法を説明する人間可読な説明
   - 入力スキーマ：ツールのパラメータを定義する JSON スキーマ
   - アノテーション：ツールの動作に関するヒント（オプション）

   ツールのアノテーションには以下のような情報が含まれます：
   - タイトル：UI 表示用の人間可読なタイトル
   - 読み取り専用ヒント：環境を変更しないツールかどうか
   - 破壊的ヒント：破壊的な更新を行う可能性があるかどうか
   - べき等性ヒント：同じ引数での繰り返し呼び出しが追加の効果を持たないかどうか
   - オープンワールドヒント：外部エンティティとの対話を行うかどうか

   クライアントは `tools/list` エンドポイントを通じて利用可能なツールを発見し、`tools/call` エンドポイントを使用してツールを呼び出します。ツールは、システム操作、API 統合、データ処理など、様々な用途に使用できます。

   ツールの実装においては、明確な名前と説明の提供、詳細な JSON スキーマ定義、適切なエラー処理、進捗報告、タイムアウト実装など、いくつかのベストプラクティスがあります。また、セキュリティ面では、入力の検証、アクセス制御、監査ログの記録など、適切な対策を講じることが重要です。

2. **リソース（Resources）**
   - AI モデルがアクセスできる静的または動的なデータソース
   - ドキュメント、API レスポンス、システム情報など
   - 静的または動的なデータを提供

#### MCP リソースの詳細

MCP におけるリソースは、サーバーがクライアントに公開し、LLM との対話のコンテキストとして使用できるデータや内容を表現する重要な基本要素です。[リソースの詳細な仕様](https://modelcontextprotocol.io/docs/concepts/resources)は公式ドキュメントで確認できます。

リソースは **アプリケーション制御型** の設計となっており、クライアントアプリケーションがいつどのようにリソースを使用するかを決定します。例えば、Claude Desktop ではユーザーが明示的にリソースを選択する必要がありますが、他のクライアントでは自動的にリソースを選択したり、AI モデル自体がどのリソースを使用するかを決定したりする場合もあります。

リソースは URI によって一意に識別され、以下のような形式に従います：

```
[プロトコル]://[ホスト]/[パス]
```

例えば、`file:///home/user/documents/report.pdf` や `postgres://database/customers/schema` などがあります。これらの URI スキームはサーバー実装によって定義されます。

リソースには主に 2 種類のコンテンツタイプがあります：

1. **テキストリソース**：UTF-8 でエンコードされたテキストデータを含み、ソースコード、設定ファイル、ログファイルなどに適しています。

2. **バイナリリソース**：Base64 でエンコードされた生のバイナリデータを含み、画像、PDF、音声ファイルなどの非テキスト形式に適しています。

クライアントは主に 2 つの方法でリソースを発見できます。1 つ目は「直接リソース」で、サーバーが `resources/list` エンドポイントを通じて具体的なリソースのリストを公開します。2 つ目は「リソーステンプレート」で、動的リソース用に URI テンプレートを公開し、クライアントが有効なリソース URI を構築できるようにします。

リソースの読み取りは、クライアントがリソース URI を含む `resources/read` リクエストを送信することで行われます。サーバーはリソースの内容を含むレスポンスを返します。また、MCP はリソースのリアルタイム更新もサポートしており、リソースリストの変更通知やコンテンツの変更通知を提供します。

3. **プロトコル定義**
   - クライアントとサーバー間の通信規約
   - 標準化されたリクエスト/レスポンス形式

4. **プロンプト（Prompts）**
   MCP におけるプロンプトは、再利用可能なプロンプトテンプレートとワークフローを定義する機能です。[プロンプトの詳細な仕様](https://modelcontextprotocol.io/docs/concepts/prompts)は公式ドキュメントで確認できます。

   プロンプトは **ユーザー制御型** の設計となっており、サーバーからクライアントに公開され、ユーザーが明示的に選択して使用することを意図しています。これにより、共通の LLM 対話を標準化し、共有する強力な方法を提供します。

   MCP のプロンプトは以下のような特徴を持っています：

   - 動的な引数を受け入れる
   - リソースからのコンテキストを含める
   - 複数の対話をチェーンする
   - 特定のワークフローをガイドする
   - UI 要素（スラッシュコマンドなど）として表面化する

   プロンプトの構造は、名前、説明、オプションの引数リストで定義されます。クライアントは `prompts/list` エンドポイントを通じて利用可能なプロンプトを発見し、`prompts/get` リクエストを使用してプロンプトを利用します。

   動的プロンプトでは、埋め込みリソースコンテキストや多段階ワークフローなど、より複雑な対話を実現できます。これにより、プロジェクトログやコードの分析、デバッグワークフローなど、高度な AI アシスタンス機能を実装することが可能になります。

   プロンプトの実装においては、明確で説明的なプロンプト名の使用、詳細な説明の提供、必須引数の検証、エラー処理の実装など、いくつかのベストプラクティスがあります。また、セキュリティ面では、引数の検証、ユーザー入力のサニタイズ、アクセス制御の実装など、適切な対策を講じることが重要です。

5. **トランスポート（Transports）**
   MCP におけるトランスポートは、クライアントとサーバー間の通信方法を定義する重要な要素です。[トランスポートの詳細な仕様](https://modelcontextprotocol.io/docs/concepts/transports)は公式ドキュメントで確認できます。

   トランスポートは、MCP の通信層を抽象化し、異なる環境や要件に応じて適切な通信方式を選択できるようにします。主要なトランスポートタイプには以下があります：

   - **Stdio（標準入出力）**: ローカル環境での通信に適しており、シンプルで効率的です。
   - **HTTP/SSE（Server-Sent Events）**: リモート環境での通信に適しており、ウェブベースのアプリケーションとの統合が容易です。

   トランスポートの選択は、以下の要因を考慮して行います：
   - 通信の環境（ローカルかリモートか）
   - セキュリティ要件
   - スケーラビリティの必要性
   - 既存のインフラストラクチャとの互換性

   適切なトランスポートを選択することで、MCP の効率的な運用と、様々な環境での柔軟な展開が可能になります。

### MCP の一般的なアーキテクチャ

MCP は基本的にクライアント-サーバーアーキテクチャに従っており、ホストアプリケーションが複数のサーバーに接続できる構造になっています：

```mermaid
flowchart TD
    subgraph Internet["インターネット"]
        WebAPIs[Web APIs]
        RemoteC[リモートサービスC]
    end
    
    subgraph Computer["ローカル PC"]
        subgraph Host["MCP クライアント"]
            Client
        end
        
        subgraph Servers["MCP サーバー"]
            ServerA[MCP サーバーA]
            ServerB[MCP サーバーB]
            ServerC[MCP サーバーC]
        end
        
        subgraph LocalData["ローカルデータソース"]
            DataA[ローカルデータソースA]
            DataB[ローカルデータソースB]
        end
        
        subgraph Transports["トランスポート"]
            Stdio[Stdio]
            HTTPSSE[HTTP/SSE]
        end
    end
    
    %% MCP プロトコル接続
    Client -- "MCP プロトコル" --> Transports
    Transports --> ServerA
    Transports --> ServerB
    Transports --> ServerC
    
    %% データソース接続
    ServerA --> DataA
    ServerB --> DataB
    ServerC --> RemoteC
    RemoteC --> WebAPIs
    
    %% スタイル設定
    style Internet fill:#e6f7ff,stroke:#0066cc,stroke-width:2px
    style Computer fill:#f5f5f5,stroke:#333333,stroke-width:2px
    style Host fill:#f9f0ff,stroke:#6600cc,stroke-width:2px
    style Client fill:#d4bbff,stroke:#333333,stroke-width:1px
    style Servers fill:#e6ffe6,stroke:#006600,stroke-width:1px
    style LocalData fill:#fff0e6,stroke:#cc3300,stroke-width:1px
    style ServerA fill:#b3ffb3,stroke:#333333,stroke-width:1px
    style ServerB fill:#b3ffb3,stroke:#333333,stroke-width:1px
    style ServerC fill:#b3ffb3,stroke:#333333,stroke-width:1px
    style DataA fill:#ffccb3,stroke:#333333,stroke-width:1px
    style DataB fill:#ffccb3,stroke:#333333,stroke-width:1px
    style RemoteC fill:#b3e6ff,stroke:#333333,stroke-width:1px
    style WebAPIs fill:#b3e6ff,stroke:#333333,stroke-width:1px
    style Transports fill:#ffe6cc,stroke:#cc6600,stroke-width:1px
    style Stdio fill:#ffd9b3,stroke:#333333,stroke-width:1px
    style HTTPSSE fill:#ffd9b3,stroke:#333333,stroke-width:1px
```

- **MCP ホスト**: Claude Desktop、IDE、AIツールなど、MCPを通じてデータにアクセスしたいプログラム
- **MCP クライアント**: サーバーとの1:1接続を維持するプロトコルクライアント
- **MCP サーバー**: 標準化されたModel Context Protocolを通じて特定の機能を公開する軽量プログラム
- **ローカルデータソース**: MCPサーバーが安全にアクセスできるコンピュータのファイル、データベース、サービス
- **リモートサービス**: MCPサーバーが接続できるインターネット経由の外部システム（APIなど）

### MCPのアーキテクチャ詳細

MCPの詳細なアーキテクチャについては、[公式ドキュメント](https://modelcontextprotocol.io/docs/concepts/architecture)で詳しく解説されています。ここでは主要な概念を簡潔に説明します。

MCP は主にプロトコル層とトランスポート層という 2 つの層で構成されています。プロトコル層はメッセージの構造化と管理を担当し、リクエストとレスポンスの制御や通信パターンの標準化を行います。一方、トランスポート層は実際の通信を処理し、ローカル環境では標準入出力を使用した通信、リモート環境では HTTP と Server-Sent Events (SSE) を組み合わせた通信を提供します。すべての通信は JSON-RPC ベースのメッセージングプロトコルを使用して行われます。

MCP の通信システムは、明確に定義されたメッセージタイプに基づいています。リクエストは相手側からの応答を期待する問い合わせであり、レスポンスはそのリクエストに対する回答です。また、応答を必要としない一方向の通知も存在します。これらのメッセージ交換は、初期化、通常のメッセージ交換、終了という 3 つのフェーズからなる接続ライフサイクルの中で行われます。

初期化フェーズでは、クライアントとサーバーが互いの機能とプロトコルバージョンを確認します。通常のメッセージ交換フェーズでは、双方向の通信が行われ、最終的に正常または異常な形で接続が終了します。また、MCP には標準化されたエラーコードと一貫したエラー報告メカニズム、適切なエラー回復手順が組み込まれており、安定した通信を実現しています。

より詳細な実装情報や高度な機能については、[アーキテクチャドキュメント](https://modelcontextprotocol.io/docs/concepts/architecture)を参照してください。

### MCP がもたらす主なメリット

MCP は、LLM 上にエージェントや複雑なワークフローを構築するのに役立ちます：

1. **豊富な事前構築された統合**
   - LLM が直接プラグインできる、成長し続ける事前構築された統合のリスト
   - 様々なデータソースやツールとの迅速な接続が可能

2. **LLM プロバイダーとベンダー間の柔軟な切り替え**
   - 異なる LLM プロバイダーやベンダー間で簡単に切り替えることができる柔軟性
   - ベンダーロックインの回避と、最適な LLM の選択が可能

3. **インフラストラクチャ内でのデータセキュリティのベストプラクティス**
   - ユーザー自身のインフラ内でデータを安全に保持
   - センシティブな情報を外部に送信せずに処理可能

4. **相互運用性の向上**
   - 標準化されたインターフェースによる開発時間の短縮
   - 異なるシステム間での円滑な情報交換

## MCP サーバーの活用

### 1. MCP Marketplace の活用

[MCP Marketplace](https://cline.bot/mcp-marketplace) は、AI エージェントの機能を拡張するための豊富なツールとリソースを提供します。Marketplace を通じて、様々な MCP サーバーを簡単に導入し、AI エージェントの能力を大幅に拡張することができます。

#### MCP Marketplace へのアクセス

MCP Marketplace にアクセスするには、VS Code の Cline 拡張機能を開き、左側のサイドバーから「MCP Servers」を選択し、画面上部の「Marketplace」タブをクリックします。

![MCP Marketplace の画面](../images/mcp-marketplace.png)

Marketplace では、キーワード検索を通じて必要なツールを見つけ、Cline 自身の能力でインストール作業を進めることができます。また、インストール済みのサーバーの設定管理や、最新バージョンへの更新も簡単に行えます。

#### MCP サーバー例

##### 1. Markdownify MCP

Markdownify MCP は、様々な形式のコンテンツを AI エージェントが理解しやすいマークダウン形式に変換します。PDF や Office ドキュメント、ウェブページ、さらには YouTube 動画の字幕まで、幅広いコンテンツを扱うことができます。

**主な機能：**
- PDF ファイルの要約
- Web ページの情報分析

##### 2. Context7 MCP

Context7 MCP は、AI エージェントが最新のライブラリドキュメントにアクセスできるようにする強力なツールです。従来の LLM が抱える以下の問題を解決します：

❌ 古いトレーニングデータに基づく古いコード例
❌ 実在しない API の誤った生成
❌ 古いパッケージバージョンに基づく一般的な回答

Context7 を使用することで：
✅ ソースから直接、最新のバージョン固有のドキュメントとコード例を取得
✅ プロンプトに直接、最新の情報を組み込み
✅ 常に最新の API 仕様に基づいた正確な回答を得られます

**使用方法：**

質問に `use context7` を追加するだけで、最新のドキュメントが自動的に取得されます：

```
Next.js の `after` 関数の使い方を教えて use context7
React Query でクエリを無効化する方法は？ use context7
NextAuth でルートを保護する方法は？ use context7
```

詳しい情報は [Context7 のライブラリページ](https://context7.com/libraries) で確認できます。

#### MCP サーバーの管理

MCP サーバーを活用するためには、適切な管理が重要です。VS Code の Cline 拡張機能の「MCP Servers」セクションでは、インストール済みのサーバーを一覧表示し、各サーバーの設定変更や有効/無効の切り替えを簡単に行うことができます。

サーバーの設定は、「Settings」アイコンから変更できます。また、一時的に特定のサーバーを無効にしたい場合は、トグルスイッチを使用して簡単に切り替えることができます。

![MCP サーバーの管理方法](../images/mcp-marketplace-how-to-use.png)

#### セキュリティとプライバシーへの配慮

MCP サーバーの利用にあたっては、セキュリティとプライバシーへの適切な配慮が不可欠です：

1. **信頼性の確認**
   - 信頼できる開発者やコミュニティが提供する MCP サーバーのみを使用する
   - オープンソースの場合はコードの確認を行う

2. **データ保護**
   - 機密情報や個人情報の取り扱いに注意する
   - Web Research などのインターネットにアクセスする MCP サーバーを使用する際は特に注意が必要

3. **リソース管理**
   - ローカル AI モデルを使用する MCP サーバーはシステムリソースを大量に消費する可能性がある
   - システム要件の確認とリソース制限の設定を検討する

### 2. AWS MCP サーバーの導入と活用

[AWS MCP Servers](https://github.com/awslabs/mcp) は、AWS のベストプラクティスと豊富な情報資源を開発ワークフローに直接統合する革新的なツールです。AWS MCP Servers は、Cline の MCP Marketplace から導入することも、単独でインストールすることも可能です。

#### AWS MCP サーバーの種類

AWS は、開発者の生産性向上と AWS サービスの効果的な活用を支援するために、複数の MCP サーバーを提供しています。以下一例です:

1. **Core MCP Server**
   - AWS Labs MCP サーバー群の中心的な役割
   - 他の MCP サーバーの管理や調整、設定の一元化

2. **AWS Documentation MCP Server**
   - AWS の公式ドキュメントを効率的に検索、探索、活用
   - マークダウン形式での情報提供

3. **Amazon Bedrock Knowledge Bases Retrieval MCP Server**
   - Amazon Bedrock の知識ベースを効率的に活用
   - 自然言語クエリによる情報検索
   - 結果のフィルタリングやリランキング

#### AWS MCP サーバーの導入方法

##### 1. MCP Marketplace からの導入（推奨）

MCP Marketplace を通じて AWS MCP サーバーを導入する方法は、最も簡単で推奨される方法です：

1. VS Code の Cline 拡張機能を開き、左側のサイドバーから「MCP Servers」を選択
2. 画面上部の「Marketplace」タブをクリック
3. 検索バーに「AWS」と入力して検索
4. 表示された AWS MCP サーバーの「Install」ボタンをクリック
5. 画面の指示に従ってインストールを完了

この方法では、依存関係の管理や設定が自動的に行われるため、初心者にも簡単に導入できます。

##### 2. 単独での導入

より詳細な設定や特定のバージョンを使用したい場合は、単独でのインストールも可能です。
公式ドキュメントを参考にインストールしてください。

##### 開発環境の準備

まず、Python 3.10 以上と、パッケージ管理ツールである uv がインストールされていることを確認します。uv は [Astral](https://astral.sh/) または [GitHub](https://github.com/astral-sh/uv) からインストールできます。

##### AWS MCP サーバーのインストール

各 MCP サーバーは以下のコマンドでインストールできます：

**Core MCP Server**
```bash
uv pip install awslabs.core-mcp-server
```

**AWS Documentation MCP Server**
```bash
uv pip install awslabs.aws-documentation-mcp-server
```

##### MCP 設定ファイルの作成

インストール後、VS Code の設定から MCP Settings を開き、以下のような設定を追加します：

```json
{
  "mcpServers": {
    "awslabs.core-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.core-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "MCP_SETTINGS_PATH": "path to your mcp settings file",
        "AWS_SDK_LOAD_CONFIG": "1"
      }
    },
    "awslabs.aws-documentation-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AWS_SDK_LOAD_CONFIG": "1",
        "DOCS_CACHE_TTL": "3600"
      }
    }
  }
}
```

#### AWS MCP サーバーの実践的な活用例

AWS MCP サーバーの活用方法を具体的に理解するために、AWS Documentation MCP Server を使用して AWS S3 バケットの命名規則に関する情報を検索・取得する例を見てみましょう。

まず、S3 バケットの命名規則に関するドキュメントを検索します。Cline に対して、以下のように質問します：

```
AWS S3 バケットの命名規則について調べてください
```

Cline は内部的に AWS Documentation MCP Server の `search_documentation` ツールを使用して検索を行います：

![AWS Documentation MCP Server による検索結果](../images/aws-document-mcp-search-document.png)

検索結果から、最も関連性の高いドキュメントを選択し、その内容を取得します：

![AWS Documentation MCP Server によるドキュメント読み取り](../images/aws-document-mcp-read-document.png)

取得したドキュメントには、S3 バケットの命名規則に関する詳細な情報が含まれています：

- バケット名は 3 文字以上 63 文字以下である必要がある
- バケット名には小文字、数字、ピリオド (.)、ハイフン (-) のみを使用できる
- バケット名は文字または数字で始まり、文字または数字で終わる必要がある

このように、AWS Documentation MCP Server を使用することで、AWS のドキュメントを効率的に検索し、必要な情報を素早く取得することができます。

## セキュリティに関する注意事項

MCP サーバーを導入・実行する際には、以下のセキュリティ上の注意点に留意してください：

1. **信頼性の確認**
   - 組織内での MCP サーバー利用に関するポリシーや許可を事前に確認すること
   - 信頼できるソースから提供される MCP のみをインストールすること
   - オープンソースの MCP の場合、コードを確認してから使用すること

2. **データ保護**
   - 外部サイトへのアクセスを行う MCP は、情報漏洩のリスクがあることを認識すること
   - 機密情報や個人情報を扱う際は、適切なセキュリティ対策が施された MCP のみを使用すること
   - API キーなどの認証情報は環境変数として安全に管理すること

3. **アクセス制御**
   - MCP サーバーに必要最小限の権限のみを付与すること
   - `autoApprove` 設定は慎重に行い、信頼できるツールのみに許可すること
   - 定期的に MCP の動作やアクセス先を監査し、不審な挙動がないか確認すること

4. **リソース管理**
   - MCP サーバーのリソース使用状況を監視すること
   - 不要なサーバーは無効化または削除すること

---

**[次のステップ]**
- [LiteLLM ワークショップへ進む](./litellm.md)
- [ワークショップ一覧に戻る](./README.md)
