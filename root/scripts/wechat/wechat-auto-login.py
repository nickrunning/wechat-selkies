#!/usr/bin/python3
import os
import subprocess
import sys
import time
from collections import deque

LOGIN_LABELS = {
    "进入微信", "進入微信", "登录", "登錄", "登入",
    "enter weixin", "enter wechat", "log in",
}
LOGIN_PAGE_MARKERS = {
    "网络代理设置", "網絡代理設置", "網路代理設定", "network proxy settings",
}
LOGIN_ACTIONS = ("press", "click", "activate")
WECHAT_EXE = os.path.realpath("/usr/bin/wechat")
WAIT_SECONDS = 15


def is_wechat(pid):
    try:
        return os.readlink(f"/proc/{pid}/exe") == WECHAT_EXE
    except OSError:
        return False


def children(node):
    for index in range(node.get_child_count()):
        child = node.get_child_at_index(index)
        if child is not None:
            yield child


def window_login_actions(atspi, window, deadline):
    pending = deque([window])
    matches = []
    has_login_marker = False
    while pending and time.monotonic() < deadline:
        node = pending.popleft()
        pending.extend(children(node))
        if node.get_role() != atspi.Role.PUSH_BUTTON:
            continue
        states = node.get_state_set()
        if not (states.contains(atspi.StateType.VISIBLE) and states.contains(atspi.StateType.SHOWING)):
            continue
        name = (node.get_name() or "").strip().casefold()
        if name in LOGIN_PAGE_MARKERS:
            has_login_marker = True
        if name not in LOGIN_LABELS:
            continue
        if not (states.contains(atspi.StateType.ENABLED) and states.contains(atspi.StateType.SENSITIVE)):
            continue
        action = node.get_action_iface()
        if action is None:
            continue
        actions = {action.get_action_name(i).casefold(): i for i in range(action.get_n_actions())}
        direct = next((actions[name] for name in LOGIN_ACTIONS if name in actions), None)
        focus = actions.get("setfocus")
        if direct is not None or focus is not None:
            matches.append((node, action, direct, focus))
    return matches if has_login_marker and not pending else []


def login_actions(atspi, pid, deadline):
    desktop = atspi.get_desktop(0)
    matches = []
    for app in children(desktop):
        if app.get_process_id() == pid:
            for window in children(app):
                if window.get_role() in (atspi.Role.FRAME, atspi.Role.DIALOG, atspi.Role.WINDOW):
                    matches.extend(window_login_actions(atspi, window, deadline))
    return matches if time.monotonic() < deadline else []


def xdotool(*args):
    return subprocess.check_output(["xdotool", *args], text=True, timeout=2).strip()


def activate_login(atspi, pid, match):
    node, action, direct, focus = match
    if direct is not None:
        return action.do_action(direct)

    # Some WeChat builds expose only SetFocus. Verify the X11 target before sending Space.
    window_id = xdotool("getactivewindow")
    if xdotool("getwindowpid", window_id) != str(pid):
        return False
    if not action.do_action(focus):
        return False
    if not node.get_state_set().contains(atspi.StateType.FOCUSED):
        return False
    if xdotool("getactivewindow") != window_id:
        return False
    xdotool("key", "--window", window_id, "space")
    return True


def main():
    if os.environ.get("ENABLE_WECHAT_AUTO_LOGIN", "true").lower() != "true":
        return 0

    try:
        pid = int(sys.argv[1])
        delay = max(0, int(os.environ.get("AUTO_LOGIN_DELAY", "3")))
    except (IndexError, ValueError):
        print("WeChat auto-login requires a process ID and a valid AUTO_LOGIN_DELAY.", file=sys.stderr)
        return 1

    try:
        import gi
        gi.require_version("Atspi", "2.0")
        from gi.repository import Atspi, GLib
    except (ImportError, ValueError) as error:
        print(f"WeChat accessibility is unavailable: {error}", file=sys.stderr)
        return 1

    Atspi.set_timeout(1000, 3000)
    time.sleep(delay)
    deadline = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < deadline and os.path.exists(f"/proc/{pid}"):
        if not is_wechat(pid):
            time.sleep(0.1)
            continue
        try:
            matches = login_actions(Atspi, pid, deadline)
        except GLib.Error:
            matches = []
        if len(matches) == 1 and is_wechat(pid):
            try:
                if activate_login(Atspi, pid, matches[0]):
                    print("WeChat login button activated.")
                    return 0
            except (GLib.Error, OSError, subprocess.SubprocessError):
                pass
            print("WeChat login button could not be activated.", file=sys.stderr)
            return 1
        time.sleep(min(0.5, max(0, deadline - time.monotonic())))

    print("No unique WeChat login button found. Open WeChat to complete login if needed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
