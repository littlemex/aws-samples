import * as cdk from 'aws-cdk-lib';
import * as sagemaker from 'aws-cdk-lib/aws-sagemaker';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class MlflowStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // MLflow アーティファクト用の S3 バケットを作成
    const artifactBucket = new s3.Bucket(this, 'MlflowArtifactBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
    });

    // MLflow サーバー用の IAM ロールを作成
    const mlflowRole = new iam.Role(this, 'MlflowServerRole', {
      assumedBy: new iam.ServicePrincipal('sagemaker.amazonaws.com'),
    });

    // S3 バケットへのアクセス権限を付与
    artifactBucket.grantReadWrite(mlflowRole);

    // MLflow トラッキングサーバーを作成
    const mlflowServer = new sagemaker.CfnMlflowTrackingServer(this, 'MlflowTrackingServer', {
      trackingServerName: 'mlflow-tracking-server',
      artifactStoreUri: artifactBucket.s3UrlForObject(),
      roleArn: mlflowRole.roleArn,
      trackingServerSize: 'Small',
    });

    // 出力を設定
    new cdk.CfnOutput(this, 'MlflowTrackingServerName', {
      value: mlflowServer.attrTrackingServerArn,
      description: 'MLflow トラッキングサーバーの ARN',
      exportName: 'MlflowTrackingServerArn',
    });

    new cdk.CfnOutput(this, 'MlflowArtifactBucketName', {
      value: artifactBucket.bucketName,
      description: 'MLflow アーティファクトバケットの名前',
      exportName: 'MlflowArtifactBucketName',
    });

    new cdk.CfnOutput(this, 'MlflowRoleArn', {
      value: mlflowRole.roleArn,
      description: 'MLflow サーバーの IAM ロール ARN',
      exportName: 'MlflowRoleArn',
    });
  }
}
