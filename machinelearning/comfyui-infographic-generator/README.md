# ComfyUI Infographic Generator

AWS GPU インスタンス上で動作する、高品質なインフォグラフィック生成環境です。Stable Diffusion XL / FLUX + ControlNet + LoRA を使用して、PowerPoint で使用できるプロフェッショナルな図を生成します。

## 📋 概要

このプロジェクトは、「Daily Dose of Data Science」や「nano banana」のような高品質なアーキテクチャ図・インフォグラフィックを、完全にオープンソースのツールチェーンで生成することを目的としています。

### 特徴

✅ **完全OSS** - プロプライエタリサービス不要
✅ **高品質出力** - PowerPoint/プレゼンテーション向け
✅ **ControlNet対応** - レイアウト制御可能
✅ **GPU最適化** - AWS G5/G6インスタンス対応
✅ **自動セットアップ** - スクリプト一発で環境構築
✅ **プロンプトテンプレート** - すぐに使える高品質プロンプト集

## 🏗️ アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│  AWS EC2 GPU Instance (G5/G6)                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │  ComfyUI Server (Port 8188)                       │  │
│  │  ├─ SDXL Base / FLUX.1                            │  │
│  │  ├─ ControlNet (Canny, Depth, Scribble)          │  │
│  │  ├─ Custom LoRA Models                            │  │
│  │  └─ Workflow Templates                            │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  Models: ~/ComfyUI/models/                              │
│  ├─ checkpoints/  (SDXL, FLUX)                          │
│  ├─ controlnet/   (Canny, Depth, Scribble)              │
│  ├─ vae/          (VAE models)                           │
│  └─ loras/        (Style LoRAs)                          │
└─────────────────────────────────────────────────────────┘
```

## 🚀 クイックスタート

### 前提条件

- AWS GPU インスタンス (G5.xlarge または G6.xlarge 推奨)
- Ubuntu 24.04 + NVIDIA Driver + PyTorch (Deep Learning AMI)
- 200GB以上のディスク容量
- インターネット接続

### インストール手順

```bash
# 1. リポジトリに移動
cd ~/aws-samples/machinelearning/comfyui-infographic-generator

# 2. ComfyUI をインストール
./scripts/install-comfyui.sh

# 3. モデルをダウンロード（対話式メニュー）
./scripts/download-models.sh

# 4. 環境を検証
./tests/validate-setup.sh

# 5. ComfyUI を起動
source ~/.comfyui_activate
comfyui
```

### 初回生成

1. ブラウザで `http://<instance-ip>:8188` にアクセス
2. ワークフローをロード (workflows/ から選択)
3. プロンプトを入力 (prompts/templates/ を参照)
4. "Queue Prompt" をクリックして生成開始

## 📁 プロジェクト構造

```
comfyui-infographic-generator/
├── README.md                    # このファイル
├── docs/
│   ├── SETUP.md                 # 詳細セットアップガイド
│   ├── TROUBLESHOOTING.md       # トラブルシューティング
│   └── WORKFLOWS.md             # ワークフロー作成ガイド
├── scripts/
│   ├── install-comfyui.sh       # ComfyUI自動インストール
│   └── download-models.sh       # モデル自動ダウンロード
├── workflows/
│   ├── README.md                # ワークフロー説明
│   ├── basic-infographic.json   # 基本ワークフロー（GPU環境で作成）
│   ├── controlnet-canny.json    # Canny制御
│   ├── controlnet-scribble.json # Scribble制御
│   ├── high-resolution.json     # 高解像度生成
│   └── flux-infographic.json    # FLUX高品質
├── prompts/
│   ├── PROMPT_GUIDE.md          # プロンプト作成ガイド
│   ├── templates/
│   │   ├── minimalist.txt       # ミニマリストスタイル
│   │   ├── ddds-style.txt       # Daily Dose of DS風
│   │   ├── technical-diagram.txt # テクニカル図
│   │   └── architecture-diagram.txt # アーキテクチャ図
│   └── negative-prompts.txt     # ネガティブプロンプト
├── examples/
│   ├── input/                   # サンプル入力画像
│   ├── output/                  # サンプル出力例
│   └── sketches/                # ControlNet用スケッチ
└── tests/
    └── validate-setup.sh        # 環境検証スクリプト
```

## 🎨 使用例

### 1. 基本的なインフォグラフィック

```bash
# プロンプト例（minimalist style）
professional infographic, machine learning pipeline visualization,
clean modern design, minimalist style, flowchart with labeled steps,
blue and white color scheme, flat design, sharp details, 4k quality
```

**生成時間:** 約 15-20秒 (1024x1024, SDXL)

### 2. ControlNet でレイアウト制御

```bash
# 手書きスケッチから生成
1. スケッチを ~/ComfyUI/input/ に配置
2. controlnet-canny.json ワークフローをロード
3. プロンプトでスタイル指定
4. 生成実行
```

**生成時間:** 約 25-30秒 (1024x1024, SDXL + ControlNet)

### 3. 高解像度プレゼンテーション用

```bash
# 2048x2048 高品質出力
1. high-resolution.json ワークフローをロード
2. SDXL Base + Refiner を使用
3. Steps: 30-35
4. 生成後、必要に応じてアップスケール
```

**生成時間:** 約 45-60秒 (2048x2048)

## 💰 コスト見積もり

### AWS EC2 料金 (us-east-1)

