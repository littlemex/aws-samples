import { createAmazonBedrock } from "@ai-sdk/amazon-bedrock";
import { fromNodeProviderChain } from "@aws-sdk/credential-providers";
import { Agent } from "@mastra/core/agent";
import { weatherTool } from "@/mastra/tools";
import { z } from "zod";

// AWS Credential Provider Chainを使用
// ローカル: ~/.aws/credentials から自動読み込み
// 本番: Lambda実行ロールから自動取得
const bedrock = createAmazonBedrock({
  region: process.env.AWS_REGION || 'us-east-1',
  credentialProvider: fromNodeProviderChain(),
});

export const AgentState = z.object({
  proverbs: z.array(z.string()).default([]),
});

export const weatherAgent = new Agent({
  name: "Weather Agent",
  tools: { weatherTool },
  model: bedrock("us.anthropic.claude-sonnet-4-20250514-v1:0"),
  instructions: "You are a helpful assistant.",
});
