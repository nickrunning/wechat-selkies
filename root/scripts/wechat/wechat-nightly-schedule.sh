#!/bin/bash

if [ "$ENABLE_WECHAT_NIGHTLY_RESTART" != "true" ]; then
    exit 0
fi

STOP_TIME="${WECHAT_NIGHTLY_STOP_TIME:-23:30}"
START_TIME="${WECHAT_NIGHTLY_START_TIME:-01:30}"


echo "⏰ WeChat nightly restart service enabled. Stop time: $STOP_TIME, Start time: $START_TIME"

get_next_timestamp() {
    local target_time="$1"
    if [[ "$target_time" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        target_time="${target_time}:00"
    fi

    local now_ts=$(date +%s)
    local today_str=$(date +%Y-%m-%d)
    local target_ts=$(date -d "$today_str $target_time" +%s 2>/dev/null)
    if [ -z "$target_ts" ]; then
        echo ""
        return
    fi
    if [ "$target_ts" -le "$now_ts" ]; then
        target_ts=$((target_ts + 86400))
    fi
    echo "$target_ts"
}


while true; do
    NOW_TS=$(date +%s)
    STOP_TS=$(get_next_timestamp "$STOP_TIME")
    
    if [ -z "$STOP_TS" ]; then
        echo "❌ Invalid WECHAT_NIGHTLY_STOP_TIME format: $STOP_TIME. Service exiting."
        exit 1
    fi
    
    SLEEP_TO_STOP=$((STOP_TS - NOW_TS))
    echo "💤 Sleeping $SLEEP_TO_STOP seconds until next stop time ($STOP_TIME)..."
    sleep "$SLEEP_TO_STOP"
    
    echo "🛑 Nightly scheduled stop: stopping WeChat..."
    /scripts/wechat/wechat-stop.sh
    
    NOW_TS=$(date +%s)
    START_TS=$(get_next_timestamp "$START_TIME")
    if [ -z "$START_TS" ]; then
        echo "❌ Invalid WECHAT_NIGHTLY_START_TIME format: $START_TIME."
        sleep 60
        continue
    fi
    
    SLEEP_TO_START=$((START_TS - NOW_TS))
    echo "💤 Sleeping $SLEEP_TO_START seconds until next start time ($START_TIME)..."
    sleep "$SLEEP_TO_START"
    
    echo "🚀 Nightly scheduled restart: starting WeChat..."
    if [ -f /usr/bin/wechat ]; then
        nohup /usr/bin/wechat > /dev/null 2>&1 &
    fi
done
