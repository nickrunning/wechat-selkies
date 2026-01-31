(function () {
  const config = window.__SELKIES_PASTE_IMAGE__ || {};
  const enabled = String(config.enabled).toLowerCase() === "true";
  if (!enabled) {
    return;
  }

  const maxBytes = Number(config.maxBytes) > 0 ? Number(config.maxBytes) : 20971520;
  const autoPaste = config.autoPaste !== false;
  let binaryClipboardEnabled = null;
  let busy = false;
  let ignorePaste = false;

  function isEditableTarget(target) {
    if (!target) return false;
    if (target.isContentEditable) return true;
    const tag = (target.tagName || "").toUpperCase();
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return true;
    return !!target.closest && !!target.closest("[contenteditable='true']");
  }

  function ensureToastContainer() {
    let container = document.getElementById("selkies-paste-toast-container");
    if (container) return container;

    const style = document.createElement("style");
    style.textContent =
      "#selkies-paste-toast-container{position:fixed;top:16px;right:16px;z-index:9999;display:flex;flex-direction:column;gap:8px;}" +
      ".selkies-paste-toast{background:#1f2937;color:#fff;padding:8px 12px;border-radius:6px;font-size:12px;box-shadow:0 4px 12px rgba(0,0,0,0.2);max-width:320px;}" +
      ".selkies-paste-toast.success{background:#0f766e;}" +
      ".selkies-paste-toast.warn{background:#92400e;}" +
      ".selkies-paste-toast.error{background:#b91c1c;}";
    document.head.appendChild(style);

    container = document.createElement("div");
    container.id = "selkies-paste-toast-container";
    document.body.appendChild(container);
    return container;
  }

  function showToast(message, level) {
    const container = ensureToastContainer();
    const toast = document.createElement("div");
    toast.className = "selkies-paste-toast" + (level ? " " + level : "");
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(() => {
      toast.remove();
    }, 4000);
  }

  function sendRemoteCtrlV() {
    const input = window.webrtcInput;
    if (!input || typeof input._sendKeyEvent !== "function") {
      return false;
    }
    input._sendKeyEvent(65507, "ControlLeft", true);
    input._sendKeyEvent(118, "KeyV", true);
    input._sendKeyEvent(118, "KeyV", false);
    input._sendKeyEvent(65507, "ControlLeft", false);
    return true;
  }

  function isPasteShortcut(event) {
    if (!event) return false;
    const key = String(event.key || "").toLowerCase();
    if (key !== "v") return false;
    return (event.ctrlKey || event.metaKey) && !event.altKey;
  }

  async function readClipboardPayload() {
    if (!window.isSecureContext || !navigator.clipboard) {
      showToast("Clipboard access requires HTTPS and permissions.", "warn");
      return null;
    }

    if (navigator.clipboard.read) {
      try {
        const items = await navigator.clipboard.read();
        if (!items || items.length === 0) return null;
        for (const item of items) {
          const imageType = item.types.find((t) => t.startsWith("image/"));
          if (imageType) {
            const blob = await item.getType(imageType);
            return {
              type: "image",
              mime: imageType,
              size: blob.size,
              buffer: await blob.arrayBuffer()
            };
          }
        }
        if (items[0] && items[0].types.includes("text/plain")) {
          const text = await (await items[0].getType("text/plain")).text();
          if (!text) return null;
          return { type: "text", text };
        }
      } catch (err) {
        showToast("Clipboard read failed. Check browser permissions.", "warn");
        return null;
      }
    }

    if (navigator.clipboard.readText) {
      try {
        const text = await navigator.clipboard.readText();
        if (!text) return null;
        return { type: "text", text };
      } catch (err) {
        showToast("Clipboard readText failed. Check browser permissions.", "warn");
        return null;
      }
    }

    showToast("Clipboard API not available in this browser.", "warn");
    return null;
  }

  async function sendClipboardPayload(payload) {
    if (!payload) return false;
    if (!window.selkiesSendClipboard || typeof window.selkiesSendClipboard !== "function") {
      showToast("Clipboard bridge not ready.", "error");
      return false;
    }

    if (payload.type === "image") {
      if (binaryClipboardEnabled === false) {
        showToast("Binary clipboard disabled on server.", "error");
        return false;
      }
      if (payload.size > maxBytes) {
        showToast("Image exceeds max size limit.", "warn");
        return false;
      }
      await window.selkiesSendClipboard(payload.buffer, payload.mime);
      showToast("Image sent to remote clipboard.", "success");
      return true;
    }

    if (payload.type === "text") {
      await window.selkiesSendClipboard(payload.text, "text/plain");
      return true;
    }

    return false;
  }

  async function handlePasteShortcut() {
    if (busy) return;
    busy = true;
    try {
      const payload = await readClipboardPayload();
      if (!payload) {
        if (autoPaste) {
          sendRemoteCtrlV();
        }
        return;
      }
      const sent = await sendClipboardPayload(payload);
      if (sent && autoPaste) {
        await new Promise((resolve) => setTimeout(resolve, 60));
        const ok = sendRemoteCtrlV();
        if (!ok) {
          showToast("Remote paste not available. Use Ctrl+V in session.", "warn");
        }
      }
    } finally {
      busy = false;
    }
  }

  function extractImageFromClipboardData(clipboardData) {
    if (!clipboardData || !clipboardData.items) return null;
    for (const item of clipboardData.items) {
      if (item.kind === "file" && item.type.startsWith("image/")) {
        const blob = item.getAsFile();
        if (!blob) return null;
        return { blob, mime: item.type, size: blob.size };
      }
    }
    return null;
  }

  document.addEventListener(
    "keydown",
    (event) => {
      if (!isPasteShortcut(event)) return;
      if (event.isComposing || event.keyCode === 229) return;
      if (isEditableTarget(event.target)) return;
      ignorePaste = true;
      setTimeout(() => {
        ignorePaste = false;
      }, 500);
      event.preventDefault();
      event.stopImmediatePropagation();
      handlePasteShortcut();
    },
    true
  );

  document.addEventListener(
    "paste",
    (event) => {
      if (ignorePaste) return;
      if (isEditableTarget(event.target)) return;
      const imageInfo = extractImageFromClipboardData(event.clipboardData);
      if (!imageInfo) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      if (imageInfo.size > maxBytes) {
        showToast("Image exceeds max size limit.", "warn");
        return;
      }
      if (binaryClipboardEnabled === false) {
        showToast("Binary clipboard disabled on server.", "error");
        return;
      }
      if (!window.selkiesSendClipboard || typeof window.selkiesSendClipboard !== "function") {
        showToast("Clipboard bridge not ready.", "error");
        return;
      }
      imageInfo.blob.arrayBuffer().then((buffer) => {
        return window.selkiesSendClipboard(buffer, imageInfo.mime);
      }).then(() => {
        showToast("Image sent to remote clipboard.", "success");
        if (autoPaste) {
          setTimeout(() => {
            const ok = sendRemoteCtrlV();
            if (!ok) {
              showToast("Remote paste not available. Use Ctrl+V in session.", "warn");
            }
          }, 60);
        }
      }).catch(() => {
        showToast("Failed to send image clipboard.", "error");
      });
    },
    true
  );

  window.addEventListener("message", (event) => {
    if (event.origin !== window.location.origin) return;
    const data = event.data || {};
    if (data.type === "serverSettings" && data.payload && data.payload.enable_binary_clipboard) {
      const value = data.payload.enable_binary_clipboard.value;
      if (typeof value === "boolean") {
        binaryClipboardEnabled = value;
      }
    }
  });
})();
