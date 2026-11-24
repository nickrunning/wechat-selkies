#!/usr/bin/env python3
"""Forward the application caret position reported to IBus.

The web client cannot know the remote caret. The application itself reports
it to its input context (IBus) on focus and caret changes. This bridge reads
those IBus D-Bus messages and writes the latest screen-pixel caret rect plus
the active X11 window position to a small JSON file served to the web client.

The caret coordinates are relative to the window at report time. The window
position is refreshed continuously so the client can shift the caret while a
window is being dragged. This runs an English-only, panel-less IBus daemon
purely as a caret sensor; Chinese composition stays with the host IME.
"""

import glob
import json
import os
import re
import subprocess
import sys
import threading
import time

OUT = os.environ.get("IME_CARET_JSON", "/config/ime-caret.json")
CURSOR_RE = re.compile(r"member=SetCursorLocation")
FOCUS_IN_RE = re.compile(r"member=FocusIn")
FOCUS_OUT_RE = re.compile(r"member=FocusOut")
INPUT_CONTEXT_RE = re.compile(r"interface=org\.freedesktop\.IBus\.InputContext")
PATH_RE = re.compile(r"path=(/org/freedesktop/IBus/InputContext_\d+)")
INT_RE = re.compile(r"int32\s+(-?\d+)")

STATE_LOCK = threading.Lock()
STATE = {
    "x": 0,
    "y": 0,
    "w": 0,
    "h": 0,
    "ct": 0,
    "wid": "",
    "wx": 0,
    "wy": 0,
}


def ibus_address():
    patterns = [
        os.path.expanduser("~/.config/ibus/bus/*"),
        "/config/.config/ibus/bus/*",
    ]
    paths = []
    for pattern in patterns:
        paths.extend(glob.glob(pattern))
    paths.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    for path in paths:
        try:
            with open(path, "r", errors="ignore") as handle:
                for line in handle:
                    if line.startswith("IBUS_ADDRESS="):
                        return line.strip().split("=", 1)[1]
        except OSError:
            continue
    return os.environ.get("IBUS_ADDRESS")


def active_window():
    env = dict(os.environ)
    env.setdefault("DISPLAY", ":1")
    try:
        wid = subprocess.check_output(
            ["xdotool", "getactivewindow"], env=env, stderr=subprocess.DEVNULL
        ).decode().strip()
        if not wid:
            return None
        out = subprocess.check_output(
            ["xdotool", "getwindowgeometry", "--shell", wid],
            env=env,
            stderr=subprocess.DEVNULL,
        ).decode()
        values = {}
        for line in out.splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
        return {
            "wid": wid,
            "x": int(values.get("X", 0)),
            "y": int(values.get("Y", 0)),
            "w": int(values.get("WIDTH", 0)),
            "h": int(values.get("HEIGHT", 0)),
        }
    except Exception:
        return None


def monitor(address):
    proc = subprocess.Popen(
        ["stdbuf", "-oL", "dbus-monitor", "--address", address],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    pending = False
    pending_path = None
    active_path = None
    values = []
    try:
        for line in proc.stdout:
            if INPUT_CONTEXT_RE.search(line):
                path_match = PATH_RE.search(line)
                path = path_match.group(1) if path_match else None
                if FOCUS_IN_RE.search(line):
                    active_path = path
                    pending = False
                    values = []
                    continue
                if FOCUS_OUT_RE.search(line):
                    if active_path == path:
                        active_path = None
                    pending = False
                    values = []
                    continue
                if CURSOR_RE.search(line):
                    pending = True
                    pending_path = path
                    values = []
                    continue
            if not pending:
                continue
            match = INT_RE.search(line)
            if match:
                values.append(int(match.group(1)))
                if len(values) == 4:
                    if active_path is None or pending_path == active_path:
                        window = active_window()
                        with STATE_LOCK:
                            STATE["x"] = values[0]
                            STATE["y"] = values[1]
                            STATE["w"] = values[2]
                            STATE["h"] = values[3]
                            STATE["ct"] = int(time.time() * 1000)
                            if window:
                                STATE["wid"] = window["wid"]
                                STATE["wx"] = window["x"]
                                STATE["wy"] = window["y"]
                    pending = False
                    values = []
            elif line.strip() and not line.startswith(" "):
                pending = False
                values = []
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()


def monitor_loop():
    while True:
        address = ibus_address()
        if not address:
            time.sleep(1)
            continue
        try:
            monitor(address)
        except Exception as exc:  # keep the sensor alive across IBus restarts
            print("caret bridge: %s" % exc, file=sys.stderr)
        time.sleep(0.5)


def publish_loop():
    while True:
        current = active_window()
        with STATE_LOCK:
            payload = dict(STATE)
        if current:
            payload["cwid"] = current["wid"]
            payload["cx"] = current["x"]
            payload["cy"] = current["y"]
            payload["cw"] = current["w"]
            payload["ch"] = current["h"]
        else:
            payload["cwid"] = ""
            payload["cx"] = 0
            payload["cy"] = 0
            payload["cw"] = 0
            payload["ch"] = 0
        payload["t"] = int(time.time() * 1000)
        try:
            tmp = OUT + ".tmp"
            with open(tmp, "w") as handle:
                json.dump(payload, handle)
            os.replace(tmp, OUT)
        except OSError:
            pass
        time.sleep(0.1)


def main():
    threading.Thread(target=monitor_loop, daemon=True).start()
    publish_loop()


if __name__ == "__main__":
    main()