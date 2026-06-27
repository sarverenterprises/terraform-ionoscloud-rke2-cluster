locals {
  has_node_dns = length(var.node_dns_servers) > 0

  node_dns_resolv_conf_lines = concat(
    length(var.node_dns_search_domains) > 0 ? ["search ${join(" ", var.node_dns_search_domains)}"] : [],
    [for server in var.node_dns_servers : "nameserver ${server}"],
    ["options timeout:2 attempts:3"]
  )

  node_dns_resolv_conf_content = join("\n", local.node_dns_resolv_conf_lines)
  node_dns_systemd_servers     = join(" ", var.node_dns_servers)
  node_dns_systemd_domains     = length(var.node_dns_search_domains) > 0 ? join(" ", var.node_dns_search_domains) : "~."

  # ==========================================================================
  # Control Plane
  # ==========================================================================

  # Effective location for control plane nodes
  control_plane_location = coalesce(var.control_plane_location, var.location)

  # Static private IP for the first control plane node.
  # Assigned explicitly so that worker cloud-inits can reference it at plan time
  # without a circular dependency. Uses the .10 address of the subnet host range.
  first_cp_private_ip = cidrhost(var.cluster_subnet_cidr, 10)

  # Private management endpoint for the Kubernetes API and RKE2 supervisor.
  # Operators reach this over Tailscale-advertised cluster subnet routes.
  control_plane_endpoint_ip = local.first_cp_private_ip
  private_network_gateway   = cidrhost(var.network_cidr, 1)

  # Terraform management endpoints can differ from the cluster-internal endpoint.
  # CI runners without kernel TUN support can use each node's direct Tailscale IP
  # for health checks and SSH instead of routing the private LAN.
  terraform_management_endpoint_ip = coalesce(var.control_plane_management_endpoint_ip, local.control_plane_endpoint_ip)
  terraform_control_plane_ips      = length(var.control_plane_management_ips) == var.control_plane_node_count ? var.control_plane_management_ips : module.control_plane.private_ips

  # ==========================================================================
  # Worker Node Counts (for Longhorn replica computation)
  # ==========================================================================

  # Sum of all worker nodes: fixed pools use node_count, autoscaled use min_nodes
  total_worker_nodes = length(var.node_pools) == 0 ? 0 : sum([
    for p in var.node_pools :
    p.scaling_mode == "autoscaled" ? p.min_nodes : p.node_count
  ])

  # Longhorn replica count: never exceed worker node count; cap at 3 for HA
  longhorn_default_replicas = min(local.total_worker_nodes, 3)

  # ==========================================================================
  # Autoscaler Cloud-Inits (reserved for future IONOS autoscaler support)
  #
  # Rendered here (root module) rather than inside modules/addons so that the
  # templatefile() path is always relative to the root, which works whether
  # the module is sourced locally or from a Git remote. The addons module
  # receives the rendered strings via var.autoscaler_pool_cloud_inits.
  # ==========================================================================
  autoscaler_pool_cloud_inits = {
    for p in var.node_pools : "${var.cluster_name}-${p.name}" => templatefile(
      "${path.module}/modules/node-pool/templates/worker-init.yaml.tpl",
      {
        rke2_version             = var.rke2_version
        rke2_token               = random_password.rke2_token.result
        control_plane_lb_ip      = local.control_plane_endpoint_ip
        node_ip                  = null
        has_labels               = length(p.labels) > 0
        label_args               = join("\n", [for k, v in p.labels : "        - \"${k}=${v}\""])
        has_taints               = length(p.taints) > 0
        taint_args               = join("\n", [for t in p.taints : "        - \"${t.key}=${t.value}:${t.effect}\""])
        longhorn_volume_size     = p.longhorn_volume_size
        enable_tailscale         = var.enable_tailscale_nodes
        tailscale_auth_key       = coalesce(var.tailscale_node_auth_key, "")
        cluster_subnet_cidr      = var.cluster_subnet_cidr
        private_network_gateway  = local.private_network_gateway
        has_node_dns             = local.has_node_dns
        node_dns_systemd_servers = local.node_dns_systemd_servers
        node_dns_systemd_domains = local.node_dns_systemd_domains
        node_dns_resolv_conf     = local.node_dns_resolv_conf_content
        # Placeholder hostname — an autoscaler would append a unique suffix per provisioned node.
        hostname = "${var.cluster_name}-${p.name}-autoscale"
      }
    ) if p.scaling_mode == "autoscaled"
  }

  # ==========================================================================
  # Kubeconfig (written to disk by null_resource.fetch_kubeconfig)
  # ==========================================================================
  kubeconfig_path = abspath("${path.root}/.kube/${var.cluster_name}.yaml")
}
