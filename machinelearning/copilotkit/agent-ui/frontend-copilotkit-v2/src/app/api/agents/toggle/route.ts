import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/auth';
import { toggleUserAgentEnabled } from '@/lib/dynamodb';
import type { ToggleAgentRequest, ToggleAgentResponse } from '@/types/agent';

/**
 * エージェント有効化/無効化（複数Runtime対応）
 * POST /api/agents/toggle
 * 
 * Body: { agentKey: "runtimeId#agentId", enabled: true }
 * 
 * ユーザーのエージェント有効化状態をDynamoDBに保存
 */
export async function POST(req: NextRequest) {
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

    // リクエストボディ検証
    const body = await req.json();
    
    if (!body.agentKey || typeof body.agentKey !== 'string') {
      return NextResponse.json(
        { error: 'Bad Request', message: 'agentKey field is required and must be a string' },
        { status: 400 }
      );
    }

    if (typeof body.enabled !== 'boolean') {
      return NextResponse.json(
        { error: 'Bad Request', message: 'enabled field must be a boolean' },
        { status: 400 }
      );
    }

    // agentKeyをパース: "runtimeId#agentId"
    const parts = body.agentKey.split('#');
    if (parts.length !== 2) {
      return NextResponse.json(
        { error: 'Bad Request', message: 'agentKey must be in format "runtimeId#agentId"' },
        { status: 400 }
      );
    }

    const [runtimeId, agentId] = parts;

    // DynamoDBに保存
    const userAgentSetting = await toggleUserAgentEnabled(
      userId,
      body.agentKey,
      runtimeId,
      agentId,
      body.enabled
    );

    const response: ToggleAgentResponse = {
      success: true,
      agent: userAgentSetting,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Error in POST /api/agents/toggle:', error);
    return NextResponse.json(
      { 
        error: 'Internal Server Error', 
        message: error instanceof Error ? error.message : 'Failed to toggle agent' 
      },
      { status: 500 }
    );
  }
}
