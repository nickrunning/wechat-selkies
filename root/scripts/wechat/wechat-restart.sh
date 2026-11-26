#!/bin/bash
pkill -9 -f /usr/bin/wechat 2>/dev/null
nohup /scripts/wechat/wechat-start.sh &
