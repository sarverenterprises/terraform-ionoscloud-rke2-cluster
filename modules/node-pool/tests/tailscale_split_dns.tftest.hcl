mock_provider "ionoscloud" {}

run "control_plane_split_dns" {
  command = plan

  variables {
    pool_name                         = "rke2-test-cp"
    cluster_name                      = "rke2-test"
    role                              = "server"
    server_type                       = "Basic Cube L"
    location                          = "us/ewr"
    ssh_keys                          = ["ssh-ed25519 test"]
    datacenter_id                     = "test-datacenter"
    public_lan_id                     = "1"
    private_lan_id                    = "2"
    network_id                        = "2"
    subnet_id                         = "2"
    assign_public_ip                  = true
    rke2_version                      = "v1.33.12+rke2r2"
    rke2_token                        = "test-token"
    control_plane_lb_ip               = "10.21.0.10"
    first_cp_ip                       = "10.21.0.10"
    cluster_subnet_cidr               = "10.21.0.0/16"
    private_ip_offset                 = 10
    private_network_gateway           = "10.0.0.1"
    node_dns_servers                  = ["1.1.1.1", "9.9.9.9"]
    enable_tailscale_nodes            = true
    tailscale_auth_key                = "tskey-auth-test"
    enable_tailscale_split_dns        = true
    tailscale_magic_dns_domain        = "example-tailnet.invalid"
    tailscale_split_dns_extra_domains = ["~ts.net"]
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf")
    error_message = "Control-plane cloud-init must preserve the systemd-resolved stub symlink."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "--accept-dns=false")
    error_message = "Control-plane cloud-init must disable Tailscale DNS ownership explicitly."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "resolvectl dns tailscale0 100.100.100.100\n      resolvectl domain tailscale0 ~example-tailnet.invalid ~ts.net")
    error_message = "Control-plane cloud-init must configure the MagicDNS resolver and routed domains."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "[Link]\n      Unmanaged=yes")
    error_message = "Control-plane cloud-init must leave tailscale0 unmanaged by systemd-networkd."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "if systemctl is-active --quiet systemd-networkd; then\n      networkctl reload\n    fi\n    tailscale up")
    error_message = "Control-plane cloud-init must reload active systemd-networkd before tailscale up."
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "cat >/etc/resolv.conf <<'EOF'")
    error_message = "Control-plane split-DNS mode must not replace /etc/resolv.conf with a static file."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "apt-get install -y cryptsetup dmsetup nfs-common open-iscsi")
    error_message = "Control-plane cloud-init must install all Longhorn host prerequisite packages."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "modprobe dm_crypt")
    error_message = "Control-plane cloud-init must load dm_crypt."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "systemctl mask multipathd.service multipathd.socket")
    error_message = "Control-plane cloud-init must prevent multipathd activation."
  }
}

run "worker_split_dns" {
  command = plan

  variables {
    pool_name                         = "rke2-test-general"
    cluster_name                      = "rke2-test"
    role                              = "agent"
    server_type                       = "Basic Cube L"
    location                          = "us/ewr"
    ssh_keys                          = ["ssh-ed25519 test"]
    datacenter_id                     = "test-datacenter"
    public_lan_id                     = "1"
    private_lan_id                    = "2"
    network_id                        = "2"
    subnet_id                         = "2"
    assign_public_ip                  = true
    rke2_version                      = "v1.33.12+rke2r2"
    rke2_token                        = "test-token"
    control_plane_lb_ip               = "10.21.0.10"
    first_cp_ip                       = "10.21.0.10"
    cluster_subnet_cidr               = "10.21.0.0/16"
    private_ip_offset                 = 100
    private_network_gateway           = "10.0.0.1"
    node_dns_servers                  = ["1.1.1.1", "9.9.9.9"]
    enable_tailscale_nodes            = true
    tailscale_auth_key                = "tskey-auth-test"
    enable_tailscale_split_dns        = true
    tailscale_magic_dns_domain        = "example-tailnet.invalid"
    tailscale_split_dns_extra_domains = ["~ts.net"]
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf")
    error_message = "Worker cloud-init must preserve the systemd-resolved stub symlink."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "--accept-dns=false")
    error_message = "Worker cloud-init must disable Tailscale DNS ownership explicitly."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "resolvectl dns tailscale0 100.100.100.100\n      resolvectl domain tailscale0 ~example-tailnet.invalid ~ts.net")
    error_message = "Worker cloud-init must configure the MagicDNS resolver and routed domains."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "[Link]\n      Unmanaged=yes")
    error_message = "Worker cloud-init must leave tailscale0 unmanaged by systemd-networkd."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "if systemctl is-active --quiet systemd-networkd; then\n      networkctl reload\n    fi\n    tailscale up")
    error_message = "Worker cloud-init must reload active systemd-networkd before tailscale up."
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "cat >/etc/resolv.conf <<'EOF'")
    error_message = "Worker split-DNS mode must not replace /etc/resolv.conf with a static file."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "apt-get install -y cryptsetup dmsetup nfs-common open-iscsi")
    error_message = "Worker cloud-init must install all Longhorn host prerequisite packages."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "modprobe dm_crypt")
    error_message = "Worker cloud-init must load dm_crypt."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "systemctl mask multipathd.service multipathd.socket")
    error_message = "Worker cloud-init must prevent multipathd activation."
  }
}

