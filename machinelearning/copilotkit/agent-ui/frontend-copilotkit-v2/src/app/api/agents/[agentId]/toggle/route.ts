import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/auth';
import { toggleUserAgentEnabled } from '@/lib/dynamodb';
import type { ToggleAgentRequest, ToggleAgentResponse } from '@/types/agent';

/**
 * エージェント有効化/無効化
 * POST /api/agents/[agentId]/toggle
 * 
 * ユーザーのエージェント有効化状態をDynamoDBに保存
 */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ agentId: string }> }
) {
  try {
    // 認証チェック
    const session = await auth();
    if (!session?.user?.sub) {
      return NextResponse.json(
        { error: 'Unauthorized', message: 'Valid authentication required' },
        { status: 401 }
      );
    }

    const userId = session.user.sub;
    const { agentId } = await params;

    // リクエストボディ検証
    const body: ToggleAgentRequest = await req.json();
    if (typeof body.enabled !== 'boolean') {
      return NextResponse.json(
        { error: 'Bad Request', message: 'enabled field must be a boolean' },
        { status: 400 }
      );
    }

    // DynamoDBに保存
    const userAgentSetting = await toggleUserAgentEnabled(
      userId,
      agentId,
      body.enabled
    );

    const response: ToggleAgentResponse = {
      success: true,
      agent: userAgentSetting,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error(`Error in POST /api/agents/[agentId]/toggle:`, error);
    return NextResponse.json(
      { 
        error: 'Internal Server Error', 
        message: error instanceof Error ? error.message : 'Failed to toggle agent' 
      },
      { status: 500 }
    );
  }
}
