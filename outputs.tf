output "cluster_name" {
  description = "Name of the provisioned cluster."
  value       = var.cluster_name
}

output "control_plane_lb_ip" {
  description = "Deprecated: no provider load balancer is provisioned."
  value       = null
}

output "private_lb_ip" {
  description = "Private control-plane endpoint IP. Used as the kubeconfig server address and tls-san; management access routes through Tailscale."
  value       = local.control_plane_endpoint_ip
}

output "control_plane_endpoint_ip" {
  description = "Private control-plane endpoint IP for Kubernetes API and RKE2 supervisor access."
  value       = local.control_plane_endpoint_ip
}

output "private_network_id" {
  description = "ID of the private IONOS LAN created for the cluster."
  value       = module.networking.network_id
}

output "private_network_name" {
  description = "Name of the private IONOS LAN created for the cluster."
  value       = module.networking.network_name
}

output "cluster_subnet_cidr" {
  description = "CIDR of the cluster subnet. Passed through for downstream workspaces."
  value       = var.cluster_subnet_cidr
}

output "node_pool_names" {
  description = "Names of all worker node pools."
  value       = [for p in var.node_pools : p.name]
}

output "kubeconfig" {
  description = <<-EOT
    Kubeconfig file contents for connecting to the cluster.
    Available after `terraform apply` completes. Write to disk:
      terraform output -raw kubeconfig > kubeconfig.yaml
    IMPORTANT: The state backend must use encryption — this value is stored in plaintext in Terraform state.
    Stored via terraform_data.kubeconfig_store so it persists across HCP Terraform remote runs.
  EOT
  value       = terraform_data.kubeconfig_store.output != "" ? terraform_data.kubeconfig_store.output : null
  sensitive   = true
}

output "rke2_token" {
  description = "RKE2 cluster join token. Only exposed when expose_rke2_token=true. Always stored in Terraform state regardless."
  value       = var.expose_rke2_token ? random_password.rke2_token.result : null
  sensitive   = true
}

output "first_cp_public_ip" {
  description = "Public IPv4 address of the first control plane node. Used for initial SSH access."
  value       = module.control_plane.first_node_public_ip
}

output "flux_public_key" {
  description = "Flux SSH deploy key public key. Register as a read-only GitHub deploy key when flux_deploy_key_mode='manual'."
  value       = module.addons.flux_public_key
}

output "grafana_admin_password" {
  description = "Auto-generated Grafana admin password. Retrieve with: terraform output -raw grafana_admin_password"
  value       = module.addons.grafana_admin_password
  sensitive   = true
}

output "argocd_admin_password_hint" {
  description = "kubectl command to retrieve the Argo CD initial admin password. Only set when enable_argocd=true."
  value       = module.addons.argocd_admin_password_hint
}

output "direct_envoy_nlb_ip" {
  description = "Reserved public IPv4 of the optional direct Envoy IONOS NLB."
  value       = var.enable_direct_envoy_nlb ? ionoscloud_ipblock.direct_envoy_ingress[0].ips[0] : null
}

output "direct_envoy_nlb_id" {
  description = "ID of the optional direct Envoy IONOS Network Load Balancer."
  value       = var.enable_direct_envoy_nlb ? ionoscloud_networkloadbalancer.direct_envoy_ingress[0].id : null
}

output "direct_envoy_nlb_forwarding_rule_id" {
  description = "ID of the optional direct Envoy TCP/443 forwarding rule."
  value       = var.enable_direct_envoy_nlb ? ionoscloud_networkloadbalancer_forwardingrule.direct_envoy_https[0].id : null
}
