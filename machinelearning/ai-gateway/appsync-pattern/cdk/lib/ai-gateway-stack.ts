import * as cdk from 'aws-cdk-lib';
import * as appsync from '@aws-cdk/aws-appsync-alpha';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class AiGatewayStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Cognito User Poolの作成
    const userPool = new cognito.UserPool(this, 'AiGatewayUserPool', {
      userPoolName: 'ai-gateway-user-pool',
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: true,
        },
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
    });

    // User Pool Clientの作成
    const userPoolClient = new cognito.UserPoolClient(this, 'AiGatewayUserPoolClient', {
      userPool,
      generateSecret: false,
      authFlows: {
        adminUserPassword: true,
        userPassword: true,
        userSrp: true,
      },
    });

    // Identity Poolの作成
    const identityPool = new cognito.CfnIdentityPool(this, 'AiGatewayIdentityPool', {
      allowUnauthenticatedIdentities: false,
      cognitoIdentityProviders: [{
        clientId: userPoolClient.userPoolClientId,
        providerName: userPool.userPoolProviderName,
      }],
    });

    // Lambda Authorizerの作成
    const authorizerFunction = new lambda.Function(this, 'AiGatewayAuthorizer', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        exports.handler = async (event) => {
          // JWTトークンの検証
          const token = event.authorizationToken;
          
          // TODO: 適切なトークン検証を実装
          // 現時点ではトークンの存在確認のみ
          if (!token) {
            throw new Error('Unauthorized');
          }
          
          return {
            isAuthorized: true,
            resolverContext: {
              userId: 'user123', // 検証済みトークンから取得する
            },
          };
        };
      `),
    });

    // AppSync APIの作成
    const api = new appsync.GraphqlApi(this, 'AiGatewayApi', {
      name: 'ai-gateway-api',
      schema: appsync.SchemaFile.fromAsset('graphql/schema.graphql'),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: {
            userPool,
          },
        },
        additionalAuthorizationModes: [{
          authorizationType: appsync.AuthorizationType.LAMBDA,
          lambdaAuthorizerConfig: {
            handler: authorizerFunction,
          },
        }],
      },
      xrayEnabled: true,
    });

    // Bedrock用のIAMロールを作成
    const bedrockRole = new iam.Role(this, 'BedrockAccessRole', {
      assumedBy: new iam.ServicePrincipal('appsync.amazonaws.com'),
    });

    bedrockRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'bedrock:InvokeModel',
        'bedrock:InvokeModelWithResponseStream',
      ],
      resources: ['*'], // 必要に応じて特定のモデルに制限可能
    }));

    // 非同期推論用のLambda関数を作成
    const inferenceFunction = new lambda.Function(this, 'AsyncInferenceFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda/async-inference'),
      timeout: cdk.Duration.minutes(15),
      environment: {
        USER_POOL_ID: userPool.userPoolId,
        IDENTITY_POOL_ID: identityPool.ref,
      },
    });

    // 推論関数に必要な権限を追加
    inferenceFunction.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'bedrock:InvokeModel',
        'bedrock:InvokeModelWithResponseStream',
      ],
      resources: ['*'],
    }));

    // AppSync DataSourceの作成
    const inferenceDataSource = api.addLambdaDataSource(
      'AsyncInferenceDataSource',
      inferenceFunction
    );

    // Resolverの作成（修正版）
    inferenceDataSource.createResolver('StartInference', {
      typeName: 'Mutation',
      fieldName: 'startInference',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Invoke",
          "payload": {
            "arguments": $util.toJson($context.arguments),
            "info": {
              "fieldName": "startInference",
              "parentTypeName": "Mutation"
            }
          }
        }
      `),
      responseMappingTemplate: appsync.MappingTemplate.fromString(`
        #if($context.error)
          $util.error($context.error.message, $context.error.type)
        #end
        $util.toJson($context.result)
      `),
    });

    inferenceDataSource.createResolver('GetInferenceStatus', {
      typeName: 'Query',
      fieldName: 'getInferenceStatus',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Invoke",
          "payload": {
            "arguments": $util.toJson($context.arguments),
            "info": {
              "fieldName": "getInferenceStatus",
              "parentTypeName": "Query"
            }
          }
        }
      `),
      responseMappingTemplate: appsync.MappingTemplate.fromString(`
        #if($context.error)
          $util.error($context.error.message, $context.error.type)
        #end
        $util.toJson($context.result)
      `),
    });

    // 出力値の設定
    new cdk.CfnOutput(this, 'GraphQLApiURL', {
      value: api.graphqlUrl,
    });

    new cdk.CfnOutput(this, 'GraphQLApiId', {
      value: api.apiId,
    });

    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
    });

    new cdk.CfnOutput(this, 'IdentityPoolId', {
      value: identityPool.ref,
    });
  }
}