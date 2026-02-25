#!/bin/bash

set -euo pipefail

pkill -TERM -f /usr/bin/qq 2>/dev/null || true

for _ in 1 2 3 4 5; do
    if ! pgrep -f /usr/bin/qq >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if pgrep -f /usr/bin/qq >/dev/null 2>&1; then
    pkill -KILL -f /usr/bin/qq 2>/dev/null || true
fi

nohup /scripts/qq/qq-launch.sh >/dev/null 2>&1 &
