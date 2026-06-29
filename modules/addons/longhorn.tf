# =============================================================================
# Longhorn Distributed Storage
#
# Deploys Longhorn as the cluster's primary distributed block storage layer.
# Data is stored in a node-local folder by default (/var/lib/longhorn), or on
# optional dedicated IONOS volumes when longhorn_default_data_path points at
# that mount path (for example /mnt/longhorn).
#
# Two StorageClasses are created:
#   - longhorn-rwo  ReadWriteOnce  (default)
#   - longhorn-rwx  ReadWriteMany  (only when longhorn_rwx_mode == "builtin")
#
# Deployed only when var.enable_longhorn == true.
# =============================================================================

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "longhorn_system" {
  count = var.enable_longhorn ? 1 : 0

  metadata {
    name = "longhorn-system"
  }
}

# ---------------------------------------------------------------------------
# Helm release: longhorn
#
# timeout = 600 — Longhorn installs many DaemonSets and CRDs; it is
# significantly slower than most charts.
# ---------------------------------------------------------------------------
resource "helm_release" "longhorn" {
  count = var.enable_longhorn ? 1 : 0

  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  namespace  = "longhorn-system"
  version    = var.longhorn_chart_version

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      defaultSettings = {
        defaultReplicaCount = var.longhorn_default_replicas
        defaultDataPath     = var.longhorn_default_data_path
      }
      persistence = {
        defaultClassReplicaCount = var.longhorn_default_replicas
        # The module creates longhorn-rwo as the default class below.
        defaultClass = false
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.longhorn_system]
}

# ---------------------------------------------------------------------------
# StorageClass: longhorn-rwo (ReadWriteOnce, default)
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "longhorn_sc_rwo" {
  count = var.enable_longhorn ? 1 : 0

  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "longhorn-rwo"
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
    }
    provisioner          = "driver.longhorn.io"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
    volumeBindingMode    = "WaitForFirstConsumer"
    parameters = {
      numberOfReplicas = tostring(var.longhorn_default_replicas)
      dataLocality     = "best-effort"
      fsType           = "ext4"
    }
  }

  depends_on = [helm_release.longhorn]
}

# ---------------------------------------------------------------------------
# StorageClass: longhorn-rwx (ReadWriteMany, builtin NFS backend)
#
# Only created when longhorn_rwx_mode == "builtin". When set to "external",
# a separate NFS provisioner (e.g. nfs-subdir-external-provisioner) is
# expected to handle RWX volumes.
# ---------------------------------------------------------------------------
resource "kubernetes_manifest" "longhorn_sc_rwx" {
  count = (var.enable_longhorn && var.longhorn_rwx_mode == "builtin") ? 1 : 0

  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "longhorn-rwx"
    }
    provisioner          = "driver.longhorn.io"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
    volumeBindingMode    = "WaitForFirstConsumer"
    parameters = {
      numberOfReplicas = tostring(var.longhorn_default_replicas)
      dataLocality     = "disabled"
      accessMode       = "ReadWriteMany"
      nfsOptions       = var.longhorn_rwx_nfs_options
    }
  }

  depends_on = [helm_release.longhorn]
}
