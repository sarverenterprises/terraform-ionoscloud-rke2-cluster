# =============================================================================
# Cluster Identity
# =============================================================================

variable "cluster_name" {
  description = "Cluster name — used to namespace Helm releases and Kubernetes resources."
  type        = string
}

variable "location" {
  description = "Default IONOS location for provider-neutral add-ons that need a location hint."
  type        = string
  default     = "us/ewr"
}

variable "kubeconfig_path" {
  description = <<-EOT
    Absolute path to the kubeconfig file on disk.
    Required for resources that cannot validate CRD types at plan time
    (e.g. CiliumClusterwideNetworkPolicy). When set, such resources are applied
    via kubectl local-exec instead of kubernetes_manifest. When null, the
    kubernetes_manifest provider is used — this requires the CRDs to already
    exist in the cluster at plan time (safe for subsequent applies after
    Cilium is installed).
  EOT
  type        = string
  default     = null
}

variable "enable_cilium" {
  description = "Install and manage Cilium from this add-ons state. Disable when the base cluster state already owns the cilium Helm release."
  type        = bool
  default     = true
}

# =============================================================================
# Network
# =============================================================================

variable "private_network_name" {
  description = "Name of the private IONOS LAN."
  type        = string
}

variable "pod_cidr" {
  description = "CIDR for Kubernetes pods. Used in Cilium IPAM and CCM clusterCIDR."
  type        = string
  default     = "10.42.0.0/16"
}

variable "private_network_id" {
  description = "ID of the private IONOS LAN."
  type        = string
}

variable "control_plane_lb_ip" {
  description = "Private IP of the control-plane endpoint."
  type        = string
}

variable "cluster_subnet_cidr" {
  description = "Cluster subnet CIDR. Used in autoscaler cloud-init."
  type        = string
}

# =============================================================================
# RKE2 / OS
# =============================================================================

variable "rke2_version" {
  description = "RKE2 version to install on autoscaled nodes."
  type        = string
}

variable "rke2_cluster_token" {
  description = "RKE2 cluster join token. Injected into autoscaler node cloud-inits."
  type        = string
  sensitive   = true
}

variable "os_image" {
  description = "IONOS OS image for future autoscaled nodes."
  type        = string
}

# =============================================================================
# Worker Pools (reserved for future IONOS autoscaler support)
# =============================================================================

variable "autoscaler_pool_cloud_inits" {
  description = "Pre-rendered cloud-init strings for autoscaled pools, keyed by full pool name (e.g. 'mycluster-workers'). Rendered in the root module to avoid cross-module template path violations when sourced from a Git remote."
  type        = map(string)
  default     = {}
}

variable "node_pools" {
  description = "Worker node pool definitions."
  type = list(object({
    name        = string
    server_type = string
    node_count  = optional(number, 1)
    location    = optional(string)

    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])

    scaling_mode = optional(string, "fixed")
    min_nodes    = optional(number, 1)
    max_nodes    = optional(number, 10)

    assign_public_ip     = optional(bool, false)
    longhorn_volume_size = optional(number, 0)
  }))
  default = []
}

# =============================================================================
# Longhorn
# =============================================================================

variable "longhorn_default_replicas" {
  description = "Default Longhorn replica count. Computed from min(total_workers, 3)."
  type        = number
  default     = 3
}

variable "longhorn_default_data_path" {
  description = "Longhorn default data path for node-local storage. Use /var/lib/longhorn for OS-disk folder-backed storage; use /mnt/longhorn only when dedicated data volumes are mounted there."
  type        = string
  default     = "/var/lib/longhorn"
}

variable "longhorn_rwx_mode" {
  description = "Longhorn RWX backend: 'builtin' or 'external'."
  type        = string
  default     = "builtin"
}

# =============================================================================
# Tailscale
# =============================================================================

variable "enable_tailscale_nodes" {
  description = "Whether Tailscale is installed on nodes. Used to inject auth key into autoscaler cloud-inits."
  type        = bool
  default     = false
}

variable "tailscale_node_auth_key" {
  description = "Tailscale auth key for node-level enrollment."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_operator_auth_key" {
  description = "Deprecated compatibility input. Use tailscale_operator_oauth_client_id and tailscale_operator_oauth_client_secret."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_operator_oauth_client_id" {
  description = "Tailscale OAuth client ID for the Kubernetes operator."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_operator_oauth_client_secret" {
  description = "Tailscale OAuth client secret for the Kubernetes operator."
  type        = string
  sensitive   = true
  default     = null
}

# =============================================================================
# Add-on Feature Flags
# =============================================================================

variable "enable_external_dns" {
  description = "Deploy External-DNS."
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Deploy cert-manager."
  type        = bool
  default     = false
}

variable "cert_manager_acme_email" {
  description = "ACME account email address for the cert-manager letsencrypt-prod ClusterIssuer."
  type        = string
  default     = ""
}

variable "enable_ingress" {
  description = "Deploy Traefik ingress controller."
  type        = bool
  default     = false
}

