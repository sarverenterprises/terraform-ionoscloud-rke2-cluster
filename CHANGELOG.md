# Changelog

## Unreleased

- Created `terraform-ionoscloud-rke2-cluster` from the existing RKE2 module.
- Replaced Hetzner infrastructure resources with IONOS Virtual Data Center,
  LAN, Cube server, NIC firewall, and volume resources.
- Removed provider CCM, provider CSI, and Cluster Autoscaler from the first
  IONOS cut.
- Kept provider-neutral add-ons: Cilium, ExternalDNS, cert-manager, Longhorn,
  Flux, monitoring, Tailscale operator, Argo CD, and System Upgrade Controller.
