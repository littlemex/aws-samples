'use client';

import { useSession, signIn, signOut } from 'next-auth/react';
import { CopilotSidebar } from '@copilotkit/react-ui';
import { useCopilotAction } from '@copilotkit/react-core';
import { useState } from 'react';

export default function Home() {
  const { data: session, status } = useSession();
  const [themeColor, setThemeColor] = useState('#6366f1');

  // Frontend Action for theme color change
  useCopilotAction({
    name: 'setThemeColor',
    parameters: [{
      name: 'themeColor',
      description: 'The theme color to set. Pick nice colors like blue, green, purple, etc.',
      required: true,
    }],
    handler({ themeColor }) {
      setThemeColor(themeColor);
    },
  });

  if (status === 'loading') {
    return (
      <div className="h-screen w-screen flex justify-center items-center" style={{ backgroundColor: themeColor }}>
        <div className="bg-white/20 backdrop-blur-md p-8 rounded-2xl shadow-xl">
          <h1 className="text-2xl font-bold text-white">🔄 Loading...</h1>
        </div>
      </div>
    );
  }

  if (!session) {
    return (
      <div className="h-screen w-screen flex justify-center items-center" style={{ backgroundColor: themeColor }}>
        <div className="bg-white/20 backdrop-blur-md p-8 rounded-2xl shadow-xl max-w-md w-full text-center">
          <h1 className="text-3xl font-bold text-white mb-4">🔐 CopilotKit × Cognito</h1>
          <p className="text-gray-200 mb-6">Amazon Cognito認証でCopilotKitチャット体験を開始</p>
          <button
            onClick={() => signIn('cognito')}
            className="w-full bg-white/20 hover:bg-white/30 text-white font-semibold py-3 px-6 rounded-lg transition-all duration-300"
          >
            Sign in with Cognito
          </button>
        </div>
      </div>
    );
  }

  // Authenticated - show CopilotKit chat interface
  const decodeJWT = (token: string) => {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      return JSON.parse(jsonPayload);
    } catch (error) {
      return null;
    }
  };

  const idTokenDecoded = session.idToken ? decodeJWT(session.idToken) : null;

  return (
    <main style={{ '--copilot-kit-primary-color': themeColor } as any}>
      <MainContent 
        themeColor={themeColor} 
        session={session} 
        userInfo={idTokenDecoded}
        onSignOut={() => signOut()}
      />
      <CopilotSidebar
        clickOutsideToClose={false}
        defaultOpen={true}
        labels={{
          title: "AI Assistant",
          initial: "👋 こんにちは！CopilotKit × Cognito認証が統合されたAIアシスタントです。\n\n以下を試してみてください：\n- **テーマ変更**: 「テーマを青色に変更して」\n- **ユーザー情報**: 「私のユーザー情報を教えて」\n- **一般的な質問**: 何でも聞いてください！"
        }}
      />
    </main>
  );
}

function MainContent({ 
  themeColor, 
  session, 
  userInfo, 
  onSignOut 
}: { 
  themeColor: string;
  session: any;
  userInfo: any;
  onSignOut: () => void;
}) {
  return (
    <div
      style={{ backgroundColor: themeColor }}
      className="h-screen w-screen flex justify-center items-center transition-colors duration-300"
    >
      <div className="bg-white/20 backdrop-blur-md p-8 rounded-2xl shadow-xl max-w-2xl w-full">
        <div className="flex justify-between items-start mb-6">
          <div>
            <h1 className="text-4xl font-bold text-white mb-2">✅ 認証成功!</h1>
            <p className="text-gray-200">CopilotKitチャット機能が利用可能です →</p>
          </div>
          <button
            onClick={onSignOut}
            className="bg-red-500/80 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-all"
          >
            Sign out
          </button>
        </div>

        <hr className="border-white/20 my-6" />

        <div className="grid md:grid-cols-2 gap-6">
          <div className="bg-white/15 p-4 rounded-xl">
            <h3 className="text-lg font-semibold text-white mb-3">👤 ユーザー情報</h3>
            <div className="text-sm text-gray-200 space-y-1">
              <p><strong>Email:</strong> {userInfo?.email || 'N/A'}</p>
              <p><strong>Username:</strong> {userInfo?.['cognito:username'] || 'N/A'}</p>
              <p><strong>User ID:</strong> {userInfo?.sub?.substring(0, 8)}...</p>
            </div>
          </div>

          <div className="bg-white/15 p-4 rounded-xl">
            <h3 className="text-lg font-semibold text-white mb-3">🎨 テーマカラー</h3>
            <div className="text-sm text-gray-200">
              <p>現在の色: <span style={{ color: themeColor }}>●</span> {themeColor}</p>
              <p className="mt-2">右のチャットで「テーマを変更して」と言ってみてください！</p>
            </div>
          </div>
        </div>

        <div className="mt-6 text-center">
          <p className="text-white/80 text-sm italic">
            右側のAIアシスタントとチャットを始めましょう！ 🚀
          </p>
        </div>
      </div>
    </div>
  );
}
