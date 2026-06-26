# =============================================================================
# cert-manager + Cloudflare ClusterIssuer
#
# Installs cert-manager via Helm (with CRDs) and provisions a
# letsencrypt-prod ClusterIssuer that uses Cloudflare DNS-01 challenges.
# A dedicated Secret carries the Cloudflare API token for cert-manager so
# it is separate from the external-dns token (different Secret names allow
# independent rotation).
#
# Deployed only when var.enable_cert_manager == true.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  metadata {
    name = "cert-manager"
  }
}

# ---------------------------------------------------------------------------
# Secret: Cloudflare API token for cert-manager DNS-01 solver
# Must exist before the ClusterIssuer is applied so cert-manager can read it
# when processing the first certificate request.
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "cloudflare_api_token_cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  metadata {
    name      = "cloudflare-api-token-certmanager"
    namespace = kubernetes_namespace_v1.cert_manager[0].metadata[0].name
  }

  data = {
    api-token = var.cloudflare_api_token
  }
}

# ---------------------------------------------------------------------------
# Helm release: cert-manager
# installCRDs=true is the recommended approach for Helm-managed cert-manager
# deployments; it keeps CRDs in sync with the chart version automatically.
# ---------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert_manager[0].metadata[0].name
  version    = var.cert_manager_chart_version

  wait    = true
  atomic  = true
  timeout = 300

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  lifecycle {
    precondition {
      condition     = trimspace(var.cert_manager_acme_email) != ""
      error_message = "enable_cert_manager requires cert_manager_acme_email to be set."
    }
  }

  depends_on = [kubernetes_namespace_v1.cert_manager]
}

# ---------------------------------------------------------------------------
# ClusterIssuer: letsencrypt-prod
# Uses Cloudflare DNS-01 so certificates can be issued for non-HTTP
# workloads and wildcard domains.
#
# NOTE: kubernetes_manifest requires the cert-manager CRDs to be present.
# When kubeconfig_path is set, kubectl applies the issuer at apply time after
# the Helm release installs the CRDs. The kubernetes_manifest fallback is for
# steady-state use when the CRDs already exist before planning.
# ---------------------------------------------------------------------------
resource "null_resource" "letsencrypt_prod_cluster_issuer" {
  count = var.enable_cert_manager && var.kubeconfig_path != null ? 1 : 0

  triggers = {
    cert_manager_release_id = helm_release.cert_manager[0].id
    acme_email              = var.cert_manager_acme_email
    secret_name             = kubernetes_secret_v1.cloudflare_api_token_cert_manager[0].metadata[0].name
  }

  provisioner "local-exec" {
    command     = <<-EOT
      echo "Waiting for CRD clusterissuers.cert-manager.io to appear..."
      for i in $(seq 1 24); do
        kubectl --kubeconfig '${var.kubeconfig_path}' \
          get crd clusterissuers.cert-manager.io \
          --ignore-not-found 2>/dev/null | grep -q clusterissuers \
          && break
        echo "  attempt $i/24: CRD not found yet, retrying in 5s..."
        sleep 5
      done
      kubectl --kubeconfig '${var.kubeconfig_path}' \
        wait --for=condition=established \
        crd/clusterissuers.cert-manager.io \
        --timeout=60s
      kubectl --kubeconfig '${var.kubeconfig_path}' apply -f - <<'ISSUER'
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: letsencrypt-prod
      spec:
        acme:
          server: https://acme-v02.api.letsencrypt.org/directory
          email: ${var.cert_manager_acme_email}
          privateKeySecretRef:
            name: letsencrypt-prod
          solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: ${kubernetes_secret_v1.cloudflare_api_token_cert_manager[0].metadata[0].name}
                  key: api-token
      ISSUER
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret_v1.cloudflare_api_token_cert_manager,
  ]
}

resource "kubernetes_manifest" "letsencrypt_prod_cluster_issuer" {
  count = var.enable_cert_manager && var.kubeconfig_path == null ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.cert_manager_acme_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret_v1.cloudflare_api_token_cert_manager[0].metadata[0].name
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  # cert-manager CRDs must be present (installed by the Helm release) before
  # the Kubernetes API will accept a ClusterIssuer resource.
  depends_on = [helm_release.cert_manager]
}