run "legacy_dns_defaults_remain_compatible" {
  command = plan

  variables {
    pool_name               = "rke2-test-general"
    cluster_name            = "rke2-test"
    role                    = "agent"
    server_type             = "Basic Cube L"
    location                = "us/ewr"
    ssh_keys                = ["ssh-ed25519 test"]
    datacenter_id           = "test-datacenter"
    public_lan_id           = "1"
    private_lan_id          = "2"
    network_id              = "2"
    subnet_id               = "2"
    assign_public_ip        = true
    rke2_version            = "v1.33.12+rke2r2"
    rke2_token              = "test-token"
    control_plane_lb_ip     = "10.21.0.10"
    first_cp_ip             = "10.21.0.10"
    cluster_subnet_cidr     = "10.21.0.0/16"
    private_ip_offset       = 100
    private_network_gateway = "10.0.0.1"
    node_dns_servers        = ["1.1.1.1", "9.9.9.9"]
    enable_tailscale_nodes  = true
    tailscale_auth_key      = "tskey-auth-test"
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "cat >/etc/resolv.conf <<'EOF'")
    error_message = "The default DNS mode must keep the existing static resolver behavior."
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "--accept-dns=false")
    error_message = "The default Tailscale mode must remain unchanged."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "[Link]\n      Unmanaged=yes")
    error_message = "Tailscale-enabled nodes must leave tailscale0 unmanaged by systemd-networkd."
  }
}

run "control_plane_without_tailscale" {
  command = plan

  variables {
    pool_name               = "rke2-test-cp"
    cluster_name            = "rke2-test"
    role                    = "server"
    server_type             = "Basic Cube L"
    location                = "us/ewr"
    ssh_keys                = ["ssh-ed25519 test"]
    datacenter_id           = "test-datacenter"
    public_lan_id           = "1"
    private_lan_id          = "2"
    network_id              = "2"
    subnet_id               = "2"
    assign_public_ip        = true
    rke2_version            = "v1.33.12+rke2r2"
    rke2_token              = "test-token"
    control_plane_lb_ip     = "10.21.0.10"
    first_cp_ip             = "10.21.0.10"
    cluster_subnet_cidr     = "10.21.0.0/16"
    private_ip_offset       = 10
    private_network_gateway = "10.0.0.1"
    node_dns_servers        = ["1.1.1.1", "9.9.9.9"]
    enable_tailscale_nodes  = false
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "/etc/systemd/network/90-tailscale0.network")
    error_message = "Tailscale-disabled control-plane nodes must not receive the tailscale0 network file."
  }
}

run "worker_without_tailscale" {
  command = plan

  variables {
    pool_name               = "rke2-test-general"
    cluster_name            = "rke2-test"
    role                    = "agent"
    server_type             = "Basic Cube L"
    location                = "us/ewr"
    ssh_keys                = ["ssh-ed25519 test"]
    datacenter_id           = "test-datacenter"
    public_lan_id           = "1"
    private_lan_id          = "2"
    network_id              = "2"
    subnet_id               = "2"
    assign_public_ip        = true
    rke2_version            = "v1.33.12+rke2r2"
    rke2_token              = "test-token"
    control_plane_lb_ip     = "10.21.0.10"
    first_cp_ip             = "10.21.0.10"
    cluster_subnet_cidr     = "10.21.0.0/16"
    private_ip_offset       = 100
    private_network_gateway = "10.0.0.1"
    node_dns_servers        = ["1.1.1.1", "9.9.9.9"]
    enable_tailscale_nodes  = false
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(ionoscloud_cube_server.nodes[0].volume[0].user_data)), "/etc/systemd/network/90-tailscale0.network")
    error_message = "Tailscale-disabled worker nodes must not receive the tailscale0 network file."
  }
}