variable "enable_envoy_gateway" {
  description = "Deploy Envoy Gateway and a default Gateway API Gateway for Cloudflare Tunnel ingress."
  type        = bool
  default     = false
}

variable "enable_longhorn" {
  description = "Deploy Longhorn."
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Deploy Cluster Autoscaler."
  type        = bool
  default     = false
}

variable "autoscaler_rbac_level" {
  description = "RBAC scope for the autoscaler: 'upstream' or 'minimal'."
  type        = string
  default     = "upstream"
}

variable "enable_flux" {
  description = "Bootstrap Flux CD."
  type        = bool
  default     = false
}

variable "flux_deploy_key_mode" {
  description = "Flux deploy key mode: 'auto' or 'manual'."
  type        = string
  default     = "auto"
}

variable "enable_monitoring" {
  description = "Deploy kube-prometheus-stack."
  type        = bool
  default     = false
}

variable "enable_cloudnative_pg" {
  description = "Deploy the CloudNativePG operator and CRDs. PostgreSQL Cluster resources remain app-owned."
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Deploy External Secrets Operator and CRDs."
  type        = bool
  default     = false
}

variable "enable_bitwarden_eso_provider" {
  description = "Deploy the Bitwarden webhook provider for External Secrets Operator."
  type        = bool
  default     = false
}

variable "enable_tailscale_operator" {
  description = "Deploy Tailscale Kubernetes operator."
  type        = bool
  default     = false
}

variable "enable_cloudflare_tunnel" {
  description = "Deploy a Cloudflare Tunnel and in-cluster cloudflared connectors."
  type        = bool
  default     = false
}

variable "enable_system_upgrade_controller" {
  description = "Deploy Rancher System Upgrade Controller."
  type        = bool
  default     = false
}

# =============================================================================
# Cloudflare
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token. Required when enable_external_dns or enable_cert_manager."
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID."
  type        = string
  default     = null
}

variable "cloudflare_zone" {
  description = "Cloudflare zone domain (e.g., 'example.com')."
  type        = string
  default     = null
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID. Required when enable_cloudflare_tunnel = true."
  type        = string
  default     = null
}

variable "cloudflare_tunnel_name" {
  description = "Cloudflare Tunnel name. Defaults to '<cluster_name>-ingress'."
  type        = string
  default     = null
}

variable "cloudflare_tunnel_replicas" {
  description = "Number of cloudflared connector replicas to run in-cluster."
  type        = number
  default     = 2
}

variable "cloudflared_image" {
  description = "cloudflared container image to run for Cloudflare Tunnel connectors."
  type        = string
  default     = "cloudflare/cloudflared:2026.6.1"
}

variable "cloudflare_tunnel_ingress" {
  description = "Cloudflare Tunnel ingress rules. A http_status:404 catch-all is always appended."
  type = list(object({
    hostname = optional(string)
    path     = optional(string)
    service  = string
  }))
  default = []
}

# =============================================================================
# Envoy Gateway
# =============================================================================

variable "envoy_gateway_namespace" {
  description = "Namespace for Envoy Gateway controller and default Gateway resources."
  type        = string
  default     = "envoy-gateway-system"
}

variable "envoy_gateway_proxy_name" {
  description = "EnvoyProxy resource name used by the Terraform-managed GatewayClass."
  type        = string
  default     = "public"
}

variable "envoy_gateway_class_name" {
  description = "GatewayClass name for the Terraform-managed Envoy Gateway."
  type        = string
  default     = "envoy"
}

variable "envoy_gateway_name" {
  description = "Default Gateway resource name."
  type        = string
  default     = "public"
}

variable "envoy_gateway_service_name" {
  description = "Stable Envoy data-plane Service name used by Cloudflare Tunnel."
  type        = string
  default     = "envoy-gateway-public"
}

variable "envoy_gateway_hostnames" {
  description = "Hostnames routed by Cloudflare Tunnel to Envoy Gateway and advertised by ExternalDNS."
  type        = list(string)
  default     = []
}

variable "envoy_gateway_listener_hostname" {
  description = "Optional hostname constraint for the default HTTP listener. Null accepts HTTPRoutes for any hostname."
  type        = string
  default     = null
}

variable "envoy_gateway_allowed_routes_from" {
  description = "Gateway API allowedRoutes namespace policy for the default listener. Valid values are Same, All, or Selector."
  type        = string
  default     = "All"

  validation {
    condition     = contains(["Same", "All", "Selector"], var.envoy_gateway_allowed_routes_from)
    error_message = "envoy_gateway_allowed_routes_from must be Same, All, or Selector."
  }
}

variable "envoy_gateway_controller_replicas" {
  description = "Number of Envoy Gateway controller replicas."
  type        = number
  default     = 2
}

# =============================================================================
# CloudNativePG
# =============================================================================

variable "cloudnative_pg_namespace" {
  description = "Namespace for the CloudNativePG operator."
  type        = string
  default     = "cnpg-system"
}

