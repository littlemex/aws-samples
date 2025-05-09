# Cline with LiteLLM Proxy ワークショップ

このワークショップでは、Cline with LiteLLM Proxy の設定とコーディング体験を行います。

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
    click L href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mcp.md"
    click N href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/langfuse.md"
    click CL href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/cline.md"
    click O href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mlflow.md"

    style M fill:#f96,stroke:#333,stroke-width:2px
```

## LiteLLM Proxy 機能紹介

### 設定例

#### 1. LiteLLM キー設定について

LiteLLM Proxy では、以下のような Virtual Key 関連の設定が重要です：

- **LITELLM_MASTER_KEY**: これは LiteLLM Proxy へのアクセスを管理するマスターキーです。例えば `sk-litellm-test-key` のような値を設定します。このキーは開発環境での使用を想定したテスト用の値です。

- **Virtual Key**: マスターキーとは別に、異なるユーザーやアプリケーション用に Virtual Key を作成できます。これにより、アクセス制御や使用状況の追跡が可能になります。

- **仮想モデルグループ**: 特定の Virtual Key に対して、アクセス可能なモデルのグループを定義できます。例えば、あるユーザーには Claude 3.7 のみへのアクセスを許可し、別のユーザーにはすべてのモデルへのアクセスを許可するといった設定が可能です。

- **トークン予算**: 各キーに対してトークン使用量の上限を設定できます。これにより、コスト管理や過剰使用の防止が可能になります。チームに対して使用量の上限を設定することもできます。

#### `store_prompts_in_spend_logs` 設定

`general_settings` セクションにある `store_prompts_in_spend_logs` 設定は、プロンプト内容をログに保存するかどうかを制御します：

```yaml
general_settings:
  store_prompts_in_spend_logs: false  # プライバシー保護のため、デフォルトでは false を推奨
```

開発環境でデバッグ目的で使用する場合は `true` に設定できますが、プライバシーやセキュリティ上の懸念がある場合は `false` に設定してください。`false` にした場合でも別の章で取り扱う Langfuse 等へのログ送信は可能です。

#### LiteLLM UI アクセス管理

LiteLLM 管理画面へのアクセスは以下の方法で制御できます：

1. **ユーザー認証**: `.env` ファイルで UI アクセス用のユーザー名とパスワードを設定します
   ```
   LITELLM_UI_USERNAME=admin
   LITELLM_UI_PASSWORD=password
   ```

### 主な機能

#### モデル一覧

利用設定したモデルとその設定情報を確認できます。Setting 画面ではフォールバック設定やモデルの優先順位を設定することが可能です。

![モデル一覧画面](../images/litellm-models.png)

#### 使用状況分析

API の使用状況や料金情報を確認できます。期間別の使用量やコスト分析が可能です。

![使用状況分析画面](../images/litellm-usage.png)

### ログ機能

LiteLLM のログ機能では、以下の情報が確認できます：

#### デフォルトのログ設定

| ログタイプ | デフォルトで記録 |
|------------|-----------------|
| 成功ログ | ✅ はい |
| エラーログ | ✅ はい |
| リクエスト/レスポンスの内容 | ❌ いいえ（デフォルトでは無効） |

デフォルトでは、LiteLLM はリクエストとレスポンスの内容（プロンプトや回答の本文）を記録しません。

![ログ画面](../images/litellm-logs.png)

### Prompt Caching 機能

Amazon Bedrock の [Prompt Caching](https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html) 機能を使用すると、同一のプロンプトに対する応答をキャッシュし、API コールを削減することができます。これにより、以下のメリットが得られます：

- レスポンス時間の短縮
- API 使用量とコストの削減

#### Amazon Bedrock Claude 3.7 Sonnet v1 での Prompt Caching

コーディング能力の高さから Cline と相性の良い Amazon Bedrock Claude 3.7 Sonnet V1 でも Prompt Caching 機能が利用可能になりました。Cline の API Provider から直接 Amazon Bedrock を指定して Prompt Caching を利用することができますし、API Provider として LiteLLM を選択した場合でも Prompt Caching を利用することができます。

専用の設定ファイル `prompt_caching.yml` を使用し Cline 設定画面上で有効化することで、簡単に利用できます。

![](../images/litellm-prompt-caching.png)

#### Amazon EC2 上での利用方法

Amazon EC2 インスタンス上で Prompt Caching を利用する場合は、以下の手順で設定します：

```bash
./manage-litellm.sh -c prompt_caching.yml start
```

#### 重要な注意事項 (2025/04/11 時点)

1. **モデルの可用性**：
   - Claude 3.7 Sonnet v1 は us-east-1 リージョンで cross region inference を有効にするケースのみで利用可能です。
   - モデルアクセスを有効化する場合は、us-east-1、us-east-2、us-west-2 すべてのリージョンで Claude 3.7 Sonnet v1 を有効化することを推奨します。

2. **モデルの特性と互換性**：
   - Claude 3.7 Sonnet v1 は高精度なコーディングが可能で、Prompt Caching 機能も利用できます。
   - Claude 3.5 Sonnet v2 は高精度なコーディングが可能ですが Prompt Caching 機能に対応していません。

3. **フォールバック設定の注意点**：
   - LiteLLM Proxy 経由で利用する場合、Prompt Caching が有効にできないモデル（例：Claude 3.5 Sonnet v2）を fallbacks に指定するとエラーが発生します。
   - フォールバック設定を行う場合は、Prompt Caching 対応モデルのみを指定するようにしてください。

その他の機能詳細については、[LiteLLM Proxy の公式ドキュメント](https://docs.litellm.ai/docs/simple_proxy)を参照してください。

---

以降、ワークショップ手順書

---

## アーキテクチャ概要

```mermaid
flowchart TD
    A[Cline] --> B[LiteLLM Proxy]
    B --> C[Amazon Bedrock]
    
    E[認証方式] --> F[IAM Role]
    E --> G[アクセスキー]
    
    F --> B
    G --> B
    
    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#bfb,stroke:#333,stroke-width:2px
