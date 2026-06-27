# =============================================================================
# Add-ons Module
#
# Deploys Kubernetes add-ons via Helm after the cluster is ready.
# Each component is behind a feature flag and implemented in its own file:
#
#   cilium.tf           — Cilium CNI
#   external_dns.tf     — External-DNS (two Cloudflare deployments)
#   cert_manager.tf     — cert-manager + Cloudflare ClusterIssuer
#   envoy_gateway.tf    — Envoy Gateway + default Gateway API entrypoint
#   ingress.tf          — Traefik (+ Gateway API CRDs)
#   longhorn.tf         — Longhorn distributed storage
#   flux.tf             — Flux CD bootstrap
#   monitoring.tf       — kube-prometheus-stack
#   tailscale.tf        — Tailscale Kubernetes operator
#   cloudflare_tunnel.tf — Cloudflare Tunnel connector
#
# IMPORTANT: This IONOS first cut intentionally omits provider CCM, provider CSI,
# and Cluster Autoscaler. Use Cloudflare Tunnel for ingress, Longhorn for storage,
# and static node pools until IONOS-specific integrations are designed.
#
# This module requires Helm and Kubernetes providers to be configured
# in the calling root module (see examples/) using the fetched kubeconfig.
# It will not function on a first-apply before the cluster exists.
# =============================================================================
