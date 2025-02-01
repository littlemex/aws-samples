import { Stack, StackProps } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam"
import * as path from "path";
import { Asset } from "aws-cdk-lib/aws-s3-assets";
import { Construct } from "constructs";

export class Ec2SsmCdkStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const region: string = process.env.CDK_DEFAULT_REGION || "us-east-1";

    // Look up the Deep Learning AMI
    const ami = new ec2.LookupMachineImage({
      name: "Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.5*Ubuntu*",
      owners: ["amazon"],
    });

    // Create a new VPC with public subnets in different AZs
    const vpc = new ec2.Vpc(this, "VPC", {
      maxAzs: 2,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
        }
      ]
    });

    // Security group for EC2 instance
    const ec2SecurityGroup = new ec2.SecurityGroup(this, "EC2SecurityGroup", {
      vpc,
      description: "Security group for EC2 instance",
      allowAllOutbound: true,
    });

    // IAM role with SSM access
    const role = new iam.Role(this, "ec2Role", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com")
    });

    // Add SSM managed policy
    role.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
    );

    // Add policy for Session Manager port forwarding
    role.addToPrincipalPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'ssmmessages:CreateControlChannel',
        'ssmmessages:CreateDataChannel',
        'ssmmessages:OpenControlChannel',
        'ssmmessages:OpenDataChannel'
      ],
      resources: ['*']
    }));

    const ec2Instance = new ec2.Instance(this, "Instance", {
      vpc,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.G6, ec2.InstanceSize.XLARGE4),
      machineImage: ami,
      securityGroup: ec2SecurityGroup,
      role: role,
      blockDevices: [
        {
          deviceName: "/dev/sda1",
          volume: ec2.BlockDeviceVolume.ebs(500),
        },
      ],
      vpcSubnets: {
        subnetType: ec2.SubnetType.PUBLIC
      }
    });


    const asset = new Asset(this, "Asset", { path: path.join(__dirname, "../config.sh") });
    const localPath = ec2Instance.userData.addS3DownloadCommand({
      bucket: asset.bucket,
      bucketKey: asset.s3ObjectKey,
    });

    // Execute config.sh in cloud-init runcmd section
    ec2Instance.userData.addCommands(
      "mkdir -p /var/lib/cloud/scripts/per-instance",
      `cp ${localPath} /var/lib/cloud/scripts/per-instance/config.sh`,
      "chmod +x /var/lib/cloud/scripts/per-instance/config.sh",
      "/var/lib/cloud/scripts/per-instance/config.sh > /var/log/config-script.log 2>&1"
    );
    asset.grantRead(ec2Instance.role);

    // Outputs
    new cdk.CfnOutput(this, "Instance ID", { value: ec2Instance.instanceId });
    new cdk.CfnOutput(this, "Prerequisites", { 
      value: "1. Install AWS CLI\n2. Install Session Manager plugin (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)"
    });
    new cdk.CfnOutput(this, "Port Forward Command", { 
      value: `aws ssm start-session --target ${ec2Instance.instanceId} --region ${region} --document-name AWS-StartPortForwardingSession --parameters "portNumber"=["8080"],"localPortNumber"=["8080"]`
    });
    new cdk.CfnOutput(this, "Access URL", {
      value: "After running the port forward command, access: https://localhost:8080"
    });
  }    
}
