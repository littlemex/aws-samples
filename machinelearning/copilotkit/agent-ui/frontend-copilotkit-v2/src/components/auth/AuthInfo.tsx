import { useState } from 'react';
import { Card, CardContent } from '@/components/ui/card';

interface AuthInfoProps {
  session: any;
}

export function AuthInfo({ session }: AuthInfoProps) {
  const [open, setOpen] = useState(false);
  const idToken = session.idToken ? decodeJWT(session.idToken) : null;
  const accessToken = session.accessToken ? decodeJWT(session.accessToken) : null;

  const truncateToken = (token: string) => {
    if (!token || token.length < 20) return token;
    return `${token.substring(0, 10)}...${token.substring(token.length - 10)}`;
  };

  return (
    <Card className="border-purple-200">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between p-6 text-left transition-colors hover:bg-purple-50"
      >
        <span className="font-medium text-purple-700">認証情報</span>
        <svg 
          className={`h-4 w-4 text-purple-600 transition-transform ${open ? 'rotate-180' : ''}`}
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      
      {open && (
        <CardContent className="space-y-4 border-t border-purple-100 bg-purple-50/50 text-sm">
          {/* ユーザー情報 */}
          <div>
            <p className="font-semibold text-purple-900">ユーザー情報</p>
            <div className="mt-2 space-y-1 text-gray-700">
              <p><span className="font-medium">Email:</span> {idToken?.email || 'N/A'}</p>
              <p><span className="font-medium">Username:</span> {idToken?.['cognito:username'] || 'N/A'}</p>
              <p><span className="font-medium">Sub:</span> {idToken?.sub || 'N/A'}</p>
            </div>
          </div>

          {/* ID Token */}
          <div>
            <p className="font-semibold text-purple-900">ID Token</p>
            <div className="mt-2 space-y-1 text-gray-700">
              <p className="break-all font-mono text-xs">
                {session.idToken ? truncateToken(session.idToken) : 'N/A'}
              </p>
              {idToken && (
                <>
                  <p><span className="font-medium">発行者:</span> {idToken.iss || 'N/A'}</p>
                  <p><span className="font-medium">対象:</span> {idToken.aud || 'N/A'}</p>
                  <p><span className="font-medium">発行時刻:</span> {idToken.iat ? new Date(idToken.iat * 1000).toLocaleString('ja-JP') : 'N/A'}</p>
                  <p><span className="font-medium">有効期限:</span> {idToken.exp ? new Date(idToken.exp * 1000).toLocaleString('ja-JP') : 'N/A'}</p>
                </>
              )}
            </div>
          </div>

          {/* Access Token */}
          <div>
            <p className="font-semibold text-purple-900">Access Token</p>
            <div className="mt-2 space-y-1 text-gray-700">
              <p className="break-all font-mono text-xs">
                {session.accessToken ? truncateToken(session.accessToken) : 'N/A'}
              </p>
              {accessToken && (
                <>
                  <p><span className="font-medium">発行時刻:</span> {accessToken.iat ? new Date(accessToken.iat * 1000).toLocaleString('ja-JP') : 'N/A'}</p>
                  <p><span className="font-medium">有効期限:</span> {accessToken.exp ? new Date(accessToken.exp * 1000).toLocaleString('ja-JP') : 'N/A'}</p>
                  <p><span className="font-medium">Scope:</span> {accessToken.scope || 'N/A'}</p>
                </>
              )}
            </div>
          </div>

          {/* Refresh Token */}
          {session.refreshToken && (
            <div>
              <p className="font-semibold text-purple-900">Refresh Token</p>
              <div className="mt-2 text-gray-700">
                <p className="break-all font-mono text-xs">
                  {truncateToken(session.refreshToken)}
                </p>
              </div>
            </div>
          )}

          {/* その他のセッション情報 */}
          <div>
            <p className="font-semibold text-purple-900">セッション情報</p>
            <div className="mt-2 space-y-1 text-gray-700">
              <p><span className="font-medium">Provider:</span> {session.provider || 'N/A'}</p>
              {session.expires && (
                <p><span className="font-medium">Session Expires:</span> {new Date(session.expires).toLocaleString('ja-JP')}</p>
              )}
            </div>
          </div>
        </CardContent>
      )}
    </Card>
  );
}

function decodeJWT(token: string) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}
