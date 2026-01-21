# GPU環境での確認項目チェックリスト

このドキュメントは、GPU インスタンス上でComfyUI環境を構築・テストする際の確認項目をまとめたものです。

## 📋 実行前の準備

### ✅ インスタンス起動確認

- [ ] GPU インスタンス (G5/G6) が起動している
- [ ] SSH または code-server でアクセス可能
- [ ] インターネット接続が可能

### ✅ 基本環境確認

```bash
# OS バージョン確認
cat /etc/os-release

# ディスク容量確認 (200GB以上推奨)
df -h

# メモリ確認 (16GB以上推奨)
free -h
```

**期待される結果:**
- Ubuntu 22.04 または 24.04
- 利用可能容量 200GB 以上
- メモリ 16GB 以上

---

## 🎮 GPU 動作確認

### ✅ Step 1: NVIDIA ドライバ確認

```bash
nvidia-smi
```

**期待される出力:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.xx.xx    Driver Version: 535.xx.xx    CUDA Version: 12.2   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA A10G         On   | 00000000:00:1E.0 Off |                    0 |
|  0%   25C    P0    25W / 300W |      0MiB / 23028MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

**確認項目:**
- [ ] GPU名が表示される (A10G or L4)
- [ ] Driver Version が表示される
- [ ] CUDA Version が 12.0 以上
- [ ] メモリ容量が 22GB 以上 (24GB GPU)
- [ ] エラーメッセージがない

**トラブルシューティング:**
```bash
# ドライバが見つからない場合
sudo apt update
sudo apt install nvidia-driver-535
sudo reboot

# 再度確認
nvidia-smi
```

### ✅ Step 2: CUDA 動作確認

```bash
# CUDA コンパイラ確認
nvcc --version

# CUDA サンプル実行 (オプション)
cd /usr/local/cuda/samples/1_Utilities/deviceQuery
sudo make
./deviceQuery
```

**期待される結果:**
- CUDA Version 12.x が表示される
- deviceQuery が PASS と表示

---

## 🐍 Python 環境確認

### ✅ Step 3: Python と PyTorch 確認

```bash
# Python バージョン
python3 --version

# PyTorch インストール確認
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"

# CUDA サポート確認
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# CUDA デバイス情報
python3 -c "import torch; print(f'CUDA devices: {torch.cuda.device_count()}'); print(f'Device name: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

**期待される出力:**
```
Python 3.10.x または 3.11.x
PyTorch: 2.1.0+cu121
CUDA available: True
CUDA devices: 1
Device name: NVIDIA A10G
```

**確認項目:**
- [ ] Python 3.10 以上
- [ ] PyTorch が CUDA対応版
- [ ] `torch.cuda.is_available()` が True
- [ ] GPU デバイス名が正しく表示

---

## 🛠️ ComfyUI インストール確認

### ✅ Step 4: インストールスクリプト実行

```bash
cd ~/aws-samples/machinelearning/comfyui-infographic-generator

# インストール実行
./scripts/install-comfyui.sh
```

**監視ポイント:**
- [ ] スクリプトがエラーなく完了
- [ ] PyTorch のGPU版がインストールされる
- [ ] ComfyUI が ~/ComfyUI にクローンされる
- [ ] 仮想環境が ~/comfyui-env に作成される
- [ ] ComfyUI Manager がインストールされる
- [ ] ControlNet Preprocessors がインストールされる

**ログ確認:**
インストールログを保存しておくと後で便利
```bash
./scripts/install-comfyui.sh 2>&1 | tee install.log
```

### ✅ Step 5: 環境検証スクリプト実行

```bash
./tests/validate-setup.sh
```

**期待される結果:**
```
========================================
Validation Summary
========================================

Tests Passed:    XX
Tests Failed:    0
Warnings:        X

✓ All checks passed! Environment is ready.
```

**確認項目:**
- [ ] GPU 認識テスト PASS
- [ ] PyTorch CUDA テスト PASS
- [ ] ComfyUI ディレクトリ存在確認 PASS
- [ ] ディレクトリ構造確認 PASS
- [ ] Failed カウントが 0

---

## 📦 モデルダウンロード確認

### ✅ Step 6: モデルダウンロード実行

```bash
./scripts/download-models.sh
```

**推奨選択:**
- 初回テスト: Option 1 (SDXL Base のみ, ~7GB)
- 本格利用: Option 11 (SDXL + ControlNets + Upscale, ~28GB)
- 最高品質: Option 12 (FLUX + ControlNets + Upscale, ~57GB)

**ダウンロード監視:**
- [ ] ダウンロードが開始される
- [ ] Progress bar が表示される
- [ ] エラーメッセージがない
- [ ] ダウンロード完了メッセージが表示される

### ✅ Step 7: ダウンロード済みモデル確認

```bash
# モデル一覧表示
ls -lh ~/ComfyUI/models/checkpoints/
ls -lh ~/ComfyUI/models/vae/
ls -lh ~/ComfyUI/models/controlnet/

