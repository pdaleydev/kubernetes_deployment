variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "aws_user" {
  type = string
}

variable "aws_credential_path" {
  type = string
}

variable "ami_id" {
  description = "AMI ID for the Kubernetes nodes (use Amazon Linux 2 or Ubuntu 22.04)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.29"
}

variable "pod_cidr" {
  description = "CIDR block for Kubernetes pods (must not overlap with VPC)"
  type        = string
  default     = "192.168.0.0/16"
}

# Node definitions — this drives the for_each
variable "kubernetes_nodes" {
  description = "Map of Kubernetes nodes to create"
  type = map(object({
    role          = string           # "control-plane" or "worker"
    instance_type = string
    volume_size   = number
  }))
  default = {
    "k8s-control-plane" = {
      role          = "control-plane"
      instance_type = "t3.medium"
      volume_size   = 25
    }
    "k8s-worker-1" = {
      role          = "worker"
      instance_type = "t3.medium"
      volume_size   = 25
    }
#    "k8s-worker-2" = {
#      role          = "worker"
#      instance_type = "t3.medium"
#      volume_size   = 25
#    }
#    "k8s-worker-3" = {
#      role          = "worker"
#      instance_type = "t3.medium"
#      volume_size   = 25
#    }
  }
}

variable "project_name" {
  type    = string
  default = "Kubernetes"
}