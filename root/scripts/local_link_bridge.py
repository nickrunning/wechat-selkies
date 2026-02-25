#!/usr/bin/env python3
import json
import os
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def parse_int_env(name, default_value, min_value, max_value):
    raw = os.getenv(name, str(default_value)).strip()
    try:
        value = int(raw)
    except Exception:
        return default_value
    if value < min_value or value > max_value:
        return default_value
    return value


def parse_allowed_schemes():
    raw = os.getenv("LOCAL_LINK_BRIDGE_ALLOWED_SCHEMES", "http,https,mailto")
    schemes = []
    for part in raw.split(","):
        text = part.strip().lower()
        if text:
            schemes.append(text)
    if not schemes:
        return {"http", "https"}
    return set(schemes)


MAX_EVENTS = parse_int_env("LOCAL_LINK_BRIDGE_MAX_EVENTS", 256, 16, 4096)
ALLOWED_SCHEMES = parse_allowed_schemes()


class EventQueue:
    def __init__(self, max_events):
        self._lock = threading.Lock()
        self._events = deque(maxlen=max_events)
        self._next_id = 1

    def push(self, url, source):
        with self._lock:
            event = {
                "id": self._next_id,
                "url": url,
                "source": source,
                "ts": int(time.time() * 1000),
            }
            self._next_id += 1
            self._events.append(event)
            return event["id"]

    def pull(self, since_id):
        with self._lock:
            events = [event for event in self._events if event["id"] > since_id]
            latest_id = self._events[-1]["id"] if self._events else 0
            return events, latest_id


QUEUE = EventQueue(MAX_EVENTS)


def sanitize_url(raw_url):
    text = str(raw_url or "").strip()
    if not text or len(text) > 4096:
        return None
    parsed = urlparse(text)
    scheme = parsed.scheme.lower()
    if scheme not in ALLOWED_SCHEMES:
        return None
    if scheme in ("http", "https") and not parsed.netloc:
        return None
    return text


class LocalLinkBridgeHandler(BaseHTTPRequestHandler):
    server_version = "LocalLinkBridge/1.0"

    def log_message(self, fmt, *args):
        message = "%s - - [%s] %s" % (
            self.client_address[0],
            self.log_date_time_string(),
            fmt % args,
        )
        print(message, flush=True)

    def _send_json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0:
            return b""
        return self.rfile.read(min(length, 16384))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send_json(200, {"ok": True})
            return
        if parsed.path != "/pull":
            self._send_json(404, {"ok": False, "error": "not found"})
            return

        query = parse_qs(parsed.query or "")
        try:
            since_id = int((query.get("since") or ["0"])[0])
        except Exception:
            since_id = 0
        if since_id < 0:
            since_id = 0

        events, latest_id = QUEUE.pull(since_id)
        self._send_json(200, {"ok": True, "events": events, "latest_id": latest_id})

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/push":
            self._send_json(404, {"ok": False, "error": "not found"})
            return

        raw_body = self._read_body()
        content_type = (self.headers.get("Content-Type") or "").lower()
        payload = {}
        if "application/json" in content_type:
            try:
                payload = json.loads(raw_body.decode("utf-8", errors="replace"))
            except Exception:
                payload = {}
        else:
            data = parse_qs(raw_body.decode("utf-8", errors="replace"))
            payload = {key: values[0] for key, values in data.items() if values}

        url = sanitize_url(payload.get("url", ""))
        if not url:
            self._send_json(400, {"ok": False, "error": "invalid url"})
            return

        source = str(payload.get("source", "xdg-open"))[:64]
        event_id = QUEUE.push(url, source)
        self._send_json(200, {"ok": True, "id": event_id})


def main():
    host = os.getenv("LOCAL_LINK_BRIDGE_HOST", "127.0.0.1")
    port = parse_int_env("LOCAL_LINK_BRIDGE_PORT", 38080, 1024, 65535)
    print(
        "[local-link-bridge] starting on %s:%d, schemes=%s, max_events=%d"
        % (host, port, ",".join(sorted(ALLOWED_SCHEMES)), MAX_EVENTS),
        flush=True,
    )
    server = ThreadingHTTPServer((host, port), LocalLinkBridgeHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
