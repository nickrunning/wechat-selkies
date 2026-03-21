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
- 🤖 **Auto Start**: Configurable auto-start for WeChat and QQ clients (optional)
- 📋 **Desktop Shortcut Integration**: Automatically scans `.desktop` files in `~/Desktop/` and adds them to the right-click menu, making it easy to launch third-party applications (e.g., apps installed via proot-apps)
- 🗄️ **SQLite CLI Tool**: The image includes `sqlite3` for direct database query and debugging inside the container

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
        ports:
          - "3000:3000"       # http port
          - "3001:3001"       # https port
        restart: unless-stopped
        volumes:
          - ./config:/config
        devices:
          - /dev/dri:/dev/dri # optional, for hardware acceleration
        environment:
          - PUID=1000                    # user ID, set according to your system
          - PGID=100                     # group ID, set according to your system
          - TZ=Asia/Shanghai             # timezone, set according to your timezone
          - LC_ALL=zh_CN.UTF-8           # locale, set according to your needs
          - AUTO_START_WECHAT=true       # default is true
          - AUTO_START_QQ=false          # default is false
          # - CUSTOM_USER=<Your Name>      # recommended to set a custom user name
          # - PASSWORD=<Your Password>     # recommended to set a password for selkies web ui
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
| `CUSTOM_USER` | - | Custom username (recommended) |
| `PASSWORD` | - | Web UI access password (recommended) |
| `AUTO_START_WECHAT` | `true` | Whether to automatically start the WeChat client |
| `AUTO_START_QQ` | `false` | Whether to automatically start the QQ client |

#### Port Configuration

- `3001`: Web UI access port

#### Volume Mounts

- `./config:/config`: WeChat configuration and data persistence directory

> **Note:** If the right-click menu lacks `WeChat` related options after an upgrade, please clear the `openbox` directory in the local mounted directory (e.g., `./config/.config/openbox`).

## Installing Third-Party Applications (e.g., Telegram)

This project supports installing third-party Linux applications via [proot-apps](https://github.com/linuxserver/proot-apps). Here's how to install Telegram as an example:

1. Open the container desktop in your browser
2. Click the **Sidebar** on the left → **Applications**
3. Find **Telegram** in the application list
4. Click the **Install** button and wait for the installation to complete

Once installed, the application shortcut will automatically appear in the `~/Desktop/` directory, and the **right-click menu will auto-refresh** — no container restart needed to launch the app from the menu.

> **Tip:** To uninstall an application, go to Sidebar → Applications, select the app, and click **Uninstall**. The right-click menu will update automatically.

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
