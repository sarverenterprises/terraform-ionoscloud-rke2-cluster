# =============================================================================
# Tailscale Kubernetes Operator
#
# Installs the Tailscale Kubernetes Operator via the official Helm chart.
# The operator enables Tailscale-based ingress/egress for Services and exposes
# Kubernetes services onto the tailnet without a traditional ingress controller.
#
# Authentication uses a Tailscale OAuth client ID and secret. The operator
# hostname on the tailnet is set to "<cluster_name>-operator" to avoid naming
# collisions when multiple clusters share the same tailnet.
#
# Deployed only when var.enable_tailscale_operator == true.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "tailscale" {
  count = var.enable_tailscale_operator ? 1 : 0

  metadata {
    name = "tailscale"
  }
}

# ---------------------------------------------------------------------------
# Helm release: tailscale-operator
# ---------------------------------------------------------------------------
resource "helm_release" "tailscale_operator" {
  count = var.enable_tailscale_operator ? 1 : 0

  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  namespace  = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  version    = "~> 1.76"

  wait    = true
  atomic  = true
  timeout = 300

  lifecycle {
    precondition {
      condition = (
        var.tailscale_operator_oauth_client_id != null &&
        var.tailscale_operator_oauth_client_id != "" &&
        var.tailscale_operator_oauth_client_secret != null &&
        var.tailscale_operator_oauth_client_secret != ""
      )
      error_message = "enable_tailscale_operator requires tailscale_operator_oauth_client_id and tailscale_operator_oauth_client_secret."
    }
  }

  values = [
    yamlencode({
      oauth = {
        clientId     = var.tailscale_operator_oauth_client_id
        clientSecret = var.tailscale_operator_oauth_client_secret
      }
      operatorConfig = {
        # Unique hostname on the tailnet — avoids collisions when multiple
        # clusters share the same tailnet account.
        hostname = "${var.cluster_name}-operator"
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.tailscale]
}
