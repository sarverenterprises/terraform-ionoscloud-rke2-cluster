# =============================================================================
# Envoy Gateway
#
# Installs Envoy Gateway and creates a default GatewayClass/Gateway pair for
# cluster ingress. The Envoy data-plane Service name is pinned through
# EnvoyProxy so Cloudflare Tunnel can target a stable in-cluster DNS name.
#
# Deployed only when var.enable_envoy_gateway == true.
# =============================================================================

locals {
  envoy_gateway_cloudflare_target = "http://${var.envoy_gateway_service_name}.${var.envoy_gateway_namespace}.svc.cluster.local:80"

  envoy_gateway_external_dns_annotations = (
    var.enable_cloudflare_tunnel && length(var.envoy_gateway_hostnames) > 0
    ? {
      "external-dns.alpha.kubernetes.io/hostname"           = join(",", var.envoy_gateway_hostnames)
      "external-dns.alpha.kubernetes.io/target"             = "${cloudflare_zero_trust_tunnel_cloudflared.this[0].id}.cfargotunnel.com"
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
    }
    : {}
  )

  direct_envoy_external_dns_annotations = var.direct_envoy_publish_dns ? {
    "external-dns.alpha.kubernetes.io/hostname"           = var.direct_envoy_hostname
    "external-dns.alpha.kubernetes.io/target"             = var.direct_envoy_nlb_ip
    "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "false"
  } : {}

  direct_envoy_manifests = slice([
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = var.direct_envoy_tls_secret_name
        namespace = var.envoy_gateway_namespace
      }
      spec = {
        secretName = var.direct_envoy_tls_secret_name
        dnsNames   = [var.direct_envoy_hostname]
        issuerRef = {
          name = "letsencrypt-prod"
          kind = "ClusterIssuer"
        }
      }
    },
    {
      apiVersion = "v1"
      kind       = "Service"
      metadata = {
        name      = "${var.envoy_gateway_service_name}-direct"
        namespace = var.envoy_gateway_namespace
      }
      spec = {
        type = "NodePort"
        selector = {
          "gateway.envoyproxy.io/owning-gateway-name"      = var.envoy_gateway_name
          "gateway.envoyproxy.io/owning-gateway-namespace" = var.envoy_gateway_namespace
        }
        ports = [{
          name       = "https"
          protocol   = "TCP"
          port       = 443
          targetPort = 10443
          nodePort   = var.direct_envoy_node_port
        }]
      }
    },
    {
      # ExternalDNS intentionally ignores some NodePort Services even when a
      # target annotation is present. Keep DNS ownership on a separate
      # ClusterIP marker while the NodePort remains dedicated to NLB traffic.
      apiVersion = "v1"
      kind       = "Service"
      metadata = {
        name        = "${var.envoy_gateway_service_name}-direct-dns"
        namespace   = var.envoy_gateway_namespace
        annotations = local.direct_envoy_external_dns_annotations
      }
      spec = {
        type = "ClusterIP"
        ports = [{
          name       = "https"
          protocol   = "TCP"
          port       = 443
          targetPort = 443
        }]
      }
    }
  ], 0, var.enable_direct_envoy_nlb ? (var.direct_envoy_publish_dns ? 3 : 2) : 0)

  envoy_gateway_manifests = [
    {
      apiVersion = "gateway.envoyproxy.io/v1alpha1"
      kind       = "EnvoyProxy"
      metadata = {
        name      = var.envoy_gateway_proxy_name
        namespace = var.envoy_gateway_namespace
      }
      spec = {
        provider = {
          type = "Kubernetes"
          kubernetes = {
            envoyService = {
              name        = var.envoy_gateway_service_name
              type        = "ClusterIP"
              annotations = local.envoy_gateway_external_dns_annotations
              labels = {
                "app.kubernetes.io/name"       = "envoy-gateway-public"
                "app.kubernetes.io/part-of"    = var.cluster_name
                "app.kubernetes.io/managed-by" = "terraform"
              }
            }
          }
        }
      }
    },
    {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "GatewayClass"
      metadata = {
        name = var.envoy_gateway_class_name
      }
      spec = {
        controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
        parametersRef = {
          group     = "gateway.envoyproxy.io"
          kind      = "EnvoyProxy"
          name      = var.envoy_gateway_proxy_name
          namespace = var.envoy_gateway_namespace
        }
      }
    },
    {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "Gateway"
      metadata = {
        name      = var.envoy_gateway_name
        namespace = var.envoy_gateway_namespace
        annotations = {
          "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
        }
      }
      spec = {
        gatewayClassName = var.envoy_gateway_class_name
        listeners = concat([
          merge(
            {
              name     = "http"
              protocol = "HTTP"
              port     = 80
              allowedRoutes = {
                namespaces = {
                  from = var.envoy_gateway_allowed_routes_from
                }
              }
            },
            var.envoy_gateway_listener_hostname != null ? { hostname = var.envoy_gateway_listener_hostname } : {}
          )
          ], var.enable_direct_envoy_nlb ? [{
            name     = "https-direct"
            protocol = "HTTPS"
            port     = 443
            hostname = var.direct_envoy_hostname
            tls = {
              mode = "Terminate"
              certificateRefs = [{
                kind = "Secret"
                name = var.direct_envoy_tls_secret_name
              }]
            }
            allowedRoutes = {
              namespaces = {
                from = var.envoy_gateway_allowed_routes_from
              }
            }
        }] : [])
      }
    }
  ]

  envoy_gateway_all_manifests = concat(local.envoy_gateway_manifests, local.direct_envoy_manifests)

  envoy_gateway_manifest_yaml = join("\n---\n", [
    for manifest in local.envoy_gateway_all_manifests : yamlencode(manifest)
  ])
}

