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

基于 Docker 的微信/QQ Linux 客户端，使用 Selkies WebRTC 技术提供浏览器访问支持。

## 项目简介

本项目将官方微信/QQ Linux 客户端封装在 Docker 容器中，通过 Selkies 技术实现在浏览器中直接使用微信/QQ，无需在本地安装微信/QQ 客户端。适用于服务器部署、远程办公等场景。

## 升级注意事项

> 如果升级后部分功能缺失，请先清空本地挂载目录下的openbox目录(如`./config/.config/openbox`)。

## 功能特性

- 🌐 **浏览器访问**：通过 Web 浏览器直接使用微信，无需本地安装
- 🐳 **Docker化部署**：简单的容器化部署，环境隔离
- 🔒 **数据持久化**：支持配置和聊天记录持久化存储
- 🎨 **中文支持**：完整的中文字体和本地化支持，支持本地中文输入法
- 🖼️ **图片复制**：支持通过侧边栏面板开启图片复制
- 📁 **文件传输**：支持通过侧边栏面板进行文件传输
- 🖥️ **AMD64和ARM64架构支持**：兼容主流CPU架构
- 🔧 **硬件加速**：可选的 GPU 硬件加速支持
- 🪟 **窗口切换器**：左上角增加切换悬浮窗，方便切换到后台窗口，为后续添加其它功能做基础
- 🤖 **自动启动**：可配置自动启动微信和QQ客户端（可选）
- 🔐 **单会话接管**：新客户端登录后会踢下旧客户端并退回 PIN 页面

## 近期新增特性

- **AMD GPU 支持**：优先支持 `/dev/dri` 的 VAAPI 硬件编码路径（不可用时自动回退 CPU）。
- **简化 PIN 登录**：登录页仅保留 PIN 密码输入，去除账号输入流程。
- **增强图片复制/粘贴**：支持浏览器 `Ctrl+V` 图片直达远端剪贴板并可自动粘贴到聊天输入框。
- **自动分屏工具**：新增窗口右键分屏和悬浮分屏工具，支持左右对半分、上下对半分、都全屏三种模式。
- **低延迟优化**：默认参数与编码策略针对交互延迟优化，并增加卡流自动恢复与 X11 自愈机制。
- **QQ 新特性支持**：镜像构建阶段自动解析并安装最新 Linux QQ，叠加卡死检测与自动拉起能力。
- **链接本地打开**：容器内应用触发链接打开时，由浏览器客户端在本机拉起新标签页打开链接。

## 截图展示
![微信截图](./docs/images/wechat-selkies-1.jpg)
![QQ截图](./docs/images/wechat-selkies-2.jpg)

## 快速开始

### 环境要求

- Docker
- Docker Compose
- 支持WebRTC的现代浏览器（Chrome、Firefox、Safari等）

### 快速部署

1. **直接使用已构建的镜像进行快速部署**

GitHub Container Registry镜像：
```bash
docker run -it -p 3001:3001 -v ./config:/config --device /dev/dri:/dev/dri ghcr.io/nickrunning/wechat-selkies:latest
```

Docker Hub镜像：
```bash
docker run -it -p 3001:3001 -v ./config:/config --device /dev/dri:/dev/dri nickrunning/wechat-selkies:latest
```

2. **访问微信**
   
   在浏览器中访问：`https://localhost:3001` 或 `https://<服务器IP>:3001`
   > **注意：** 映射3000端口用于HTTP访问，3001端口用于HTTPS访问，建议使用HTTPS。

### docker-compose 部署
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
          # - PASSWORD=<Your PIN>          # PIN 登录（仅密码输入，无需账号）
        mem_reservation: "1g"            # reduce OOM risk during long-running idle sessions
        mem_limit: "2g"                  # hard limit, adjust by host capacity
        shm_size: "1gb"                  # recommended, will improve performance
    ```
3. **启动服务**
   ```bash
   docker-compose up -d
   ```

### 源码部署

1. **克隆项目**
   ```bash
   git clone https://github.com/nickrunning/wechat-selkies.git
   cd wechat-selkies
   ```

2. **启动服务**
   ```bash
   docker-compose up -d
   ```

3. **访问微信**

   在浏览器中访问：`https://localhost:3001` 或 `https://<服务器IP>:3001`

### 配置说明

