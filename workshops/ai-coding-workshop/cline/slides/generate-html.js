const showdown = require('showdown');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

/**
 * Markdown を HTML に変換し、Mermaid 図を画像として埋め込む
 * @param {string} inputFile - 入力Markdownファイル名
 */
async function convertMarkdownToHtml(inputFile) {
    // Markdown ファイルを読み込む
    const mdFile = path.join(__dirname, inputFile);
    const markdownContent = fs.readFileSync(mdFile, 'utf-8');
    
    // Mermaid 図を抽出して画像に変換
    const mermaidMatch = markdownContent.match(/```mermaid\n([\s\S]*?)```/);
    let mermaidImage = '';
    
    if (mermaidMatch) {
        const mermaidContent = mermaidMatch[1];
        const mermaidFile = path.join(__dirname, 'temp.mmd');
        const mermaidOutput = path.join(__dirname, 'diagram.png');
        
        // Mermaid ファイルを作成
        fs.writeFileSync(mermaidFile, mermaidContent);
        
        try {
            // Mermaid 図を PNG に変換
            await execAsync(`npx mmdc -i ${mermaidFile} -o ${mermaidOutput}`);
            console.log('Mermaid 図を画像に変換しました');
            
            // 画像を Base64 エンコード
            const imageBuffer = fs.readFileSync(mermaidOutput);
            const base64Image = imageBuffer.toString('base64');
            mermaidImage = `<div class="image-container"><img src="data:image/png;base64,${base64Image}" alt="Mermaid Diagram" data-type="mermaid"></div>`;
            
            // 一時ファイルを削除
            fs.unlinkSync(mermaidFile);
            fs.unlinkSync(mermaidOutput);
        } catch (error) {
            console.error('Mermaid 図の変換に失敗しました:', error);
        }
    }
    
    // サンプル画像を Base64 エンコード
    const sampleImagePath = path.join(__dirname, 'vscode-extension.png');
    const sampleImageBuffer = fs.readFileSync(sampleImagePath);
    const sampleBase64Image = sampleImageBuffer.toString('base64');
    
    // カスタム拡張機能を作成（画像処理用）
    const imageExtension = {
        type: 'output',
        filter: function(text) {
            // p要素で囲まれた画像を検出して修正
            return text.replace(/<p>(<img[^>]+>)<\/p>/g, '<div class="image-container">$1</div>');
        }
    };

    // Showdown コンバーターの初期化（GitHub Flavored Markdown をサポート）
    const converter = new showdown.Converter({
        tables: true,
        tasklists: true,
        strikethrough: true,
        emoji: true,
        ghCodeBlocks: true,
        smoothLivePreview: true,
        bulletListMarker: '-',  // ハイフンをリストマーカーとして使用
        disableForced4SpacesIndentedSublists: true,  // 強制的なインデントを無効化
        parseImgDimensions: true,  // 画像のサイズ指定を解析
        simplifiedAutoLink: true,  // URLを自動的にリンクに変換
        excludeTrailingPunctuationFromURLs: true,  // URLの末尾の句読点を除外
        literalMidWordUnderscores: true,  // 単語内のアンダースコアをそのまま表示
        simpleLineBreaks: true  // 改行を<br>に変換
    });

    // カスタム拡張機能を追加
    converter.addExtension(imageExtension, 'imageExtension');
    
    // Markdown内の画像参照をBase64に変換
    const imgRegex = /!\[([^\]]*)\]\(([^)]+)\)/g;
    let markdownWithBase64Images = markdownContent;
    
    // Markdown内の画像参照をBase64に置き換え
    const matches = markdownContent.matchAll(imgRegex);
    for (const match of matches) {
        const altText = match[1];
        const imgPath = match[2];
        
        try {
            // 画像ファイルを読み込んでBase64エンコード
            const imagePath = path.join(__dirname, imgPath);
            const imageBuffer = fs.readFileSync(imagePath);
            const base64Image = imageBuffer.toString('base64');
            const imageType = path.extname(imgPath).substring(1); // 拡張子から画像タイプを取得
            
            // Markdown形式の画像参照をHTMLのimg要素に置き換え
            const imgHtml = `<div class="image-container"><img src="data:image/${imageType};base64,${base64Image}" alt="${altText}"></div>`;
            markdownWithBase64Images = markdownWithBase64Images.replace(match[0], imgHtml);
        } catch (error) {
            console.error(`画像の変換に失敗しました: ${imgPath}`, error);
        }
    }
    
    // Mermaid ブロックを含む部分を特定し、その部分を画像に置き換える
    const parts = markdownWithBase64Images.split(/```mermaid\n[\s\S]*?```\n*/);
    const beforeMermaid = parts[0];
    const afterMermaid = parts[1] || '';
    
    // Markdown を HTML に変換（Mermaid ブロックを除外）
    let html = converter.makeHtml(beforeMermaid);
    
    // Mermaid 図を追加（存在する場合）
    if (mermaidImage) {
        html += mermaidImage;
    }
    
    // Mermaid 図の後のコンテンツを変換して追加
    html += converter.makeHtml(afterMermaid);
    
    // HTML ファイルを作成
    const outputHtml = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Markdown Preview</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 { color: #007BFF; }
        h2 { color: #6C757D; }
        a {
            color: #0000FF;
            text-decoration: underline;
        }
        pre {
            background-color: #f5f5f5;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        code {
            font-family: 'Courier New', monospace;
        }
        ul, ol {
            padding-left: 20px;
        }
        li {
            margin: 5px 0;
        }
        .image-container {
            margin: 10px 0;
            text-align: center;
        }
        .image-container img {
            max-width: 100%;
            height: auto;
            display: inline-block;
        }
    </style>
</head>
<body>
    ${html}
</body>
</html>`;
    
    // 出力ファイル名を生成（入力ファイル名に基づく）
    const baseName = path.basename(inputFile, path.extname(inputFile));
    const htmlOutputPath = path.join(__dirname, `${baseName}-preview.html`);
    fs.writeFileSync(htmlOutputPath, outputHtml);
    console.log(`HTML ファイルを生成しました: ${htmlOutputPath}`);
    
    // 出力ファイルパスを返す（html-to-pptx-with-images.js で使用するため）
    return htmlOutputPath;
}

// コマンドライン引数からMarkdownファイルを取得
const inputFile = process.argv[2] || 'test.md';
console.log(`Markdownファイル '${inputFile}' を処理します...`);

convertMarkdownToHtml(inputFile).catch(console.error);
