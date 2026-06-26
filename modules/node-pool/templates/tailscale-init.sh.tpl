#!/bin/bash
# Tailscale node-level installer — sourced by cloud-init runcmd snippets.
# Not used directly; imported as a fragment in cp-init.yaml.tpl and worker-init.yaml.tpl.
#
# Security notes:
# - Uses --accept-routes: required for Tailscale subnet routing
# - Auth key is reusable (not one-time-use — shared across pool nodes)
# - Key is injected via cloud-init at provision time; cloud metadata APIs may expose
#   user_data — block 169.254.169.254 via CiliumClusterwideNetworkPolicy post-bootstrap

set -euo pipefail

TAILSCALE_AUTH_KEY="${tailscale_auth_key}"
HOSTNAME="${hostname}"

curl -fsSL https://tailscale.com/install.sh | sh

tailscale up \
  --auth-key="$TAILSCALE_AUTH_KEY" \
  --hostname="$HOSTNAME" \
  --accept-routes \
  2>&1

echo "Tailscale enrolled as $HOSTNAME"
