'use client'

import { useState } from 'react'
import { LoginScreen, LandingScreen } from '@/ui-libs'

type DemoType = 'landing' | 'login'

export default function UiLibsDemoPage() {
  const [demoType, setDemoType] = useState<DemoType>('landing')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)
    
    console.log('ログイン:', { email, password })
    alert(`ログイン試行\nEmail: ${email}\nPassword: ${'*'.repeat(password.length)}`)
    
    // 実際の認証処理をシミュレート
    setTimeout(() => {
      setIsSubmitting(false)
    }, 1000)
  }

  const handleSignup = () => {
    console.log('サインアップがクリックされました')
    alert('サインアップページに遷移します')
  }

  const handleForgotPassword = () => {
    console.log('パスワードリセットがクリックされました')
    alert('パスワードリセットページに遷移します')
  }

  const handleSignInClick = () => {
    console.log('Sign Inがクリックされました')
    alert('Cognito Hosted UIに遷移します')
  }

  const handleKiteClick = () => {
    console.log('🪁がクリックされました')
    alert('🪁をクリックしました！Cognito Hosted UIに遷移します')
  }

  // デモ切り替えUI
  if (demoType === 'landing') {
    return (
      <div className="relative">
        {/* 切り替えボタン */}
        <div className="fixed top-4 right-4 z-50 flex gap-2">
          <button
            onClick={() => setDemoType('landing')}
            className="px-4 py-2 bg-purple-700 text-white rounded-md shadow-lg"
          >
            LandingScreen
          </button>
          <button
            onClick={() => setDemoType('login')}
            className="px-4 py-2 bg-white text-purple-700 border-2 border-purple-700 rounded-md shadow-lg"
          >
            LoginScreen
          </button>
        </div>

        <LandingScreen
          appName="UI Libs Demo"
          tagline="Beautiful components for your next project"
          onSignInClick={handleSignInClick}
          onSignUpClick={handleSignup}
          onKiteClick={handleKiteClick}
        />
      </div>
    )
  }

  return (
    <div className="relative">
      {/* 切り替えボタン */}
      <div className="fixed top-4 right-4 z-50 flex gap-2">
        <button
          onClick={() => setDemoType('landing')}
          className="px-4 py-2 bg-white text-purple-700 border-2 border-purple-700 rounded-md shadow-lg"
        >
          LandingScreen
        </button>
        <button
          onClick={() => setDemoType('login')}
          className="px-4 py-2 bg-purple-700 text-white rounded-md shadow-lg"
        >
          LoginScreen
        </button>
      </div>

      <LoginScreen
        appName="UI Libs Demo"
        email={email}
        password={password}
        onEmailChange={setEmail}
        onPasswordChange={setPassword}
        onSubmit={handleSubmit}
        onSignupClick={handleSignup}
        onForgotPasswordClick={handleForgotPassword}
        isSubmitting={isSubmitting}
      />
    </div>
  )
}
