# terraform-ionoscloud-rke2-cluster

Terraform module for a self-managed RKE2 cluster on IONOS Cloud Cubes.

This module is forked from the Hetzner RKE2 module, but the provider-specific
layers are IONOS-specific:

- `ionos-cloud/ionoscloud` provider
- IONOS Virtual Data Center plus public/private LANs
- IONOS Cube servers via `ionoscloud_cube_server`
- deterministic private NIC IPs for RKE2 bootstrap
- public NIC firewall rules for optional SSH/API/Tailscale direct-peer access
- no provider load balancer, no provider CCM, no provider CSI, no autoscaler

## Current Scope

The first IONOS cut supports static clusters. Use it for the intended 3 control
plane / 2 worker shape before adding provider integrations.

Supported:

- HA RKE2 control plane with embedded etcd
- static worker node pools
- Cilium CNI
- Longhorn on OS disks or optional attached IONOS volumes
- ExternalDNS, cert-manager, Flux, monitoring, and Tailscale operator
- Cloudflare Tunnel based ingress outside provider load balancers

Not yet supported:

- IONOS CCM
- IONOS CSI
- Cluster Autoscaler
- IONOS managed load balancers for Kubernetes Services

## Provider Auth

Prefer token auth through the environment:

```bash
export IONOS_TOKEN=...
```

The provider also supports username/password and config-file auth, but token
auth is the intended CI/CD path.

## Important Defaults

- `location = "us/ewr"`
- `control_plane_server_type = "Basic Cube L"`
- `os_image = "ubuntu:latest"`
- `enable_firewall = true`
- SSH, public Kubernetes API, NodePort, and Tailscale direct-peer ingress are
  closed unless their corresponding allowlists are set. IONOS NIC firewall
  `source_ip` accepts single IPv4 addresses, so broad CIDRs are intentionally
  rejected; use individual IPs or `/32` host routes only.

The module keeps the first control-plane private IP as the Kubernetes API and
RKE2 supervisor endpoint. Management access should go through Tailscale routes
or direct node Tailscale IPs.

## Private Networking

IONOS LAN CIDRs are provider-computed, but this module assigns deterministic
private NIC IPs from `cluster_subnet_cidr` to preserve the existing RKE2
bootstrap model.

Before production use, verify in a real plan/apply that the selected IONOS
location accepts explicit RFC1918 addresses in `ionoscloud_cube_server.nic.ips`
for the private LAN.

## Minimal Example

```hcl
module "cluster" {
  source = "../modules/terraform-ionoscloud-rke2-cluster"

  cluster_name              = "rke2-abby"
  location                  = "us/ewr"
  control_plane_server_type = "Basic Cube L"
  os_image                  = "ubuntu:latest"

  ssh_keys        = [file(pathexpand("~/.ssh/id_ed25519.pub"))]
  ssh_private_key = file(pathexpand("~/.ssh/id_ed25519"))

  cluster_subnet_cidr = "10.11.0.0/16"
  pod_cidr            = "10.42.0.0/16"
  service_cidr        = "10.43.0.0/16"

  enable_tailscale_nodes = true
  tailscale_node_auth_key = var.tailscale_node_auth_key

  node_pools = [
    {
      name        = "general"
      server_type = "Basic Cube L"
      node_count  = 2
      scaling_mode = "fixed"
    }
  ]
}
```

## Validation

From this repository:

```bash
terraform -chdir=modules/terraform-ionoscloud-rke2-cluster init -backend=false
terraform -chdir=modules/terraform-ionoscloud-rke2-cluster validate
```
