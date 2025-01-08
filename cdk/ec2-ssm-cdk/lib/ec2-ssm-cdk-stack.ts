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

    const vpc = ec2.Vpc.fromLookup(this, "VPC", {
      isDefault: true
    });

    // Security group without SSH access
    const securityGroup = new ec2.SecurityGroup(this, "SecurityGroup", {
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

    const ec2Instance = new ec2.Instance(this, "Instance", {
      vpc,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.G6, ec2.InstanceSize.XLARGE4),
      machineImage: ami,
      securityGroup: securityGroup,
      role: role,
      blockDevices: [
        {
          deviceName: "/dev/sda1",
          volume: ec2.BlockDeviceVolume.ebs(500),
        },
      ],
    });

    // Add user data script to install and start SSM agent
    ec2Instance.userData.addCommands(
      // Update package list
      "apt-get update",
      // Install required dependencies
      "apt-get install -y snapd",
      // Install SSM agent via snap
      "snap install amazon-ssm-agent --classic",
      // Start SSM agent
      "snap start amazon-ssm-agent"
    );

    const asset = new Asset(this, "Asset", { path: path.join(__dirname, "../config.sh") });
    const localPath = ec2Instance.userData.addS3DownloadCommand({
      bucket: asset.bucket,
      bucketKey: asset.s3ObjectKey,
    });

    ec2Instance.userData.addExecuteFileCommand({
      filePath: localPath,
      arguments: "--verbose -y"
    });
    asset.grantRead(ec2Instance.role);

    new cdk.CfnOutput(this, "Instance ID", { value: ec2Instance.instanceId });
    new cdk.CfnOutput(this, "Notifications", { 
      value: `Please install session-manager-plugin to your local pc.`
    });
    new cdk.CfnOutput(this, "Connect Command", { 
      value: `aws ssm start-session --target ${ec2Instance.instanceId} --region ${region}`
    });
  }    
}
