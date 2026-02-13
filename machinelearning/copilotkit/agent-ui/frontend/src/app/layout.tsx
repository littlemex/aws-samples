import type { Metadata } from 'next';
import { SessionProvider } from './providers';

export const metadata: Metadata = {
  title: 'Cognito Hosted UI Test',
  description: 'Testing Cognito authentication with NextAuth.js',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  );
}
