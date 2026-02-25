#!/usr/bin/env python3

import argparse
import sys
from typing import List, Tuple

from Xlib import X, display
from Xlib.protocol import event


ALL_DESKTOPS = 0xFFFFFFFF
MIN_SPLIT_WIDTH = 160
MIN_SPLIT_HEIGHT = 120


class WindowTiler:
    def __init__(self) -> None:
        self.display = display.Display()
        self.root = self.display.screen().root
        self.atoms = {
            name: self.display.intern_atom(name)
            for name in [
                "_NET_ACTIVE_WINDOW",
                "_NET_CLIENT_LIST",
                "_NET_CLIENT_LIST_STACKING",
                "_NET_CURRENT_DESKTOP",
                "_NET_WORKAREA",
                "_NET_WM_DESKTOP",
                "_NET_WM_STATE",
                "_NET_WM_STATE_HIDDEN",
                "_NET_WM_STATE_MAXIMIZED_VERT",
                "_NET_WM_STATE_MAXIMIZED_HORZ",
                "_NET_WM_WINDOW_TYPE",
                "_NET_WM_WINDOW_TYPE_DOCK",
                "_NET_WM_WINDOW_TYPE_DESKTOP",
                "_NET_WM_WINDOW_TYPE_SPLASH",
                "_NET_WM_WINDOW_TYPE_TOOLBAR",
                "_NET_WM_WINDOW_TYPE_MENU",
                "_NET_WM_STATE",
                "_NET_MOVERESIZE_WINDOW",
            ]
        }

    def close(self) -> None:
        try:
            self.display.close()
        except Exception:
            pass

    def _get_property(self, win, atom_name: str):
        return win.get_full_property(self.atoms[atom_name], X.AnyPropertyType)

    def get_current_desktop(self) -> int:
        prop = self._get_property(self.root, "_NET_CURRENT_DESKTOP")
        if prop and prop.value is not None and len(prop.value) > 0:
            return int(prop.value[0])
        return 0

    def get_active_window_id(self) -> int:
        prop = self._get_property(self.root, "_NET_ACTIVE_WINDOW")
        if prop and prop.value is not None and len(prop.value) > 0:
            return int(prop.value[0])
        return 0

    def get_workarea(self, desktop: int) -> Tuple[int, int, int, int]:
        prop = self._get_property(self.root, "_NET_WORKAREA")
        if prop and prop.value is not None and len(prop.value) >= (desktop + 1) * 4:
            base = desktop * 4
            return (
                int(prop.value[base]),
                int(prop.value[base + 1]),
                int(prop.value[base + 2]),
                int(prop.value[base + 3]),
            )

        geom = self.root.get_geometry()
        return (0, 0, int(geom.width), int(geom.height))

    def _window_desktop(self, win) -> int:
        prop = self._get_property(win, "_NET_WM_DESKTOP")
        if prop and prop.value is not None and len(prop.value) > 0:
            return int(prop.value[0])
        return ALL_DESKTOPS

    def _window_type_atoms(self, win) -> List[int]:
        prop = self._get_property(win, "_NET_WM_WINDOW_TYPE")
        if prop and prop.value is not None:
            return [int(v) for v in prop.value]
        return []

    def _window_state_atoms(self, win) -> List[int]:
        prop = self._get_property(win, "_NET_WM_STATE")
        if prop and prop.value is not None:
            return [int(v) for v in prop.value]
        return []

    def _is_tilable_window(self, wid: int, current_desktop: int) -> bool:
        try:
            win = self.display.create_resource_object("window", wid)
            attrs = win.get_attributes()
            if attrs.map_state == X.IsUnmapped:
                return False

            desktop = self._window_desktop(win)
            if desktop not in (ALL_DESKTOPS, current_desktop):
                return False

            skip_types = {
                self.atoms["_NET_WM_WINDOW_TYPE_DOCK"],
                self.atoms["_NET_WM_WINDOW_TYPE_DESKTOP"],
                self.atoms["_NET_WM_WINDOW_TYPE_SPLASH"],
                self.atoms["_NET_WM_WINDOW_TYPE_TOOLBAR"],
                self.atoms["_NET_WM_WINDOW_TYPE_MENU"],
            }
            if any(atom in skip_types for atom in self._window_type_atoms(win)):
                return False

            states = self._window_state_atoms(win)
            if self.atoms["_NET_WM_STATE_HIDDEN"] in states:
                return False

            return True
        except Exception:
            return False

    def get_tilable_windows_ordered(self) -> List[int]:
        current_desktop = self.get_current_desktop()
        prop = self._get_property(self.root, "_NET_CLIENT_LIST_STACKING")
        if not prop or prop.value is None:
            prop = self._get_property(self.root, "_NET_CLIENT_LIST")
        if not prop or prop.value is None:
            return []

        ordered: List[int] = []
        for wid in [int(v) for v in prop.value]:
            if self._is_tilable_window(wid, current_desktop):
                ordered.append(wid)
        return ordered

    def choose_pair(self) -> Tuple[int, int]:
        active = self.get_active_window_id()
        if not active:
            raise RuntimeError("No active window")

        ordered = self.get_tilable_windows_ordered()
        if len(ordered) < 2:
            raise RuntimeError("Need at least two tilable windows")
        if active not in ordered:
            raise RuntimeError("Active window is not tilable")

        idx = ordered.index(active)
        for offset in range(1, len(ordered)):
            candidate = ordered[(idx + offset) % len(ordered)]
            if candidate != active:
                return active, candidate
        raise RuntimeError("Cannot find a second tilable window")

    def _send_client_message(self, target, message_type: str, data: List[int]) -> None:
        msg = event.ClientMessage(
            window=target,
            client_type=self.atoms[message_type],
            data=(32, data),
        )
        self.root.send_event(
            msg,
            event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask,
        )

    def _clear_maximized(self, wid: int) -> None:
        win = self.display.create_resource_object("window", wid)
        # _NET_WM_STATE action 0 means remove.
        self._send_client_message(
            win,
            "_NET_WM_STATE",
            [
                0,
                self.atoms["_NET_WM_STATE_MAXIMIZED_HORZ"],
                self.atoms["_NET_WM_STATE_MAXIMIZED_VERT"],
                1,
                0,
            ],
        )

    def _set_maximized(self, wid: int) -> None:
        win = self.display.create_resource_object("window", wid)
        # _NET_WM_STATE action 1 means add.
        self._send_client_message(
            win,
            "_NET_WM_STATE",
            [
                1,
                self.atoms["_NET_WM_STATE_MAXIMIZED_HORZ"],
                self.atoms["_NET_WM_STATE_MAXIMIZED_VERT"],
                1,
                0,
            ],
        )

    def _move_resize(self, wid: int, x: int, y: int, w: int, h: int) -> None:
        win = self.display.create_resource_object("window", wid)
        gravity = 0
        flags = (1 << 8) | (1 << 9) | (1 << 10) | (1 << 11)
        self._send_client_message(
            win,
            "_NET_MOVERESIZE_WINDOW",
            [gravity | flags, int(x), int(y), int(w), int(h)],
        )

        # Fallback configure for WMs that ignore _NET_MOVERESIZE_WINDOW.
        try:
            win.configure(x=int(x), y=int(y), width=int(w), height=int(h))
        except Exception:
            pass

    def _focus(self, wid: int) -> None:
        win = self.display.create_resource_object("window", wid)
        self._send_client_message(
            win,
            "_NET_ACTIVE_WINDOW",
            [1, X.CurrentTime, 0, 0, 0],
        )

    def split(self, mode: str, active_side: str) -> Tuple[int, int]:
        if mode not in ("lr", "tb", "fullscreen"):
            raise RuntimeError("mode must be one of: lr, tb, fullscreen")
        active, other = self.choose_pair()
        desktop = self.get_current_desktop()
        wx, wy, ww, wh = self.get_workarea(desktop)
        if mode == "fullscreen":
            for wid in (active, other):
                self._move_resize(wid, wx, wy, ww, wh)
                self._set_maximized(wid)
            self._focus(active)
            self.display.flush()
            return active, other

        self._clear_maximized(active)
        self._clear_maximized(other)
        if mode == "lr":
            if active_side not in ("left", "right"):
                raise RuntimeError("active_side must be left or right for lr mode")
            if ww < MIN_SPLIT_WIDTH * 2 or wh < MIN_SPLIT_HEIGHT:
                raise RuntimeError(
                    f"Workarea too small for left/right split: {ww}x{wh} (minimum {MIN_SPLIT_WIDTH*2}x{MIN_SPLIT_HEIGHT})"
                )
            left_w = ww // 2
            right_w = ww - left_w
            left_geom = (wx, wy, left_w, wh)
            right_geom = (wx + left_w, wy, right_w, wh)
            left_wid, right_wid = (
                (active, other) if active_side == "left" else (other, active)
            )
            self._move_resize(left_wid, *left_geom)
            self._move_resize(right_wid, *right_geom)
        else:
            if active_side not in ("top", "bottom", "left", "right"):
                raise RuntimeError("active_side must be top or bottom for tb mode")
            if wh < MIN_SPLIT_HEIGHT * 2 or ww < MIN_SPLIT_WIDTH:
                raise RuntimeError(
                    f"Workarea too small for top/bottom split: {ww}x{wh} (minimum {MIN_SPLIT_WIDTH}x{MIN_SPLIT_HEIGHT*2})"
                )
            top_h = wh // 2
            bottom_h = wh - top_h
            top_geom = (wx, wy, ww, top_h)
            bottom_geom = (wx, wy + top_h, ww, bottom_h)
            place_active_top = active_side in ("top", "left")
            top_wid, bottom_wid = (
                (active, other) if place_active_top else (other, active)
            )
            self._move_resize(top_wid, *top_geom)
            self._move_resize(bottom_wid, *bottom_geom)
        self._focus(active)
        self.display.flush()
        return active, other


