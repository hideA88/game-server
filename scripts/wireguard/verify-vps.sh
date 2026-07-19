#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
ENV_FILE=${1:-"${WIREGUARD_TEMPLATE_DIR}/vps.env"}
load_env_file "${ENV_FILE}"

: "${WG_INTERFACE:=wg0}"
: "${WG_PORT:=51820}"
: "${ENABLED_GAMES:=palworld}"
: "${PORT_RULES_DIR:=${WIREGUARD_TEMPLATE_DIR}/ports.d}"
load_port_rules "${ENABLED_GAMES}" "${PORT_RULES_DIR}"

log "Configured game proxy ports"
print_port_rules
log "WireGuard state"
wg show "${WG_INTERFACE}"
log "IPv4 forwarding"
sysctl net.ipv4.ip_forward
log "Game proxy nftables rules"
nft list table inet game_proxy
log "WireGuard UDP listener"
ss -ulnp | grep -E ":${WG_PORT}\\b" || true
