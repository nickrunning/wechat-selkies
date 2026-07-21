#!/bin/bash
# Stop WeChat gracefully: SIGTERM first, wait 5s, then SIGKILL if still running
if pgrep -f /usr/bin/wechat >/dev/null 2>&1; then
    echo "Sending SIGTERM to WeChat..."
    pkill -15 -f /usr/bin/wechat 2>/dev/null
    sleep 5
    if pgrep -f /usr/bin/wechat >/dev/null 2>&1; then
        echo "WeChat still running, sending SIGKILL..."
        pkill -9 -f /usr/bin/wechat 2>/dev/null
    fi
fi