def count_tilable_windows() -> int:
    tiler = WindowTiler()
    try:
        return len(tiler.get_tilable_windows_ordered())
    finally:
        tiler.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Tile windows in Openbox")
    sub = parser.add_subparsers(dest="command")

    split_parser = sub.add_parser("split", help="Apply split/fullscreen layout to active and recent window")
    split_parser.add_argument(
        "--mode",
        choices=["lr", "tb", "fullscreen"],
        default="lr",
        help="Layout mode: lr (left/right), tb (top/bottom), fullscreen (both maximized)",
    )
    split_parser.add_argument(
        "--active-side",
        choices=["left", "right", "top", "bottom"],
        default="left",
        help="Place active window on requested side (lr: left/right, tb: top/bottom)",
    )

    args = parser.parse_args()
    if args.command != "split":
        parser.print_help()
        return 2

    tiler = WindowTiler()
    try:
        left_wid, right_wid = tiler.split(mode=args.mode, active_side=args.active_side)
        print(
            f"Layout completed: mode={args.mode} win1={left_wid} win2={right_wid} active_side={args.active_side}"
        )
        return 0
    except Exception as exc:
        print(f"Split failed: {exc}", file=sys.stderr)
        return 1
    finally:
        tiler.close()


if __name__ == "__main__":
    sys.exit(main())
