# =============================================================================
# RKE2 CoreDNS Upstream Resolver Override
#
# RKE2 owns the rke2-coredns HelmChart. This module may optionally own the
# matching HelmChartConfig so CoreDNS forwards public lookups to explicit,
# stable upstream resolvers instead of inheriting pod /etc/resolv.conf. That
# avoids node/runtime resolver search domains or IPv6-only upstreams turning
# public AAAA lookups into SERVFAIL.
# =============================================================================

locals {
  coredns_forward_parameters = length(var.coredns_upstream_servers) > 0 ? ". ${join(" ", var.coredns_upstream_servers)}" : null

  coredns_servers = [
    {
      zones = [
        {
          zone    = "."
          use_tcp = true
        }
      ]
      port = 53
      plugins = [
        {
          name = "errors"
        },
        {
          name        = "health"
          configBlock = <<-EOT
            lameduck 10s
          EOT
        },
        {
          name = "ready"
        },
        {
          name        = "kubernetes"
          parameters  = "in-addr.arpa ip6.arpa"
          configBlock = <<-EOT
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
          EOT
        },
        {
          name       = "prometheus"
          parameters = "0.0.0.0:9153"
        },
        {
          name       = "forward"
          parameters = local.coredns_forward_parameters
        },
        {
          name       = "cache"
          parameters = "30"
        },
        {
          name = "loop"
        },
        {
          name = "reload"
        },
        {
          name = "loadbalance"
        },
      ]
    }
  ]
}

resource "kubernetes_manifest" "rke2_coredns_config" {
  count = length(var.coredns_upstream_servers) > 0 ? 1 : 0

  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-coredns"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = yamlencode({
        servers = local.coredns_servers
      })
    }
  }

  depends_on = [null_resource.wait_for_coredns]
}