| インスタンス | GPU | VRAM | オンデマンド | スポット | 推奨用途 |
|-------------|-----|------|-------------|---------|----------|
| g5.xlarge | A10G | 24GB | $1.006/時 | $0.30-0.50/時 | 開発・テスト |
| g6.xlarge | L4 | 24GB | $0.868/時 | $0.26-0.45/時 | 推論最適化 |

### 月間コスト例

**開発環境（スポットインスタンス、40時間/月）:**
- インスタンス: $15-20
- ストレージ (200GB EBS): $16
- **合計: 約 $31-36/月**

**本番環境（オンデマンド、160時間/月）:**
- インスタンス: $160-180
- ストレージ: $20
- **合計: 約 $180-200/月**

## ⚙️ 技術スタック

### インフラ
- **クラウド:** AWS EC2
- **インスタンス:** G5/G6 (NVIDIA A10G / L4 GPU)
- **OS:** Ubuntu 24.04 LTS (Deep Learning AMI)
- **ストレージ:** 200GB EBS gp3

### AI/MLスタック
- **フレームワーク:** PyTorch 2.1+
- **CUDA:** 12.1+
- **インターフェース:** ComfyUI
- **ベースモデル:**
  - Stable Diffusion XL 1.0 (安定性重視)
  - FLUX.1 schnell (品質重視、商用可)

### 拡張機能
- **ControlNet:** Canny, Depth, Scribble
- **ComfyUI Manager:** カスタムノード管理
- **ControlNet Preprocessors:** 前処理ツール

## 📊 パフォーマンス

### 生成速度 (G5.xlarge, A10G 24GB)

| モデル | 解像度 | Steps | 生成時間 |
|--------|--------|-------|----------|
| SDXL Base | 1024x1024 | 25 | 15-20秒 |
| SDXL Base | 2048x2048 | 30 | 45-60秒 |
| SDXL + ControlNet | 1024x1024 | 25 | 25-30秒 |
| FLUX.1 schnell | 1024x1024 | 4-8 | 8-12秒 |

### VRAM 使用量

| 構成 | VRAM使用量 |
|------|-----------|
| SDXL Base (1024x1024) | 8-10GB |
| SDXL Base (2048x2048) | 14-18GB |
| FLUX.1 (1024x1024) | 12-16GB |
| ControlNet 追加 | +2-3GB |

## 📚 ドキュメント

- **[セットアップガイド](docs/SETUP.md)** - 詳細なインストール手順
- **[ワークフローガイド](docs/WORKFLOWS.md)** - ワークフロー作成方法
- **[プロンプトガイド](prompts/PROMPT_GUIDE.md)** - 効果的なプロンプト作成
- **[トラブルシューティング](docs/TROUBLESHOOTING.md)** - よくある問題と解決策

## 🔧 トラブルシューティング

### GPU が認識されない

```bash
# GPU確認
nvidia-smi

# PyTorchでGPU確認
python3 -c "import torch; print(torch.cuda.is_available())"

# ドライバ再インストール（必要な場合）
sudo apt install nvidia-driver-535
sudo reboot
```

### VRAM 不足エラー

```bash
# 解像度を下げる: 2048 → 1024
# または低VRAMモードで起動
python main.py --lowvram --listen 0.0.0.0 --port 8188
```

### 生成が遅い

```bash
# 最適化オプション
python main.py --use-xformers --listen 0.0.0.0 --port 8188

# Stepsを減らす: 30 → 20
# Samplerを変更: dpmpp_2m_karras が高速
```

詳細は [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) を参照

## 🤝 貢献

プルリクエスト歓迎！以下の改善を募集中：

- 新しいワークフローテンプレート
- プロンプトテンプレートの追加
- LoRAモデルの推奨
- ドキュメントの改善
- バグ修正

## 📄 ライセンス

### プロジェクトコード
このリポジトリのスクリプトとドキュメントは MIT License

### 使用モデルのライセンス

| モデル | ライセンス | 商用利用 |
|--------|-----------|---------|
| SDXL 1.0 | CreativeML Open RAIL-M | ✅ 可能 |
| FLUX.1 schnell | Apache 2.0 | ✅ 可能 |
| FLUX.1 dev | 非商用 | ❌ 不可 |
| ControlNet | Apache 2.0 | ✅ 可能 |
| ComfyUI | GPL-3.0 | ✅ 可能 |

詳細は各モデルの公式ライセンスを確認してください。

## 🔗 関連リソース

### 公式ドキュメント
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [Stable Diffusion XL](https://github.com/Stability-AI/generative-models)
- [FLUX.1](https://github.com/black-forest-labs/flux)
- [ControlNet](https://github.com/lllyasviel/ControlNet)

### コミュニティ
- [ComfyUI Discord](https://discord.gg/comfyui)
- [r/StableDiffusion](https://reddit.com/r/StableDiffusion)
- [Civitai](https://civitai.com/) - LoRAモデル共有

### 学習リソース
- [Prompt Engineering Guide](https://github.com/dair-ai/Prompt-Engineering-Guide)
- [ComfyUI Examples](https://comfyanonymous.github.io/ComfyUI_examples/)
- [ControlNet Paper](https://arxiv.org/abs/2302.05543)

## 📧 サポート

問題が発生した場合：

1. [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) を確認
2. [GitHub Issues](../../issues) で検索
3. 新しいIssueを作成（テンプレートに従って記載）

---

**作成日:** 2026-01-21
**バージョン:** 1.0.0
**ステータス:** Production Ready (ワークフローJSONはGPU環境で作成が必要)

**Happy Generating! 🎨✨**
