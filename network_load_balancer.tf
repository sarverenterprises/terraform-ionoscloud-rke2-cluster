# =============================================================================
# Optional direct Envoy ingress
#
# This is deliberately independent of the Kubernetes cloud-controller manager.
# The IONOS NLB forwards TCP/443 to a fixed NodePort on every cluster node's
# private address; the existing Envoy Gateway data plane terminates TLS
# in-cluster. Kubernetes NodePort makes the endpoint available on control-plane
# and worker nodes unless a cluster explicitly restricts kube-proxy behavior.
# =============================================================================

locals {
  direct_envoy_node_ips = concat(
    module.control_plane.private_ips,
    flatten([for pool in module.worker_pools : pool.private_ips])
  )
}

resource "ionoscloud_ipblock" "direct_envoy_ingress" {
  count = var.enable_direct_envoy_nlb ? 1 : 0

  name     = "${var.cluster_name}-envoy-ingress"
  location = local.control_plane_location
  size     = 1
}

resource "ionoscloud_networkloadbalancer" "direct_envoy_ingress" {
  count = var.enable_direct_envoy_nlb ? 1 : 0

  name          = "${var.cluster_name}-envoy-ingress"
  datacenter_id = module.networking.datacenter_id
  listener_lan  = module.networking.public_lan_id
  target_lan    = module.networking.private_lan_id
  ips           = [ionoscloud_ipblock.direct_envoy_ingress[0].ips[0]]

  # IONOS otherwise auto-assigns an address from the LAN's provider-computed
  # subnet, which may not match the explicit RFC1918 addresses assigned to RKE2
  # nodes. Keep the NLB's target-side address in the same subnet as every node.
  lb_private_ips = [
    "${cidrhost(var.cluster_subnet_cidr, 225)}/${split("/", var.cluster_subnet_cidr)[1]}"
  ]

  # Keep the lowest-cost configuration: no flow logs or central logging.
  central_logging = false
}

resource "ionoscloud_networkloadbalancer_forwardingrule" "direct_envoy_https" {
  count = var.enable_direct_envoy_nlb ? 1 : 0

  name                   = "${var.cluster_name}-envoy-https"
  datacenter_id          = module.networking.datacenter_id
  networkloadbalancer_id = ionoscloud_networkloadbalancer.direct_envoy_ingress[0].id
  algorithm              = "ROUND_ROBIN"
  protocol               = "TCP"
  listener_ip            = ionoscloud_ipblock.direct_envoy_ingress[0].ips[0]
  listener_port          = 443

  # These are inactivity timeouts, not maximum request durations. Long values
  # prevent slow registry uploads from being cut off during quiet intervals.
  health_check {
    client_timeout  = var.direct_envoy_nlb_client_timeout_ms
    connect_timeout = var.direct_envoy_nlb_connect_timeout_ms
    target_timeout  = var.direct_envoy_nlb_target_timeout_ms
    retries         = var.direct_envoy_nlb_retries
  }

  dynamic "targets" {
    for_each = toset(local.direct_envoy_node_ips)
    content {
      ip     = targets.value
      port   = var.direct_envoy_node_port
      weight = 1

      health_check {
        check          = true
        check_interval = var.direct_envoy_nlb_health_check_interval_ms
        maintenance    = false
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.direct_envoy_node_ips) > 0
      error_message = "enable_direct_envoy_nlb requires at least one cluster node target."
    }
  }
}
