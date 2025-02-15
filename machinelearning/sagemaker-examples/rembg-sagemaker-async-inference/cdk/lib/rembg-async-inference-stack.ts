import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as sns from 'aws-cdk-lib/aws-sns';
import { Construct } from 'constructs';

export class RembgAsyncInferenceStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create S3 buckets for input and output
    const inputBucket = new s3.Bucket(this, 'InputBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      cors: [{
        allowedMethods: [
          s3.HttpMethods.PUT,
          s3.HttpMethods.POST,
          s3.HttpMethods.GET
        ],
        allowedOrigins: ['*'],
        allowedHeaders: ['*'],
      }]
    });

    const outputBucket = new s3.Bucket(this, 'OutputBucket', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      cors: [{
        allowedMethods: [s3.HttpMethods.GET],
        allowedOrigins: ['*'],
        allowedHeaders: ['*'],
      }]
    });

    // Create ECR repository
    const repository = new ecr.Repository(this, 'RembgRepository', {
      repositoryName: 'rembg-async',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      imageScanOnPush: true,
    });

    // Create SNS topic for async inference notifications
    const notificationTopic = new sns.Topic(this, 'AsyncInferenceTopic', {
      displayName: 'Rembg Async Inference Notifications'
    });

    // Create SageMaker execution role
    const sagemakerRole = new iam.Role(this, 'SageMakerExecutionRole', {
      assumedBy: new iam.ServicePrincipal('sagemaker.amazonaws.com'),
      description: 'Execution role for Rembg SageMaker endpoint'
    });

    // Add required policies to SageMaker role
    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        's3:GetObject',
        's3:PutObject',
        's3:ListBucket'
      ],
      resources: [
        inputBucket.bucketArn,
        `${inputBucket.bucketArn}/*`,
        outputBucket.bucketArn,
        `${outputBucket.bucketArn}/*`
      ]
    }));

    // Add ECR repository access permissions
    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'ecr:GetDownloadUrlForLayer',
        'ecr:BatchGetImage',
        'ecr:BatchCheckLayerAvailability'
      ],
      resources: [`arn:aws:ecr:${this.region}:${this.account}:repository/*`]
    }));

    // Add ECR authorization token permission
    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: ['ecr:GetAuthorizationToken'],
      resources: ['*']  // GetAuthorizationToken requires resource "*"
    }));

    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'cloudwatch:PutMetricData',
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents'
      ],
      resources: ['*']
    }));

    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: ['sns:Publish'],
      resources: [notificationTopic.topicArn]
    }));

    // Add permissions for SageMaker default bucket
    sagemakerRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        's3:ListBucket',
        's3:PutObject'
      ],
      resources: [
        `arn:aws:s3:::sagemaker-${this.region}-${this.account}`,
        `arn:aws:s3:::sagemaker-${this.region}-${this.account}/*`
      ]
    }));

    // Output the resource information
    new cdk.CfnOutput(this, 'InputBucketName', {
      value: inputBucket.bucketName,
      description: 'Name of the S3 bucket for input images'
    });

    new cdk.CfnOutput(this, 'OutputBucketName', {
      value: outputBucket.bucketName,
      description: 'Name of the S3 bucket for processed images'
    });

    new cdk.CfnOutput(this, 'SageMakerRoleArn', {
      value: sagemakerRole.roleArn,
      description: 'ARN of the SageMaker execution role'
    });

    new cdk.CfnOutput(this, 'ECRRepositoryUri', {
      value: repository.repositoryUri,
      description: 'URI of the ECR repository'
    });

    new cdk.CfnOutput(this, 'NotificationTopicArn', {
      value: notificationTopic.topicArn,
      description: 'ARN of the SNS notification topic'
    });
  }
}