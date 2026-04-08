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

variable "iam_username" {
  description = "Name of the IAM user for the Kubernetes control node"
  type        = string
  default     = "kubernetes-control"
}