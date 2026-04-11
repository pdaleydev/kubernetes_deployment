# IAM User
resource "aws_iam_user" "kubernetes_control" {
  name = var.iam_username
  path = "/kubernetes/"

  tags = {
    Project = var.project_name
  }
}

# IAM Access Key (used by Ansible/AWS CLI on your control node)
resource "aws_iam_access_key" "kubernetes_control" {
  user = aws_iam_user.kubernetes_control.name
}

# IAM Policy — scoped to what the control node actually needs
resource "aws_iam_policy" "kubernetes_control" {
  name        = "kubernetes-control-policy"
  path        = "/kubernetes/"
  description = "Permissions for the Kubernetes control node to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # EC2 — manage nodes, security groups, key pairs
      {
        Sid    = "EC2Management"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:CreateTags",
          "ec2:ImportKeyPair",
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },

      # EKS — create and manage Kubernetes clusters
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:UpdateNodegroupConfig",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = "*"
      },

      # IAM — limited, only for EKS service roles
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListRoles",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = "*"
      },

      # VPC — manage networking for the cluster
      {
        Sid    = "VPCManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable"
        ]
        Resource = "*"
      },

      # SSM — pull AMI IDs and secrets
      {
        Sid    = "SSMReadOnly"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      # ACM — manage VPN certificates
      {
        Sid    = "ACMManagement"
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:DeleteCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate",
          "acm:AddTagsToCertificate"
        ]
        Resource = "*"
      },
      # Client VPN — manage VPN endpoints and configurations
      {
        Sid    = "ClientVPNManagement"
        Effect = "Allow"
        Action = [
          "ec2:ExportClientVpnClientConfiguration",
          "ec2:CreateClientVpnEndpoint",
          "ec2:DeleteClientVpnEndpoint",
          "ec2:DescribeClientVpnEndpoints",
          "ec2:ModifyClientVpnEndpoint",
          "ec2:CreateClientVpnRoute",
          "ec2:DeleteClientVpnRoute",
          "ec2:DescribeClientVpnRoutes",
          "ec2:AuthorizeClientVpnIngress",
          "ec2:RevokeClientVpnIngress",
          "ec2:DescribeClientVpnAuthorizationRules",
          "ec2:AssociateClientVpnTargetNetwork",
          "ec2:DisassociateClientVpnTargetNetwork",
          "ec2:DescribeClientVpnTargetNetworks",
          "ec2:ApplySecurityGroupsToClientVpnTargetNetwork"
        ]
        Resource = "*"
      },
      # CloudWatch — VPN connection logging
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "kubernetes_control" {
  user       = aws_iam_user.kubernetes_control.name
  policy_arn = aws_iam_policy.kubernetes_control.arn
}