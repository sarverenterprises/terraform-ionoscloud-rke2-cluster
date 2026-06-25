#cloud-config
# RKE2 Worker Agent bootstrap
# Joins the cluster via the private control-plane endpoint (port 9345).

write_files:
  - path: /etc/rancher/rke2/config.yaml
    owner: root:root
    permissions: '0600'
    content: |
      server: https://${control_plane_lb_ip}:9345
      token: "${rke2_token}"
      cloud-provider-name: external
      cni: none
%{ if has_labels ~}
      node-label:
${label_args}
%{ endif ~}
%{ if has_taints ~}
      node-taint:
${taint_args}
%{ endif ~}

runcmd:
  # Block metadata API at host level before any services start (defense-in-depth).
  # Cilium network policy provides pod-level blocking after CNI deploys, but this
  # iptables rule covers the bootstrap window when Cilium is not yet running.
  # Root (uid 0) is exempted so cloud-init and CCM can still function.
  - iptables -I OUTPUT -d 169.254.169.254 -m owner ! --uid-owner 0 -j DROP

%{ if enable_tailscale ~}
  # Install and configure Tailscale before private-network and RKE2 work. If
  # bootstrap stalls, the node remains reachable for diagnostics.
  - |
    for attempt in 1 2 3; do
      if curl -fsSL https://tailscale.com/install.sh -o /tmp/install-tailscale.sh \
        && sh /tmp/install-tailscale.sh; then
        break
      fi
      echo "Tailscale install attempt $attempt failed — retrying in $((attempt * 10))s..." >&2
      sleep $((attempt * 10))
    done
    if ! command -v tailscale >/dev/null 2>&1; then
      echo "FATAL: Tailscale install failed after 3 attempts" >&2
      exit 1
    fi
    tailscale up \
      --auth-key="${tailscale_auth_key}" \
      --hostname="${hostname}" \
      --ephemeral \
      2>&1 | tee -a /var/log/tailscale-setup.log
    if ! tailscale status >/dev/null 2>&1; then
      echo "ERROR: Tailscale enrollment failed — node will not be reachable via tailnet" >&2
    fi
%{ endif ~}

  # IONOS assigns the private NIC IP through the server/NIC definition. Do not
  # hardcode Linux interface names; wait for the expected address to appear.
  - |
%{ if node_ip != null ~}
    for i in $(seq 1 120); do
      if ip -4 addr show | grep -q "${node_ip}/"; then
        echo "IONOS private IP ${node_ip} detected"
        break
      fi
      if [ "$i" -eq 120 ]; then
        echo "FATAL: IONOS private IP ${node_ip} not present after 120s" >&2
        exit 1
      fi
      sleep 1
    done
%{ else ~}
    echo "No static private IP was provided; relying on provider DHCP."
%{ endif ~}
    for i in $(seq 1 60); do
      if getent hosts get.rke2.io >/dev/null 2>&1; then
        break
      fi
      if [ "$i" -eq 60 ]; then
        echo "FATAL: DNS did not become ready after private network configuration" >&2
        exit 1
      fi
      sleep 2
    done

  # Detect and set the IONOS private network IP for node-ip.
  # Uses subnet prefix matching (more reliable than interface names) with a
  # 60s retry loop to handle DHCP assignment lag on first boot.
  - |
    SUBNET_PREFIX=$(echo "${cluster_subnet_cidr}" | cut -d/ -f1 | cut -d. -f1-2)
    PRIVATE_IP=""
    for i in $(seq 1 60); do
      PRIVATE_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+(?=/)' \
                   | grep "^$SUBNET_PREFIX\." | head -1 || true)
      if [ -n "$PRIVATE_IP" ]; then break; fi
      sleep 1
    done
    if [ -n "$PRIVATE_IP" ]; then
      echo "node-ip: \"$PRIVATE_IP\"" >> /etc/rancher/rke2/config.yaml
      echo "Detected private IP: $PRIVATE_IP — written to config.yaml"
    else
      echo "FATAL: no private network IP detected after 60s — aborting to prevent wrong-IP join" >&2
      exit 1
    fi

  # Install RKE2 agent (retry up to 5 times for transient network failures)
  - |
    set -e
    for attempt in 1 2 3 4 5; do
      if curl -sfL https://get.rke2.io -o /tmp/install-rke2.sh \
        && INSTALL_RKE2_VERSION="${rke2_version}" INSTALL_RKE2_TYPE="agent" sh /tmp/install-rke2.sh; then
        break
      fi
      if [ "$attempt" -eq 5 ]; then
        echo "FATAL: RKE2 agent install failed after 5 attempts" >&2
        exit 1
      fi
      echo "RKE2 install attempt $attempt failed — retrying in $((attempt * 15))s..." >&2
      sleep $((attempt * 15))
    done

  # Enable and start RKE2 agent service
  - systemctl enable rke2-agent.service
  - systemctl start rke2-agent.service

  # Add RKE2 binaries to PATH for interactive sessions
  - |
    echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> /root/.bashrc

%{ if longhorn_volume_size > 0 ~}
  # Format and mount the first non-root IONOS block volume for Longhorn data.
  - |
    timeout 60 bash -c '
      until lsblk -ndo NAME,TYPE,MOUNTPOINT | awk "$2 == \"disk\" && $3 == \"\" {print \"/dev/\" $1}" | head -1 | grep -q .; do
        echo "Waiting for Longhorn volume to appear..."
        sleep 3
      done
    '
    DISK=$(lsblk -ndo NAME,TYPE,MOUNTPOINT | awk '$2 == "disk" && $3 == "" {print "/dev/" $1}' | head -1)
    echo "Found Longhorn data volume: $DISK"
    # Format only if not already formatted (ensures idempotency on node restart)
    if ! blkid "$DISK" 2>/dev/null | grep -q ext4; then
      mkfs.ext4 -F "$DISK"
      echo "Formatted $DISK as ext4"
    fi
    mkdir -p /mnt/longhorn
    # Add to fstab for persistence across reboots (nofail prevents boot failure if disk missing)
    if ! grep -q "$(basename $DISK)" /etc/fstab 2>/dev/null; then
      echo "$DISK /mnt/longhorn ext4 defaults,nofail,discard 0 2" >> /etc/fstab
    fi
    mount /mnt/longhorn || mountpoint -q /mnt/longhorn
    echo "Longhorn data volume mounted at /mnt/longhorn"
%{ endif ~}

  # Security: remove secrets from disk after bootstrap completes.
  # Covers cloud-init logs, cached user-data (contains rke2_token), and journal.
  - |
    sleep 10
    truncate -s 0 /var/log/cloud-init-output.log 2>/dev/null || true
    truncate -s 0 /var/log/cloud-init.log 2>/dev/null || true
    rm -f /var/lib/cloud/instance/user-data.txt 2>/dev/null || true
    rm -f /var/lib/cloud/instance/scripts/runcmd 2>/dev/null || true
    journalctl --vacuum-time=1s -u cloud-init 2>/dev/null || true
