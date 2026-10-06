# Changelog

## Unreleased

- Added `envoy_gateway_escaped_slash_listener` (optional): a second, distinct-port
  plaintext HTTP listener on the default Gateway, hostname-scoped, so a
  `ClientTrafficPolicy` (notably `path.escapedSlashesAction: KeepUnchanged`) can
  be attached to that listener alone. Envoy Gateway rejects a listener-scoped
  ClientTrafficPolicy when another non-TLS listener shares the port, so the new
  listener requires a port distinct from `http` (80) and `https-direct` (443),
  and no dedicated Kubernetes Service is needed (the Envoy data-plane Service
  exposes every listener port automatically). Null (default) is a no-op.

- Added opt-in Tailscale split DNS for RKE2 nodes. The node templates now keep
  public DNS on systemd-resolved, route MagicDNS domains through tailscale0,
  and make Tailscale DNS ownership explicit without changing existing defaults.
- Moved direct NLB DNS annotations from the traffic-serving NodePort to a
  dedicated ClusterIP marker Service so ExternalDNS reliably publishes the
  DNS-only A record while the NodePort remains unchanged.
- Assigned the direct Envoy NLB a target-side private IP from
  `cluster_subnet_cidr` so it can reach statically addressed RKE2 nodes when the
  IONOS LAN's provider-computed subnet differs.
- Expanded direct Envoy NLB targets to every control-plane and worker private
  IP so the Kubernetes NodePort is reachable through every cluster host.
- Added an opt-in direct Envoy ingress path backed by one reserved IONOS IPv4,
  one Network Load Balancer, and one TCP forwarding rule. The Kubernetes side
  adds a hostname-scoped HTTPS listener and a separate NodePort Service while
  preserving the existing Cloudflare Tunnel HTTP listener and ClusterIP.
- Added a staged DNS publication switch so operators can validate the NLB with
  SNI before moving an ExternalDNS-managed hostname away from a Tunnel CNAME.
- Hardened the monitoring add-ons by removing node-exporter's host network,
  host PID namespace, and root filesystem mount, and by removing Alloy's
  host `/var/log` mount when pod logs are collected through the Kubernetes API.
- Added an optional Grafana Alloy add-on for cluster-level OTLP/log collection,
  with LGTM credentials sourced from a Kubernetes Secret instead of inline chart
  configuration.
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
