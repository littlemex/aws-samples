import type { NextConfig } from "next";

// AWS Lambda用設定
// output: 'standalone'でスタンドアロンビルドを生成
const nextConfig: NextConfig = {
  output: 'standalone',
  
  // ビルド時に環境変数を埋め込む
  // これにより、デプロイ時に渡された環境変数がアプリケーションに組み込まれます
  env: {
    COGNITO_CLIENT_ID: process.env.COGNITO_CLIENT_ID,
    COGNITO_ISSUER: process.env.COGNITO_ISSUER,
    NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET,
    NEXTAUTH_URL: process.env.NEXTAUTH_URL,
    AWS_REGION: process.env.AWS_REGION,
  },
};

export default nextConfig;
