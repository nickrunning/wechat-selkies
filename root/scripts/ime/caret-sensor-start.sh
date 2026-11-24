#!/bin/bash

# English-only, panel-less IBus runs purely as a caret sensor: the remote
# application reports its caret to IBus, and caret-bridge.py forwards that
# position to the web client. Chinese composition stays with the host IME.

[ "${ENABLE_IBUS_CARET_SENSOR:-true}" = "true" ] || exit 0
command -v ibus-daemon >/dev/null 2>&1 || exit 0

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

if ! pgrep -u "$(id -u)" -x ibus-daemon >/dev/null 2>&1; then
    ibus-daemon -drx --panel=disable >/dev/null 2>&1 || true
fi

# Wait for the daemon's private bus address file.
for _ in $(seq 1 40); do
    if grep -h '^IBUS_ADDRESS=' "$HOME"/.config/ibus/bus/* 2>/dev/null | head -1 >/dev/null; then
        break
    fi
    sleep 0.25
done

# Keep the sensor on the plain keyboard engine. No pinyin, no candidates.
# The engine list may still be loading right after daemon start.
for _ in $(seq 1 40); do
    ibus engine xkb:us::eng >/dev/null 2>&1 || true
    if [ "$(ibus engine 2>/dev/null)" = "xkb:us::eng" ]; then
        break
    fi
    sleep 0.25
done

PYTHON_BIN="$(command -v python3 2>/dev/null || true)"
# Prefer the Selkies virtualenv interpreter, which ships aiohttp for the WS.
if [ -x /lsiopy/bin/python3 ] && /lsiopy/bin/python3 -c 'import aiohttp' >/dev/null 2>&1; then
    PYTHON_BIN=/lsiopy/bin/python3
fi

bridge_running() {
    for pid in $(pgrep -x python3 2>/dev/null); do
        if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q "scripts/ime/caret-bridge.py"; then
            return 0
        fi
    done
    return 1
}

if [ -n "$PYTHON_BIN" ] && [ -f /scripts/ime/caret-bridge.py ]; then
    if ! bridge_running; then
        nohup "$PYTHON_BIN" /scripts/ime/caret-bridge.py >/dev/null 2>&1 &
    fi
fi