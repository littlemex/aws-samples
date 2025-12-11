import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { Construct } from 'constructs';
import { AppConfig } from './config';

export interface AgentsDynamoDBStackProps extends cdk.StackProps {
  config: AppConfig;
}

export class AgentsDynamoDBStack extends cdk.Stack {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props: AgentsDynamoDBStackProps) {
    super(scope, id, props);

    const { config } = props;
    const envSuffix = config.cognito.clientSuffix;

    // DynamoDBテーブル作成
    // ユーザーがMastraエージェントを有効化/無効化する設定を保存
    this.table = new dynamodb.Table(this, 'UserAgentsTable', {
      tableName: `copilotkit-user-agents-${envSuffix}`,
      partitionKey: {
        name: 'userId',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'agentId',
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST, // オンデマンド課金
      pointInTimeRecovery: true, // バックアップ有効
      removalPolicy: envSuffix === 'prod' 
        ? cdk.RemovalPolicy.RETAIN 
        : cdk.RemovalPolicy.DESTROY,
      deletionProtection: envSuffix === 'prod', // 本番環境では削除保護
    });

    // SSM Parameter Storeにテーブル名を保存
    new ssm.StringParameter(this, 'UserAgentsTableNameParam', {
      parameterName: `/copilotkit-agentcore/${envSuffix}/dynamodb/user-agents-table-name`,
      stringValue: this.table.tableName,
      description: `User Agents DynamoDB Table Name for ${envSuffix} environment`,
      tier: ssm.ParameterTier.STANDARD,
    });

    // テーブルARNも保存
    new ssm.StringParameter(this, 'UserAgentsTableArnParam', {
      parameterName: `/copilotkit-agentcore/${envSuffix}/dynamodb/user-agents-table-arn`,
      stringValue: this.table.tableArn,
      description: `User Agents DynamoDB Table ARN for ${envSuffix} environment`,
      tier: ssm.ParameterTier.STANDARD,
    });

    // グローバルセカンダリインデックス（将来の拡張用：ステータス別検索など）
    // 必要に応じてコメント解除
    /*
    this.table.addGlobalSecondaryIndex({
      indexName: 'StatusIndex',
      partitionKey: {
        name: 'status',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'createdAt',
        type: dynamodb.AttributeType.STRING,
      },
      projectionType: dynamodb.ProjectionType.ALL,
    });
    */

    // Outputs
    new cdk.CfnOutput(this, 'TableName', {
      value: this.table.tableName,
      description: 'User Agents DynamoDB Table Name',
      exportName: `CopilotKit-UserAgents-TableName-${envSuffix}`,
    });

    new cdk.CfnOutput(this, 'TableArn', {
      value: this.table.tableArn,
      description: 'User Agents DynamoDB Table ARN',
      exportName: `CopilotKit-UserAgents-TableArn-${envSuffix}`,
    });

    // Tags
    cdk.Tags.of(this.table).add('Component', 'UserAgentsDatabase');
    cdk.Tags.of(this.table).add('Environment', envSuffix);
  }
}
