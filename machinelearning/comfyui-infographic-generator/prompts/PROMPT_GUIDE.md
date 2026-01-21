# Prompt Engineering Guide for Infographic Generation

このガイドでは、ComfyUIでインフォグラフィックを生成するための効果的なプロンプト作成方法を説明します。

## 📝 基本構造

効果的なプロンプトは以下の要素で構成されます：

```
[スタイル] + [コンテンツ] + [品質指定] + [技術仕様]
```

## 🎨 プロンプトテンプレート

### 1. ミニマリストスタイル (`minimalist.txt`)

**用途:** クリーンでシンプルな図、概念説明

**特徴:**
- パステルカラー
- フラットデザイン
- 白背景
- シンプルな形状

**カスタマイズ例:**
```
professional infographic, machine learning pipeline visualization,
clean modern design, minimalist style, technical illustration,
pastel color palette (azure blue, mint green, coral pink),
flowchart style, clear arrows and boxes,
high quality vector art style, educational diagram,
clear typography, organized layout, white background,
flat design, simple shapes, 4k resolution, sharp details
```

### 2. Daily Dose of Data Science スタイル (`ddds-style.txt`)

**用途:** 教育的なデータサイエンス図、コンセプト説明

**特徴:**
- プロフェッショナルなカラースキーム（青、ティール、オレンジ）
- 明確な視覚階層
- ミニマリストアイコン
- 理解しやすいレイアウト

**カスタマイズ例:**
```
technical infographic explaining gradient descent algorithm,
in the style of Daily Dose of Data Science,
clean educational visualization, step-by-step process,
modern flat design, professional color scheme (blue, teal, orange accents),
numbered steps, clear visual hierarchy, minimalist icons,
mathematical notation, simple geometric shapes,
white background, easy to understand,
high quality technical illustration, 2048x2048
```

### 3. テクニカルダイアグラム (`technical-diagram.txt`)

**用途:** データビジュアライゼーション、統計チャート

**特徴:**
- ビジネスプレゼンテーション向け
- グラフとチャート
- ハイコントラスト
- 読みやすいタイポグラフィ

**カスタマイズ例:**
```
data visualization infographic, model performance comparison,
bar charts and line graphs, statistical analysis,
modern business presentation style, clean graph design,
professional color palette, clear data labels, legends,
minimalist aesthetic, flat design elements,
high contrast, readable typography, organized layout,
white background, 4k quality
```

### 4. アーキテクチャダイアグラム (`architecture-diagram.txt`)

**用途:** システムアーキテクチャ、クラウドインフラ図

**特徴:**
- ボックスとアロー
- 階層構造
- AWSサービスアイコン風
- クリーンなライン

**カスタマイズ例:**
```
AWS cloud architecture diagram, microservices infrastructure,
technical illustration, system design visualization,
boxes connected with arrows, hierarchical layout,
modern color scheme (blues and grays), professional style,
clear labels for each component, service icons,
high quality vector graphics, white background,
easy to read, sharp details, enterprise style
```

## ⚙️ パラメータ調整ガイド

### CFG Scale (Classifier-Free Guidance)

**SDXL:**
- 低 (5.0-6.5): より自由な解釈、創造的
- 中 (7.0-8.0): バランス（推奨）
- 高 (8.5-10.0): プロンプトに厳密、過度に制約される可能性

**FLUX:**
- 低 (1.0-2.0): バランス（推奨）
- 中 (2.5-3.5): プロンプトに忠実
- 高 (4.0+): 通常は不要

### Steps

**SDXL:**
- 高速 (20-25): クイックプレビュー
- 標準 (25-30): ほとんどの用途に最適
- 高品質 (30-40): 最終出力用

**FLUX schnell:**
- 高速 (4-6): schnell モデルに最適化
- 標準 (6-8): 高品質
- 注: FLUX schnellは少ないステップで高品質

### 解像度

**推奨解像度:**
- 1024x1024: 標準、最も速い
- 1536x1536: 高品質
- 2048x2048: PowerPoint/プレゼンテーション用

**アスペクト比:**
- 1:1 (1024x1024): 正方形、SNS向け
- 4:3 (1152x864): プレゼンテーション標準
- 16:9 (1344x768): ワイドスクリーン

## 🚫 ネガティブプロンプトの活用

ネガティブプロンプトは不要な要素を除外します：

**基本ネガティブプロンプト:**
```
photorealistic, 3d render, photograph, realistic,
blurry, low quality, pixelated, jpeg artifacts,
watermark, signature, cluttered, messy
```

