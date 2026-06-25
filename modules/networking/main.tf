# =============================================================================
# IONOS Virtual Data Center and LANs
#
# IONOS models private networking as LANs inside a Virtual Data Center. Nodes get
# a public LAN for outbound bootstrap/Tailscale/Cloudflare Tunnel traffic and a
# private LAN for RKE2, etcd, kubelet, Cilium, and Longhorn replication.
# =============================================================================

resource "ionoscloud_datacenter" "cluster" {
  count    = var.existing_datacenter_id == null ? 1 : 0
  name     = "${var.cluster_name}-vdc"
  location = var.location
}

data "ionoscloud_datacenter" "existing" {
  count = var.existing_datacenter_id != null ? 1 : 0
  id    = var.existing_datacenter_id
}

resource "ionoscloud_lan" "public" {
  count         = var.existing_public_lan_id == null ? 1 : 0
  datacenter_id = local.datacenter_id
  public        = true
  name          = "${var.cluster_name}-public"
}

resource "ionoscloud_lan" "private" {
  count         = var.existing_private_lan_id == null ? 1 : 0
  datacenter_id = local.datacenter_id
  public        = false
  name          = "${var.cluster_name}-private"
}

locals {
  datacenter_id   = var.existing_datacenter_id != null ? var.existing_datacenter_id : ionoscloud_datacenter.cluster[0].id
  datacenter_name = var.existing_datacenter_id != null ? data.ionoscloud_datacenter.existing[0].name : ionoscloud_datacenter.cluster[0].name

  public_lan_id  = var.existing_public_lan_id != null ? var.existing_public_lan_id : ionoscloud_lan.public[0].id
  private_lan_id = var.existing_private_lan_id != null ? var.existing_private_lan_id : ionoscloud_lan.private[0].id
}
