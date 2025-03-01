import * as cdk from 'aws-cdk-lib';
import * as appsync from 'aws-cdk-lib/aws-appsync';
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

    // JWT用のLambda Layerを作成
    const jwtLayer = new lambda.LayerVersion(this, 'JwtLayer', {
      code: lambda.Code.fromAsset('lambda/layers/jwt'),
      compatibleRuntimes: [lambda.Runtime.NODEJS_18_X],
      description: 'Layer containing jsonwebtoken package',
    });

    // Lambda Authorizerの作成
    const authorizerFunction = new lambda.Function(this, 'AiGatewayAuthorizer', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      layers: [jwtLayer],
      code: lambda.Code.fromInline(`
        const jwt = require('jsonwebtoken');
        
        exports.handler = async (event) => {
          console.log('=== Lambda Authorizer Event ===');
          console.log('Event:', JSON.stringify(event, null, 2));
          console.log('Authorization Token:', event.authorizationToken);
          
          try {
            const token = event.authorizationToken;
            
            console.log('Checking token existence...');
            if (!token) {
              console.log('No token provided');
              throw new Error('Unauthorized: No token provided');
            }

            console.log('Token format:', token.substring(0, 20) + '...');

            // Lambda-Auth- プレフィックスの確認
            if (!token.startsWith('Lambda-Auth-')) {
              console.log('Invalid token format - missing Lambda-Auth- prefix');
              throw new Error('Invalid authorization token format');
            }

            // プレフィックスを削除して元のIdTokenを取得
            const idToken = token.substring('Lambda-Auth-'.length);
            console.log('Extracted ID token:', idToken.substring(0, 20) + '...');

            // トークンをデコード（検証なし）してペイロードを取得
            const decodedToken = jwt.decode(idToken);
            if (!decodedToken) {
              console.log('Failed to decode token');
              throw new Error('Invalid token format');
            }

            // Cognitoトークンから'sub'（ユーザーID）を取得
            const userId = decodedToken.sub;
            if (!userId) {
              console.log('No user ID in token');
              throw new Error('Invalid token: no user ID');
            }

            console.log('Authorization successful for user:', userId);
            return {
              isAuthorized: true,
              resolverContext: {
                userId: userId,
                tokenType: 'cognito',
              },
            };
          } catch (error) {
            console.log('Authorization failed:', error.message);
            throw error;
          }
        };
      `),
    });

    // AppSync APIのログロールを作成
    const appsyncLogRole = new iam.Role(this, 'AppsyncLogRole', {
      assumedBy: new iam.ServicePrincipal('appsync.amazonaws.com'),
    });

    appsyncLogRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents'
      ],
      resources: ['*'],
    }));

    // AppSync APIの作成
    const api = new appsync.GraphqlApi(this, 'AiGatewayApi', {
      name: 'ai-gateway-api',
      schema: appsync.SchemaFile.fromAsset('graphql/schema.graphql'),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.LAMBDA,
          lambdaAuthorizerConfig: {
            handler: authorizerFunction,
          },
        },
        additionalAuthorizationModes: [{
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: {
            userPool,
          },
        }],
      },
      xrayEnabled: true,
      logConfig: {
        excludeVerboseContent: false,
        fieldLogLevel: appsync.FieldLogLevel.ALL,
        role: appsyncLogRole,
      },
    });

    // GQL Layer for AppSync API calls
    const gqlLayer = new lambda.LayerVersion(this, 'GqlLayer', {
      code: lambda.Code.fromAsset('lambda/layers/gql'),
      compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
      description: 'Layer containing gql and requests packages',
    });

    // Inference Lambda関数の作成
    const inferenceFunction = new lambda.Function(this, 'InferenceFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'inference.handler',
      code: lambda.Code.fromAsset('lambda'),
      timeout: cdk.Duration.minutes(15),
      layers: [gqlLayer],
      environment: {
        APPSYNC_API_URL: api.graphqlUrl,
      },
    });

    // Lambda関数にAppSync APIへのアクセス権限を追加
    inferenceFunction.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['appsync:GraphQL'],
      resources: [
        `${api.arn}/types/Mutation/fields/updateInferenceStatus`,
      ],
    }));

    // Bedrock用のIAMロールを作成
    const bedrockRole = new iam.Role(this, 'BedrockAccessRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
    });

    bedrockRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'bedrock:InvokeModel',
        'bedrock:InvokeModelWithResponseStream',
      ],
      resources: ['*'],
    }));

    // Update Status Lambda関数の作成
    const updateStatusFunction = new lambda.Function(this, 'UpdateStatusFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'update_status.handler',
      code: lambda.Code.fromAsset('lambda'),
      timeout: cdk.Duration.minutes(1),
    });

    // AppSync DataSourceの作成
    const inferenceDataSource = api.addLambdaDataSource(
      'InferenceDataSource',
      inferenceFunction,
      {
        description: 'Lambda data source for inference operations',
      }
    );

    const updateStatusDataSource = api.addLambdaDataSource(
      'UpdateStatusDataSource',
      updateStatusFunction,
      {
        description: 'Lambda data source for status updates',
      }
    );

    // Resolverの作成
    inferenceDataSource.createResolver('StartInferenceResolver', {
      typeName: 'Mutation',
      fieldName: 'startInference',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Invoke",
          "invocationType": "Event",
          "payload": $util.toJson($context.arguments.input)
        }
      `),
      // この設定は Lambda の非同期呼び出しの場合意味がないので修正不要
      responseMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "jobId": "$util.autoId()",
          "status": "PENDING",
          "startTime": "$util.time.nowISO8601()"
        }
      `)
    });

    // updateInferenceStatus用のリゾルバーを作成
    updateStatusDataSource.createResolver('UpdateInferenceStatusResolver', {
      typeName: 'Mutation',
      fieldName: 'updateInferenceStatus',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Invoke",
          "payload": $util.toJson($context.arguments)
        }
      `),
      responseMappingTemplate: appsync.MappingTemplate.fromString(`
        $util.toJson($context.result)
      `)
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