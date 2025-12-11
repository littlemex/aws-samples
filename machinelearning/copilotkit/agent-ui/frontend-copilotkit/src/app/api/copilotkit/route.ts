import { NextRequest } from 'next/server';
import { auth } from '@/auth';
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from '@copilotkit/runtime';
import { MastraAgent } from '@ag-ui/mastra';
import { mastra } from '@/mastra';

// 空のアダプターを使用
const serviceAdapter = new ExperimentalEmptyAdapter();

const handleCopilotRequest = async (req: NextRequest) => {
  try {
    console.log('CopilotKit API called');
    
    // Cognito認証確認 (NextAuth v5)
    const session = await auth();
    console.log('Session status:', !!session);
    
    if (!session?.idToken) {
      console.log('No session or idToken found');
      return new Response('Unauthorized', { status: 401 });
    }

    console.log('User authenticated:', session.user?.email);

    // CopilotRuntimeインスタンス作成 with Mastraエージェント
    const agents = MastraAgent.getLocalAgents({ mastra });
    console.log('🔍 DEBUG: Number of agents loaded:', agents.length);
    console.log('🔍 DEBUG: Agents:', JSON.stringify(agents, null, 2));
    
    const runtime = new CopilotRuntime({
      agents,
    });

    const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
      runtime,
      serviceAdapter,
      endpoint: '/api/copilotkit',
    });

    return handleRequest(req);
  } catch (error) {
    console.error('CopilotKit API error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(`Internal Server Error: ${errorMessage}`, { status: 500 });
  }
};

export const GET = handleCopilotRequest;
export const POST = handleCopilotRequest;