# ディスク使用量確認
du -sh ~/ComfyUI/models/
```

**確認項目:**
- [ ] checkpoints/ に .safetensors ファイルが存在
- [ ] vae/ に VAE モデルが存在
- [ ] ファイルサイズが正常 (SDXL: 6-7GB, FLUX: 20-24GB)
- [ ] ファイルが破損していない (ls でエラーが出ない)

---

## 🚀 ComfyUI 起動確認

### ✅ Step 8: ComfyUI サーバー起動

```bash
# 環境アクティベート
source ~/.comfyui_activate

# ComfyUI 起動
comfyui
```

または手動起動:
```bash
cd ~/ComfyUI
source ~/comfyui-env/bin/activate
python main.py --listen 0.0.0.0 --port 8188
```

**期待される起動ログ:**
```
Total VRAM 23028 MB, total RAM 15944 MB
pytorch version: 2.1.0+cu121
Set vram state to: NORMAL_VRAM
Device: cuda:0 NVIDIA A10G : cudaMallocAsync
VAE dtype: torch.bfloat16

Import times for custom nodes:
   0.0 seconds: /root/ComfyUI/custom_nodes/ComfyUI-Manager
   0.1 seconds: /root/ComfyUI/custom_nodes/comfyui_controlnet_aux

Starting server
To see the GUI go to: http://0.0.0.0:8188
```

**確認項目:**
- [ ] `Device: cuda:0` と表示される (GPU認識)
- [ ] VRAM サイズが正しく表示 (~23GB)
- [ ] エラーメッセージがない
- [ ] `Starting server` と表示される
- [ ] カスタムノードが読み込まれる

### ✅ Step 9: Web UI アクセス確認

```bash
# 別ターミナルまたはブラウザで確認
curl http://localhost:8188/

# ブラウザでアクセス
# http://<instance-ip>:8188
```

**ブラウザ確認項目:**
- [ ] ComfyUI UI が表示される
- [ ] 左側にノードメニューが表示される
- [ ] 右側に "Queue Prompt" ボタンがある
- [ ] エラーメッセージがない
- [ ] マウス操作で canvas が動く

---

## 🎨 画像生成テスト

### ✅ Step 10: シンプルな生成テスト

**UIで以下を実行:**

1. **ワークフロー構築:**
   - "Add Node" → "loaders" → "Load Checkpoint"
   - SDXL Base モデルを選択
   - 基本的なワークフロー構築 (Checkpoint → KSampler → VAE Decode → Save Image)

2. **プロンプト入力:**
   ```
   Positive: simple test image, blue square on white background
   Negative: complex, detailed
   ```

3. **パラメータ設定:**
   - Width: 512
   - Height: 512
   - Steps: 20
   - CFG: 7.0
   - Sampler: euler

4. **生成実行:**
   - "Queue Prompt" をクリック

**確認項目:**
- [ ] Queue にジョブが追加される
- [ ] GPU使用率が上昇する (nvidia-smi で確認)
- [ ] プログレスバーが進む
- [ ] 10-15秒程度で完了
- [ ] output/ フォルダに画像が保存される
- [ ] エラーメッセージがない

### ✅ Step 11: 生成画像確認

```bash
# 生成された画像確認
ls -lh ~/ComfyUI/output/

