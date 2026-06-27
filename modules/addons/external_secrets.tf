# =============================================================================
# External Secrets Operator + Bitwarden Provider
#
# Mirrors the k3s-lab stack shape: External Secrets Operator with controller,
# webhook, and cert-controller replicas, plus the small-hack Bitwarden webhook
# provider that creates ClusterSecretStores for Bitwarden login, fields, and
# notes lookups. Application ExternalSecret resources remain app-owned.
#
# Deployed only when var.enable_external_secrets == true. The Bitwarden provider
# is deployed only when var.enable_bitwarden_eso_provider == true.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "external_secrets" {
  count = var.enable_external_secrets || var.enable_bitwarden_eso_provider ? 1 : 0

  metadata {
    name = var.external_secrets_namespace
  }
}

# ---------------------------------------------------------------------------
# Helm release: External Secrets Operator
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name       = "external-secrets-external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets[0].metadata[0].name
  version    = var.external_secrets_chart_version

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      installCRDs  = true
      replicaCount = var.external_secrets_replica_count

      crds = {
        createClusterExternalSecret = true
        createClusterSecretStore    = true
        createClusterGenerator      = true
        createClusterPushSecret     = true
        createPushSecret            = true
      }

      leaderElect = false
      concurrent  = 1

      serviceAccount = {
        create    = true
        automount = true
      }

      rbac = {
        create          = true
        aggregateToView = true
        aggregateToEdit = true
      }

      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }

      webhook = {
        create       = true
        replicaCount = var.external_secrets_replica_count
        certManager = {
          enabled = false
        }
        podDisruptionBudget = {
          enabled      = true
          minAvailable = 1
        }
      }

      certController = {
        create       = true
        replicaCount = var.external_secrets_replica_count
        podDisruptionBudget = {
          enabled      = true
          minAvailable = 1
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.external_secrets]
}

# ---------------------------------------------------------------------------
# Secret: Bitwarden credentials for the provider pod
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "bitwarden_eso_provider" {
  count = var.enable_bitwarden_eso_provider ? 1 : 0

  metadata {
    name      = "external-secrets-bitwarden-eso-provider"
    namespace = kubernetes_namespace_v1.external_secrets[0].metadata[0].name
  }

  data = {
    BW_HOST         = var.bitwarden_host
    BW_PASSWORD     = var.bitwarden_password
    BW_CLIENTID     = var.bitwarden_client_id
    BW_CLIENTSECRET = var.bitwarden_client_secret
    BW_APPID        = var.bitwarden_app_id
  }

  lifecycle {
    precondition {
      condition = (
        try(trimspace(var.bitwarden_host), "") != "" &&
        try(trimspace(var.bitwarden_password), "") != "" &&
        try(trimspace(var.bitwarden_client_id), "") != "" &&
        try(trimspace(var.bitwarden_client_secret), "") != ""
      )
      error_message = "enable_bitwarden_eso_provider requires bitwarden_host, bitwarden_password, bitwarden_client_id, and bitwarden_client_secret."
    }
  }
}

# ---------------------------------------------------------------------------
# Helm release: Bitwarden ESO Provider
# ---------------------------------------------------------------------------
resource "helm_release" "bitwarden_eso_provider" {
  count = var.enable_bitwarden_eso_provider ? 1 : 0

  name       = "external-secrets-bitwarden-eso-provider"
  repository = "https://raw.githubusercontent.com/small-hack/bitwarden-eso-provider/gh-pages"
  chart      = "bitwarden-eso-provider"
  namespace  = kubernetes_namespace_v1.external_secrets[0].metadata[0].name
  version    = var.bitwarden_eso_provider_chart_version

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      replicaCount = var.bitwarden_eso_provider_replica_count

      bitwarden_eso_provider = {
        create_cluster_secret_store = true
        auth = {
          existingSecret = kubernetes_secret_v1.bitwarden_eso_provider[0].metadata[0].name
        }
      }

      service = {
        type = "ClusterIP"
        port = 8087
      }

      network_policy = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.external_secrets,
    kubernetes_secret_v1.bitwarden_eso_provider,
  ]
}
