# Changelog

## Unreleased

- Added an optional RKE2 CoreDNS `HelmChartConfig` override so clusters can
  forward public DNS queries to explicit upstream resolvers instead of pod
  `/etc/resolv.conf`, preventing inherited resolver/search-domain behavior from
  causing public AAAA lookups to return `SERVFAIL`.
- Updated Abby-relevant add-on defaults for security and maintenance:
  cert-manager v1.20.3, External Secrets Operator 2.7.0, Flux chart 2.18.4,
  kube-prometheus-stack 87.2.1, Tailscale operator 1.98.4, and Longhorn 1.8.2
  as the next supported storage upgrade hop.
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
