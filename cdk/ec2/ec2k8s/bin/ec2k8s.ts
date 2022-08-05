#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { Ec2K8sStack } from '../lib/ec2k8s-stack';

const app = new cdk.App();
new Ec2K8sStack(app, 'Ec2K8sStack', {
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION
    },
});
