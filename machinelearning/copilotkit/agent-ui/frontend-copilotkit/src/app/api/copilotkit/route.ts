import { NextRequest } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from '@copilotkit/runtime';

// 空のアダプターを使用（基本的なチャット機能用）
const serviceAdapter = new ExperimentalEmptyAdapter();

const handleCopilotRequest = async (req: NextRequest) => {
  try {
    console.log('CopilotKit API called');
    
    // Cognito認証確認
    const session = await getServerSession(authOptions);
    console.log('Session status:', !!session);
    
    if (!session?.idToken) {
      console.log('No session or idToken found');
      return new Response('Unauthorized', { status: 401 });
    }

    console.log('User authenticated:', session.user?.email);

    // CopilotRuntimeインスタンス作成
    const runtime = new CopilotRuntime({
      // 基本的なランタイム設定
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
