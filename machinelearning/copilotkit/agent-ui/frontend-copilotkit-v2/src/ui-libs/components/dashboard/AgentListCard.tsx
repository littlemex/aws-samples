import React from 'react'
import Link from 'next/link'

export interface Agent {
  /**
   * エージェントの一意識別子
   */
  id: string
  /**
   * エージェント名
   */
  name: string
  /**
   * エージェントの説明
   */
  description: string
  /**
   * アイコン（絵文字など）
   */
  icon: string
  /**
   * タイプ（AgentまたはMCP）
   */
  type: 'agent' | 'mcp'
  /**
   * ステータス
   */
  status?: 'available' | 'unavailable'
  /**
   * 詳細ページへのリンク（オプション）
   */
  href?: string
  /**
   * カスタムクリックハンドラー（オプション）
   */
  onClick?: () => void
}

export interface AgentListCardProps {
  /**
   * エージェントのリスト
   */
  agents: Agent[]
  /**
   * カードのタイトル
   */
  title?: string
  /**
   * カードの説明
   */
  description?: string
}

/**
 * AgentListCard - AI AgentとMCPサーバーのリストを表示
 * 
 * 制御されたコンポーネントとして実装されており、
 * リストデータとルーティングは親から提供されます。
 * 
 * @example
 * ```tsx
 * const agents = [
 *   {
 *     id: 'weather',
 *     name: '天気予報エージェント',
 *     description: '指定した場所の天気情報を取得',
 *     icon: '🌤️',
 *     type: 'agent',
 *     href: '/agents/weather'
 *   }
 * ]
 * 
 * <AgentListCard
 *   agents={agents}
 *   title="利用可能なAIエージェント"
 * />
 * ```
 */
export function AgentListCard({
  agents,
  title = '利用可能なAI Agent & MCP',
  description = 'クリックして詳細情報を表示',
}: AgentListCardProps) {
  return (
    <div className="rounded-lg border bg-white shadow-sm">
      {/* ヘッダー */}
      <div className="border-b bg-white p-6">
        <h2 className="text-xl font-semibold text-purple-700">{title}</h2>
        {description && (
          <p className="mt-1 text-sm text-gray-600">{description}</p>
        )}
      </div>

      {/* コンテンツ */}
      <div className="p-6">
        {agents.length === 0 ? (
          <div className="py-12 text-center text-sm text-gray-500">
            <p>利用可能なエージェントがありません</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {agents.map((agent) => {
              const content = (
                <div
                  className={`group flex flex-col gap-3 rounded-lg border bg-gray-50 p-4 transition-all ${
                    agent.href || agent.onClick
                      ? 'cursor-pointer hover:border-purple-400 hover:bg-purple-50 hover:shadow-md'
                      : ''
                  }`}
                  onClick={agent.onClick}
                >
                  {/* アイコンとタイプバッジ */}
                  <div className="flex items-start justify-between">
                    <span className="text-3xl">{agent.icon}</span>
                    <span
                      className={`rounded-full px-2 py-1 text-xs font-medium ${
                        agent.type === 'agent'
                          ? 'bg-purple-100 text-purple-700'
                          : 'bg-blue-100 text-blue-700'
                      }`}
                    >
                      {agent.type === 'agent' ? 'Agent' : 'MCP'}
                    </span>
                  </div>

                  {/* 名前と説明 */}
                  <div className="flex-1">
                    <h3 className="font-semibold text-gray-900 group-hover:text-purple-700">
                      {agent.name}
                    </h3>
                    <p className="mt-1 text-sm text-gray-600">
                      {agent.description}
                    </p>
                  </div>

                  {/* ステータス */}
                  {agent.status && (
                    <div className="flex items-center gap-2">
                      <span
                        className={`h-2 w-2 rounded-full ${
                          agent.status === 'available'
                            ? 'bg-green-500'
                            : 'bg-gray-400'
                        }`}
                      />
                      <span className="text-xs text-gray-500">
                        {agent.status === 'available' ? '利用可能' : '利用不可'}
                      </span>
                    </div>
                  )}
                </div>
              )

              // hrefがある場合はLinkでラップ
              if (agent.href) {
                return (
                  <Link key={agent.id} href={agent.href}>
                    {content}
                  </Link>
                )
              }

              // hrefがない場合はそのまま返す
              return <div key={agent.id}>{content}</div>
            })}
          </div>
        )}
      </div>
    </div>
  )
}
