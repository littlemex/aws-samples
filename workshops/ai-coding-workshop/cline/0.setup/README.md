# AI エージェントワークショップ環境構築手順

このガイドでは、AI エージェントワークショップの開発環境をセットアップするための手順を説明します。開発環境として EC2 を使用し、code-server または Remote SSH で接続して開発を行うことができます。

## 1. 前提条件

- AWS アカウント（適切な権限が付与されていること）
- AWS CLI がインストールされていること
- AWS CDK v2.x 以上がインストールされていること
- Node.js v14.x 以上と npm v6.x 以上がインストールされていること

### 必要なツールのインストール

```bash
# AWS CLI のインストール（macOS の例）
brew install awscli

# AWS CDK のインストール
npm install -g aws-cdk

# Session Manager プラグインのインストール（macOS の例）
# See: https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
brew install session-manager-plugin
```

## 2. EC2 環境のデプロイ

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
   ```bash
   cdk deploy
   ```

   > **注意**: インスタンスの起動まで約5-10分かかる場合があります

## 3. 開発環境へのアクセス方法

### A. code-server を使用する場合

1. デプロイ完了後、出力される Port Forward コマンドを実行します：
   ```bash
   aws ssm start-session --target <インスタンス ID> --document-name AWS-StartPortForwardingSession --parameters "portNumber=8080,localPortNumber=8080"
   ```

2. ブラウザで http://localhost:8080 にアクセスし、code-server に接続します：
   - ユーザー名：デフォルト
   - パスワード：code-server

### B. VS Code Remote SSH を使用する場合

Remote SSH を使用した接続方法の詳細については、[Remote SSH セットアップガイド](./0.remotessh/README.md)を参照してください。

## 4. cline のセットアップ

cline のインストールと設定方法については、[cline セットアップガイド](./1.cline/README.md)を参照してください。
このガイドには以下の内容が含まれています：
- Code Server 拡張機能のインストール手順
- AWS 認証情報の設定方法
- 動作確認手順
- トラブルシューティング

### Bedrock モデルアクセスの設定

1. AWS コンソールの Bedrock サービスに移動
2. 左側メニューから「Model access」を選択
3. 「Manage model access」をクリック
4. Anthropic Claude 3 モデルを選択
5. 「Save changes」をクリック

> **注意**: モデルアクセスの承認には数分かかる場合があります

![Bedrockモデルアクセスの設定](./bedrock-setup.png)

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [Code Server ドキュメント](https://coder.com/docs/code-server/latest)
- [Amazon Bedrock 開発者ガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)