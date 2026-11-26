#!/bin/bash

# The entrypoint generates the initial menu before the window manager reads it.
mkdir -p "$HOME/Desktop"
if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -mq -e close_write,create,delete,moved_from,moved_to \
        --include '\.desktop$' --format '%e' "$HOME/Desktop/" |
        while read -r _; do /scripts/refresh-menu.sh; done >/dev/null &
fi

# start WeChat application in the background if exists and auto-start enabled
if [ "$AUTO_START_WECHAT" = "true" ]; then
    if [ -f /usr/bin/wechat ]; then
        nohup /scripts/wechat/wechat-start.sh &
    fi
fi

# start QQ application in the background if exists and auto-start enabled
if [ "$AUTO_START_QQ" = "true" ]; then
    if [ -f /usr/bin/qq ]; then nohup /usr/bin/qq --no-sandbox > /dev/null 2>&1 & fi
fi

# start WeChat nightly schedule background daemon if enabled
if [ "$ENABLE_WECHAT_NIGHTLY_RESTART" = "true" ]; then
    nohup /scripts/wechat/wechat-nightly-schedule.sh > /dev/null 2>&1 &
fi


# !deprecated: start window switcher application in the background
# start window switcher application in the background
# nohup sleep 2 && python /scripts/window_switcher.py > /dev/null 2>&1 &
