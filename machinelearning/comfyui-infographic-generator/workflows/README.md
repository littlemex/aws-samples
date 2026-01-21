# ComfyUI Workflow Templates

このディレクトリには、インフォグラフィック生成用のComfyUIワークフローテンプレートが含まれます。

## 📋 ワークフロー作成ガイド

### GPU環境で作成するワークフロー

以下のワークフローは、GPU環境のComfyUIで作成する必要があります：

1. **basic-infographic.json** - 基本的なSDXLインフォグラフィック生成
2. **controlnet-canny.json** - Cannyエッジ検出を使用した制御生成
3. **controlnet-scribble.json** - スケッチベースの制御生成
4. **high-resolution.json** - 高解像度(2048x2048)生成
5. **flux-infographic.json** - FLUX.1ベースの高品質生成

---

## 🎨 ワークフロー1: 基本的なインフォグラフィック

**ファイル名:** `basic-infographic.json`

**概要:**
SDXL Baseモデルを使用した標準的なインフォグラフィック生成ワークフロー

**必要なモデル:**
- `sd_xl_base_1.0.safetensors`
- `sdxl_vae.safetensors`

**ノード構成:**

```
1. Load Checkpoint
   └─> SDXL Base 1.0

2. CLIP Text Encode (Positive)
   └─> プロンプト入力

3. CLIP Text Encode (Negative)
   └─> ネガティブプロンプト

4. Empty Latent Image
   └─> 1024x1024

5. KSampler
   ├─ steps: 25
   ├─ cfg: 7.5
   ├─ sampler_name: dpmpp_2m_karras
   └─ scheduler: karras

6. VAE Decode
   └─> SDXL VAE

7. Save Image
```

**推奨パラメータ:**
- 解像度: 1024x1024
- Steps: 25-30
- CFG Scale: 7.0-8.0
- Sampler: dpmpp_2m_karras
- Scheduler: karras

**サンプルプロンプト:**
```
professional infographic, machine learning pipeline visualization,
clean modern design, minimalist style, flowchart with labeled steps,
blue and white color scheme, flat design, sharp details, 4k quality
```

---

## 🖼️ ワークフロー2: ControlNet Canny

**ファイル名:** `controlnet-canny.json`

**概要:**
Cannyエッジ検出でレイアウトを制御しながら生成

**必要なモデル:**
- `sd_xl_base_1.0.safetensors`
- `sdxl_vae.safetensors`
- `controlnet-canny-sdxl-1.0.safetensors`

**ノード構成:**

```
1. Load Image
   └─> 入力画像 (スケッチ/ワイヤーフレーム)

2. Canny Edge Detection (Preprocessor)
   ├─ low_threshold: 100
   └─ high_threshold: 200

3. Load ControlNet Model
   └─> ControlNet Canny

4. Apply ControlNet
   ├─ strength: 0.8-1.0
   ├─ start_percent: 0.0
   └─ end_percent: 1.0

5. Load Checkpoint
   └─> SDXL Base 1.0

6. CLIP Text Encode (Positive + Negative)

7. KSampler (with ControlNet conditioning)

8. VAE Decode → Save Image
```

**使用方法:**
1. 手書きスケッチまたはワイヤーフレームを準備
2. `input/` フォルダに配置
3. ワークフローで画像を読み込み
4. プロンプトでスタイルを指定
5. 生成実行

**推奨パラメータ:**
- ControlNet Strength: 0.8-1.0
- Steps: 30
- CFG: 7.5-8.5

---

## ✏️ ワークフロー3: ControlNet Scribble

**ファイル名:** `controlnet-scribble.json`

**概要:**
ラフスケッチから高品質なインフォグラフィックを生成

**必要なモデル:**
- `sd_xl_base_1.0.safetensors`
- `sdxl_vae.safetensors`
- `controlnet-scribble-sdxl-1.0.safetensors`

**特徴:**
- Cannyよりも自由な解釈
- 手書き風スケッチに最適
- より創造的な出力

**推奨パラメータ:**
- ControlNet Strength: 0.6-0.9
- Steps: 25-30
- CFG: 7.0-8.0

---

## 🔍 ワークフロー4: 高解像度生成

**ファイル名:** `high-resolution.json`

**概要:**
PowerPoint/プレゼンテーション用の高解像度出力

**必要なモデル:**
- `sd_xl_base_1.0.safetensors`
- `sd_xl_refiner_1.0.safetensors` (オプション)
- `sdxl_vae.safetensors`
- `RealESRGAN_x4plus.pth` (オプション: アップスケール用)

