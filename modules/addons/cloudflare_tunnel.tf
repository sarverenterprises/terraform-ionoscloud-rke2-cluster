# =============================================================================
# Cloudflare Tunnel
#
# Creates a remotely-managed Cloudflare Tunnel and runs cloudflared connectors
# inside the cluster. The tunnel starts with an explicit 404 catch-all so the
# connector can be deployed before application hostnames are wired.
#
# Deployed only when var.enable_cloudflare_tunnel == true.
# =============================================================================

locals {
  cloudflare_tunnel_name = coalesce(var.cloudflare_tunnel_name, "${var.cluster_name}-ingress")
  cloudflare_tunnel_ingress_rules = concat(
    [
      for rule in var.cloudflare_tunnel_ingress : {
        hostname = try(rule.hostname, null)
        path     = try(rule.path, null)
        service  = rule.service
      }
    ],
    [
      for hostname in var.envoy_gateway_hostnames : {
        hostname = hostname
        service  = local.envoy_gateway_cloudflare_target
      } if var.enable_envoy_gateway
    ],
    [
      {
        service = "http_status:404"
      }
    ]
  )
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = local.cloudflare_tunnel_name
  config_src = "cloudflare"

  lifecycle {
    precondition {
      condition     = var.cloudflare_account_id != null && var.cloudflare_account_id != ""
      error_message = "enable_cloudflare_tunnel requires cloudflare_account_id."
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[0].id
  source     = "cloudflare"

  config = {
    ingress = local.cloudflare_tunnel_ingress_rules
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[0].id
}

resource "kubernetes_namespace_v1" "cloudflare_tunnel" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  metadata {
    name = "cloudflare-tunnel"
  }
}

resource "kubernetes_secret_v1" "cloudflare_tunnel_token" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace_v1.cloudflare_tunnel[0].metadata[0].name
  }

  data = {
    TUNNEL_TOKEN = data.cloudflare_zero_trust_tunnel_cloudflared_token.this[0].token
  }

  depends_on = [kubernetes_namespace_v1.cloudflare_tunnel]
}

resource "kubernetes_deployment_v1" "cloudflared" {
  count = var.enable_cloudflare_tunnel ? 1 : 0

  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.cloudflare_tunnel[0].metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = var.cloudflare_tunnel_replicas

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = var.cloudflared_image
          args  = ["tunnel", "--no-autoupdate", "run", "--token", "$(TUNNEL_TOKEN)"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.cloudflare_tunnel_token[0].metadata[0].name
                key  = "TUNNEL_TOKEN"
              }
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared_config.this,
    kubernetes_secret_v1.cloudflare_tunnel_token,
    null_resource.wait_for_coredns,
  ]
}
