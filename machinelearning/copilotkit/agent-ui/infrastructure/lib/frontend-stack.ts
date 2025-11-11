import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigatewayv2 from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigatewayv2_integrations from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { AppConfig } from './config';
import { CognitoStack } from './cognito-stack';
import * as path from 'path';

export interface FrontendStackProps extends cdk.StackProps {
  config: AppConfig;
  cognitoStack: CognitoStack;
}

export class FrontendStack extends cdk.Stack {
  public readonly distribution: cloudfront.Distribution;
  public readonly lambdaFunction: lambda.Function;

  constructor(scope: Construct, id: string, props: FrontendStackProps) {
    super(scope, id, props);

    // S3 Bucket for static assets
    const staticAssetsBucket = new s3.Bucket(this, 'StaticAssetsBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      cors: [
        {
          allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD],
          allowedOrigins: ['*'],
          allowedHeaders: ['*'],
        },
      ],
    });

    // Lambda Function for Next.js
    const nextjsAppPath = path.join(__dirname, props.config.frontend.nextjsAppPath);
    
    // Lambda環境変数を定義
    const lambdaEnvironment = {
      AWS_LAMBDA_EXEC_WRAPPER: '/opt/bootstrap',
      PORT: '8080',
      RUST_LOG: 'info',
      // NextAuth.js設定 - 環境別に動的設定
      NEXTAUTH_URL: props.config.nextAuth.url || '', // 本番では後でCloudFront URLに更新
      NEXTAUTH_SECRET: props.config.nextAuth.secret,
      // Cognito values - CognitoStackから取得
      COGNITO_CLIENT_ID: props.cognitoStack.userPoolClient.userPoolClientId,
      COGNITO_ISSUER: `https://cognito-idp.${cdk.Aws.REGION}.amazonaws.com/${props.cognitoStack.userPool.userPoolId}`,
      // 環境別設定
      NODE_ENV: props.config.env.environment === 'local' ? 'development' : 'production',
    };
    
    this.lambdaFunction = new lambda.Function(this, 'NextjsFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'run.sh',
      code: lambda.Code.fromAsset(nextjsAppPath, {
        bundling: {
          image: lambda.Runtime.NODEJS_20_X.bundlingImage,
          environment: {
            NPM_CONFIG_CACHE: '/asset-input/.npm-cache',
            NPM_CONFIG_PREFIX: '/asset-input/.npm-prefix',
            HOME: '/asset-input',
          },
          command: [
            'bash',
            '-c',
            [
              // Install dependencies and build
              'mkdir -p /asset-input/.npm-cache /asset-input/.npm-prefix',
              'npm ci --cache /asset-input/.npm-cache --no-audit --no-fund',
              'npm run build',
              // Copy public and static assets to standalone directory (recommended pattern)
              '[ -d public ] && cp -r public/. .next/standalone/public/ || echo "No public directory found"',
              '[ -d .next/static ] && cp -r .next/static/. .next/standalone/.next/static/ || echo "No static directory found"',
              // Create run.sh script in standalone directory using echo
              'echo "#!/bin/bash" > .next/standalone/run.sh',
              'echo "exec node server.js" >> .next/standalone/run.sh',
              'chmod +x .next/standalone/run.sh',
              // Copy everything from standalone to output
              'cp -r .next/standalone/* /asset-output/',
              'cp -r .next/standalone/.next /asset-output/ 2>/dev/null || true',
            ].join(' && '),
          ],
        },
      }),
      memorySize: props.config.lambda.memorySize,
      timeout: cdk.Duration.seconds(props.config.lambda.timeout),
      environment: lambdaEnvironment,
      layers: [
        lambda.LayerVersion.fromLayerVersionArn(
          this,
          'LambdaWebAdapterLayer',
          props.config.lambda.webAdapterLayerArn
        ),
      ],
    });

    // セキュリティ修正: Lambda Function URL削除（World Accessible問題を回避）
    // API Gateway経由のみでアクセスするように変更

    // API Gateway HTTP API v2
    const httpApi = new apigatewayv2.HttpApi(this, 'HttpApi', {
      description: 'HTTP API for Next.js frontend',
      corsPreflight: {
        allowOrigins: ['*'],
        allowMethods: [
          apigatewayv2.CorsHttpMethod.GET,
          apigatewayv2.CorsHttpMethod.POST,
          apigatewayv2.CorsHttpMethod.OPTIONS,
        ],
        allowHeaders: ['*'],
      },
    });

    // Lambda Integration
    const lambdaIntegration = new apigatewayv2_integrations.HttpLambdaIntegration(
      'LambdaIntegration',
      this.lambdaFunction
    );

    // Add routes for both root and proxy paths
    httpApi.addRoutes({
      path: '/',
      methods: [apigatewayv2.HttpMethod.ANY],
      integration: lambdaIntegration,
    });

    httpApi.addRoutes({
      path: '/{proxy+}',
      methods: [apigatewayv2.HttpMethod.ANY],
      integration: lambdaIntegration,
    });

    // CloudFront Cache Policy (開発用: キャッシュ無効化)
    const cachePolicy = new cloudfront.CachePolicy(this, 'CachePolicy', {
      cachePolicyName: `NextjsCache-${this.stackName}`,
      comment: 'Cache policy for Next.js with no caching for development',
      defaultTtl: cdk.Duration.seconds(0),
      minTtl: cdk.Duration.seconds(0),
      maxTtl: cdk.Duration.seconds(1),
      enableAcceptEncodingGzip: true,
      enableAcceptEncodingBrotli: true,
      headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
        'Authorization',
        'CloudFront-Forwarded-Proto',
        'Host'
      ),
      queryStringBehavior: cloudfront.CacheQueryStringBehavior.all(),
      cookieBehavior: cloudfront.CacheCookieBehavior.all(),
    });

    // CloudFront Origin Request Policy - API Gateway optimized
    const originRequestPolicy = new cloudfront.OriginRequestPolicy(
      this,
      'OriginRequestPolicy',
      {
        originRequestPolicyName: `NextjsOriginRequest-${this.stackName}`,
        comment: 'Origin request policy for Next.js with API Gateway',
        headerBehavior: cloudfront.OriginRequestHeaderBehavior.allowList(
          'Accept',
          'Accept-Language',
          'User-Agent',
          'Referer'
        ),
        queryStringBehavior: cloudfront.OriginRequestQueryStringBehavior.all(),
        cookieBehavior: cloudfront.OriginRequestCookieBehavior.all(),
      }
    );

    // Static Assets Cache Policy (静的ファイル用: キャッシュ有効)
    const staticCachePolicy = new cloudfront.CachePolicy(this, 'StaticCachePolicy', {
      cachePolicyName: `NextjsStaticCache-${this.stackName}`,
      comment: 'Cache policy for static assets',
      defaultTtl: cdk.Duration.days(7),
      minTtl: cdk.Duration.seconds(0),
      maxTtl: cdk.Duration.days(365),
      enableAcceptEncodingGzip: true,
      enableAcceptEncodingBrotli: true,
    });

    // CloudFront Distribution
    this.distribution = new cloudfront.Distribution(this, 'Distribution', {
      comment: 'Next.js frontend distribution',
      defaultBehavior: {
        origin: new origins.HttpOrigin(
          cdk.Fn.select(2, cdk.Fn.split('/', httpApi.url!))
        ),
        cachePolicy: cachePolicy,
        originRequestPolicy: originRequestPolicy,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      },
      additionalBehaviors: {
        '/_next/static/*': {
          origin: new origins.S3Origin(staticAssetsBucket),
          cachePolicy: staticCachePolicy,
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        },
        '/static/*': {
          origin: new origins.S3Origin(staticAssetsBucket),
          cachePolicy: staticCachePolicy,
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        },
      },
    });

    // Deploy static assets to S3 (conditional deployment)
    // Next.js静的アセットのデプロイ（ビルド後に存在する場合のみ）
    const staticAssetsPath = path.join(nextjsAppPath, '.next/static');
    try {
      // .next/staticディレクトリが存在するかチェック
      new s3deploy.BucketDeployment(this, 'DeployStaticAssets', {
        sources: [
          s3deploy.Source.asset(staticAssetsPath, {
            exclude: ['**/.DS_Store', '**/.gitkeep'],
          }),
        ],
        destinationBucket: staticAssetsBucket,
        destinationKeyPrefix: '_next/static',
        distribution: this.distribution,
        distributionPaths: ['/_next/static/*'],
        // 存在しない場合はエラーではなく警告として処理
        retainOnDelete: false,
      });
    } catch (error) {
      // 静的アセットが存在しない場合は無視（開発中は正常）
      console.warn(`Static assets directory not found: ${staticAssetsPath}`);
    }

    // Public assets deployment (public/ディレクトリが存在する場合のみ)
    const publicPath = path.join(nextjsAppPath, 'public');
    try {
      new s3deploy.BucketDeployment(this, 'DeployPublicAssets', {
        sources: [
          s3deploy.Source.asset(publicPath, {
            exclude: ['**/.DS_Store', '**/.gitkeep'],
          }),
        ],
        destinationBucket: staticAssetsBucket,
        destinationKeyPrefix: 'static',
        distribution: this.distribution,
        distributionPaths: ['/static/*'],
        retainOnDelete: false,
      });
    } catch (error) {
      // publicディレクトリが存在しない場合は無視
      console.warn(`Public assets directory not found: ${publicPath}`);
    }

    // デプロイ後にNEXTAUTH_URLをCloudFront URLで更新
    const cloudFrontUrl = `https://${this.distribution.distributionDomainName}`;
    
    // 本番環境でNEXTAUTH_URLが未設定の場合、Lambda環境変数を更新
    if (!props.config.nextAuth.url && props.config.env.environment === 'production') {
      // Lambda環境変数を更新するCustomリソース用のロール
      const updateLambdaRole = new iam.Role(this, 'UpdateLambdaRole', {
        assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
        ],
        inlinePolicies: {
          UpdateLambdaEnv: new iam.PolicyDocument({
            statements: [
              new iam.PolicyStatement({
                actions: ['lambda:UpdateFunctionConfiguration'],
                resources: [this.lambdaFunction.functionArn],
              }),
            ],
          }),
        },
      });

      // Lambda環境変数更新用のCustomリソース
      const updateEnvLambda = new lambda.Function(this, 'UpdateEnvFunction', {
        runtime: lambda.Runtime.NODEJS_20_X,
        handler: 'index.handler',
        role: updateLambdaRole,
        code: lambda.Code.fromInline(`
          const { LambdaClient, UpdateFunctionConfigurationCommand } = require('@aws-sdk/client-lambda');
          const lambda = new LambdaClient({ region: process.env.AWS_REGION });

          exports.handler = async (event) => {
            console.log('Event:', JSON.stringify(event, null, 2));
            
            if (event.RequestType === 'Delete') {
              return { PhysicalResourceId: 'update-env-resource' };
            }

            const functionName = event.ResourceProperties.FunctionName;
            const cloudFrontUrl = event.ResourceProperties.CloudFrontUrl;

            try {
              const command = new UpdateFunctionConfigurationCommand({
                FunctionName: functionName,
                Environment: {
                  Variables: {
                    ...event.ResourceProperties.CurrentEnv,
                    NEXTAUTH_URL: cloudFrontUrl,
                  },
                },
              });

              const result = await lambda.send(command);
              console.log('Lambda environment updated:', result);
              
              return { 
                PhysicalResourceId: 'update-env-resource',
                Data: { CloudFrontUrl: cloudFrontUrl }
              };
            } catch (error) {
              console.error('Error updating Lambda environment:', error);
              throw error;
            }
          };
        `),
      });

      // CustomResource
      new cdk.CustomResource(this, 'UpdateNextAuthUrl', {
        serviceToken: updateEnvLambda.functionArn,
        properties: {
          FunctionName: this.lambdaFunction.functionName,
          CloudFrontUrl: cloudFrontUrl,
          CurrentEnv: lambdaEnvironment,
        },
      });
    }

    // Outputs
    new cdk.CfnOutput(this, 'CloudFrontURL', {
      value: cloudFrontUrl,
      description: 'CloudFront Distribution URL',
    });

    new cdk.CfnOutput(this, 'ApiGatewayUrl', {
      value: httpApi.url || '',
      description: 'API Gateway URL',
    });

    new cdk.CfnOutput(this, 'LambdaFunctionArn', {
      value: this.lambdaFunction.functionArn,
      description: 'Lambda Function ARN',
    });

    new cdk.CfnOutput(this, 'StaticAssetsBucketName', {
      value: staticAssetsBucket.bucketName,
      description: 'S3 Bucket for static assets',
    });

    new cdk.CfnOutput(this, 'NextAuthCallbackUrl', {
      value: `${cloudFrontUrl}/api/auth/callback/cognito`,
      description: 'Cognito Callback URL to add to User Pool Client',
    });
  }
}
