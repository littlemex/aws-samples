import { NextRequest } from 'next/server';
import { handlers } from '@/auth';

/**
 * NextAuth v5のtrustHostが正しく動作しない問題の回避策
 * X-Forwarded-HostヘッダーからオリジンURLを再構築してリクエストを書き換える
 * 
 * これにより、CloudFront経由でのアクセス時に正しいredirect_uriが生成される
 * 認証開始時とトークン交換時の両方で機能する
 * 
 * @see https://github.com/nextauthjs/next-auth/issues/12176
 */
const reqWithTrustedOrigin = (req: NextRequest): NextRequest => {
  // AUTH_TRUST_HOSTが有効でない場合はそのまま返す
  if (process.env.AUTH_TRUST_HOST !== 'true') {
    return req;
  }
  
  const forwardedHost = req.headers.get('x-forwarded-host');
  const forwardedProto = req.headers.get('x-forwarded-proto');
  
  if (!forwardedProto || !forwardedHost) {
    console.warn('[NextAuth] Missing x-forwarded-* headers:', {
      forwardedProto,
      forwardedHost,
    });
    return req;
  }
  
  const trustedOrigin = `${forwardedProto}://${forwardedHost}`;
  const { href, origin } = req.nextUrl;
  
  // デバッグログ
  console.log('[NextAuth v5] Original origin:', origin);
  console.log('[NextAuth v5] Trusted origin:', trustedOrigin);
  console.log('[NextAuth v5] X-Forwarded-Host:', forwardedHost);
  console.log('[NextAuth v5] X-Forwarded-Proto:', forwardedProto);
  
  // URLのオリジン部分を書き換えて新しいNextRequestを返す
  return new NextRequest(href.replace(origin, trustedOrigin), req);
};

export const GET = (req: NextRequest) => handlers.GET(reqWithTrustedOrigin(req));
export const POST = (req: NextRequest) => handlers.POST(reqWithTrustedOrigin(req));
