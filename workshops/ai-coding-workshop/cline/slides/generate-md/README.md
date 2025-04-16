# Markdown プレゼンテーション変換プロンプト

このディレクトリには、複数の Markdown ファイルを魅力的なプレゼンテーション用の単一 Markdown ファイルに変換するためのプロンプトが含まれています。

## ファイル構成

- `prompt-template.json`: JSON 形式のプロンプト定義テンプレート
- `prompt-template.txt`: テキスト形式の詳細なプロンプト

## 生成 AI への提供方法

### 1. 基本的な使用方法

1. まず、`prompt.txt` の内容、プロンプトの全体像を理解させます。
2. 次に、変換したい Markdown ファイルのリストを提供します。
3. 生成 AI は、プロンプトに従って変換を実行し、単一の Markdown ファイルを生成します。

### 2. 詳細な制御が必要な場合

`prompt.json` を使用して、より詳細な制御を行うことができます：

1. `prompt.json` の内容を生成 AI に提供します。
3. 変換したい Markdown ファイルのリストを提供します。

### 3. 推奨される使用手順

```markdown
# 生成 AI への指示例

以下のプロンプトと設定に従って、複数の Markdown ファイルを単一のプレゼンテーション用 Markdown ファイルに変換してください：

[prompt.txt の内容をここに貼り付け]

変換対象のファイル：
- file1.md
- file2.md
- file3.md

出力ファイル名: ./presentation.md
```

### 4. カスタマイズのポイント

- **スライドの構造**:
  - タイトルスライドのフォーマット
  - アジェンダの項目数
  - 継続スライドの表示方法

- **視覚要素**:
  - Mermaid 図のサイズと配置
  - コードブロックの色とフォント
  - 画像のアスペクト比

- **デザイン指針**:
  - フォントサイズ
  - 余白の設定
  - カラースキーム

## 注意事項

1. プロンプトは必ず完全な形で提供してください。一部分だけを提供すると、期待通りの結果が得られない可能性があります。

2. Markdown ファイルのリストを提供する際は、ファイルの順序が最終的なプレゼンテーションの構造に影響することに注意してください。

3. 生成された Markdown は、`../slides/generate-pptx` ディレクトリの変換スクリプトで PowerPoint に変換できます。

## 使用例

```bash
# 1. 生成 AI に prompt.txt の内容を提供

# 2. 以下のような指示を追加
変換対象のファイル：
- ../../blog/01_introduction.md
- ../../blog/02_about_cline.md
- ../../blog/03_architecture.md
- ../../blog/architecture.md

# 3. 生成された Markdown を保存

# 4. PowerPoint に変換
cd ../generate-pptx
node generate-html.js presentation.md
node html-to-pptx.js presentation-preview.html
```
