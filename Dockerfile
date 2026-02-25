# WeChat for Linux using Selkies baseimage
FROM ghcr.io/linuxserver/baseimage-selkies:ubuntunoble

# Metadata labels
LABEL org.opencontainers.image.title="WeChat Selkies"
LABEL org.opencontainers.image.description="WeChat Linux client in browser via Selkies WebRTC"
LABEL org.opencontainers.image.authors="nickrunning"
LABEL org.opencontainers.image.source="https://github.com/nickrunning/wechat-selkies"
LABEL org.opencontainers.image.documentation="https://github.com/nickrunning/wechat-selkies#readme"
LABEL org.opencontainers.image.vendor="WeChat Selkies Project"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

# Build arguments for multi-arch support
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "馃彈锔?Building WeChat-Selkies on $BUILDPLATFORM, targeting $TARGETPLATFORM"

# set environment variables
RUN apt-get update && \
    apt-get install -y fonts-noto-cjk libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-xkb1 libxkbcommon-x11-0 \
    shared-mime-info desktop-file-utils libxcb1 libxcb-icccm4 libxcb-image0 \
    libxcb-keysyms1 libxcb-randr0 libxcb-render0 libxcb-render-util0 libxcb-shape0 \
    libxcb-shm0 libxcb-sync1 libxcb-util1 libxcb-xfixes0 libxcb-xkb1 libxcb-xinerama0 \
    libxcb-xkb1 libxcb-glx0 libatk1.0-0 libatk-bridge2.0-0 libc6 libcairo2 libcups2 \
    libdbus-1-3 libfontconfig1 libgbm1 libgcc1 libgdk-pixbuf2.0-0 libglib2.0-0 \
    libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 \
    libxss1 libxtst6 libatomic1 libxcomposite1 libxrender1 libxrandr2 libxkbcommon-x11-0 \
    libfontconfig1 libdbus-1-3 libnss3 libx11-xcb1 python3-tk stalonetray xprintidle xdotool

RUN pip install --no-cache-dir python-xlib

# Install WeChat based on target architecture
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"; \
        WECHAT_ARCH="x86_64" ;; \
    "linux/arm64") \
        WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb"; \
        WECHAT_ARCH="arm64" ;; \
    *) \
        echo "鉂?Unsupported platform: $TARGETPLATFORM" >&2; \
        echo "Supported platforms: linux/amd64, linux/arm64" >&2; \
        exit 1 ;; \
    esac && \
    echo "馃摝 Downloading WeChat for $WECHAT_ARCH architecture..." && \
    curl -fsSL -o wechat.deb "$WECHAT_URL" && \
    echo "馃敡 Installing WeChat..." && \
    (dpkg -i wechat.deb || (apt-get update && apt-get install -f -y && dpkg -i wechat.deb)) && \
    rm -f wechat.deb && \
    echo "鉁?WeChat installation completed for $WECHAT_ARCH"

# Install QQ based on target architecture (resolve latest URL from official Linux QQ config)
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        QQ_ARCH_KEY="x64DownloadUrl"; \
        QQ_FALLBACK_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.22_251203_amd64_01.deb"; \
        QQ_ARCH="x86_64" ;; \
    "linux/arm64") \
        QQ_ARCH_KEY="armDownloadUrl"; \
        QQ_FALLBACK_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.22_251203_arm64_01.deb"; \
        QQ_ARCH="arm64" ;; \
    *) \
        echo "Unsupported platform: $TARGETPLATFORM" >&2; \
        echo "Supported platforms: linux/amd64, linux/arm64" >&2; \
        exit 1 ;; \
    esac && \
    QQ_CONFIG_URL="https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js" && \
    QQ_CONFIG="$(curl -fsSL "$QQ_CONFIG_URL" | tr -d '\n')" && \
    QQ_VERSION="$(echo "$QQ_CONFIG" | sed -n 's/.*\"version\":\"\([^\"]*\)\".*/\1/p')" && \
    QQ_URL="$(echo "$QQ_CONFIG" | sed -n "s/.*\"${QQ_ARCH_KEY}\":{\"deb\":\"\([^\"]*\)\".*/\1/p")" && \
    if [ -z "$QQ_URL" ]; then QQ_URL="$QQ_FALLBACK_URL"; fi && \
    echo "Downloading QQ for $QQ_ARCH architecture from: $QQ_URL (version: ${QQ_VERSION:-unknown})" && \
    curl -fsSL -o qq.deb "$QQ_URL" && \
    echo "Installing QQ..." && \
    (dpkg -i qq.deb || (apt-get update && apt-get install -f -y && dpkg -i qq.deb)) && \
    rm -f qq.deb && \
    echo "QQ installation completed for $QQ_ARCH"

# Clean up
RUN apt-get purge -y --autoremove
RUN apt-get autoclean && \
    rm -rf \
        /config/.cache \
        /config/.npm \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# configure openbox dock mode for stalonetray
RUN sed -i '/<dock>/,/<\/dock>/s/<noStrut>no<\/noStrut>/<noStrut>yes<\/noStrut>/' /etc/xdg/openbox/rc.xml

