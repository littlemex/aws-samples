# GPU環境 クイック確認チェックリスト

GPU インスタンスで実行する確認項目の簡潔版です。

## 🚀 セットアップ（15-30分）

```bash
# 1. GPU確認
nvidia-smi

# 2. プロジェクトディレクトリへ移動
cd ~/aws-samples/machinelearning/comfyui-infographic-generator

# 3. ComfyUIインストール
./scripts/install-comfyui.sh

# 4. 環境検証
./tests/validate-setup.sh

# 5. モデルダウンロード（推奨: Option 1 または 11）
./scripts/download-models.sh

# 6. 再度検証
./tests/validate-setup.sh
```

## ✅ 重要確認項目

### GPU認識
```bash
nvidia-smi
# 期待: GPU名、VRAM 22GB以上表示
```

### PyTorch CUDA
```bash
python3 -c "import torch; print(torch.cuda.is_available())"
# 期待: True
```

### ComfyUI起動
```bash
source ~/.comfyui_activate
comfyui
# 期待: "Device: cuda:0" と表示
```

### Web UI アクセス
```
ブラウザ: http://<instance-ip>:8188
# 期待: ComfyUI UI が表示される
```

### テスト生成
```
1. 基本ワークフロー作成
2. プロンプト: "simple test, blue square"
3. 512x512, 20 steps
4. Queue Prompt
# 期待: 10-15秒で完了
```

## 🎯 ワークフロー作成（GPU環境で）

```bash
# 1. ComfyUI起動
comfyui

# 2. ブラウザでワークフロー作成
# http://<instance-ip>:8188

# 3. workflows/README.md の手順に従って作成

# 4. 保存: Save (API Format) → workflows/ に保存

# 5. Git コミット
cd ~/aws-samples/machinelearning/comfyui-infographic-generator
git add workflows/*.json
git commit -m "Add workflow templates"
```

## 📊 生成速度ベンチマーク

期待される生成時間:

- 512x512, 20 steps: 5-10秒
- 1024x1024, 25 steps: 15-20秒
- 2048x2048, 30 steps: 45-60秒

遅い場合:
```bash
# xformers使用
python main.py --use-xformers --listen 0.0.0.0 --port 8188
```

## 🚨 トラブルシューティング

### GPU認識されない
```bash
sudo apt install --reinstall nvidia-driver-535
sudo reboot
```

### VRAM不足
```bash
# 低VRAMモード
python main.py --lowvram --listen 0.0.0.0 --port 8188
```

### モデルエラー
```bash
# 再ダウンロード
./scripts/download-models.sh
```

## 📝 完了後のタスク

- [ ] ワークフローJSON作成 (最低3個)
- [ ] テスト画像生成 (examples/output/ に保存)
- [ ] Git コミット
- [ ] GPU確認項目リストの全項目確認

---

詳細は [docs/GPU_VERIFICATION_CHECKLIST.md](docs/GPU_VERIFICATION_CHECKLIST.md) を参照
