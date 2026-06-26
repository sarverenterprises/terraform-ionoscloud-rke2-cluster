# Changelog

## Unreleased

- Persist IONOS public and private NIC netplan entries by MAC address during
  bootstrap so RKE2 nodes do not depend on a fixed Linux interface name such as
  `ens7`.
- Created `terraform-ionoscloud-rke2-cluster` from the existing RKE2 module.
- Replaced Hetzner infrastructure resources with IONOS Virtual Data Center,
  LAN, Cube server, NIC firewall, and volume resources.
- Removed provider CCM, provider CSI, and Cluster Autoscaler from the first
  IONOS cut.
- Kept provider-neutral add-ons: Cilium, ExternalDNS, cert-manager, Longhorn,
  Flux, monitoring, Tailscale operator, Argo CD, and System Upgrade Controller.
