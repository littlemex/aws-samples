# Background Removal API Service

このプロジェクトは、画像から背景を自動的に削除するAPIサービスを提供します。[rembg](https://github.com/danielgatis/rembg)ライブラリを使用して、機械学習モデルによる高精度な背景除去を実現しています。

## 機能

- 画像から背景を自動的に削除
- 複数の背景除去モデルをサポート
- RESTful APIインターフェース
- Dockerコンテナ対応

## 必要要件

- Python 3.9以上
- Docker（コンテナ実行時）

## 利用可能なモデル

プロジェクトには以下のモデルが含まれています：

- u2net.onnx (デフォルト): 汎用的な背景除去
- u2netp.onnx: 軽量版の汎用モデル
- isnet-general-use.onnx: 一般用途向け
- isnet-anime.onnx: アニメ画像に特化

## セットアップ

### Dockerを使用する場合

1. リポジトリをクローン
```bash
git clone <repository-url>
cd rembg-serving
```

2. Dockerイメージをビルド
```bash
docker build -t rembg-serving .
```

3. コンテナを実行
```bash
docker run -p 8000:8000 -v $(pwd)/models:/app/models rembg-serving
```

### ローカル環境で実行する場合

1. 依存関係をインストール
```bash
pip install uv
uv sync
```

2. サーバーを起動
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## APIの使用方法

### 背景除去 API

**エンドポイント**: `/remove-background`

**メソッド**: POST

**パラメータ**:
- `file`: 画像ファイル（必須、multipart/form-data）
- `model`: 使用するモデル名（オプション、デフォルト: "u2net"）

**curlコマンドの例**:

post.sh を利用可能です。

```bash
# 基本的な使用方法
curl -X POST \
  http://localhost:8000/remove-background \
  -F "file=@画像ファイルのパス" \
  -o output.png

# モデルを指定する場合
curl -X POST \
  http://localhost:8000/remove-background \
  -F "file=@画像ファイルのパス" \
  -F "model=isnet-anime" \
  -o output.png
```

### ヘルスチェック API

**エンドポイント**: `/health`

**メソッド**: GET

**curlコマンドの例**:
```bash
curl http://localhost:8000/health
```

## プロジェクト構造

```
.
├── app/
│   └── main.py          # メインアプリケーションコード
├── models/              # 背景除去モデル
│   ├── u2net.onnx
│   ├── u2netp.onnx
│   ├── isnet-general-use.onnx
│   └── isnet-anime.onnx
├── examples/            # サンプル画像
├── outputs/             # 出力画像の保存先
├── Dockerfile          # Dockerビルド設定
└── pyproject.toml      # プロジェクト依存関係
```

## 主な依存関係

- fastapi: WebフレームワークとAPIの構築
- rembg: 背景除去の実装
- onnxruntime: 機械学習モデルの実行
- uvicorn: ASGIサーバー
- gunicorn: プロダクション用WSGIサーバー