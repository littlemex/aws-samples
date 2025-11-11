import { NextAuthOptions } from 'next-auth';
import CognitoProvider from 'next-auth/providers/cognito';

export const authOptions: NextAuthOptions = {
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID!,
      clientSecret: '', // Public client (no secret)
      issuer: process.env.COGNITO_ISSUER!,
      client: {
        token_endpoint_auth_method: 'none', // クライアントシークレット不使用を明示
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
  debug: process.env.NODE_ENV === 'development', // 環境に応じてデバッグモードを制御
};
