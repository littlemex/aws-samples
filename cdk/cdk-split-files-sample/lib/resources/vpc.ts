import * as cdk from '@aws-cdk/core';
import { CfnVPC } from '@aws-cdk/aws-ec2';

export class Vpc {
    public vpc: CfnVPC;

    constructor() {};

    public createResources(scope: cdk.Construct) {
        this.vpc = new CfnVPC(scope, 'Vpc', {
            cidrBlock: '10.1.0.0/16',
            tags: [{ key: 'SampleCdkVpc', value: 'sample-cdk-vpc' }]
        });
    }
}