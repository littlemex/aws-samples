# Wren AI スクリプト

このディレクトリには Wren AI プロジェクト用のユーティリティスクリプトが含まれています。

## AWS Bedrock モデルバリデーター

AWS Bedrock モデルバリデーターは、Wren AI の設定ファイルで指定された AWS Bedrock モデルが AWS アカウントで適切に有効化されアクセス可能かどうかを確認するツールです。

### ファイル

- `model_validator.py`: AWS Bedrock モデルを検証する Python スクリプト
- `validate_models.sh`: Python バリデーターのシェルスクリプトラッパー
- `docker-entrypoint.sh`: サービス起動前にモデルを検証する Docker エントリーポイントスクリプト
- `test_validator.py`: バリデーターをテストするためのスクリプト

### 使用方法

#### スタンドアロン検証

Python スクリプトを直接使用してモデルを検証する方法:

```bash
./model_validator.py --config /path/to/config.yaml [--region us-east-1] [--verbose]
```

シェルスクリプトラッパーを使用する方法:

```bash
./validate_models.sh [--config /path/to/config.yaml] [--region us-east-1] [--verbose]
```

テストスクリプトを使用してバリデーターをテストする方法:

```bash
./test_validator.py [--region us-east-1] [--verbose]
```

#### Docker 統合

Docker エントリーポイントスクリプトを使用するには、Dockerfile を以下のように変更します:

```dockerfile
COPY scripts/model_validator.py /app/scripts/
COPY scripts/docker-entrypoint.sh /app/scripts/

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
CMD ["python", "-m", "your_service_module"]
```

そして docker-compose.yaml を更新してスクリプトディレクトリをマウントします:

```yaml
services:
  wren-ai-service:
    # ... その他の設定 ...
    volumes:
      - ./scripts:/app/scripts
    environment:
      # ... その他の環境変数 ...
      # オプション: 検証をスキップ
      # SKIP_MODEL_VALIDATION: "true"
      # オプション: 検証が失敗しても続行
      # CONTINUE_ON_VALIDATION_FAILURE: "true"
```

### 環境変数

Docker エントリーポイントスクリプトを使用する場合、以下の環境変数で動作を設定できます:

- `CONFIG_PATH`: config.yaml ファイルへのパス (デフォルト: "/app/data/config.yaml")
- `AWS_REGION_NAME`: 使用する AWS リージョン (デフォルト: "us-east-1")
- `SKIP_MODEL_VALIDATION`: "true" に設定するとモデル検証をスキップ (デフォルト: "false")
- `CONTINUE_ON_VALIDATION_FAILURE`: "true" に設定すると検証失敗でも続行 (デフォルト: "false")

### 終了コード

- `0`: すべてのモデルが正常に検証された
- `1`: 1つ以上のモデルが検証に失敗した

## モデル ID の正規化

LiteLLM で使用されるモデル ID 形式（例：`bedrock/converse/us.anthropic.claude-3-7-sonnet-20250219-v1:0`）は、AWS Bedrock API で使用される形式（例：`anthropic.claude-3-sonnet-20240229-v1`）と異なります。バリデーターは以下の変換を行います：

1. `bedrock/` プレフィックスを削除
2. `converse/` などの追加プレフィックスを削除
3. `us.` や `apac.` などのリージョンプレフィックスを削除
4. `:0` などのバージョンサフィックスを削除
5. 特定のモデル ID に対するマッピングを適用（例：新しいバージョンのモデル ID を現在利用可能なバージョンにマッピング）

## トラブルシューティング

検証に失敗した場合は、以下を確認してください:

1. AWS Bedrock コンソールでモデルが有効化されていることを確認:
   https://console.aws.amazon.com/bedrock/home#/modelaccess

2. IAM ロールに必要な権限があることを確認:
   - `bedrock:ListFoundationModels`
   - `bedrock:InvokeModel`

3. モデルが使用している AWS リージョンで利用可能であることを確認

4. AWS 認証情報が正しく設定されていることを確認

5. LiteLLM の設定で使用しているモデル ID が正しいことを確認:
   - バリデーターの出力に表示される「利用可能なモデル」リストを参照
   - 類似モデルの提案を確認
