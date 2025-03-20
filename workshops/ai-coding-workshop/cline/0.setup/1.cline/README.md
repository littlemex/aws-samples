## Amazon Bedrock を利用した Cline セットアップ手順

### 1. Cline 拡張機能のインストール

VSCode の Extentions メニューから「Cline」を検索し、インストールを実行します。インストール完了後、VSCode を再起動することをお勧めします。

![Cline拡張機能のインストール](images/cline-setup1.png)

### 2. Amazon Bedrock の認証情報設定

認証方式として「Use your own API key」を選択し、以下の設定を行います：
- API Provider: Amazon Bedrock
- 認証方式: AWS Profile

AWS認証情報は以下の形式で `~/.aws/credentials` に設定する必要があります：

```
cat ~/.aws/credentials 
[cline]
aws_access_key_id = XXX
aws_secret_access_key = XXX
region = us-east-1
```

![Bedrock認証設定](images/cline-setup2.png)

### 3. Cline の詳細設定

以下の設定項目を正確に入力してください：

- AWS Profile Name: cline
  - credentials ファイルで設定したプロファイル名と一致させてください
- AWS Region: us-east-1
  - Bedrock のサービスが利用可能なリージョンを指定
- ☑️ Use cross-region inference
  - このオプションは必ず有効にしてください
- Model: anthropic.claude-3-7-sonnet-20250219-v1:0
  - 最新の Claude 3 Sonnet モデルを使用

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

`.clinerules` ファイルは、**プロジェクトのルートディレクトリに配置するだけで自動的に適用**される設定ファイルです：

1. `.clinerules` ファイルをプロジェクトのルートディレクトリに配置します
2. Cline は自動的にこのファイルを検出し、プロジェクト固有の指示として読み込みます
3. ユーザーが追加の設定や操作を行う必要はありません

`.clinerules` ファイルは、Custom Instructions とは異なります：
- **Custom Instructions**: ユーザー固有のグローバル設定で、VSCode の Cline 拡張機能の設定ダイアル ⚙️ から設定します。すべてのプロジェクトに適用されます。
- **.clinerules ファイル**: プロジェクト固有の設定で、プロジェクトのルートディレクトリに配置するだけで自動的に適用されます。このプロジェクト内での Cline の動作のみに影響します。

`.clinerules` ファイルでは以下のような設定が可能です：
- プロジェクト固有の規約やガイドラインの定義
- コーディング規約の設定
- セキュリティポリシーの設定
- 実装方針の定義
- エラーハンドリングの規約
- テスト実装の規約

詳細な例については、提供されている `.clinerules` ファイルを参照してください。
