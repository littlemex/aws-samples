# L300: AI コーディング支援エージェントにおける開発生産性とガバナンスの両立

本資料ではワークショップの一連の流れをまとめます。

## 座学

AI コーディング支援エージェントは、開発者の生産性を大幅に向上させる可能性を秘めていますが、企業環境での導入には適切なガバナンスとセキュリティ対策が不可欠です。本ワークショップの座学セクションでは、まず AI コーディング支援エージェントの概要と、特に Cline と Amazon Bedrock の特徴や利点について解説します。続いて、企業環境での AI 活用におけるガバナンスの重要性、セキュリティリスクとその対策、コスト管理の方法などについて詳しく説明します。

1. ご挨拶と本日のワークショップに関する全体の説明
2. [座学用ブログ](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/blog/README.md) の説明と質疑応答

## ハンズオン

本ハンズオンでは、AWS 環境上で AI コーディング支援エージェントを構築し、適切なガバナンスを確保しながら運用するための一連の作業を体験します。まず AWS マネジメントコンソールから AWS CloudShell を起動し、AWS CloudFormation テンプレートを使用して Amazon EC2 インスタンスをデプロイします。次に、ポートフォワーディングを設定してローカルブラウザから VS Code Server にアクセスし、開発環境を整えます。この環境内で Cline 拡張機能をインストールし、Amazon Bedrock との連携設定を行います。

続いて、LiteLLM Proxy をコンテナとして起動し、Cline からアクセスできるよう設定します。Amazon EC2 インスタンスのプロファイルに、Amazon Bedrock アクセス用の AWS Identity and Access Management (IAM) ロールが付与されているため、アクセスキーなどの認証情報を明示的に設定することなく、安全に Amazon Bedrock の LLM モデルを利用できます。LiteLLM Proxy の管理 UI にアクセスして、モデルの設定状況やログを確認する方法も学びます。

さらに、Cline の実行ログを Langfuse に転送する設定を行い、AI の利用状況やパフォーマンスを可視化します。Langfuse の Web UI にアクセスして、トレース情報やダッシュボードの活用方法を体験します。

時間に余裕がある参加者は、オプショナルコンテンツとして MLflow によるよりモニタリング設定や、MCP（Model Context Protocol）を活用した機能拡張の演習にも取り組むことができます。MLflow は起動に時間がかかるため、早く基本ハンズオンを終えた方から順次取り組みます。

このハンズオンを通じて、参加者は開発生産性の向上とガバナンスの両立を実現する環境構築のスキルを習得できます。

## 手順リスト

### 0. 事前準備

ローカル PC に必要なツールのインストールを実施します。既に実施されている方は実施済み作業をスキップしてください。

