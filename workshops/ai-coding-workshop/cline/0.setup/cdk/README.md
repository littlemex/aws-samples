# AWS CDK を使用した環境構築

このガイドでは、AWS CDK を使用して AI エージェントワークショップの開発環境をセットアップする手順を説明します。

## デプロイ方法

AWS CloudShell または ローカル環境から CDK を使用してデプロイできます。

### 実行環境の選択

以下のいずれかの環境でコマンドを実行できます：

#### AWS CloudShell を使用する場合

AWS CloudShell を使用すると、ブラウザから直接 AWS CLI コマンドを実行できます。

> **注意**: 
> - AWS CloudShell は追加料金なしで使用でき、必要な AWS CLI ツールが事前にインストールされています
> - 以下の cdk, git, npm 等のコマンドはすべて CloudShell 上でデフォルトで利用可能です

必要なツール：
- Node.js v18.x 以上と npm v9.x 以上（CloudShell にプリインストール済み）
- AWS CDK v2.92.0 以上（`npm install -g aws-cdk` でインストール）

#### ローカル環境を使用する場合

> **注意**:
> - ローカル環境の場合は事前に必要なツールのインストールが必要です

必要なツール：
- Node.js v18.x 以上と npm v9.x 以上（推奨: Node.js v20.x LTS）
- AWS CDK v2.92.0 以上
- AWS CLI がインストールされていること

## CDK Bootstrap の実行

CDK を使用してスタックをデプロイする前に、対象の AWS アカウントとリージョンで bootstrap を実行する必要があります。これは、CDK がデプロイに必要とする特別なリソース（S3 バケットや IAM ロールなど）を作成するプロセスです。

### Bootstrap が必要な場合

以下のような場合、CDK bootstrap の実行が必要です：

- 初めて CDK をアカウントとリージョンで使用する場合
- アセットを含むスタックをデプロイする場合（例：Lambda 関数のコード、EC2 のユーザーデータスクリプトなど）
- クロスアカウントデプロイを行う場合

### Bootstrap の実行方法

1. AWS CLI の認証情報が正しく設定されていることを確認：
   ```bash
   aws sts get-caller-identity
   ```

2. Bootstrap コマンドを実行：
   ```bash
   cdk bootstrap aws://ACCOUNT-NUMBER/REGION
   ```
   例：
   ```bash
   cdk bootstrap aws://123456789012/us-east-1
   ```

## デプロイ手順

1. リファレンス用の CDK リポジトリをクローンします：
   ```bash
   git clone https://github.com/littlemex/aws-samples
   cd aws-samples/cdk/ec2-ssm-cdk
   ```

2. 依存関係をインストールします：
   ```bash
   npm install
   ```

3. CDK スタックをデプロイします：

- インスタンスタイプ等の設定値を確認した上でデプロイしてください。

   ```bash
   cdk deploy
   ```

   > **注意**: インスタンスの起動まで約 5-10 分かかる場合があります

## スタックの削除

環境が不要になった場合は、以下のコマンドでスタックを削除できます：

```bash
cdk destroy
```

## トラブルシューティング

### Bootstrap 関連の一般的なエラー

1. "This stack uses assets, so the toolkit stack must be deployed to the environment"
   - 解決策: `cdk bootstrap` を実行してください

2. "CDK bootstrap stack version X required, but found version Y"
   - 解決策: 新しいバージョンの機能を使用するために bootstrap の再実行が必要です
   ```bash
   cdk bootstrap --force
   ```

3. "Unable to resolve AWS account to deploy into"
   - 解決策: AWS 認証情報が正しく設定されているか確認してください