**ノード構成:**

```
1. SDXL Base生成 (1024x1024 → Latent)

2. SDXL Refiner (オプション)
   ├─ Latent入力
   ├─ Steps: 10-15
   └─ Denoise: 0.3-0.5

3. VAE Decode → 1024x1024 image

4. Upscale Image (with Model)
   ├─ Model: RealESRGAN_x4plus
   └─ Output: 4096x4096

5. Downscale to 2048x2048

6. Save Image
```

**推奨パラメータ:**
- Base Steps: 30-35
- Refiner Steps: 10-15
- CFG: 8.0
- 最終解像度: 2048x2048

---

## ⚡ ワークフロー5: FLUX高品質生成

**ファイル名:** `flux-infographic.json`

**概要:**
FLUX.1 schnellモデルによる最高品質の生成

**必要なモデル:**
- `flux1-schnell.safetensors`
- `t5xxl_fp16.safetensors`
- `clip_l.safetensors`
- `ae.safetensors` (FLUX VAE)

**ノード構成:**

```
1. Load Diffusion Model
   └─> FLUX.1 schnell

2. Load CLIP
   ├─> clip_l
   └─> t5xxl_fp16

3. CLIP Text Encode

4. Empty Latent Image
   └─> 1024x1024

5. KSampler
   ├─ steps: 4-8 (schnellは高速)
   ├─ cfg: 1.0-3.5
   ├─ sampler_name: euler
   └─ scheduler: simple

6. VAE Decode
   └─> FLUX VAE

7. Save Image
```

**特徴:**
- 最高品質の出力
- 優れたテキストレンダリング
- 少ないstepsで高品質 (4-8 steps)

**推奨パラメータ:**
- Steps: 4-8
- CFG: 1.0-3.5 (低めが推奨)
- Sampler: euler
- Scheduler: simple

---

## 🛠️ ワークフロー作成手順

### GPU環境での作成方法

1. **ComfyUIを起動**
   ```bash
   cd ~/ComfyUI
   source ~/comfyui-env/bin/activate
   python main.py --listen 0.0.0.0 --port 8188
   ```

2. **ブラウザでアクセス**
   ```
   http://<GPU-instance-ip>:8188
   ```

3. **ワークフローを構築**
   - 上記のノード構成を参考にノードを配置
   - モデルを選択
   - パラメータを設定

4. **テスト生成**
   - サンプルプロンプトで動作確認
   - パラメータを調整

5. **ワークフローを保存**
   - 右上の "Save" → "Save (API Format)" でJSON出力
   - ファイル名: 上記の推奨名
   - 保存先: このディレクトリ

6. **Git コミット**
   ```bash
   cd ~/aws-samples/machinelearning/comfyui-infographic-generator
   git add workflows/*.json
   git commit -m "Add ComfyUI workflow templates"
   ```

---

## 📝 ワークフローカスタマイズガイド

### プロンプトの変更

各ワークフローの「CLIP Text Encode」ノードでプロンプトを変更できます。

**テンプレートを使用:**
```bash
# プロンプトファイルから読み込み
cat ../prompts/templates/ddds-style.txt
```

### パラメータ調整

**生成速度を優先:**
- Steps: 20-25
- CFG: 7.0
- Sampler: euler_a

**品質を優先:**
- Steps: 30-40
- CFG: 8.0-9.0
- Sampler: dpmpp_2m_karras

**バランス型:**
- Steps: 25-30
- CFG: 7.5-8.0
- Sampler: dpmpp_2m_karras

### ControlNet強度調整

- **0.6-0.7**: ゆるい制御、創造的
- **0.8-0.9**: バランス（推奨）
- **1.0**: 厳密な制御、レイアウト保持

---

## 🔗 関連リソース

- [ComfyUI Examples](https://comfyanonymous.github.io/ComfyUI_examples/)
- [Workflow Sharing Community](https://openart.ai/workflows)
- [ControlNet Guide](https://stable-diffusion-art.com/controlnet/)

---

## ⚠️ 注意事項

1. **ワークフローJSONはGPU環境で作成**
   CPU環境では動作テストができないため、必ずGPU instanceで作成・テストしてください。

2. **モデルパスの確認**
   ワークフロー内のモデルパスが環境に合っているか確認してください。

3. **バージョン互換性**
   ComfyUIのバージョンによってノードの仕様が変わる可能性があります。

4. **バックアップ**
   動作確認済みのワークフローは必ずgitにコミットしてください。

---

作成日: 2026-01-21
