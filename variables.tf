# =============================================================================
# Cluster Identity
# =============================================================================

variable "cluster_name" {
  description = "Unique name for the cluster. Used as a prefix for all IONOS resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be lowercase alphanumeric with hyphens, 3-32 chars, starting with a letter."
  }
}

variable "location" {
  description = "Default IONOS Cloud Virtual Data Center location. Used for control plane and any worker pool that does not override location."
  type        = string
  default     = "us/ewr"

  validation {
    condition     = contains(["de/fra", "de/fra/2", "de/txl", "us/las", "us/ewr", "us/mci", "gb/lhr", "gb/bhx", "es/vit", "fr/par"], var.location)
    error_message = "location must be a supported IONOS Cloud location, for example us/ewr, us/las, us/mci, de/fra, or gb/lhr."
  }
}

# =============================================================================
# IONOS Cloud API Token
# =============================================================================

variable "ionos_token" {
  description = "Optional IONOS Cloud API token. If null, use the IONOS_TOKEN environment variable in the root provider configuration."
  type        = string
  sensitive   = true
  default     = null
}

# =============================================================================
# OS & RKE2 Configuration
# =============================================================================

variable "os_image" {
  description = "IONOS image name or alias for all nodes. Must be a cloud-init capable Ubuntu image."
  type        = string
  default     = "ubuntu:latest"
}

variable "rke2_version" {
  description = "RKE2 release version to install on all nodes."
  type        = string
  default     = "v1.33.12+rke2r2"
}

variable "disabled_packaged_components" {
  description = "RKE2 packaged AddOns to disable on server nodes, for example rke2-ingress-nginx."
  type        = list(string)
  default     = []
}

variable "ssh_keys" {
  description = "List of SSH public key file paths or direct public key strings for IONOS Linux image injection."
  type        = list(string)
}

variable "ssh_private_key" {
  description = "Contents of the SSH private key used to provision nodes. Required to fetch the kubeconfig after cluster creation."
  type        = string
  sensitive   = true
}

# =============================================================================
# Control Plane
# =============================================================================

variable "control_plane_server_type" {
  description = "IONOS Cube template name for control plane nodes."
  type        = string
  default     = "Basic Cube L"
}

variable "control_plane_node_count" {
  description = "Number of control plane nodes. Use 1 for a temporary PoC or 3 for HA embedded etcd."
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3], var.control_plane_node_count)
    error_message = "control_plane_node_count must be 1 for a PoC or 3 for HA embedded etcd."
  }
}

variable "control_plane_location" {
  description = "IONOS location for control plane nodes. Defaults to var.location if null."
  type        = string
  default     = null
}

variable "control_plane_management_endpoint_ip" {
  description = "Optional Terraform management endpoint for CP-0. Use a direct Tailscale IP when CI cannot route the IONOS private LAN."
  type        = string
  default     = null
}

variable "control_plane_management_ips" {
  description = "Optional Terraform SSH endpoints for CP nodes in index order. Use direct Tailscale IPs when CI cannot route the IONOS private LAN."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.control_plane_management_ips) == 0 || length(var.control_plane_management_ips) == var.control_plane_node_count
    error_message = "control_plane_management_ips must be empty or match control_plane_node_count."
  }
}

variable "node_bootstrap_revision" {
  description = "Operator-controlled bootstrap revision. Change this value to intentionally replace nodes and rerun cloud-init after bootstrap logic changes."
  type        = string
  default     = "1"
}

variable "node_dns_servers" {
  description = "Optional DNS resolvers written into node bootstrap. When empty, the OS image/provider resolver configuration is left unchanged."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for server in var.node_dns_servers : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", server))])
    error_message = "node_dns_servers must contain IPv4 resolver addresses."
  }
}

variable "node_dns_search_domains" {
  description = "Optional DNS search domains written into node /etc/resolv.conf. Empty keeps the static resolver file free of search domains."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for domain in var.node_dns_search_domains : can(regex("^[A-Za-z0-9_.-]+$", domain))])
    error_message = "node_dns_search_domains must contain only DNS search-domain characters."
  }
}

