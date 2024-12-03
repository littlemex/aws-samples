provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

data "aws_region" "current" {}

resource "aws_eks_cluster" "example" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = aws_subnet.example[*].id
    security_group_ids      = [aws_security_group.eks_security_group.id]
    endpoint_public_access  = false
    endpoint_private_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

data "aws_security_group" "eks_created_sg" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [aws_eks_cluster.example.name]
  }
}

resource "aws_security_group_rule" "eks_to_eks_sg_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_security_group.id
  source_security_group_id = data.aws_security_group.eks_created_sg.id
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

data "aws_availability_zones" "az" {}

resource "aws_subnet" "example" {
  count             = 2
  vpc_id            = aws_vpc.example.id
  cidr_block        = cidrsubnet(aws_vpc.example.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.az.names, count.index)
}

resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_security_group" "eks_security_group" {
  name        = "eks-security-group"
  description = "Security group for EKS cluster"

  vpc_id = aws_vpc.example.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  subnet_ids = aws_subnet.example[*].id
  ami_type   = "AL2023_x86_64_STANDARD"
}


variable "bootstrap_extra_args" {
  type        = string
  default     = "--use-max-pods false"
  description = "Additional arguments to pass to the bootstrap script"
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "eks-node-group-template"
  instance_type = "t3.medium"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  vpc_security_group_ids = [aws_security_group.eks_security_group.id]

  user_data = base64encode(<<-EOF
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

      --==MYBOUNDARY==
      Content-Type: text/x-shellscript; charset="us-ascii"

      #!/bin/bash
      set -ex
      /etc/eks/bootstrap.sh ${aws_eks_cluster.example.name} ${var.bootstrap_extra_args}
      --==MYBOUNDARY==--
      EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EKS-managed-node"
    }
  }
}

resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = aws_eks_cluster.example.name
}

variable "ami_id" {
  description = "The AMI ID to use for the EKS nodes"
  type        = string
}

variable "cluster_token" {
  description = "cluster auth token."
  type        = string
}

variable "extra_scripts" {
  description = "user data extra script."
  type        = string
}

locals {
  user_data = base64encode(templatefile("./al2023_user_data.tpl", {
    apiServerEndpoint    = aws_eks_cluster.example.endpoint
    certificateAuthority = aws_eks_cluster.example.certificate_authority[0].data
    cidr                 = aws_vpc.example.cidr_block
    name                 = aws_eks_cluster.example.name
    extra_scripts        = var.extra_scripts
  }))

  enable_bootstrap_user_data = true
  cloudinit_pre_nodeadm = [
    {
      content_type = "application/node.eks.aws"
      content      = <<-EOT
        ---
        apiVersion: node.eks.aws/v1alpha1
        kind: NodeConfig
        spec:
          kubelet:
            config:
              shutdownGracePeriod: 30s
              featureGates:
                DisableKubeletCloudCredentialProviders: true
      EOT
    }
  ]

  cloudinit_post_nodeadm = [{
    content      = <<-EOT
      echo "All done"
    EOT
    content_type = "text/x-shellscript; charset=\"us-ascii\""
  }]

  nodeadm_cloudinit = local.enable_bootstrap_user_data ? concat(
    local.cloudinit_pre_nodeadm,
    [{
      content_type = "application/node.eks.aws"
      content      = base64decode(local.user_data)
    }],
    local.cloudinit_post_nodeadm
  ) : local.cloudinit_pre_nodeadm
}

data "cloudinit_config" "al2023_eks_managed_node_group" {
  count = length(local.nodeadm_cloudinit) > 0 ? 1 : 0

  base64_encode = true
  gzip          = false
  boundary      = "MIMEBOUNDARY"

  dynamic "part" {
    for_each = { for i, v in local.nodeadm_cloudinit : i => v }

    content {
      content      = part.value.content
      content_type = try(part.value.content_type, null)
      filename     = try(part.value.filename, null)
      merge_type   = try(part.value.merge_type, null)
    }
  }
}

resource "aws_launch_template" "eks_nodes_custom_ami" {
  name_prefix   = "eks-node-group-custom-template"
  image_id      = var.ami_id
  instance_type = "t3.medium"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  vpc_security_group_ids = [aws_security_group.eks_security_group.id]

  user_data = data.cloudinit_config.al2023_eks_managed_node_group[0].rendered

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EKS-managed-node-custom-ami"
    }
  }
}

resource "aws_eks_node_group" "example-custom-ami" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example-custom-ami-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodes_custom_ami.id
    version = aws_launch_template.eks_nodes_custom_ami.latest_version
  }

  subnet_ids = aws_subnet.example[*].id
}

data "aws_route_table" "default" {
  vpc_id = aws_vpc.example.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.example.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [data.aws_route_table.default.id]

  tags = {
    Name = "MyVPCEndpointS3GW"
  }
}

resource "aws_vpc_endpoint" "s3_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointS3"
  }
}

resource "aws_vpc_endpoint" "ec2_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointEC2"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointECR"
  }
}

resource "aws_vpc_endpoint" "ecr_api_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointECRAPI"
  }
}

resource "aws_vpc_endpoint" "ssm_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointSSM"
  }
}

resource "aws_vpc_endpoint" "ec2messages_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointEC2MSG"
  }
}

resource "aws_vpc_endpoint" "ssmmessages_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointSSMMSG"
  }
}

resource "aws_vpc_endpoint" "sts_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointSTS"
  }
}

resource "aws_vpc_endpoint" "sagemaker_notebook_interface" {
  vpc_id             = aws_vpc.example.id
  service_name       = "aws.sagemaker.${data.aws_region.current.name}.notebook"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.example[*].id
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointSMNotebook"
  }
}

resource "aws_vpc_endpoint" "eks_interface" {
  vpc_id            = aws_vpc.example.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.eks"
  vpc_endpoint_type = "Interface"

  subnet_ids         = [aws_subnet.example[0].id, aws_subnet.example[1].id]
  security_group_ids = [aws_security_group.eks_security_group.id]

  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = true
  }

  tags = {
    Name = "MyVPCEndpointEKS"
  }
}

# Outputs for VPC endpoints can be added here if needed

output "subnet_ids" {
  description = "The IDs of the created subnets."
  value       = aws_subnet.example[*].id
}

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.example.id
}

output "node_group_role_arn" {
  description = "The ARN of the EKS node group IAM role."
  value       = aws_iam_role.eks_node_group_role.arn
}