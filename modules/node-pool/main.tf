locals {
  taint_args = join("\n", [
    for t in var.taints : "        - \"${t.key}=${t.value}:${t.effect}\""
  ])
  has_taints = length(var.taints) > 0

  label_args = join("\n", [
    for k, v in var.labels : "        - \"${k}=${v}\""
  ])
  has_labels = length(var.labels) > 0

  disabled_component_args = join("\n", [
    for name in var.disabled_packaged_components : "        - \"${name}\""
  ])
  has_disabled_components = length(var.disabled_packaged_components) > 0

  node_private_ips = var.private_ip_offset == null ? [] : [
    for index in range(var.node_count) : cidrhost(var.cluster_subnet_cidr, var.private_ip_offset + index)
  ]

  ssh_firewall_rules = flatten([
    for source in var.trusted_ssh_cidrs : [{
      name       = "ssh-${replace(replace(source, "/", "-"), ".", "-")}"
      protocol   = "TCP"
      port_start = 22
      port_end   = 22
      source_ip  = trimsuffix(source, "/32")
    }]
  ])

  kube_api_firewall_rules = flatten([
    for source in var.kube_api_allowed_cidrs : [{
      name       = "kube-api-${replace(replace(source, "/", "-"), ".", "-")}"
      protocol   = "TCP"
      port_start = 6443
      port_end   = 6443
      source_ip  = trimsuffix(source, "/32")
    }]
  ])

  tailscale_firewall_rules = flatten([
    for source in var.tailscale_wireguard_allowed_cidrs : [{
      name       = "tailscale-${replace(replace(source, "/", "-"), ".", "-")}"
      protocol   = "UDP"
      port_start = 41641
      port_end   = 41641
      source_ip  = trimsuffix(source, "/32")
    }]
  ])

  nodeport_firewall_rules = flatten([
    for source in var.nodeport_allowed_cidrs : [{
      name       = "nodeport-${replace(replace(source, "/", "-"), ".", "-")}"
      protocol   = "TCP"
      port_start = 30000
      port_end   = 32767
      source_ip  = trimsuffix(source, "/32")
    }]
  ])

  public_firewall_rules = concat(
    local.ssh_firewall_rules,
    local.kube_api_firewall_rules,
    local.tailscale_firewall_rules,
    local.nodeport_firewall_rules,
  )

  rendered_user_data = [
    for index in range(var.node_count) : (
      var.role == "server" && index == 0
      ? templatefile("${path.module}/templates/cp-init.yaml.tpl", {
        rke2_version                = var.rke2_version
        rke2_token                  = var.rke2_token
        control_plane_lb_ip         = var.control_plane_lb_ip
        node_ip                     = local.node_private_ips[index]
        first_cp_ip                 = null
        cluster_init                = true
        has_labels                  = local.has_labels
        label_args                  = local.label_args
        has_taints                  = local.has_taints
        taint_args                  = local.taint_args
        longhorn_volume_size        = var.longhorn_volume_size
        enable_tailscale            = var.enable_tailscale_nodes
        tailscale_auth_key          = var.tailscale_auth_key != null ? var.tailscale_auth_key : ""
        hostname                    = "${var.pool_name}-1"
        pod_cidr                    = var.pod_cidr
        service_cidr                = var.service_cidr
        cluster_subnet_cidr         = var.cluster_subnet_cidr
        private_network_gateway     = var.private_network_gateway
        has_disabled_components     = local.has_disabled_components
        disabled_component_args     = local.disabled_component_args
        enable_etcd_backup          = var.enable_etcd_backup
        etcd_snapshot_schedule_cron = var.etcd_snapshot_schedule_cron
        etcd_snapshot_retention     = var.etcd_snapshot_retention
        etcd_s3_endpoint            = var.etcd_s3_endpoint != null ? var.etcd_s3_endpoint : ""
        etcd_s3_bucket              = var.etcd_s3_bucket != null ? var.etcd_s3_bucket : ""
        etcd_s3_access_key          = var.etcd_s3_access_key != null ? var.etcd_s3_access_key : ""
        etcd_s3_secret_key          = var.etcd_s3_secret_key != null ? var.etcd_s3_secret_key : ""
        etcd_s3_region              = var.etcd_s3_region != null ? var.etcd_s3_region : ""
        etcd_s3_folder              = var.etcd_s3_folder != null ? var.etcd_s3_folder : ""
      })
      : var.role == "server"
      ? templatefile("${path.module}/templates/cp-init.yaml.tpl", {
        rke2_version                = var.rke2_version
        rke2_token                  = var.rke2_token
        control_plane_lb_ip         = var.control_plane_lb_ip
        node_ip                     = local.node_private_ips[index]
        cluster_init                = false
        first_cp_ip                 = var.first_cp_ip
        has_labels                  = local.has_labels
        label_args                  = local.label_args
        has_taints                  = local.has_taints
        taint_args                  = local.taint_args
        longhorn_volume_size        = var.longhorn_volume_size
        enable_tailscale            = var.enable_tailscale_nodes
        tailscale_auth_key          = var.tailscale_auth_key != null ? var.tailscale_auth_key : ""
        hostname                    = "${var.pool_name}-${index + 1}"
        pod_cidr                    = var.pod_cidr
        service_cidr                = var.service_cidr
        cluster_subnet_cidr         = var.cluster_subnet_cidr
        private_network_gateway     = var.private_network_gateway
        has_disabled_components     = local.has_disabled_components
        disabled_component_args     = local.disabled_component_args
        enable_etcd_backup          = var.enable_etcd_backup
        etcd_snapshot_schedule_cron = var.etcd_snapshot_schedule_cron
        etcd_snapshot_retention     = var.etcd_snapshot_retention
        etcd_s3_endpoint            = var.etcd_s3_endpoint != null ? var.etcd_s3_endpoint : ""
        etcd_s3_bucket              = var.etcd_s3_bucket != null ? var.etcd_s3_bucket : ""
        etcd_s3_access_key          = var.etcd_s3_access_key != null ? var.etcd_s3_access_key : ""
        etcd_s3_secret_key          = var.etcd_s3_secret_key != null ? var.etcd_s3_secret_key : ""
        etcd_s3_region              = var.etcd_s3_region != null ? var.etcd_s3_region : ""
        etcd_s3_folder              = var.etcd_s3_folder != null ? var.etcd_s3_folder : ""
      })
      : templatefile("${path.module}/templates/worker-init.yaml.tpl", {
        rke2_version            = var.rke2_version
        rke2_token              = var.rke2_token
        control_plane_lb_ip     = var.control_plane_lb_ip
        node_ip                 = var.private_ip_offset != null ? local.node_private_ips[index] : null
        cluster_subnet_cidr     = var.cluster_subnet_cidr
        has_labels              = local.has_labels
        label_args              = local.label_args
        has_taints              = local.has_taints
        taint_args              = local.taint_args
        longhorn_volume_size    = var.longhorn_volume_size
        enable_tailscale        = var.enable_tailscale_nodes
        tailscale_auth_key      = var.tailscale_auth_key != null ? var.tailscale_auth_key : ""
        hostname                = "${var.pool_name}-${index + 1}"
        private_network_gateway = var.private_network_gateway
      })
    )
  ]
}