variable "cloudnative_pg_replica_count" {
  description = "CloudNativePG operator replica count."
  type        = number
  default     = 1
}

variable "external_secrets_namespace" {
  description = "Namespace for External Secrets Operator and the Bitwarden provider."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_replica_count" {
  description = "Replica count for External Secrets Operator controller, webhook, and cert-controller."
  type        = number
  default     = 2
}

variable "bitwarden_eso_provider_replica_count" {
  description = "Replica count for the Bitwarden ESO provider."
  type        = number
  default     = 1
}

variable "bitwarden_host" {
  description = "Bitwarden vault host used by the Bitwarden ESO provider."
  type        = string
  default     = "https://vault.bitwarden.com"
}

variable "bitwarden_password" {
  description = "Bitwarden account password used by the Bitwarden ESO provider."
  type        = string
  sensitive   = true
  default     = null
}

variable "bitwarden_client_id" {
  description = "Bitwarden API client ID used by the Bitwarden ESO provider."
  type        = string
  sensitive   = true
  default     = null
}

variable "bitwarden_client_secret" {
  description = "Bitwarden API client secret used by the Bitwarden ESO provider."
  type        = string
  sensitive   = true
  default     = null
}

variable "bitwarden_app_id" {
  description = "Optional Bitwarden app ID used to identify the provider pod login client."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# GitHub / Flux
# =============================================================================

variable "github_token" {
  description = "GitHub PAT. Required when enable_flux=true."
  type        = string
  sensitive   = true
  default     = null
}

variable "flux_github_org" {
  description = "GitHub org or user for Flux repository."
  type        = string
  default     = null
}

variable "flux_github_repo" {
  description = "GitHub repository name for Flux."
  type        = string
  default     = null
}

variable "flux_branch" {
  description = "Git branch for Flux to track."
  type        = string
  default     = "main"
}

variable "flux_path" {
  description = "Path in the Flux repository for cluster manifests."
  type        = string
  default     = "clusters/main"
}

# =============================================================================
# Monitoring
# =============================================================================

variable "grafana_hostname" {
  description = "Hostname for Grafana ingress."
  type        = string
  default     = null
}

# =============================================================================
# Argo CD
# =============================================================================

variable "enable_argocd" {
  description = "Deploy Argo CD and Argo Rollouts."
  type        = bool
  default     = false
}

variable "argocd_hostname" {
  description = "Hostname for Argo CD ingress. When null, no Ingress is created — access via kubectl port-forward."
  type        = string
  default     = null
}

variable "argocd_github_client_id" {
  description = "GitHub OAuth App client ID for Dex SSO. Required together with argocd_github_client_secret to enable GitHub login."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_github_client_secret" {
  description = "GitHub OAuth App client secret for Dex SSO."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_dex_connectors" {
  description = "Raw Dex connectors YAML string. When set, overrides the auto-wired GitHub connector entirely. Use this for non-GitHub providers (Google, LDAP, OIDC, etc.)."
  type        = string
  default     = null
}

# =============================================================================
# Chart Versions
# =============================================================================

variable "cilium_chart_version" {
  description = "Cilium Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.19.1"
}

variable "cilium_dns_proxy_enable_transparent_mode" {
  description = "Whether Cilium DNS proxy transparent mode is enabled. Pin this instead of inheriting chart-version defaults."
  type        = bool
  default     = false
}

variable "cilium_external_envoy_proxy" {
  description = "Whether Cilium runs Envoy as a standalone DaemonSet for L7 policy. False keeps the embedded Envoy behavior used by rke2-primary."
  type        = bool
  default     = false
}

variable "longhorn_chart_version" {
  description = "Longhorn Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.7.3"
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "v1.16.5"
}

variable "external_dns_chart_version" {
  description = "External-DNS Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.14.5"
}

variable "envoy_gateway_chart_version" {
  description = "Envoy Gateway Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "v1.8.1"
}

variable "cloudnative_pg_chart_version" {
  description = "CloudNativePG Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "0.28.3"
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "2.5.0"
}

variable "bitwarden_eso_provider_chart_version" {
  description = "Bitwarden ESO provider Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.2.0"
}

variable "traefik_chart_version" {
  description = "Traefik Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "32.1.1"
}

variable "flux_version" {
  description = "Flux CD version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "2.4.1"
}

variable "cluster_autoscaler_chart_version" {
  description = "Cluster Autoscaler Helm chart version."
  type        = string
  default     = "9.46.6"
}

variable "cluster_autoscaler_image_tag" {
  description = "Cluster Autoscaler container image tag."
  type        = string
  default     = "v1.33.0"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "9.4.18"
}

variable "argo_rollouts_chart_version" {
  description = "Argo Rollouts Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "2.40.10"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "67.11.0"
}

variable "system_upgrade_controller_chart_version" {
  description = "System Upgrade Controller Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "0.14.2"
}

variable "tailscale_operator_chart_version" {
  description = "Tailscale Kubernetes Operator Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.76.6"
}
