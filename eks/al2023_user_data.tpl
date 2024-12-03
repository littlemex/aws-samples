apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    apiServerEndpoint: ${apiServerEndpoint}
    certificateAuthority: ${certificateAuthority}
    cidr: ${cidr}
    name: ${name}