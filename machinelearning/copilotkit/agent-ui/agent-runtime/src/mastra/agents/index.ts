import { Agent, createTool } from '@mastra/core';
import { createAmazonBedrock } from "@ai-sdk/amazon-bedrock";
import { fromNodeProviderChain } from "@aws-sdk/credential-providers";
import { z } from 'zod';

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
export const weatherAgent = new Agent({
  name: 'weatherAgent',
  instructions: 'You are a helpful weather assistant. Use the get-weather tool to provide current weather information for requested locations. Always be friendly and provide clear, concise weather updates.',
  model: bedrock("us.anthropic.claude-sonnet-4-20250514-v1:0"),
  tools: { weatherTool },
});