# set app name
ENV TITLE="WeChat-Selkies"
ENV TZ="Asia/Shanghai"
ENV LC_ALL="zh_CN.UTF-8"
ENV AUTO_START_WECHAT="true"
ENV AUTO_START_QQ="false"
ENV PROCESS_WATCHDOG="true"
ENV WATCHDOG_INTERVAL="10"
ENV WATCHDOG_TRAY="true"
ENV WATCHDOG_RESTART_WECHAT="true"
ENV WATCHDOG_RESTART_QQ="true"
ENV WATCHDOG_LOG_PATH="/config/logs/process-watchdog.log"
ENV X11_WATCHDOG="true"
ENV X11_WATCHDOG_FAIL_THRESHOLD="2"
ENV X11_HEALTHCHECK_TIMEOUT="2"
ENV WECHAT_IDLE_KEEPALIVE="true"
ENV WECHAT_KEEPALIVE_INTERVAL="300"
ENV WECHAT_KEEPALIVE_IDLE_SECONDS="300"
ENV WECHAT_KEEPALIVE_LOG_PATH="/config/logs/wechat-idle-keepalive.log"
ENV QQ_EXTRA_FLAGS="--disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-features=CalculateNativeWinOcclusion,UseSkiaRenderer"
ENV QQ_NICE_LEVEL="-2"
ENV QQ_WATCHDOG_HANG_DETECT="true"
ENV QQ_WATCHDOG_FAIL_THRESHOLD="3"
ENV QQ_WATCHDOG_X11_PING="true"
ENV QQ_WATCHDOG_X11_TIMEOUT="2"
ENV SELKIES_ENABLE_BINARY_CLIPBOARD="true"
ENV SELKIES_PASTE_IMAGE="true"
ENV SELKIES_DEFAULT_FRAMERATE="48"
ENV SELKIES_DEFAULT_GAMEPAD_ENABLED="false"
ENV SELKIES_DEFAULT_BINARY_CLIPBOARD="true"
ENV SELKIES_DEFAULT_ENCODER="x264enc"
ENV SELKIES_DEFAULT_USE_CPU="false"
ENV SELKIES_DEFAULT_H264_STREAMING_MODE="true"
ENV SELKIES_DEFAULT_USE_PAINT_OVER_QUALITY="false"
ENV SELKIES_DEFAULT_H264_CRF="30"
ENV SELKIES_STREAM_WAIT_THRESHOLD_MS="35000"
ENV SELKIES_STREAM_RECOVER_COOLDOWN_MS="120000"
ENV SELKIES_LOCAL_LINK_OPEN="true"
ENV SELKIES_LOCAL_LINK_POLL_INTERVAL_MS="800"
ENV LOCAL_LINK_BRIDGE_PORT="38080"
ENV LOCAL_LINK_BRIDGE_MAX_EVENTS="256"
ENV LOCAL_LINK_BRIDGE_ALLOWED_SCHEMES="http,https,mailto"
ENV LOCAL_LINK_BRIDGE_LOG_PATH="/config/logs/local-link-bridge.log"
ENV ENABLE_RIGHT_CLICK_SPLIT="true"
ENV ENABLE_SPLIT_FAB="true"
ENV SPLIT_FAB_LOG_PATH="/config/logs/split-fab.log"
ENV SPLIT_FAB_POSITION="top-center"

# update favicon
RUN cp /usr/share/icons/hicolor/128x128/apps/wechat.png /usr/share/selkies/www/icon.png

# add local files
COPY /root /

# normalize line endings for scripts copied from Windows worktrees
RUN sed -i 's/\r$//' \
    /etc/s6-overlay/s6-rc.d/init-nginx/run \
    /etc/cont-init.d/90-selkies-paste-config \
    /etc/cont-init.d/91-selkies-single-session-patch \
    /etc/cont-init.d/92-xvfb-maxclients-patch \
    /defaults/default.conf \
    /defaults/autostart \
    /defaults/menu.xml \
    /scripts/start.sh \
    /scripts/process-watchdog.sh \
    /scripts/local_link_bridge.py \
    /scripts/xdg-open-wrapper.sh \
    /scripts/x11-healthcheck.sh \
    /scripts/recover-xstack.sh \
    /scripts/healthcheck.sh \
    /scripts/window_tiler.py \
    /scripts/patch_openbox_rc.py \
    /scripts/split_fab.py \
    /scripts/wechat/*.sh \
    /scripts/qq/*.sh

# ensure custom cont-init scripts are executable
RUN chmod +x /etc/cont-init.d/90-selkies-paste-config \
    /etc/cont-init.d/91-selkies-single-session-patch \
    /etc/cont-init.d/92-xvfb-maxclients-patch \
    /etc/s6-overlay/s6-rc.d/init-nginx/run \
    /scripts/start.sh \
    /scripts/process-watchdog.sh \
    /scripts/local_link_bridge.py \
    /scripts/xdg-open-wrapper.sh \
    /scripts/x11-healthcheck.sh \
    /scripts/recover-xstack.sh \
    /scripts/healthcheck.sh \
    /scripts/window_tiler.py \
    /scripts/patch_openbox_rc.py \
    /scripts/split_fab.py \
    /scripts/wechat/*.sh \
    /scripts/qq/*.sh

RUN if [ -x /usr/bin/xdg-open ] && [ ! -x /usr/bin/xdg-open.real ]; then mv /usr/bin/xdg-open /usr/bin/xdg-open.real; fi && \
    cp /scripts/xdg-open-wrapper.sh /usr/bin/xdg-open && \
    chmod +x /usr/bin/xdg-open

