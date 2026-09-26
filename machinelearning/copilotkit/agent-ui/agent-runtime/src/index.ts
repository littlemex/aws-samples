import { Mastra, Agent, createTool } from '@mastra/core';
import { registerApiRoute } from '@mastra/core/server';
import { createAmazonBedrock } from "@ai-sdk/amazon-bedrock";
import { fromNodeProviderChain } from "@aws-sdk/credential-providers";
import { z } from 'zod';
import 'dotenv/config';

// Amazon Bedrock設定
const bedrock = createAmazonBedrock({
  region: process.env.AWS_REGION || 'us-east-1',
  credentialProvider: fromNodeProviderChain(),
});

// Weather Tool定義
const weatherTool = createTool({
  id: 'get-weather',
  description: 'Get the current weather for a location',
  inputSchema: z.object({
    location: z.string().describe('The location to get weather for'),
  }),
  execute: async ({ context }) => {
    const { location } = context;
    
    // 実際のAPIを呼ぶ代わりに、モックデータを返す
    const mockWeather = {
      location,
      temperature: Math.floor(Math.random() * 30) + 10, // 10-40°C
      condition: ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy'][Math.floor(Math.random() * 4)],
      humidity: Math.floor(Math.random() * 40) + 40, // 40-80%
      windSpeed: Math.floor(Math.random() * 20) + 5, // 5-25 km/h
      timestamp: new Date().toISOString()
    };
    
    console.log('Weather tool executed:', mockWeather);
    
    return {
      location: mockWeather.location,
      temperature: `${mockWeather.temperature}°C`,
      condition: mockWeather.condition,
      humidity: `${mockWeather.humidity}%`,
      windSpeed: `${mockWeather.windSpeed} km/h`,
      timestamp: mockWeather.timestamp
    };
  },
});

// Weather Agent定義
const weatherAgent = new Agent({
  name: 'weatherAgent',
  instructions: 'You are a helpful weather assistant. Use the get-weather tool to provide current weather information for requested locations. Always be friendly and provide clear, concise weather updates.',
  model: bedrock("us.anthropic.claude-sonnet-4-20250514-v1:0"),
  tools: { weatherTool },
});

// 開発環境チェック
const isDevelopment = process.env.NODE_ENV !== 'production';
console.log('🔍 Environment Check:', {
  NODE_ENV: process.env.NODE_ENV,
  isDevelopment,
  timestamp: new Date().toISOString()
});

// Mastra設定
export const mastra = new Mastra({
  agents: {
    weatherAgent
  },
  server: {
    port: 8080,
    host: "0.0.0.0",
    apiRoutes: [
      // AgentCore Runtime 必須エンドポイント: /invocations
      registerApiRoute("/invocations", {
        method: "POST",
        requiresAuth: false,  // 開発環境では認証不要
        handler: async (c) => {
          try {
            const body = await c.req.json();
            const { prompt, agentName = 'weatherAgent' } = body;
            
            if (!prompt) {
              return c.json({ error: 'Prompt is required' }, 400);
            }

            // JWT取得（ログ出力のみ、検証はAgentCore Identityが実施）
            const authHeader = c.req.header('authorization');
            console.log('Received invocation request:', {
              prompt: prompt.substring(0, 100),
              hasAuth: !!authHeader,
              agentName,
              timestamp: new Date().toISOString()
            });

            // エージェント実行
            const agent = mastra.getAgent(agentName);
            if (!agent) {
              return c.json({ error: `Agent '${agentName}' not found` }, 404);
            }

            const result = await agent.generate(prompt);

            console.log('Invocation successful:', {
              responseLength: result.text.length,
              timestamp: new Date().toISOString()
            });

            return c.json({ 
              response: result.text,
              timestamp: new Date().toISOString()
            });

          } catch (error: any) {
            console.error('Invocation error:', error);
            return c.json({ 
              error: 'Internal server error',
              details: error?.message || 'Unknown error'
            }, 500);
          }
        },
      }),
      
      // AgentCore Runtime 必須エンドポイント: /ping
      registerApiRoute("/ping", {
        method: "GET",
        requiresAuth: false,  // 認証不要
        handler: async (c) => {
          const healthStatus = {
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: '1.0.0',
            service: 'agent-runtime-mastra',
            agents: ['weatherAgent']
          };
          
          console.log('Health check requested:', healthStatus);
          return c.json(healthStatus);
        },
      }),

      // デバッグ用エンドポイント
      registerApiRoute("/debug", {
        method: "GET",
        requiresAuth: false,  // 認証不要
        handler: async (c) => {
          return c.json({
            environment: {
              NODE_ENV: process.env.NODE_ENV || 'development',
              AWS_REGION: process.env.AWS_REGION || 'us-east-1',
              isDevelopment
            },
            agents: {
              weatherAgent: {
                name: 'weatherAgent',
                model: 'us.anthropic.claude-sonnet-4-20250514-v1:0',
                tools: ['get-weather'],
                status: 'active'
              }
            },
            timestamp: new Date().toISOString()
          });
        },
      }),
    ],
  },
});

// サーバー開始
console.log('🚀 Mastra Agent Runtime initialized');
console.log('📍 Port: 8080');
console.log('📍 Host: 0.0.0.0');
console.log('🤖 Agent: weatherAgent');
console.log('🔧 Tools: get-weather');
console.log('🌐 Endpoints: /invocations, /ping, /debug');
