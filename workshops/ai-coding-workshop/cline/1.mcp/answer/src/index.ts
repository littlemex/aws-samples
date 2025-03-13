#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';

interface WeatherData {
  city: string;
  weather: 'sunny' | 'rainy' | 'cloudy';
  temperature: number;
}

const weatherData: { [key: string]: WeatherData } = {
  '東京': { city: '東京', weather: 'sunny', temperature: 25 },
  '大阪': { city: '大阪', weather: 'sunny', temperature: 26 },
  '福岡': { city: '福岡', weather: 'sunny', temperature: 24 },
  'ロンドン': { city: 'ロンドン', weather: 'rainy', temperature: 15 },
  'シアトル': { city: 'シアトル', weather: 'rainy', temperature: 14 },
  'パリ': { city: 'パリ', weather: 'cloudy', temperature: 18 },
  'ニューヨーク': { city: 'ニューヨーク', weather: 'cloudy', temperature: 20 },
};

class WeatherServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'weather-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'get_weather',
          description: '指定された都市の天気情報を取得します',
          inputSchema: {
            type: 'object',
            properties: {
              city: {
                type: 'string',
                description: '都市名',
              },
            },
            required: ['city'],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      if (request.params.name !== 'get_weather') {
        throw new McpError(
          ErrorCode.MethodNotFound,
          `Unknown tool: ${request.params.name}`
        );
      }

      if (!request.params.arguments) {
        throw new McpError(
          ErrorCode.InvalidParams,
          'Arguments are required'
        );
      }

      const args = request.params.arguments as { city: string };
      const city = args.city;
      const weather = weatherData[city as keyof typeof weatherData];

      if (!weather) {
        return {
          content: [
            {
              type: 'text',
              text: `City not found: ${city}`,
            },
          ],
          isError: true,
        };
      }

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(weather, null, 2),
          },
        ],
      };
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Weather MCP server running on stdio');
  }
}

const server = new WeatherServer();
server.run().catch(console.error);