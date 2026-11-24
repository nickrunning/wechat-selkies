(function () {
    'use strict';
    if (window.__selkiesImeAnchorInstalled) return;
    window.__selkiesImeAnchorInstalled = true;

    const VERSION = '7';
    let host = null;
    let hostLine = 22;
    let sensorCaret = null;
    let caretWS = null;
    let wsBackoff = 1000;
    let wsReconnect = null;
    let scanToken = 0;

    function debug() {
        return window.__SELKIES_IME_DEBUG__ === true;
    }

    function log(...args) {
        if (!debug()) return;
        const text = args.map(function (value) {
            if (typeof value === 'string') return value;
            try {
                return JSON.stringify(value);
            } catch (err) {
                return String(value);
            }
        }).join(' ');
        console.log('[IME-ANCHOR]', text);
    }

    function overlay() {
        const input = window.webrtcInput && window.webrtcInput.element;
        return input && input.tagName === 'INPUT' ? input : null;
    }

    function streamInfo() {
        const canvas = document.getElementById('videoCanvas');
        if (!canvas) return null;
        const rect = canvas.getBoundingClientRect();
        return {
            canvasBuffer: [canvas.width, canvas.height],
            canvasCss: [Math.round(rect.width), Math.round(rect.height)],
            scale: canvas.width ? +(rect.width / canvas.width).toFixed(4) : null,
            dpr: window.devicePixelRatio || 1,
            viewport: [window.innerWidth, window.innerHeight]
        };
    }

    function sampleStream(clientX, clientY) {
        const canvas = document.getElementById('videoCanvas');
        if (!canvas || !canvas.width || !canvas.height) return null;
        const rect = canvas.getBoundingClientRect();
        if (clientX < rect.left || clientY < rect.top || clientX >= rect.right || clientY >= rect.bottom) return null;
        const sx = Math.floor((clientX - rect.left) * canvas.width / rect.width);
        const sy = Math.floor((clientY - rect.top) * canvas.height / rect.height);
        try {
            const ctx = canvas.getContext('2d');
            if (!ctx) return null;
            const size = 7;
            const data = ctx.getImageData(
                Math.max(0, sx - size / 2), Math.max(0, sy - size / 2), size, size
            ).data;
            let max = 0;
            for (let i = 0; i < data.length; i += 4) {
                max = Math.max(max, data[i], data[i + 1], data[i + 2]);
            }
            return { max: max, x: sx, y: sy };
        } catch (err) {
            return null;
        }
    }

    // WeChat draws the text caret as a short teal vertical line. Find it in
    // the stream so the IME host can be placed at the real caret.
    function findCaret(clientX, clientY, fullFrame) {
        const canvas = document.getElementById('videoCanvas');
        if (!canvas || !canvas.width || !canvas.height) return null;
        const rect = canvas.getBoundingClientRect();
        const clickX = (clientX - rect.left) * canvas.width / rect.width;
        const clickY = (clientY - rect.top) * canvas.height / rect.height;
        const padX = fullFrame ? canvas.width : 600;
        const padY = fullFrame ? canvas.height : 360;
        const x0 = fullFrame ? 0 : Math.max(0, Math.floor(clickX - padX));
        const y0 = fullFrame ? 0 : Math.max(0, Math.floor(clickY - padY));
        const w = fullFrame ? canvas.width : Math.min(canvas.width - x0, padX * 2);
        const h = fullFrame ? canvas.height : Math.min(canvas.height - y0, padY * 2);
        if (w < 8 || h < 8) return null;
        let data;
        try {
            const ctx = canvas.getContext('2d');
            if (!ctx) return null;
            data = ctx.getImageData(x0, y0, w, h).data;
        } catch (err) {
            return null;
        }
        const clusters = [];
        for (let x = 0; x < w; x++) {
            let start = -1;
            for (let y = 0; y <= h; y++) {
                let on = false;
                if (y < h) {
                    const i = (y * w + x) * 4;
                    const r = data[i];
                    const g = data[i + 1];
                    const b = data[i + 2];
                    on = g > 150 && r < 80 && b < 180 && g > b + 30;
                }
                if (on && start < 0) start = y;
                if (!on && start >= 0) {
                    const len = y - start;
                    if (len >= 15 && len <= 70) {
                        const ys = start;
                        const ye = y - 1;
                        let cluster = null;
                        for (let k = 0; k < clusters.length; k++) {
                            const cl = clusters[k];
                            if (cl.x1 === x - 1 &&
                                Math.min(cl.y1, ye) - Math.max(cl.y0, ys) > Math.min(cl.y1 - cl.y0 + 1, ye - ys + 1) * 0.5) {
                                cluster = cl;
                                break;
                            }
                        }
                        if (cluster) {
                            cluster.x1 = x;
                            cluster.y0 = Math.min(cluster.y0, ys);
                            cluster.y1 = Math.max(cluster.y1, ye);
                        } else {
                            clusters.push({ x0: x, x1: x, y0: ys, y1: ye });
                        }
                    }
                    start = -1;
                }
            }
        }
        let best = null;
        let bestDist = Infinity;
        for (let k = 0; k < clusters.length; k++) {
            const cl = clusters[k];
            const cw = cl.x1 - cl.x0 + 1;
            const ch = cl.y1 - cl.y0 + 1;
            if (cw < 1 || cw > 9 || ch < 15 || ch > 70) continue;
            const px = x0 + (cl.x0 + cl.x1) / 2;
            const py = y0 + (cl.y0 + cl.y1) / 2;
            const dist = Math.hypot(px - clickX, py - clickY);
            if (dist < bestDist) {
                bestDist = dist;
                best = { px: px, py: py, cw: cw, ch: ch };
            }
        }
        if (!best) return null;
        return {
            cssX: rect.left + best.px * rect.width / canvas.width,
            cssY: rect.top + best.py * rect.height / canvas.height,
            cssHeight: best.ch * rect.height / canvas.height,
            buffer: [Math.round(best.px), Math.round(best.py)],
            size: [best.cw, best.ch],
            clickBuffer: [Math.round(clickX), Math.round(clickY)],
            distance: Math.round(bestDist)
        };
    }

    function ensureHost() {
        if (host && host.isConnected) return host;
        host = document.createElement('input');
        host.type = 'text';
        host.id = 'selkies-ime-host';
        host.setAttribute('autocomplete', 'off');
        host.setAttribute('autocorrect', 'off');
        host.setAttribute('autocapitalize', 'off');
        host.setAttribute('spellcheck', 'false');
        const style = host.style;
        style.position = 'fixed';
        style.left = '0px';
        style.top = '0px';
        style.width = '1px';
        style.height = '1px';
        style.margin = '0';
        style.padding = '0';
        style.border = '0';
        style.outline = '0';
        style.opacity = '0';
        style.background = 'transparent';
        style.color = 'transparent';
        style.caretColor = 'transparent';
        style.pointerEvents = 'none';
        style.zIndex = '2147483647';
        style.fontSize = '15px';
        style.lineHeight = '22px';
        document.body.appendChild(host);

        host.addEventListener('compositionstart', function (event) {
            scanToken++;
            const sensor = sensorCaretRect();
            if (sensor) {
                positionHostRect(sensor.x, sensor.y, sensor.h, true);
            } else {
                let caret = findCaret(hostLeft, hostTop + hostLine / 2, false);
                if (!caret) caret = findCaret(hostLeft, hostTop + hostLine / 2, true);
                if (caret) {
                    positionHost(caret, true);
                } else {
                    host.value = '';
                }
            }
            const shell = window.webrtcInput;
            if (shell && shell._compositionStart) shell._compositionStart(event);
            log('compositionstart', { data: event.data, host: hostInfo(), sensor: sensor });
        }, true);
        host.addEventListener('compositionupdate', function (event) {
            const shell = window.webrtcInput;
            if (shell && shell._compositionUpdate) shell._compositionUpdate(event);
            log('compositionupdate', { data: event.data, host: hostInfo() });
        }, true);
        host.addEventListener('compositionend', function (event) {
            const shell = window.webrtcInput;
            if (shell && shell._compositionEnd) shell._compositionEnd(event);
            host.value = '';
            scheduleCaretScan(hostLeft, hostTop + hostLine / 2, false);
            pollSensorCaret();
            log('compositionend', { data: event.data, host: hostInfo() });
        }, true);
        return host;
    }

    function hostInfo() {
        if (!host) return null;
        const rect = host.getBoundingClientRect();
        return {
            rect: [Math.round(rect.left), Math.round(rect.top), Math.round(rect.width), Math.round(rect.height)],
            value: host.value,
            fontSize: host.style.fontSize,
            lineHeight: host.style.lineHeight,
            active: document.activeElement === host
        };
    }

    let hostLeft = 0;
    let hostTop = 0;

    function positionHostRect(x, y, lineHeight, clear) {
        const el = ensureHost();
        const offset = window.__selkiesImeAnchorOffset || {};
        x = Math.max(0, x + (Number(offset.x) || 0));
        y = Math.max(0, y + (Number(offset.y) || 0));
        const lh = Math.max(12, Math.min(48, lineHeight || 22));
        const width = Math.max(40, Math.min(800, window.innerWidth - x - 8));
        hostLeft = x;
        hostTop = y;
        hostLine = lh;
        if (clear) el.value = '';
        el.style.left = x + 'px';
        el.style.top = y + 'px';
        el.style.width = width + 'px';
        el.style.height = lh + 'px';
        el.style.lineHeight = lh + 'px';
        el.style.fontSize = (lh * 0.68) + 'px';
        if (document.activeElement !== el) {
            el.focus({ preventScroll: true });
        }
        log('host-position', {
            version: VERSION,
            host: hostInfo(),
            stream: streamInfo(),
            offset: window.__selkiesImeAnchorOffset || null
        });
    }

    function positionHost(caret, clear) {
        const lineHeight = caret.cssHeight || 22;
        positionHostRect(caret.cssX, caret.cssY - lineHeight / 2, lineHeight, clear);
    }

    function scheduleCaretScan(clientX, clientY, clear) {
        const token = ++scanToken;
        [0, 40, 90, 180, 320, 600].forEach(function (delay) {
            setTimeout(function () {
                if (token !== scanToken) return;
                const shell = window.webrtcInput;
                if (shell && shell.isComposing) return;
                const caret = findCaret(clientX, clientY, false);
                if (!caret) return;
                log('caret-detected', { delay: delay, caret: caret });
                positionHost(caret, clear);
            }, delay);
        });
    }

    function focusHostAtClick(clientX, clientY) {
        const o = overlay();
        if (o && document.activeElement === o) o.blur();
        positionHostRect(clientX, clientY - 11, 22, true);
        log('host-provisional', { click: [Math.round(clientX), Math.round(clientY)], host: hostInfo(), stream: streamInfo() });
    }

    function sensorCaretRect() {
        if (!sensorCaret || !Number.isFinite(sensorCaret.x)) return null;
        if (sensorCaret.wid && sensorCaret.cwid) {
            if (sensorCaret.wid !== sensorCaret.cwid) return null;
        } else if (!sensorCaret.ct || Date.now() - sensorCaret.ct > 5000) {
            return null;
        }
        const canvas = document.getElementById('videoCanvas');
        if (!canvas || !canvas.width || !canvas.height) return null;
        const rect = canvas.getBoundingClientRect();
        const dx = (sensorCaret.cx || 0) - (sensorCaret.wx || 0);
        const dy = (sensorCaret.cy || 0) - (sensorCaret.wy || 0);
        const x = rect.left + (sensorCaret.x + dx) * rect.width / canvas.width;
        const y = rect.top + (sensorCaret.y + dy) * rect.height / canvas.height;
        const h = (sensorCaret.h > 0 ? sensorCaret.h : 44) * rect.height / canvas.height;
        if (x < rect.left - 50 || x > rect.right + 50 || y < rect.top - 50 || y > rect.bottom + 50) return null;
        return { x: x, y: y, h: h, raw: sensorCaret, delta: [dx, dy] };
    }

    function applySensorPayload(payload) {
        if (!payload || !Number.isFinite(payload.x) || !Number.isFinite(payload.y)) return;
        sensorCaret = payload;
        const el = host;
        if (!el || document.activeElement !== el) return;
        const shell = window.webrtcInput;
        if (shell && shell.isComposing) return;
        const rect = sensorCaretRect();
        if (!rect) return;
        if (Math.abs(rect.x - hostLeft) < 0.5 && Math.abs(rect.y - hostTop) < 0.5 && Math.abs(rect.h - hostLine) < 0.5) return;
        positionHostRect(rect.x, rect.y, rect.h, false);
    }

    async function pollSensorCaret() {
        // The WebSocket is the primary transport; the JSON poll is only a
        // fallback while the socket is unavailable.
        if (caretWS && caretWS.readyState === WebSocket.OPEN) return;
        const base = location.pathname.replace(/[^/]*$/, '');
        let payload;
        try {
            const response = await fetch(location.origin + base + 'ime-caret.json', { cache: 'no-store' });
            if (!response.ok) return;
            payload = await response.json();
        } catch (err) {
            return;
        }
        applySensorPayload(payload);
    }

    function caretWSURL() {
        const base = location.pathname.replace(/[^/]*$/, '');
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        return proto + '//' + location.host + base + 'ime-caret.ws';
    }

    function connectCaretWS() {
        if (!window.WebSocket) return;
        try {
            caretWS = new WebSocket(caretWSURL());
        } catch (err) {
            wsReconnect = setTimeout(connectCaretWS, wsBackoff);
            wsBackoff = Math.min(wsBackoff * 2, 10000);
            return;
        }
        caretWS.onopen = function () {
            wsBackoff = 1000;
            log('caret-ws-open', { url: caretWSURL() });
        };
        caretWS.onmessage = function (event) {
            let payload;
            try {
                payload = JSON.parse(event.data);
            } catch (err) {
                return;
            }
            log('caret-ws-message', payload);
            applySensorPayload(payload);
        };
        caretWS.onerror = function () {
            try { caretWS.close(); } catch (err) { /* already closed */ }
        };
        caretWS.onclose = function () {
            caretWS = null;
            log('caret-ws-close');
            if (wsReconnect) clearTimeout(wsReconnect);
            wsReconnect = setTimeout(connectCaretWS, wsBackoff);
            wsBackoff = Math.min(wsBackoff * 2, 10000);
        };
    }

    function onOverlayPointerDown(event) {
        if (event.button !== 0) return;
        const o = overlay();
        if (!o || event.target !== o) return;
        // Do not preventDefault here: it would suppress the compatibility
        // mousedown/mouseup events that Selkies uses to forward the mouse.
        if (o === document.activeElement) o.blur();
        const pixel = sampleStream(event.clientX, event.clientY);
        if (pixel && pixel.max < 8) {
            log('pointerdown-skipped-desktop', { click: [event.clientX, event.clientY], pixel: pixel });
            return;
        }
        const caret = findCaret(event.clientX, event.clientY, false);
        if (caret) {
            positionHost(caret, true);
        } else if (!host) {
            focusHostAtClick(event.clientX, event.clientY);
        } else {
            ensureHost().focus({ preventScroll: true });
        }
        scheduleCaretScan(event.clientX, event.clientY, true);
        pollSensorCaret();
    }

    function onOverlayMouseDown(event) {
        const o = overlay();
        if (!o || event.target !== o) return;
        // Keep the overlay input from taking focus; the IME host must own it.
        event.preventDefault();
    }

    function onKeyDown(event) {
        if (event.isComposing || event.keyCode === 229) return;
        if (event.key === 'Enter') {
            if (host) host.value = '';
            return;
        }
        if (event.key === 'Shift' || event.key === 'Control' || event.key === 'Alt' || event.key === 'Meta') return;
        if (window.webrtcInput && window.webrtcInput.isComposing) return;
        if (host) {
            host.value = '';
            scheduleCaretScan(hostLeft, hostTop + hostLine / 2, false);
            pollSensorCaret();
        }
    }

    document.addEventListener('pointerdown', onOverlayPointerDown, true);
    document.addEventListener('mousedown', onOverlayMouseDown, true);
    window.addEventListener('keydown', onKeyDown, true);
    setInterval(pollSensorCaret, 1000);
    pollSensorCaret();
    connectCaretWS();
    log('installed', { version: VERSION, debug: debug(), stream: streamInfo() });
})();