# 最新の画像を表示 (code-server経由の場合)
# または SCP でローカルにダウンロード
```

**確認項目:**
- [ ] 画像ファイルが存在する (.png)
- [ ] ファイルサイズが適切 (100KB-5MB程度)
- [ ] 画像が開ける (破損していない)
- [ ] 指定した解像度と一致

---

## 📊 パフォーマンステスト

### ✅ Step 12: 生成速度ベンチマーク

**テストケース:**

1. **低解像度テスト (512x512)**
   - Steps: 20
   - 期待時間: 5-10秒

2. **標準解像度テスト (1024x1024)**
   - Steps: 25
   - 期待時間: 15-20秒

3. **高解像度テスト (2048x2048)**
   - Steps: 30
   - 期待時間: 45-60秒

**VRAM 使用量確認:**
```bash
# 生成中に別ターミナルで実行
watch -n 1 nvidia-smi
```

**確認項目:**
- [ ] 生成時間が期待値内
- [ ] VRAM使用量が上限以下 (23GB以下)
- [ ] GPU使用率が高い (80-100%)
- [ ] メモリリークがない (複数回生成後も安定)

---

## 🔧 ワークフロー作成テスト

### ✅ Step 13: プロンプトテンプレート使用

```bash
# プロンプトテンプレート表示
cat ~/aws-samples/machinelearning/comfyui-infographic-generator/prompts/templates/minimalist.txt
```

**ComfyUI で実行:**
1. テンプレートのプロンプトをコピー
2. CLIP Text Encode (Positive) に貼り付け
3. ネガティブプロンプトも設定
4. 1024x1024, Steps 25 で生成

**期待される結果:**
- [ ] インフォグラフィック風の画像が生成される
- [ ] ミニマリストスタイルが適用される
- [ ] クリーンなデザイン
- [ ] 指定したカラースキームが反映

### ✅ Step 14: ControlNet テスト (オプション)

**前提条件:**
- ControlNet モデルがダウンロード済み
- テスト用の入力画像が準備済み

**テスト手順:**
1. ControlNet ノードを追加
2. Canny Preprocessor を設定
3. 入力画像をロード
4. プロンプトを設定して生成

**確認項目:**
- [ ] ControlNet ノードが正常動作
- [ ] エッジ検出が機能
- [ ] 入力画像のレイアウトが保持される
- [ ] VRAM が不足しない

---

## 📝 最終チェックリスト

### システム全体

- [ ] GPU が正常に認識・動作
- [ ] ComfyUI が起動し、Web UI にアクセス可能
- [ ] モデルが正常にロード
- [ ] 画像生成が正常に完了
- [ ] 生成速度が許容範囲内
- [ ] VRAM使用量が上限以下
- [ ] エラーログがない

### ファイル・ディレクトリ

- [ ] ~/ComfyUI/ が存在
- [ ] ~/comfyui-env/ が存在
- [ ] models/ 以下にモデルファイルが存在
- [ ] output/ に生成画像が保存される
- [ ] ~/.comfyui_activate が機能

### ドキュメント

- [ ] README.md を読んで理解
- [ ] プロンプトテンプレートを確認
- [ ] ワークフロー説明を確認

---

## 🎯 次のステップ

全ての確認項目が完了したら:

1. **ワークフローJSONを作成**
   - workflows/README.md の手順に従って作成
   - 最低3つのワークフローを作成推奨
   - Git にコミット

2. **プロンプトライブラリを拡張**
   - 独自のプロンプトテンプレートを追加
   - 成功したプロンプトを保存

3. **サンプル画像を生成**
   - examples/output/ に保存
   - ドキュメントに追加

4. **最適化とチューニング**
   - パラメータ調整
   - 生成速度の最適化
   - VRAM使用量の最適化

---

## 🚨 トラブルシューティング

### GPU認識されない

```bash
# ドライバ確認
nvidia-smi

# 再インストール
sudo apt update
sudo apt install --reinstall nvidia-driver-535
sudo reboot
```

### VRAM不足

```bash
# 低VRAMモードで起動
python main.py --lowvram --listen 0.0.0.0 --port 8188

# または解像度を下げる
# 2048 → 1024
# 1024 → 512
```

### モデルロードエラー

```bash
# モデルファイル確認
ls -lh ~/ComfyUI/models/checkpoints/

# 破損している場合は再ダウンロード
rm ~/ComfyUI/models/checkpoints/<broken-file>
./scripts/download-models.sh
```

### 生成が遅い

```bash
# xformers を使用
pip install xformers
python main.py --use-xformers --listen 0.0.0.0 --port 8188

# Steps を減らす
# 30 → 20 または 25
```

---

## 📞 サポート

問題が解決しない場合:

1. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) を確認
2. ログを保存して Issue を作成
3. 環境情報を含める (GPU, OS, ComfyUI version)

---

**作成日:** 2026-01-21
**最終更新:** 2026-01-21

**GPU環境での動作確認、お疲れ様でした！🎉**
