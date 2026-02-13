import React from 'react'

export interface LandingScreenProps {
  /**
   * アプリケーション名
   */
  appName?: string
  /**
   * サブタイトル/タグライン
   */
  tagline?: string
  /**
   * Sign Inボタンクリック時のハンドラー
   */
  onSignInClick: () => void
  /**
   * Sign Upボタンクリック時のハンドラー（オプション）
   */
  onSignUpClick?: () => void
  /**
   * 🪁（凧）クリック時のハンドラー
   */
  onKiteClick: () => void
}

/**
 * LandingScreen - ランディングページコンポーネント
 * 
 * プロジェクト名とアニメーションするグラフを表示し、
 * Sign In/Sign Upボタンを提供します。
 * グラフ内の🪁をクリックすることでもアクションを実行できます。
 * 
 * @example
 * ```tsx
 * <LandingScreen
 *   appName="My App"
 *   tagline="Welcome to the future"
 *   onSignInClick={() => signIn('cognito')}
 *   onSignUpClick={() => console.log('signup')}
 *   onKiteClick={() => signIn('cognito')}
 * />
 * ```
 */
export function LandingScreen({
  appName = 'UI Libs Landing',
  tagline = 'Welcome to the knowledge graph',
  onSignInClick,
  onSignUpClick,
  onKiteClick,
}: LandingScreenProps) {
  // グラフのノード位置を定義（10個）
  const nodes = [
    { id: 0, x: 150, y: 100, isKite: false },
    { id: 1, x: 350, y: 80, isKite: false },
    { id: 2, x: 550, y: 100, isKite: false },
    { id: 3, x: 100, y: 200, isKite: false },
    { id: 4, x: 300, y: 180, isKite: true }, // 🪁
    { id: 5, x: 500, y: 200, isKite: false },
    { id: 6, x: 600, y: 220, isKite: false },
    { id: 7, x: 200, y: 280, isKite: false },
    { id: 8, x: 400, y: 300, isKite: false },
    { id: 9, x: 550, y: 290, isKite: false },
  ]

  // エッジ（ノード間の線）を定義
  const edges = [
    [0, 1], [1, 2], [0, 3], [1, 4], [2, 5], [2, 6],
    [3, 4], [4, 5], [5, 6], [3, 7], [4, 8], [5, 9],
    [7, 8], [8, 9],
  ]

  return (
    <div className="relative flex flex-col justify-center min-h-screen overflow-hidden bg-gray-50">
      <div className="w-full p-6 m-auto bg-white rounded-md shadow-xl shadow-rose-600/40 ring ring-2 ring-purple-600 lg:max-w-4xl">
        {/* ヘッダー */}
        <div className="text-center">
          <h1 className="text-4xl font-semibold text-purple-700 underline uppercase decoration-wavy">
            {appName}
          </h1>
          {tagline && (
            <p className="mt-2 text-sm text-gray-600">
              {tagline}
            </p>
          )}
        </div>

        {/* グラフアニメーション */}
        <div className="mt-8 mb-8">
          <svg
            viewBox="0 0 700 380"
            className="w-full h-auto"
            style={{ maxHeight: '380px' }}
          >
            {/* エッジ（線） */}
            <g className="edges">
              {edges.map(([from, to], idx) => (
                <line
                  key={idx}
                  x1={nodes[from].x}
                  y1={nodes[from].y}
                  x2={nodes[to].x}
                  y2={nodes[to].y}
                  stroke="#d1d5db"
                  strokeWidth="2"
                  className="opacity-60"
                />
              ))}
            </g>

            {/* ノード */}
            <g className="nodes">
              {nodes.map((node) => {
                if (node.isKite) {
                  // 🪁ノード
                  return (
                    <g
                      key={node.id}
                      className="cursor-pointer transition-transform hover:scale-110"
                      onClick={onKiteClick}
                    >
                      <circle
                        cx={node.x}
                        cy={node.y}
                        r="30"
                        fill="white"
                        stroke="#a78bfa"
                        strokeWidth="2"
                        className="animate-float"
                        style={{
                          animationDelay: `${node.id * 0.2}s`,
                        }}
                      />
                      <text
                        x={node.x}
                        y={node.y}
                        textAnchor="middle"
                        dominantBaseline="central"
                        fontSize="32"
                        className="pointer-events-none"
                      >
                        🪁
                      </text>
                    </g>
                  )
                }

                // 通常のノード
                return (
                  <circle
                    key={node.id}
                    cx={node.x}
                    cy={node.y}
                    r="20"
                    fill="#e9d5ff"
                    stroke="#a78bfa"
                    strokeWidth="2"
                    className="animate-float"
                    style={{
                      animationDelay: `${node.id * 0.2}s`,
                    }}
                  />
                )
              })}
            </g>
          </svg>
        </div>

        {/* ボタンエリア */}
        <div className="space-y-3">
          <button
            onClick={onSignInClick}
            className="w-full px-4 py-2 tracking-wide text-white transition-colors duration-200 transform bg-purple-700 rounded-md hover:bg-purple-600 focus:outline-none focus:bg-purple-600"
          >
            Sign In
          </button>

          {onSignUpClick && (
            <button
              onClick={onSignUpClick}
              className="w-full px-4 py-2 tracking-wide text-purple-700 transition-colors duration-200 transform border-2 border-purple-700 rounded-md hover:bg-purple-50 focus:outline-none focus:bg-purple-50"
            >
              Sign Up
            </button>
          )}
        </div>

        {/* フッター */}
        <p className="mt-6 text-xs text-center text-gray-500">
          Click the 🪁 to get started
        </p>
      </div>

      {/* CSSアニメーション定義 */}
      <style jsx>{`
        @keyframes float {
          0%, 100% {
            transform: translateY(0px);
          }
          50% {
            transform: translateY(-10px);
          }
        }

        .animate-float {
          animation: float 3s ease-in-out infinite;
        }
      `}</style>
    </div>
  )
}
