# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-23
**Commit:** e18821f
**Branch:** master

## OVERVIEW

Docker 容器化微信/QQ Linux 客户端，基于 LinuxServer Selkies WebRTC 基础镜像，通过浏览器远程访问桌面应用。支持 AMD64/ARM64 双架构。

## STRUCTURE

```
wechat-selkies/
├── Dockerfile              # 单阶段构建，基于 selkies:ubunturesolute
├── docker-compose.yml      # 单服务编排
├── root/                   # COPY /root / → 容器内脚本和配置
│   ├── defaults/
│   │   ├── autostart           # 容器启动入口，仅一行: /scripts/start.sh
│   │   └── menu.xml            # Openbox 右键菜单模板（静态基础项）
│   └── scripts/
│       ├── start.sh            # 主启动脚本：openbox配置 → 菜单刷新 → 监听桌面 → 启动应用
│       ├── refresh-menu.sh     # 合并 menu.xml + ~/Desktop/*.desktop → 生成最终菜单
│       ├── window_switcher.py  # ⚠️ 已废弃，仅保留
│       ├── wechat/             # wechat-start.sh / wechat-restart.sh / wechat-unminimize.sh
│       └── qq/                 # qq-restart.sh
├── .github/workflows/      # CI: 多架构构建 + Issue 自动化
├── docs/images/            # README 截图
└── config/                 # ⚠️ gitignored 运行时数据挂载点
```

## WHERE TO LOOK

| 任务 | 位置 | 备注 |
|------|------|------|
| 添加新应用 | `Dockerfile` (安装) + `root/defaults/menu.xml` (菜单) | 参考 QQ 安装段落的 case 模式 |
| 修改启动行为 | `root/scripts/start.sh` | 入口脚本，由 `root/defaults/autostart` 触发 |
| 修改右键菜单 | `root/defaults/menu.xml` + `root/scripts/refresh-menu.sh` | menu.xml 是模板，refresh-menu.sh 动态合并 ~/Desktop/*.desktop |
| 修改菜单动态生成逻辑 | `root/scripts/refresh-menu.sh` | 解析 .desktop 文件的 Name/Exec/Icon 字段，处理图标搜索 |
| 添加新应用启动/重启脚本 | `root/scripts/<app>/` | 遵循 wechat/ 目录模式: start.sh + restart.sh |
| 修改环境变量 | `Dockerfile` (ENV) + `docker-compose.yml` (environment) | 两处需同步 |
| CI/CD | `.github/workflows/docker.yml` | tag v* 触发，多架构 buildx，可选推送 Docker Hub |
| Issue 自动化 | `.github/workflows/issue-validation.yml` + `cleanup-issues.yml` | 标题/描述校验 + 7天自动关闭 |

## CONVENTIONS

- **语言**: 脚本用 Bash (#!/bin/bash)，窗口切换器用 Python3 + Xlib + tkinter
- **容器路径约定**: `COPY /root /` 将 `root/` 目录内容映射到容器根 `/`，因此 `root/scripts/start.sh` → 容器内 `/scripts/start.sh`
- **自启动机制**: Selkies 基础镜像读取 `/defaults/autostart` 文件执行启动脚本
- **菜单刷新**: inotifywait 监听 `~/Desktop/` 变更自动刷新 Openbox 菜单
- **进程管理**: 应用通过 `nohup ... &` 后台启动，restart 脚本先 `pkill -9` 再启动
- **restart 脚本模式**: `pkill -9 -f /usr/bin/<app>` → `nohup /usr/bin/<app> >/dev/null 2>&1 &`（QQ 需额外 `--no-sandbox`）
- **菜单模板 vs 运行时**: `root/defaults/menu.xml` 是源码模板，`/config/.config/openbox/menu.xml` 是运行时生成的，不要混淆
- **refresh-menu.sh**: 仅在内容变更时才写入 + reconfigure，避免无意义刷新
- **图标搜索优先级**: proot-apps icons (256→512→128→64→48→scalable) → system icons → fallback xterm icon
- **多架构**: Dockerfile 使用 `$TARGETPLATFORM` 条件分支安装不同架构 deb 包

## ANTI-PATTERNS (THIS PROJECT)

- **不要直接修改 `config/` 目录下的文件** — 这是运行时挂载数据，gitignored
- **不要修改 `config/.config/openbox/` 下文件作为"源码"** — 这些由 `root/defaults/` 模板生成
- **不要在 `root/` 下放非容器必需文件** — `COPY /root /` 会将所有内容复制到容器根目录
- **不要在 menu.xml 中添加 .desktop 动态条目** — 由 refresh-menu.sh 自动处理
- **不要在 start.sh 中用 `exec` 替代 `nohup ... &`** — 需要多进程并行运行
- **升级后功能缺失** → 清空 `./config/.config/openbox/` 目录（已知 gotcha，见 README）
- **window_switcher.py 已废弃** — `start.sh` 中已注释掉，但文件保留，不要删除

## COMMANDS

```bash
# 本地构建并启动
docker-compose up -d --build

# 仅启动（使用已有镜像）
docker-compose up -d

# 查看日志
docker-compose logs -f wechat-selkies

# 进入容器调试
docker exec -it wechat-selkies bash

# 清理升级问题
rm -rf ./config/.config/openbox
```

## NOTES

- 端口 3000=HTTP, 3001=HTTPS（推荐 HTTPS）
- `shm_size: "1gb"` 影响 WebRTC 性能，建议保留
- `/dev/dri` 映射为可选 GPU 加速
- `AUTO_START_WECHAT` / `AUTO_START_QQ` 控制容器启动时是否自动拉起应用
- 第三方应用通过 proot-apps 安装，快捷方式自动出现在右键菜单
- Docker Hub 推送需在 GitHub 仓库 Environment 中配置 `ENABLE_DOCKERHUB=true`
