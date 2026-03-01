#!/bin/bash

set -euo pipefail

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

validate_interval() {
    if [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 30 ]; then
        echo "$1"
    else
        echo "1800"
    fi
}

validate_idle_seconds() {
    if [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 60 ]; then
        echo "$1"
    else
        echo "1800"
    fi
}

log() {
    printf '%s [wechat-keepalive] %s\n' "$(date -Iseconds)" "$*"
}

get_wechat_window() {
    local wid=""
    wid="$(xdotool search --onlyvisible --class wechat 2>/dev/null | head -n 1 || true)"
    if [ -z "$wid" ]; then
        wid="$(xdotool search --onlyvisible --name '微信（测试版）|WeChat Beta|WeChat' 2>/dev/null | head -n 1 || true)"
    fi
    echo "$wid"
}

interval="$(validate_interval "${WECHAT_KEEPALIVE_INTERVAL:-1800}")"
idle_seconds="$(validate_idle_seconds "${WECHAT_KEEPALIVE_IDLE_SECONDS:-1800}")"
idle_threshold_ms=$((idle_seconds * 1000))

if ! command -v xdotool >/dev/null 2>&1; then
    log "xdotool not found, exit"
    exit 0
fi

exec 8>/tmp/wechat-idle-keepalive.lock
if ! flock -n 8; then
    log "already running, exit"
    exit 0
fi

log "started interval=${interval}s idle_threshold=${idle_seconds}s"

while true; do
    if ! is_true "${WECHAT_IDLE_KEEPALIVE:-true}"; then
        sleep "$interval"
        continue
    fi

    if ! pgrep -af "/usr/bin/wechat" >/dev/null 2>&1; then
        sleep "$interval"
        continue
    fi

    idle_ms=999999999
    if command -v xprintidle >/dev/null 2>&1; then
        idle_raw="$(xprintidle 2>/dev/null || echo 0)"
        if [[ "$idle_raw" =~ ^[0-9]+$ ]]; then
            idle_ms="$idle_raw"
        fi
    fi

    if [ "$idle_ms" -lt "$idle_threshold_ms" ]; then
        sleep "$interval"
        continue
    fi

    current_wid="$(xdotool getactivewindow 2>/dev/null || true)"
    wechat_wid="$(get_wechat_window)"

    if [ -n "$wechat_wid" ]; then
        xdotool windowactivate --sync "$wechat_wid" >/dev/null 2>&1 || true
        # Shift key press/release is harmless and can refresh app activity state.
        xdotool key --window "$wechat_wid" Shift_L >/dev/null 2>&1 || true
        if [ -n "$current_wid" ] && [ "$current_wid" != "$wechat_wid" ]; then
            xdotool windowactivate --sync "$current_wid" >/dev/null 2>&1 || true
        fi
        log "keepalive tick idle_ms=${idle_ms} wechat_wid=${wechat_wid}"
    fi

    sleep "$interval"
done
