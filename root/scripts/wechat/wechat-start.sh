#!/bin/bash

/usr/bin/wechat "$@" >/dev/null 2>&1 &
wechat_pid=$!
if [[ ${ENABLE_WECHAT_AUTO_LOGIN:-true} == true ]]; then
    /usr/bin/python3 /scripts/wechat/wechat-auto-login.py "$wechat_pid" &
fi
wait "$wechat_pid"
