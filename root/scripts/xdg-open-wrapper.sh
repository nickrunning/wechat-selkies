#!/bin/bash
set -euo pipefail

is_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

REAL_XDG_OPEN="/usr/bin/xdg-open.real"
if [ ! -x "$REAL_XDG_OPEN" ]; then
    if command -v gio >/dev/null 2>&1; then
        exec gio open "$@"
    fi
    echo "xdg-open fallback not found" >&2
    exit 1
fi

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    exec "$REAL_XDG_OPEN" "$@"
fi

if ! is_true "${SELKIES_LOCAL_LINK_OPEN:-true}"; then
    exec "$REAL_XDG_OPEN" "$@"
fi

case "$TARGET" in
    http://*|https://*|mailto:*)
        BRIDGE_PORT="${LOCAL_LINK_BRIDGE_PORT:-38080}"
        if python3 - "$TARGET" "$BRIDGE_PORT" <<'PY'
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

url = sys.argv[1]
port = int(sys.argv[2])
endpoint = "http://127.0.0.1:%d/push" % port
payload = urllib.parse.urlencode({"url": url, "source": "xdg-open"}).encode("utf-8")
request = urllib.request.Request(endpoint, data=payload, method="POST")
request.add_header("Content-Type", "application/x-www-form-urlencoded")
with urllib.request.urlopen(request, timeout=1.5) as response:
    body = response.read().decode("utf-8", errors="replace")
    parsed = json.loads(body)
    if not parsed.get("ok", False):
        raise RuntimeError("bridge rejected url")
PY
        then
            exit 0
        fi
        ;;
esac

exec "$REAL_XDG_OPEN" "$@"
