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

Docker-based WeChat/QQ Linux client with browser access support using Selkies WebRTC technology. AI agents can now operate WeChat through the API, with an optional [WeChat agent skill](#control-wechat-through-the-api-with-an-ai-agent).

## Project Overview

This project packages the official WeChat/QQ Linux client in a Docker container, enabling direct WeChat/QQ usage in browsers through Selkies technology without local installation. Suitable for server deployment, remote work, and other scenarios.

## Upgrade Notes

Before upgrading an older deployment to the new `latest`, back up `/config` and keep the `PUID` and `PGID` from your existing Compose file. WeChat may ask you to scan a QR code or confirm on your phone after an update. [Upgrade and rollback steps](#upgrade-or-roll-back-from-an-older-image)

> This repository includes automatic upstream WeChat version detection: GitHub Actions periodically checks the official `.deb` packages, updates `versions/upstream.env` when changes are detected, and then triggers the image build workflow.

## Features

- 🌐 **Browser Access**: Use WeChat directly through web browsers without local installation
- 🐳 **Dockerized Deployment**: Simple containerized deployment with environment isolation
- 🔒 **Data Persistence**: Supports persistent storage of configurations and chat records
- 🎨 **Chinese Support**: Complete Chinese fonts and localization support, including local Chinese input methods
- 📁 **File transfer**: Upload and download files in the browser sidebar’s Files panel. The default directory inside the container is `/config/Desktop`.
- 🖥️ **AMD64 and ARM64 Architecture Support**: Compatible with mainstream CPU architectures
- 🔧 **Hardware Acceleration**: Optional GPU hardware acceleration support
- 🤖 **Auto Start**: Configurable auto-start for WeChat and QQ clients (optional)
- 📋 **Desktop Shortcut Integration**: Automatically adds `.desktop` shortcuts from `~/Desktop/` to the right-click menu. Select **Reload Menu** to refresh it manually.
- 📂 **File Manager**: Built-in PCManFM lightweight file manager, accessible from the right-click menu for easy file management inside the container

## Screenshots
![WeChat Screenshot](./docs/images/wechat-selkies-1.jpg)
![QQ Screenshot](./docs/images/wechat-selkies-2.jpg)

## Quick Start

### Requirements

- Docker
- Docker Compose
- Modern browser with WebRTC support (Chrome, Firefox, Safari, etc.)

### Quick Deployment

Create a `.env` file with a nonempty `PASSWORD` and optionally set `CUSTOM_USER` (default `abc`).

1. **Direct deployment using pre-built images**
GitHub Container Registry image:
```bash
docker run -it --env-file .env -p 3001:3001 -v ./config:/config ghcr.io/nickrunning/wechat-selkies:latest
```
Docker Hub image:
```bash
docker run -it --env-file .env -p 3001:3001 -v ./config:/config nickrunning/wechat-selkies:latest
```

> **Minimal image**: If you only need WeChat (without QQ and file manager), use the `minimal` tag for a smaller image:
> ```bash
> docker run -it --env-file .env -p 3001:3001 -v ./config:/config ghcr.io/nickrunning/wechat-selkies:minimal
> ```
> Versioned minimal tags are also available, e.g. `:1.2.3-minimal`, `:1.2-minimal`, for pinning to a specific release.

2. **Access WeChat**
   
   Open in browser: `https://localhost:3001` or `https://<server-ip>:3001`
   > **Note**: 3001 port is for HTTPS access. If you need HTTP access, please map port 3000 as well.

### Docker Compose Deployment

Use this example for a new deployment. For an upgrade, keep your existing Compose file and `.env`. [Upgrade and rollback steps](#upgrade-or-roll-back-from-an-older-image)

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
       hostname: ${WECHAT_HOSTNAME:-}
       volumes:
         - ./config:/config
       ports:
         - "${HTTP_PORT:-3000}:3000"
         - "${HTTPS_PORT:-3001}:3001"
       restart: unless-stopped
       environment:
         - PUID=${PUID:-1000}
         - PGID=${PGID:-100}
         - CUSTOM_USER=${CUSTOM_USER:-abc}
         - PASSWORD=${PASSWORD:-}
         - ENABLE_WECHAT_AUTO_LOGIN=${ENABLE_WECHAT_AUTO_LOGIN:-false}
       shm_size: "${SHM_SIZE:-1gb}"
   ```
3. **Set the access password in `.env`**

   ```dotenv
   PASSWORD=replace-with-your-password
   ```
4. **Start the service**
   ```bash
   docker compose up -d
   ```

### Source Code Deployment

1. **Clone the repository**
   ```bash
   git clone https://github.com/nickrunning/wechat-selkies.git
   cd wechat-selkies
   ```

2. **Copy the configuration, set `PASSWORD` in `.env`, and build**

   ```bash
   cp .env.example .env
   # Edit .env and set PASSWORD before running the next command.
   docker compose up -d --build
   ```

3. **Access WeChat**

   Open in browser: `https://localhost:3001` or `https://<server-ip>:3001`

> **Build minimal version**: When building from source, use build-arg to create a WeChat-only image:
> ```bash
> docker build --build-arg INSTALL_QQ=false --build-arg INSTALL_PCMANFM=false -t wechat-selkies:minimal .
> ```

When building from source, set `INSTALL_QQ=false` in `.env` to omit QQ.

### Upgrade or roll back from an older image

The `latest` tag follows stable releases. The `edge` tag follows builds from `master`.

1. **Record the settings and back up.** Keep your Compose file, `.env`, and current image version or digest. If you omitted `PUID` and `PGID`, run `docker exec wechat-selkies id abc` before stopping the old LinuxServer container to see its actual IDs. Stop the container and back up all of `/config`, preserving numeric ownership and permissions.
2. **Reuse the existing configuration.** Mount the same data at `/config` and keep the previous container's UID/GID. The supplied Compose file defaults to `1000:100`, and a direct `docker run` defaults to `911:911`. Set the old IDs explicitly if you switch deployment methods.
3. **Verify or roll back.** Open WeChat after recreating the container and check your account and chat history. If the profile looks empty or access is denied, check the volume path, the active account directory’s owner, and any NAS ACLs. Archived accounts can stay read-only. Avoid recursive permission changes across the volume. To roll back, stop the new container, restore the backup and original configuration, then start the recorded image version or digest.

These three cases apply to custom deployments.

- **Reverse proxy**. You can keep the SWAG rule that forwards the whole site, including WebSockets, to `https://wechat-selkies:3001`. If you routed WebSockets to a separate `CUSTOM_WS_PORT`, point that rule at the same upstream address and port as the web page. `CUSTOM_PORT` and `CUSTOM_HTTPS_PORT` still set the web listener ports.
  If web login succeeds but the desktop cannot connect and the container logs show `disallowed Origin`, set `SELKIES_ALLOWED_ORIGINS=https://wechat.example.com` in the WeChat service's Compose `environment` and recreate the container. Use the scheme and hostname from the browser address, including any non-default port. Separate multiple origins with commas.
- **Desktop restrictions**. If you enabled LinuxServer switches such as `HARDEN_DESKTOP`, `HARDEN_OPENBOX`, or `DISABLE_SUDO`, the new container reports an error and exits. Verify that the new deployment enforces your original access restrictions before removing those switches from Compose.
- **Custom scripts**. If a host directory is mounted over `/scripts`, update the scripts in that directory to match the new image.

### Control WeChat through the API with an AI agent

Sign in to WeChat in the browser desktop. Your agent can then open a specific chat, read visible messages, or send a message at your request. The API is enabled by default. Append `/api/pelorus/` to your desktop URL and use the same web username and password (HTTP Basic authentication). External agents do not need a model key in the container.

**Install the WeChat skill.** On the machine where your agent runs, open the project directory where you want to use the skill. With Node.js 22.20 or later, run the following command and select Codex, Claude Code, or another supported agent when prompted.

```bash
npx skills add nickrunning/wechat-selkies --skill wechat-selkies
```

The skill is installed in the current project by default. Append `-g` to use it across projects. If you do not have Node.js, you can give [SKILL.md](skills/wechat-selkies/SKILL.md) directly to an agent that can make HTTP requests. [Installer documentation](https://github.com/vercel-labs/skills#install-a-skill)

Give the agent an HTTPS desktop URL it can reach and configure its web login credentials. Then try asking it to use the wechat-selkies skill to open File Transfer Assistant and read the latest visible message.

To list desktop windows on a local deployment, run the command below and enter your web password when prompted. The default username is `abc`. Use `-k` only for the local self-signed certificate.

```bash
curl -kfsS -u abc https://localhost:3001/api/pelorus/desktop
```

The optional `/pelorus/` page lets you give instructions to a built-in assistant. Configure a model there if you want to use that assistant.

### Configuration

#### Docker Hub Push Configuration
This project supports pushing to both GitHub Container Registry and Docker Hub. Docker Hub push is optional and requires manual configuration. Please add the following Environment Secrets and Environment Variables in your repository to enable Docker Hub push functionality:

**Environment Secrets:**
* `DOCKERHUB_USERNAME`: Your Docker Hub username
* `DOCKERHUB_TOKEN`: Your Docker Hub Access Token

**Environment Variables:**
* `ENABLE_DOCKERHUB`: Set to `true` to enable Docker Hub push

#### Environment Variables

To use additional `.env` variables with the quick-start example, add their entries to the service’s `environment` section. See the repository’s [docker-compose.yml](docker-compose.yml).

| Variable | Default | Description |
|----------|---------|-------------|
| `TITLE` | `WeChat-Selkies` | Web UI title |
| `PUID` | `1000` with Compose, `911` with `docker run` | Desktop session user ID |
| `PGID` | `100` with Compose, `911` with `docker run` | Desktop session group ID |
| `TZ` | `Asia/Shanghai` | Timezone setting |
| `LC_ALL` | `zh_CN.UTF-8` | Locale setting |
| `CUSTOM_USER` | `abc` | Web UI username |
| `PASSWORD` | - | Desktop and API password |
| `AUTO_START_WECHAT` | `true` | Whether to automatically start the WeChat client |
| `AUTO_START_QQ` | `false` | Whether to automatically start the QQ client |
| `ENABLE_WECHAT_NIGHTLY_RESTART` | `false` | Whether to enable nightly auto-stop and auto-restart for WeChat |
| `WECHAT_NIGHTLY_STOP_TIME` | `23:30` | Daily scheduled stop time for WeChat (HH:MM format) |
| `WECHAT_NIGHTLY_START_TIME` | `01:30` | Daily scheduled restart time for WeChat (HH:MM format) |
| `ENABLE_WECHAT_AUTO_LOGIN` | `false` in Compose, `true` with `docker run` | Whether to automatically detect and click the login button after WeChat starts/restarts |
| `AUTO_LOGIN_DELAY` | `3` | Delay in seconds after WeChat launch to wait for UI rendering before login action |

To use a password file, leave `PASSWORD` empty and set `SELKIES_BASIC_AUTH_PASSWORD_FILE` in the container environment to a file readable by the desktop user. Existing LinuxServer deployments can continue using `FILE__PASSWORD`.

#### Port Configuration

- Compose uses `HTTP_PORT` and `HTTPS_PORT` for host ports, defaulting to `3000` and `3001`.
- To change a container listener, set `SELKIES_PORT` or `SELKIES_HTTPS_PORT` in the service’s `environment` section and update the container side of the corresponding `ports` mapping.

#### Volume Mounts

- `./config:/config`: WeChat configuration and data persistence directory

## Advanced Configuration

### Hardware Acceleration

If your host has `/dev/dri`, add the following mapping to the Compose service to enable GPU hardware acceleration.

```yaml
devices:
  - /dev/dri:/dev/dri
```

## Directory Structure

```
wechat-selkies/
├── docker-compose.yml          # Docker Compose configuration file
├── .env.example                # Environment variables example file
├── Dockerfile                  # Docker image build file
├── LICENSE                     # License
├── README.md                   # Project documentation (Chinese)
├── README_en.md                # Project documentation (English)
├── config/                     # Configuration and data persistence directory
└── root/                       # Container initialization files
    ├── defaults/              # Menu template
    └── scripts/               # Container and application startup scripts
```

## Troubleshooting

### WeChat search closes or typing goes to the chat

If you use a custom `/config/.config/openbox/rc.xml`, copy the `<application>` rule from the [image configuration](root/etc/xdg/openbox/rc.xml) into the first `<applications>` section, before general WeChat or wildcard rules, then restart the container.

### Updating WeChat/QQ Version

When WeChat or QQ displays a "version outdated" message, pull an updated image from your chosen release channel and recreate the container. Your chat history and configurations will be preserved:

```bash
# Using pre-built images
docker compose pull && docker compose up -d

# Using source code build
git pull && docker compose up -d --build
```

> **Note:** WeChat uses its official update URLs. QQ detection tries the latest official packages first, then the previously successful URLs and backup versions if downloads fail, and records the URLs actually used. CI builds use the URLs and SHA256 hashes in `versions/upstream.env` to verify packages.

For maintainers, the current automation flow is:

1. `Detect Upstream Package Updates` checks the official WeChat and QQ packages every 6 hours and can also be triggered manually
2. If a successful download URL, version, or package hash changes, the workflow updates `versions/upstream.env`
3. After committing the changes to `master`, detection explicitly triggers `Build and Publish Docker Image` with `workflow_dispatch` (`GITHUB_TOKEN` pushes do not trigger other push workflows)
4. Builds receive package SHA256 hashes to refresh download caches when packages change and verify files before installation. Image publishing runs serially to reduce rate limits caused by concurrent pushes

The version state file is stored at `versions/upstream.env` and currently records:

- Successful WeChat and QQ amd64/arm64 download URLs
- Parsed WeChat and QQ amd64/arm64 package versions
- WeChat and QQ amd64/arm64 package SHA256 hashes
- The last detection time that actually changed the tracked state

### Common Issues

1. **Unable to access Web UI**
   - Check if port 3001 is occupied
   - Confirm Docker container is running normally: `docker ps`

### Log Viewing

View container runtime logs:
```bash
docker compose logs -f wechat-selkies
```

## Technical Architecture

- **Base Image**: `ghcr.io/selkies-project/selkies/base:main-ubuntu26.04`
- **WeChat Client**: Official WeChat Linux version
- **Web Technology**: Selkies WebRTC
- **Desktop and API**: The built-in Selkies X11 window manager reads Openbox-format menus and supports a subset of Openbox window rules. Pelorus provides the desktop control API. The desktop page and its installed web app use `TITLE` and the WeChat icon. The web assistant uses the Pelorus name and icon. [Upstream API](https://github.com/selkies-project/selkies/blob/f956c26/crates/selkies/src/pelorus.rs)
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
- [xiaoheiCat/docker-wechat-sogou-pinyin](https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nickrunning/wechat-selkies&type=Date)](https://www.star-history.com/#nickrunning/wechat-selkies&Date)
