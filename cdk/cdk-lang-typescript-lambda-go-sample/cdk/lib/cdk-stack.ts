import * as cdk from '@aws-cdk/core';
import * as lambda from '@aws-cdk/aws-lambda-go';

export class CdkStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    new lambda.GoFunction(this, 'handler', {
        entry: '../lambda'
    })
  }

    private newMethod() {
        return this;
    }
}
