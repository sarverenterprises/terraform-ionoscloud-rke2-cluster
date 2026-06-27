# =============================================================================
# CloudNativePG Operator
#
# Installs the CloudNativePG operator via the official Helm chart. This manages
# only the operator and CRDs; PostgreSQL Cluster resources remain app-owned so
# Flux can migrate workloads independently.
#
# Deployed only when var.enable_cloudnative_pg == true.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "cloudnative_pg" {
  count = var.enable_cloudnative_pg ? 1 : 0

  metadata {
    name = var.cloudnative_pg_namespace
  }
}

# ---------------------------------------------------------------------------
# Helm release: cloudnative-pg
# ---------------------------------------------------------------------------
resource "helm_release" "cloudnative_pg" {
  count = var.enable_cloudnative_pg ? 1 : 0

  name       = "cloudnative-pg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  namespace  = kubernetes_namespace_v1.cloudnative_pg[0].metadata[0].name
  version    = var.cloudnative_pg_chart_version

  wait    = true
  atomic  = true
  timeout = 300

  values = [
    yamlencode({
      replicaCount = var.cloudnative_pg_replica_count
    })
  ]

  depends_on = [kubernetes_namespace_v1.cloudnative_pg]
}