variable "coredns_upstream_servers" {
  description = "Optional public IPv4 DNS resolvers for RKE2 CoreDNS upstream forwarding. When empty, RKE2's default /etc/resolv.conf forwarding is left unchanged."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for server in var.coredns_upstream_servers : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", server))])
    error_message = "coredns_upstream_servers must contain IPv4 resolver addresses."
  }
}

# =============================================================================
# Networking
# =============================================================================

variable "network_cidr" {
  description = "CIDR used to derive compatibility gateway defaults. IONOS LAN CIDR is provider-computed; cluster_subnet_cidr controls node addressing."
  type        = string
  default     = "10.0.0.0/8"
}

variable "cluster_subnet_cidr" {
  description = "CIDR used for deterministic private node IPs on the IONOS private LAN."
  type        = string
  default     = "10.11.0.0/16"

  validation {
    condition     = tonumber(split("/", var.cluster_subnet_cidr)[1]) >= 16
    error_message = "cluster_subnet_cidr must be /16 or smaller to limit etcd firewall rule blast radius."
  }
}

variable "existing_network_id" {
  description = "Deprecated compatibility input. Use existing_private_lan_id instead."
  type        = string
  default     = null
}

variable "existing_datacenter_id" {
  description = "ID of an existing IONOS Virtual Data Center. When null, this module creates one."
  type        = string
  default     = null
}

variable "existing_public_lan_id" {
  description = "ID of an existing public IONOS LAN in the selected datacenter. When null, this module creates one."
  type        = string
  default     = null
}

variable "existing_private_lan_id" {
  description = "ID of an existing private IONOS LAN in the selected datacenter. When null, this module creates one."
  type        = string
  default     = null
}

variable "lb_private_ip" {
  description = "Deprecated: provider load balancers are not provisioned. The control-plane endpoint is the first CP private IP."
  type        = string
  default     = null
}

variable "enable_placement_group" {
  description = "Deprecated compatibility flag. IONOS Cubes do not expose provider-managed placement groups."
  type        = bool
  default     = false
}

variable "pod_cidr" {
  description = "CIDR for Kubernetes pods (RKE2 cluster-cidr and Cilium). Must not overlap with other clusters on the same network."
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services (RKE2 service-cidr). Must not overlap with other clusters on the same network."
  type        = string
  default     = "10.43.0.0/16"
}

# =============================================================================
# Worker Node Pools
# =============================================================================

variable "node_pools" {
  description = <<-EOT
    List of worker node pool configurations.
    Each pool is independently configurable for server type, count, location, labels, taints,
    autoscaling mode, public IP assignment, and optional dedicated Longhorn data volume.
  EOT
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

    # "fixed" = Terraform-managed count; "autoscaled" = Cluster Autoscaler manages after bootstrap
    scaling_mode = optional(string, "fixed")
    min_nodes    = optional(number, 1)
    max_nodes    = optional(number, 10)

    assign_public_ip = optional(bool, false)

    # Size in GB of a dedicated IONOS block volume for Longhorn data.
    # 0 = Longhorn uses the OS disk's /var/lib/longhorn directory.
    longhorn_volume_size = optional(number, 0)
  }))
  default = []

  validation {
    condition = alltrue([
      for p in var.node_pools : contains(["fixed", "autoscaled"], p.scaling_mode)
    ])
    error_message = "Each node pool's scaling_mode must be 'fixed' or 'autoscaled'."
  }
}

# =============================================================================
# Security & Firewall
# =============================================================================

variable "enable_firewall" {
  description = "Create IONOS public NIC firewall rules with production-derived security rules."
  type        = bool
  default     = true
}

variable "trusted_ssh_cidrs" {
  description = <<-EOT
    Single public IPv4 addresses allowed to SSH (TCP 22) to all nodes.
    IONOS firewall source_ip accepts an IPv4 address, not a network CIDR; /32 is accepted and stripped before use.
    Default [] = SSH blocked from all external IPs.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for source in var.trusted_ssh_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/32)?$", source))
    ])
    error_message = "trusted_ssh_cidrs must contain only individual IPv4 addresses or /32 host routes because IONOS firewall source_ip does not accept broad CIDRs."
  }
}

