import { DynamoDBClient, ScanCommand, GetItemCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const tableName = process.env.RUNTIMES_TABLE_NAME || 'copilotkit-runtimes-prod';

export interface OAuthConfig {
  issuerUrl: string;
  discoveryUrl: string;
  clientId: string;
  audience: string;
  requiredScopes?: string[];
  clientSecretArn?: string;
}

export interface SigV4Config {
  service: string;
  region: string;
}

export interface Runtime {
  runtimeId: string;
  runtimeName: string;
  runtimeUrl: string;
  region: string;
  authType: 'none' | 'oauth' | 'sigv4';
  status: 'active' | 'inactive' | 'error';
  oauthConfig?: OAuthConfig;
  sigv4Config?: SigV4Config;
  createdAt: string;
  updatedAt: string;
  deployedBy?: string;
  description?: string;
}

/**
 * Get all runtimes from DynamoDB
 */
export async function getAllRuntimes(): Promise<Runtime[]> {
  try {
    const command = new ScanCommand({
      TableName: tableName,
    });

    const response = await client.send(command);
    
    if (!response.Items) {
      return [];
    }

    const runtimes = response.Items.map((item) => unmarshall(item) as Runtime);
    
    // Filter to only return active runtimes by default
    return runtimes.filter((runtime) => runtime.status === 'active');
  } catch (error) {
    console.error('Error fetching runtimes:', error);
    return [];
  }
}

/**
 * Get a specific runtime by ID
 */
export async function getRuntimeById(runtimeId: string): Promise<Runtime | null> {
  try {
    const command = new GetItemCommand({
      TableName: tableName,
      Key: {
        runtimeId: { S: runtimeId },
      },
    });

    const response = await client.send(command);
    
    if (!response.Item) {
      return null;
    }

    return unmarshall(response.Item) as Runtime;
  } catch (error) {
    console.error(`Error fetching runtime ${runtimeId}:`, error);
    return null;
  }
}

/**
 * Fetch agents from a specific runtime
 */
export async function fetchAgentsFromRuntime(
  runtime: Runtime,
  accessToken?: string
): Promise<Record<string, any>> {
  try {
    const headers = new Headers({
      'Content-Type': 'application/json',
    });

    // Set authentication headers based on runtime auth type
    switch (runtime.authType) {
      case 'none':
        // No authentication required
        break;

      case 'oauth':
        // JWT Token passthrough
        if (accessToken) {
          headers.set('Authorization', `Bearer ${accessToken}`);
        } else {
          console.warn(`Runtime ${runtime.runtimeId} requires OAuth but no token provided`);
          return {};
        }
        break;

      case 'sigv4':
        // TODO: Implement SigV4 signing in the future
        console.warn(`SigV4 authentication not yet implemented for ${runtime.runtimeId}`);
        return {};

      default:
        console.warn(`Unknown auth type: ${runtime.authType}`);
        return {};
    }

    // Fetch agents from the runtime
    const response = await fetch(`${runtime.runtimeUrl}/api/agents`, {
      headers,
      signal: AbortSignal.timeout(5000), // 5 second timeout
    });

    if (!response.ok) {
      console.error(
        `Failed to fetch agents from ${runtime.runtimeId}: ${response.status} ${response.statusText}`
      );
      return {};
    }

    const agents = await response.json();
    return agents;
  } catch (error) {
    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        console.error(`Timeout fetching agents from ${runtime.runtimeId}`);
      } else {
        console.error(`Error fetching agents from ${runtime.runtimeId}:`, error.message);
      }
    }
    return {};
  }
}