data "ionoscloud_template" "selected" {
  name = var.server_type
}

resource "ionoscloud_cube_server" "nodes" {
  count = var.node_count

  name              = "${var.pool_name}-${count.index + 1}"
  hostname          = "${var.pool_name}-${count.index + 1}"
  datacenter_id     = var.datacenter_id
  image_name        = var.os_image
  template_uuid     = data.ionoscloud_template.selected.id
  availability_zone = "AUTO"
  ssh_key_path      = var.ssh_keys

  volume {
    name         = "${var.pool_name}-${count.index + 1}-boot"
    licence_type = "LINUX"
    disk_type    = "DAS"
    user_data    = base64encode(local.rendered_user_data[count.index])
  }

  dynamic "nic" {
    for_each = var.assign_public_ip ? [1] : []
    content {
      lan             = var.public_lan_id
      name            = "${var.pool_name}-${count.index + 1}-public"
      dhcp            = true
      firewall_active = var.enable_firewall
      firewall_type   = "INGRESS"

      dynamic "firewall" {
        for_each = var.enable_firewall ? local.public_firewall_rules : []
        content {
          name             = firewall.value.name
          protocol         = firewall.value.protocol
          port_range_start = firewall.value.port_start
          port_range_end   = firewall.value.port_end
          source_ip        = firewall.value.source_ip
          type             = "INGRESS"
        }
      }
    }
  }

  nic {
    lan             = var.private_lan_id
    name            = "${var.pool_name}-${count.index + 1}-private"
    dhcp            = false
    ips             = [local.node_private_ips[count.index]]
    firewall_active = false
  }

  lifecycle {
    ignore_changes = [
      volume[0].user_data,
    ]
  }
}

resource "ionoscloud_volume" "longhorn_data" {
  count = var.longhorn_volume_size > 0 ? var.node_count : 0

  datacenter_id     = var.datacenter_id
  server_id         = ionoscloud_cube_server.nodes[count.index].id
  name              = "${var.pool_name}-longhorn-${count.index + 1}"
  availability_zone = "AUTO"
  size              = var.longhorn_volume_size
  disk_type         = "SSD Standard"
  bus               = "VIRTIO"
  licence_type      = "OTHER"

  lifecycle {
    prevent_destroy = true
  }
}