check "direct_envoy_prerequisites" {
  assert {
    condition = !var.enable_direct_envoy_nlb || (
      var.enable_envoy_gateway &&
      var.enable_cert_manager &&
      var.direct_envoy_hostname != null
    )
    error_message = "enable_direct_envoy_nlb in add-ons requires enable_envoy_gateway, enable_cert_manager, and direct_envoy_hostname."
  }

  assert {
    condition = !var.direct_envoy_publish_dns || (
      var.enable_direct_envoy_nlb &&
      var.enable_external_dns &&
      var.direct_envoy_nlb_ip != null
    )
    error_message = "direct_envoy_publish_dns requires the direct Envoy add-on, ExternalDNS, and a non-null direct_envoy_nlb_ip."
  }
}

resource "kubernetes_namespace_v1" "envoy_gateway" {
  count = var.enable_envoy_gateway ? 1 : 0

  metadata {
    name = var.envoy_gateway_namespace
  }
}

resource "helm_release" "envoy_gateway" {
  count = var.enable_envoy_gateway ? 1 : 0

  name       = "envoy-gateway"
  repository = "oci://docker.io/envoyproxy"
  chart      = "gateway-helm"
  namespace  = kubernetes_namespace_v1.envoy_gateway[0].metadata[0].name
  version    = var.envoy_gateway_chart_version

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      deployment = {
        replicas = var.envoy_gateway_controller_replicas
      }
      service = {
        type = "ClusterIP"
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.envoy_gateway]
}

resource "null_resource" "envoy_gateway_bootstrap" {
  count = var.enable_envoy_gateway && var.kubeconfig_path != null ? 1 : 0

  triggers = {
    envoy_gateway_release_id = helm_release.envoy_gateway[0].id
    manifest                 = local.envoy_gateway_manifest_yaml
  }

  provisioner "local-exec" {
    command     = <<-EOT
      echo "Waiting for Envoy Gateway CRDs to be established..."
      for crd in \
        envoyproxies.gateway.envoyproxy.io \
        gatewayclasses.gateway.networking.k8s.io \
        gateways.gateway.networking.k8s.io \
        httproutes.gateway.networking.k8s.io; do
        for i in $(seq 1 24); do
          kubectl --kubeconfig '${var.kubeconfig_path}' \
            get crd "$crd" --ignore-not-found 2>/dev/null | grep -q "$crd" && break
          echo "  attempt $i/24: $crd not found yet, retrying in 5s..."
          sleep 5
        done
        kubectl --kubeconfig '${var.kubeconfig_path}' \
          wait --for=condition=established "crd/$crd" --timeout=60s
      done

      kubectl --kubeconfig '${var.kubeconfig_path}' apply -f - <<'MANIFESTS'
      ${local.envoy_gateway_manifest_yaml}
      MANIFESTS
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    helm_release.envoy_gateway,
    cloudflare_zero_trust_tunnel_cloudflared.this,
  ]
}

resource "kubernetes_manifest" "envoy_gateway_bootstrap" {
  count = var.enable_envoy_gateway && var.kubeconfig_path == null ? length(local.envoy_gateway_all_manifests) : 0

  manifest = local.envoy_gateway_all_manifests[count.index]

  depends_on = [
    helm_release.envoy_gateway,
    cloudflare_zero_trust_tunnel_cloudflared.this,
  ]
}
