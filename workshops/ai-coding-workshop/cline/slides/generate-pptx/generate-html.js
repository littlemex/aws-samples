const showdown = require('showdown');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

/**
 * Mermaid 図を画像に変換する
 * @param {string} mermaidContent - Mermaid図の内容
 * @returns {Promise<string>} Base64エンコードされた画像データ
 */
async function convertMermaidToImage(mermaidContent) {
    const mermaidFile = path.join(__dirname, `temp-${Date.now()}.mmd`);
    const mermaidOutput = path.join(__dirname, `diagram-${Date.now()}.png`);
    
    // Mermaid ファイルを作成
    fs.writeFileSync(mermaidFile, mermaidContent);
    
    try {
        // Mermaid 図を PNG に変換
        await execAsync(`npx mmdc -i ${mermaidFile} -o ${mermaidOutput}`);
        console.log('Mermaid 図を画像に変換しました');
        
        // 画像を Base64 エンコード
        const imageBuffer = fs.readFileSync(mermaidOutput);
        const base64Image = imageBuffer.toString('base64');
        
        // 一時ファイルを削除
        fs.unlinkSync(mermaidFile);
        fs.unlinkSync(mermaidOutput);
        
        return base64Image;
    } catch (error) {
        console.error('Mermaid 図の変換に失敗しました:', error);
        // 一時ファイルを削除（エラー時も）
        if (fs.existsSync(mermaidFile)) fs.unlinkSync(mermaidFile);
        if (fs.existsSync(mermaidOutput)) fs.unlinkSync(mermaidOutput);
        throw error;
    }
}

/**
 * Markdown を HTML に変換し、Mermaid 図を画像として埋め込む
 * @param {string} inputFile - 入力Markdownファイル名
 */
async function convertMarkdownToHtml(inputFile) {
    // Markdown ファイルを読み込む
    const mdFile = path.join(__dirname, inputFile);
    const markdownContent = fs.readFileSync(mdFile, 'utf-8');
    
    // Mermaid 図を検出して画像に変換
    const mermaidRegex = /```mermaid\n([\s\S]*?)```/g;
    const mermaidMatches = Array.from(markdownContent.matchAll(mermaidRegex));
    
    // Markdown を Mermaid ブロックで分割
    const parts = markdownContent.split(/```mermaid\n[\s\S]*?```/);
    let finalHtml = '';
    
    // Showdown コンバーターの初期化
    const converter = new showdown.Converter({
        tables: true,
        tasklists: true,
        strikethrough: true,
        emoji: true,
        ghCodeBlocks: true,
        smoothLivePreview: true,
        bulletListMarker: '-',
        disableForced4SpacesIndentedSublists: true,
        parseImgDimensions: true,
        simplifiedAutoLink: true,
        excludeTrailingPunctuationFromURLs: true,
        literalMidWordUnderscores: true,
        simpleLineBreaks: true
    });
    
    // カスタム拡張機能を追加（画像処理用）
    converter.addExtension({
        type: 'output',
        filter: function(text) {
            return text.replace(/<p>(<img[^>]+>)<\/p>/g, '<div class="image-container">$1</div>');
        }
    }, 'imageExtension');
    
    // 各部分を処理
    for (let i = 0; i < parts.length; i++) {
        // Markdown 部分を HTML に変換
        let html = converter.makeHtml(parts[i]);
        finalHtml += html;
        
        // 対応する Mermaid 図があれば変換して追加
        if (i < mermaidMatches.length) {
            try {
                const mermaidContent = mermaidMatches[i][1];
                const base64Image = await convertMermaidToImage(mermaidContent);
                const mermaidImage = `<div class="image-container"><img src="data:image/png;base64,${base64Image}" alt="Mermaid Diagram" data-type="mermaid"></div>`;
                finalHtml += mermaidImage;
            } catch (error) {
                console.error('Mermaid 図の処理に失敗しました:', error);
            }
        }
    }
    
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
    ${finalHtml}
</body>
</html>`;
    
    // 出力ファイル名を生成
    const baseName = path.basename(inputFile, path.extname(inputFile));
    const htmlOutputPath = path.join(__dirname, `${baseName}-preview.html`);
    fs.writeFileSync(htmlOutputPath, outputHtml);
    console.log(`HTML ファイルを生成しました: ${htmlOutputPath}`);
    
    return htmlOutputPath;
}

// コマンドライン引数からMarkdownファイルを取得
const inputFile = process.argv[2] || 'test.md';
console.log(`Markdownファイル '${inputFile}' を処理します...`);

convertMarkdownToHtml(inputFile).catch(console.error);