variable "kube_api_allowed_cidrs" {
  description = <<-EOT
    Single public IPv4 addresses allowed to reach the Kubernetes API server (port 6443) directly on control-plane nodes.
    IONOS firewall source_ip accepts an IPv4 address, not a network CIDR; /32 is accepted and stripped before use.
    Default closed. Use Tailscale-routed private access for management.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for source in var.kube_api_allowed_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/32)?$", source))
    ])
    error_message = "kube_api_allowed_cidrs must contain only individual IPv4 addresses or /32 host routes because IONOS firewall source_ip does not accept broad CIDRs."
  }
}

variable "tailscale_wireguard_allowed_cidrs" {
  description = "Single public IPv4 addresses allowed to reach tailscaled's WireGuard UDP listener (41641). Empty = rely on outbound/DERP only."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for source in var.tailscale_wireguard_allowed_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/32)?$", source))
    ])
    error_message = "tailscale_wireguard_allowed_cidrs must contain only individual IPv4 addresses or /32 host routes because IONOS firewall source_ip does not accept broad CIDRs."
  }
}

variable "nodeport_allowed_cidrs" {
  description = <<-EOT
    Single public IPv4 addresses allowed to reach NodePort services (TCP 30000-32767) on worker nodes.
    IONOS firewall source_ip accepts an IPv4 address, not a network CIDR; /32 is accepted and stripped before use.
    Default [] = NodePort closed. Prefer Cloudflare Tunnel/Gateway access instead of NodePort.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for source in var.nodeport_allowed_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/32)?$", source))
    ])
    error_message = "nodeport_allowed_cidrs must contain only individual IPv4 addresses or /32 host routes because IONOS firewall source_ip does not accept broad CIDRs."
  }
}

# =============================================================================
# Add-on Flags
# =============================================================================

variable "enable_external_dns" {
  description = "Deploy External-DNS with two Cloudflare deployments (proxied + DNS-only)."
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Deploy cert-manager with Cloudflare DNS-01 ClusterIssuer."
  type        = bool
  default     = false
}

variable "enable_ingress" {
  description = "Deploy Traefik ingress controller with Gateway API CRDs."
  type        = bool
  default     = false
}

variable "enable_envoy_gateway" {
  description = "Deploy Envoy Gateway and a default Gateway API Gateway for Cloudflare Tunnel ingress."
  type        = bool
  default     = false
}

variable "enable_longhorn" {
  description = "Deploy Longhorn distributed storage with RWO and RWX StorageClasses."
  type        = bool
  default     = false
}

variable "longhorn_rwx_mode" {
  description = "Longhorn RWX backend. 'builtin' uses Longhorn's built-in share manager; 'external' deploys a separate NFS server."
  type        = string
  default     = "builtin"

  validation {
    condition     = contains(["builtin", "external"], var.longhorn_rwx_mode)
    error_message = "longhorn_rwx_mode must be 'builtin' or 'external'."
  }
}

variable "longhorn_rwx_nfs_options" {
  description = "NFS mount options for the built-in Longhorn RWX StorageClass. Use vers=4.0 only with Longhorn versions that support NFSv4.0 exports."
  type        = string
  default     = "vers=4.1,noresvport,softerr,timeo=600,retrans=5"
}

variable "longhorn_default_data_path" {
  description = "Longhorn default data path for node-local storage. Use /var/lib/longhorn for OS-disk folder-backed storage; use /mnt/longhorn only when dedicated data volumes are mounted there."
  type        = string
  default     = "/var/lib/longhorn"
}

variable "enable_cluster_autoscaler" {
  description = "Deprecated for IONOS first cut. Static node pools are supported; autoscaler wiring is intentionally disabled."
  type        = bool
  default     = false
}

