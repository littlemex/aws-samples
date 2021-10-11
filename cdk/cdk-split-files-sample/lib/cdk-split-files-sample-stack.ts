import * as cdk from '@aws-cdk/core';
import { Vpc } from './resources/vpc';
import { Subnet } from './resources/subnet';

export class CdkSplitFilesSampleStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    // VPC
    const vpc = new Vpc();
    vpc.createResources(this);
    // Subnet
    const subnet = new Subnet(vpc.vpc);
    subnet.createResources(this);  
  }
}
