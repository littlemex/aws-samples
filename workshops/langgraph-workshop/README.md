# Amazon Bedrock を使用した LangGraph エージェント

Original: https://github.com/aws-samples/langgraph-agents-with-amazon-bedrock/blob/main/README.md の日本語翻訳版です。（個人利用用途）

> uv 利用に変更するなど一部改変

このリポジトリは、[Harrison Chase](https://www.linkedin.com/in/harrison-chase-961287118)（[LangChain](https://www.langchain.com/) の共同創設者兼CEO）と [Rotem Weiss](https://www.linkedin.com/in/rotem-weiss)（[Tavily](https://tavily.com/) の共同創設者兼CEO）によって作成され、[DeepLearning.AI](https://www.deeplearning.ai/) でホストされている [LangGraph における AI エージェント](https://www.deeplearning.ai/short-courses/ai-agents-in-langgraph/) コースから適応されたワークショップを含んでいます。
オリジナルのコンテンツは著者の同意を得て使用されています。

スムーズな体験を確保するために、資料に取り組む前にこの README を読み、指示に従ってください。

## 概要

このワークショップでは：
- 関数呼び出し LLM やエージェント検索などの特殊ツールの改善を活用した、AI エージェントとエージェンティックワークフローの最新の進歩を探求します
- LangChain のエージェンティックワークフローに対する更新されたサポートを活用し、複雑なエージェント動作を構築するための拡張機能である LangGraph を紹介します
- エージェンティックワークフローにおける重要な設計パターン（*計画、ツールの使用、振り返り、マルチエージェントコミュニケーション、メモリ*）に関する洞察を提供します

資料は 6 つの Jupyter Notebook ラボに分かれており、LangGraph フレームワーク、その基礎概念、および Amazon Bedrock での使用方法を理解するのに役立ちます：

- Lab 1: [一から ReAct エージェントを構築する](Lab_1/)
    - Python と LLM を使用して基本的な ReAct エージェントを一から構築し、ツールの使用と観察を通じてタスクを解決するための推論と行動のループを実装します
- Lab 2: [LangGraph コンポーネント](Lab_2/)
    - 循環グラフを使用してエージェントを実装するためのツールである LangGraph の紹介。ノード、エッジ、状態管理などのコンポーネントを使用して、より構造化され制御可能なエージェントを作成する方法を示します
- Lab 3: [エージェンティック検索ツール](Lab_3/)
    - エージェンティック検索ツールの紹介。動的ソースから構造化された関連データを提供することで AI エージェントの能力を強化し、精度を向上させ、幻覚を減らします
- Lab 4: [永続性とストリーミング](Lab_4/)
    - 永続性とストリーミングは長時間実行されるエージェントタスクに不可欠であり、状態の保存、会話の再開、エージェントのアクションと出力のリアルタイム可視性を可能にします
- Lab 5: [ヒューマン・イン・ザ・ループ](Lab_5/)
    - LangGraph における高度なヒューマン・イン・ザ・ループ相互作用パターン。休憩の追加、状態の変更、タイムトラベル、AI エージェントとのより良い制御と相互作用のための手動状態更新を含みます
- Lab 6: [エッセイライター](Lab_6/)
    - 計画、研究、執筆、振り返り、修正を含む多段階プロセスを使用して AI エッセイライターを構築し、相互接続されたエージェントのグラフとして実装します

LangGraph を初めて使用する場合は、詳細なビデオ説明については [オリジナルコース](https://www.deeplearning.ai/short-courses/ai-agents-in-langgraph/) を参照することをお勧めします。

環境のセットアップから始めましょう。

## 仮想環境のセットアップ

### 前提

- uv を導入済み

### 1. 仮想環境の作成と Python 依存関係のインストール

```
# プロジェクトディレクトリ pyproject.toml のあるディレクトリ上
uv venv && source .venv/bin/activate
uv sync
```

### 2. Jupyter Notebook サーバーにカーネルを追加する
新しく作成された Python 環境を Jupyter Notebook サーバーの利用可能なカーネルのリストに追加する必要があります。

```
uv pip install ipykernel
ipython kernel install --user --name=agents-dev-env
```
カーネルがリストにすぐに表示されない場合は、リストの更新が必要になります。

### 3. Tavily API キーの作成と設定

https://app.tavily.com/home にアクセスして、無料で API キーを作成してください。

### 6. ローカル環境変数の設定

一時環境ファイル [env.tmp](env.tmp) の個人用コピーを `.env` という名前で作成します。これは個人情報をコミットしないように [.gitignore](.gitignore) に既に追加されています。
```
cp env.tmp .env
```
必要に応じて、`.env` ファイル内で Amazon Bedrock を使用する優先リージョンを編集できます（デフォルトは `us-east-1` です）。

### 7. Tavily API キーの保存
Tavily API キーを保存するには 2 つのオプションがあります：

1. Tavily API キーを `.env` ファイル内にコピーします。このオプションが常に最初にチェックされます。

2. "TAVILY_API_KEY" という名前で [AWS Secrets Manager に新しいシークレットを作成](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html) し、クリックしてシークレット `arn` を取得し、[シークレットを読み取る権限](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples.html#auth-and-access_examples_read) を持つ [インラインポリシーを追加](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_manage-attach-detach.html#add-policies-console) して、以下の例でコピーした `arn` を置き換えて [SageMaker 実行ロール](https://docs.aws.amazon.com/sagemaker/latest/dg/domain-user-profile-view-describe.html) に追加します。
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "arn:aws:secretsmanager:<Region>:<AccountId>:secret:SecretName-6RandomCharacters"
        }
    ]
}
```

これで準備完了です！各ノートブックに対して新しく作成した `agents-dev-env` カーネルを選択してください。

# 追加リソース

- [Amazon Bedrock ユーザーガイド](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)
- [LangChain ドキュメント](https://python.langchain.com/v0.2/docs/introduction/)
- [LangGraph GitHub リポジトリ](https://github.com/langchain-ai/langgraph)
- [LangSmith Prompt hub](https://smith.langchain.com/hub)