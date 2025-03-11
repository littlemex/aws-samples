# MCP Server Implementation Workshop

このワークショップでは、Model Context Protocol (MCP) サーバーの実装方法を学び、AIコーディングエージェントとの連携について理解を深めます。

## 概要

このワークショップは2つのステップで構成されています：

### Step 1: 天気予報MCPサーバーの実装

最初のステップでは、シンプルな天気予報MCPサーバーを実装します。主な実装内容：

- TypeScriptを使用したMCPサーバーの作成
- 特定の都市（東京、ロンドン、パリなど）の天気情報を返すツールの実装
- 都市ごとに固定の天気状態（晴れ、雨、曇り）を返す機能
- MCPのSDKを活用した実装

### Step 2: 実装の解説とアーキテクチャ

2番目のステップでは、実装したMCPサーバーの詳細な解説と、コーディングエージェントについて学習します：

- MCPサーバーのアーキテクチャと構成要素の説明
- データフローとコンポーネント間の連携
- TypeScriptによる型安全性の確保
- エラーハンドリングと拡張性への配慮
- Clineなどのコーディングエージェントの概要と役割

## 学習目標

このワークショップを通じて以下を習得できます：

1. MCPサーバーの基本的な実装方法
2. TypeScriptを使用した型安全な実装手法
3. AIコーディングエージェントとの連携方法
4. MCPの概念とその重要性の理解

## 前提条件

- Node.js の基本的な知識
- TypeScriptの基本的な理解
- VSCode と Cline の環境セットアップ

## 始め方

各ステップのディレクトリに移動し、それぞれのREADME.mdの手順に従って進めてください：

1. [Step 1: 天気予報MCPサーバーの作成](step1/README.md)
2. [Step 2: MCPサーバー実装の解説](step2/README.md)

## 参考リンク

- [MCP Servers GitHub Repository](https://github.com/modelcontextprotocol/servers)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
