'use client';

import { useSession, signIn, signOut } from 'next-auth/react';

export default function Home() {
  const { data: session, status } = useSession();

  if (status === 'loading') {
    return (
      <div style={{ padding: '2rem', fontFamily: 'monospace' }}>
        <h1>🔄 Loading...</h1>
      </div>
    );
  }

  if (!session) {
    return (
      <div style={{ padding: '2rem', fontFamily: 'monospace' }}>
        <h1>🔐 Cognito Hosted UI Authentication Test</h1>
        <p>Click the button below to authenticate with Amazon Cognito</p>
        <button
          onClick={() => signIn('cognito')}
          style={{
            padding: '10px 20px',
            fontSize: '16px',
            cursor: 'pointer',
            marginTop: '1rem',
          }}
        >
          Sign in with Cognito
        </button>
      </div>
    );
  }

  // Authenticated - display tokens and user info
  const decodeJWT = (token: string) => {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      return JSON.parse(jsonPayload);
    } catch (error) {
      return null;
    }
  };

  const idTokenDecoded = session.idToken ? decodeJWT(session.idToken) : null;
  const accessTokenDecoded = session.accessToken
    ? decodeJWT(session.accessToken)
    : null;

  return (
    <div style={{ padding: '2rem', fontFamily: 'monospace', maxWidth: '1200px' }}>
      <h1>✅ Authentication Successful!</h1>

      <button
        onClick={() => signOut()}
        style={{
          padding: '10px 20px',
          fontSize: '16px',
          cursor: 'pointer',
          marginBottom: '2rem',
        }}
      >
        Sign out
      </button>

      <hr />

      <h2>👤 User Information</h2>
      <pre style={{ background: '#f5f5f5', padding: '1rem', overflow: 'auto' }}>
        {JSON.stringify(session.user, null, 2)}
      </pre>

      <hr />

      <h2>🔑 ID Token</h2>
      <h3>Raw Token:</h3>
      <pre
        style={{
          background: '#f5f5f5',
          padding: '1rem',
          overflow: 'auto',
          wordBreak: 'break-all',
        }}
      >
        {session.idToken}
      </pre>

      {idTokenDecoded && (
        <>
          <h3>Decoded Payload:</h3>
          <pre style={{ background: '#f5f5f5', padding: '1rem', overflow: 'auto' }}>
            {JSON.stringify(idTokenDecoded, null, 2)}
          </pre>
        </>
      )}

      <hr />

      <h2>🎫 Access Token</h2>
      <h3>Raw Token:</h3>
      <pre
        style={{
          background: '#f5f5f5',
          padding: '1rem',
          overflow: 'auto',
          wordBreak: 'break-all',
        }}
      >
        {session.accessToken}
      </pre>

      {accessTokenDecoded && (
        <>
          <h3>Decoded Payload:</h3>
          <pre style={{ background: '#f5f5f5', padding: '1rem', overflow: 'auto' }}>
            {JSON.stringify(accessTokenDecoded, null, 2)}
          </pre>
        </>
      )}

      <hr />

      <h2>📊 Key Information</h2>
      <ul>
        <li>
          <strong>User ID (sub):</strong> {idTokenDecoded?.sub}
        </li>
        <li>
          <strong>Email:</strong> {idTokenDecoded?.email}
        </li>
        <li>
          <strong>Cognito Username:</strong> {idTokenDecoded?.['cognito:username']}
        </li>
        <li>
          <strong>Token Issued At:</strong>{' '}
          {idTokenDecoded?.iat
            ? new Date(idTokenDecoded.iat * 1000).toLocaleString()
            : 'N/A'}
        </li>
        <li>
          <strong>Token Expires At:</strong>{' '}
          {idTokenDecoded?.exp
            ? new Date(idTokenDecoded.exp * 1000).toLocaleString()
            : 'N/A'}
        </li>
        <li>
          <strong>Issuer:</strong> {idTokenDecoded?.iss}
        </li>
      </ul>
    </div>
  );
}
