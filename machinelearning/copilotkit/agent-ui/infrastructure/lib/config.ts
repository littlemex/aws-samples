import * as path from 'path';
import * as fs from 'fs';

// 環境に応じて.envファイルを選択して読み込み
const loadEnvironmentConfig = () => {
  // NODE_ENVから環境名を取得（デフォルトは'production'）
  const envName = process.env.NODE_ENV || 'production';
  
  // 環境ファイルのパス: .env.{環境名}
  const envFile = `.env.${envName}`;
  const envPath = path.resolve(__dirname, '..', envFile);
  
  // フォールバック: .envファイル（後方互換性のため）
  const fallbackEnvFile = '.env';
  const fallbackEnvPath = path.resolve(__dirname, '..', fallbackEnvFile);
  
  try {
    // まず.env.{環境名}を試す
    if (fs.existsSync(envPath)) {
      console.log(`Loading environment from: ${envFile}`);
      const envContent = fs.readFileSync(envPath, 'utf-8');
      
      // 環境変数を解析して設定
      envContent.split('\n').forEach(line => {
        if (line.trim() && !line.startsWith('#')) {
          const [key, ...valueParts] = line.split('=');
          const value = valueParts.join('=').trim();
          if (key && value && !process.env[key.trim()]) {
            process.env[key.trim()] = value;
          }
        }
      });
    } else if (fs.existsSync(fallbackEnvPath)) {
      // フォールバック: .envを読み込む
      console.log(`Loading environment from: ${fallbackEnvFile} (fallback)`);
      const envContent = fs.readFileSync(fallbackEnvPath, 'utf-8');
      
      // 環境変数を解析して設定
      envContent.split('\n').forEach(line => {
        if (line.trim() && !line.startsWith('#')) {
          const [key, ...valueParts] = line.split('=');
          const value = valueParts.join('=').trim();
          if (key && value && !process.env[key.trim()]) {
            process.env[key.trim()] = value;
          }
        }
      });
    } else {
      console.warn(`Environment file not found: ${envFile} or ${fallbackEnvFile}`);
    }
  } catch (error) {
    console.warn(`Failed to load environment file: ${envFile}`, error);
  }
};

// 環境設定を読み込み
loadEnvironmentConfig();

export interface AppConfig {
  // 環境設定
  env: {
    account: string;
    region: string;
    environment: 'local' | 'production';
  };
  
  // Cognito設定
  cognito: {
    projectName: string;
    clientSuffix: string;       // Client名のサフィックス
    appName: string;           // アプリケーション名
    callbackUrls: string[];    // コールバックURL一覧
    logoutUrls: string[];      // ログアウトURL一覧
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
  
  // NextAuth.js設定
  nextAuth: {
    url?: string;
    secret: string;
    debugMode: boolean;
  };
}

export const config: AppConfig = {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT || '',
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
    environment: (process.env.ENVIRONMENT as 'local' | 'production') || 'production',
  },
  
  cognito: {
    projectName: 'copilotkit-agentcore',
    clientSuffix: process.env.COGNITO_CLIENT_SUFFIX || 'default',
    appName: process.env.APP_NAME || 'Default',
    // コールバックURLとログアウトURLを環境変数から読み込み（カンマ区切り）
    callbackUrls: process.env.COGNITO_CALLBACK_URLS 
      ? process.env.COGNITO_CALLBACK_URLS.split(',').map(url => url.trim())
      : [
          'http://localhost:3000/api/auth/callback/cognito',
          'http://localhost:3000',
          'http://localhost:3001/api/auth/callback/cognito',
          'http://localhost:13001/api/auth/callback/cognito', // SSM Port Forwarding
        ],
    logoutUrls: process.env.COGNITO_LOGOUT_URLS
      ? process.env.COGNITO_LOGOUT_URLS.split(',').map(url => url.trim())
      : [
          'http://localhost:3000',
          'http://localhost:3001',
          'http://localhost:13001',
        ],
  },
  
  frontend: {
    nextjsAppPath: `../../${process.env.DEPLOY_FRONTEND_DIR || 'frontend'}`,
  },
  
  lambda: {
    memorySize: 512,
    timeout: 30,
    runtime: 'nodejs20.x',
    // Lambda Web Adapter Layer ARN - 動的にリージョンを取得
    webAdapterLayerArn: `arn:aws:lambda:${process.env.CDK_DEFAULT_REGION || 'us-east-1'}:753240598075:layer:LambdaAdapterLayerX86:20`,
  },
  
  nextAuth: {
    url: process.env.NEXTAUTH_URL || undefined,
    secret: process.env.NEXTAUTH_SECRET || 'PLEASE_CHANGE_THIS_SECRET',
    debugMode: process.env.DEBUG_MODE === 'true',
  },
};
