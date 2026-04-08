output "iam_username" {
  description = "IAM username"
  value       = aws_iam_user.kubernetes_control.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = aws_iam_user.kubernetes_control.arn
}

output "access_key_id" {
  description = "AWS Access Key ID — use this in 'aws configure' on your control node"
  value       = aws_iam_access_key.kubernetes_control.id
}

output "secret_access_key" {
  description = "AWS Secret Access Key — store this securely, it will not be shown again"
  value       = aws_iam_access_key.kubernetes_control.secret
  sensitive   = true
}