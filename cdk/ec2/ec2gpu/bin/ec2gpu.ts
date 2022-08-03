#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { Ec2GpuStack } from '../lib/ec2gpu-stack';

const app = new cdk.App();
new Ec2GpuStack(app, 'Ec2GpuStack', {
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION
    },
});
