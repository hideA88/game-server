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
: "${WG_VPS_ADDRESS:=10.77.0.1/30}"
: "${WG_HOME_ADDRESS:=10.77.0.2/32}"
: "${ENABLED_GAMES:=palworld}"
: "${PORT_RULES_DIR:=${WIREGUARD_TEMPLATE_DIR}/ports.d}"
: "${MANAGE_UFW:=false}"

validate_interface WG_INTERFACE
validate_port WG_PORT
validate_ipv4_cidr WG_VPS_ADDRESS
validate_ipv4_cidr WG_HOME_ADDRESS
load_port_rules "${ENABLED_GAMES}" "${PORT_RULES_DIR}"

install_packages
require_command wg
require_command nft

if [[ -z ${VPS_PUBLIC_INTERFACE:-} ]]; then
    VPS_PUBLIC_INTERFACE=$(ip -4 route show default | awk 'NR == 1 { print $5 }')
fi
validate_interface VPS_PUBLIC_INTERFACE
WG_HOME_IP=$(host_ip "${WG_HOME_ADDRESS}")
validate_ipv4 WG_HOME_IP

generate_keypair "${WG_INTERFACE}"
PRIVATE_KEY=$(<"/etc/wireguard/${WG_INTERFACE}.key")

tmp_config=$(mktemp)
trap 'rm -f -- "${tmp_config:-}" "${tmp_nft:-}"' EXIT
render_template \
    "${WIREGUARD_TEMPLATE_DIR}/wg-vps.conf.template" \
    "${tmp_config}" \
    "WG_VPS_ADDRESS=${WG_VPS_ADDRESS}" \
    "WG_PORT=${WG_PORT}" \
    "PRIVATE_KEY=${PRIVATE_KEY}"

if [[ -n ${HOME_PUBLIC_KEY:-} ]]; then
    validate_public_key HOME_PUBLIC_KEY
    cat >>"${tmp_config}" <<PEER

[Peer]
PublicKey = ${HOME_PUBLIC_KEY}
AllowedIPs = ${WG_HOME_ADDRESS}
PEER
fi

configure_ipv4_forwarding

tmp_nft=$(mktemp)
render_nftables_rules "${tmp_nft}"

install -d -m 0755 -o root -g root /etc/nftables.d
backup_file /etc/nftables.d/game-proxy.nft
install -m 0644 -o root -g root "${tmp_nft}" /etc/nftables.d/game-proxy.nft

install -m 0755 -o root -g root \
    "${WIREGUARD_TEMPLATE_DIR}/apply-game-proxy-nftables" \
    /usr/local/sbin/apply-game-proxy-nftables
install -m 0644 -o root -g root \
    "${WIREGUARD_TEMPLATE_DIR}/game-proxy-nftables.service" \
    /etc/systemd/system/game-proxy-nftables.service
systemctl daemon-reload
systemctl enable game-proxy-nftables.service
if systemctl is-active --quiet game-proxy-nftables.service; then
    systemctl restart game-proxy-nftables.service
else
    systemctl start game-proxy-nftables.service
fi

install_wireguard_config "${tmp_config}" "${WG_INTERFACE}"
maybe_configure_ufw_vps

log "VPS bootstrap completed."
log "VPS WireGuard public key: $(<"/etc/wireguard/${WG_INTERFACE}.pub")"
log "Next: put this public key in home.env, run install-home.sh, then put the home public key in vps.env and run configure-vps-peer.sh."
