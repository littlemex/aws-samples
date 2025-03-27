#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { MlflowStack } from '../lib/mlflow-stack';

const app = new cdk.App();
new MlflowStack(app, 'MlflowStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'ap-northeast-1',
  },
});
