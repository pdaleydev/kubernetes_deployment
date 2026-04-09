# Reference the existing VPC from the other state
# We use a data source so we don't manage it, just read it
data "aws_vpc" "existing" {
  id = data.terraform_remote_state.networking.outputs.vpc_id
}

# Private Subnet
resource "aws_subnet" "kubernetes_private" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false   # private — no public IPs

  tags = {
    Project = var.project_name
    "kubernetes.io/role/internal-elb" = "1"   # tells K8s this is an internal subnet
  }
}

# -------------------------------------------------------------------
# Security Group for Interface Endpoints (ECR API + ECR DKR)
# -------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name        = "kubernetes-vpc-endpoints-sg"
  description = "Allow HTTPS from private subnet to VPC interface endpoints"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "HTTPS from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Interface Endpoint — ECR API
# (authentication, image manifest lookups)
# -------------------------------------------------------------------
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.existing.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.kubernetes_private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true    # lets nodes use the standard ECR DNS names

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Interface Endpoint — ECR DKR
# (actual image layer resolution)
# -------------------------------------------------------------------
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.existing.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.kubernetes_private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Gateway Endpoint — S3
# (ECR stores image layer blobs here)
# Note: Gateway type - free, no security group, wired to route table
# -------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.existing.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.kubernetes_private.id]

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Security group for the VPN endpoint
# -------------------------------------------------------------------
resource "aws_security_group" "vpn_endpoint" {
  name        = "kubernetes-vpn-endpoint-sg"
  description = "Security group for AWS Client VPN endpoint"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # Allow VPN tunnel traffic in
  ingress {
    description = "Client VPN UDP"
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow VPN clients to reach anything in the private subnet
  egress {
    description = "Allow all outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Client VPN Endpoint
# -------------------------------------------------------------------
resource "aws_ec2_client_vpn_endpoint" "kubernetes" {
  description            = "Kubernetes cluster VPN access"
  server_certificate_arn = var.server_cert_arn
  client_cidr_block      = var.vpn_client_cidr
  vpc_id                 = data.terraform_remote_state.networking.outputs.vpc_id
  security_group_ids     = [aws_security_group.vpn_endpoint.id]
  self_service_portal    = "disabled"
  session_timeout_hours  = 24

  # Mutual TLS authentication
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_cert_arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn.name
  }

  tags = {
    Project        = var.project_name
  }
}

# -------------------------------------------------------------------
# Associate VPN endpoint with the private subnet
# -------------------------------------------------------------------
resource "aws_ec2_client_vpn_network_association" "kubernetes" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.kubernetes.id
  subnet_id              = aws_subnet.kubernetes_private.id
}

# -------------------------------------------------------------------
# Authorisation rule — allow VPN clients to reach the private subnet
# -------------------------------------------------------------------
resource "aws_ec2_client_vpn_authorization_rule" "private_subnet" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.kubernetes.id
  target_network_cidr    = aws_subnet.kubernetes_private.cidr_block
  authorize_all_groups   = true
  description            = "Allow VPN clients to reach private subnet"
}

# -------------------------------------------------------------------
# CloudWatch logs for VPN connections
# -------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/kubernetes/vpn"
  retention_in_days = 7

  tags = {
    Project        = var.project_name
  }
}

resource "aws_cloudwatch_log_stream" "vpn" {
  name           = "vpn-connections"
  log_group_name = aws_cloudwatch_log_group.vpn.name
}

# -------------------------------------------------------------------
# NATGW to allow ubuntu instances to connect to apt repos.
# -------------------------------------------------------------------

# 1. Allocate a Static IP (Elastic IP) for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { 
    Project = var.project_name
    }
}

# 2. Create the NAT Gateway
# This MUST be placed in a PUBLIC subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.terraform_remote_state.networking.outputs.public_subnet_a # A subnet with an IGW route

  tags   = { 
    Project = var.project_name
    }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
}

# 3. Create a Route Table for the Private Subnet
resource "aws_route_table" "kubernetes_private" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags   = { 
    Project = var.project_name
    }
}

# 4. Associate the Private Subnet with the Private Route Table
resource "aws_route_table_association" "kubernetes_private" {
  subnet_id      = aws_subnet.kubernetes_private.id
  route_table_id = aws_route_table.kubernetes_private.id
}