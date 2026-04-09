output "node_ids" {
  description = "Map of node name to EC2 instance ID"
  value       = { for k, v in aws_instance.kubernetes_nodes : k => v.id }
}

output "node_private_ips" {
  description = "Map of node name to private IP — use these in your Ansible inventory"
  value       = { for k, v in aws_instance.kubernetes_nodes : k => v.private_ip }
}

output "control_plane_ip" {
  description = "Private IP of the control plane node"
  value = {
    for k, v in aws_instance.kubernetes_nodes : k => v.private_ip
    if v.tags["Role"] == "control-plane"
  }
}

output "worker_ips" {
  description = "Private IPs of the worker nodes"
  value = {
    for k, v in aws_instance.kubernetes_nodes : k => v.private_ip
    if v.tags["Role"] == "worker"
  }
}

output "security_group_id" {
  description = "Security group ID attached to the nodes"
  value       = aws_security_group.kubernetes_nodes.id
}