import React from 'react'

export interface LoginScreenProps {
  /**
   * アプリケーション名
   */
  appName?: string
  /**
   * メールアドレスの値（制御された入力）
   */
  email: string
  /**
   * パスワードの値（制御された入力）
   */
  password: string
  /**
   * メールアドレス変更時のハンドラー
   */
  onEmailChange: (value: string) => void
  /**
   * パスワード変更時のハンドラー
   */
  onPasswordChange: (value: string) => void
  /**
   * フォーム送信時のハンドラー
   */
  onSubmit: (e: React.FormEvent) => void
  /**
   * サインアップリンククリック時のハンドラー
   */
  onSignupClick?: () => void
  /**
   * パスワードを忘れた場合のハンドラー
   */
  onForgotPasswordClick?: () => void
  /**
   * 送信中かどうか
   */
  isSubmitting?: boolean
}

/**
 * LoginScreen - 疎結合なログインフォームコンポーネント
 * 
 * 制御されたコンポーネント（Controlled Component）として実装されており、
 * すべての状態とロジックは親コンポーネントから提供されます。
 * 
 * @example
 * ```tsx
 * function MyApp() {
 *   const [email, setEmail] = useState('')
 *   const [password, setPassword] = useState('')
 *   
 *   const handleSubmit = (e) => {
 *     e.preventDefault()
 *     signIn('cognito', { email, password })
 *   }
 *   
 *   return (
 *     <LoginScreen
 *       email={email}
 *       password={password}
 *       onEmailChange={setEmail}
 *       onPasswordChange={setPassword}
 *       onSubmit={handleSubmit}
 *     />
 *   )
 * }
 * ```
 */
export function LoginScreen({
  appName = 'MyApp',
  email,
  password,
  onEmailChange,
  onPasswordChange,
  onSubmit,
  onSignupClick,
  onForgotPasswordClick,
  isSubmitting = false,
}: LoginScreenProps) {
  return (
    <div className="relative flex flex-col justify-center min-h-screen overflow-hidden">
      <div className="w-full p-6 m-auto bg-white rounded-md shadow-xl shadow-rose-600/40 ring ring-2 ring-purple-600 lg:max-w-xl">
        <h1 className="text-3xl font-semibold text-center text-purple-700 underline uppercase decoration-wavy">
          {appName}
        </h1>
        <form className="mt-6" onSubmit={onSubmit}>
          <div className="mb-2">
            <label
              htmlFor="email"
              className="block text-sm font-semibold text-gray-800"
            >
              Email
            </label>
            <input
              type="email"
              id="email"
              value={email}
              onChange={(e) => onEmailChange(e.target.value)}
              disabled={isSubmitting}
              className="block w-full px-4 py-2 mt-2 text-purple-700 bg-white border rounded-md focus:border-purple-400 focus:ring-purple-300 focus:outline-none focus:ring focus:ring-opacity-40 disabled:opacity-50 disabled:cursor-not-allowed"
              required
            />
          </div>
          <div className="mb-2">
            <label
              htmlFor="password"
              className="block text-sm font-semibold text-gray-800"
            >
              Password
            </label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => onPasswordChange(e.target.value)}
              disabled={isSubmitting}
              className="block w-full px-4 py-2 mt-2 text-purple-700 bg-white border rounded-md focus:border-purple-400 focus:ring-purple-300 focus:outline-none focus:ring focus:ring-opacity-40 disabled:opacity-50 disabled:cursor-not-allowed"
              required
            />
          </div>
          {onForgotPasswordClick && (
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                onForgotPasswordClick()
              }}
              className="text-xs text-purple-600 hover:underline"
            >
              Forget Password?
            </a>
          )}
          <div className="mt-6">
            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full px-4 py-2 tracking-wide text-white transition-colors duration-200 transform bg-purple-700 rounded-md hover:bg-purple-600 focus:outline-none focus:bg-purple-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Logging in...' : 'Login'}
            </button>
          </div>
        </form>

        {onSignupClick && (
          <p className="mt-8 text-xs font-light text-center text-gray-700">
            {' '}
            Don't have an account?{' '}
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                onSignupClick()
              }}
              className="font-medium text-purple-600 hover:underline"
            >
              Sign up
            </a>
          </p>
        )}
      </div>
    </div>
  )
}
