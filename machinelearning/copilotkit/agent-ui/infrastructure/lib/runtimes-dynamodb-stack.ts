import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { Construct } from 'constructs';
import { AppConfig } from './config';

export interface RuntimesDynamoDBStackProps extends cdk.StackProps {
  config: AppConfig;
}

export class RuntimesDynamoDBStack extends cdk.Stack {
  public readonly runtimesTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props: RuntimesDynamoDBStackProps) {
    super(scope, id, props);

    const { config } = props;
    const envSuffix = config.cognito.clientSuffix;

    // Runtimes テーブル
    this.runtimesTable = new dynamodb.Table(this, 'RuntimesTable', {
      tableName: `copilotkit-runtimes-${envSuffix}`,
      partitionKey: {
        name: 'runtimeId',
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: envSuffix === 'prod' 
        ? cdk.RemovalPolicy.RETAIN 
        : cdk.RemovalPolicy.DESTROY,
      pointInTimeRecovery: envSuffix === 'prod',
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // SSM Parameter に Runtimes テーブル名を保存
    new ssm.StringParameter(this, 'RuntimesTableNameParameter', {
      parameterName: `/copilotkit-agentcore/${envSuffix}/dynamodb/runtimes-table-name`,
      stringValue: this.runtimesTable.tableName,
      description: `AgentCore Runtimes DynamoDB table name for ${envSuffix}`,
      tier: ssm.ParameterTier.STANDARD,
    });

    // Outputs
    new cdk.CfnOutput(this, 'RuntimesTableName', {
      value: this.runtimesTable.tableName,
      description: 'Runtimes DynamoDB table name',
      exportName: `CopilotKit-Runtimes-TableName-${envSuffix}`,
    });

    new cdk.CfnOutput(this, 'RuntimesTableArn', {
      value: this.runtimesTable.tableArn,
      description: 'Runtimes DynamoDB table ARN',
      exportName: `CopilotKit-Runtimes-TableArn-${envSuffix}`,
    });

    // Tags
    cdk.Tags.of(this.runtimesTable).add('Component', 'RuntimesDatabase');
    cdk.Tags.of(this.runtimesTable).add('Environment', envSuffix);
  }
}
