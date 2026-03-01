# WeChat Selkies

[![GitHub Stars](https://img.shields.io/github/stars/nickrunning/wechat-selkies?style=flat-square&logo=github&color=yellow)](https://github.com/nickrunning/wechat-selkies/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/nickrunning/wechat-selkies?style=flat-square&logo=github&color=blue)](https://github.com/nickrunning/wechat-selkies/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/nickrunning/wechat-selkies?style=flat-square&logo=github&color=red)](https://github.com/nickrunning/wechat-selkies/issues)
[![GitHub License](https://img.shields.io/github/license/nickrunning/wechat-selkies?style=flat-square&color=green)](https://github.com/nickrunning/wechat-selkies/blob/master/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/nickrunning/wechat-selkies?style=flat-square&logo=docker&color=blue)](https://hub.docker.com/r/nickrunning/wechat-selkies)
[![Docker Image Size](https://img.shields.io/docker/image-size/nickrunning/wechat-selkies?style=flat-square&logo=docker&color=orange)](https://hub.docker.com/r/nickrunning/wechat-selkies)
[![GitHub Release](https://img.shields.io/github/v/release/nickrunning/wechat-selkies?style=flat-square&logo=github&include_prereleases)](https://github.com/nickrunning/wechat-selkies/releases)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/nickrunning/wechat-selkies/docker.yml?style=flat-square&logo=github-actions&label=build)](https://github.com/nickrunning/wechat-selkies/actions)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/nickrunning/wechat-selkies?style=flat-square&logo=github&color=purple)](https://github.com/nickrunning/wechat-selkies/commits)

English | [中文](README.md)

Docker-based WeChat/QQ Linux client with browser access support using Selkies WebRTC technology.

## Project Overview

This project packages the official WeChat/QQ Linux client in a Docker container, enabling direct WeChat/QQ usage in browsers through Selkies technology without local installation. Suitable for server deployment, remote work, and other scenarios.

## Upgrade Notes

> If some features are missing after an upgrade, please clear the `openbox` directory in the local mounted directory (e.g., `./config/.config/openbox`).

## Features

- 🌐 **Browser Access**: Use WeChat directly through web browsers without local installation
- 🐳 **Dockerized Deployment**: Simple containerized deployment with environment isolation
- 🔒 **Data Persistence**: Supports persistent storage of configurations and chat records
- 🎨 **Chinese Support**: Complete Chinese fonts and localization support, including local Chinese input methods
- 🖼️ **Image Copy**: Support image copying through sidebar panel
- 📁 **File Transfer**: Support file transfer through sidebar panel
- 🖥️ **AMD64 and ARM64 Architecture Support**: Compatible with mainstream CPU architectures
- 🔧 **Hardware Acceleration**: Optional GPU hardware acceleration support
- 🪟 **Window Switcher**: Added a floating window switcher in the top left corner for easy switching to background windows, laying the foundation for adding other features in the future
- 🔐 **Single-Session Takeover**: A new client login disconnects old clients and returns them to the PIN page

## Recent Updates

- **AMD GPU Support**: Prefer VAAPI hardware encoding via `/dev/dri` with automatic CPU fallback.
- **Simplified PIN Login**: Password-only PIN page, no username field.
- **Improved Image Copy/Paste**: Browser `Ctrl+V` image paste to remote clipboard with optional auto-paste into chat input.
- **Auto Split Tooling**: Window right-click split plus floating split tool with three modes: left/right half, top/bottom half, and both fullscreen.
- **Low-Latency Optimization**: Tuned defaults for interaction latency, plus stream auto-recovery and X11 self-healing.
- **New QQ Support Enhancements**: Build-time latest Linux QQ URL resolution, hang detection, and auto-restart.
- **Open Links Locally**: Links triggered inside QQ/WeChat are forwarded and opened by the browser on the local client machine.

## Screenshots
![WeChat Screenshot](./docs/images/wechat-selkies-1.jpg)
![QQ Screenshot](./docs/images/wechat-selkies-2.jpg)

## Quick Start

### Requirements

- Docker
- Docker Compose
- Modern browser with WebRTC support (Chrome, Firefox, Safari, etc.)

### Quick Deployment

1. **Direct deployment using pre-built images**
GitHub Container Registry image:
```bash
docker run -it -p 3001:3001 -v ./config:/config --device /dev/dri:/dev/dri ghcr.io/nickrunning/wechat-selkies:latest
```
Docker Hub image:
```bash
docker run -it -p 3001:3001 -v ./config:/config --device /dev/dri:/dev/dri nickrunning/wechat-selkies:latest
```

2. **Access WeChat**
   
   Open in browser: `https://localhost:3001` or `https://<server-ip>:3001`
   > **Note**: 3001 port is for HTTPS access. If you need HTTP access, please map port 3000 as well.

### docker-compose Deployment
1. **Create project directory and navigate into it**
   ```bash
   mkdir wechat-selkies
   cd wechat-selkies
   ```
2. **Create `docker-compose.yml` file with the following content**
   ```yaml
    services:
      wechat-selkies:
        image: nickrunning/wechat-selkies:latest    # or ghcr.io/nickrunning/wechat-selkies:latest
        container_name: wechat-selkies
        init: true
        ports:
          - "3000:3000"       # http port
          - "3001:3001"       # https port
        restart: unless-stopped
        stop_grace_period: 1m
        volumes:
          - ./config:/config
        devices:
          - /dev/dri:/dev/dri # optional, for hardware acceleration
        pids_limit: 4096
        ulimits:
          nofile:
            soft: 65536
            hard: 65536
          nproc: 8192
        healthcheck:
          test: ["CMD-SHELL", "/scripts/healthcheck.sh"]
          interval: 30s
          timeout: 10s
          retries: 5
          start_period: 120s
        logging:
          driver: json-file
          options:
            max-size: "20m"
            max-file: "5"
        environment:
          - PUID=1000                    # user ID, set according to your system
          - PGID=100                     # group ID, set according to your system
          - TZ=Asia/Shanghai             # timezone, set according to your timezone
          - LC_ALL=zh_CN.UTF-8           # locale, set according to your needs
          - AUTO_START_WECHAT=true       # default is true
          - AUTO_START_QQ=false          # default is false
          - PROCESS_WATCHDOG=true        # process watchdog for long-running stability
          - WATCHDOG_INTERVAL=10         # watchdog check interval (seconds)
          - WATCHDOG_TRAY=true           # auto-restart stalonetray
          - WATCHDOG_RESTART_WECHAT=true # auto-restart WeChat when process exits
          - WATCHDOG_RESTART_QQ=true     # auto-restart QQ when process exits
          - WECHAT_IDLE_KEEPALIVE=true   # idle-time WeChat keepalive poke
          - WECHAT_KEEPALIVE_INTERVAL=1800      # keepalive interval in seconds
          - WECHAT_KEEPALIVE_IDLE_SECONDS=1800  # only run keepalive when idle >= this value
          - QQ_EXTRA_FLAGS=--disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-features=CalculateNativeWinOcclusion,UseSkiaRenderer
          - QQ_NICE_LEVEL=-2             # process nice level, lower value = higher priority (requires permission)
          - QQ_WATCHDOG_HANG_DETECT=true
          - QQ_WATCHDOG_FAIL_THRESHOLD=3
          - QQ_WATCHDOG_X11_PING=true
          - QQ_WATCHDOG_X11_TIMEOUT=2
          - DRI_NODE=/dev/dri/renderD128 # preferred render node for VAAPI
          - SELKIES_ENABLE_BINARY_CLIPBOARD=true
          - SELKIES_PASTE_IMAGE=true
          - SELKIES_DEFAULT_ENCODER=x264enc
          - SELKIES_DEFAULT_FRAMERATE=48
          - SELKIES_DEFAULT_GAMEPAD_ENABLED=false
          - SELKIES_DEFAULT_BINARY_CLIPBOARD=true
          - SELKIES_DEFAULT_USE_CPU=false
          - SELKIES_DEFAULT_H264_STREAMING_MODE=true
          - SELKIES_DEFAULT_USE_PAINT_OVER_QUALITY=false
          - SELKIES_DEFAULT_H264_CRF=30
          - SELKIES_STREAM_WAIT_THRESHOLD_MS=35000
          - SELKIES_STREAM_RECOVER_COOLDOWN_MS=120000
          - SELKIES_LOCAL_LINK_OPEN=true
          - SELKIES_LOCAL_LINK_POLL_INTERVAL_MS=800
          - LOCAL_LINK_BRIDGE_PORT=38080
          # - CUSTOM_USER=<Your Name>      # legacy field; kept for compatibility
          # - PASSWORD=<Your PIN>          # PIN login (password only, no username input)
        mem_reservation: "1g"            # reduce OOM risk during long-running idle sessions
        mem_limit: "2g"                  # hard limit, adjust by host capacity
        shm_size: "1gb"                  # recommended, will improve performance
    ```
3. **Start the service**
   ```bash
   docker-compose up -d
   ```

### Source Code Deployment

1. **Clone the repository**
   ```bash
   git clone https://github.com/nickrunning/wechat-selkies.git
   cd wechat-selkies
   ```

2. **Start the service**
   ```bash
   docker-compose up -d
   ```

3. **Access WeChat**

   Open in browser: `https://localhost:3001` or `https://<server-ip>:3001`

### Configuration

For more custom configurations, please refer to [Selkies Base Images from LinuxServer](https://github.com/linuxserver/docker-baseimage-selkies).

#### Docker Hub Push Configuration
This project supports pushing to both GitHub Container Registry and Docker Hub. Docker Hub push is optional and requires manual configuration. Please add the following Environment Secrets and Environment Variables in your repository to enable Docker Hub push functionality:

**Environment Secrets:**
* `DOCKERHUB_USERNAME`: Your Docker Hub username
* `DOCKERHUB_TOKEN`: Your Docker Hub Access Token

**Environment Variables:**
* `ENABLE_DOCKERHUB`: Set to `true` to enable Docker Hub push

#### Environment Variables

Configure the following environment variables in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TITLE` | `WeChat Selkies` | Web UI title |
| `PUID` | `1000` | User ID |
| `PGID` | `100` | Group ID |
| `TZ` | `Asia/Shanghai` | Timezone setting |
| `LC_ALL` | `zh_CN.UTF-8` | Locale setting |
| `CUSTOM_USER` | - | Legacy compatibility field (not required in PIN mode) |
| `PASSWORD` | - | Web UI PIN (password-only login, no username input) |
| `AUTO_START_WECHAT` | `true` | Whether to automatically start the WeChat client |
| `AUTO_START_QQ` | `false` | Whether to automatically start the QQ client |
| `PROCESS_WATCHDOG` | `true` | Enable in-container process watchdog |
| `WATCHDOG_INTERVAL` | `10` | Watchdog check interval in seconds |
| `WATCHDOG_TRAY` | `true` | Auto-restart the stalonetray process |
| `WATCHDOG_RESTART_WECHAT` | `true` | Auto-restart WeChat if process exits |
| `WATCHDOG_RESTART_QQ` | `true` | Auto-restart QQ if process exits (only when AUTO_START_QQ=true) |
| `WECHAT_IDLE_KEEPALIVE` | `true` | Periodically activate WeChat when session is idle to reduce overnight logout probability |
| `WECHAT_KEEPALIVE_INTERVAL` | `1800` | WeChat keepalive check interval in seconds |
| `WECHAT_KEEPALIVE_IDLE_SECONDS` | `1800` | Run keepalive only when user idle time exceeds this threshold |
| `QQ_EXTRA_FLAGS` | `--disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-features=CalculateNativeWinOcclusion,UseSkiaRenderer` | Extra QQ launch flags to reduce GPU-related hangs |
| `QQ_NICE_LEVEL` | `-2` | Nice level for QQ process (-20 to 19) |
| `QQ_WATCHDOG_HANG_DETECT` | `true` | Enable QQ hang detection (process alive but window unresponsive) |
| `QQ_WATCHDOG_FAIL_THRESHOLD` | `3` | Restart QQ after this many consecutive healthcheck failures |
| `QQ_WATCHDOG_X11_PING` | `true` | Use X11 window-title probe for QQ responsiveness checks |
| `QQ_WATCHDOG_X11_TIMEOUT` | `2` | X11 probe timeout in seconds |
| `DRI_NODE` | `/dev/dri/renderD128` | VAAPI render node path (GPU encoding is preferred when available) |
| `SELKIES_ENABLE_BINARY_CLIPBOARD` | `true` | Enable binary clipboard (images, etc.) |
| `SELKIES_PASTE_IMAGE` | `true` | Enable Ctrl+V image paste in browser |
| `SELKIES_PASTE_IMAGE_MAX_SIZE` | `20971520` | Max image size in bytes (default 20MB) |
| `SELKIES_PASTE_IMAGE_AUTO_PASTE` | `true` | Auto-trigger remote Ctrl+V after clipboard write |
| `SELKIES_DEFAULT_ENCODER` | `x264enc` | Default encoder (stable, low-latency profile) |
| `SELKIES_DEFAULT_FRAMERATE` | `48` | Default frame rate |
| `SELKIES_DEFAULT_GAMEPAD_ENABLED` | `false` | Default touch gamepad toggle |
| `SELKIES_DEFAULT_BINARY_CLIPBOARD` | `true` | Frontend default for binary clipboard toggle |
| `SELKIES_DEFAULT_USE_CPU` | `false` | Prefer VAAPI encoding by default (fallback to CPU when DRI is unavailable) |
| `SELKIES_DEFAULT_H264_STREAMING_MODE` | `true` | Enable H264 streaming mode by default (lower end-to-end latency) |
| `SELKIES_DEFAULT_USE_PAINT_OVER_QUALITY` | `false` | Disable static-scene paint-over quality by default (less latency spikes) |
| `SELKIES_DEFAULT_H264_CRF` | `30` | Default H264 CRF tuned to lower encode load and input delay |
| `SELKIES_STREAM_WAIT_THRESHOLD_MS` | `35000` | Auto-recovery threshold in milliseconds when UI is stuck on `Waiting for stream...` |
| `SELKIES_STREAM_RECOVER_COOLDOWN_MS` | `120000` | Auto-recovery cooldown in milliseconds to avoid refresh loops |
| `SELKIES_LOCAL_LINK_OPEN` | `true` | Enable opening QQ/WeChat links in the local browser on the client side |
| `SELKIES_LOCAL_LINK_POLL_INTERVAL_MS` | `800` | Frontend polling interval for local-link events (milliseconds) |
| `LOCAL_LINK_BRIDGE_PORT` | `38080` | In-container local-link bridge service port (must match nginx route) |
| `LOCAL_LINK_BRIDGE_MAX_EVENTS` | `256` | Local-link event queue capacity (ring buffer) |
| `LOCAL_LINK_BRIDGE_ALLOWED_SCHEMES` | `http,https,mailto` | Allowed URL schemes forwarded from container apps to local browser |

#### Image Paste (Ctrl+V)

Image paste is enabled by default. If you want to set it explicitly, keep these values as `true`:

- `SELKIES_ENABLE_BINARY_CLIPBOARD=true`
- `SELKIES_PASTE_IMAGE=true`

Optional settings:

- `SELKIES_PASTE_IMAGE_MAX_SIZE`: Max image size (default 20MB)
- `SELKIES_PASTE_IMAGE_AUTO_PASTE=false`: Disable auto Ctrl+V after clipboard write

Notes:

- Clipboard is only read on user paste (Ctrl+V or paste event)
- HTTPS or localhost is required for the Clipboard API
- At least `image/png` is supported; other formats depend on client/WeChat

#### Single-Session Takeover (new client kicks old clients)

- When a new client successfully connects, existing clients are force-disconnected and redirected back to the PIN login page.
- This helps avoid multi-client contention that can lead to `Waiting for stream...` and unstable sessions.

#### Encoder Mode Badge and VAAPI Fallback

- The default encoder profile is `x264enc` + `use_cpu=false` (prefer VAAPI).
- A `VAAPI`/`CPU` badge is displayed next to the encoder selector in video settings.
- Experimental injected encoder options that could cause black screen were removed (`vaapih264enc`, `vaapih265enc`, `vaapivp9enc`, `vaav1enc`).
- The mode badge refreshes on initial load, encoder switches, and each sidebar/video-settings reopen as `CPU` or `VAAPI`.
- If the page is stuck on `Waiting for stream...` after long idle, the frontend performs one automatic recovery reload after threshold (controlled by the two env vars above).

#### QQ Version and Performance Notes

- During image build, QQ deb URL is resolved from Tencent Linux QQ official config `linuxConfig.js` and installs the latest available package; static fallback URL is only used when parsing fails.
- If QQ is still laggy, try:
  - increasing `shm_size` and `mem_limit`
  - tuning `QQ_EXTRA_FLAGS`
  - setting a lower `QQ_NICE_LEVEL` (for example `-5`, requires permission)

#### Port Configuration

- `3001`: Web UI access port

#### Volume Mounts

- `./config:/config`: WeChat configuration and data persistence directory

> **Note:** If the right-click menu lacks `WeChat` related options after an upgrade, please clear the `openbox` directory in the local mounted directory (e.g., `./config/.config/openbox`).

## Advanced Configuration

### Hardware Acceleration

If your system supports GPU hardware acceleration, the Docker Compose configuration includes relevant device mapping:

```yaml
devices:
  - /dev/dri:/dev/dri
```

## Directory Structure

```
wechat-selkies/
├── docker-compose.yml          # Docker Compose configuration file
├── Dockerfile                  # Docker image build file
├── LICENSE                     # License
├── README.md                   # Project documentation (Chinese)
├── README_en.md                # Project documentation (English)
├── config/                     # Configuration and data persistence directory
└── root/                       # Container initialization files
    ├── defaults/
    │   └── autostart           # Auto-start configuration
    └── wechat.png              # WeChat icon
```

## Troubleshooting

### Common Issues

1. **Unable to access Web UI**
   - Check if port 3001 is occupied
   - Confirm Docker container is running normally: `docker ps`

### Overnight Security Logout Diagnosis

- Guide: `docs/ops/wechat-overnight-security-exit.md`
- Collect one evidence batch:
  - `powershell -ExecutionPolicy Bypass -File scripts/ops/collect-overnight-evidence.ps1 -ContainerName wechat-selkies`
- Generate 7-night summary:
  - `powershell -ExecutionPolicy Bypass -File scripts/ops/summarize-overnight-evidence.ps1 -InputDir diagnostics/overnight -WindowSize 7`

### Log Viewing

View container runtime logs:
```bash
docker-compose logs -f wechat-selkies
```

## Technical Architecture

- **Base Image**: `ghcr.io/linuxserver/baseimage-selkies:ubuntunoble`
- **WeChat Client**: Official WeChat Linux version
- **Web Technology**: Selkies WebRTC
- **Containerization**: Docker + Docker Compose

## Contributing

Issues and Pull Requests are welcome!

1. Fork this project
2. Create feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -am 'Add some feature'`
4. Push branch: `git push origin feature/your-feature`
5. Submit Pull Request

## License

This project is licensed under **MIT License**. See the [LICENSE](LICENSE) file for details.

### 📜 License Statement

- **Project License**: MIT License - A permissive open source license
- **Dependency Note**: This project uses [LinuxServer.io baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies) as base image
- **License Compatibility**: Since this project only uses the base image without modifying its source code, following containerized software licensing practices, it can adopt the MIT license
- **Open Source**: Complete project source code is publicly available on GitHub: https://github.com/nickrunning/wechat-selkies

## Disclaimer and Copyright Notice

### 🚨 Important Statement

**This project has no affiliation with Tencent and is an independent third-party open source project.**

### 📋 Copyright Notice

- **WeChat®** is a registered trademark and copyrighted work of **Tencent**
- The copyright of WeChat-related icons, logos and other visual elements used in this project belongs to Tencent
- This project is for technical demonstration and learning purposes only, not for commercial use
- **In case of copyright disputes, relevant content will be removed immediately**

### ⚖️ Legal Compliance

- This project strictly complies with relevant laws, regulations and user agreements
- Users should comply with local laws and regulations when using this project
- This project assumes no legal responsibility for users' actions
- **If Tencent believes there is infringement, please contact us for immediate resolution**

### 🎯 Terms of Use

- This project is for learning, research and personal use only
- Prohibited for any commercial purposes or profit-making activities
- Users should bear the risks and legal responsibilities of use
- Please comply with WeChat user agreements and related terms of service

## Related Links

- [WeChat Official Website](https://weixin.qq.com/)
- [Selkies WebRTC](https://github.com/selkies-project)
- [LinuxServer.io](https://github.com/linuxserver)
- [xiaoheiCat/docker-wechat-sogou-pinyin](https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nickrunning/wechat-selkies&type=Date)](https://www.star-history.com/#nickrunning/wechat-selkies&Date)




