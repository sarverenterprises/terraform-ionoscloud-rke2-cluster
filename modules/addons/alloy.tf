# =============================================================================
# Grafana Alloy
#
# Installs a cluster-level Alloy collector in the monitoring namespace. The
# collector exposes OTLP/gRPC on 4317 and OTLP/HTTP on 4318 for app telemetry
# and forwards Kubernetes logs plus OTLP data to the central LGTM endpoints.
#
# Deployed only when var.enable_alloy == true.
# =============================================================================

locals {
  alloy_lgtm_secret_name = "alloy-lgtm-credentials"

  alloy_config = <<-EOT
    discovery.kubernetes "pods" {
      role = "pod"

      selectors {
        role  = "pod"
        field = "spec.nodeName=" + coalesce(sys.env("K8S_NODE_NAME"), sys.env("HOSTNAME"), constants.hostname)
      }
    }

    discovery.relabel "pod_logs" {
      targets = discovery.kubernetes.pods.targets

      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        action        = "replace"
        target_label  = "namespace"
      }

      rule {
        source_labels = ["__meta_kubernetes_pod_name"]
        action        = "replace"
        target_label  = "pod"
      }

      rule {
        source_labels = ["__meta_kubernetes_pod_container_name"]
        action        = "replace"
        target_label  = "container"
      }

      rule {
        source_labels = ["__meta_kubernetes_pod_node_name"]
        action        = "replace"
        target_label  = "node_name"
      }

      rule {
        source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
        action        = "replace"
        target_label  = "app"
      }

      rule {
        source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_container_name"]
        action        = "replace"
        target_label  = "job"
        separator     = "/"
        replacement   = "$1"
      }

      rule {
        source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
        action        = "replace"
        target_label  = "__path__"
        separator     = "/"
        replacement   = "/var/log/pods/*$1/*.log"
      }
    }

    loki.source.kubernetes "pod_logs" {
      targets    = discovery.relabel.pod_logs.output
      forward_to = [loki.process.pod_logs.receiver]
    }

    loki.process "pod_logs" {
      stage.static_labels {
        values = {
          cluster = "${var.cluster_name}",
        }
      }

      stage.drop {
        older_than = "24h"
      }

      stage.cri {}

      stage.multiline {
        firstline     = "^\\d{4}-\\d{2}-\\d{2}"
        max_wait_time = "3s"
      }

      forward_to = [loki.write.lgtm.receiver]
    }

    loki.write "lgtm" {
      endpoint {
        url = "${var.alloy_loki_endpoint}"

        basic_auth {
          username = sys.env("ALLOY_LGTM_USERNAME")
          password = sys.env("ALLOY_LGTM_PASSWORD")
        }

        tenant_id = "${var.alloy_lgtm_tenant_id}"
      }
    }

    otelcol.receiver.otlp "default" {
      grpc {
        endpoint = "0.0.0.0:4317"
      }

      http {
        endpoint = "0.0.0.0:4318"
      }

      output {
        metrics = [otelcol.processor.batch.default.input]
        logs    = [otelcol.processor.batch.default.input]
        traces  = [otelcol.processor.batch.default.input]
      }
    }

    otelcol.processor.batch "default" {
      timeout             = "10s"
      send_batch_size     = 1024
      send_batch_max_size = 2048

      output {
        metrics = [otelcol.exporter.otlphttp.mimir.input]
        logs    = [otelcol.exporter.otlphttp.loki.input]
        traces  = [otelcol.exporter.otlphttp.tempo.input]
      }
    }

    otelcol.exporter.otlphttp "tempo" {
      client {
        endpoint = "${var.alloy_tempo_endpoint}"
        auth     = otelcol.auth.basic.lgtm.handler
      }
    }

    otelcol.exporter.otlphttp "loki" {
      client {
        endpoint = "${var.alloy_loki_otlp_endpoint}"
        auth     = otelcol.auth.basic.lgtm.handler
      }
    }

    otelcol.exporter.otlphttp "mimir" {
      client {
        endpoint = "${var.alloy_mimir_endpoint}"
        auth     = otelcol.auth.basic.lgtm.handler
      }
    }

    otelcol.auth.basic "lgtm" {
      username = sys.env("ALLOY_LGTM_USERNAME")
      password = sys.env("ALLOY_LGTM_PASSWORD")
    }
  EOT
}

resource "kubernetes_secret_v1" "alloy_lgtm_credentials" {
  count = var.enable_alloy ? 1 : 0

  metadata {
    name      = local.alloy_lgtm_secret_name
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  }

  data = {
    ALLOY_LGTM_USERNAME = var.alloy_lgtm_username
    ALLOY_LGTM_PASSWORD = var.alloy_lgtm_password
  }

  type = "Opaque"

  lifecycle {
    precondition {
      condition     = !(var.enable_alloy && (!var.enable_monitoring || var.alloy_lgtm_username == null || var.alloy_lgtm_password == null))
      error_message = "enable_alloy requires enable_monitoring=true, alloy_lgtm_username, and alloy_lgtm_password."
    }
  }

  depends_on = [kubernetes_namespace_v1.monitoring]
}

resource "helm_release" "alloy" {
  count = var.enable_alloy ? 1 : 0

  name       = "k8s-monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  version    = var.alloy_chart_version

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      fullnameOverride = "k8s-monitoring-alloy"

      alloy = {
        configMap = {
          content = local.alloy_config
        }
        envFrom = [
          {
            secretRef = {
              name = kubernetes_secret_v1.alloy_lgtm_credentials[0].metadata[0].name
            }
          }
        ]
        mounts = {
          # Pod log collection uses loki.source.kubernetes, which tails through
          # the Kubernetes API and does not require host /var/log access.
          varlog = false
        }
        securityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          runAsGroup               = 473
          runAsNonRoot             = true
          runAsUser                = 473
          capabilities = {
            drop = ["ALL"]
          }
        }
        extraPorts = [
          {
            name       = "otlp-grpc"
            port       = 4317
            targetPort = 4317
            protocol   = "TCP"
          },
          {
            name       = "otlp-http"
            port       = 4318
            targetPort = 4318
            protocol   = "TCP"
          }
        ]
      }

      controller = {
        type = "daemonset"
      }

      global = {
        podSecurityContext = {
          fsGroup      = 473
          runAsGroup   = 473
          runAsNonRoot = true
          runAsUser    = 473
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }

      service = {
        enabled = true
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    kubernetes_secret_v1.alloy_lgtm_credentials,
  ]
}
