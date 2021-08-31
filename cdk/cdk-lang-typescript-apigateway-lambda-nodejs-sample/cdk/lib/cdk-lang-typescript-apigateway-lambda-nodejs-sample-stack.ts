import * as cdk from '@aws-cdk/core';
import * as lambda from '@aws-cdk/aws-lambda-nodejs';
import { join } from 'path';

export const NODE_LAMBDA_DIR = `${process.cwd()}/lambda`;
console.log("NODE_LAMBDA_DIR:", NODE_LAMBDA_DIR);

interface StageContext {
  env: string;
}

export class CdkLangTypescriptApigatewayLambdaNodejsSampleStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    new lambda.NodejsFunction(this, 'handler', {
      entry: `${NODE_LAMBDA_DIR}/index.ts`,
      bundling: {
        dockerImage: cdk.DockerImage.fromBuild(NODE_LAMBDA_DIR),
      },
    });
    const env: string = this.node.tryGetContext("stage");
    const context: StageContext = this.node.tryGetContext(env);

    // outputs
    new cdk.CfnOutput(this, 'env', {value: context.env});
  }
}