import * as cdk from '@aws-cdk/core';
import * as lambda from '@aws-cdk/aws-lambda-nodejs';
import { ServicePrincipal } from '@aws-cdk/aws-iam';
import { RestApi, LambdaIntegration, Cors, Stage, Deployment } from '@aws-cdk/aws-apigateway';
import { join } from 'path';

export const NODE_LAMBDA_DIR = `${process.cwd()}/lambda`;
const LAMBDA_FUNCTION_TIMEOUT = 5;

interface StageContext {
  env: string;
}

export class CdkLangTypescriptApigatewayLambdaNodejsSampleStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    
    // get context
    const env: string = this.node.tryGetContext("stage");
    const context: StageContext = this.node.tryGetContext(env);
    const apiversion: string = this.node.tryGetContext("apiversion");

    const SampleFunction = new lambda.NodejsFunction(this, 'SampleFunction', {
      entry: `${NODE_LAMBDA_DIR}/index.ts`,
      timeout: cdk.Duration.seconds(LAMBDA_FUNCTION_TIMEOUT),
      bundling: {
        dockerImage: cdk.DockerImage.fromBuild(NODE_LAMBDA_DIR),
      },
    });
    SampleFunction.grantInvoke(new ServicePrincipal('apigateway.amazonaws.com'));
    
    const api = new RestApi(this, "testRestApi", {
      restApiName: "TestRestAPI",
      defaultCorsPreflightOptions: {
        allowOrigins: Cors.ALL_ORIGINS,
        allowMethods: Cors.ALL_METHODS,
        allowHeaders: Cors.DEFAULT_HEADERS,
        statusCode: 200,
      },
      deploy: true,
      deployOptions: {
        stageName: apiversion,
      }
    });
    const items = api.root.addResource('items');
    items.addMethod('GET', new LambdaIntegration(SampleFunction), {
      apiKeyRequired: false,
    });  // GET /items/
    
    const deployment = new Deployment(this, 'apiItemsDeployment', {
      api: api,
    });
    const apistage = new Stage(this, 'apiItemsStage', {
      deployment: deployment,
      stageName: "dev",
    });

    // outputs
    new cdk.CfnOutput(this, 'env', {value: context.env});
    new cdk.CfnOutput(this, 'API Gateway URL', {value: api.url});

    // console.log
    console.log("NODE_LAMBDA_DIR:", NODE_LAMBDA_DIR);
    console.log("apiversion:", apiversion)
  }
}