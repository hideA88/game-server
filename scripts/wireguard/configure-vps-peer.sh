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

require_var HOME_PUBLIC_KEY
validate_interface WG_INTERFACE
validate_port WG_PORT
validate_ipv4_cidr WG_VPS_ADDRESS
validate_ipv4_cidr WG_HOME_ADDRESS
validate_public_key HOME_PUBLIC_KEY
[[ -s /etc/wireguard/${WG_INTERFACE}.key ]] || die "Run install-vps.sh first."

PRIVATE_KEY=$(<"/etc/wireguard/${WG_INTERFACE}.key")
tmp_config=$(mktemp)
trap 'rm -f -- "${tmp_config:-}"' EXIT

render_template \
    "${WIREGUARD_TEMPLATE_DIR}/wg-vps.conf.template" \
    "${tmp_config}" \
    "WG_VPS_ADDRESS=${WG_VPS_ADDRESS}" \
    "WG_PORT=${WG_PORT}" \
    "PRIVATE_KEY=${PRIVATE_KEY}"

cat >>"${tmp_config}" <<PEER

[Peer]
PublicKey = ${HOME_PUBLIC_KEY}
AllowedIPs = ${WG_HOME_ADDRESS}
PEER

install_wireguard_config "${tmp_config}" "${WG_INTERFACE}"
log "Configured the home peer on the VPS."
wg show "${WG_INTERFACE}"
