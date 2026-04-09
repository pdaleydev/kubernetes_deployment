# -------------------------------------------------------------------
# IAM Role for EC2 — allows nodes to pull from S3 and ECR
# -------------------------------------------------------------------
resource "aws_iam_role" "kubernetes_node" {
  name = "kubernetes-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "kubernetes-node-role"
    ManagedBy   = "Terraform"
    Project = var.project_name
  }
}

# Allow nodes to pull from ECR
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.kubernetes_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "kubernetes_node" {
  name = "kubernetes-node-profile"
  role = aws_iam_role.kubernetes_node.name
}

# -------------------------------------------------------------------
# Security Group for Kubernetes nodes
# -------------------------------------------------------------------
resource "aws_security_group" "kubernetes_nodes" {
  name        = "kubernetes-nodes-sg"
  description = "Security group for Kubernetes cluster nodes"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  # Kubernetes API server — control plane only
  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  }

  # etcd — control plane only
  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true    # only from other nodes in this SG
  }

  # Allow ping from anywhere.
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  }

  # Allow SSH from anywhere.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # NodePort services range
  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  }

  # Flannel/Calico CNI overlay — adjust port if using a different CNI
  ingress {
    description = "Calico CNI VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  # Allow all internal node-to-node traffic
  ingress {
    description = "Inter-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow ping to anywhere.
  egress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound to external repos, HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound to external repos, HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  }

  tags = {
    Name        = "kubernetes-nodes-sg"
    ManagedBy   = "Terraform"
    Project = var.project_name
  }
}

# -------------------------------------------------------------------
# EC2 Instances — for_each over var.kubernetes_nodes
# -------------------------------------------------------------------
resource "aws_instance" "kubernetes_nodes" {
  for_each = var.kubernetes_nodes

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = data.terraform_remote_state.k8_networking.outputs.k8_private_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.kubernetes_node.name
  vpc_security_group_ids = [aws_security_group.kubernetes_nodes.id]
  key_name = "ansible-key"

  # No public IP — private subnet only
  associate_public_ip_address = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${each.key}-root-volume"
    }
  }

  # Render the userdata template per node
  user_data = templatefile("${path.module}/scripts/userdata.sh.tpl", {
    node_name          = each.key
    node_role          = each.value.role
    kubernetes_version = var.kubernetes_version
    pod_cidr           = var.pod_cidr
    aws_region         = var.aws_region
  })

  tags = {
    Name                = each.key
    Role                = each.value.role
    ManagedBy           = "Terraform"
    "kubernetes.io/role" = each.value.role
  }

  lifecycle {
    ignore_changes = [user_data]   # don't rebuild nodes if userdata changes after initial launch
  }
}