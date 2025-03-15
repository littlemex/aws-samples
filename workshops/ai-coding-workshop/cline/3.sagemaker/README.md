# SageMaker Custom Model Workshop

このワークショップでは、SageMaker 上にカスタムモデル（Llama-3.3-Swallow-70B）をデプロイし、LiteLLM Proxy を通じて利用する方法を学びます。

注意：現状、SageMaker Endpoint 自体は動作しますが、LiteLLM 経由での利用がエラーしてしまいます。調査中

## 概要

- SageMaker エンドポイントとして Llama-3.3-Swallow-70B モデルをデプロイ
- LiteLLM Proxy で SageMaker エンドポイントを統合
- Cline からの利用設定

## 環境要件

- AWS CLI 設定済み（~/.aws/credentials）
- Python 3.9 以上
- uv（Python パッケージマネージャー）
- Docker 環境（LiteLLM Proxy 用）

## セットアップ手順

### 1. SageMaker エンドポイントのデプロイ

```bash
# Python 仮想環境の作成と依存関係のインストール
uv venv
uv sync

# モデルのデプロイ
uv run scripts/deploy_llama.py \
  --endpoint-name llama-3-3-swallow-70b-q4bit \
  --instance-type ml.g5.12xlarge
```

デプロイ時の主な設定:
- モデル: tokyotech-llm/Llama-3.3-Swallow-70B-v0.4
- インスタンスタイプ: ml.g5.12xlarge（4 GPU）
- インスタンス数: 1

### 2. デプロイしたモデルのテスト

単一のプロンプトでテスト:
```bash
uv run scripts/query_llama.py \
  --endpoint-name llama-3-3-swallow-70b-q4bit \
  --prompt "こんにちは、あなたは誰ですか？" \
  --region us-east-1
```

対話形式でテスト:
```bash
python scripts/chat_llama.py \
  --endpoint-name llama-3-3-swallow-70b-q4bit \
  --region us-east-1
```

### 3. LiteLLM Proxy の設定

`default_config.yaml` で以下の設定が可能です：

- モデルの優先順位とフォールバック設定
- 各モデルの最大トークン数
- リトライ設定
- レート制限

### 4. LiteLLM Proxy の起動

```bash
./start.sh
```

### 5. LiteLLM Proxy の動作確認

モデル一覧の取得:
```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}"
```

補完リクエストのテスト:
```bash
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -d '{
    "model": "swallow-llama",
    "messages": [
      {
        "role": "user",
        "content": "what llm are you"
      }
    ]
  }'
```

## Cline との統合

1. Cline の設定画面を開く
2. API Provider として「LiteLLM」を選択
3. 以下の設定を行う:
   - API Key: 環境変数 `LITELLM_MASTER_KEY` で設定した値
   - Base URL: `http://localhost:4000`

![Cline での LiteLLM 設定](images/cline-litellm.png)

これにより、Cline からのリクエストが LiteLLM Proxy を経由して SageMaker エンドポイントに転送され、エラー発生時には自動的にフォールバックする構成となります。
