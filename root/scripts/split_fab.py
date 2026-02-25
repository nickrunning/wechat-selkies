#!/usr/bin/env python3

import math
import os
import subprocess
import threading
import time
import tkinter as tk
import tkinter.font as tkfont

import window_tiler


POLL_INTERVAL_MS = 1000
EDGE_GAP = 1
TOP_GAP = 1
PANEL_COLLAPSED_W = 96
PANEL_EXPANDED_W = 184
PANEL_EXPANDED_H = 118
STRIP_THICKNESS = 12
IDLE_COLLAPSE_MS = 15000
DEFAULT_POSITION = "top-center"

BG_IDLE = "#0f172a"
BG_HOVER = "#1e293b"
BG_SUCCESS = "#065f46"
BG_ERROR = "#7f1d1d"
FG_TEXT = "#f8fafc"
FG_MUTED = "#cbd5e1"
BORDER = "#334155"
BORDER_HI = "#94a3b8"
OPTION_IDLE = "#111827"
OPTION_HOVER = "#1f2937"
OPTION_BORDER = "#475569"
SPLIT_OPTIONS = [
    ("lr", "左右对半分"),
    ("tb", "上下对半分"),
    ("fullscreen", "都全屏"),
]


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def ease_out_cubic(t: float) -> float:
    p = clamp(t, 0.0, 1.0) - 1.0
    return p * p * p + 1.0


def ease_in_out_cubic(t: float) -> float:
    t = clamp(t, 0.0, 1.0)
    if t < 0.5:
        return 4 * t * t * t
    return 1 - pow(-2 * t + 2, 3) / 2