**インフォグラフィック特化:**
```
dark background, oversaturated colors, neon colors,
anime style, cartoon style, hand-drawn, sketch,
distorted, noisy, grainy, low resolution
```

## 💡 プロンプト作成のコツ

### 1. 具体的に記述

❌ 悪い例:
```
nice infographic about machine learning
```

✅ 良い例:
```
professional infographic explaining supervised learning process,
clean modern design, flowchart style with labeled steps,
blue and white color scheme, minimalist icons
```

### 2. 品質キーワードを含める

常に含めるべきキーワード:
- `professional`
- `high quality`
- `4k` または `2048x2048`
- `sharp details`
- `clean`

### 3. スタイル参照を使用

- `in the style of [specific reference]`
- `similar to [example]`
- `[brand name] style design`

### 4. レイアウトを指定

- `organized layout`
- `clear visual hierarchy`
- `step-by-step process`
- `flowchart style`
- `comparison diagram`

### 5. カラースキームを明示

- `blue and white color scheme`
- `pastel colors (azure, mint, coral)`
- `professional color palette`
- `monochromatic design`

## 📊 ユースケース別テンプレート

### Machine Learning Pipeline

```
machine learning pipeline infographic,
data preprocessing to model deployment workflow,
flowchart with labeled stages, modern flat design,
blue gradient color scheme, minimalist icons for each step,
white background, professional technical illustration,
clear arrows showing data flow, 2048x2048, high quality
```

### Algorithm Explanation

```
[algorithm name] algorithm visualization,
step-by-step process diagram, educational infographic,
numbered stages with clear explanations,
modern color scheme with accent colors,
simple geometric shapes, flowchart style,
white or light gray background, professional design,
easy to understand, technical illustration
```

### Performance Comparison

```
model performance comparison infographic,
side-by-side bar charts, accuracy metrics visualization,
clean business presentation style, professional colors,
clear labels and legends, minimal design,
high contrast for readability, white background,
statistical data visualization, 4k quality
```

### System Architecture

```
[system name] architecture diagram,
cloud infrastructure visualization, microservices design,
boxes and arrows showing connections,
hierarchical layout, professional color scheme,
service labels and icons, clean technical illustration,
white background, enterprise style, sharp lines
```

## 🔄 反復改善プロセス

1. **初回生成**: ベーステンプレートを使用
2. **評価**: 出力を確認し、不足要素を特定
3. **調整**: プロンプトに具体的な指示を追加
4. **再生成**: パラメータ（CFG、Steps）も調整
5. **最適化**: 最良の結果が出たプロンプトを保存

## 📋 チェックリスト

生成前に確認：
- [ ] スタイルを明確に指定
- [ ] コンテンツの詳細を記述
- [ ] 品質キーワードを含む
- [ ] カラースキームを指定
- [ ] 背景色を指定
- [ ] 解像度を指定
- [ ] ネガティブプロンプトを設定
- [ ] 適切なCFGとStepsを選択

## 🎯 よくある問題と解決策

### 問題: 画像がぼやけている

**解決策:**
- Stepsを増やす (30-35)
- `sharp details`, `high quality`, `4k` をプロンプトに追加
- 解像度を上げる (2048x2048)

### 問題: 色が派手すぎる

**解決策:**
- ネガティブプロンプトに `oversaturated colors, neon colors` を追加
- `pastel colors`, `muted tones`, `professional color palette` を指定

### 問題: レイアウトが雑然としている

**解決策:**
- `clean layout`, `organized design`, `minimalist` を強調
- ネガティブプロンプトに `cluttered, messy, disorganized` を追加
- `white space`, `clear hierarchy` を追加

### 問題: 写実的すぎる

**解決策:**
- `flat design`, `vector art style`, `illustration` を強調
- ネガティブプロンプトに `photorealistic, photograph, 3d render` を追加

### 問題: テキストが読めない（文字化け）

**解決策:**
- FLUX モデルを使用（テキストレンダリングが優れている）
- プロンプトで `clear typography`, `readable text` を指定
- 生成後に外部ツールでテキストを追加することを検討

## 📚 参考リソース

- [Stable Diffusion Prompt Book](https://openart.ai/promptbook)
- [Lexica - SDXL Prompts](https://lexica.art/)
- [Civitai - Community Prompts](https://civitai.com/)
- [PromptHero](https://prompthero.com/)

---

**ヒント:** 良いプロンプトが見つかったら、必ずファイルに保存して再利用しましょう！
