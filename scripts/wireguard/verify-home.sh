#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
ENV_FILE=${1:-"${WIREGUARD_TEMPLATE_DIR}/home.env"}
load_env_file "${ENV_FILE}"

: "${WG_INTERFACE:=wg0}"
: "${WG_VPS_ADDRESS:=10.77.0.1/32}"
: "${ENABLED_GAMES:=palworld}"
: "${PORT_RULES_DIR:=${WIREGUARD_TEMPLATE_DIR}/ports.d}"
load_port_rules "${ENABLED_GAMES}" "${PORT_RULES_DIR}"

WG_VPS_IP=$(host_ip "${WG_VPS_ADDRESS}")
log "Configured game proxy ports"
print_port_rules
log "WireGuard state"
wg show "${WG_INTERFACE}"
log "Tunnel address and route"
ip address show dev "${WG_INTERFACE}"
ip route show dev "${WG_INTERFACE}"
log "Ping VPS tunnel address"
ping -c 3 -W 2 "${WG_VPS_IP}"

log "Game port listeners on the home server"
missing_listeners=0
for index in "${!PROXY_GAMES[@]}"; do
    printf '%s %s/%s (%s): ' \
        "${PROXY_GAMES[index]}" \
        "${PROXY_HOME_PORTS[index]}" \
        "${PROXY_PROTOCOLS[index]}" \
        "${PROXY_PURPOSES[index]}"
    if [[ ${PROXY_PROTOCOLS[index]} == udp ]]; then
        listener_output=$(ss -H -ulnp)
    else
        listener_output=$(ss -H -lntp)
    fi
    if matching_listeners=$(grep -E ":${PROXY_HOME_PORTS[index]}([[:space:]]|$)" <<<"${listener_output}"); then
        printf '%s\n' "${matching_listeners}"
    else
        printf 'NOT LISTENING\n'
        ((missing_listeners += 1))
    fi
done

(( missing_listeners == 0 )) \
    || die "${missing_listeners} configured game port(s) are not listening on the home server."

if command -v docker >/dev/null 2>&1; then
    log "Running Docker containers"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
fi
