output "server_ids" {
  description = "List of IONOS server IDs in this pool."
  value       = ionoscloud_cube_server.nodes[*].id
}

output "server_names" {
  description = "List of server names in this pool."
  value       = ionoscloud_cube_server.nodes[*].name
}

output "private_ips" {
  description = "Private network IP addresses of all nodes in this pool."
  value       = local.node_private_ips
}

output "public_ips" {
  description = "Public IPv4 addresses of nodes. Empty string for nodes without a public IP."
  value       = [for s in ionoscloud_cube_server.nodes : try(s.primary_ip, "")]
}

output "first_node_public_ip" {
  description = "Public IPv4 of the first node in this pool. Used for initial SSH access to fetch kubeconfig."
  value       = length(ionoscloud_cube_server.nodes) > 0 ? try(ionoscloud_cube_server.nodes[0].primary_ip, null) : null
}

output "first_node_id" {
  description = "IONOS server ID of the first node."
  value       = length(ionoscloud_cube_server.nodes) > 0 ? ionoscloud_cube_server.nodes[0].id : null
}

output "volume_attachment_ids" {
  description = "IDs of Longhorn volume attachments. Empty if longhorn_volume_size=0."
  value       = ionoscloud_volume.longhorn_data[*].id
}
