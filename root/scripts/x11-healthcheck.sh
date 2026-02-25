#!/bin/bash

set -euo pipefail

validate_timeout() {
    if [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 10 ]; then
        echo "$1"
    else
        echo "2"
    fi
}

if ! command -v xrandr >/dev/null 2>&1; then
    exit 0
fi

if ! command -v timeout >/dev/null 2>&1; then
    exit 0
fi

display_name="${DISPLAY:-:1}"
timeout_s="$(validate_timeout "${X11_HEALTHCHECK_TIMEOUT:-2}")"
err_file="$(mktemp)"

if timeout "${timeout_s}"s bash -lc "DISPLAY='${display_name}' xrandr --current >/dev/null" 2>"${err_file}"; then
    rm -f "${err_file}"
    exit 0
fi

err_text="$(cat "${err_file}" 2>/dev/null || true)"
rm -f "${err_file}"

if echo "${err_text}" | grep -qi "Maximum number of clients reached"; then
    exit 2
fi

if echo "${err_text}" | grep -qi "Can't open display"; then
    exit 3
fi

exit 1
