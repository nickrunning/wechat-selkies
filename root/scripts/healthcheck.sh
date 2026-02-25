#!/bin/bash

set -euo pipefail

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

if ! pgrep -x openbox >/dev/null 2>&1; then
    echo "openbox process missing"
    exit 1
fi

if is_true "${PROCESS_WATCHDOG:-true}"; then
    if ! pgrep -af "/scripts/process-watchdog.sh" >/dev/null 2>&1; then
        echo "watchdog process missing"
        exit 1
    fi
fi

if is_true "${AUTO_START_WECHAT:-true}" && is_true "${WATCHDOG_RESTART_WECHAT:-true}"; then
    if ! pgrep -af "/usr/bin/wechat" >/dev/null 2>&1; then
        echo "wechat process missing"
        exit 1
    fi
fi

if is_true "${AUTO_START_QQ:-false}" && is_true "${WATCHDOG_RESTART_QQ:-true}"; then
    if ! pgrep -af "/usr/bin/qq" >/dev/null 2>&1; then
        echo "qq process missing"
        exit 1
    fi
fi

if is_true "${WECHAT_IDLE_KEEPALIVE:-true}"; then
    if ! pgrep -af "/scripts/wechat/wechat-idle-keepalive.sh" >/dev/null 2>&1; then
        echo "wechat idle keepalive process missing"
        exit 1
    fi
fi

exit 0
