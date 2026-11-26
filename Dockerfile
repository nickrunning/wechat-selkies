# WeChat for Linux using Selkies baseimage
FROM ghcr.io/selkies-project/selkies/base:main-ubuntu26.04@sha256:50dac7381d2aa306cd7fb2084feb331f37d6007bd7042df5786438eafd19530e

USER 0
SHELL ["/bin/sh", "-c"]
WORKDIR /tmp

# Metadata labels
LABEL org.opencontainers.image.title="WeChat Selkies"
LABEL org.opencontainers.image.description="WeChat Linux client in a browser via Selkies WebRTC, with Pelorus API access for AI agents"
LABEL org.opencontainers.image.authors="nickrunning"
LABEL org.opencontainers.image.source="https://github.com/nickrunning/wechat-selkies"
LABEL org.opencontainers.image.documentation="https://github.com/nickrunning/wechat-selkies#readme"
LABEL org.opencontainers.image.vendor="WeChat Selkies Project"
LABEL org.opencontainers.image.licenses="MIT"

# Build arguments for multi-arch support
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG INSTALL_QQ=true
ARG INSTALL_PCMANFM=true
RUN echo "🏗️ Building WeChat-Selkies on $BUILDPLATFORM, targeting $TARGETPLATFORM"

RUN apt-get update && apt-get install -y --no-install-recommends \
        fonts-noto-cjk python3-gi gir1.2-atspi-2.0 at-spi2-core inotify-tools xterm locales \
        libatk1.0-0t64 libatk-bridge2.0-0t64 && \
    localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 && \
    if [ "$INSTALL_PCMANFM" = "true" ]; then apt-get install -y --no-install-recommends pcmanfm; fi

# Install WeChat based on target architecture
ARG WECHAT_AMD64_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"
ARG WECHAT_ARM64_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb"
ARG WECHAT_AMD64_SHA256
ARG WECHAT_ARM64_SHA256
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        WECHAT_URL="$WECHAT_AMD64_URL"; \
        WECHAT_SHA256="$WECHAT_AMD64_SHA256"; \
        WECHAT_ARCH="x86_64" ;; \
    "linux/arm64") \
        WECHAT_URL="$WECHAT_ARM64_URL"; \
        WECHAT_SHA256="$WECHAT_ARM64_SHA256"; \
        WECHAT_ARCH="arm64" ;; \
    *) \
        echo "❌ Unsupported platform: $TARGETPLATFORM" >&2; \
        echo "Supported platforms: linux/amd64, linux/arm64" >&2; \
        exit 1 ;; \
    esac && \
    echo "📦 Downloading WeChat for $WECHAT_ARCH architecture..." && \
    curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 --retry-delay 10 --retry-connrefused -o wechat.deb "$WECHAT_URL" && \
    if [ -n "$WECHAT_SHA256" ]; then echo "$WECHAT_SHA256  wechat.deb" | sha256sum -c -; fi && \
    echo "🔧 Installing WeChat..." && \
    (dpkg -i wechat.deb || (apt-get update && apt-get install -f -y && dpkg -i wechat.deb)) && \
    rm -f wechat.deb && \
    echo "✅ WeChat installation completed for $WECHAT_ARCH"

# Install QQ based on target architecture (optional)
ARG INSTALL_QQ
ARG QQ_AMD64_URL="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/c97651b2/QQ_3.2.32_260730_amd64_01.deb"
ARG QQ_ARM64_URL="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/c97651b2/QQ_3.2.32_260730_arm64_01.deb"
ARG QQ_AMD64_SHA256=81ae2b8542ef5311fc72ecf53c9a523923c834569c7b0da52e0bf4360b9cb5f9
ARG QQ_ARM64_SHA256=ecc02e27b0ae55aba721f0671d44a919c26643456674a1857a2d0cde806e0d7e
RUN if [ "$INSTALL_QQ" = "true" ]; then \
        case "$TARGETPLATFORM" in \
        "linux/amd64") \
            QQ_URL="$QQ_AMD64_URL"; \
            QQ_SHA256="$QQ_AMD64_SHA256"; \
            QQ_ARCH="x86_64" ;; \
        "linux/arm64") \
            QQ_URL="$QQ_ARM64_URL"; \
            QQ_SHA256="$QQ_ARM64_SHA256"; \
            QQ_ARCH="arm64" ;; \
        *) \
            echo "❌ Unsupported platform: $TARGETPLATFORM" >&2; \
            exit 1 ;; \
        esac && \
        echo "📦 Downloading QQ for $QQ_ARCH architecture..." && \
        (curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 -o qq.deb "$QQ_URL" || \
         { test -n "$QQ_SHA256" && curl -fsSL --retry 3 -o qq.deb \
           "https://github.com/Rodert/qq-versions/releases/download/qq-packages-20260730-8b1562d3/${QQ_URL##*/}"; }) && \
        if [ -n "$QQ_SHA256" ]; then echo "$QQ_SHA256  qq.deb" | sha256sum -c -; fi && \
        echo "🔧 Installing QQ..." && \
        (dpkg -i qq.deb || (apt-get update && apt-get install -f -y && dpkg -i qq.deb)) && \
        rm -f qq.deb && \
        echo "✅ QQ installation completed for $QQ_ARCH"; \
    else \
        echo "⏭️ Skipping QQ installation (INSTALL_QQ=$INSTALL_QQ)"; \
    fi

# set app name
ENV TITLE="WeChat-Selkies"
ENV TZ="Asia/Shanghai"
ENV LANG="zh_CN.UTF-8" LANGUAGE="zh_CN:zh" LC_ALL="zh_CN.UTF-8"
ENV AUTO_START_WECHAT="true"
ENV AUTO_START_QQ="false"
ENV ENABLE_WECHAT_NIGHTLY_RESTART="false"
ENV WECHAT_NIGHTLY_STOP_TIME="23:30"
ENV WECHAT_NIGHTLY_START_TIME="01:30"
ENV ENABLE_WECHAT_AUTO_LOGIN="true"
ENV AUTO_LOGIN_DELAY="3"

ENV HOME=/config \
    SELKIES_WM=true \
    SELKIES_DESKTOP=true \
    SELKIES_WM_MAXIMIZE=false \
    SELKIES_PELORUS=true \
    SELKIES_PORT="" \
    SELKIES_ENABLE_HTTPS=false \
    SELKIES_HTTPS_PORT="" \
    QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
    SELKIES_UI_ICON=/usr/share/icons/hicolor/512x512/apps/wechat.png

RUN mkdir -p /etc/xdg/openbox /config && chown ubuntu:ubuntu /config && \
    usermod -d /config ubuntu && rm -rf /var/lib/apt/lists/*
COPY root/ /
COPY root/defaults/autostart /etc/xdg/openbox/autostart
VOLUME /config
WORKDIR /config
EXPOSE 3000 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD prefix="${SELKIES_SUBFOLDER:-${SUBFOLDER:-/}}"; prefix="${prefix#/}"; prefix="${prefix%/}"; \
        url="localhost:${SELKIES_PORT:-${CUSTOM_PORT:-3000}}${prefix:+/${prefix}}/api/health"; \
        curl -fs -o /dev/null "http://$url" || curl -kfsS -o /dev/null "https://$url"
ENTRYPOINT ["/wechat-container-start"]
