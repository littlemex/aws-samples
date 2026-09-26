import { Mastra } from "@mastra/core/mastra";
import { ConsoleLogger, LogLevel } from "@mastra/core/logger";
import { registerApiRoute } from "@mastra/core/server";
import { weatherAgent } from "./agents/index.js";
import 'dotenv/config';

const LOG_LEVEL = (process.env.LOG_LEVEL as LogLevel) || "info";

// AgentCore Runtime互換のMastra設定
export const mastra = new Mastra({
  agents: { 
    weatherAgent
  },
  logger: new ConsoleLogger({
    level: LOG_LEVEL,
  }),
  server: {
    port: parseInt(process.env.PORT || '8080'),
    host: "0.0.0.0",
    apiRoutes: [
      // AgentCore Runtime必須エンドポイント: /invocations
      registerApiRoute("/invocations", {
        method: "POST",
        handler: async (c) => {
          try {
            const body = await c.req.json();
            const { prompt, messages, agentName = 'weatherAgent' } = body;
            
            // promptまたはmessages形式に対応
            const agentMessages = messages || [{ role: "user", content: prompt }];
            
            if (!agentMessages || agentMessages.length === 0) {
              return c.json({ error: 'Prompt or messages required' }, 400);
            }

            const mastra = c.get('mastra');
            const agent = mastra.getAgent(agentName);
            
            console.log('Invocation request:', {
              agentName,
              messageCount: agentMessages.length,
              timestamp: new Date().toISOString()
            });

            const result = await agent.generate(agentMessages);

            return c.json({ 
              response: result.text,
              usage: result.usage,
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
      
      // AgentCore Runtime必須エンドポイント: /ping
      registerApiRoute("/ping", {
        method: "GET",
        handler: async (c) => {
          const healthStatus = {
            status: 'Healthy',
            time_of_last_update: Math.floor(Date.now() / 1000),
            timestamp: new Date().toISOString(),
          };
          
          console.log('Health check:', healthStatus);
          return c.json(healthStatus);
        },
      }),
    ],
  },
});
