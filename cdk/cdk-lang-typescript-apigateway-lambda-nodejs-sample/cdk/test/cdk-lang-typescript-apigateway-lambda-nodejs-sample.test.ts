import { expect as expectCDK, matchTemplate, MatchStyle } from '@aws-cdk/assert';
import * as cdk from '@aws-cdk/core';
import * as CdkLangTypescriptApigatewayLambdaNodejsSample from '../lib/cdk-lang-typescript-apigateway-lambda-nodejs-sample-stack';

test('Empty Stack', () => {
    const app = new cdk.App();
    // WHEN
    const stack = new CdkLangTypescriptApigatewayLambdaNodejsSample.CdkLangTypescriptApigatewayLambdaNodejsSampleStack(app, 'MyTestStack');
    // THEN
    expectCDK(stack).to(matchTemplate({
      "Resources": {}
    }, MatchStyle.EXACT))
});
