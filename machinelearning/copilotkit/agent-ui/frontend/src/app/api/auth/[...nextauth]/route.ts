import { NextRequest } from 'next/server';
import { handlers } from '@/auth';

/**
 * NextAuth v5のtrustHostバグ回避策
 * 
 * GitHub Issue: https://github.com/nextauthjs/next-auth/issues/12176
 * 
 * NextAuth v5 beta版では、trustHost: trueを設定してもredirect_uriが正しく設定されず、
 * 内部ホスト（Lambda URLやlocalhostなど）がそのまま使用されてしまう問題があります。
 * 
 * この関数は、X-Forwarded-HostとX-Forwarded-Protoヘッダーを使用して
 * NextRequestオブジェクトのURLを書き換えることで、この問題を回避します。
 */
const reqWithTrustedOrigin = (req: NextRequest): NextRequest => {
  // AUTH_TRUST_HOSTが明示的にtrueに設定されている場合のみ有効
  if (process.env.AUTH_TRUST_HOST !== 'true') {
    return req;
  }

  const proto = req.headers.get('x-forwarded-proto');
  const host = req.headers.get('x-forwarded-host');

  // ヘッダーが存在しない場合は元のリクエストを返す
  if (!proto || !host) {
    return req;
  }

  // 信頼できるオリジンを構築
  const trustedOrigin = `${proto}://${host}`;

  // 元のURLを取得
  const { href, origin } = req.nextUrl;

  // オリジンを書き換えた新しいURLを作成
  const newUrl = href.replace(origin, trustedOrigin);

  // 新しいNextRequestオブジェクトを作成して返す
  return new NextRequest(newUrl, req);
};

// NextAuth v5のハンドラーをエクスポート
// リクエストを事前処理してからハンドラーに渡す
export const GET = (req: NextRequest) => handlers.GET(reqWithTrustedOrigin(req));
export const POST = (req: NextRequest) => handlers.POST(reqWithTrustedOrigin(req));
