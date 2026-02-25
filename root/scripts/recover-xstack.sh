#!/bin/bash

set -euo pipefail

log() {
    printf '%s [x11-recover] %s\n' "$(date -Iseconds)" "$*"
}

restart_service() {
    local service_name="$1"
    local service_dir="/run/service/${service_name}"
    if [ ! -d "${service_dir}" ]; then
        return
    fi
    log "restart ${service_name}"
    s6-svc -r "${service_dir}" || true
}

restart_service "svc-xorg"
sleep 1
restart_service "svc-xsettingsd"
restart_service "svc-de"
restart_service "svc-selkies"

exit 0
