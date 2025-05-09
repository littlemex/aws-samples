# Langfuse 実装詳細

本ドキュメントは実装詳細を解説するための資料であり、Langfuse の概要やワークショップのマニュアルは [manuals](../manuals/README.md) をご確認ください。
Langfuse ワークショップは[こちら](../manuals/workshops/langfuse.md)。

## スクリプト

Langfuse の起動等を行うスクリプトです。
詳細な使い方はヘルプを確認してください。
スクリプトの実行には必ず `.env` が必要なため、`.env.example` をコピーしてください。

`../scripts/setup_env.sh` は ~/.aws/credentials の設定を確認して .env を設定するスクリプトです。
説明をせずともコードを見て何をしているのか分かる方のみ利用してください。

```bash
# サービスの起動
./manage-langfuse.sh start

# サービスの停止
./manage-langfuse.sh stop

# サービスの再起動
./manage-langfuse.sh restart

# LiteLLM Proxy の設定更新と再起動
./manage-langfuse.sh update-config

# ヘルプの表示
./manage-langfuse.sh --help
```

## Langfuse 動作確認

以下のデバッグツールについてはコードを確認して自身で理解できる方のみが利用してください。


### デバッグツール

`../scripts/debug_langfuse.sh` スクリプトを使用してトラブルシューティングを行えます：

```bash
bash -x ../scripts/debug_langfuse.sh
```

このスクリプトは以下を確認します：
- Langfuse と LiteLLM コンテナの状態
- 環境変数の設定
- コンテナのログ
- ネットワーク接続状態

### テストの実行

まず、scripts ディレクトリで Python 環境をセットアップします：

```bash
# mise で uv がインストール済みの前提
cd ../scripts
uv venv && source .venv/bin/activate && uv sync
cd ../4.langfuse
```

その後、テストを実行します：

```bash
python test_litellm_langfuse.py

# ERROR - Unexpected error occurred. Please check your request and contact support: https://langfuse.com/support. このようなワーニングが出ることがありますが、既知の Langfuse のバグのため動作に問題はありません。https://github.com/orgs/langfuse/discussions/6194
```

テストスクリプトは以下を実行します：
- LiteLLM を通じた Amazon Bedrock の呼び出し
- Langfuse へのログ送信
- 接続テストとデバッグ情報の出力

## 設定ファイルの切り替え

スクリプトでは `-c` オプションを使用して異なる設定ファイルを指定できます。

```bash
# 例
./manage-langfuse.sh -c prompt_caching.yml update-config
```

## ネットワーク構成

### コンテナネットワーク
- すべてのサービスは `langfuse_default` ネットワーク内で実行
- コンテナ間通信には Docker DNS 名を使用（例：`langfuse-web`、`postgres`）
- 内部ポートはネットワーク内で公開

### 重要な注意点
- コンテナ内では `localhost` は自身のコンテナを指すため、使用を避ける
- 代わりに Docker サービス名を使用（例：`http://langfuse-web:3000`）
- MinIO は 9000 ポートを使用