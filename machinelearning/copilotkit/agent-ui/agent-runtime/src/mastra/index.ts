import { Mastra } from "@mastra/core/mastra";
import { ConsoleLogger, LogLevel } from "@mastra/core/logger";
import { registerApiRoute } from "@mastra/core/server";
import { weatherAgent } from "./agents/index.js";
import 'dotenv/config';

const LOG_LEVEL = (process.env.LOG_LEVEL as LogLevel) || "info";

// シンプルなMastra設定（server.apiRoutesなし）
export const mastra = new Mastra({
  agents: { 
    weatherAgent
  },
  logger: new ConsoleLogger({
    level: LOG_LEVEL,
  }),
  server: {
    port: parseInt(process.env.PORT || '8081'),
    host: "0.0.0.0",
  },
});
