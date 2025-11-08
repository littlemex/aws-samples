export interface AppConfig {
  // 環境設定
  env: {
    account: string;
    region: string;
  };
  
  // Cognito設定
  cognito: {
    projectName: string;
    userPoolId?: string;        // CDK移行後は不要
    userPoolClientId?: string;  // CDK移行後は不要
    userPoolDomain?: string;    // CDK移行後は不要
  };
  
  // フロントエンドアプリ設定
  frontend: {
    nextjsAppPath: string;  // Next.jsアプリのパス
    domainName?: string;     // カスタムドメイン（オプション）
  };
  
  // Lambda設定
  lambda: {
    memorySize: number;
    timeout: number;
    runtime: string;
    webAdapterLayerArn: string;
  };
}

export const config: AppConfig = {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT || '',
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
  },
  
  cognito: {
    projectName: 'copilotkit-agentcore',
    // 固定値削除 - 新しいCognitoリソースを作成するため不要
  },
  
  frontend: {
    nextjsAppPath: '../../frontend',
  },
  
  lambda: {
    memorySize: 512,
    timeout: 30,
    runtime: 'nodejs20.x',
    // Lambda Web Adapter Layer ARN - 動的にリージョンを取得
    webAdapterLayerArn: `arn:aws:lambda:${process.env.CDK_DEFAULT_REGION || 'us-east-1'}:753240598075:layer:LambdaAdapterLayerX86:20`,
  },
};
