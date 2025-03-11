# AI エージェントワークショップ環境構築手順

このガイドでは、AI エージェントワークショップの開発環境をセットアップするための手順を説明します。開発環境として SageMaker Studio または EC2 のいずれかを選択できます。各環境の特徴を理解した上で、ニーズに合った選択をしてください。

## 環境の選択

### SageMaker Studio
- **メリット**：
  - マネージドな開発環境
  - 豊富な機械学習ツールとの統合
  - スケーラブルなリソース管理
- **適している場合**：
  - データサイエンスや機械学習の作業も行う場合
  - マネージドサービスを優先する場合
- **適していない場合**:
  - コンテナ namespace を柔軟に変更する必要がある場合

### EC2
- **メリット**：
  - より柔軟なカスタマイズ性
  - コスト効率の良い運用が可能
  - 完全なコントロール権限
- **適している場合**：
  - 特定のソフトウェアやツールのインストールが必要な場合
  - カスタマイズされた環境が必要な場合

## オプション1: SageMaker Studio のセットアップ

### 前提条件
- AWS アカウント（適切な権限が付与されていること）
- AWS CDK v2.x 以上がインストールされていること
- Node.js v14.x 以上と npm v6.x 以上がインストールされていること

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

   > **注意**: デプロイには約15-20分かかる場合があります

SageMaker Studio の CDK セットアップについての詳細は、以下のリソースを参照してください：
- [SageMaker Studio と Presigned URL の活用](https://dev.classmethod.jp/articles/amazon-sagemaker-studio-presigned-url/)
- [SageMaker Studio LCC CDK サンプル](https://github.com/aws-samples/sagemaker-studio-lcc-cdk)

## オプション2: EC2 のセットアップ

### 前提条件
- AWS アカウント（適切な権限が付与されていること）
- AWS CDK v2.x 以上がインストールされていること
- Node.js v14.x 以上と npm v6.x 以上がインストールされていること

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

   > **注意**: インスタンスの起動まで約5-10分かかる場合があります

## Code Server の設定

環境のデプロイが完了したら、以下の手順で Code Server をセットアップします：

1. 開発環境へのアクセス：
   - SageMaker Studio の場合：
     1. AWS コンソールから SageMaker Studio に移動
     2. 提供された Studio URL をクリックしてアクセス
   - EC2 の場合：
     1. AWS コンソールから Systems Manager に移動
     2. Session Manager を選択
     3. デプロイしたインスタンスに接続

2. Code Server 拡張機能のインストール：
   - 拡張機能パネルを開く（Ctrl+Shift+X または ⌘+Shift+X）
   - Cline 拡張機能を検索してインストール
   - インストール後、VSCode の再起動が必要な場合があります

## Cline プラグインのセットアップ

Cline プラグインのセットアップ手順の詳細については、[Cline セットアップガイド](./1.cline/README.md)を参照してください。

## 認証情報の設定

### IAM ポリシーの設定

以下の最小権限のIAMポリシーを作成し、ユーザーまたはロールに付与してください：

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:ListFoundationModels"
            ],
            "Resource": [
                "arn:aws:bedrock:*:*:model/anthropic.claude-3*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:ListFoundationModels"
            ],
            "Resource": "*"
        }
    ]
}
```

### Bedrock モデルアクセスの設定手順

1. AWS コンソールにログインし、Bedrock サービスに移動します

2. モデルアクセスの有効化：
   - 左側メニューから「Model access」を選択
   - 「Manage model access」をクリック
   - Anthropic Claude 3 モデルを選択
   - 「Save changes」をクリック
   
   > **注意**: モデルアクセスの承認には数分かかる場合があります

![Bedrockモデルアクセスの設定](./1.cline/images/bedrock-setup1.png)

3. AWS 認証情報の設定：

aws configure 後に ~/.aws/credentials にファイルが作成され、[default] というプロファイルが存在することを確認してください。プロファイル名を [cline] に変更しましょう。

   ```bash
   aws configure
   # プロンプトに従って以下の情報を入力：
   # AWS Access Key ID
   # AWS Secret Access Key
   # Default region name (例: us-east-1)
   # Default output format (json)
   ```

4. 必要な環境変数の設定：
   ```bash
   export AWS_REGION=us-east-1  # Bedrockが利用可能なリージョン
   export AWS_PROFILE=cline   # 使用するAWSプロファイル名
   ```

## 動作確認

セットアップの確認：

1. Code Server を開く
2. Cline 拡張機能が正しく読み込まれていることを確認
   - サイドバーに Cline アイコンが表示されていることを確認
3. 簡単な Cline コマンドを実行して環境をテスト
   - 新しいファイルを作成し、Cline に簡単な質問を投げかけてレスポンスを確認

## トラブルシューティング

問題が発生した場合の確認事項：

1. AWS 認証情報の確認
   - `~/.aws/credentials` ファイルの内容が正しいか
   - 環境変数 `AWS_REGION` と `AWS_PROFILE` が正しく設定されているか

2. ネットワーク接続の確認
   - AWS APIへの接続が可能か
   - プロキシ設定が必要な場合は正しく設定されているか

3. 権限の確認
   - IAM ポリシーが正しく付与されているか
   - Bedrock モデルへのアクセスが承認されているか

4. Code Server のログ確認
   - エラーメッセージの有無
   - 拡張機能の正常な読み込み状態

## 参考リソース

- [AWS CDK ドキュメント](https://docs.aws.amazon.com/ja_jp/cdk/latest/guide/home.html)
- [SageMaker Studio ドキュメント](https://docs.aws.amazon.com/ja_jp/sagemaker/latest/dg/studio.html)
- [Code Server ドキュメント](https://coder.com/docs/code-server/latest)
- [Amazon Bedrock 開発者ガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)