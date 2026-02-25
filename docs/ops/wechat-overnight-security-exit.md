# 微信夜间“为了账号安全已退出登录”排查（容器稳定性版）

本方案只做容器侧证据采集与稳态治理，不删除配置文件，不做自动点击/按键模拟。

## 目标

区分两类问题：

1. 容器中断：`pause/restart/oom/kill/die` 或状态异常。
2. 容器持续运行但微信仍被踢下线：更偏风控/网络特征。

## 已落地配置

`docker-compose.yml` 已增加：

- `restart: unless-stopped`（原有）
- `mem_reservation: "1g"`
- `mem_limit: "2g"`
- `shm_size: "1gb"`（原有）

## 证据采集脚本

### 1) 单次采集

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ops/collect-overnight-evidence.ps1 `
  -ContainerName wechat-selkies `
  -Since "2026-02-01T22:00:00+08:00" `
  -Until "2026-02-02T08:00:00+08:00"
```

默认输出目录：`diagnostics/overnight/<timestamp>/`

输出文件：

- `inspect.json`
- `state-summary.txt`
- `events.log`
- `events.lifecycle.log`
- `container.log`
- `wechat-process.txt`
- `network-check.txt`
- `summary.json`
- `summary.txt`

### 2) 7晚汇总

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ops/summarize-overnight-evidence.ps1 `
  -InputDir diagnostics/overnight `
  -WindowSize 7
```

输出：`diagnostics/overnight/seven-night-report.json`

## 判定规则

### 先判容器是否中断

若任一条件命中，优先按“容器稳定性问题”处理：

- `state.paused=true`
- `state.running=false`
- `events.lifecycle.log` 出现 `pause/unpause/restart/oom/kill/die/stop/start`
- 7晚内 `restartCount` 上升

### 若容器稳定但仍被踢

满足以下条件时，更偏微信风控/网络特征：

- 每晚 `running=true && paused=false`
- `restartCount` 不增长
- 微信仍提示“为了账号安全已退出登录”

## 7晚验收标准

1. 连续 7 晚满足：
   - `running=true`
   - `paused=false`
   - `restartCount` 不增长
2. 若仍被踢：可以明确“不是容器休眠/暂停导致”。
3. 若发现 pause/restart/oom：先修稳定性，再重新做 7 晚验证。

## 说明

- 本方案不清理 `./config`，不重置 openbox，不清微信缓存。
- 本方案不包含任何自动交互保活行为。
