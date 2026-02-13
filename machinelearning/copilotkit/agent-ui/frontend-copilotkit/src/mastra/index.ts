import { Mastra } from "@mastra/core/mastra";
import { weatherAgent } from "./agents";
import { ConsoleLogger, LogLevel } from "@mastra/core/logger";

const LOG_LEVEL = process.env.LOG_LEVEL as LogLevel || "info";

export const mastra = new Mastra({
  agents: { 
    weatherAgent
  },
  // storage: LibSQLStore removed - Lambda環境でネイティブバイナリ問題を回避
  // Mastraはデフォルトでインメモリストレージを使用
  logger: new ConsoleLogger({
    level: LOG_LEVEL,
  }),
});
