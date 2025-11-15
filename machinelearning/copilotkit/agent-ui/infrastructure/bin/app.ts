#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CognitoStack } from '../lib/cognito-stack';
import { NextjsStack } from '../lib/nextjs-stack';
import { config } from '../lib/config';

const app = new cdk.App();

// Cognito Stack (always deployed first)
const cognitoStack = new CognitoStack(app, 'CopilotKitCognitoStack', {
  config: config,
  env: config.env,
  description: 'Cognito User Pool and Client for CopilotKit Agent UI',
});

// Next.js Frontend Stack using cdk-nextjs (deployed second)
// 環境変数DEPLOY_FRONTENDでNextjsStackの作成を制御
const deployFrontend = process.env.DEPLOY_FRONTEND !== 'false';

if (deployFrontend) {
  const nextjsStack = new NextjsStack(app, 'CopilotKitNextjsStack', {
    config: config,
    env: config.env,
    description: 'Next.js frontend using cdklabs/cdk-nextjs with Lambda Function URL + CloudFront',
    // Cognito設定は後で環境変数として追加
    cognitoUserPoolId: cognitoStack.userPool.userPoolId,
    cognitoUserPoolClientId: cognitoStack.userPoolClient.userPoolClientId,
    cognitoIssuerUrl: `https://cognito-idp.${config.env.region}.amazonaws.com/${cognitoStack.userPool.userPoolId}`,
  });

  // 依存関係設定：Next.jsスタックはCognitoスタック後にデプロイ
  nextjsStack.addDependency(cognitoStack);
}

// Tags
cdk.Tags.of(app).add('Project', 'CopilotKit');
cdk.Tags.of(app).add('Environment', 'Development');
