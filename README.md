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

中文 | [English](README_en.md)

基于 Docker 的微信/QQ Linux 客户端，使用 Selkies WebRTC 技术提供浏览器访问支持。现已支持 AI Agent 通过 API 操作微信，并提供可安装的 [Agent Skill](#ai-agent-通过-api-操作微信)。

## 项目简介

本项目将官方微信/QQ Linux 客户端封装在 Docker 容器中，通过 Selkies 技术实现在浏览器中直接使用微信/QQ，无需在本地安装微信/QQ 客户端。适用于服务器部署、远程办公等场景。

## 升级注意事项

从旧版切换到新版 `latest` 前，请先备份 `/config`，并保留原 Compose 中的 `PUID` 和 `PGID`。微信更新后可能需要重新扫码或在手机上确认。[升级与回滚步骤](#从旧版升级或回滚)

> 仓库内置了上游微信版本自动检测机制：GitHub Actions 会定时检查官方 `.deb` 包版本，检测到变化后自动更新 `versions/upstream.env` 并触发镜像构建。

## 功能特性

- 🌐 **浏览器访问**：通过 Web 浏览器直接使用微信，无需本地安装
- 🐳 **Docker化部署**：简单的容器化部署，环境隔离
- 🔒 **数据持久化**：支持配置和聊天记录持久化存储
- 🎨 **中文支持**：完整的中文字体和本地化支持，支持本地中文输入法
- 📁 **文件传输**：在浏览器侧栏的“文件”面板上传和下载文件，默认目录为容器内的 `/config/Desktop`。
- 🖥️ **AMD64和ARM64架构支持**：兼容主流CPU架构
- 🔧 **硬件加速**：可选的 GPU 硬件加速支持
- 🤖 **自动启动**：可配置自动启动微信和QQ客户端（可选）
- 📋 **桌面快捷方式集成**：自动将 `~/Desktop/` 下的 `.desktop` 快捷方式添加到右键菜单，也可选择 **Reload Menu** 手动刷新
- 📂 **文件管理器**：内置 PCManFM 轻量文件管理器，右键菜单即可启动，方便管理容器内文件

## 截图展示
![微信截图](./docs/images/wechat-selkies-1.jpg)
![QQ截图](./docs/images/wechat-selkies-2.jpg)

## 快速开始

### 环境要求

- Docker
- Docker Compose
- 支持WebRTC的现代浏览器（Chrome、Firefox、Safari等）

### 快速部署

创建 `.env` 文件并设置非空的 `PASSWORD`，可通过 `CUSTOM_USER` 指定用户名（默认 `abc`）。

1. **直接使用已构建的镜像进行快速部署**

GitHub Container Registry镜像：
```bash
docker run -it --env-file .env -p 3001:3001 -v ./config:/config ghcr.io/nickrunning/wechat-selkies:latest
```

Docker Hub镜像：
```bash
docker run -it --env-file .env -p 3001:3001 -v ./config:/config nickrunning/wechat-selkies:latest
```

> **精简版镜像**：如果只需要微信（不含 QQ 和文件管理器），可使用 `minimal` 标签，镜像体积更小：
> ```bash
> docker run -it --env-file .env -p 3001:3001 -v ./config:/config ghcr.io/nickrunning/wechat-selkies:minimal
> ```
> 精简版也支持版本号标签，如 `:1.2.3-minimal`、`:1.2-minimal`，方便锁定特定版本。

2. **访问微信**
   
   在浏览器中访问：`https://localhost:3001` 或 `https://<服务器IP>:3001`
   > **注意：** 映射3000端口用于HTTP访问，3001端口用于HTTPS访问，建议使用HTTPS。

### Docker Compose 部署

以下示例用于首次部署。升级时请沿用原 Compose 文件和 `.env`。[升级与回滚步骤](#从旧版升级或回滚)

1. **创建项目目录并进入**
   ```bash
   mkdir wechat-selkies
   cd wechat-selkies
   ```
2. **创建 docker-compose.yml 文件**
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
3. **在 `.env` 中设置访问密码**

   ```dotenv
   PASSWORD=replace-with-your-password
   ```
4. **启动服务**
   ```bash
   docker compose up -d
   ```

### 源码部署

1. **克隆项目**
   ```bash
   git clone https://github.com/nickrunning/wechat-selkies.git
   cd wechat-selkies
   ```

2. **复制配置，在 `.env` 中设置 `PASSWORD`，然后构建并启动**

   ```bash
   cp .env.example .env
   # 先编辑 .env 并设置 PASSWORD，再执行下一条命令。
   docker compose up -d --build
   ```

3. **访问微信**

   在浏览器中访问：`https://localhost:3001` 或 `https://<服务器IP>:3001`

> **构建精简版**：源码部署时可通过 build-arg 构建仅含微信的精简镜像：
> ```bash
> docker build --build-arg INSTALL_QQ=false --build-arg INSTALL_PCMANFM=false -t wechat-selkies:minimal .
> ```

从源码构建时，可在 `.env` 中设置 `INSTALL_QQ=false` 跳过 QQ 安装。

### 从旧版升级或回滚

`latest` 跟随稳定版发布，`edge` 跟随 `master` 构建。

1. **记录并备份。** 保留原 Compose 文件、`.env` 和镜像版本或摘要。如果旧配置没有写 `PUID`、`PGID`，可在停机前运行 `docker exec wechat-selkies id abc` 查看旧 LinuxServer 容器的实际身份。停止容器后备份完整的 `/config`，备份应保留数字属主和权限。
2. **沿用原配置。** 新容器继续挂载同一份 `/config`，保留原容器的 UID/GID。仓库提供的 Compose 默认使用 `1000:100`，直接 `docker run` 默认使用 `911:911`。如果切换了部署方式，请显式填写旧值。
3. **验证与回滚。** 重建后打开微信，检查原账号和聊天记录。若数据看似为空或提示权限不足，先核对挂载路径，再检查当前账号目录的属主和 NAS ACL。旧账号可以只读归档，无需递归修改整个卷的权限。如需回滚，停掉新版，恢复备份和原部署配置，用记录的镜像版本或摘要启动。

以下三项只涉及定制部署。

- **反向代理**。如果 SWAG 已将整个站点转发到 `https://wechat-selkies:3001` 并启用 WebSocket，可以沿用这条转发规则。若以前单独转发到 `CUSTOM_WS_PORT`，请改为与网页相同的上游地址和端口。`CUSTOM_PORT` 和 `CUSTOM_HTTPS_PORT` 仍可指定容器的 Web 端口。
  如果网页能登录，但桌面连不上，且容器日志出现 `disallowed Origin`，在微信服务的 Compose `environment` 中设置 `SELKIES_ALLOWED_ORIGINS=https://wechat.example.com` 后重建容器。将示例替换为浏览器实际访问的协议、域名和非默认端口，多个来源用逗号分隔。
- **桌面限制**。如果启用了 LinuxServer 的 `HARDEN_DESKTOP`、`HARDEN_OPENBOX`、`DISABLE_SUDO` 等开关，新容器会提示并退出。先确认新版部署满足原有访问限制，再从 Compose 中移除相应开关。
- **自定义脚本**。如果用宿主机目录覆盖了容器的 `/scripts`，请把新版脚本同步到该目录。

### AI Agent 通过 API 操作微信

先在浏览器桌面登录微信。你的 AI Agent 可以通过 API 打开指定会话、读取界面上可见的消息，或按你的指示发送消息。API 默认开启，地址是桌面网址后加 `/api/pelorus/`，使用同一组 Web 用户名和密码（HTTP Basic 认证），无需在容器中配置模型密钥。

**安装微信操作技能**。在运行 Agent 的电脑上，进入你希望使用技能的项目目录。使用 Node.js 22.20 或更高版本运行以下命令，按提示选择 Codex、Claude Code 或其他受支持的 Agent。

```bash
npx skills add nickrunning/wechat-selkies --skill wechat-selkies
```

默认只安装到当前项目。要在多个项目中使用，可在命令末尾加 `-g`。没有 Node.js 时，也可将 [SKILL.md](skills/wechat-selkies/SKILL.md) 直接交给能调用 HTTP 的 Agent 阅读。[安装工具说明](https://github.com/vercel-labs/skills#install-a-skill)

安装后，给 Agent 配置它能访问的 HTTPS 桌面地址和 Web 登录凭据，再试一句：“使用 wechat-selkies 技能打开文件传输助手，读出最新一条可见消息。”

在本机测试时，下面的命令会提示输入 Web 密码，并列出桌面窗口。用户名默认是 `abc`，`-k` 仅用于本机自签名证书。

```bash
curl -kfsS -u abc https://localhost:3001/api/pelorus/desktop
```

`/pelorus/` 是可选的网页助手。只有想直接在这个页面给助手下指令时，才需要在页面中配置模型。

### 配置说明

#### Docker Hub 推送配置

本项目支持同时推送到 GitHub Container Registry 和 Docker Hub。如需启用 Docker Hub 推送功能，请在仓库下添加Environment Secrets和Environment Variables:

**Environment Secrets:**
* DOCKERHUB_USERNAME: 你的 Docker Hub 用户名
* DOCKERHUB_TOKEN: 你的 Docker Hub Access Token
**Environment Variables:**
* ENABLE_DOCKERHUB: 设置为 `true` 来启用 Docker Hub 推送

#### 环境变量配置

若需在快速部署示例中使用更多 `.env` 变量，请将相应项加入服务的 `environment`。可参考仓库的 [docker-compose.yml](docker-compose.yml)。

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `TITLE` | `WeChat-Selkies` | Web UI 标题 |
| `PUID` | Compose 为 `1000`，`docker run` 为 `911` | 桌面会话的用户 ID |
| `PGID` | Compose 为 `100`，`docker run` 为 `911` | 桌面会话的组 ID |
| `TZ` | `Asia/Shanghai` | 时区设置 |
| `LC_ALL` | `zh_CN.UTF-8` | 语言环境 |
| `CUSTOM_USER` | `abc` | Web UI 用户名 |
| `PASSWORD` | - | 桌面和 API 的访问密码 |
| `AUTO_START_WECHAT` | `true` | 是否自动启动微信客户端 |
| `AUTO_START_QQ` | `false` | 是否自动启动 QQ 客户端 |
| `ENABLE_WECHAT_NIGHTLY_RESTART` | `false` | 是否启用凌晨定时停止与自动重启微信 |
| `WECHAT_NIGHTLY_STOP_TIME` | `23:30` | 每日自动关闭微信的时刻（HH:MM 格式） |
| `WECHAT_NIGHTLY_START_TIME` | `01:30` | 每日自动重新启动微信的时刻（HH:MM 格式） |
| `ENABLE_WECHAT_AUTO_LOGIN` | Compose 为 `false`，`docker run` 为 `true` | 是否在微信启动/重启后自动识别并点击登录按钮 |
| `AUTO_LOGIN_DELAY` | `3` | 微信启动后等待 UI 渲染完成的秒数 |

使用密码文件时，留空 `PASSWORD`，在容器环境中设置 `SELKIES_BASIC_AUTH_PASSWORD_FILE`，指向桌面用户可读的文件。旧 LinuxServer 部署可沿用 `FILE__PASSWORD`。

#### 端口配置

- Compose 的 `HTTP_PORT` 和 `HTTPS_PORT` 是宿主机端口，默认分别为 `3000` 和 `3001`。
- 如需修改容器监听端口，在服务的 `environment` 中设置 `SELKIES_PORT` 或 `SELKIES_HTTPS_PORT`，并同步修改 `ports` 映射右侧的端口。

#### 数据卷挂载

- `./config:/config`: 微信配置和数据持久化目录

## 高级配置

### 硬件加速

如果宿主机有 `/dev/dri` 且需要 GPU 硬件加速，可在 Compose 服务下启用以下设备映射。

```yaml
devices:
  - /dev/dri:/dev/dri
```

## 目录结构

```
wechat-selkies/
├── docker-compose.yml          # Docker Compose 配置文件
├── .env.example                # 环境变量示例文件
├── Dockerfile                  # Docker 镜像构建文件
├── LICENSE                     # License
├── README.md                   # 项目说明文档
├── config/                     # 配置和数据持久化目录
└── root/                       # 容器初始化文件
    ├── defaults/              # 菜单模板
    └── scripts/               # 容器和应用启动脚本
```

## 故障排除

### 更新微信/QQ版本

当微信或QQ提示"版本过期"时，可拉取所用发布分支的新版镜像并重建容器即可，聊天记录和配置不受影响：

```bash
# 使用预构建镜像
docker compose pull && docker compose up -d

# 使用源码构建
git pull && docker compose up -d --build
```

> **注意：** 微信使用官方更新地址；QQ 自动检测优先尝试官方最新版，下载失败时依次回退到上次成功的地址和备用版本，并记录实际使用的地址。CI 构建使用 `versions/upstream.env` 中的地址和 SHA256 校验安装包。

对于仓库维护者，当前自动化流程如下：

1. `Detect Upstream Package Updates` 每 6 小时检查一次微信和 QQ 官方安装包，也支持手动触发
2. 如果检测到实际下载地址、版本号或安装包哈希变化，工作流会更新 `versions/upstream.env`
3. 自动检测将变更提交到 `master` 后，通过 `workflow_dispatch` 显式触发 `Build and Publish Docker Image`（`GITHUB_TOKEN` 的提交不会触发其他 push 工作流）
4. 镜像构建传入安装包 SHA256，确保版本变化时刷新下载缓存，并在安装前校验文件；镜像发布串行执行，减少并发推送触发限流

版本状态文件位于 `versions/upstream.env`，当前记录了：

- 微信和 QQ amd64/arm64 实际下载成功的地址
- 微信和 QQ amd64/arm64 解析出的版本号
- 微信和 QQ amd64/arm64 安装包 SHA256
- 最近一次发生变更的检测时间

### 常见问题

1. **无法访问 Web UI**
   - 检查端口 3001 是否被占用
   - 确认 Docker 容器正常运行：`docker ps`

2. **微信顶部搜索框闪退或输入落到聊天框**
   如果使用自定义 `/config/.config/openbox/rc.xml`，请把[镜像配置](root/etc/xdg/openbox/rc.xml)中的 `<application>` 规则复制到第一个 `<applications>` 段，放在通用微信规则和通配规则之前，然后重启容器。

### 日志查看

查看容器运行日志：
```bash
docker compose logs -f wechat-selkies
```

## 技术架构

- **基础镜像**：`ghcr.io/selkies-project/selkies/base:main-ubuntu26.04`
- **微信客户端**：官方微信 Linux 版本
- **Web 技术**：Selkies WebRTC
- **桌面与 API**：Selkies 内置 X11 窗口管理器读取 Openbox 格式菜单和部分窗口规则，Pelorus 提供桌面操作 API。桌面网页及其安装后的 Web 应用使用 `TITLE` 和微信图标，网页助手使用 Pelorus 的名称与图标。[上游接口](https://github.com/selkies-project/selkies/blob/f956c26/crates/selkies/src/pelorus.rs)
- **容器化**：Docker + Docker Compose

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -am 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

## 许可证

本项目采用 **MIT License** 开源协议。详见 [LICENSE](LICENSE) 文件。

### 📜 许可证说明

- **项目许可证**: MIT License - 宽松的开源许可证
- **许可证兼容性**: 由于本项目仅使用基础镜像而未修改其源码，根据容器化软件的许可证实践，可以采用MIT许可证
- **源码开放**: 完整项目源代码在 GitHub 上公开：https://github.com/nickrunning/wechat-selkies

## 免责声明与版权声明

### 🚨 重要声明

**本项目与腾讯公司无任何关联，属于独立的第三方开源项目。**

### 📋 版权声明

- **微信®** 是 **腾讯公司** 的注册商标和版权作品
- 本项目中使用的微信相关图标、logo 等视觉元素的版权归腾讯公司所有
- 本项目仅为技术展示和学习目的，不用于商业用途
- **如有版权争议，将立即移除相关内容**

### ⚖️ 法律合规

- 本项目严格遵守相关法律法规和用户协议
- 用户使用本项目时应遵守当地法律法规
- 本项目不对用户的使用行为承担法律责任
- **如腾讯公司认为存在侵权行为，请联系我们立即处理**

### 🎯 使用条款

- 本项目仅供学习、研究和个人使用
- 禁止用于任何商业目的或盈利活动
- 用户应自行承担使用风险和法律责任
- 请遵守微信用户协议和相关服务条款

## 相关链接

- [微信官方网站](https://weixin.qq.com/)
- [Selkies WebRTC](https://github.com/selkies-project)
- [xiaoheiCat/docker-wechat-sogou-pinyin](https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nickrunning/wechat-selkies&type=Date)](https://www.star-history.com/#nickrunning/wechat-selkies&Date)
