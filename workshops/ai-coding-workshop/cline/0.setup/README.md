# AI エージェントワークショップ環境構築手順

このガイドでは、AI エージェントワークショップの開発環境をセットアップするための手順を説明します。開発環境として SageMaker Studio または EC2 のいずれかを選択できます。

## オプション1: SageMaker Studio のセットアップ

### 前提条件
- AWS アカウント（適切な権限が付与されていること）
- AWS CDK がインストールされていること
- Node.js と npm がインストールされていること

### デプロイ手順

1. リファレンス用の CDK リポジトリをクローンします：
   ```bash
   git clone https://github.com/aws-samples/aws-cdk-sagemaker-studio
   cd aws-cdk-sagemaker-studio
   ```

2. 依存関係をインストールします：
   ```bash
   npm install
   ```

3. CDK スタックをデプロイします：
   ```bash
   cdk deploy
   ```

SageMaker Studio の CDK セットアップについての詳細は、以下のリソースを参照してください：
- [SageMaker Studio と Presigned URL の活用](https://dev.classmethod.jp/articles/amazon-sagemaker-studio-presigned-url/)
- [SageMaker Studio LCC CDK サンプル](https://github.com/aws-samples/sagemaker-studio-lcc-cdk)

## オプション2: EC2 のセットアップ

### 前提条件
- AWS アカウント（適切な権限が付与されていること）
- AWS CDK がインストールされていること
- Node.js と npm がインストールされていること

### デプロイ手順

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

## Code Server の設定

環境のデプロイが完了したら、以下の手順で Code Server をセットアップします：

1. 開発環境へのアクセス：
   - SageMaker Studio の場合：提供された Studio URL を使用
   - EC2 の場合：AWS Systems Manager Session Manager 経由で接続

2. Code Server 拡張機能のインストール：
   - 拡張機能パネルを開く（Ctrl+Shift+X）
   - Cline 拡張機能を検索してインストール

## Cline プラグインのセットアップ

1. Cline プラグインのインストール：
   ```bash
   code --install-extension rooveterinaryinc.roo-cline
   ```

2. Cline の設定：
   - コマンドパレットを開く（Ctrl+Shift+P）
   - "Preferences: Open Settings (JSON)" を検索
   - Cline の設定を追加

## 認証情報の設定

1. AWS 認証情報の設定：
   ```bash
   aws configure
   ```

2. 必要な環境変数の設定：
   ```bash
   export AWS_REGION=<リージョン名>
   export AWS_PROFILE=<プロファイル名>
   ```

## 動作確認

セットアップの確認：

1. Code Server を開く
2. Cline 拡張機能が正しく読み込まれていることを確認
3. 簡単な Cline コマンドを実行して環境をテスト

## トラブルシューティング

問題が発生した場合の確認事項：

1. AWS 認証情報が正しく設定されているか
2. ネットワーク接続が正常か
3. 必要な権限が全て付与されているか
4. Code Server のログにエラーメッセージがないか

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [SageMaker Studio ドキュメント](https://docs.aws.amazon.com/ja_jp/sagemaker/latest/dg/studio.html)
- [Code Server ドキュメント](https://coder.com/docs/code-server/latest)