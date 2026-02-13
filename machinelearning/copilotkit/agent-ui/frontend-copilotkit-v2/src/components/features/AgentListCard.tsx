'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import type { Agent } from '@/types/agent';

interface AgentListCardProps {
  className?: string;
  onAgentToggle?: () => void;
}

export function AgentListCard({ className, onAgentToggle }: AgentListCardProps) {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // エージェント一覧を取得
  useEffect(() => {
    fetchAgents();
  }, []);

  const fetchAgents = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await fetch('/api/agents');
      if (!response.ok) {
        throw new Error('Failed to fetch agents');
      }
      
      const data = await response.json();
      setAgents(data.agents || []);
    } catch (err) {
      console.error('Error fetching agents:', err);
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  // エージェントの有効化/無効化をトグル
  const toggleAgent = async (agentKey: string, currentEnabled: boolean) => {
    try {
      const response = await fetch('/api/agents/toggle', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          agentKey,
          enabled: !currentEnabled,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to toggle agent');
      }

      // 成功したらUIを更新
      setAgents(prevAgents =>
        prevAgents.map(agent =>
          agent.id === agentKey
            ? { ...agent, enabled: !currentEnabled }
            : agent
        )
      );

      // 親コンポーネントに通知（CopilotKitのagent属性を更新）
      if (onAgentToggle) {
        onAgentToggle();
      }
    } catch (err) {
      console.error('Error toggling agent:', err);
      alert('エージェントの設定変更に失敗しました');
    }
  };

  if (loading) {
    return (
      <Card className={className}>
        <div className="p-6">
          <div className="flex items-center justify-center py-8">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-gray-300 border-t-blue-600" />
          </div>
        </div>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className={className}>
        <div className="p-6">
          <div className="rounded-lg bg-red-50 p-4 text-red-800">
            <p className="font-medium">エラーが発生しました</p>
            <p className="text-sm">{error}</p>
          </div>
        </div>
      </Card>
    );
  }

  // Runtimeごとにグループ化
  const agentsByRuntime = agents.reduce((acc, agent) => {
    const runtimeName = agent.runtimeName || agent.runtimeId;
    if (!acc[runtimeName]) {
      acc[runtimeName] = [];
    }
    acc[runtimeName].push(agent);
    return acc;
  }, {} as Record<string, Agent[]>);

  return (
    <Card className={className}>
      <div className="p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">利用可能なエージェント</h2>
          <Button
            variant="outline"
            size="sm"
            onClick={fetchAgents}
            className="text-sm"
          >
            🔄 更新
          </Button>
        </div>

        {agents.length === 0 ? (
          <div className="rounded-lg bg-gray-50 p-8 text-center">
            <p className="text-gray-600">利用可能なエージェントがありません</p>
            <p className="mt-2 text-sm text-gray-500">
              管理者がRuntimeを登録してください
            </p>
          </div>
        ) : (
          <div className="space-y-6">
            {Object.entries(agentsByRuntime).map(([runtimeName, runtimeAgents]) => (
              <div key={runtimeName}>
                <h3 className="mb-3 text-sm font-medium text-gray-700">
                  📦 {runtimeName}
                </h3>
                <div className="space-y-2">
                  {runtimeAgents.map((agent) => (
                    <div
                      key={agent.id}
                      className="flex items-center justify-between rounded-lg border border-gray-200 bg-white p-4 transition-shadow hover:shadow-md"
                    >
                      <div className="flex items-center space-x-3">
                        <div className="text-2xl">{agent.icon}</div>
                        <div>
                          <h4 className="font-medium text-gray-900">{agent.name}</h4>
                          <p className="text-sm text-gray-600">{agent.description}</p>
                          {agent.provider && (
                            <p className="mt-1 text-xs text-gray-500">
                              {agent.provider} • {agent.modelId}
                            </p>
                          )}
                          {agent.usageCount && agent.usageCount > 0 && (
                            <p className="mt-1 text-xs text-gray-500">
                              使用回数: {agent.usageCount}回
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <label className="flex cursor-pointer items-center space-x-2">
                          <input
                            type="checkbox"
                            checked={agent.enabled}
                            onChange={() => toggleAgent(agent.id, agent.enabled)}
                            className="h-5 w-5 rounded border-gray-300 text-blue-600 focus:ring-2 focus:ring-blue-500"
                          />
                          <span className="text-sm font-medium text-gray-700">
                            {agent.enabled ? '有効' : '無効'}
                          </span>
                        </label>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {agents.length > 0 && (
          <div className="mt-4 rounded-lg bg-blue-50 p-4">
            <p className="text-sm text-blue-800">
              💡 <strong>ヒント:</strong> エージェントを有効化すると、CopilotKitのサイドバーで利用できるようになります。
            </p>
          </div>
        )}
      </div>
    </Card>
  );
}
