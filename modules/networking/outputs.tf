output "datacenter_id" {
  description = "ID of the IONOS Virtual Data Center."
  value       = local.datacenter_id
}

output "datacenter_name" {
  description = "Name of the IONOS Virtual Data Center."
  value       = local.datacenter_name
}

output "public_lan_id" {
  description = "ID of the public IONOS LAN used for outbound node traffic."
  value       = local.public_lan_id
}

output "private_lan_id" {
  description = "ID of the private IONOS LAN used for cluster traffic."
  value       = local.private_lan_id
}

output "network_id" {
  description = "Compatibility output: private IONOS LAN ID."
  value       = local.private_lan_id
}

output "network_name" {
  description = "Compatibility output: IONOS private LAN name."
  value       = "${var.cluster_name}-private"
}

output "subnet_id" {
  description = "Compatibility output: private IONOS LAN ID."
  value       = local.private_lan_id
}

output "placement_group_id" {
  description = "Deprecated: IONOS Cubes do not expose provider-managed placement groups."
  value       = null
}

output "lb_id" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = null
}

output "lb_network_attachment_id" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = null
}

output "control_plane_lb_ip" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = null
}

output "private_lb_ip" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = null
}

output "lb_service_ids" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = []
}

output "firewall_id" {
  description = "Deprecated: IONOS firewall rules are NIC-local."
  value       = null
}