variable "autoscaler_rbac_level" {
  description = "RBAC scope for the autoscaler ClusterRole. 'upstream' tracks the standard upstream ClusterRole; 'minimal' uses a reduced permission set."
  type        = string
  default     = "upstream"

  validation {
    condition     = contains(["upstream", "minimal"], var.autoscaler_rbac_level)
    error_message = "autoscaler_rbac_level must be 'upstream' or 'minimal'."
  }
}

variable "enable_flux" {
  description = "Bootstrap Flux CD via the fluxcd/flux Terraform provider."
  type        = bool
  default     = false
}

variable "flux_deploy_key_mode" {
  description = "Deploy key mode for Flux. 'auto' generates an SSH keypair and registers it via GitHub API; 'manual' uses a pre-registered key."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "manual"], var.flux_deploy_key_mode)
    error_message = "flux_deploy_key_mode must be 'auto' or 'manual'."
  }
}

variable "enable_monitoring" {
  description = "Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana)."
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

variable "enable_tailscale_nodes" {
  description = "Install Tailscale on each node via cloud-init for VPN mesh SSH access."
  type        = bool
  default     = false
}

# =============================================================================
# Cloudflare (required when enable_external_dns or enable_cert_manager = true)
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permission on cloudflare_zone_id. Required for External-DNS and cert-manager."
  type        = string
  sensitive   = true
  default     = null
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID. Required when enable_external_dns or enable_cert_manager is true."
  type        = string
  default     = null
}

variable "cloudflare_zone" {
  description = "Cloudflare zone domain (e.g., 'example.com'). Required for Cloudflare-managed resources."
  type        = string
  default     = null
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID. Required when enable_cloudflare_tunnel = true."
  type        = string
  default     = null
}

