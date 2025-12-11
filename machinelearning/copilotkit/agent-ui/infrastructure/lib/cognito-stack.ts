import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { Construct } from 'constructs';
import { AppConfig } from './config';

export interface CognitoStackProps extends cdk.StackProps {
  config: AppConfig;
}

export class CognitoStack extends cdk.Stack {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.UserPoolClient;
  public readonly userPoolDomain: cognito.UserPoolDomain;

  constructor(scope: Construct, id: string, props: CognitoStackProps) {
    super(scope, id, props);

    const projectName = props.config.cognito.projectName || 'copilotkit-agentcore';

    this.userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: `${projectName}-user-pool`,
      signInAliases: {
        email: true,
      },
      autoVerify: {
        email: true,
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: false,
        },
        fullname: {
          required: false,
          mutable: true,
        },
      },
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      selfSignUpEnabled: true,
      // MFA configuration (OFF for simplicity)
      mfa: cognito.Mfa.OFF,
      // Removal policy for development
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    this.userPoolDomain = new cognito.UserPoolDomain(this, 'UserPoolDomain', {
      userPool: this.userPool,
      cognitoDomain: {
        domainPrefix: `${projectName}-${cdk.Aws.ACCOUNT_ID}`,
      },
    });

    const clientSuffix = props.config.cognito.clientSuffix;
    this.userPoolClient = new cognito.UserPoolClient(this, 'UserPoolClient', {
      userPool: this.userPool,
      userPoolClientName: `${projectName}-${clientSuffix}-client`,
      // Public client - no secret for SPA
      generateSecret: false,
      // OAuth flows for SPA
      oAuth: {
        flows: {
          authorizationCodeGrant: true,
          implicitCodeGrant: true,
        },
        scopes: [
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: props.config.cognito.callbackUrls,
        logoutUrls: props.config.cognito.logoutUrls,
      },
      // Identity providers
      supportedIdentityProviders: [
        cognito.UserPoolClientIdentityProvider.COGNITO,
      ],
      // Token validity
      accessTokenValidity: cdk.Duration.minutes(60),
      idTokenValidity: cdk.Duration.minutes(60),
      refreshTokenValidity: cdk.Duration.days(30),
      // Security settings
      preventUserExistenceErrors: true,
      enableTokenRevocation: true,
      // Auth flows
      authFlows: {
        userSrp: true,
        userPassword: true,
        custom: false,
        adminUserPassword: false,
      },
    });

    // SSM Parameter Store に Cognito 設定を保存
    const ssmPrefix = `/${projectName}/${clientSuffix}`;
    
    new ssm.StringParameter(this, 'SsmUserPoolId', {
      parameterName: `${ssmPrefix}/cognito/user-pool-id`,
      stringValue: this.userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new ssm.StringParameter(this, 'SsmUserPoolClientId', {
      parameterName: `${ssmPrefix}/cognito/client-id`,
      stringValue: this.userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
    });

    new ssm.StringParameter(this, 'SsmIssuerUrl', {
      parameterName: `${ssmPrefix}/cognito/issuer-url`,
      stringValue: `https://cognito-idp.${cdk.Aws.REGION}.amazonaws.com/${this.userPool.userPoolId}`,
      description: 'Cognito Issuer URL',
    });

    new ssm.StringParameter(this, 'SsmUserPoolDomain', {
      parameterName: `${ssmPrefix}/cognito/domain`,
      stringValue: this.userPoolDomain.domainName,
      description: 'Cognito User Pool Domain',
    });

    // 新しいCognito Outputs（CloudFormation互換）
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: this.userPool.userPoolId,
      description: 'Cognito User Pool ID',
      exportName: `${this.stackName}-UserPoolId`,
    });

    new cdk.CfnOutput(this, 'UserPoolArn', {
      value: this.userPool.userPoolArn,
      description: 'Cognito User Pool ARN',
      exportName: `${this.stackName}-UserPoolArn`,
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: this.userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
      exportName: `${this.stackName}-UserPoolClientId`,
    });

    new cdk.CfnOutput(this, 'UserPoolDomainName', {
      value: this.userPoolDomain.domainName,
      description: 'Cognito User Pool Domain',
      exportName: `${this.stackName}-UserPoolDomain`,
    });

    new cdk.CfnOutput(this, 'HostedUIUrl', {
      value: `https://${this.userPoolDomain.domainName}.auth.${cdk.Aws.REGION}.amazoncognito.com/login?client_id=${this.userPoolClient.userPoolClientId}&response_type=code&scope=openid+email+profile&redirect_uri=http://localhost:3000/api/auth/callback/cognito`,
      description: 'Cognito Hosted UI URL',
      exportName: `${this.stackName}-HostedUIUrl`,
    });

    new cdk.CfnOutput(this, 'DiscoveryUrl', {
      value: `https://cognito-idp.${cdk.Aws.REGION}.amazonaws.com/${this.userPool.userPoolId}/.well-known/openid-configuration`,
      description: 'OIDC Discovery URL (for AgentCore Runtime)',
      exportName: `${this.stackName}-DiscoveryUrl`,
    });

    new cdk.CfnOutput(this, 'IssuerUrl', {
      value: `https://cognito-idp.${cdk.Aws.REGION}.amazonaws.com/${this.userPool.userPoolId}`,
      description: 'Cognito Issuer URL (for NextAuth.js)',
      exportName: `${this.stackName}-IssuerUrl`,
    });

    new cdk.CfnOutput(this, 'TokenEndpoint', {
      value: `https://${this.userPoolDomain.domainName}.auth.${cdk.Aws.REGION}.amazoncognito.com/oauth2/token`,
      description: 'OAuth2 Token Endpoint',
      exportName: `${this.stackName}-TokenEndpoint`,
    });

    new cdk.CfnOutput(this, 'AuthorizationEndpoint', {
      value: `https://${this.userPoolDomain.domainName}.auth.${cdk.Aws.REGION}.amazoncognito.com/oauth2/authorize`,
      description: 'OAuth2 Authorization Endpoint',
      exportName: `${this.stackName}-AuthorizationEndpoint`,
    });

    // Tags
    cdk.Tags.of(this).add('Name', `${projectName}-user-pool`);
    cdk.Tags.of(this).add('Project', projectName);
    cdk.Tags.of(this).add('Environment', 'development');
  }
}
