'use client';

import { useSession, signIn, signOut } from 'next-auth/react';
import { CopilotSidebar } from '@copilotkit/react-ui';
import { useCopilotAction, useCoAgent } from '@copilotkit/react-core';
import { useState } from 'react';
import { AgentState } from '@/mastra/agents';
import { z } from 'zod';
import { WeatherToolResult } from '@/mastra/tools';

type AgentStateType = z.infer<typeof AgentState>;

export default function Home() {
  const { data: session, status } = useSession();
  const [themeColor, setThemeColor] = useState('#6366f1');

  // Frontend Action for theme color change
  useCopilotAction({
    name: 'setThemeColor',
    description: 'Set the theme color of the application UI',
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

  // Authenticated - show CopilotKit chat interface with Mastra features
  return (
    <main style={{ '--copilot-kit-primary-color': themeColor } as React.CSSProperties & { '--copilot-kit-primary-color': string }}>
      <MainContent 
        themeColor={themeColor}
        session={session}
        onSignOut={() => signOut()}
      />
      <CopilotSidebar
        clickOutsideToClose={false}
        defaultOpen={true}
        labels={{
          title: "AI Assistant",
          initial: "👋 こんにちは！CopilotKit × Cognito × Mastraが統合されたAIアシスタントです。\n\n以下を試してみてください：\n- **テーマ変更**: 「テーマをオレンジ色に変更して」\n- **天気情報**: 「サンフランシスコの天気を教えて」\n- **Proverbs**: 「AIについてのことわざを書いて」\n\n天気情報は動的なUIで表示されます！"
        }}
      />
    </main>
  );
}

function MainContent({ 
  themeColor,
  session,
  onSignOut 
}: { 
  themeColor: string;
  session: any;
  onSignOut: () => void;
}) {
  const { state, setState } = useCoAgent<AgentStateType>({
    name: "weatherAgent",
    initialState: {
      proverbs: [
        "CopilotKit may be new, but it's the best thing since sliced bread.",
      ],
    },
  });

  useCopilotAction({
    name: "weatherTool",
    description: "Get the weather for a given location.",
    available: "frontend",
    parameters: [
      { name: "location", type: "string", required: true },
    ],
    render: ({ args, result, status }) => {
      return <WeatherCard 
        location={args.location} 
        themeColor={themeColor} 
        result={result} 
        status={status}
      />
    },
  });

  return (
    <div
      style={{ backgroundColor: themeColor }}
      className="h-screen w-screen flex justify-center items-center flex-col transition-colors duration-300"
    >
      <div className="bg-white/20 backdrop-blur-md p-8 rounded-2xl shadow-xl max-w-2xl w-full">
        <div className="flex justify-between items-start mb-4">
          <div>
            <h1 className="text-4xl font-bold text-white mb-2">🪁 Proverbs</h1>
            <p className="text-gray-200 italic">Mastra-powered AI Agent with Cognito Auth</p>
          </div>
          <button
            onClick={onSignOut}
            className="bg-red-500/80 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-all"
          >
            Sign out
          </button>
        </div>
        
        <hr className="border-white/20 my-6" />
        
        <div className="flex flex-col gap-3">
          {state.proverbs?.map((proverb, index) => (
            <div 
              key={index} 
              className="bg-white/15 p-4 rounded-xl text-white relative group hover:bg-white/20 transition-all"
            >
              <p className="pr-8">{proverb}</p>
              <button 
                onClick={() => setState({
                  ...state,
                  proverbs: state.proverbs?.filter((_, i) => i !== index),
                })}
                className="absolute right-3 top-3 opacity-0 group-hover:opacity-100 transition-opacity 
                  bg-red-500 hover:bg-red-600 text-white rounded-full h-6 w-6 flex items-center justify-center"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
        
        {state.proverbs?.length === 0 && <p className="text-center text-white/80 italic my-8">
          No proverbs yet. Ask the assistant to add some!
        </p>}
        
        <AuthInfoTable session={session} />
      </div>
    </div>
  );
}

// Weather card component with Generative UI
function WeatherCard({ 
  location, 
  themeColor, 
  result, 
  status 
}: { 
  location?: string, 
  themeColor: string, 
  result: WeatherToolResult, 
  status: "inProgress" | "executing" | "complete" 
}) {
  if (status !== "complete") {
    return (
      <div 
        className="rounded-xl shadow-xl mt-6 mb-4 max-w-md w-full"
        style={{ backgroundColor: themeColor }}
      >
        <div className="bg-white/20 p-4 w-full">
          <p className="text-white animate-pulse">Loading weather for {location}...</p>
        </div>
      </div>
    )
  }

  return (
    <div
      style={{ backgroundColor: themeColor }}
      className="rounded-xl shadow-xl mt-6 mb-4 max-w-md w-full"
    >
      <div className="bg-white/20 p-4 w-full">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold text-white capitalize">{location}</h3>
            <p className="text-white">Current Weather</p>
          </div>
          <WeatherIcon conditions={result.conditions} />         
        </div>
        
        <div className="mt-4 flex items-end justify-between">
          <div className="text-3xl font-bold text-white">
            <span className="">
              {result.temperature}° C
            </span>
            <span className="text-sm text-white/50">
              {" / "}
              {((result.temperature * 9) / 5 + 32).toFixed(1)}° F
            </span>
          </div>
          <div className="text-sm text-white">{result.conditions}</div>
        </div>
        
        <div className="mt-4 pt-4 border-t border-white">
          <div className="grid grid-cols-3 gap-2 text-center">
            <div>
              <p className="text-white text-xs">Humidity</p>
              <p className="text-white font-medium">{result.humidity}%</p>
            </div>
            <div>
              <p className="text-white text-xs">Wind</p>
              <p className="text-white font-medium">{result.windSpeed} mph</p>
            </div>
            <div>
              <p className="text-white text-xs">Feels Like</p>
              <p className="text-white font-medium">{result.feelsLike}°</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function WeatherIcon({ conditions }: { conditions: string }) {
  if (!conditions) return null;

  if (
    conditions.toLowerCase().includes("clear") ||
    conditions.toLowerCase().includes("sunny")
  ) {
    return <SunIcon />;
  }
  
  if (
    conditions.toLowerCase().includes("rain") ||
    conditions.toLowerCase().includes("drizzle") ||
    conditions.toLowerCase().includes("snow") ||
    conditions.toLowerCase().includes("thunderstorm")
  ) {
    return <RainIcon />;
  } 
  
  if (
    conditions.toLowerCase().includes("fog") ||
    conditions.toLowerCase().includes("cloud") ||
    conditions.toLowerCase().includes("overcast")
  ) {
    return <CloudIcon />;
  }

  return <CloudIcon />;
}

function SunIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-14 h-14 text-yellow-200">
      <circle cx="12" cy="12" r="5" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" strokeWidth="2" stroke="currentColor" />
    </svg>
  );
}

function RainIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-14 h-14 text-blue-200">
      <path d="M7 15a4 4 0 0 1 0-8 5 5 0 0 1 10 0 4 4 0 0 1 0 8H7z" fill="currentColor" opacity="0.8"/>
      <path d="M8 18l2 4M12 18l2 4M16 18l2 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" fill="none"/>
    </svg>
  );
}

function CloudIcon() {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-14 h-14 text-gray-200">
      <path d="M7 15a4 4 0 0 1 0-8 5 5 0 0 1 10 0 4 4 0 0 1 0 8H7z" fill="currentColor"/>
    </svg>
  );
}

// JWT Decode Helper
function decodeJWT(token: string) {
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
}

// Truncate Token Helper
function truncateToken(token: string, startChars = 20, endChars = 20): string {
  if (!token || token.length <= startChars + endChars) return token;
  return `${token.substring(0, startChars)}...${token.substring(token.length - endChars)}`;
}

// Auth Info Table Component
function AuthInfoTable({ session }: { session: any }) {
  const idTokenDecoded = session.idToken ? decodeJWT(session.idToken) : null;
  const accessTokenDecoded = session.accessToken ? decodeJWT(session.accessToken) : null;

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString('ja-JP');
  };

  const getTimeRemaining = (exp: number) => {
    const now = Math.floor(Date.now() / 1000);
    const remaining = exp - now;
    if (remaining <= 0) return '期限切れ';
    const minutes = Math.floor(remaining / 60);
    const seconds = remaining % 60;
    return `${minutes}分${seconds}秒`;
  };

  const TableRow = ({ label, value, mono = false }: { label: string; value: string | React.ReactNode; mono?: boolean }) => (
    <tr className="border-b border-white/10 last:border-0">
      <td className="py-2 pr-4 text-white/70 font-medium whitespace-nowrap">{label}</td>
      <td className={`py-2 text-white/90 break-all ${mono ? 'font-mono text-xs' : ''}`}>{value}</td>
    </tr>
  );

  return (
    <div className="mt-6">
      <h3 className="text-white/90 text-sm font-semibold mb-3">
        🔐 認証情報（AgentCore Runtime送信用）
      </h3>
      <div className="bg-white/10 rounded-lg p-4 space-y-4 max-h-64 overflow-y-auto">
        {/* User Information */}
        <div>
          <h4 className="text-white/80 text-xs font-semibold mb-2 uppercase">👤 User Info</h4>
          <table className="w-full text-sm">
            <tbody>
              <TableRow label="User ID (sub)" value={idTokenDecoded?.sub || 'N/A'} mono />
              <TableRow label="Email" value={idTokenDecoded?.email || session.user?.email || 'N/A'} />
              <TableRow label="Email Verified" value={idTokenDecoded?.email_verified ? '✅' : '❌'} />
              <TableRow label="Cognito Username" value={idTokenDecoded?.['cognito:username'] || 'N/A'} mono />
            </tbody>
          </table>
        </div>

        {/* Token Information */}
        <div>
          <h4 className="text-white/80 text-xs font-semibold mb-2 uppercase">🎫 Token Info</h4>
          <table className="w-full text-sm">
            <tbody>
              <TableRow label="ID Token" value={session.idToken ? truncateToken(session.idToken) : 'N/A'} mono />
              <TableRow label="Access Token" value={session.accessToken ? truncateToken(session.accessToken) : 'N/A'} mono />
              <TableRow 
                label="発行日時 (iat)" 
                value={idTokenDecoded?.iat ? formatDate(idTokenDecoded.iat) : 'N/A'} 
              />
              <TableRow 
                label="有効期限 (exp)" 
                value={idTokenDecoded?.exp ? formatDate(idTokenDecoded.exp) : 'N/A'} 
              />
              <TableRow 
                label="残り有効時間" 
                value={idTokenDecoded?.exp ? getTimeRemaining(idTokenDecoded.exp) : 'N/A'} 
              />
            </tbody>
          </table>
        </div>

        {/* Authorization Information */}
        <div>
          <h4 className="text-white/80 text-xs font-semibold mb-2 uppercase">🔒 Authorization Info</h4>
          <table className="w-full text-sm">
            <tbody>
              <TableRow label="Issuer (iss)" value={idTokenDecoded?.iss || 'N/A'} mono />
              <TableRow label="Audience (aud)" value={idTokenDecoded?.aud || 'N/A'} mono />
              <TableRow label="Token Use" value={idTokenDecoded?.token_use || accessTokenDecoded?.token_use || 'N/A'} />
              <TableRow 
                label="Auth Time" 
                value={idTokenDecoded?.auth_time ? formatDate(idTokenDecoded.auth_time) : 'N/A'} 
              />
              {idTokenDecoded?.['cognito:groups'] && (
                <TableRow 
                  label="Cognito Groups" 
                  value={Array.isArray(idTokenDecoded['cognito:groups']) 
                    ? idTokenDecoded['cognito:groups'].join(', ') 
                    : idTokenDecoded['cognito:groups']} 
                />
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