```

## 認証方式の選択

### 1. IAM Role を使用する場合（Amazon EC2 環境のみ）

**メリット：**
- 認証情報の管理が不要
- セキュリティ的に推奨
- 自動更新される

**制限事項：**
- Amazon EC2 環境でのみ利用可能
- インスタンスプロファイルの設定が必要

**設定手順：**
1. Amazon EC2 インスタンスに適切な IAM ロールが割り当てられていることを確認
2. 特別な設定は不要（自動的にロールが使用される）

### 2. アクセスキーを使用する場合

**メリット：**
- どの環境でも利用可能
- 設定が簡単

**制限事項：**
- 認証情報の管理が必要
- 定期的な更新が必要
- セキュリティリスクの考慮が必要

**設定手順：**
1. AWS 認証情報を環境変数またはプロファイルで設定
2. LiteLLM の設定ファイルで認証方式を指定

## 環境別のセットアップ手順

作業ディレクトリに移動してください。

```bash
cd ~/aws-samples/workshops/ai-coding-workshop/cline/2.litellm
```

### Amazon EC2 環境の場合（推奨）

環境変数ファイルの準備を行いましょう。

docker compose を利用して環境を構築しており、データベースの認証情報、AWS アクセスキー、等の環境変数を設定します。
設定された環境変数は、コンテナ起動時の設定、もしくは LiteLLM Proxy の Config ファイル内で利用されます。
この場合は、IAM Role を用いるため AWS アクセスキーの設定は不要です。

```bash
cp .env.example .env
```

#### LiteLLM Proxy の起動

スクリプトを実行して LiteLLM Proxy を起動します。内部的には docker compose を単に実行しているだけの Wrapper です。
`.env` の `CONFIG_FILE="iam_role_config.yml"` がデフォルトの LiteLLM Proxy の設定ファイルです。
この設定ファイルに基づいて LiteLLM Proxy の利用するモデル、ログ保存有無、など様々な設定を行います。

```bash
./manage-litellm.sh start
```

### ローカルPC環境の場合

この場合は、IAM Role を用いるため AWS アクセスキーの設定が必要です。

```bash
cp .env.example .env
```

```bash
# .env
...
# AWS Configuration
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
...
```

#### LiteLLM Proxy の起動

スクリプトの引数でアクセスキー認証を利用する設定ファイルを指定します。

```bash
./manage-litellm.sh -c access_key_config.yml start
```

### 動作確認

LiteLLM Proxy の Virtual Key `sk-litellm-test-key` は .env でコンテナ作成時に設定したものです。
この Virtual Key を用いることで開発者は Amazon Bedrock に直接アクセスすることなく、間接的に モデル API を利用できます。
`iam_role_config.yml` 設定ファイルで記載されたモデルリストに対して上記の Virtual Key はアクセスすることが可能です。
以下のコマンドで上記の Virtual Key がアクセスすることが可能なモデル一覧を取得できます。

```bash
export LITELLM_MASTER_KEY=sk-litellm-test-key
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"
```

### Cline と LiteLLM Proxy を連携させる

それでは Cline の API Provider に LiteLLM Proxy を連携しましょう。

![Cline での LiteLLM 設定例](../images/cline-litellm.png)

1. Cline の設定画面から「API Provider」セクションを開きます
2. 「Add Provider」ボタンをクリックします
3. 以下の情報を入力します：
   - **Provider Type**: LiteLLM
   - **Name**: 任意の識別名（例：「Local LiteLLM Proxy」）
   - **API Key**: 環境変数 `LITELLM_MASTER_KEY` で設定した値（例：`sk-litellm-test-key`）
   - **Base URL**: `http://localhost:4000`
   - **Model ID**: LiteLLM Proxy で利用可能なモデル ID（例：`bedrock-converse-us-claude-3-7-sonnet-v1`）、config ファイルを確認ください。
   - **[注意!] Extended thinking オプション**: Claude 3.7 Sonnet V1 を使用する場合、Cline の「Enable extended thinking」をオフにしないとエラーになるバグがあります。
4. 「Save」ボタンをクリックして設定を保存します

設定完了後、Cline から簡単なタスクを実行して動作確認してみましょう。

## LiteLLM 管理画面（Admin UI）

LiteLLM には、サービスの監視や管理を行うための Web インターフェースが用意されています。この管理画面では、モデルの一覧確認、使用状況の分析、ログの閲覧などが可能です。

### アクセス方法

1. ポートフォワードを設定

   Amazon EC2 実行環境の場合は、VS Code Server へのアクセスとは別にポートフォワードを実行する必要があります。
   4000 → 4000 で VS Code Server のコマンドとは別のターミナルを開いて追加のコマンドを実行してください。
   ポートフォワードコマンドを実行してから UI へのアクセスが一定期間ない場合、コマンドが fail するので再度コマンドを再実行してください。

2. LiteLLM Proxy が起動している状態で、ブラウザから以下の URL にアクセス
   ```
   http://localhost:4000/ui
   ```

2. ログイン画面が表示されます。認証情報は `.env` ファイルに設定した値を使用します。
   ```
   # デフォルト設定
   UI_USERNAME=litellm
   UI_PASSWORD=litellm
   ```

![LiteLLM 管理画面ログイン](../images/litellm-ui-login.png)

---

**[次のステップ]**
- [Langfuse ワークショップを開始](./langfuse.md)
- [ワークショップ一覧に戻る](./README.md)
