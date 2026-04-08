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

# Route table for the private subnet
resource "aws_route_table" "kubernetes_private" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Project = var.project_name
  }
}

# Associate the route table with the private subnet
resource "aws_route_table_association" "kubernetes_private" {
  subnet_id      = aws_subnet.kubernetes_private.id
  route_table_id = aws_route_table.kubernetes_private.id
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