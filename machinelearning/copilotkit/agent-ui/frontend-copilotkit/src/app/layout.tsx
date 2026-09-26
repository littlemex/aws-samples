import type { Metadata } from 'next';
import { SessionProvider } from './providers';
import { CopilotKit } from '@copilotkit/react-core';
import '@copilotkit/react-ui/styles.css';
import './globals.css';

export const metadata: Metadata = {
  title: 'CopilotKit × Cognito Authentication',
  description: 'CopilotKit integrated with Cognito authentication',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>
          <CopilotKit runtimeUrl="/api/copilotkit" agent="weatherAgent">
            {children}
          </CopilotKit>
        </SessionProvider>
      </body>
    </html>
  );
}
