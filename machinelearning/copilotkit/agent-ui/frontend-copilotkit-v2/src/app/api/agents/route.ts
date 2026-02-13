import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/auth';
import { getUserAgentSettings } from '@/lib/dynamodb';
import { getAllRuntimes, fetchAgentsFromRuntime } from '@/lib/runtime';
import type { Agent, ListAgentsResponse, MastraAgent } from '@/types/agent';

/**
 * エージェント一覧取得（複数Runtime対応）
 * GET /api/agents
 * 
 * 全RuntimesからMastraエージェント一覧を取得し、
 * ユーザーの有効化設定とマージして返す
 */
export async function GET(req: NextRequest) {
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

    // [1] 全Runtimesを取得
    const runtimes = await getAllRuntimes();

    // [2] 各RuntimeからMastra APIでエージェント一覧を取得（並列実行）
    const agentsByRuntime = await Promise.allSettled(
      runtimes.map(async (runtime) => {
        const agents = await fetchAgentsFromRuntime(runtime, session.idToken);
        return { runtime, agents };
      })
    );

    // [3] ユーザーの有効化設定を取得（agentKeyベース）
    const userSettings = await getUserAgentSettings(userId);
    const userSettingsMap = new Map(
      userSettings.map(s => [s.agentKey, s])
    );

    // [4] 全Runtimeのエージェントをマージ
    const allAgents: Agent[] = [];

    for (const result of agentsByRuntime) {
      if (result.status === 'rejected') {
        console.error('Failed to fetch agents from runtime:', result.reason);
        continue;
      }

      const { runtime, agents: mastraAgents } = result.value;

      // RuntimeのエージェントをAgent型に変換
      for (const [agentId, mastraAgent] of Object.entries(mastraAgents)) {
        const agentKey = `${runtime.runtimeId}#${agentId}`;
        const userSetting = userSettingsMap.get(agentKey);

        allAgents.push({
          id: agentKey, // 複数Runtime対応: runtimeId#agentId
          agentId, // 元のagentId
          runtimeId: runtime.runtimeId,
          name: mastraAgent.name || agentId,
          description: mastraAgent.description || '',
          icon: getIconForAgent(agentId),
          type: 'system' as const,
          runtimeUrl: runtime.runtimeUrl,
          runtimeName: runtime.runtimeName,
          agentName: agentId,
          enabled: userSetting?.enabled || false,
          status: 'available' as const,
          editable: false, // システムエージェントは編集不可
          provider: mastraAgent.provider,
          modelId: mastraAgent.modelId,
          lastUsedAt: userSetting?.lastUsedAt,
          usageCount: userSetting?.usageCount || 0,
        });
      }
    }

    const response: ListAgentsResponse = {
      agents: allAgents,
      count: allAgents.length,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Error in GET /api/agents:', error);
    return NextResponse.json(
      { 
        error: 'Internal Server Error', 
        message: error instanceof Error ? error.message : 'Failed to fetch agents' 
      },
      { status: 500 }
    );
  }
}

/**
 * エージェントIDに応じたアイコンを返す
 */
function getIconForAgent(agentId: string): string {
  const iconMap: Record<string, string> = {
    'weatherAgent': '🌤️',
    'supportAgent': '💬',
    'codeAgent': '💻',
    'dataAgent': '📊',
    'searchAgent': '🔍',
  };

  return iconMap[agentId] || '🤖';
}
