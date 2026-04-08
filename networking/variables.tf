variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_user" {
  type = string
}

variable "aws_credential_path" {
  type = string
}

variable "project_name" {
  type    = string
  default = "Kubernetes"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the private subnet"
  type        = string
  default     = "us-east-2a"
}

variable "server_cert_arn" {
  description = "ACM ARN of the VPN server certificate - from Kubernetes Config Doc"
  type        = string
}

variable "client_cert_arn" {
  description = "ACM ARN of the client certificate - from Kubernetes Config Doc"
  type        = string
}

variable "vpn_client_cidr" {
  description = "CIDR block assigned to VPN clients — must not overlap with VPC or private subnet"
  type        = string
}