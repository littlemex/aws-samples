import * as cdk from '@aws-cdk/core';
import { CfnSubnet, CfnVPC } from '@aws-cdk/aws-ec2';

export class Subnet {
    public public1a: CfnSubnet;

    private readonly vpc: CfnVPC;

    constructor(vpc: CfnVPC) {
        this.vpc = vpc;
    };

    public createResources(scope: cdk.Construct) {
        this.public1a = new CfnSubnet(scope, 'SubnetPublic1a', {
            cidrBlock: '10.1.11.0/24',
            vpcId: this.vpc.ref,
            availabilityZone: 'ap-northeast-1a',
            tags: [{ key: 'Name', value: 'sample-cdk-subnet-public-1a' }]
        })
   }
}