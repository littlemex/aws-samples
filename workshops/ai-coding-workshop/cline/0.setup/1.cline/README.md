## Amazon Bedrock を利用した Cline セットアップ手順

### 1. Cline 拡張機能のインストール

VSCode の Extentions メニューから「Cline」を検索し、インストールを実行します。インストール完了後、VSCode を再起動することをお勧めします。

![Cline拡張機能のインストール](images/cline-setup1.png)

### 2. Amazon Bedrock の認証情報設定

認証方式として「Use your own API key」を選択し、以下の設定を行います：
- API Provider: Amazon Bedrock
- 認証方式: AWS Profile

AWS 認証情報の設定には、以下の 2 つの方法があります：

#### 方法 1: AWS アクセスキーを使用する方法（`aws configure`）

AWS CLI の `aws configure` コマンドを使用して、アクセスキーとシークレットキーを `~/.aws/credentials` ファイルに設定します：

```bash
aws configure
```

コマンド実行後、以下の情報の入力を求められます：
- AWS Access Key ID: [アクセスキー ID を入力]
- AWS Secret Access Key: [シークレットアクセスキーを入力]
- Default region name: us-east-1
- Default output format: json (または希望の形式)

設定後、`~/.aws/credentials` ファイルは以下のようになります：

```
[Cline]
aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
region = us-east-1
```

#### 方法 2: AWS SSO を使用する方法（`aws configure sso`）

AWS SSO を使用すると、アクセスキーを手動で管理する必要がなく、より安全に認証を行えるメリットがあります。

```bash
aws configure sso
```

コマンド実行後、以下の情報の入力を求められます：
- SSO start URL: [SSO のスタート URL を入力]
- SSO Region: [SSO のリージョンを入力]
- SSO registration scopes: sso:account:access

ブラウザが開き、AWS SSO へのログインを求められます。ログイン後、アクセスするアカウントとロールを選択します。

設定後、`~/.aws/config` ファイルは以下のようになります：

```
[profile Cline]
sso_session = sso-session-name
sso_account_id = 123456789012
sso_role_name = RoleName
region = us-east-1

[sso-session sso-session-name]
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

![Bedrock認証設定](images/cline-setup2.png)

### 3. Cline の詳細設定

以下の設定項目を正確に入力してください：

- AWS Profile Name: Cline
  - credentials ファイルで設定したプロファイル名と一致させてください
- AWS Region: us-east-1
  - Bedrock のサービスが利用可能なリージョンを指定
- ☑️ Use cross-region inference
  - このオプションは必ず有効にしてください
- ☑️ Use prompt caching
  - [Amazon Bedrock プロンプトキャッシュ](https://aws.amazon.com/jp/bedrock/prompt-caching/) が有効になります。
- Model: 最新の Claude 3 Sonnet モデル（例: anthropic.claude-3-sonnet-*）
  - 利用可能な最新のモデルを選択してください
  - UI に表示される最新のものを選択

設定が完了したら「Done」ボタンを押下します。

![設定完了](images/cline-setup3.png)

### 4. データ収集の設定

「Help Improve Cline」というダイアログが表示されたら、「Deny」を選択してください。

### セットアップ完了

以上で Cline の設定は完了です。VSCode のサイドバーに Cline のアイコンが表示され、利用可能な状態となります。

### トラブルシューティング

1. 認証エラーが発生する場合
   - AWS 認証情報が正しく設定されているか確認してください
   - リージョンが正しく設定されているか確認してください

2. モデルにアクセスできない場合
   - AWS アカウントで Bedrock のモデルへのアクセスが有効になっているか確認してください
   - 「Use cross-region inference」が有効になっているか確認してください

3. 拡張機能が正しく動作しない場合
   - VSCode を再起動してください
   - 拡張機能を一度アンインストールしてから再インストールしてください

### カスタマイズ設定

#### [.clinerules ファイル](https://docs.cline.bot/improving-your-prompting-skills/prompting)

本ディレクトリには、Cline の動作をカスタマイズするための `.clinerules` ファイルのサンプルを提供しています。

`.clinerules` ファイルは、プロジェクトのルートディレクトリに配置するだけで自動的に適用される設定ファイルです。このファイルを使用することで、プロジェクト固有の指示や規約を Cline に与えることができます。

#### テーマ別ルールファイルの追加

Cline では、特定のテーマや機能に特化したルールを定義し、Global Rules として参照することができます。これにより機能やテーマごとに Cline のルールを管理することが可能です。ルールの ON/OFF を UI から行うことも可能です。

例えば、本ディレクトリには Model Context Protocol (MCP) に関する規約を定義した `.clinerules-mcp.md` がサンプルとして含まれています。このファイルには、MCP の基本概念、設定ガイドライン、セキュリティ考慮事項など、MCP に特化したルールが詳細に記述されています。

![Clineテーマ別ルール](images/cline-mcprule.png)

このように、テーマ別のルールファイルを作成することで、以下のような利点があります：

1. **モジュール化**: ルールを機能やテーマごとに分割し、管理が容易になります
2. **再利用性**: 共通のルールを複数のプロジェクトで再利用できます
3. **メンテナンス性**: 特定の機能に関するルールの更新が容易になります
4. **可読性**: 関心事の分離により、ルールの理解が容易になります

詳細については、[Cline の公式ドキュメント](https://docs.cline.bot/improving-your-prompting-skills/prompting)を参照してください。
