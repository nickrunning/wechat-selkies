(function () {
  "use strict";

  var runtime = window.__SELKIES_RUNTIME__ || {};
  var VAAPI_ENCODER_HINTS = new Set(["vaapih264enc"]);
  var CPU_ONLY_ENCODERS = new Set(["jpeg", "x264enc-striped"]);
  var STABLE_ENCODERS = new Set(["x264enc", "x264enc-striped", "jpeg"]);
  var FALLBACK_ENCODER = "x264enc";
  var badgeRefreshTimer = null;
  var lastServerUseCpu = null;
  var streamRecoverTimer = null;
  var waitingSinceMs = 0;
  var lastVideoPipelineActive = true;
  var STREAM_WAIT_THRESHOLD_MS = sanitizeInt(runtime.streamWaitThresholdMs, 35000, 10000, 300000);
  var STREAM_RECOVER_COOLDOWN_MS = sanitizeInt(runtime.streamRecoverCooldownMs, 120000, 30000, 600000);
  var WS_SESSION_ID = "sid_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 10);
  var WS_SESSION_EPOCH = Date.now();
  var LOCAL_LINK_OPEN_ENABLED = sanitizeBool(runtime.localLinkOpenEnabled, true);
  var LOCAL_LINK_POLL_INTERVAL_MS = sanitizeInt(runtime.localLinkPollIntervalMs, 800, 300, 10000);
  var localLinkCursorKey = "local_link_cursor_v1";
  var localLinkCursor = parseTimestamp(getStoredValue(localLinkCursorKey));
  var localLinkPollTimer = null;

  function authBasePath() {
    var path = String(window.location.pathname || "/");
    if (!path.endsWith("/")) {
      var slash = path.lastIndexOf("/");
      path = slash >= 0 ? path.slice(0, slash + 1) : "/";
    }
    return path + "auth/";
  }

  function appBasePath() {
    return authBasePath().replace(/auth\/$/, "");
  }

  function forcePinLogin() {
    var base = authBasePath();
    var logoutUrl = base + "logout";
    var landingUrl = appBasePath();

    var redirect = function () {
      window.location.href = landingUrl;
    };

    try {
      window
        .fetch(logoutUrl, {
          method: "POST",
          credentials: "same-origin",
          headers: { "X-Requested-With": "XMLHttpRequest" },
          cache: "no-store"
        })
        .finally(redirect);
    } catch (_err) {
      redirect();
    }
  }

  function withSessionIdentity(url) {
    var raw = String(url || "");
    var sid = encodeURIComponent(WS_SESSION_ID);
    var epoch = encodeURIComponent(String(WS_SESSION_EPOCH));
    try {
      var parsed = new URL(raw, window.location.href);
      parsed.searchParams.set("selkies_session_id", WS_SESSION_ID);
      parsed.searchParams.set("selkies_session_epoch", String(WS_SESSION_EPOCH));
      return parsed.toString();
    } catch (_err) {
      var joiner = raw.indexOf("?") >= 0 ? "&" : "?";
      return raw + joiner + "selkies_session_id=" + sid + "&selkies_session_epoch=" + epoch;
    }
  }

  function installSingleSessionWebSocketGuard() {
    var NativeWebSocket = window.WebSocket;
    if (!NativeWebSocket || NativeWebSocket.__selkiesSingleSessionWrapped) return;

    var WrappedWebSocket = function (url, protocols) {
      var wsUrl = withSessionIdentity(url);
      var ws =
        typeof protocols === "undefined"
          ? new NativeWebSocket(wsUrl)
          : new NativeWebSocket(wsUrl, protocols);

      ws.addEventListener("message", function (event) {
        if (!event || event.data !== "FORCE_PIN_LOGIN") return;
        try {
          ws.close(4002, "single-session takeover");
        } catch (_closeErr) {}
        forcePinLogin();
      });
      ws.addEventListener("close", function (event) {
        var code = event && typeof event.code === "number" ? event.code : 0;
        var reason = String((event && event.reason) || "").toLowerCase();
        if (
          code === 4002 ||
          code === 4003 ||
          reason.indexOf("replaced by a new client session") >= 0 ||
          reason.indexOf("stale session epoch") >= 0
        ) {
          forcePinLogin();
        }
      });
      return ws;
    };

    WrappedWebSocket.prototype = NativeWebSocket.prototype;
    WrappedWebSocket.CONNECTING = NativeWebSocket.CONNECTING;
    WrappedWebSocket.OPEN = NativeWebSocket.OPEN;
    WrappedWebSocket.CLOSING = NativeWebSocket.CLOSING;
    WrappedWebSocket.CLOSED = NativeWebSocket.CLOSED;
    WrappedWebSocket.__selkiesSingleSessionWrapped = true;
    window.WebSocket = WrappedWebSocket;
  }

  function sanitizeBool(value, fallbackValue) {
    if (typeof value === "boolean") return value;
    if (typeof value === "string") {
      var text = value.trim().toLowerCase();
      if (["true", "1", "yes", "on"].indexOf(text) >= 0) return true;
      if (["false", "0", "no", "off"].indexOf(text) >= 0) return false;
    }
    return fallbackValue;
  }

  function sanitizeInt(value, fallbackValue, minValue, maxValue) {
    var n = parseInt(String(value), 10);
    if (!Number.isFinite(n)) return fallbackValue;
    if (n < minValue || n > maxValue) return fallbackValue;
    return n;
  }

  function storagePrefix() {
    return window.location.href.split("#")[0].replace(/[^a-zA-Z0-9._-]/g, "_");
  }

  function storageKey(name) {
    return storagePrefix() + "_" + name;
  }

  function getStoredValue(name) {
    return window.localStorage.getItem(storageKey(name));
  }

  function setStoredValue(name, value) {
    if (value === null || value === undefined) {
      window.localStorage.removeItem(storageKey(name));
      return;
    }
    window.localStorage.setItem(storageKey(name), String(value));
  }

  function setStoredDefault(name, value) {
    if (getStoredValue(name) === null) {
      setStoredValue(name, value);
    }
  }

  function preferredEncoder() {
    var configured = String(runtime.preferredEncoder || "").trim().toLowerCase();
    if (!configured) {
      configured = FALLBACK_ENCODER;
    }
    if (VAAPI_ENCODER_HINTS.has(configured)) {
      return "x264enc";
    }
    if (!STABLE_ENCODERS.has(configured)) {
      return FALLBACK_ENCODER;
    }
    return configured;
  }

  function readUseCpuHint(fallbackValue) {
    var stored = getStoredValue("use_cpu");
    if (stored !== null) {
      var parsed = sanitizeBool(stored, true);
      lastServerUseCpu = parsed;
      return parsed;
    }
    if (lastServerUseCpu !== null) {
      return lastServerUseCpu;
    }
    return sanitizeBool(runtime.defaultUseCpu, fallbackValue);
  }

  function encoderMode(encoder) {
    var name = String(encoder || "").trim().toLowerCase();
    var useCpu = readUseCpuHint(true);
    if (CPU_ONLY_ENCODERS.has(name)) {
      return "CPU";
    }
    if (VAAPI_ENCODER_HINTS.has(name) && sanitizeBool(runtime.driAvailable, false)) {
      return "VAAPI";
    }
    if (name === "x264enc" && sanitizeBool(runtime.driAvailable, false) && !useCpu) {
      return "VAAPI";
    }
    return "CPU";
  }

  function setUseCpuFlag(useCpu) {
    var safe = sanitizeBool(useCpu, false);
    setStoredValue("use_cpu", safe);
    lastServerUseCpu = safe;
  }

  function initUseCpuHint() {
    var stored = getStoredValue("use_cpu");
    if (stored !== null) {
      lastServerUseCpu = sanitizeBool(stored, true);
      return;
    }
    if (typeof runtime.encoderMode === "string") {
      var mode = runtime.encoderMode.trim().toUpperCase();
      if (mode === "CPU") {
        lastServerUseCpu = true;
        return;
      }
      if (mode === "VAAPI" || mode === "GPU") {
        lastServerUseCpu = false;
        return;
      }
    }
    lastServerUseCpu = sanitizeBool(runtime.defaultUseCpu, false);
  }

  function applyRuntimeDefaults() {
    var frameRate = sanitizeInt(runtime.defaultFramerate, 48, 1, 240);
    var gamepadEnabled = sanitizeBool(runtime.defaultGamepadEnabled, false);
    var binaryClipboard = sanitizeBool(runtime.defaultBinaryClipboard, true);
    var defaultUseCpu = sanitizeBool(runtime.defaultUseCpu, false);
    var defaultStreamingMode = sanitizeBool(runtime.defaultH264StreamingMode, true);
    var defaultPaintOver = sanitizeBool(runtime.defaultUsePaintOverQuality, false);
    var defaultH264Crf = sanitizeInt(runtime.defaultH264Crf, 30, 5, 50);

    setStoredDefault("framerate", frameRate);
    setStoredDefault("isGamepadEnabled", gamepadEnabled);
    setStoredDefault("enable_binary_clipboard", binaryClipboard);
    setStoredDefault("use_cpu", defaultUseCpu);
    setStoredDefault("h264_streaming_mode", defaultStreamingMode);
    setStoredDefault("use_paint_over_quality", defaultPaintOver);
    setStoredDefault("h264_crf", defaultH264Crf);

    var currentEncoder = getStoredValue("encoder");
    if (currentEncoder === null || !STABLE_ENCODERS.has(String(currentEncoder).toLowerCase())) {
      setStoredValue("encoder", preferredEncoder());
    }
  }

  function migrateUseCpuPreferenceOnce() {
    var migrationKey = "use_cpu_migrated_vaapi_default_v1";
    if (getStoredValue(migrationKey) !== null) return;
    var encoder = String(getStoredValue("encoder") || preferredEncoder()).toLowerCase();
    if (encoder === "x264enc" && sanitizeBool(runtime.driAvailable, false)) {
      setStoredValue("use_cpu", sanitizeBool(runtime.defaultUseCpu, false));
    }
    setStoredValue(migrationKey, "1");
  }

  function injectBadgeStyle() {
    if (document.getElementById("selkies-encoder-mode-style")) return;
    var style = document.createElement("style");
    style.id = "selkies-encoder-mode-style";
    style.textContent =
      ".selkies-encoder-mode-badge{display:inline-flex;align-items:center;justify-content:center;" +
      "height:22px;min-width:42px;padding:0 8px;margin-left:8px;border-radius:999px;" +
      "border:1px solid #334155;background:#0f172a;color:#e2e8f0;font-size:11px;font-weight:700;}" +
      ".selkies-encoder-mode-badge[data-mode='vaapi']{background:#052e16;border-color:#166534;color:#86efac;}" +
      ".selkies-encoder-mode-badge[data-mode='cpu']{background:#172554;border-color:#1d4ed8;color:#bfdbfe;}";
    document.head.appendChild(style);
  }

  function findEncoderSelect() {
    var selects = Array.prototype.slice.call(document.querySelectorAll("select"));
    var candidate = null;
    for (var i = 0; i < selects.length; i += 1) {
      var values = Array.prototype.slice.call(selects[i].options || []).map(function (opt) {
        return String(opt.value || "").toLowerCase();
      });
      if (values.indexOf("x264enc") >= 0 && values.indexOf("jpeg") >= 0) {
        candidate = selects[i];
        if (selects[i].offsetParent !== null) {
          return selects[i];
        }
      }
    }
    return candidate;
  }

  function ensureEncoderBadge(select) {
    if (!select || !select.parentElement) return null;
    var badge = document.getElementById("selkies-encoder-mode-badge");
    if (!badge) {
      badge = document.createElement("span");
      badge.id = "selkies-encoder-mode-badge";
      badge.className = "selkies-encoder-mode-badge";
    }
    if (badge.parentElement !== select.parentElement) {
      select.parentElement.appendChild(badge);
    }
    return badge;
  }

  function handleEncoderModeSideEffects(select) {
    if (!select) return;
    var value = String(select.value || "").toLowerCase();
    if (CPU_ONLY_ENCODERS.has(value)) {
      setUseCpuFlag(true);
      return;
    }
    if (VAAPI_ENCODER_HINTS.has(value)) {
      setUseCpuFlag(false);
      return;
    }
    if (value === "x264enc") {
      setUseCpuFlag(readUseCpuHint(sanitizeBool(runtime.defaultUseCpu, false)));
    }
  }

  function updateEncoderBadge() {
    var select = findEncoderSelect();
    if (!select) return;
    var badge = ensureEncoderBadge(select);
    if (!badge) return;

    if (!select.dataset.encoderModeBound) {
      select.addEventListener("change", function () {
        handleEncoderModeSideEffects(select);
        scheduleBadgeRefresh(0);
      });
      select.dataset.encoderModeBound = "1";
    }

    var selectedEncoder = String(select.value || getStoredValue("encoder") || "").toLowerCase();
    var mode = encoderMode(selectedEncoder);
    badge.textContent = mode;
    badge.dataset.mode = mode.toLowerCase();
  }

  function scheduleBadgeRefresh(delayMs) {
    var delay = typeof delayMs === "number" ? delayMs : 80;
    if (badgeRefreshTimer) {
      window.clearTimeout(badgeRefreshTimer);
    }
    badgeRefreshTimer = window.setTimeout(function () {
      badgeRefreshTimer = null;
      updateEncoderBadge();
    }, delay);
  }

  function scheduleBurstRefresh() {
    var delays = [0, 120, 320, 650];
    for (var i = 0; i < delays.length; i += 1) {
      window.setTimeout(updateEncoderBadge, delays[i]);
    }
  }

  function isWaitingForStreamVisible() {
    if (!document || !document.body) return false;
    var text = String(document.body.innerText || document.body.textContent || "");
    return text.indexOf("Waiting for stream") >= 0;
  }

  function parseTimestamp(value) {
    var n = parseInt(String(value || ""), 10);
    if (!Number.isFinite(n) || n <= 0) return 0;
    return n;
  }

  function lastRecoverTimestamp() {
    return parseTimestamp(getStoredValue("stream_recover_at"));
  }

  function markRecoverTimestamp(tsMs) {
    setStoredValue("stream_recover_at", String(tsMs));
  }

  function tryRecoverFromWaiting() {
    var now = Date.now();
    var lastRecoverAt = lastRecoverTimestamp();
    if (now - lastRecoverAt < STREAM_RECOVER_COOLDOWN_MS) return;
    markRecoverTimestamp(now);
    waitingSinceMs = 0;
    window.location.reload();
  }

  function bindStreamRecoveryWatchdog() {
    if (streamRecoverTimer) return;
    streamRecoverTimer = window.setInterval(function () {
      if (document.hidden) return;
      if (!isWaitingForStreamVisible()) {
        waitingSinceMs = 0;
        return;
      }
      if (lastVideoPipelineActive) {
        waitingSinceMs = 0;
        return;
      }
      if (waitingSinceMs === 0) {
        waitingSinceMs = Date.now();
        return;
      }
      if (Date.now() - waitingSinceMs < STREAM_WAIT_THRESHOLD_MS) return;
      tryRecoverFromWaiting();
    }, 3000);

    window.addEventListener("focus", function () {
      waitingSinceMs = 0;
    });
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden) {
        waitingSinceMs = 0;
      }
    });
  }

  function localLinkApiPath(pathSuffix) {
    var base = appBasePath();
    if (!base.endsWith("/")) {
      base += "/";
    }
    return base + "api/local-link/" + String(pathSuffix || "").replace(/^\/+/, "");
  }

  function ensureLocalLinkToastStyle() {
    if (document.getElementById("selkies-local-link-toast-style")) return;
    var style = document.createElement("style");
    style.id = "selkies-local-link-toast-style";
    style.textContent =
      "#selkies-local-link-toast{position:fixed;top:14px;left:50%;transform:translateX(-50%);" +
      "background:#0f172a;color:#e2e8f0;border:1px solid #334155;border-radius:8px;padding:8px 12px;" +
      "font-size:12px;z-index:10020;display:none;box-shadow:0 10px 30px rgba(0,0,0,.35);max-width:min(90vw,780px);" +
      "white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" +
      "#selkies-local-link-toast a{color:#93c5fd;text-decoration:underline;}";
    document.head.appendChild(style);
  }

  function showLocalLinkToast(url, opened) {
    ensureLocalLinkToastStyle();
    var toast = document.getElementById("selkies-local-link-toast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "selkies-local-link-toast";
      document.body.appendChild(toast);
    }

    if (opened) {
      toast.textContent = "Opened local browser: " + url;
    } else {
      toast.innerHTML = "";
      var prefix = document.createElement("span");
      prefix.textContent = "Popup was blocked. Click to open: ";
      var link = document.createElement("a");
      link.href = url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = url;
      toast.appendChild(prefix);
      toast.appendChild(link);
    }

    toast.style.display = "block";
    window.setTimeout(function () {
      toast.style.display = "none";
    }, 4500);
  }

  function sanitizeLocalLinkUrl(url) {
    try {
      var parsed = new URL(String(url || ""), window.location.href);
      var protocol = parsed.protocol.toLowerCase();
      if (protocol !== "http:" && protocol !== "https:" && protocol !== "mailto:") {
        return "";
      }
      return parsed.toString();
    } catch (_err) {
      return "";
    }
  }

  function openLocalLink(url) {
    var safeUrl = sanitizeLocalLinkUrl(url);
    if (!safeUrl) return false;
    var openedWindow = null;
    try {
      openedWindow = window.open(safeUrl, "_blank", "noopener,noreferrer");
    } catch (_err) {}
    if (openedWindow) {
      try {
        openedWindow.opener = null;
      } catch (_err) {}
      return true;
    }
    return false;
  }

  function applyLocalLinkEvents(events) {
    if (!Array.isArray(events) || events.length === 0) return;
    events.sort(function (a, b) {
      return parseTimestamp(a && a.id) - parseTimestamp(b && b.id);
    });
    for (var i = 0; i < events.length; i += 1) {
      var event = events[i] || {};
      var eventId = parseTimestamp(event.id);
      if (eventId > localLinkCursor) {
        localLinkCursor = eventId;
      }
      var safeUrl = sanitizeLocalLinkUrl(event.url);
      if (!safeUrl) continue;
      var opened = openLocalLink(safeUrl);
      showLocalLinkToast(safeUrl, opened);
    }
    setStoredValue(localLinkCursorKey, localLinkCursor);
  }

  function pollLocalLinkEvents() {
    if (!LOCAL_LINK_OPEN_ENABLED) return;
    var path = localLinkApiPath("pull?since=" + encodeURIComponent(String(localLinkCursor || 0)));
    window
      .fetch(path, {
        method: "GET",
        credentials: "same-origin",
        cache: "no-store",
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
      .then(function (response) {
        if (!response.ok) return null;
        return response.json();
      })
      .then(function (payload) {
        if (!payload || !payload.ok) return;
        applyLocalLinkEvents(payload.events);
        var latest = parseTimestamp(payload.latest_id);
        if (latest > localLinkCursor) {
          localLinkCursor = latest;
          setStoredValue(localLinkCursorKey, localLinkCursor);
        }
      })
      .catch(function () {});
  }

  function startLocalLinkEventPoller() {
    if (!LOCAL_LINK_OPEN_ENABLED || localLinkPollTimer) return;
    pollLocalLinkEvents();
    localLinkPollTimer = window.setInterval(pollLocalLinkEvents, LOCAL_LINK_POLL_INTERVAL_MS);
    window.addEventListener("focus", pollLocalLinkEvents);
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden) {
        pollLocalLinkEvents();
      }
    });
  }

  function bindServerSettingsModeHint() {
    window.addEventListener("message", function (event) {
      var data = event && event.data;
      if (!data || typeof data !== "object") return;
      if (data.payload && Object.prototype.hasOwnProperty.call(data.payload, "use_cpu")) {
        var rawUseCpu = data.payload.use_cpu;
        if (rawUseCpu && typeof rawUseCpu === "object" && Object.prototype.hasOwnProperty.call(rawUseCpu, "value")) {
          rawUseCpu = rawUseCpu.value;
        }
        lastServerUseCpu = sanitizeBool(rawUseCpu, true);
        setStoredValue("use_cpu", lastServerUseCpu);
        scheduleBurstRefresh();
      } else if (data.type === "pipelineStatusUpdate") {
        if (Object.prototype.hasOwnProperty.call(data, "video")) {
          lastVideoPipelineActive = sanitizeBool(data.video, lastVideoPipelineActive);
          if (lastVideoPipelineActive) {
            waitingSinceMs = 0;
          }
        }
        scheduleBadgeRefresh(0);
      }
    });
  }

  function boot() {
    injectBadgeStyle();
    initUseCpuHint();
    applyRuntimeDefaults();
    migrateUseCpuPreferenceOnce();
    handleEncoderModeSideEffects(findEncoderSelect());
    scheduleBadgeRefresh(0);

    // Avoid high-frequency DOM observers; refresh with short bursts on UI interactions.
    document.addEventListener(
      "click",
      function () {
        scheduleBurstRefresh();
      },
      true
    );
    window.addEventListener("focus", function () {
      scheduleBurstRefresh();
    });
    window.addEventListener("hashchange", function () {
      scheduleBurstRefresh();
    });
    window.setInterval(function () {
      scheduleBadgeRefresh(0);
    }, 5000);
    bindServerSettingsModeHint();
    bindStreamRecoveryWatchdog();
    startLocalLinkEventPoller();
  }

  if (document.readyState === "loading") {
    installSingleSessionWebSocketGuard();
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    installSingleSessionWebSocketGuard();
    boot();
  }
})();
