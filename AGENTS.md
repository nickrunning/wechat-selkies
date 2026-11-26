# WeChat Selkies 维护指南

本项目基于 Selkies 官方 `main-ubuntu26.04` 镜像，支持 AMD64 和 ARM64。桌面使用 Selkies 内置的 X11 窗口管理器。外部 Agent 通过 `/api/pelorus/` 调用内置 Pelorus，沿用 Web 登录凭据。`/pelorus/` 是浏览器中的 Agent 界面。

## 代码入口

| 修改内容 | 从哪里开始 |
| --- | --- |
| 镜像与依赖 | `Dockerfile` 按架构安装微信，QQ 和 PCManFM 可在构建时关闭。`root/` 中的内容会复制到镜像根目录，只放容器运行所需文件。 |
| 容器启动 | `root/wechat-container-start` 处理身份、卷权限和旧配置，生成初始菜单，再启动 Selkies。入口放在 `/scripts` 之外，兼容已有的脚本挂载。 |
| 桌面自启动 | 窗口管理器通过 `root/defaults/autostart` 调用 `root/scripts/start.sh`。应用和定时任务在后台运行。`root/scripts/window_switcher.py` 已停用，保留文件。 |
| 微信自动登录 | `root/scripts/wechat/wechat-start.sh` 将本次启动的微信 PID 传给 `root/scripts/wechat/wechat-auto-login.py`。修改 AT-SPI 点击逻辑时，保留对目标进程和登录窗口的校验。 |
| 右键菜单 | 编辑 Openbox 格式的 `root/defaults/menu.xml`。`root/scripts/refresh-menu.sh` 合并桌面的 `.desktop` 快捷方式，仅在内容变化时写入 `/config/.config/openbox/menu.xml`。 |
| 发布 | `.github/workflows/docker.yml` 从 `master` 构建 `edge` 和 `edge-minimal`。稳定版的完整和精简镜像都通过 AMD64 卷迁移测试后，才更新 `latest` 和 `minimal`。 |

## 配置与迁移

- 仓库的 `config/` 是用户挂载到 `/config` 的运行数据。改菜单或启动配置时编辑 `root/` 下的源码，迁移测试使用临时卷。
- 升级沿用原容器的 `PUID` 和 `PGID`。省略时，仓库 Compose 的默认值为 `1000:100`，直接以 root 启动镜像的默认值为 `911:911`。同一卷可有多种属主，禁止从数据目录推断身份或递归修改卷内属主。
- Web 登录通常在 `.env` 中设置 `PASSWORD`。文件密码沿用 Selkies 原生的 `SELKIES_BASIC_AUTH_PASSWORD_FILE`，旧 LinuxServer 部署兼容 `FILE__PASSWORD`。
- 修改用户可见配置时，核对 `Dockerfile` 的镜像默认值和 `docker-compose.yml` 的部署默认值，两者可以不同。例如微信自动登录在镜像中默认开启，仓库 Compose 默认关闭。按需同步 `.env.example`、[中文 README](README.md) 和 [英文 README](README_en.md)。

## 本地验证

```bash
# 检查 Compose 配置
docker compose config -q

# 修改启动或卷迁移逻辑后，构建本地镜像并用临时卷验证
docker compose build wechat-selkies
bash .github/tests/test-volume-migration.sh wechat-selkies:latest

# 修改上游软件包检测脚本后，运行对应单测
python3 -m unittest discover -s .github/tests -v
```

首次启动桌面前，复制 `.env.example` 为 `.env` 并设置 `PASSWORD`，然后运行 `docker compose up -d --build`。已有部署保留原 `.env` 和挂载路径，升级与回滚步骤见 [README](README.md#从旧版升级或回滚)。