class SplitFab:
    def __init__(self) -> None:
        poll_raw = os.environ.get("SPLIT_FAB_POLL_MS", str(POLL_INTERVAL_MS)).strip()
        try:
            poll_value = int(poll_raw)
        except Exception:
            poll_value = POLL_INTERVAL_MS
        self.poll_interval_ms = max(300, poll_value)

        self.root = tk.Tk()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=BG_IDLE)

        self.position_mode = (
            os.environ.get("SPLIT_FAB_POSITION", DEFAULT_POSITION).strip().lower()
        )
        if self.position_mode not in {"bottom-right", "top-center"}:
            self.position_mode = DEFAULT_POSITION

        self.canvas = tk.Canvas(
            self.root,
            width=PANEL_EXPANDED_W,
            height=PANEL_EXPANDED_H,
            bd=0,
            highlightthickness=0,
            bg=BG_IDLE,
            cursor="hand2",
        )
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Enter>", self.on_hover_enter)
        self.canvas.bind("<Leave>", self.on_hover_leave)
        self.canvas.bind("<Button-1>", self.on_click)
        self.canvas.bind("<Motion>", self.on_motion)
        self.text_font = tkfont.nametofont("TkDefaultFont").copy()
        self.text_font.configure(size=9, weight="bold")

        self.visible = False
        self.is_hovering = False
        self.hover_mode = None
        self.busy = False

        self.progress = 1.0
        self.press = 0.0
        self.shake = 0.0
        self.complete = 0.0
        self.last_interaction = time.monotonic()

        self.bg_color = BG_IDLE
        self.status_text = ""
        self.hitboxes = {}

        self.anim_tokens = {}
        self.tiler = None
        self.root.withdraw()
        self.redraw()
        self.poll()

    def get_tiler(self):
        if self.tiler is not None:
            return self.tiler
        self.tiler = window_tiler.WindowTiler()
        return self.tiler

    def reset_tiler(self):
        if self.tiler is not None:
            try:
                self.tiler.close()
            except Exception:
                pass
        self.tiler = None

    def count_tilable_windows(self) -> int:
        try:
            tiler = self.get_tiler()
            return len(tiler.get_tilable_windows_ordered())
        except Exception:
            self.reset_tiler()
            try:
                tiler = self.get_tiler()
                return len(tiler.get_tilable_windows_ordered())
            except Exception:
                return 0

    def cancel_animation(self, key: str) -> None:
        token = self.anim_tokens.pop(key, None)
        if token is not None:
            self.root.after_cancel(token)

    def animate(self, key: str, duration_ms: int, on_step, on_done=None, ease=ease_in_out_cubic):
        self.cancel_animation(key)
        start = time.monotonic()
        duration = max(0.001, duration_ms / 1000.0)

        def tick():
            now = time.monotonic()
            t = clamp((now - start) / duration, 0.0, 1.0)
            on_step(ease(t), t)
            if t >= 1.0:
                self.anim_tokens.pop(key, None)
                if on_done:
                    on_done()
                return
            self.anim_tokens[key] = self.root.after(16, tick)

        tick()

    def get_workarea(self):
        try:
            tiler = self.get_tiler()
            desktop = tiler.get_current_desktop()
            area = tiler.get_workarea(desktop)
            return area
        except Exception:
            self.reset_tiler()
            sw = self.root.winfo_screenwidth()
            sh = self.root.winfo_screenheight()
            return (0, 0, sw, sh)

    def current_size(self):
        p = clamp(self.progress, 0.0, 1.0)
        width = int(PANEL_COLLAPSED_W + (PANEL_EXPANDED_W - PANEL_COLLAPSED_W) * p)
        height = int(STRIP_THICKNESS + (PANEL_EXPANDED_H - STRIP_THICKNESS) * p)
        return max(STRIP_THICKNESS, width), max(STRIP_THICKNESS, height)

    def position_window(self):
        wx, wy, ww, wh = self.get_workarea()
        width, height = self.current_size()
        if self.position_mode == "top-center":
            x = wx + (ww - width) // 2 + int(self.shake)
            y = wy + TOP_GAP
        else:
            x = wx + ww - width - EDGE_GAP
            y = wy + wh - height - EDGE_GAP + int(self.shake)
        self.root.geometry(f"{width}x{height}+{x}+{y}")
        self.canvas.config(width=width, height=height)

    def draw_handle(self, width: int, height: int):
        if self.position_mode == "top-center":
            y = height // 2
            self.canvas.create_line(
                width // 2 - 14, y, width // 2 + 14, y, fill=FG_MUTED, width=2
            )
        else:
            x = width // 2
            self.canvas.create_line(
                x, height // 2 - 14, x, height // 2 + 14, fill=FG_MUTED, width=2
            )

    def draw_options(self, width: int, height: int):
        self.hitboxes = {}
        pad_x = 8
        pad_top = 8
        pad_bottom = 8
        row_gap = 4
        usable_h = height - pad_top - pad_bottom - row_gap * 2
        row_h = max(20, usable_h // 3)
        x1 = pad_x
        x2 = width - pad_x

        for idx, (mode, label) in enumerate(SPLIT_OPTIONS):
            y1 = pad_top + idx * (row_h + row_gap)
            y2 = y1 + row_h
            fill = OPTION_HOVER if self.hover_mode == mode else OPTION_IDLE
            self.canvas.create_rectangle(
                x1, y1, x2, y2, fill=fill, outline=OPTION_BORDER, width=1
            )
            self.canvas.create_text(
                (x1 + x2) // 2,
                (y1 + y2) // 2,
                text=label,
                fill=FG_TEXT,
                font=self.text_font,
            )
            self.hitboxes[mode] = (x1, y1, x2, y2)

    def mode_from_point(self, x: int, y: int):
        for mode, (x1, y1, x2, y2) in self.hitboxes.items():
            if x1 <= x <= x2 and y1 <= y <= y2:
                return mode
        return None

    def redraw(self):
        width, height = self.current_size()
        self.position_window()
        self.canvas.delete("all")

        base = self.bg_color
        if self.is_hovering and self.progress > 0.15 and not self.busy:
            base = BG_HOVER

        # Press animation scales content inward.
        inset = int(2 * self.press)
        self.canvas.create_rectangle(
            0, 0, width - 1, height - 1, fill=base, outline=BORDER_HI, width=1
        )
        self.canvas.create_rectangle(
            1, 1, width - 2, height - 2, fill=base, outline=BORDER, width=1
        )

        self.hitboxes = {}
        if self.progress <= 0.1:
            self.draw_handle(width, height)
            return

        # Show three direct actions once expanded enough.
        if self.progress >= 0.55:
            self.draw_options(width, height)
        else:
            self.draw_handle(width, height)

        if self.busy or self.status_text:
            msg = "处理中..." if self.busy else self.status_text
            self.canvas.create_text(
                width // 2,
                height - 10,
                text=msg,
                fill=FG_MUTED,
                font=self.text_font,
            )

        if self.complete > 0:
            glow = int(255 * (1 - self.complete))
            if glow > 0:
                color = f"#{glow:02x}{255:02x}{220:02x}"
                self.canvas.create_rectangle(
                    1, 1, width - 1, height - 1, outline=color, width=2
                )

    def mark_interaction(self):
        self.last_interaction = time.monotonic()

    def animate_appear(self):
        self.progress = 0.0
        self.bg_color = BG_IDLE
        self.status_text = ""
        self.redraw()
        self.root.deiconify()
        self.root.lift()
        self.visible = True

        def step(v, _):
            self.progress = ease_out_cubic(v)
            self.redraw()

        self.animate("panel", 220, step)

    def animate_collapse(self):
        start = self.progress
        if start <= 0.02:
            self.progress = 0.0
            self.redraw()
            return

        def step(v, _):
            self.progress = start * (1.0 - v)
            self.redraw()

        self.animate("panel", 220, step)

    def animate_expand(self):
        start = self.progress
        if start >= 0.98:
            self.progress = 1.0
            self.redraw()
            return

        def step(v, _):
            self.progress = start + (1.0 - start) * ease_out_cubic(v)
            self.redraw()

        self.animate("panel", 220, step)

    def animate_hide(self):
        start = self.progress

        def step(v, _):
            self.progress = start * (1.0 - v)
            self.redraw()

        def done():
            self.root.withdraw()
            self.visible = False
            self.progress = 0.0
            self.press = 0.0
            self.shake = 0.0
            self.complete = 0.0
            self.bg_color = BG_IDLE
            self.status_text = ""
            self.redraw()

        self.animate("panel", 180, step, done)

    def animate_click(self):
        if self.press > 0:
            return

        def down(v, _):
            self.press = 0.25 * v
            self.redraw()

        def up():
            def step(v, _):
                self.press = 0.25 * (1.0 - v)
                self.redraw()

            self.animate("press", 120, step)

        self.animate("press", 80, down, up)

    def animate_complete(self):
        self.bg_color = BG_SUCCESS
        self.status_text = "已完成"
        self.complete = 0.0
        self.redraw()

        def step(v, _):
            self.complete = v
            self.redraw()

        def done():
            self.bg_color = BG_IDLE
            self.status_text = ""
            self.complete = 0.0
            self.redraw()
            self.mark_interaction()
            self.animate_collapse()

        self.animate("complete", 380, step, done, ease_out_cubic)

    def animate_error(self):
        self.bg_color = BG_ERROR
        self.status_text = "失败"
        self.redraw()

        def step(v, _):
            self.shake = math.sin(v * math.pi * 8) * (1.0 - v) * 6
            self.redraw()

        def done():
            self.shake = 0.0
            self.bg_color = BG_IDLE
            self.status_text = ""
            self.redraw()

        self.animate("shake", 320, step, done, ease_out_cubic)

    def run_split_async(self, mode: str):
        if self.busy:
            return
        self.busy = True
        self.status_text = ""
        self.redraw()

        def worker():
            try:
                result = subprocess.run(
                    ["python3", "/scripts/window_tiler.py", "split", "--mode", mode],
                    capture_output=True,
                    text=True,
                    timeout=6,
                )
                ok = result.returncode == 0
            except Exception:
                ok = False

            def finish():
                self.busy = False
                if ok:
                    self.animate_complete()
                else:
                    self.animate_error()

            self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def on_hover_enter(self, _event):
        self.mark_interaction()
        self.is_hovering = True
        self.redraw()

    def on_hover_leave(self, _event):
        self.is_hovering = False
        self.hover_mode = None
        self.redraw()

    def on_motion(self, event):
        if self.progress < 0.55 or self.busy:
            if self.hover_mode is not None:
                self.hover_mode = None
                self.redraw()
            return
        mode = self.mode_from_point(event.x, event.y)
        if mode != self.hover_mode:
            self.hover_mode = mode
            self.redraw()

    def on_click(self, event):
        self.mark_interaction()
        if self.busy:
            return
        if self.progress <= 0.1:
            self.animate_expand()
            return
        mode = self.mode_from_point(event.x, event.y)
        if mode is None:
            self.animate_collapse()
            return
        self.animate_click()
        self.run_split_async(mode)

    def poll(self):
        count = self.count_tilable_windows()

        should_show = count >= 2
        if should_show and not self.visible:
            self.mark_interaction()
            self.animate_appear()
        elif not should_show and self.visible:
            if "panel" not in self.anim_tokens:
                self.animate_hide()
        elif should_show and self.visible:
            idle_ms = int((time.monotonic() - self.last_interaction) * 1000)
            if (
                idle_ms >= IDLE_COLLAPSE_MS
                and not self.busy
                and "panel" not in self.anim_tokens
                and self.progress > 0.02
            ):
                self.animate_collapse()
            self.position_window()
            self.root.lift()

        self.root.after(self.poll_interval_ms, self.poll)

    def run(self):
        try:
            self.root.mainloop()
        finally:
            self.reset_tiler()


def main() -> int:
    app = SplitFab()
    app.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
