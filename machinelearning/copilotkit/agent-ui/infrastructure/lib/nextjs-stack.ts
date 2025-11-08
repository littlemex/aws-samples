import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { NextjsGlobalFunctions } from 'cdk-nextjs';
import { AppConfig } from './config';
import * as path from 'path';

export interface NextjsStackProps extends cdk.StackProps {
  config: AppConfig;
  cognitoUserPoolId?: string;
  cognitoUserPoolClientId?: string;
  cognitoIssuerUrl?: string;
}

export class NextjsStack extends cdk.Stack {
  public readonly nextjsApp: NextjsGlobalFunctions;

  constructor(scope: Construct, id: string, props: NextjsStackProps) {
    super(scope, id, props);

    // Next.jsアプリケーションのパス
    const nextjsAppPath = path.resolve(__dirname, props.config.frontend.nextjsAppPath);

    // NextjsGlobalFunctions construct
    this.nextjsApp = new NextjsGlobalFunctions(this, 'NextjsApp', {
      buildContext: nextjsAppPath,
      
      // ヘルスチェックパス
      healthCheckPath: '/api/health',
      
      // セキュリティ設定
      // Lambda Function URL + IAM Authを使用（デフォルトのNextjsGlobalFunctions設定）
      // これにより、CloudFrontを通じてのみアクセス可能になり、World Accessible問題を回避
    });

    // 環境変数設定（デプロイ後に追加）
    // NextAuth.js設定とCognito設定は後で追加する予定

    // 出力
    new cdk.CfnOutput(this, 'NextjsUrl', {
      value: this.nextjsApp.url,
      description: 'Next.js Application URL',
    });

    new cdk.CfnOutput(this, 'NextAuthCallbackUrl', {
      value: `${this.nextjsApp.url}/api/auth/callback/cognito`,
      description: 'NextAuth Cognito Callback URL',
    });

    // タグ付け
    cdk.Tags.of(this).add('Name', `${props.config.cognito.projectName}-nextjs`);
    cdk.Tags.of(this).add('Project', props.config.cognito.projectName);
    cdk.Tags.of(this).add('Environment', 'development');
  }
}
