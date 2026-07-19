#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
ENV_FILE=${1:-"${WIREGUARD_TEMPLATE_DIR}/home.env"}
load_env_file "${ENV_FILE}"

: "${WG_INTERFACE:=wg0}"
: "${WG_HOME_ADDRESS:=10.77.0.2/30}"
: "${WG_VPS_ADDRESS:=10.77.0.1/32}"
: "${WG_PORT:=51820}"
: "${WG_MTU:=1380}"
: "${ENABLED_GAMES:=palworld}"
: "${PORT_RULES_DIR:=${WIREGUARD_TEMPLATE_DIR}/ports.d}"
: "${MANAGE_UFW:=false}"

require_var VPS_PUBLIC_IP
require_var VPS_PUBLIC_KEY
validate_interface WG_INTERFACE
validate_port WG_PORT
validate_ipv4_cidr WG_HOME_ADDRESS
validate_ipv4_cidr WG_VPS_ADDRESS
validate_ipv4 VPS_PUBLIC_IP
validate_public_key VPS_PUBLIC_KEY
[[ ${WG_MTU} =~ ^[0-9]+$ ]] || die "WG_MTU must be numeric."
(( WG_MTU >= 1280 && WG_MTU <= 1420 )) || die "WG_MTU must be between 1280 and 1420."
load_port_rules "${ENABLED_GAMES}" "${PORT_RULES_DIR}"

install_packages
require_command wg
configure_ipv4_forwarding
generate_keypair "${WG_INTERFACE}"
PRIVATE_KEY=$(<"/etc/wireguard/${WG_INTERFACE}.key")

tmp_config=$(mktemp)
trap 'rm -f -- "${tmp_config:-}"' EXIT
render_template \
    "${WIREGUARD_TEMPLATE_DIR}/wg-home.conf.template" \
    "${tmp_config}" \
    "WG_HOME_ADDRESS=${WG_HOME_ADDRESS}" \
    "PRIVATE_KEY=${PRIVATE_KEY}" \
    "WG_MTU=${WG_MTU}" \
    "VPS_PUBLIC_KEY=${VPS_PUBLIC_KEY}" \
    "VPS_PUBLIC_IP=${VPS_PUBLIC_IP}" \
    "WG_PORT=${WG_PORT}" \
    "WG_VPS_ADDRESS=${WG_VPS_ADDRESS}"

install_wireguard_config "${tmp_config}" "${WG_INTERFACE}"
maybe_configure_ufw_home

log "Home game-server setup completed."
log "Home WireGuard public key: $(<"/etc/wireguard/${WG_INTERFACE}.pub")"
log "Put this public key in HOME_PUBLIC_KEY in vps.env and run configure-vps-peer.sh on the VPS."
