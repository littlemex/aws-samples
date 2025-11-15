import NextAuth from 'next-auth';
import Cognito from 'next-auth/providers/cognito';

export const { auth, handlers, signIn, signOut } = NextAuth({
  providers: [
    // NextAuth v5では環境変数（AUTH_COGNITO_ID, AUTH_COGNITO_ISSUER）から自動推論
    // Public clientのため、明示的な設定を追加
    Cognito({
      client: {
        token_endpoint_auth_method: 'none',
      },
    }),
  ],
  callbacks: {
    async jwt({ token, account }) {
      // Save Cognito tokens to JWT token
      if (account) {
        token.idToken = account.id_token;
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
      }
      return token;
    },
    async session({ session, token }) {
      // Add tokens to session
      session.idToken = token.idToken as string;
      session.accessToken = token.accessToken as string;
      session.refreshToken = token.refreshToken as string;
      return session;
    },
  },
  debug: process.env.NODE_ENV === 'development',
  // ★ CloudFrontのX-Forwarded-Hostヘッダーを信頼
  trustHost: true,
});
