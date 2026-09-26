'use client';

import { useState } from 'react';
import { useSession } from 'next-auth/react';
import { Button } from '@/ui-libs/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/ui-libs/components/ui/card';

export default function TestAPIPage() {
  const { data: session } = useSession();
  const [testResults, setTestResults] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const addResult = (result: string) => {
    setTestResults(prev => [...prev, result]);
  };

  const clearResults = () => {
    setTestResults([]);
  };

  const testGetAgents = async () => {
    setLoading(true);
    addResult('\n=== Test 1: GET /api/agents ===');
    
    try {
      const response = await fetch('/api/agents');
      const data = await response.json();
      
      addResult(`Status: ${response.status}`);
      addResult(`Response: ${JSON.stringify(data, null, 2)}`);
      
      if (response.ok) {
        addResult('✅ Test 1 PASSED');
      } else {
        addResult('❌ Test 1 FAILED');
      }
    } catch (error) {
      addResult(`❌ Error: ${error}`);
    }
    
    setLoading(false);
  };

  const testToggleAgent = async (agentId: string, enabled: boolean) => {
    setLoading(true);
    addResult(`\n=== Test: POST /api/agents/${agentId}/toggle (${enabled ? 'enable' : 'disable'}) ===`);
    
    try {
      const response = await fetch(`/api/agents/${agentId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled }),
      });
      
      const data = await response.json();
      
      addResult(`Status: ${response.status}`);
      addResult(`Response: ${JSON.stringify(data, null, 2)}`);
      
      if (response.ok) {
        addResult('✅ Test PASSED');
      } else {
        addResult('❌ Test FAILED');
      }
    } catch (error) {
      addResult(`❌ Error: ${error}`);
    }
    
    setLoading(false);
  };

  const runAllTests = async () => {
    clearResults();
    
    addResult('🧪 Starting API Tests...\n');
    
    // Test 1: GET /api/agents
    await testGetAgents();
    
    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Test 2: Enable weatherAgent
    await testToggleAgent('weatherAgent', true);
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Test 3: GET /api/agents again
    await testGetAgents();
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Test 4: Disable weatherAgent
    await testToggleAgent('weatherAgent', false);
    
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Test 5: GET /api/agents again
    await testGetAgents();
    
    addResult('\n🎉 All tests completed!');
  };

  if (!session) {
    return (
      <div className="container mx-auto p-8">
        <Card>
          <CardHeader>
            <CardTitle>認証が必要です</CardTitle>
          </CardHeader>
          <CardContent>
            <p>APIテストを実行するにはログインしてください。</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-8 space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl">🧪 Agents API テスト</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <p className="text-sm text-gray-600 mb-2">
              ログイン中: {session.user?.email}
            </p>
            <p className="text-sm text-gray-600">
              User ID: {session.user?.sub}
            </p>
          </div>

          <div className="flex gap-2 flex-wrap">
            <Button onClick={runAllTests} disabled={loading}>
              全テスト実行
            </Button>
            <Button onClick={testGetAgents} variant="outline" disabled={loading}>
              GET /api/agents
            </Button>
            <Button onClick={() => testToggleAgent('weatherAgent', true)} variant="outline" disabled={loading}>
              Enable weatherAgent
            </Button>
            <Button onClick={() => testToggleAgent('weatherAgent', false)} variant="outline" disabled={loading}>
              Disable weatherAgent
            </Button>
            <Button onClick={clearResults} variant="ghost" disabled={loading}>
              クリア
            </Button>
          </div>

          {loading && <p className="text-sm text-gray-500">実行中...</p>}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>テスト結果</CardTitle>
        </CardHeader>
        <CardContent>
          <pre className="bg-gray-50 p-4 rounded-lg overflow-auto max-h-[600px] text-xs font-mono">
            {testResults.length === 0 ? (
              <span className="text-gray-400">テスト結果がここに表示されます</span>
            ) : (
              testResults.join('\n')
            )}
          </pre>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>DynamoDB確認コマンド</CardTitle>
        </CardHeader>
        <CardContent>
          <pre className="bg-gray-50 p-4 rounded-lg text-xs font-mono">
{`# テーブル全体をスキャン
aws dynamodb scan \\
  --table-name copilotkit-user-agents-prod \\
  --max-items 10

# 特定ユーザーの設定を取得
aws dynamodb query \\
  --table-name copilotkit-user-agents-prod \\
  --key-condition-expression "userId = :uid" \\
  --expression-attribute-values '{\\":uid\\":{\\"S\\":\\"${session.user?.sub}\\"}}'`}
          </pre>
        </CardContent>
      </Card>
    </div>
  );
}
