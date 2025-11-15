import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { NextjsGlobalFunctions } from 'cdk-nextjs';
import { AppConfig } from './config';
import * as path from 'path';

export interface NextjsStackProps extends cdk.StackProps {
  config: AppConfig;
  cognitoUserPoolId?: string;
  cognitoUserPoolClientId?: string;
  cognitoIssuerUrl?: string;
}

export class NextjsStack extends cdk.Stack {
  public readonly nextjsApp: NextjsGlobalFunctions;

  constructor(scope: Construct, id: string, props: NextjsStackProps) {
    super(scope, id, props);

    // Next.jsアプリケーションのパス
    const nextjsAppPath = path.resolve(__dirname, props.config.frontend.nextjsAppPath);

    // NextjsGlobalFunctions construct  
    this.nextjsApp = new NextjsGlobalFunctions(this, 'NextjsApp', {
      buildContext: nextjsAppPath,
      
      // ヘルスチェックパス
      healthCheckPath: '/api/health',
      
      // セキュリティ設定
      // Lambda Function URL + IAM Authを使用（デフォルトのNextjsGlobalFunctions設定）
      // これにより、CloudFrontを通じてのみアクセス可能になり、World Accessible問題を回避
    });

    // Custom Resource to add Bedrock permissions to Lambda execution role
    const addBedrockPermissionRole = new cdk.aws_iam.Role(this, 'AddBedrockPermissionRole', {
      assumedBy: new cdk.aws_iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        cdk.aws_iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
      inlinePolicies: {
        AddIAMPolicy: new cdk.aws_iam.PolicyDocument({
          statements: [
            new cdk.aws_iam.PolicyStatement({
              actions: [
                'lambda:ListFunctions',
                'lambda:GetFunction',
                'iam:GetRole',
                'iam:PutRolePolicy',
              ],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    const addBedrockPermissionFunction = new cdk.aws_lambda.Function(this, 'AddBedrockPermissionFunction', {
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      role: addBedrockPermissionRole,
      code: cdk.aws_lambda.Code.fromInline(`
        const { LambdaClient, ListFunctionsCommand, GetFunctionCommand } = require('@aws-sdk/client-lambda');
        const { IAMClient, PutRolePolicyCommand } = require('@aws-sdk/client-iam');
        
        async function sendResponse(event, context, responseStatus, responseData, physicalResourceId) {
          const responseBody = JSON.stringify({
            Status: responseStatus,
            Reason: 'See the details in CloudWatch Log Stream: ' + context.logStreamName,
            PhysicalResourceId: physicalResourceId || context.logStreamName,
            StackId: event.StackId,
            RequestId: event.RequestId,
            LogicalResourceId: event.LogicalResourceId,
            Data: responseData
          });
          
          try {
            await fetch(event.ResponseURL, {
              method: 'PUT',
              headers: { 'content-type': '', 'content-length': responseBody.length.toString() },
              body: responseBody
            });
          } catch (error) {
            console.error('Failed to send response:', error);
          }
        }
        
        exports.handler = async (event, context) => {
          console.log('Event:', JSON.stringify(event, null, 2));
          
          if (event.RequestType === 'Delete') {
            await sendResponse(event, context, 'SUCCESS', {}, event.PhysicalResourceId || 'add-bedrock-permission');
            return;
          }
          
          try {
            const stackName = event.ResourceProperties.StackName;
            const lambda = new LambdaClient({ region: process.env.AWS_REGION });
            const iam = new IAMClient({ region: process.env.AWS_REGION });
            
            // Stack内のNextjsFunctions Lambda関数を検索（実際にアプリケーションが動作する関数）
            const listResult = await lambda.send(new ListFunctionsCommand({}));
            const targetFunction = listResult.Functions?.find(fn => 
              fn.FunctionName?.includes(stackName) && fn.FunctionName?.includes('NextjsFunctions')
            );
            
            if (!targetFunction) {
              throw new Error('NextjsApp Lambda function not found');
            }
            
            console.log('Found Lambda function:', targetFunction.FunctionName);
            
            // Lambda関数の詳細を取得してRoleを特定
            const funcDetails = await lambda.send(new GetFunctionCommand({
              FunctionName: targetFunction.FunctionName
            }));
            
            const roleArn = funcDetails.Configuration?.Role;
            if (!roleArn) {
              throw new Error('Lambda role not found');
            }
            
            const roleName = roleArn.split('/').pop();
            console.log('Lambda role:', roleName);
            
            // Bedrock権限をロールに追加（foundation modelとinference profileの両方に対応）
            await iam.send(new PutRolePolicyCommand({
              RoleName: roleName,
              PolicyName: 'BedrockAccess',
              PolicyDocument: JSON.stringify({
                Version: '2012-10-17',
                Statement: [{
                  Effect: 'Allow',
                  Action: [
                    'bedrock:InvokeModel',
                    'bedrock:InvokeModelWithResponseStream'
                  ],
                  Resource: [
                    'arn:aws:bedrock:*:*:foundation-model/*',
                    'arn:aws:bedrock:*:*:inference-profile/*'
                  ]
                }]
              })
            }));
            
            console.log('Bedrock permissions added successfully');
            
            await sendResponse(
              event,
              context,
              'SUCCESS',
              { RoleName: roleName, FunctionName: targetFunction.FunctionName },
              'add-bedrock-permission'
            );
            
          } catch (error) {
            console.error('Error:', error);
            await sendResponse(
              event,
              context,
              'FAILED',
              { Error: error.message },
              event.PhysicalResourceId || 'add-bedrock-permission'
            );
          }
        };
      `),
      timeout: cdk.Duration.minutes(2),
    });

    // Custom Resource to add Bedrock permissions
    new cdk.CustomResource(this, 'AddBedrockPermissions', {
      serviceToken: addBedrockPermissionFunction.functionArn,
      properties: {
        StackName: this.stackName,
        DeployTimestamp: Date.now(),
      },
    });

    // Custom Resource to update Cognito callback URLs
    const updateCognitoRole = new cdk.aws_iam.Role(this, 'UpdateCognitoRole', {
      assumedBy: new cdk.aws_iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        cdk.aws_iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
      inlinePolicies: {
        UpdateCognitoPolicy: new cdk.aws_iam.PolicyDocument({
          statements: [
            new cdk.aws_iam.PolicyStatement({
              actions: [
                'cognito-idp:DescribeUserPoolClient',
                'cognito-idp:UpdateUserPoolClient'
              ],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    const updateCognitoFunction = new cdk.aws_lambda.Function(this, 'UpdateCognitoFunction', {
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      role: updateCognitoRole,
      code: cdk.aws_lambda.Code.fromInline(`
        const { CognitoIdentityProviderClient, DescribeUserPoolClientCommand, UpdateUserPoolClientCommand } = require('@aws-sdk/client-cognito-identity-provider');
        
        async function sendResponse(event, context, responseStatus, responseData, physicalResourceId) {
          const responseBody = JSON.stringify({
            Status: responseStatus,
            Reason: 'See the details in CloudWatch Log Stream: ' + context.logStreamName,
            PhysicalResourceId: physicalResourceId || context.logStreamName,
            StackId: event.StackId,
            RequestId: event.RequestId,
            LogicalResourceId: event.LogicalResourceId,
            Data: responseData
          });
          
          console.log('Response body:', responseBody);
          
          try {
            const response = await fetch(event.ResponseURL, {
              method: 'PUT',
              headers: {
                'content-type': '',
                'content-length': responseBody.length.toString()
              },
              body: responseBody
            });
            console.log('CloudFormation response sent:', response.status);
          } catch (error) {
            console.error('Failed to send response to CloudFormation:', error);
            throw error;
          }
        }
        
        exports.handler = async (event, context) => {
          console.log('Event:', JSON.stringify(event, null, 2));
          
          const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION });
          
          if (event.RequestType === 'Delete') {
            await sendResponse(event, context, 'SUCCESS', {}, event.PhysicalResourceId || 'update-cognito');
            return;
          }
          
          try {
            const userPoolId = event.ResourceProperties.UserPoolId;
            const clientId = event.ResourceProperties.ClientId;
            const cloudfrontUrl = event.ResourceProperties.CloudFrontUrl;
            const additionalCallbackUrls = event.ResourceProperties.AdditionalCallbackUrls || [];
            const additionalLogoutUrls = event.ResourceProperties.AdditionalLogoutUrls || [];
            
            // 現在の設定を取得
            const describeResult = await cognito.send(new DescribeUserPoolClientCommand({
              UserPoolId: userPoolId,
              ClientId: clientId
            }));
            
            const currentConfig = describeResult.UserPoolClient;
            console.log('Current Cognito configuration:', JSON.stringify(currentConfig, null, 2));
            
            // CloudFrontのURLを追加
            const newCallbackUrls = [
              ...additionalCallbackUrls,
              cloudfrontUrl,
              \`\${cloudfrontUrl}/api/auth/callback/cognito\`
            ];
            
            const newLogoutUrls = [
              ...additionalLogoutUrls,
              cloudfrontUrl
            ];
            
            // 重複を除去
            const uniqueCallbackUrls = [...new Set(newCallbackUrls)];
            const uniqueLogoutUrls = [...new Set(newLogoutUrls)];
            
            console.log('New callback URLs:', uniqueCallbackUrls);
            console.log('New logout URLs:', uniqueLogoutUrls);
            
            // Cognito設定を更新
            await cognito.send(new UpdateUserPoolClientCommand({
              UserPoolId: userPoolId,
              ClientId: clientId,
              CallbackURLs: uniqueCallbackUrls,
              LogoutURLs: uniqueLogoutUrls,
              AllowedOAuthFlows: currentConfig.AllowedOAuthFlows,
              AllowedOAuthScopes: currentConfig.AllowedOAuthScopes,
              AllowedOAuthFlowsUserPoolClient: currentConfig.AllowedOAuthFlowsUserPoolClient,
              SupportedIdentityProviders: currentConfig.SupportedIdentityProviders,
            }));
            
            console.log('Cognito callback URLs updated successfully');
            
            await sendResponse(
              event,
              context,
              'SUCCESS',
              { 
                CallbackURLs: uniqueCallbackUrls,
                LogoutURLs: uniqueLogoutUrls
              },
              'update-cognito'
            );
            
          } catch (error) {
            console.error('Error:', error);
            await sendResponse(
              event,
              context,
              'FAILED',
              { Error: error.message },
              event.PhysicalResourceId || 'update-cognito'
            );
          }
        };
      `),
      timeout: cdk.Duration.minutes(2),
    });

    // Custom Resource to update Cognito callback URLs with CloudFront URL
    new cdk.CustomResource(this, 'UpdateCognitoCallbacks', {
      serviceToken: updateCognitoFunction.functionArn,
      properties: {
        UserPoolId: props.cognitoUserPoolId || '',
        ClientId: props.cognitoUserPoolClientId || '',
        CloudFrontUrl: this.nextjsApp.url,
        AdditionalCallbackUrls: props.config.cognito.callbackUrls,
        AdditionalLogoutUrls: props.config.cognito.logoutUrls,
        // デプロイ時刻をプロパティに含めて毎回更新を実行
        DeployTimestamp: Date.now(),
      },
    });

    // Custom Resource to update Lambda environment variables
    const updateEnvRole = new cdk.aws_iam.Role(this, 'UpdateEnvRole', {
      assumedBy: new cdk.aws_iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        cdk.aws_iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
      inlinePolicies: {
        UpdateLambdaPolicy: new cdk.aws_iam.PolicyDocument({
          statements: [
            new cdk.aws_iam.PolicyStatement({
              actions: [
                'lambda:ListFunctions',
                'lambda:GetFunction', 
                'lambda:UpdateFunctionConfiguration'
              ],
              resources: ['*'], // NextjsGlobalFunctionsが作成するLambda関数のARNが不明のため
            }),
          ],
        }),
      },
    });

    const updateEnvFunction = new cdk.aws_lambda.Function(this, 'UpdateEnvFunction', {
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      role: updateEnvRole,
      code: cdk.aws_lambda.Code.fromInline(`
        const { LambdaClient, ListFunctionsCommand, UpdateFunctionConfigurationCommand } = require('@aws-sdk/client-lambda');
        
        // CloudFormationレスポンス送信関数
        async function sendResponse(event, context, responseStatus, responseData, physicalResourceId) {
          const responseBody = JSON.stringify({
            Status: responseStatus,
            Reason: 'See the details in CloudWatch Log Stream: ' + context.logStreamName,
            PhysicalResourceId: physicalResourceId || context.logStreamName,
            StackId: event.StackId,
            RequestId: event.RequestId,
            LogicalResourceId: event.LogicalResourceId,
            Data: responseData
          });
          
          console.log('Response body:', responseBody);
          
          try {
            const response = await fetch(event.ResponseURL, {
              method: 'PUT',
              headers: {
                'content-type': '',
                'content-length': responseBody.length.toString()
              },
              body: responseBody
            });
            console.log('CloudFormation response sent:', response.status);
          } catch (error) {
            console.error('Failed to send response to CloudFormation:', error);
            throw error;
          }
        }
        
        exports.handler = async (event, context) => {
          console.log('Event:', JSON.stringify(event, null, 2));
          
          const lambda = new LambdaClient({ region: process.env.AWS_REGION });
          
          // DELETEリクエストの処理
          if (event.RequestType === 'Delete') {
            await sendResponse(event, context, 'SUCCESS', {}, event.PhysicalResourceId || 'update-env');
            return;
          }
          
          try {
            const stackName = event.ResourceProperties.StackName;
            const envVars = event.ResourceProperties.Environment;
            
            // Stack内のLambda関数を検索
            const listResult = await lambda.send(new ListFunctionsCommand({}));
            const targetFunction = listResult.Functions?.find(fn => 
              fn.FunctionName?.includes(stackName) && fn.FunctionName?.includes('NextjsApp')
            );
            
            if (!targetFunction) {
              throw new Error('NextjsApp Lambda function not found');
            }
            
            console.log('Found Lambda function:', targetFunction.FunctionName);
            
            // 環境変数を更新
            await lambda.send(new UpdateFunctionConfigurationCommand({
              FunctionName: targetFunction.FunctionName,
              Environment: {
                Variables: envVars
              }
            }));
            
            console.log('Environment variables updated successfully');
            
            // 成功レスポンスを送信
            await sendResponse(
              event, 
              context, 
              'SUCCESS', 
              { FunctionName: targetFunction.FunctionName },
              'update-env'
            );
            
          } catch (error) {
            console.error('Error:', error);
            // エラーレスポンスを送信
            await sendResponse(
              event,
              context,
              'FAILED',
              { Error: error.message },
              event.PhysicalResourceId || 'update-env'
            );
          }
        };
      `),
      timeout: cdk.Duration.minutes(2),
    });

    // Custom Resource to trigger environment update
    new cdk.CustomResource(this, 'UpdateEnvironment', {
      serviceToken: updateEnvFunction.functionArn,
      properties: {
        StackName: this.stackName,
        Environment: {
          // NextAuth.js設定 - 環境別に動的設定
          NEXTAUTH_URL: props.config.nextAuth?.url || this.nextjsApp.url,
          NEXTAUTH_SECRET: props.config.nextAuth?.secret || 'PLEASE_CHANGE_THIS_SECRET',
          // Cognito values - 渡されたプロパティから設定
          COGNITO_CLIENT_ID: props.cognitoUserPoolClientId || '',
          COGNITO_ISSUER: props.cognitoIssuerUrl || '',
          // 環境別設定
          NODE_ENV: props.config.env?.environment === 'local' ? 'development' : 'production',
        },
        // デプロイ時刻をプロパティに含めて毎回更新を実行
        DeployTimestamp: Date.now(),
      },
    });

    // 出力
    new cdk.CfnOutput(this, 'NextjsUrl', {
      value: this.nextjsApp.url,
      description: 'Next.js Application URL',
    });

    new cdk.CfnOutput(this, 'NextAuthCallbackUrl', {
      value: `${this.nextjsApp.url}/api/auth/callback/cognito`,
      description: 'NextAuth Cognito Callback URL',
    });

    // タグ付け
    cdk.Tags.of(this).add('Name', `${props.config.cognito.projectName}-nextjs`);
    cdk.Tags.of(this).add('Project', props.config.cognito.projectName);
    cdk.Tags.of(this).add('Environment', 'development');
  }
}
