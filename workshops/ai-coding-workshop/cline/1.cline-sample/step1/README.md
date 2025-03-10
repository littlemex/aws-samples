# 天気予報MCPサーバーの作成

## 目的
シンプルな天気予報MCPサーバーを作成し、Roo Code (Cline Fork) を使用してMCPサーバーを実装する方法を学びます。

## セットアップ手順

1. プロジェクトの作成:
```bash
npx @modelcontextprotocol/create-server weather-server && \
  cd weather-server && \
  npm install
# 1.cline-sample/step1/weather-server というパス構造になる
```

## Clineへの依頼プロンプト

色々なプロンプトをぜひ試してみてください。

```
天気予報のMCPサーバーを作成してください。以下の要件で実装をお願いします：

要件：
1. 都市名を入力として受け取り、その都市の天気予報を返すツールを提供する
2. 実際のAPI通信は行わず、以下の固定値を返す：
   - 晴れ（sunny）: 東京、大阪、福岡
   - 雨（rainy）: ロンドン、シアトル
   - 曇り（cloudy）: パリ、ニューヨーク
3. TypeScriptで実装する
4. MCPのSDKを使用する
5. 天気情報は以下の形式で返す：
   {
     city: string;
     weather: "sunny" | "rainy" | "cloudy";
     temperature: number;
   }

サーバーはディレクトリに作成してください。
```

## 模範解答

模範解答のコードは `answer` ディレクトリにあります：
- `answer/index.ts`: MCPサーバーの実装
- `answer/package.json`: プロジェクトの設定とパッケージ依存関係
- `answer/tsconfig.json`: TypeScriptの設定

## 動かす

1. ビルド:
```bash
cd weather-server
npm run build
```

2. MCPサーバーの設定:

ROO CODE の設定 > MCP Servers > Edit MCP Settings

![](images/vscode-mcp-setting.png)

`/home/coder/.local/share/code-server/User/globalStorage/rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json` に以下を追加:

自身の環境に合わせて適切なパスに変更してください。

```json
{
  "mcpServers": {
    "weather": {
      "command": "node", // 実際のパスに変更: /home/coder/.nvm/versions/node/v22.14.0/bin/node など
      "args": ["/home/coder/aws-samples/workshops/ai-coding-workshop/cline/1.cline-sample/step1/weather-server/build/index.js"],
      "disabled": false,
      "alwaysAllow": []
    }
  }
}
```

3. 作成した MCP Server を試す

![](images/vscode-mcp-test.png)