variable "enable_cloudflare_tunnel" {
  description = "Deploy a Cloudflare Tunnel and in-cluster cloudflared connectors."
  type        = bool
  default     = false
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
  description = "Additional Cloudflare Tunnel ingress rules. Envoy Gateway hostnames and a 404 catch-all are appended automatically."
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
# Flux / GitHub (required when enable_flux = true)
# =============================================================================

variable "github_token" {
  description = "GitHub personal access token with repo scope. Required when enable_flux=true and flux_deploy_key_mode='auto'."
  type        = string
  sensitive   = true
  default     = null
}

variable "flux_github_org" {
  description = "GitHub organization or user that owns the Flux repository."
  type        = string
  default     = null
}

variable "flux_github_repo" {
  description = "GitHub repository name for Flux to manage."
  type        = string
  default     = null
}

variable "flux_branch" {
  description = "Git branch for Flux to track."
  type        = string
  default     = "main"
}

variable "flux_path" {
  description = "Path within the Flux repository where cluster manifests live."
  type        = string
  default     = "clusters/main"
}

# =============================================================================
# Tailscale (required when enable_tailscale_operator or enable_tailscale_nodes = true)
# =============================================================================

variable "tailscale_operator_auth_key" {
  description = "Tailscale auth key for the Kubernetes operator. Separate from node-level key; use tag:k8s-operator ACL tag."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_node_auth_key" {
  description = "Tailscale auth key for node-level enrollment via cloud-init. Use ephemeral reusable keys; tag: tag:k8s-node."
  type        = string
  sensitive   = true
  default     = null
}

# =============================================================================
# etcd Backup
# =============================================================================

variable "enable_etcd_backup" {
  description = "Enable automated etcd snapshots to S3-compatible storage via RKE2 native config."
  type        = bool
  default     = false
}

variable "etcd_s3_endpoint" {
  description = "S3-compatible endpoint for etcd backups (e.g. 's3.us-east-1.amazonaws.com')."
  type        = string
  default     = null
}

variable "etcd_s3_bucket" {
  description = "S3 bucket name for etcd snapshots."
  type        = string
  default     = null
}

variable "etcd_s3_access_key" {
  description = "S3 access key for etcd backup uploads."
  type        = string
  sensitive   = true
  default     = null
}

variable "etcd_s3_secret_key" {
  description = "S3 secret key for etcd backup uploads."
  type        = string
  sensitive   = true
  default     = null
}

variable "etcd_s3_region" {
  description = "S3 region for etcd backups."
  type        = string
  default     = null
}

variable "etcd_s3_folder" {
  description = "S3 folder (prefix) for etcd snapshots. Defaults to cluster_name at usage site."
  type        = string
  default     = null
}

variable "etcd_snapshot_schedule_cron" {
  description = "Cron schedule for etcd snapshots."
  type        = string
  default     = "0 */6 * * *"
}

variable "etcd_snapshot_retention" {
  description = "Number of etcd snapshots to retain."
  type        = number
  default     = 48
}

# =============================================================================
# Monitoring
# =============================================================================

variable "grafana_hostname" {
  description = "Hostname for Grafana ingress. Used by external-dns + cert-manager if both are enabled."
  type        = string
  default     = null
}

# =============================================================================
# Argo CD (required when enable_argocd = true)
# =============================================================================

variable "enable_argocd" {
  description = "Deploy Argo CD and Argo Rollouts."
  type        = bool
  default     = false
}

variable "enable_system_upgrade_controller" {
  description = "Deploy Rancher System Upgrade Controller for automated node upgrades via Plan CRDs."
  type        = bool
  default     = false
}

variable "argocd_hostname" {
  description = "Hostname for Argo CD ingress (e.g. 'argocd.example.com'). When null, no Ingress is created — access via kubectl port-forward. Requires enable_ingress = true when set."
  type        = string
  default     = null
}

variable "argocd_github_client_id" {
  description = "GitHub OAuth App client ID for Argo CD Dex SSO. Provide together with argocd_github_client_secret to enable GitHub login."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_github_client_secret" {
  description = "GitHub OAuth App client secret for Argo CD Dex SSO."
  type        = string
  sensitive   = true
  default     = null
}

variable "argocd_dex_connectors" {
  description = "Raw Dex connectors YAML string. When set, overrides the auto-wired GitHub connector. Use for non-GitHub providers (Google, LDAP, OIDC, etc.)."
  type        = string
  default     = null
}

# =============================================================================
# Outputs
# =============================================================================

variable "expose_rke2_token" {
  description = "Output the RKE2 cluster join token. Default false — only enable if callers need it outside this module. The token is always stored in Terraform state."
  type        = bool
  default     = false
}

# =============================================================================
# Component Version Pins
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
  description = "Longhorn Helm chart version."
  type        = string
  default     = "1.8.2"
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version."
  type        = string
  default     = "v1.20.3"
}

variable "external_dns_chart_version" {
  description = "External-DNS Helm chart version."
  type        = string
  default     = "1.21.1"
}

variable "envoy_gateway_chart_version" {
  description = "Envoy Gateway Helm chart version."
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
  default     = "2.7.0"
}

variable "bitwarden_eso_provider_chart_version" {
  description = "Bitwarden ESO provider Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "1.2.0"
}

variable "traefik_chart_version" {
  description = "Traefik Helm chart version (v3.x)."
  type        = string
  default     = "~> 32.0"
}

variable "flux_version" {
  description = "Flux CD version for flux_bootstrap_git."
  type        = string
  default     = "2.18.4"
}

variable "cluster_autoscaler_chart_version" {
  description = "Cluster Autoscaler Helm chart version. Must match cluster Kubernetes minor version."
  type        = string
  default     = "9.46.6"
}

variable "cluster_autoscaler_image_tag" {
  description = "Cluster Autoscaler container image tag. Must match cluster Kubernetes minor version (e.g., v1.33.0 for K8s 1.33)."
  type        = string
  default     = "v1.33.0"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "87.2.1"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "~> 9.4"
}

variable "argo_rollouts_chart_version" {
  description = "Argo Rollouts Helm chart version."
  type        = string
  default     = "~> 2.40"
}

variable "system_upgrade_controller_chart_version" {
  description = "System Upgrade Controller Helm chart version. Must be an exact version — Helm provider v3 does not support constraint expressions."
  type        = string
  default     = "0.14.2"
}
