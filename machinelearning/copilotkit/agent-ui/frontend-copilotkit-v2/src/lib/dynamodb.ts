import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { 
  DynamoDBDocumentClient, 
  QueryCommand, 
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand
} from '@aws-sdk/lib-dynamodb';
import type { UserAgentSetting } from '@/types/agent';

const client = new DynamoDBClient({
  region: process.env.AWS_REGION || 'us-east-1',
});

export const docClient = DynamoDBDocumentClient.from(client);

export const USER_AGENTS_TABLE_NAME = process.env.USER_AGENTS_TABLE_NAME || 'copilotkit-user-agents-prod';

/**
 * ユーザーの全エージェント設定を取得
 */
export async function getUserAgentSettings(userId: string): Promise<UserAgentSetting[]> {
  const result = await docClient.send(new QueryCommand({
    TableName: USER_AGENTS_TABLE_NAME,
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId,
    },
  }));
  
  return (result.Items || []) as UserAgentSetting[];
}

/**
 * 特定エージェントの設定を取得（Phase 3: 複数Runtime対応）
 * agentIdには "runtimeId#agentId" 形式の値を使用
 */
export async function getUserAgentSetting(
  userId: string, 
  agentKey: string
): Promise<UserAgentSetting | null> {
  const result = await docClient.send(new GetCommand({
    TableName: USER_AGENTS_TABLE_NAME,
    Key: {
      userId,
      agentId: agentKey, // agentIdフィールドにagentKeyを保存
    },
  }));
  
  return (result.Item as UserAgentSetting) || null;
}

/**
 * エージェント設定を保存/更新
 */
export async function putUserAgentSetting(setting: UserAgentSetting): Promise<void> {
  await docClient.send(new PutCommand({
    TableName: USER_AGENTS_TABLE_NAME,
    Item: setting,
  }));
}

/**
 * エージェントの有効化状態を切り替え（Phase 3: 複数Runtime対応）
 * agentIdフィールドにagentKey（runtimeId#agentId）を保存
 */
export async function toggleUserAgentEnabled(
  userId: string,
  agentKey: string,
  runtimeId: string,
  agentId: string,
  enabled: boolean
): Promise<UserAgentSetting> {
  const now = new Date().toISOString();
  
  // 既存の設定を取得
  const existing = await getUserAgentSetting(userId, agentKey);
  
  const setting: UserAgentSetting = {
    userId,
    agentId: agentKey, // DynamoDB SKにはagentKey（runtimeId#agentId）を保存
    agentKey,
    runtimeId,
    enabled,
    enabledAt: enabled ? now : existing?.enabledAt,
    lastUsedAt: existing?.lastUsedAt,
    usageCount: existing?.usageCount || 0,
    createdAt: existing?.createdAt || now,
    updatedAt: now,
  };
  
  await putUserAgentSetting(setting);
  
  return setting;
}

/**
 * エージェント使用時にカウンターを更新（Phase 3: 複数Runtime対応）
 */
export async function incrementAgentUsage(
  userId: string,
  agentKey: string
): Promise<void> {
  const now = new Date().toISOString();
  
  await docClient.send(new UpdateCommand({
    TableName: USER_AGENTS_TABLE_NAME,
    Key: { userId, agentId: agentKey }, // agentIdフィールドにagentKeyを使用
    UpdateExpression: 'SET lastUsedAt = :now, usageCount = if_not_exists(usageCount, :zero) + :inc, updatedAt = :now',
    ExpressionAttributeValues: {
      ':now': now,
      ':zero': 0,
      ':inc': 1,
    },
  }));
}

/**
 * エージェント設定を削除（Phase 3: 複数Runtime対応）
 */
export async function deleteUserAgentSetting(
  userId: string,
  agentKey: string
): Promise<void> {
  await docClient.send(new DeleteCommand({
    TableName: USER_AGENTS_TABLE_NAME,
    Key: { userId, agentId: agentKey }, // agentIdフィールドにagentKeyを使用
  }));
}