1. [AWS CLIをインストール](https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/getting-started-install.html)します
1. [AWS Systems Manager Session Manager プラグインをインストール](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/README.md#%E3%83%AD%E3%83%BC%E3%82%AB%E3%83%AB-pc-%E3%81%AB%E5%BF%85%E8%A6%81%E3%81%AA%E3%83%84%E3%83%BC%E3%83%AB%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)します
2. [AWS 認証情報の設定](https://github.com/littlemex/aws-samples/tree/main/workshops/ai-coding-workshop/cline/0.setup/1.cline#2-amazon-bedrock-%E3%81%AE%E8%AA%8D%E8%A8%BC%E6%83%85%E5%A0%B1%E8%A8%AD%E5%AE%9A) を行います

### 1. 環境構築

1. [AWS マネジメントコンソール](https://console.aws.amazon.com/)にログインします
2. [AWS CloudShell を起動](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#aws-cloudshell-を使用する場合)します
3. [AWS CloudFormation テンプレートをダウンロード](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#共通操作)します
   ```bash
   curl -O https://raw.githubusercontent.com/littlemex/aws-samples/main/workshops/ai-coding-workshop/cline/0.setup/cfn/ec2-ssm.yml
   ```
4. [AWS CloudFormation スタックをデプロイ](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#1-ec2-ssmyml-を使用する場合)します
   ```bash
   export USERNAME=<任意の値（- 使用可、_ 使用不可）>
   aws cloudformation deploy \
     --template-file ec2-ssm.yml \
     --stack-name ai-workshop-${USERNAME} \
     --parameter-overrides UserName=${USERNAME} Environment=dev \
     --capabilities CAPABILITY_NAMED_IAM
   ```
5. [スタックの出力を確認](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#アクセス方法)します
   ```bash
   aws cloudformation describe-stacks \
     --stack-name ai-workshop-${USERNAME} \
     --query 'Stacks[0].Outputs' \
     --output table
   ```
6. ローカル PC で[ポートフォワーディングを設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#vs-code-server-へのアクセス)します
   ```bash
   aws ssm start-session \
     --target <インスタンス ID> \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["8080"],"localPortNumber":["18080"]}'
   ```
7. ブラウザで [VS Code Server にアクセス](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/cfn/README.md#vs-code-server-へのアクセス)します（http://localhost:18080）

### 2. Cline のセットアップ

1. [Cline 拡張機能をインストール](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/1.cline/README.md#1-cline-拡張機能のインストール)します
2. [Amazon Bedrock のモデルアクセスを設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/README.md#amazon-bedrock-モデルアクセスの設定)します
3. [Cline の認証設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/1.cline/README.md#2-amazon-bedrock-の認証情報設定)を行います。
    - API Provider に Amazon Bedrock を指定する場合は、プロファイル or アクセスキー設定が必要です。
4. [Cline の詳細設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/1.cline/README.md#3-cline-の詳細設定)を行います

### 3. LiteLLM Proxy の設定

1. LiteLLM ディレクトリに移動します
   ```bash
   cd ~/aws-samples/workshops/ai-coding-workshop/cline/2.litellm/
   ```
2. [環境変数を設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#1-iam-ロールを使用する方法推奨)します
   ```bash
   cp .env.example .env
   # アクセスキー等の設定は不要
   ```
3. [LiteLLM Proxy を起動](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#1-iam-ロールを使用する方法推奨)します
   ```bash
   ./manage-litellm.sh start
   ```
4. [動作確認](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#3-動作確認)を行います
   ```bash
   export LITELLM_MASTER_KEY=sk-litellm-test-key
   curl http://localhost:4000/v1/models \
     -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"
   ```
5. [Cline と LiteLLM Proxy を連携](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#cline-での-litellm-設定)します
6. 追加で Port Forward を設定します
   ```bash
   aws ssm start-session \
     --target <インスタンス ID> \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["4000"],"localPortNumber":["4000"]}'
   ```
6. [LiteLLM Proxy 管理画面](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#litellm-管理画面admin-ui)にアクセスします（http://localhost:4000/ui)

### 4. Langfuse によるログ分析

1. Langfuse ディレクトリに移動します
   ```bash
   cd ~/aws-samples/workshops/ai-coding-workshop/cline/4.langfuse/
   ```
2. [環境変数を設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#セットアップ手順)します
   ```bash
   cp .env.example .env
   ```
3. [Langfuse を起動](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#セットアップ手順)します
   ```bash
   ./manage-langfuse.sh start
   ```
4. [LiteLLM Proxy の設定を更新](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#セットアップ手順)します
   ```bash
   ./manage-langfuse.sh update-config
   ```
5. [ポートフォワーディングを設定](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#セットアップ手順)します
   ```bash
   aws ssm start-session \
     --target <インスタンス ID> \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
   ```
6. [Langfuse Web UI にアクセス](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#langfuse-web-ui-の利用方法)します（http://localhost:3000）
7. [ダッシュボード](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#dashboard)と[トレース](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#traces)を確認します

### 5. オプショナルハンズオン

#### 5.1 MLflow によるモニタリング

1. [MLflow の環境構築](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/5.mlflow/README.md#cdk-のデプロイ)を行います
2. [MLflow トラッキングサーバーの起動](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/5.mlflow/README.md#アプリケーションのセットアップ)と設定を行います
3. [メトリクス収集と分析](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/5.mlflow/README.md#主要機能)を行います

#### 5.2 MCP の活用

1. [Weather MCP サーバーの実装](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/1.mcp/0.weather-mcp/README.md)を行います
2. [MCP Marketplace の活用](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/1.mcp/1.marketplace-mcp/README.md)を体験します - **推奨**
3. [AWS MCP サーバーの利用](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/1.mcp/2.aws-mcp/README.md)を試します

## トラブルシューティング

- 組織の制約で session-manager-plugin をローカル PC に入れることができない場合
  - ローカルの VS Code を用いて Remote Development using SSH を利用してみてください。設定方法は[こちら](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/0.remotessh/README.md)

- Cline の認証エラーが発生する場合
  - [AWS 認証情報が正しく設定されているか確認](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/1.cline/README.md#トラブルシューティング)してください
  - リージョンが正しく設定されているか確認してください

- モデルにアクセスできない場合
  - [AWS アカウントで Amazon Bedrock のモデルへのアクセスが有効になっているか確認](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/0.setup/README.md#amazon-bedrock-モデルアクセスの設定)してください
  - 「Use cross-region inference」が有効になっているか確認してください

- LiteLLM Proxy の接続エラーが発生する場合
  - [LiteLLM Proxy が正常に起動しているか確認](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/2.litellm/README.md#3-動作確認)してください
  - API キーが正しく設定されているか確認してください

- Langfuse の接続エラーが発生する場合
  - [デバッグツール](https://github.com/littlemex/aws-samples/blob/main/workshops/ai-coding-workshop/cline/4.langfuse/README.md#デバッグツール)を使用してトラブルシューティングを行ってください