更多自定义配置请参考 [Selkies Base Images from LinuxServer](https://github.com/linuxserver/docker-baseimage-selkies)。

#### Docker Hub 推送配置

本项目支持同时推送到 GitHub Container Registry 和 Docker Hub。如需启用 Docker Hub 推送功能，请在仓库下添加Environment Secrets和Environment Variables:

**Environment Secrets:**
* DOCKERHUB_USERNAME: 你的 Docker Hub 用户名
* DOCKERHUB_TOKEN: 你的 Docker Hub Access Token
**Environment Variables:**
* ENABLE_DOCKERHUB: 设置为 `true` 来启用 Docker Hub 推送

#### 环境变量配置

在 `docker-compose.yml` 中可以配置以下环境变量：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `TITLE` | `WeChat Selkies` | Web UI 标题 |
| `PUID` | `1000` | 用户 ID |
| `PGID` | `100` | 组 ID |
| `TZ` | `Asia/Shanghai` | 时区设置 |
| `LC_ALL` | `zh_CN.UTF-8` | 语言环境 |
| `CUSTOM_USER` | - | 兼容旧配置字段（PIN 模式下不需要） |
| `PASSWORD` | - | Web UI PIN 码（仅密码输入，无需账号） |
| `AUTO_START_WECHAT` | `true` | 是否自动启动微信客户端 |
| `AUTO_START_QQ` | `false` | 是否自动启动 QQ 客户端 |
| `PROCESS_WATCHDOG` | `true` | 启用容器内进程看门狗 |
| `WATCHDOG_INTERVAL` | `10` | 看门狗巡检间隔（秒） |
| `WATCHDOG_TRAY` | `true` | 自动拉起 stalonetray 托盘进程 |
| `WATCHDOG_RESTART_WECHAT` | `true` | 微信进程退出后自动重启 |
| `WATCHDOG_RESTART_QQ` | `true` | QQ 进程退出后自动重启（仅在 AUTO_START_QQ=true 时） |
| `WECHAT_IDLE_KEEPALIVE` | `true` | 空闲时定时激活微信窗口并触发轻量按键，降低隔夜掉线概率 |
| `WECHAT_KEEPALIVE_INTERVAL` | `1800` | 微信保活巡检间隔（秒） |
| `WECHAT_KEEPALIVE_IDLE_SECONDS` | `1800` | 仅当会话空闲超过该阈值时执行保活（秒） |
| `QQ_EXTRA_FLAGS` | `--disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-gpu --disable-gpu-compositing --disable-gpu-rasterization --disable-features=CalculateNativeWinOcclusion,UseSkiaRenderer` | QQ 启动附加参数（降低 GPU 导致的卡死概率） |
| `QQ_NICE_LEVEL` | `-2` | QQ 进程 nice 优先级（-20 到 19） |
| `QQ_WATCHDOG_HANG_DETECT` | `true` | 启用 QQ 卡死检测（进程存在但窗口不响应） |
| `QQ_WATCHDOG_FAIL_THRESHOLD` | `3` | 连续失败达到阈值后重启 QQ |
| `QQ_WATCHDOG_X11_PING` | `true` | 通过 X11 查询窗口名检测 QQ 窗口响应性 |
| `QQ_WATCHDOG_X11_TIMEOUT` | `2` | X11 响应检测超时（秒） |
| `DRI_NODE` | `/dev/dri/renderD128` | VAAPI 渲染节点路径（存在时优先尝试 GPU 编码） |
| `SELKIES_ENABLE_BINARY_CLIPBOARD` | `true` | 启用二进制剪贴板（图片等） |
| `SELKIES_PASTE_IMAGE` | `true` | 启用浏览器内 Ctrl+V 图片粘贴 |
| `SELKIES_PASTE_IMAGE_MAX_SIZE` | `20971520` | 图片粘贴最大字节数（默认 20MB） |
| `SELKIES_PASTE_IMAGE_AUTO_PASTE` | `true` | 写入远端剪贴板后自动发送 Ctrl+V |
| `SELKIES_DEFAULT_ENCODER` | `x264enc` | 默认编码器（低延迟优先，稳定模式） |
| `SELKIES_DEFAULT_FRAMERATE` | `48` | 默认帧率 |
| `SELKIES_DEFAULT_GAMEPAD_ENABLED` | `false` | 触控手柄默认开关 |
| `SELKIES_DEFAULT_BINARY_CLIPBOARD` | `true` | 前端侧二进制剪贴板默认开关 |
| `SELKIES_DEFAULT_USE_CPU` | `false` | 默认优先 VAAPI 编码（无 DRI 时自动回退 CPU） |
| `SELKIES_DEFAULT_H264_STREAMING_MODE` | `true` | 默认开启 H264 streaming mode（降低端到端延迟） |
| `SELKIES_DEFAULT_USE_PAINT_OVER_QUALITY` | `false` | 默认关闭静态场景高质量叠加（降低突发延迟） |
| `SELKIES_DEFAULT_H264_CRF` | `30` | 默认 H264 CRF（优先降低编码负载与输入延迟） |
| `SELKIES_STREAM_WAIT_THRESHOLD_MS` | `35000` | 页面处于 `Waiting for stream...` 且无视频流时，自动恢复阈值（毫秒） |
| `SELKIES_STREAM_RECOVER_COOLDOWN_MS` | `120000` | 自动恢复冷却时间（毫秒，防止循环刷新） |
| `SELKIES_LOCAL_LINK_OPEN` | `true` | 启用容器应用链接在本地浏览器打开（QQ/微信点击链接） |
| `SELKIES_LOCAL_LINK_POLL_INTERVAL_MS` | `800` | 前端轮询链接事件间隔（毫秒） |
| `LOCAL_LINK_BRIDGE_PORT` | `38080` | 容器内本地链接桥接服务端口（需与 nginx 配置保持一致） |
| `LOCAL_LINK_BRIDGE_MAX_EVENTS` | `256` | 本地链接事件队列容量（环形缓存） |
| `LOCAL_LINK_BRIDGE_ALLOWED_SCHEMES` | `http,https,mailto` | 允许从容器传递到本地浏览器打开的协议白名单 |

#### 图片粘贴（Ctrl+V）

该功能默认启用；如需显式声明，保持以下配置为 `true`：

- `SELKIES_ENABLE_BINARY_CLIPBOARD=true`
- `SELKIES_PASTE_IMAGE=true`

可选配置：

- `SELKIES_PASTE_IMAGE_MAX_SIZE`：最大图片大小（默认 20MB）
- `SELKIES_PASTE_IMAGE_AUTO_PASTE=false`：关闭自动触发远端 Ctrl+V

注意事项：

- 仅在用户触发粘贴（Ctrl+V 或浏览器粘贴事件）时读取剪贴板
- 需要 HTTPS 或 localhost 才能使用 Clipboard API
- 目前至少支持 `image/png`，其它格式视客户端/微信支持情况而定

#### 单会话接管（新连接踢旧连接）

- 当有新的客户端成功接入时，已有客户端会被强制断开并跳回 PIN 登录页。
- 该策略用于避免多客户端抢占导致的 `Waiting for stream...` 与会话混乱。

#### 编码器模式显示与 VAAPI 回退

- 默认编码器采用策略：`x264enc` + `use_cpu=false`（优先 VAAPI）。
- 视频设置里的编码器下拉框旁会显示当前模式徽标：`VAAPI` 或 `CPU`。
- 已移除会导致黑屏的实验编码器注入项（`vaapih264enc`、`vaapih265enc`、`vaapivp9enc`、`vaav1enc`）。
- 编码模式徽标会在首屏加载、编码器切换以及每次重新打开侧边栏/视频设置时自动刷新为 `CPU` 或 `VAAPI`。
- 长时间空闲后若页面卡在 `Waiting for stream...`，前端会在阈值后自动执行一次恢复刷新（受上述两个环境变量控制）。

#### QQ 版本与性能说明

- 镜像构建阶段会从腾讯 Linux QQ 官方配置 `linuxConfig.js` 解析最新 deb 下载地址，优先安装最新版本，解析失败时才回退到内置版本链接。
- 若 QQ 仍然卡顿，可先尝试：
  - 增大 `shm_size` 与 `mem_limit`
  - 调整 `QQ_EXTRA_FLAGS`
  - 适度降低 `QQ_NICE_LEVEL`（例如 `-5`，需要容器内允许设置优先级）

#### 端口配置

- `3001`: Web UI 访问端口

#### 数据卷挂载

- `./config:/config`: 微信配置和数据持久化目录

> **注意：** 如果升级后右键菜单缺少 `WeChat` 相关选项，请先清空本地挂载目录下的openbox目录(如`./config/.config/openbox`)。

## 高级配置

### 硬件加速

如果您的系统支持 GPU 硬件加速，Docker Compose 配置中已包含相关设备映射：

```yaml
devices:
  - /dev/dri:/dev/dri
```

## 目录结构

```
wechat-selkies/
├── docker-compose.yml          # Docker Compose 配置文件
├── Dockerfile                  # Docker 镜像构建文件
├── LICENSE                     # License
├── README.md                   # 项目说明文档
├── config/                     # 配置和数据持久化目录
└── root/                       # 容器初始化文件
    ├── defaults/
    │   └── autostart           # 自动启动配置
    └── wechat.png              # 微信图标
```

## 故障排除

### 常见问题

1. **无法访问 Web UI**
   - 检查端口 3001 是否被占用
   - 确认 Docker 容器正常运行：`docker ps`

### 微信夜间“为了账号安全已退出登录”排查

- 文档：`docs/ops/wechat-overnight-security-exit.md`
- 单次证据采集：
  - `powershell -ExecutionPolicy Bypass -File scripts/ops/collect-overnight-evidence.ps1 -ContainerName wechat-selkies`
- 7晚汇总验收：
  - `powershell -ExecutionPolicy Bypass -File scripts/ops/summarize-overnight-evidence.ps1 -InputDir diagnostics/overnight -WindowSize 7`

### 日志查看

查看容器运行日志：
```bash
docker-compose logs -f wechat-selkies
```

## 技术架构

- **基础镜像**：`ghcr.io/linuxserver/baseimage-selkies:ubuntunoble`
- **微信客户端**：官方微信 Linux 版本
- **Web 技术**：Selkies WebRTC
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
- **依赖项说明**: 本项目使用 [LinuxServer.io baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies) 作为基础镜像
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
- [LinuxServer.io](https://github.com/linuxserver)
- [xiaoheiCat/docker-wechat-sogou-pinyin](https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nickrunning/wechat-selkies&type=Date)](https://www.star-history.com/#nickrunning/wechat-selkies&Date)



