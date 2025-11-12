import { NextRequest } from 'next/server';
import NextAuth from 'next-auth';
import { authOptions } from '@/lib/auth';

/**
 * リクエストヘッダーからホスト情報を取得し、動的にNEXTAUTH_URLを設定
 * これにより、ポートフォワーディング経由でもEC2 IP直接アクセスでも
 * 正しいコールバックURLが使用されます
 */
function setDynamicNextAuthUrl(req: NextRequest) {
  const protocol = process.env.NODE_ENV === 'production' ? 'https' : 'http';
  const host = req.headers.get('host');
  
  if (!host) {
    throw new Error('Request has no host header');
  }
  
  const dynamicUrl = `${protocol}://${host}`;
  process.env.NEXTAUTH_URL = dynamicUrl;
  
  if (process.env.NODE_ENV === 'development') {
    console.log('[NextAuth] Dynamic NEXTAUTH_URL set to:', dynamicUrl);
  }
}

async function handler(req: NextRequest, context: any) {
  // リクエストごとに動的にNEXTAUTH_URLを設定
  setDynamicNextAuthUrl(req);
  
  // NextAuthハンドラーを呼び出し
  return await NextAuth(req, context, authOptions);
}

export { handler as GET, handler as POST };
