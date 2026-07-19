#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

ENV_FILE=${1:-"${WIREGUARD_TEMPLATE_DIR}/vps.env"}
load_env_file "${ENV_FILE}"
: "${ENABLED_GAMES:=palworld}"
: "${PORT_RULES_DIR:=${WIREGUARD_TEMPLATE_DIR}/ports.d}"

load_port_rules "${ENABLED_GAMES}" "${PORT_RULES_DIR}"
print_port_rules
