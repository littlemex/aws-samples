/**
 * Mastraエージェントの基本情報
 * MastraのlistAgentsから取得される情報
 */
export interface MastraAgent {
  id: string;
  name: string;
  description?: string;
  instructions?: string;
  provider?: string;
  modelId?: string;
  tools: Record<string, any>;
  workflows: Record<string, any>;
}

/**
 * ユーザーエージェント設定（Phase 3: 複数Runtime対応）
 * DynamoDBに保存されるユーザーごとの設定
 * 
 * 注意: DynamoDBのagentId（SK）には "runtimeId#agentId" 形式の値を保存
 */
export interface UserAgentSetting {
  userId: string;          // PK
  agentId: string;         // SK: DynamoDBスキーマ名（実際の値は "runtimeId#agentId"）
  agentKey: string;        // アプリケーション用: "runtimeId#agentId"
  runtimeId: string;       // Runtime識別子
  enabled: boolean;
  enabledAt?: string;
  lastUsedAt?: string;
  usageCount?: number;
  createdAt: string;
  updatedAt: string;
}

/**
 * フロントエンドで表示するエージェント情報（Phase 3: 複数Runtime対応）
 * MastraAgentとUserAgentSettingをマージしたもの
 */
export interface Agent {
  id: string;              // agentKey: "runtimeId#agentId"
  agentId: string;         // 元のエージェントID
  runtimeId: string;       // Runtime識別子
  name: string;
  description: string;
  icon: string;
  type: 'system' | 'user';
  runtimeUrl: string;
  runtimeName?: string;    // Runtime表示名
  agentName: string;
  enabled: boolean;
  status: 'available' | 'unavailable' | 'error';
  editable: boolean;
  // オプション情報
  provider?: string;
  modelId?: string;
  lastUsedAt?: string;
  usageCount?: number;
}

/**
 * エージェント一覧APIのレスポンス
 */
export interface ListAgentsResponse {
  agents: Agent[];
  count: number;
}

/**
 * エージェント有効化/無効化APIのリクエスト
 */
export interface ToggleAgentRequest {
  enabled: boolean;
}

/**
 * エージェント有効化/無効化APIのレスポンス
 */
export interface ToggleAgentResponse {
  success: boolean;
  agent: UserAgentSetting;
}
