# AI エージェントワークショップ環境構築手順

このガイドでは、AI エージェントワークショップの開発環境をセットアップするための手順を説明します。開発環境として Amazon Elastic Compute Cloud (Amazon EC2) を使用し、VS Code Server または [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) で接続して開発を行うことができます。

## 1. 前提条件

ワークショップの実行環境、必要なツール、バージョン要件などの詳細については、[詳細要件表](./requirements.md)を参照してください。

- AWS アカウント（適切な権限が付与されていること）
- AWS CLI がインストールされていること
- AWS Systems Manager Session Manager プラグイン

### ローカル PC に必要なツールのインストール

> **注意**: 
> - Session Manager プラグインは、EC2 インスタンスへの接続に必要なツールです
> - このツールはローカル PC にインストールする必要があります（CloudShell では使用できません）

```bash
# AWS Systems Manager Session Manager プラグインのインストール（macOS の例）
# See: https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
brew install session-manager-plugin
```

MacOS 以外の場合は [AWS CLI 用の Session Manager プラグインをインストールする](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) を参照してください。

## 2. EC2 環境のデプロイ

開発環境のデプロイには、AWS CDK または AWS CloudFormation を使用できます。どちらの方法も AWS CloudShell からブラウザ上で直接実行することが可能です。

[AWS CDK を使用したデプロイ](./cdk/README.md)は、Infrastructure as Code の利点を活かした柔軟なカスタマイズが可能です。ただし、cdk bootstrap の実行に管理者権限が必要となるため、権限が制限されている環境では利用できない場合があります。

[AWS CloudFormation を使用したデプロイ](./cfn/README.md)は、管理者権限を必要とせず、より広い環境で利用できます。CloudFormation テンプレートは事前に検証済みのため、安定した環境構築が可能です。

## 3. 開発環境へのアクセス方法

### A. VS Code Server を使用する場合

1. デプロイ完了後、出力される Port Forward コマンドをローカル PC のターミナルから実行します（AWS CloudShell では実行できません）：

```bash
aws ssm start-session --target <インスタンス ID> --document-name AWS-StartPortForwardingSession --parameters "portNumber=8080,localPortNumber=8080"
# もしくは以下を実行する
cd workshops/ai-coding-workshop/cline/scripts
uv venv && source .venv/bin/activate && uv sync
uv run port_forward.py --instance-id <インスタンス ID>
```

2. ブラウザで http://localhost:18080 にアクセスし、VS Code Server に接続します

### B. VS Code Remote SSH を使用する場合

Remote SSH を使用した接続方法の詳細については、[Remote SSH セットアップガイド](./0.remotessh/README.md)を参照してください。

## 4. Cline のセットアップ

Cline のインストールと設定方法については、[Cline セットアップガイド](./1.cline/README.md)を参照してください。
このガイドには以下の内容が含まれています：
- VS Code Server 拡張機能のインストール手順
- AWS 認証情報の設定方法
- 動作確認手順
- トラブルシューティング

### Amazon Bedrock モデルアクセスの設定

1. AWS コンソールの Amazon Bedrock サービスに移動
2. 左側メニューから「Model access」を選択
3. 「Manage model access」をクリック
4. Anthropic Claude 3 系モデルをすべて選択
5. 「Save changes」をクリック

> **注意**: モデルアクセスの承認には数分かかる場合があります

![Amazon Bedrock モデルアクセスの設定](./bedrock-setup.png)

### Amazon Bedrock のクオータの確認

- [us-east-1 リージョン](https://us-east-1.console.aws.amazon.com/servicequotas/home/services/bedrock/quotas)・[us-west-2 リージョン](https://us-west-2.console.aws.amazon.com/servicequotas/home/services/bedrock/quotas) で `tokens per minute for Anthropic Claude` をクオータ検索窓に入力し、各モデルが利用可能になっていることを確認します。

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [VS Code Server ドキュメント](https://code.visualstudio.com/docs/remote/vscode-server)
- [Amazon Bedrock 開発者ガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)
