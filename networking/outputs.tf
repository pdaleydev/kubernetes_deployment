output "ecr_api_endpoint_id" {
  description = "ID of the ECR API VPC endpoint"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_endpoint_id" {
  description = "ID of the ECR DKR VPC endpoint"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID attached to the interface endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.kubernetes.id
}

output "vpn_endpoint_dns" {
  description = "VPN endpoint DNS name — needed to build the .ovpn config file"
  value       = aws_ec2_client_vpn_endpoint.kubernetes.dns_name
}