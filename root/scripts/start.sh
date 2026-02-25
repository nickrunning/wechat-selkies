#!/bin/bash

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

start_wechat() {
    if [ -x /usr/bin/wechat ]; then
        nohup /usr/bin/wechat >/dev/null 2>&1 &
    fi
}

start_qq() {
    if [ -x /usr/bin/qq ]; then
        nohup /scripts/qq/qq-launch.sh >/dev/null 2>&1 &
    fi
}

start_tray() {
    if ! pgrep -x stalonetray >/dev/null 2>&1; then
        nohup stalonetray --dockapp-mode simple >/dev/null 2>&1 &
    fi
}

start_split_fab() {
    if ! pgrep -f "/scripts/split_fab.py" >/dev/null 2>&1; then
        SPLIT_FAB_LOG_PATH="${SPLIT_FAB_LOG_PATH:-/config/logs/split-fab.log}"
        mkdir -p "$(dirname "$SPLIT_FAB_LOG_PATH")"
        nohup python3 /scripts/split_fab.py >>"$SPLIT_FAB_LOG_PATH" 2>&1 &
    fi
}

start_wechat_keepalive() {
    if ! pgrep -af "/scripts/wechat/wechat-idle-keepalive.sh" >/dev/null 2>&1; then
        WECHAT_KEEPALIVE_LOG_PATH="${WECHAT_KEEPALIVE_LOG_PATH:-/config/logs/wechat-idle-keepalive.log}"
        mkdir -p "$(dirname "$WECHAT_KEEPALIVE_LOG_PATH")"
        nohup /scripts/wechat/wechat-idle-keepalive.sh >>"$WECHAT_KEEPALIVE_LOG_PATH" 2>&1 &
    fi
}

reconfigure_openbox() {
    openbox --reconfigure >/dev/null 2>&1 || true
}

patch_openbox_right_click_menu() {
    local target_menu="client-menu"
    if is_true "${ENABLE_RIGHT_CLICK_SPLIT:-true}"; then
        target_menu="window-right-click-menu"
    fi

    if [ -f /config/.config/openbox/rc.xml ]; then
        local result=""
        if result=$(python3 /scripts/patch_openbox_rc.py /config/.config/openbox/rc.xml --target-menu-id "$target_menu" 2>/tmp/patch-openbox-rc.err); then
            if [ "$result" = "changed" ]; then
                reconfigure_openbox
            fi
        else
            echo "[start] patch_openbox_rc failed: $(cat /tmp/patch-openbox-rc.err)" >&2
        fi
        rm -f /tmp/patch-openbox-rc.err
    fi
}

# configure openbox dock mode for stalonetray
if [ ! -f /config/.config/openbox/rc.xml ] || grep -A20 "<dock>" /config/.config/openbox/rc.xml | grep -q "<noStrut>no</noStrut>"; then
    mkdir -p /config/.config/openbox
    [ ! -f /config/.config/openbox/rc.xml ] && cp /etc/xdg/openbox/rc.xml /config/.config/openbox/
    sed -i '/<dock>/,/<\/dock>/s/<noStrut>no<\/noStrut>/<noStrut>yes<\/noStrut>/' /config/.config/openbox/rc.xml
    reconfigure_openbox
fi

# update openbox menu if differs from default
if [ ! -f /config/.config/openbox/menu.xml ] || ! cmp /defaults/menu.xml /config/.config/openbox/menu.xml; then
    mkdir -p /config/.config/openbox
    cp /defaults/menu.xml /config/.config/openbox/menu.xml
    reconfigure_openbox
fi

patch_openbox_right_click_menu

start_tray

# start WeChat application in the background if exists and auto-start enabled
if is_true "${AUTO_START_WECHAT:-true}"; then
    start_wechat
fi

# start QQ application in the background if exists and auto-start enabled
if is_true "${AUTO_START_QQ:-false}"; then
    start_qq
fi

# launch process watchdog for long-running stability
if is_true "${PROCESS_WATCHDOG:-true}"; then
    WATCHDOG_LOG_PATH="${WATCHDOG_LOG_PATH:-/config/logs/process-watchdog.log}"
    mkdir -p "$(dirname "$WATCHDOG_LOG_PATH")"
    nohup /scripts/process-watchdog.sh >>"$WATCHDOG_LOG_PATH" 2>&1 &
fi

# periodically poke WeChat only when session is idle to reduce overnight logout probability
if is_true "${WECHAT_IDLE_KEEPALIVE:-true}"; then
    start_wechat_keepalive
fi

# start split FAB process for quick left/right tiling when there are >=2 windows
if is_true "${ENABLE_SPLIT_FAB:-true}"; then
    start_split_fab
fi

# !deprecated: start window switcher application in the background
# start window switcher application in the background
# nohup sleep 2 && python /scripts/window_switcher.py > /dev/null 2>&1 &
