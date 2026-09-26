'use client';

import { useSession, signIn, signOut } from 'next-auth/react';
import { CopilotKit } from '@copilotkit/react-core';
import { CopilotSidebar } from '@copilotkit/react-ui';
import { useCopilotAction, useCoAgent } from '@copilotkit/react-core';
import { useState, useEffect, useCallback } from 'react';
import { AgentState } from '@/mastra/agents';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { LandingScreen } from '@/ui-libs';
import { AuthInfo } from '@/components/auth/AuthInfo';
import { WeatherCard } from '@/components/features/WeatherCard';
import { AgentListCard } from '@/components/features/AgentListCard';

type AgentStateType = z.infer<typeof AgentState>;

export default function Home() {
  const { data: session, status } = useSession();
  const [themeColor, setThemeColor] = useState('#3b82f6');
  const [enabledAgent, setEnabledAgent] = useState<string | undefined>(undefined);
  const [agentsLoaded, setAgentsLoaded] = useState(false);

  // 有効化されたエージェントを取得
  const fetchEnabledAgent = useCallback(async () => {
    if (!session?.user) {
      setEnabledAgent(undefined);
      setAgentsLoaded(false);
      return;
    }

    try {
      const response = await fetch('/api/agents');
      if (!response.ok) {
        console.error('Failed to fetch agents');
        setEnabledAgent(undefined);
        setAgentsLoaded(true);
        return;
      }

      const data = await response.json();
      const enabledAgents = data.agents.filter((agent: any) => agent.enabled);
      
      // 有効なエージェントがあれば最初の1つを使用
      if (enabledAgents.length > 0) {
        setEnabledAgent(enabledAgents[0].agentId);
      } else {
        setEnabledAgent(undefined);
      }
      setAgentsLoaded(true);
    } catch (error) {
      console.error('Error fetching enabled agent:', error);
      setEnabledAgent(undefined);
      setAgentsLoaded(true);
    }
  }, [session]);

  // 初回ロード時とセッション変更時にエージェント取得
  useEffect(() => {
    if (session?.user) {
      fetchEnabledAgent();
    }
  }, [session, fetchEnabledAgent]);

  if (status === 'loading') {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-gray-300 border-t-blue-600" />
      </div>
    );
  }

  if (!session) {
    return (
      <LandingScreen
        appName="CopilotKit Sample Landing"
        tagline="CopilotKit sample for your AI agent projects."
        onSignInClick={() => signIn('cognito')}
        onSignUpClick={() => {
          // Sign up button - no action for now
          console.log('Sign up clicked')
        }}
        onKiteClick={() => signIn('cognito')}
      />
    );
  }

  // エージェントの有無に関わらず常にCopilotKitでラップ
  // agent=undefinedの場合、CopilotKitはagentモードを使用しない
  return (
    <CopilotKit 
      runtimeUrl="/api/copilotkit" 
      agent={enabledAgent}
      key={enabledAgent || 'no-agent'} // エージェント変更時に再マウント
    >
      <AuthenticatedView 
        themeColor={themeColor}
        setThemeColor={setThemeColor}
        session={session}
        onAgentChange={fetchEnabledAgent}
        hasEnabledAgent={agentsLoaded && !!enabledAgent}
      />
    </CopilotKit>
  );
}

function AuthenticatedView({
  themeColor,
  setThemeColor,
  session,
  onAgentChange,
  hasEnabledAgent = true,
}: {
  themeColor: string;
  setThemeColor: (color: string) => void;
  session: any;
  onAgentChange: () => void;
  hasEnabledAgent?: boolean;
}) {
  // Frontend Action: テーマカラー変更
  useCopilotAction({
    name: 'setThemeColor',
    description: 'Set the theme color of the application UI',
    parameters: [{
      name: 'themeColor',
      description: 'The theme color to set. Pick nice colors.',
      required: true,
    }],
    handler({ themeColor }) {
      setThemeColor(themeColor);
    },
  });

  // Generative UI: 天気情報
  useCopilotAction({
    name: "weatherTool",
    description: "Get the weather for a given location.",
    available: "frontend",
    parameters: [{ name: "location", type: "string", required: true }],
    render: ({ args, result, status }) => (
      <WeatherCard location={args.location} result={result} status={status} />
    ),
  });

  return (
    <>
      <div className="flex min-h-screen flex-col bg-gray-50">
        <header className="border-b border-purple-200 bg-white">
          <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
            <div>
              <h1 className="text-xl font-semibold text-purple-700">AI Agent Dashboard</h1>
              <p className="text-sm text-purple-600">CopilotKit × Cognito × Mastra</p>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={() => signOut()}
              className="border-purple-600 text-purple-600 hover:bg-purple-50 hover:text-purple-700"
            >
              サインアウト
            </Button>
          </div>
        </header>

        <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6 lg:px-8">
          <div className="space-y-6">
            <AgentListCard onAgentToggle={onAgentChange} />
            <AuthInfo session={session} />
          </div>
        </main>
      </div>
      
      {hasEnabledAgent && (
        <CopilotSidebar
          clickOutsideToClose={false}
          defaultOpen={true}
          labels={{
            title: "AI アシスタント",
            initial: "👋 こんにちは！\n\nCopilotKit × Cognito × Mastraの統合AIアシスタントです。\n\n**試してみてください：**\n• テーマを緑色に変更して\n• 東京の天気を教えて"
          }}
        />
      )}
      
      {!hasEnabledAgent && (
        <div className="fixed bottom-4 right-4 rounded-lg bg-yellow-50 border border-yellow-200 p-4 shadow-lg max-w-md">
          <p className="font-medium text-yellow-900">⚠️ エージェントが有効化されていません</p>
          <p className="mt-1 text-sm text-yellow-800">
            「利用可能なエージェント」カードからエージェントを有効化してください。
          </p>
        </div>
      )}
    </>
  );
}
