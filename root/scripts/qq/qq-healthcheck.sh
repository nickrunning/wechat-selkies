#!/bin/bash

set -euo pipefail

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

validate_timeout() {
    if [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 10 ]; then
        echo "$1"
    else
        echo "2"
    fi
}

pids="$(pgrep -f /usr/bin/qq || true)"
if [ -z "$pids" ]; then
    exit 1
fi

has_runnable_pid=0
for pid in $pids; do
    stat_path="/proc/${pid}/stat"
    if [ ! -r "$stat_path" ]; then
        continue
    fi
    state="$(awk '{print $3}' "$stat_path" 2>/dev/null || echo '?')"
    case "$state" in
        Z|X|x|D)
            ;;
        *)
            has_runnable_pid=1
            break
            ;;
    esac
done

if [ "$has_runnable_pid" -ne 1 ]; then
    exit 1
fi

if ! is_true "${QQ_WATCHDOG_X11_PING:-true}"; then
    exit 0
fi

if ! command -v xdotool >/dev/null 2>&1; then
    exit 0
fi

if ! command -v timeout >/dev/null 2>&1; then
    exit 0
fi

display_name="${DISPLAY:-:1}"
window_id="$(DISPLAY="$display_name" xdotool search --onlyvisible --class qq 2>/dev/null | head -n 1 || true)"

# QQ may be starting/minimized with no visible window. Do not treat this as a hang.
if [ -z "$window_id" ]; then
    exit 0
fi

x11_timeout="$(validate_timeout "${QQ_WATCHDOG_X11_TIMEOUT:-2}")"
if timeout "${x11_timeout}"s bash -lc "DISPLAY='${display_name}' xdotool getwindowname '${window_id}' >/dev/null 2>&1"; then
    exit 0
fi

exit 2
