#!/usr/bin/env bash

set -Eeuo pipefail

WIREGUARD_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WIREGUARD_REPO_ROOT="$(cd -- "${WIREGUARD_SCRIPT_DIR}/../.." && pwd)"
WIREGUARD_TEMPLATE_DIR="${WIREGUARD_REPO_ROOT}/infra/wireguard"

log() {
    printf '[wireguard-setup] %s\n' "$*"
}

die() {
    printf '[wireguard-setup] ERROR: %s\n' "$*" >&2
    exit 1
}

require_root() {
    [[ ${EUID} -eq 0 ]] || die "Run this script with sudo."
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

load_env_file() {
    local env_file=$1
    [[ -f ${env_file} ]] || die "Environment file not found: ${env_file}"
    # The env file is an administrator-owned local configuration file.
    # shellcheck disable=SC1090
    source "${env_file}"
}

require_var() {
    local name=$1
    [[ -n ${!name:-} ]] || die "Required variable is empty: ${name}"
}

validate_port() {
    local name=$1
    validate_port_value "${name}" "${!name:-}"
}

validate_port_value() {
    local label=$1
    local value=$2
    [[ ${value} =~ ^[0-9]+$ ]] || die "${label} must be a numeric port."
    (( value >= 1 && value <= 65535 )) || die "${label} must be between 1 and 65535."
}

validate_interface() {
    local name=$1
    local value=${!name:-}
    [[ ${value} =~ ^[a-zA-Z0-9_.-]+$ ]] || die "${name} is not a valid interface name."
}

validate_ipv4() {
    local name=$1
    local value=${!name:-}
    local octet
    local -a octets=()

    [[ ${value} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "${name} must be an IPv4 address."
    IFS='.' read -r -a octets <<<"${value}"
    for octet in "${octets[@]}"; do
        (( 10#${octet} <= 255 )) || die "${name} must be an IPv4 address."
    done
}

validate_ipv4_cidr() {
    local name=$1
    local value=${!name:-}
    local address=${value%/*}
    local prefix=${value#*/}
    [[ ${value} == */* && ${prefix} =~ ^([0-9]|[12][0-9]|3[0-2])$ ]] \
        || die "${name} must be an IPv4 CIDR."
    validate_ipv4 address
}

validate_public_key() {
    local name=$1
    local value=${!name:-}
    [[ ${value} =~ ^[A-Za-z0-9+/]{43}=$ ]] || die "${name} is not a WireGuard public key."
}

bool_is_true() {
    [[ ${1,,} == true ]]
}

host_ip() {
    printf '%s\n' "${1%%/*}"
}

declare -ag PROXY_GAMES=()
declare -ag PROXY_PROTOCOLS=()
declare -ag PROXY_PUBLIC_PORTS=()
declare -ag PROXY_HOME_PORTS=()
declare -ag PROXY_PURPOSES=()

load_port_rules() {
    local enabled_games=$1
    local rules_dir=$2
    local game protocol public_port home_port purpose extra port_key
    local rules_file
    local -a games=()
    local -A seen_public=()

    PROXY_GAMES=()
    PROXY_PROTOCOLS=()
    PROXY_PUBLIC_PORTS=()
    PROXY_HOME_PORTS=()
    PROXY_PURPOSES=()

    IFS=',' read -r -a games <<<"${enabled_games}"
    for game in "${games[@]}"; do
        game=${game//[[:space:]]/}
        [[ ${game} =~ ^[a-zA-Z0-9_.-]+$ ]] || die "Invalid game name in ENABLED_GAMES: ${game}"
        rules_file="${rules_dir}/${game}.ports"
        [[ -f ${rules_file} ]] || die "Port rules not found for ${game}: ${rules_file}"

        while read -r protocol public_port home_port purpose extra; do
            [[ -z ${protocol:-} || ${protocol:0:1} == '#' ]] && continue
            [[ -z ${extra:-} ]] || die "Too many fields in ${rules_file}: ${protocol} ${public_port} ${home_port} ${purpose} ${extra}"
            [[ ${protocol} == udp || ${protocol} == tcp ]] || die "Protocol must be udp or tcp in ${rules_file}."
            validate_port_value "${game} public_port" "${public_port}"
            validate_port_value "${game} home_port" "${home_port}"
            [[ ${purpose} =~ ^[a-zA-Z0-9_.:-]+$ ]] || die "Invalid purpose in ${rules_file}: ${purpose}"
            port_key="${protocol}:${public_port}"
            [[ -z ${seen_public[${port_key}]:-} ]] \
                || die "Duplicate VPS port ${port_key} in ${game} and ${seen_public[${port_key}]}"
            seen_public[${port_key}]=${game}

            PROXY_GAMES+=("${game}")
            PROXY_PROTOCOLS+=("${protocol}")
            PROXY_PUBLIC_PORTS+=("${public_port}")
            PROXY_HOME_PORTS+=("${home_port}")
            PROXY_PURPOSES+=("${purpose}")
        done <"${rules_file}"
    done

    (( ${#PROXY_GAMES[@]} > 0 )) || die "No game proxy ports were loaded."
}

print_port_rules() {
    local index
    printf '%-12s %-8s %-12s %-10s %s\n' GAME PROTOCOL VPS_PORT HOME_PORT PURPOSE
    for index in "${!PROXY_GAMES[@]}"; do
        printf '%-12s %-8s %-12s %-10s %s\n' \
            "${PROXY_GAMES[index]}" \
            "${PROXY_PROTOCOLS[index]}" \
            "${PROXY_PUBLIC_PORTS[index]}" \
            "${PROXY_HOME_PORTS[index]}" \
            "${PROXY_PURPOSES[index]}"
    done
}

render_nftables_rules() {
    local destination=$1
    local index game protocol public_port home_port purpose

    cat >"${destination}" <<NFT_HEADER
table inet game_proxy {
    chain forward {
        type filter hook forward priority -10; policy accept;
NFT_HEADER

    for index in "${!PROXY_GAMES[@]}"; do
        game=${PROXY_GAMES[index]}
        protocol=${PROXY_PROTOCOLS[index]}
        home_port=${PROXY_HOME_PORTS[index]}
        purpose=${PROXY_PURPOSES[index]}
        printf '        iifname "%s" oifname "%s" ip daddr %s %s dport %s ct state new,established counter comment "%s: %s" accept\n' \
            "${VPS_PUBLIC_INTERFACE}" "${WG_INTERFACE}" "${WG_HOME_IP}" "${protocol}" "${home_port}" "${game}" "${purpose}" \
            >>"${destination}"
    done

    cat >>"${destination}" <<NFT_MIDDLE
        iifname "${WG_INTERFACE}" oifname "${VPS_PUBLIC_INTERFACE}" ip saddr ${WG_HOME_IP} ct state established,related counter accept
    }

    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
NFT_MIDDLE

    for index in "${!PROXY_GAMES[@]}"; do
        game=${PROXY_GAMES[index]}
        protocol=${PROXY_PROTOCOLS[index]}
        public_port=${PROXY_PUBLIC_PORTS[index]}
        home_port=${PROXY_HOME_PORTS[index]}
        purpose=${PROXY_PURPOSES[index]}
        printf '        iifname "%s" %s dport %s counter comment "%s: %s" dnat ip to %s:%s\n' \
            "${VPS_PUBLIC_INTERFACE}" "${protocol}" "${public_port}" "${game}" "${purpose}" "${WG_HOME_IP}" "${home_port}" \
            >>"${destination}"
    done

    cat >>"${destination}" <<NFT_MIDDLE
    }

    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
NFT_MIDDLE

    for index in "${!PROXY_GAMES[@]}"; do
        game=${PROXY_GAMES[index]}
        protocol=${PROXY_PROTOCOLS[index]}
        home_port=${PROXY_HOME_PORTS[index]}
        purpose=${PROXY_PURPOSES[index]}
        printf '        oifname "%s" ip daddr %s %s dport %s counter comment "%s: %s" masquerade\n' \
            "${WG_INTERFACE}" "${WG_HOME_IP}" "${protocol}" "${home_port}" "${game}" "${purpose}" \
            >>"${destination}"
    done

    printf '    }\n}\n' >>"${destination}"
}

backup_file() {
    local path=$1
    if [[ -e ${path} ]]; then
        local backup="${path}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
        cp -a -- "${path}" "${backup}"
        log "Backed up ${path} to ${backup}"
    fi
}

install_packages() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y wireguard wireguard-tools nftables
}

configure_ipv4_forwarding() {
    local sysctl_file=/etc/sysctl.d/70-game-proxy-routing.conf

    backup_file "${sysctl_file}"
    install -m 0644 -o root -g root /dev/stdin "${sysctl_file}" <<'SYSCTL'
net.ipv4.ip_forward = 1
SYSCTL
    sysctl -p "${sysctl_file}"
}

generate_keypair() {
    local prefix=$1
    local private_key="/etc/wireguard/${prefix}.key"
    local public_key="/etc/wireguard/${prefix}.pub"

    install -d -m 0700 -o root -g root /etc/wireguard
    if [[ ! -s ${private_key} ]]; then
        umask 077
        wg genkey >"${private_key}"
        chmod 0600 "${private_key}"
        log "Generated ${private_key}"
    fi
    wg pubkey <"${private_key}" >"${public_key}"
    chmod 0644 "${public_key}"
}

render_template() {
    local source=$1
    local destination=$2
    shift 2

    local sed_args=()
    local replacement
    for replacement in "$@"; do
        sed_args+=( -e "s|__${replacement%%=*}__|${replacement#*=}|g" )
    done
    sed "${sed_args[@]}" "${source}" >"${destination}"
}

install_wireguard_config() {
    local rendered=$1
    local interface=$2
    local destination="/etc/wireguard/${interface}.conf"

    backup_file "${destination}"
    install -m 0600 -o root -g root "${rendered}" "${destination}"
    systemctl enable "wg-quick@${interface}"
    if systemctl is-active --quiet "wg-quick@${interface}"; then
        systemctl restart "wg-quick@${interface}"
    else
        systemctl start "wg-quick@${interface}"
    fi
}

maybe_configure_ufw_vps() {
    if ! bool_is_true "${MANAGE_UFW:-false}"; then
        return
    fi
    local index
    require_command ufw
    ufw allow "${WG_PORT}/udp" comment 'WireGuard game tunnel'
    for index in "${!PROXY_GAMES[@]}"; do
        ufw allow "${PROXY_PUBLIC_PORTS[index]}/${PROXY_PROTOCOLS[index]}" \
            comment "${PROXY_GAMES[index]} ${PROXY_PURPOSES[index]} proxy"
        ufw route allow in on "${VPS_PUBLIC_INTERFACE}" out on "${WG_INTERFACE}" \
            to "${WG_HOME_IP}" port "${PROXY_HOME_PORTS[index]}" proto "${PROXY_PROTOCOLS[index]}"
    done
}

maybe_configure_ufw_home() {
    if ! bool_is_true "${MANAGE_UFW:-false}"; then
        return
    fi
    local index
    require_command ufw
    for index in "${!PROXY_GAMES[@]}"; do
        # Docker-published ports are DNATed before filtering and traverse FORWARD.
        ufw route allow in on "${WG_INTERFACE}" from "${WG_VPS_ADDRESS}" \
            to any port "${PROXY_HOME_PORTS[index]}" proto "${PROXY_PROTOCOLS[index]}" \
            comment "${PROXY_GAMES[index]} ${PROXY_PURPOSES[index]} from VPS"
    done
}
