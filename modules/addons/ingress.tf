# =============================================================================
# Ingress Controller — Traefik
#
# Traefik v3 proxy + Gateway API CRDs are deployed only when
# var.enable_ingress == true. The former ingress-nginx path was removed because
# these clusters use Cloudflare tunnels for ingress instead of nginx.
# =============================================================================

locals {
  deploy_traefik = var.enable_ingress
}

# =============================================================================
# Traefik path
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace: traefik
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "traefik" {
  count = local.deploy_traefik ? 1 : 0

  metadata {
    name = "traefik"
  }
}

# ---------------------------------------------------------------------------
# Helm release: traefik
# No provider load balancer annotations are set in the IONOS fork. Prefer
# Cloudflare Tunnel for ingress; Traefik remains available for internal routing.
# isDefaultClass=true makes Traefik the cluster-wide default IngressClass.
# ---------------------------------------------------------------------------
resource "helm_release" "traefik" {
  count = local.deploy_traefik ? 1 : 0

  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  namespace  = kubernetes_namespace_v1.traefik[0].metadata[0].name
  version    = var.traefik_chart_version

  wait    = true
  atomic  = true
  timeout = 300

  values = [
    yamlencode({
      ingressClass = {
        enabled        = true
        isDefaultClass = true
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.traefik]
}

# ---------------------------------------------------------------------------
# Gateway API CRDs
# Installed via kubectl so the CRD set matches the upstream release exactly.
# The caller must have KUBECONFIG set in the environment (or use the
# KUBE_CONFIG_PATH env var) before running terraform apply.
#
# The trigger on helm_release.traefik[0].id ensures this runs (or re-runs)
# whenever the Traefik release is replaced, keeping CRD lifecycle coupled to
# the controller that implements them.
# ---------------------------------------------------------------------------
resource "null_resource" "gateway_api_crds" {
  count = local.deploy_traefik ? 1 : 0

  triggers = {
    # Re-apply when the Traefik release changes (e.g. version bump).
    traefik_release_id = helm_release.traefik[0].id
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig '${var.kubeconfig_path}' apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
  }

  depends_on = [helm_release.traefik]
}
