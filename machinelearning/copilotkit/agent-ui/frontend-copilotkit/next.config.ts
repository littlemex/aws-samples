import type { NextConfig } from "next";

// AWS Lambda用設定
// output: 'standalone'でスタンドアロンビルドを生成
const nextConfig: NextConfig = {
  output: 'standalone',
};

export default nextConfig;
