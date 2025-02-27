#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AiGatewayStack } from '../lib/ai-gateway-stack';

const app = new cdk.App();
new AiGatewayStack(app, 'AiGatewayStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  description: 'AI Gateway with AppSync, Cognito, and Bedrock integration',
});